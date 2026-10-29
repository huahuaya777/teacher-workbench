from django.conf import settings
from django.db import transaction

from .ai import AIResponseError, AIUnavailable, request_member_worksheet, request_worksheet
from .member_tasks import process_member_task_offline
from .models import GenerationTask, TeacherProfile, WorksheetVersion


def process_generation_task(task_id):
    with transaction.atomic():
        task = GenerationTask.objects.select_for_update().select_related("worksheet__material").get(pk=task_id)
        if task.status != GenerationTask.Status.QUEUED:
            return
        if task.member_mode:
            task.status = GenerationTask.Status.FAILED
            task.error_message = "成员模型任务须走独立额度闸门；没有调用模型。"
            task.save(update_fields=["status", "error_message", "updated_at"])
            return
        if settings.AI_MEMBER_TASKS_ENABLED:
            task.status = GenerationTask.Status.FAILED
            task.error_message = "成员模式启用后，旧进程级任务不会调用模型。"
            task.save(update_fields=["status", "error_message", "updated_at"])
            return
        if task.owner_id != task.worksheet.owner_id or task.owner_id != task.worksheet.material.owner_id:
            task.status = GenerationTask.Status.FAILED
            task.error_message = "资料归属不一致。"
            task.save(update_fields=["status", "error_message", "updated_at"])
            return
        task.status = GenerationTask.Status.RUNNING
        task.save(update_fields=["status", "updated_at"])
        previous = task.worksheet.versions.first()
        previous_content = previous.content if task.kind == GenerationTask.Kind.REVISE and previous else None
        if task.kind == GenerationTask.Kind.REVISE and previous_content is None:
            task.status = GenerationTask.Status.FAILED
            task.error_message = "尚无可修改的草稿。"
            task.save(update_fields=["status", "error_message", "updated_at"])
            return
        source = task.worksheet.material.extracted_text
        instruction = task.instruction
        teaching_context = TeacherProfile.objects.filter(owner_id=task.owner_id).values(
            "subject", "grade", "textbook_edition"
        ).first()
    try:
        content = request_worksheet(source, previous_content, instruction, teaching_context)
    except (AIUnavailable, AIResponseError) as exc:
        GenerationTask.objects.filter(pk=task_id, status=GenerationTask.Status.RUNNING).update(
            status=GenerationTask.Status.FAILED, error_message=str(exc))
        return
    except Exception:
        GenerationTask.objects.filter(pk=task_id, status=GenerationTask.Status.RUNNING).update(
            status=GenerationTask.Status.FAILED, error_message="生成过程出错，请联系管理员检查任务环境。")
        return
    with transaction.atomic():
        task = GenerationTask.objects.select_for_update().select_related("worksheet").get(pk=task_id)
        if task.status != GenerationTask.Status.RUNNING:
            return
        latest = task.worksheet.versions.first()
        WorksheetVersion.objects.create(
            worksheet=task.worksheet, number=(latest.number + 1 if latest else 1),
            content=content, change_request=instruction,
        )
        task.worksheet.title = content["title"]
        task.worksheet.save(update_fields=["title", "updated_at"])
        task.status = GenerationTask.Status.DONE
        task.save(update_fields=["status", "updated_at"])


def process_member_generation_task(task_id):
    """Queue entry point. An explicit runtime flag is required for paid calls."""
    if not settings.AI_MEMBER_TASKS_ENABLED:
        return False
    return process_member_task_offline(task_id, provider_call=request_member_worksheet)
