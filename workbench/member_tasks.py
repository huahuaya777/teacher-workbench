"""Member task execution seam. A caller must supply a reviewed provider function.

There is intentionally no default network sender here. The queue entry point
supplies the reviewed adapter only when the explicit member-task flag is on.
"""

from django.db import transaction
from django.utils import timezone

from .ai import AIResponseError, AIUnavailable, _validate_content, safe_member_error
from .call_gate import (CallGateDenied, abort_reserved_task, fail_unreserved_task, finish_attempt,
                        credential_fingerprint, mark_task_sent, reserve_task_call)
from .credential_vault import VaultIntegrityError, VaultUnavailable, unseal_key_for_owner
from .models import GenerationTask, ModelCredential, WorksheetVersion


def _reliable_usage(usage):
    if (isinstance(usage, tuple) and len(usage) == 2 and
            all(type(value) is int and value >= 0 for value in usage)):
        return usage
    return (None, None)


def _fail_running(task_id, message):
    GenerationTask.objects.filter(pk=task_id, status=GenerationTask.Status.RUNNING).update(
        status=GenerationTask.Status.FAILED, error_message=message, updated_at=timezone.now(),
    )


def process_member_task_offline(task_id, *, provider_call):
    """Exercise the guarded task lifecycle with an explicitly supplied sender.

    provider_call(source, previous, instruction, context, credential, secret)
    returns (content, (input_tokens, output_tokens) or None). Never pass a
    provider function sourced from a request or an untrusted file.
    """
    if not callable(provider_call):
        raise ValueError("成员任务没有经过核准的接口执行器。")
    task = GenerationTask.objects.select_related("worksheet__material").filter(pk=task_id).first()
    if not task or not task.member_mode or not task.member_credential_id:
        raise CallGateDenied("任务未绑定成员模型配置；没有调用模型。")
    previous = task.worksheet.versions.first()
    if task.kind == GenerationTask.Kind.REVISE and previous is None:
        GenerationTask.objects.filter(pk=task_id, status=GenerationTask.Status.QUEUED).update(
            status=GenerationTask.Status.FAILED, error_message="尚无可修改的草稿；没有调用模型。",
        )
        return False
    try:
        reserve_task_call(task_id, task.member_credential_id)
    except CallGateDenied:
        # A duplicate worker must not rewrite the first worker's task state.
        fail_unreserved_task(task_id)
        return False
    credential = ModelCredential.objects.filter(pk=task.member_credential_id, owner_id=task.owner_id).first()
    try:
        if credential is None:
            raise VaultIntegrityError("模型配置不可用。")
        secret = unseal_key_for_owner(credential, task.owner_id)
    except (VaultIntegrityError, VaultUnavailable):
        abort_reserved_task(task_id)
        return False
    context = task.worksheet.ai_teaching_context()
    try:
        marked = mark_task_sent(task_id, expected_fingerprint=credential_fingerprint(credential))
    except CallGateDenied:
        return False
    if not marked:
        return False
    try:
        result = provider_call(
            task.worksheet.material.extracted_text,
            previous.content if task.kind == GenerationTask.Kind.REVISE else None,
            task.instruction, context, credential, secret,
        )
        content, usage = result
        content = _validate_content(content)
    except (AIResponseError, AIUnavailable) as exc:
        finish_attempt(task_id, succeeded=False)
        _fail_running(task_id, safe_member_error(exc) + " 请求可能已发送，请核对厂商账单。")
        return False
    except Exception:
        # The request may have reached the provider. Never refund this attempt,
        # and never render exception text which might contain the key or prompt.
        finish_attempt(task_id, succeeded=False)
        _fail_running(task_id, "模型请求或结果处理失败；请核对厂商账单后再创建新任务。")
        return False
    input_tokens, output_tokens = _reliable_usage(usage)
    finish_attempt(task_id, succeeded=True, input_tokens=input_tokens, output_tokens=output_tokens)
    with transaction.atomic():
        current = GenerationTask.objects.select_for_update().select_related("worksheet").get(pk=task_id)
        if current.status != GenerationTask.Status.RUNNING:
            return False
        latest = current.worksheet.versions.first()
        WorksheetVersion.objects.create(
            worksheet=current.worksheet, number=(latest.number + 1 if latest else 1),
            content=content, change_request=current.instruction,
        )
        current.worksheet.title = content["title"]
        current.worksheet.save(update_fields=["title", "updated_at"])
        current.status = GenerationTask.Status.DONE
        current.save(update_fields=["status", "updated_at"])
    return True
