from pathlib import Path

from django.conf import settings
from django.contrib import messages
from django.contrib.auth.decorators import login_required
from django.db import transaction
from django.http import FileResponse, Http404, HttpResponseNotAllowed
from django.shortcuts import get_object_or_404, redirect, render
from django.urls import reverse
from django.utils import timezone
from django.views.decorators.http import require_GET, require_POST

from .ai import configured
from .call_gate import cancel_queued_task
from .export import render_docx, segments
from .extract import MAX_EXTRACTED_CHARS, MaterialExtractionError, extract_text
from .forms import MaterialUploadForm, MemberModelSelectionForm, RevisionForm, TeacherProfileForm
from .models import CallAllowance, GenerationTask, Material, ModelCredential, TeacherProfile, Worksheet, WorksheetVersion
from .queue import enqueue_task


def _manual_queue():
    return settings.AI_LOCAL_QUEUE or settings.AI_STAGING_MANUAL_QUEUE


def _ai_available(user=None):
    if settings.AI_MEMBER_TASKS_ENABLED:
        if user is None:
            return False
        allowance = CallAllowance.objects.filter(owner=user).first()
        return bool(allowance and allowance.valid_until > timezone.now() and
                    allowance.max_calls > allowance.used_calls + allowance.reserved_calls and
                    ModelCredential.objects.filter(owner=user).exists())
    return configured() or _manual_queue()


@login_required
@require_GET
def dashboard(request):
    return render(request, "workbench/dashboard.html", {
        "ai_available": _ai_available(request.user),
        "local_queue": _manual_queue(),
        "staging_queue": settings.AI_STAGING_MANUAL_QUEUE,
    })


@login_required
@require_GET
def worksheet_start(request):
    return render(request, "workbench/worksheet_start.html", {
        "materials": Material.objects.filter(owner=request.user),
        "upload_form": MaterialUploadForm(),
        "ai_available": _ai_available(request.user),
        "member_mode": settings.AI_MEMBER_TASKS_ENABLED,
        "member_credentials": (ModelCredential.objects.filter(owner=request.user).order_by("label")
                               if settings.AI_MEMBER_TASKS_ENABLED else []),
        "local_queue": _manual_queue(),
        "staging_queue": settings.AI_STAGING_MANUAL_QUEUE,
    })


@login_required
@require_GET
def worksheet_list(request):
    return render(request, "workbench/worksheet_list.html", {
        "worksheets": Worksheet.objects.filter(owner=request.user).select_related("material", "final_version"),
    })


@login_required
@require_GET
def material_library(request):
    return render(request, "workbench/material_library.html", {
        "materials": Material.objects.filter(owner=request.user),
        "upload_form": MaterialUploadForm(),
    })


@login_required
def edit_profile(request):
    profile, _ = TeacherProfile.objects.get_or_create(owner=request.user)
    if request.method == "POST":
        form = TeacherProfileForm(request.POST, instance=profile)
        if form.is_valid():
            form.save()
            messages.success(request, "个人教学设置已保存。")
            return redirect("dashboard")
    else:
        form = TeacherProfileForm(instance=profile)
    return render(request, "workbench/profile.html", {"form": form})


@login_required
def upload_material(request):
    if request.method != "POST":
        return HttpResponseNotAllowed(["POST"])
    form = MaterialUploadForm(request.POST, request.FILES)
    if not form.is_valid():
        return render(request, "workbench/upload_error.html", {"form": form}, status=400)
    uploaded = form.cleaned_data["file"]
    try:
        extracted = extract_text(uploaded)
    except MaterialExtractionError as exc:
        form.add_error("file", str(exc))
        return render(request, "workbench/upload_error.html", {"form": form}, status=400)
    name = Path(uploaded.name.replace("\\", "/")).name[:255]
    Material.objects.create(owner=request.user, file=uploaded, original_name=name,
                            size_bytes=uploaded.size, extracted_text=extracted)
    messages.success(request, "资料已保存，文字已提取。")
    return redirect("material_library" if request.POST.get("return_to") == "materials" else "worksheet_start")


@login_required
@require_GET
def download_material(request, material_id):
    material = get_object_or_404(Material, pk=material_id, owner=request.user)
    try:
        stream = material.file.open("rb")
    except FileNotFoundError as exc:
        raise Http404("文件不存在。") from exc
    response = FileResponse(stream, as_attachment=True, filename=material.original_name)
    response["Cache-Control"] = "private, no-store"
    return response


def _enqueue_or_fail(task):
    try:
        enqueue_task(task.pk)
    except Exception:
        task.status = GenerationTask.Status.FAILED
        task.error_message = "任务队列不可用，请稍后再试。"
        task.save(update_fields=["status", "error_message", "updated_at"])
        return False
    return True


@login_required
@require_POST
def create_worksheet(request, material_id):
    material = get_object_or_404(Material, pk=material_id, owner=request.user)
    if len(material.extracted_text) > MAX_EXTRACTED_CHARS:
        messages.error(request, "这份旧资料文字超过当前 15000 字上限，请拆分后重新上传；没有调用模型。")
        return redirect("worksheet_start")
    if not _ai_available(request.user):
        messages.error(request, "未配置并启用真实 AI 服务；没有调用模型。")
        return redirect("worksheet_start")
    member_credential = None
    if settings.AI_MEMBER_TASKS_ENABLED:
        selection = MemberModelSelectionForm(request.POST, owner=request.user)
        if not selection.is_valid():
            messages.error(request, "请选择本人可用的模型配置；没有调用模型。")
            return redirect("worksheet_start")
        member_credential = selection.cleaned_data["credential"]
    worksheet = Worksheet.objects.create(owner=request.user, material=material)
    task = GenerationTask.objects.create(owner=request.user, worksheet=worksheet, kind=GenerationTask.Kind.CREATE,
                                         member_mode=settings.AI_MEMBER_TASKS_ENABLED,
                                         member_credential=member_credential)
    if _enqueue_or_fail(task):
        messages.info(request, "生成任务已排队。")
    else:
        messages.error(request, task.error_message)
    return redirect("worksheet_detail", worksheet_id=worksheet.pk)


@login_required
@require_GET
def worksheet_detail(request, worksheet_id):
    worksheet = get_object_or_404(Worksheet.objects.select_related("material", "final_version"),
                                  pk=worksheet_id, owner=request.user)
    versions = list(worksheet.versions.all())
    selected = None
    if versions:
        number = request.GET.get("version")
        if number:
            selected = get_object_or_404(WorksheetVersion, worksheet=worksheet, number=number)
        else:
            selected = versions[0]
    return render(request, "workbench/worksheet.html", {
        "worksheet": worksheet, "versions": versions, "selected": selected,
        "tasks": worksheet.tasks.select_related("call_attempt").all(),
        "revision_form": RevisionForm(owner=request.user, member_mode=settings.AI_MEMBER_TASKS_ENABLED),
        "revision_pending": worksheet.tasks.filter(status__in=[
            GenerationTask.Status.QUEUED, GenerationTask.Status.RUNNING,
        ]).exists(),
        "ai_available": _ai_available(request.user),
        "member_mode": settings.AI_MEMBER_TASKS_ENABLED,
        "local_queue": _manual_queue(), "staging_queue": settings.AI_STAGING_MANUAL_QUEUE,
        "segmenter": segments,
    })


@login_required
@require_POST
def revise_worksheet(request, worksheet_id):
    worksheet = get_object_or_404(Worksheet, pk=worksheet_id, owner=request.user)
    form = RevisionForm(request.POST, owner=request.user, member_mode=settings.AI_MEMBER_TASKS_ENABLED)
    if not form.is_valid():
        messages.error(request, "请填写修改要求，最多 2000 字。")
        return redirect("worksheet_detail", worksheet_id=worksheet.pk)
    if not _ai_available(request.user):
        messages.error(request, "未配置并启用真实 AI 服务；没有调用模型。")
        return redirect("worksheet_detail", worksheet_id=worksheet.pk)
    if len(worksheet.material.extracted_text) > MAX_EXTRACTED_CHARS:
        messages.error(request, "这份旧资料文字超过当前 15000 字上限，请拆分后重新上传；没有调用模型。")
        return redirect("worksheet_detail", worksheet_id=worksheet.pk)
    if not worksheet.versions.exists():
        messages.error(request, "尚无可修改的草稿。")
        return redirect("worksheet_detail", worksheet_id=worksheet.pk)
    if worksheet.tasks.filter(status__in=[GenerationTask.Status.QUEUED, GenerationTask.Status.RUNNING]).exists():
        messages.error(request, "已有任务在处理，请完成后再修改。")
        return redirect("worksheet_detail", worksheet_id=worksheet.pk)
    task = GenerationTask.objects.create(owner=request.user, worksheet=worksheet,
                                         kind=GenerationTask.Kind.REVISE, instruction=form.cleaned_data["instruction"],
                                         member_mode=settings.AI_MEMBER_TASKS_ENABLED,
                                         member_credential=form.cleaned_data.get("credential"))
    if _enqueue_or_fail(task):
        messages.info(request, "修改任务已排队。")
    else:
        messages.error(request, task.error_message)
    return redirect("worksheet_detail", worksheet_id=worksheet.pk)


@login_required
@require_POST
def cancel_task(request, task_id):
    task = get_object_or_404(GenerationTask, pk=task_id, owner=request.user)
    changed = cancel_queued_task(task_id, request.user.pk)
    if changed:
        messages.info(request, "排队任务已取消，不会启动模型调用。")
    else:
        messages.error(request, "任务已开始或结束；已发送的模型请求无法取消。")
    return redirect("worksheet_detail", worksheet_id=task.worksheet_id)


@login_required
@require_POST
def mark_final_version(request, worksheet_id, version_number):
    with transaction.atomic():
        worksheet = get_object_or_404(Worksheet.objects.select_for_update(),
                                      pk=worksheet_id, owner=request.user)
        version = get_object_or_404(WorksheetVersion, worksheet=worksheet, number=version_number)
        worksheet.final_version = version
        worksheet.save(update_fields=["final_version"])
    messages.success(request, f"第 {version.number} 版已标为正式成果，其他历史版本仍保留。")
    return redirect(f"{reverse('worksheet_detail', args=[worksheet.pk])}?version={version.number}")


@login_required
@require_POST
def unmark_final_version(request, worksheet_id, version_number):
    worksheet = get_object_or_404(Worksheet, pk=worksheet_id, owner=request.user)
    version = get_object_or_404(WorksheetVersion, worksheet=worksheet, number=version_number)
    changed = Worksheet.objects.filter(pk=worksheet.pk, final_version=version).update(final_version=None)
    if changed:
        messages.success(request, "已撤回正式标记，草稿和历史版本仍保留。")
    else:
        messages.info(request, "这份作业的正式标记已变化，请查看当前状态。")
    return redirect(f"{reverse('worksheet_detail', args=[worksheet.pk])}?version={version.number}")


@login_required
@require_GET
def export_worksheet(request, worksheet_id, version_number, variant):
    worksheet = get_object_or_404(Worksheet.objects.select_related("material"), pk=worksheet_id, owner=request.user)
    version = get_object_or_404(WorksheetVersion, worksheet=worksheet, number=version_number)
    if variant not in {"student", "teacher"}:
        raise Http404
    output = render_docx(version.content, worksheet.material.original_name, teacher=(variant == "teacher"))
    filename = f"worksheet-{worksheet.pk}-v{version.number}-{variant}.docx"
    response = FileResponse(output, as_attachment=True, filename=filename,
                            content_type="application/vnd.openxmlformats-officedocument.wordprocessingml.document")
    response["Cache-Control"] = "private, no-store"
    return response
