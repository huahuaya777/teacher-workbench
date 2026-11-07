import uuid
from pathlib import Path

from django.conf import settings
from django.core.validators import FileExtensionValidator
from django.db import models

MATERIAL_EXTENSIONS = ("docx", "pdf", "pptx", "doc", "ppt", "enbx", "png", "jpg", "jpeg")


def private_upload_path(instance, filename):
    suffix = Path(filename).suffix.lower()
    return f"materials/{instance.owner_id}/{uuid.uuid4().hex}{suffix}"


class TeacherProfile(models.Model):
    owner = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="teacher_profile")
    workbench_name = models.CharField(max_length=80, blank=True)
    subject = models.CharField(max_length=40, blank=True)
    textbook_edition = models.CharField(max_length=80, blank=True)
    grade = models.CharField(max_length=40, blank=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.workbench_name or f"{self.owner.username} 的教学档案"


class MemberAccess(models.Model):
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="member_access")
    must_change_password = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        permissions = [("manage_members", "Can manage member accounts")]


class MemberAudit(models.Model):
    class Action(models.TextChoices):
        CREATE = "create", "创建账号"
        RESET = "reset", "重置密码"
        DEACTIVATE = "deactivate", "停用账号"
        REACTIVATE = "reactivate", "重新启用"
        CHANGE_PASSWORD = "change_password", "本人修改密码"
        ALLOWANCE = "allowance", "设置调用次数"

    actor = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, on_delete=models.SET_NULL,
                              related_name="member_actions_performed")
    target = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, on_delete=models.SET_NULL,
                               related_name="member_actions_received")
    action = models.CharField(max_length=20, choices=Action.choices)
    created_at = models.DateTimeField(auto_now_add=True)


class ModelCredential(models.Model):
    """Encrypted provider credential; plaintext never belongs in a model field."""

    class Provider(models.TextChoices):
        QWEN = "qwen", "百炼（北京）"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    owner = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                              related_name="model_credentials")
    label = models.CharField(max_length=60)
    provider = models.CharField(max_length=20, choices=Provider.choices)
    api_base_url = models.CharField(max_length=255)
    model_name = models.CharField(max_length=80)
    key_ciphertext = models.BinaryField()
    key_nonce = models.BinaryField()
    key_version = models.PositiveIntegerField()
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["owner", "label"], name="unique_owner_model_label")]

    def __str__(self):
        return self.label


class Material(models.Model):
    owner = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="materials")
    file = models.FileField(upload_to=private_upload_path, validators=[FileExtensionValidator(MATERIAL_EXTENSIONS)])
    original_name = models.CharField(max_length=255)
    category = models.CharField(max_length=60, blank=True, db_default="")
    size_bytes = models.PositiveBigIntegerField()
    extracted_text = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return self.original_name


class Worksheet(models.Model):
    class Mode(models.TextChoices):
        HOMEWORK = "homework", "作业"
        EXAM = "exam", "试卷"

    owner = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="worksheets")
    material = models.ForeignKey(Material, on_delete=models.PROTECT, related_name="worksheets")
    title = models.CharField(max_length=200, default="作业草稿")
    mode = models.CharField(max_length=8, choices=Mode.choices, default=Mode.HOMEWORK, db_default=Mode.HOMEWORK)
    final_version = models.ForeignKey("WorksheetVersion", null=True, blank=True,
                                      on_delete=models.SET_NULL, related_name="+")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-updated_at"]

    def ai_teaching_context(self):
        context = TeacherProfile.objects.filter(owner_id=self.owner_id).values(
            "subject", "grade", "textbook_edition",
        ).first()
        if self.mode == self.Mode.EXAM:
            return {**(context or {}), "worksheet_mode": self.Mode.EXAM}
        return context


class WorksheetVersion(models.Model):
    worksheet = models.ForeignKey(Worksheet, on_delete=models.CASCADE, related_name="versions")
    number = models.PositiveIntegerField()
    content = models.JSONField()
    change_request = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-number"]
        constraints = [models.UniqueConstraint(fields=["worksheet", "number"], name="unique_worksheet_version")]


class GenerationTask(models.Model):
    class Kind(models.TextChoices):
        CREATE = "create", "生成"
        REVISE = "revise", "修改"

    class Status(models.TextChoices):
        QUEUED = "queued", "排队中"
        RUNNING = "running", "处理中"
        DONE = "done", "已完成"
        FAILED = "failed", "失败"
        CANCELLED = "cancelled", "已取消"

    owner = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="generation_tasks")
    worksheet = models.ForeignKey(Worksheet, on_delete=models.CASCADE, related_name="tasks")
    member_mode = models.BooleanField(default=False)
    member_credential = models.ForeignKey(ModelCredential, null=True, blank=True,
                                          on_delete=models.SET_NULL, related_name="generation_tasks")
    kind = models.CharField(max_length=10, choices=Kind.choices)
    status = models.CharField(max_length=12, choices=Status.choices, default=Status.QUEUED)
    instruction = models.TextField(blank=True)
    error_message = models.CharField(max_length=300, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]


class CallAllowance(models.Model):
    """Per-member request-count guard; this is not a currency balance."""

    owner = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.PROTECT,
                                 related_name="call_allowance")
    max_calls = models.PositiveIntegerField()
    reserved_calls = models.PositiveIntegerField(default=0)
    used_calls = models.PositiveIntegerField(default=0)
    valid_until = models.DateTimeField()
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        constraints = [models.CheckConstraint(
            condition=models.Q(max_calls__gte=models.F("reserved_calls") + models.F("used_calls")),
            name="call_allowance_within_limit",
        )]


class CallAttempt(models.Model):
    """One task may authorize at most one provider request."""

    class Status(models.TextChoices):
        RESERVED = "reserved", "已预留"
        RELEASED = "released", "未发送已释放"
        SENT = "sent", "已标记发送"
        COMPLETED = "completed", "已完成"
        UNKNOWN = "unknown", "发送后结果未知"

    task = models.OneToOneField(GenerationTask, on_delete=models.PROTECT,
                                related_name="call_attempt")
    owner = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT,
                              related_name="call_attempts")
    allowance = models.ForeignKey(CallAllowance, on_delete=models.PROTECT,
                                  related_name="attempts")
    credential = models.ForeignKey(ModelCredential, null=True, on_delete=models.SET_NULL,
                                   related_name="call_attempts")
    provider = models.CharField(max_length=20)
    model_name = models.CharField(max_length=80)
    allowance_limit_at_reserve = models.PositiveIntegerField()
    allowance_valid_until_at_reserve = models.DateTimeField()
    status = models.CharField(max_length=12, choices=Status.choices, default=Status.RESERVED)
    reserved_at = models.DateTimeField(auto_now_add=True)
    sent_at = models.DateTimeField(null=True, blank=True)
    finished_at = models.DateTimeField(null=True, blank=True)
    input_tokens = models.PositiveIntegerField(null=True, blank=True)
    output_tokens = models.PositiveIntegerField(null=True, blank=True)

    class Meta:
        indexes = [models.Index(fields=["owner", "reserved_at"], name="call_attempt_owner_time")]
