"""Local, fail-closed request-count guard. No key is read and no API is called here.

The guarded member worker reserves, loads its owner's credential, marks sent
immediately before the network request, then finishes. Once marked sent, the
call stays counted even if the result is unknown.
"""

import hashlib
from datetime import timedelta

from django.contrib.auth import get_user_model
from django.db import transaction
from django.utils import timezone

from .credential_vault import CredentialInvalid, normalize_qwen_config
from .models import CallAllowance, CallAttempt, GenerationTask, MemberAccess, ModelCredential


class CallGateDenied(ValueError):
    pass


def _member_ready(owner_id):
    user = get_user_model().objects.select_for_update().filter(pk=owner_id).first()
    access = MemberAccess.objects.select_for_update().filter(user_id=owner_id).first()
    return bool(user and user.is_active and not (access and access.must_change_password))


def _release_reserved(attempt, allowance, at):
    if attempt.status != CallAttempt.Status.RESERVED:
        return False
    allowance.reserved_calls -= 1
    allowance.save(update_fields=["reserved_calls", "updated_at"])
    attempt.status = CallAttempt.Status.RELEASED
    attempt.finished_at = at
    attempt.save(update_fields=["status", "finished_at"])
    return True


def _credential_ready(credential, owner_id):
    if not credential or credential.owner_id != owner_id:
        return False
    try:
        normalize_qwen_config(credential.api_base_url, credential.model_name)
    except CredentialInvalid:
        return False
    return (credential.provider == ModelCredential.Provider.QWEN and
            len(credential.key_nonce) == 12 and bool(credential.key_ciphertext) and
            credential.key_version >= 1)


def credential_fingerprint(credential):
    """Bind the secret loaded by a worker to the encrypted row checked at send."""
    digest = hashlib.sha256()
    for field in (str(credential.pk), str(credential.owner_id), credential.provider,
                  credential.api_base_url, credential.model_name, str(credential.key_version)):
        digest.update(field.encode("utf-8") + b"\0")
    digest.update(bytes(credential.key_nonce) + b"\0" + bytes(credential.key_ciphertext))
    return digest.digest()


@transaction.atomic
def reserve_task_call(task_id, credential_id, *, at=None):
    """Reserve one of a member's calls; duplicate task authorization is denied."""
    at = at or timezone.now()
    task = GenerationTask.objects.select_for_update().select_related("worksheet__material").filter(pk=task_id).first()
    if not task or task.status != GenerationTask.Status.QUEUED or not task.member_mode:
        raise CallGateDenied("任务不在待处理状态；没有发送模型请求。")
    if not task.member_credential_id or task.member_credential_id != credential_id:
        raise CallGateDenied("任务未绑定该成员的模型配置；没有发送模型请求。")
    if (task.owner_id != task.worksheet.owner_id or
            task.owner_id != task.worksheet.material.owner_id or
            not _member_ready(task.owner_id)):
        raise CallGateDenied("成员或资料不可用；没有发送模型请求。")
    if CallAttempt.objects.filter(task_id=task_id).exists():
        raise CallGateDenied("该任务已有调用记录；不会重复发送。")
    credential = ModelCredential.objects.select_for_update().filter(
        pk=credential_id, owner_id=task.owner_id,
    ).first()
    if not _credential_ready(credential, task.owner_id):
        raise CallGateDenied("模型配置不可用；没有发送模型请求。")
    allowance = CallAllowance.objects.select_for_update().filter(owner_id=task.owner_id).first()
    if not allowance or allowance.valid_until <= at or (
        allowance.used_calls + allowance.reserved_calls >= allowance.max_calls
    ):
        raise CallGateDenied("调用次数额度已用完或过期；没有发送模型请求。")
    allowance.reserved_calls += 1
    allowance.save(update_fields=["reserved_calls", "updated_at"])
    return CallAttempt.objects.create(
        task=task, owner_id=task.owner_id, credential=credential, allowance=allowance,
        provider=credential.provider, model_name=credential.model_name,
        allowance_limit_at_reserve=allowance.max_calls,
        allowance_valid_until_at_reserve=allowance.valid_until,
    )


@transaction.atomic
def mark_task_sent(task_id, *, expected_fingerprint, at=None):
    """Commit a reserved slot before attempting I/O; never refund it afterward."""
    at = at or timezone.now()
    task = GenerationTask.objects.select_for_update().select_related("worksheet__material").filter(pk=task_id).first()
    if not task:
        raise CallGateDenied("任务不存在；没有发送模型请求。")
    attempt = CallAttempt.objects.select_for_update().filter(task_id=task_id).first()
    if not attempt or attempt.status != CallAttempt.Status.RESERVED:
        raise CallGateDenied("任务没有可用的调用预留；没有发送模型请求。")
    member_ready = _member_ready(attempt.owner_id)
    allowance = CallAllowance.objects.select_for_update().filter(pk=attempt.allowance_id,
                                                                  owner_id=attempt.owner_id).first()
    if not allowance:
        raise CallGateDenied("调用次数配置缺失；没有发送模型请求。")
    credential = (ModelCredential.objects.select_for_update().filter(pk=attempt.credential_id).first()
                  if attempt.credential_id else None)
    if (task.status != GenerationTask.Status.QUEUED or
            not task.member_mode or
            task.member_credential_id != attempt.credential_id or
            task.owner_id != attempt.owner_id or
            task.worksheet.owner_id != attempt.owner_id or
            task.worksheet.material.owner_id != attempt.owner_id or
            not member_ready or
            allowance.valid_until <= at or
            not _credential_ready(credential, attempt.owner_id) or
            credential_fingerprint(credential) != expected_fingerprint or
            credential.provider != attempt.provider or
            credential.model_name != attempt.model_name):
        _release_reserved(attempt, allowance, at)
        if task.status == GenerationTask.Status.QUEUED:
            task.status = GenerationTask.Status.CANCELLED
            task.save(update_fields=["status", "updated_at"])
        return False
    allowance.reserved_calls -= 1
    allowance.used_calls += 1
    allowance.save(update_fields=["reserved_calls", "used_calls", "updated_at"])
    attempt.status = CallAttempt.Status.SENT
    attempt.sent_at = at
    attempt.save(update_fields=["status", "sent_at"])
    task.status = GenerationTask.Status.RUNNING
    task.save(update_fields=["status", "updated_at"])
    return True


@transaction.atomic
def cancel_queued_task(task_id, owner_id, *, at=None):
    """A queued task can be cancelled and its unsent reservation released."""
    at = at or timezone.now()
    task = GenerationTask.objects.select_for_update().filter(pk=task_id, owner_id=owner_id).first()
    if not task or task.status != GenerationTask.Status.QUEUED:
        return False
    attempt = CallAttempt.objects.select_for_update().filter(task_id=task_id).first()
    if attempt:
        allowance = CallAllowance.objects.select_for_update().get(pk=attempt.allowance_id, owner_id=owner_id)
        if not _release_reserved(attempt, allowance, at):
            return False
    task.status = GenerationTask.Status.CANCELLED
    task.save(update_fields=["status", "updated_at"])
    return True


@transaction.atomic
def abort_reserved_task(task_id, *, message="模型配置在发送前不可用；没有调用模型。", at=None):
    """Fail a reserved task before network I/O and release its call slot."""
    at = at or timezone.now()
    task = GenerationTask.objects.select_for_update().filter(pk=task_id).first()
    attempt = CallAttempt.objects.select_for_update().filter(task_id=task_id).first()
    if not task or not attempt or task.status != GenerationTask.Status.QUEUED or attempt.status != CallAttempt.Status.RESERVED:
        return False
    allowance = CallAllowance.objects.select_for_update().get(pk=attempt.allowance_id,
                                                               owner_id=attempt.owner_id)
    _release_reserved(attempt, allowance, at)
    task.status = GenerationTask.Status.FAILED
    task.error_message = message
    task.save(update_fields=["status", "error_message", "updated_at"])
    return True


@transaction.atomic
def fail_unreserved_task(task_id):
    """Show a safe failure only when no other worker reserved this task."""
    task = GenerationTask.objects.select_for_update().filter(pk=task_id).first()
    if (not task or task.status != GenerationTask.Status.QUEUED or
            CallAttempt.objects.filter(task_id=task_id).exists()):
        return False
    task.status = GenerationTask.Status.FAILED
    task.error_message = "模型配置或调用次数不可用；没有发送模型请求。"
    task.save(update_fields=["status", "error_message", "updated_at"])
    return True


@transaction.atomic
def reclaim_stale_reservation(task_id, *, at=None, min_age=timedelta(minutes=10)):
    """Release a long-abandoned unsent reservation; a late worker cannot send."""
    if min_age < timedelta(minutes=10):
        raise ValueError("预留清理须至少等待 10 分钟。")
    at = at or timezone.now()
    task = GenerationTask.objects.select_for_update().filter(pk=task_id).first()
    attempt = CallAttempt.objects.select_for_update().filter(task_id=task_id).first()
    if (not task or not attempt or attempt.status != CallAttempt.Status.RESERVED or
            attempt.reserved_at > at - min_age):
        return False
    allowance = CallAllowance.objects.select_for_update().get(pk=attempt.allowance_id,
                                                               owner_id=attempt.owner_id)
    _release_reserved(attempt, allowance, at)
    if task.status == GenerationTask.Status.QUEUED:
        task.status = GenerationTask.Status.FAILED
        task.error_message = "调用预留超时，未发送模型请求；请新建任务。"
        task.save(update_fields=["status", "error_message", "updated_at"])
    return True


@transaction.atomic
def reconcile_stale_post_send_task(task_id, *, at=None, min_age=timedelta(minutes=10)):
    """Stop a stranded sent task without refunding or retrying its request."""
    if min_age < timedelta(minutes=10):
        raise ValueError("发送后清理须至少等待 10 分钟。")
    at = at or timezone.now()
    task = GenerationTask.objects.select_for_update().filter(pk=task_id).first()
    attempt = CallAttempt.objects.select_for_update().filter(task_id=task_id).first()
    if not task or not attempt or task.status != GenerationTask.Status.RUNNING:
        return False
    when = attempt.sent_at if attempt.status == CallAttempt.Status.SENT else attempt.finished_at
    if attempt.status not in (CallAttempt.Status.SENT, CallAttempt.Status.COMPLETED,
                              CallAttempt.Status.UNKNOWN) or not when or when > at - min_age:
        return False
    if attempt.status == CallAttempt.Status.SENT:
        attempt.status = CallAttempt.Status.UNKNOWN
        attempt.finished_at = at
        attempt.save(update_fields=["status", "finished_at"])
    task.status = GenerationTask.Status.FAILED
    task.error_message = "模型请求结果未能保存；调用次数已计入，请核对厂商账单后新建任务。"
    task.save(update_fields=["status", "error_message", "updated_at"])
    return True


@transaction.atomic
def finish_attempt(task_id, *, succeeded, input_tokens=None, output_tokens=None, at=None):
    """Record reliable provider usage only; a post-send failure remains counted."""
    if (input_tokens is None) != (output_tokens is None) or any(
        type(value) is not int or value < 0 for value in (input_tokens, output_tokens) if value is not None
    ):
        raise ValueError("用量须为完整的非负整数，或标记为未知。")
    attempt = CallAttempt.objects.select_for_update().filter(task_id=task_id).first()
    if not attempt or attempt.status != CallAttempt.Status.SENT:
        raise CallGateDenied("没有可结算的已发送调用。")
    attempt.status = CallAttempt.Status.COMPLETED if succeeded else CallAttempt.Status.UNKNOWN
    attempt.finished_at = at or timezone.now()
    attempt.input_tokens = input_tokens
    attempt.output_tokens = output_tokens
    attempt.save(update_fields=["status", "finished_at", "input_tokens", "output_tokens"])
    return attempt
