from pathlib import Path

from django.conf import settings
from django.contrib import messages
from django.contrib.auth.decorators import login_required
from django.core.paginator import Paginator
from django.db import transaction
from django.db.models import Q
from django.db.models.functions import Length
from django.http import FileResponse, Http404, HttpResponseNotAllowed
from django.shortcuts import get_object_or_404, redirect, render
from django.urls import reverse
from django.utils import timezone
from django.views.decorators.http import require_GET, require_http_methods, require_POST

from .ai import configured
from .call_gate import cancel_queued_task
from .export import render_docx, segments
from .extract import (AI_TEXT_EXTENSIONS, MAX_EXTRACTED_CHARS, MaterialExtractionError,
                      MaterialTextUnavailable, extract_text)
from .forms import (MaterialCategoryForm, MaterialUploadForm, MemberModelSelectionForm, RevisionForm,
                    TeacherProfileForm, WorksheetGenerationForm)
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


def _material_search(materials, params):
    query = params.get("q", "").strip()[:120]
    category = params.get("category", "")[:61]
    for term in query.split()[:10]:
        materials = materials.filter(Q(original_name__icontains=term) | Q(category__icontains=term))
    if category:
        materials = materials.filter(category="" if category == " " else category)
    return materials, query, category


@login_required
@require_http_methods(["GET", "POST"])
def worksheet_start(request, mode=Worksheet.Mode.EXAM):
    owned = Material.objects.filter(owner=request.user)
    readable = owned.annotate(text_length=Length("extracted_text")).filter(
        text_length__range=(1, MAX_EXTRACTED_CHARS),
    ).defer("extracted_text")
    filtered, query, category = _material_search(readable, request.GET)
    ai_available = _ai_available(request.user)
    form = WorksheetGenerationForm(
        request.POST if request.method == "POST" else None,
        materials=filtered, owner=request.user, member_mode=settings.AI_MEMBER_TASKS_ENABLED,
    )
    if request.method == "POST":
        if not ai_available:
            messages.error(request, "当前模型配置或额度不可用。")
            return redirect(request.resolver_match.url_name)
        if form.is_valid():
            material = form.cleaned_data["material"]
            if material.extracted_text.strip():
                return _queue_worksheet(request, material, mode, form.cleaned_data["instruction"],
                                        form.cleaned_data.get("credential"))
            form.add_error("material", "这份资料没有可用文字，请选择其他资料。")
    return render(request, "workbench/worksheet_start.html", {
        "mode": mode,
        "is_exam": mode == Worksheet.Mode.EXAM,
        "form": form,
        "has_readable": readable.exists(),
        "has_matches": filtered.exists(),
        "query": query,
        "category": category,
        "categories": readable.order_by("category").values_list("category", flat=True).distinct(),
        "ai_available": ai_available,
        "member_mode": settings.AI_MEMBER_TASKS_ENABLED,
        "local_queue": _manual_queue(),
        "staging_queue": settings.AI_STAGING_MANUAL_QUEUE,
        "worksheets": Worksheet.objects.filter(owner=request.user, mode=mode)
        .select_related("material", "final_version").defer("material__extracted_text"),
    })


@login_required
@require_GET
def material_library(request):
    owned = Material.objects.filter(owner=request.user)
    materials, query, category = _material_search(owned, request.GET)
    page = Paginator(materials.annotate(text_length=Length("extracted_text"))
                     .defer("extracted_text").order_by("-created_at", "-pk"), 20).get_page(request.GET.get("page"))
    return render(request, "workbench/material_library.html", {
        "page": page,
        "query": query,
        "category": category,
        "categories": owned.order_by("category").values_list("category", flat=True).distinct(),
        "max_extracted_chars": MAX_EXTRACTED_CHARS,
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
    name = Path(uploaded.name.replace("\\", "/")).name[:255]
    extracted = ""
    try:
        if Path(name).suffix.lower() in AI_TEXT_EXTENSIONS:
            extracted = extract_text(uploaded)
    except MaterialTextUnavailable as exc:
        messages.info(request, f"{exc} 本次仅保存原件，供下载。")
    except MaterialExtractionError as exc:
        form.add_error("file", str(exc))
        return render(request, "workbench/upload_error.html", {"form": form}, status=400)
    Material.objects.create(owner=request.user, file=uploaded, original_name=name,
                            category=form.cleaned_data["category"], size_bytes=uploaded.size,
                            extracted_text=extracted)
    messages.success(request, "原件已保存，可用于 AI 出题。" if extracted else "原件已保存。")
    return redirect("material_library")


@login_required
@require_POST
def categorize_material(request, material_id):
    material = get_object_or_404(Material, pk=material_id, owner=request.user)
    form = MaterialCategoryForm(request.POST, instance=material)
    if form.is_valid():
        material.save(update_fields=["category"])
        messages.success(request, "资料分类已保存。")
    else:
        messages.error(request, "分类最多 60 字。")
    return redirect("material_library")


@login_required
@require_GET
def download_material(request, material_id):
    material = get_object_or_404(Material, pk=material_id, owner=request.user)
    try:
        stream = material.file.open("rb")
    except FileNotFoundError as exc:
        raise Http404("文件不存在。") from exc
    response = FileResponse(stream, as_attachment=True, filename=material.original_name,
                            content_type="application/octet-stream")
    response["Cache-Control"] = "private, no-store"
    response["X-Content-Type-Options"] = "nosniff"
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
    if not material.extracted_text.strip():
        messages.error(request, "这份资料没有可用文字，请选择其他资料。")
        return redirect("worksheet_list")
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
    return _queue_worksheet(request, material, Worksheet.Mode.HOMEWORK, "", member_credential)


def _queue_worksheet(request, material, mode, instruction, member_credential):
    with transaction.atomic():
        worksheet = Worksheet.objects.create(
            owner=request.user, material=material, mode=mode, title=f"{mode.label}草稿",
        )
        task = GenerationTask.objects.create(
            owner=request.user, worksheet=worksheet, kind=GenerationTask.Kind.CREATE,
            instruction=instruction, member_mode=settings.AI_MEMBER_TASKS_ENABLED,
            member_credential=member_credential,
        )
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
