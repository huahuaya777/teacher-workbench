from pathlib import Path
import re

from django import forms
from django.contrib.auth import get_user_model
from django.utils import timezone
from .models import ModelCredential, TeacherProfile
from .credential_vault import CredentialInvalid, normalize_qwen_config

MAX_UPLOAD_BYTES = 15 * 1024 * 1024


class TeacherProfileForm(forms.ModelForm):
    class Meta:
        model = TeacherProfile
        fields = ["workbench_name", "subject", "textbook_edition", "grade"]
        labels = {
            "workbench_name": "工作台名称",
            "subject": "任教学科",
            "textbook_edition": "教材版本",
            "grade": "年级",
        }
        widgets = {
            "workbench_name": forms.TextInput(attrs={"placeholder": "例如：华华的教学工作台"}),
            "subject": forms.TextInput(attrs={"placeholder": "例如：数学"}),
            "textbook_edition": forms.TextInput(attrs={"placeholder": "例如：人教版"}),
            "grade": forms.TextInput(attrs={"placeholder": "例如：九年级"}),
        }


class MaterialUploadForm(forms.Form):
    file = forms.FileField(label="选择 Word 或 PDF 资料")

    def clean_file(self):
        uploaded = self.cleaned_data["file"]
        suffix = Path(uploaded.name).suffix.lower()
        if suffix not in {".docx", ".pdf"}:
            raise forms.ValidationError("当前验证版只支持 .docx 和 .pdf 文件。")
        if uploaded.size > MAX_UPLOAD_BYTES:
            raise forms.ValidationError("文件超过 15 MB 限制。")
        if uploaded.size == 0:
            raise forms.ValidationError("不能上传空文件。")
        return uploaded


class RevisionForm(forms.Form):
    instruction = forms.CharField(label="希望怎样修改", max_length=2000, widget=forms.Textarea(attrs={"rows": 3}))

    def __init__(self, *args, owner=None, member_mode=False, **kwargs):
        super().__init__(*args, **kwargs)
        if member_mode:
            self.fields["credential"] = forms.ModelChoiceField(
                label="使用我的模型配置",
                queryset=ModelCredential.objects.filter(owner=owner).order_by("label") if owner else
                         ModelCredential.objects.none(),
                empty_label="请选择模型配置",
            )


class MemberModelSelectionForm(forms.Form):
    credential = forms.ModelChoiceField(label="使用我的模型配置",
                                        queryset=ModelCredential.objects.none(),
                                        empty_label="请选择模型配置")

    def __init__(self, *args, owner=None, **kwargs):
        super().__init__(*args, **kwargs)
        if owner:
            self.fields["credential"].queryset = ModelCredential.objects.filter(owner=owner).order_by("label")


class MemberCreateForm(forms.Form):
    username = forms.CharField(label="登录用户名", min_length=3, max_length=32,
                               help_text="只能使用小写英文字母、数字和下划线；以字母开头。")

    def clean_username(self):
        username = self.cleaned_data["username"].strip()
        if not re.fullmatch(r"[a-z][a-z0-9_]{2,31}", username):
            raise forms.ValidationError("用户名须为 3～32 位小写字母、数字或下划线，并以字母开头。")
        if get_user_model().objects.filter(username__iexact=username).exists():
            raise forms.ValidationError("该用户名已存在。")
        return username


class CallAllowanceForm(forms.Form):
    max_calls = forms.IntegerField(label="累计允许调用次数", min_value=0, max_value=10000)
    valid_until = forms.DateTimeField(
        label="有效期截止", widget=forms.DateTimeInput(attrs={"type": "datetime-local"},
                                                 format="%Y-%m-%dT%H:%M"),
        input_formats=["%Y-%m-%dT%H:%M"],
    )

    def clean_valid_until(self):
        value = self.cleaned_data["valid_until"]
        if value <= timezone.now():
            raise forms.ValidationError("截止时间须晚于现在。")
        return value


class ModelCredentialCreateForm(forms.Form):
    label = forms.CharField(label="配置名称", max_length=60,
                            widget=forms.TextInput(attrs={"placeholder": "例如：我的百炼账号"}))
    api_base_url = forms.CharField(label="百炼北京 Base URL", max_length=255,
                                   widget=forms.URLInput(attrs={"placeholder": "https://dashscope.aliyuncs.com/compatible-mode/v1"}))
    model_name = forms.ChoiceField(label="模型", choices=[("qwen-flash", "qwen-flash")])
    api_key = forms.CharField(label="API Key", min_length=8, max_length=512, strip=False,
                              widget=forms.PasswordInput(render_value=False, attrs={"autocomplete": "new-password"}))

    def clean(self):
        cleaned = super().clean()
        if "api_base_url" in cleaned and "model_name" in cleaned:
            try:
                cleaned["api_base_url"] = normalize_qwen_config(cleaned["api_base_url"], cleaned["model_name"])
            except CredentialInvalid as exc:
                self.add_error("api_base_url", str(exc))
        return cleaned


class ModelCredentialReplaceForm(forms.Form):
    api_key = forms.CharField(label="新的 API Key", min_length=8, max_length=512, strip=False,
                              widget=forms.PasswordInput(render_value=False, attrs={"autocomplete": "new-password"}))
