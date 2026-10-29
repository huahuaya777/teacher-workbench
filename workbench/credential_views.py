"""Owner-only metadata and secret replacement; no model calls or key display."""

from django.contrib import messages
from django.contrib.auth import get_user_model
from django.contrib.auth.decorators import login_required, permission_required
from django.db import IntegrityError, transaction
from django.shortcuts import get_object_or_404, redirect, render
from django.views.decorators.cache import never_cache
from django.views.decorators.http import require_http_methods, require_POST

from .credential_vault import CredentialInvalid, VaultUnavailable, seal_key, vault_ready
from .forms import ModelCredentialCreateForm, ModelCredentialReplaceForm
from .models import ModelCredential
from .member_views import MANAGER_GRANT


@never_cache
@login_required
@require_http_methods(["GET", "POST"])
def credential_list(request):
    ready = vault_ready()
    form = ModelCredentialCreateForm(request.POST or None)
    if request.method == "POST":
        if not ready:
            form.add_error(None, "服务端密钥保管尚未配置，暂不能保存。")
        elif form.is_valid():
            credential = ModelCredential(
                owner=request.user, label=form.cleaned_data["label"], provider=ModelCredential.Provider.QWEN,
                api_base_url=form.cleaned_data["api_base_url"], model_name=form.cleaned_data["model_name"],
            )
            try:
                with transaction.atomic():
                    seal_key(credential, form.cleaned_data["api_key"])
                    credential.save()
            except IntegrityError:
                form.add_error("label", "已有同名配置。")
            except (CredentialInvalid, VaultUnavailable):
                form.add_error(None, "配置未保存；请核对地址、Key 和服务端密钥保管状态。")
            else:
                messages.success(request, "模型配置已保存；尚未启用模型调用。")
                return redirect("credential_list")
    credentials = ModelCredential.objects.filter(owner=request.user).order_by("label")
    return render(request, "workbench/credential_list.html", {
        "form": form, "credentials": credentials, "vault_ready": ready,
    })


@never_cache
@login_required
@require_POST
def credential_replace(request, credential_id):
    credential = get_object_or_404(ModelCredential, pk=credential_id, owner=request.user)
    form = ModelCredentialReplaceForm(request.POST)
    if not form.is_valid() or not vault_ready():
        messages.error(request, "新 Key 未保存；请检查输入或服务端密钥保管状态。")
        return redirect("credential_list")
    try:
        with transaction.atomic():
            seal_key(credential, form.cleaned_data["api_key"])
            credential.save(update_fields=["key_ciphertext", "key_nonce", "key_version", "updated_at"])
    except (CredentialInvalid, VaultUnavailable):
        messages.error(request, "新 Key 未保存；请检查输入或服务端密钥保管状态。")
    else:
        messages.success(request, "API Key 已替换；旧 Key 不再保存在此配置中。")
    return redirect("credential_list")


@never_cache
@login_required
@require_POST
def credential_delete(request, credential_id):
    credential = get_object_or_404(ModelCredential, pk=credential_id, owner=request.user)
    credential.delete()
    messages.success(request, "模型配置已删除。")
    return redirect("credential_list")


@never_cache
@login_required
@permission_required("workbench.manage_members", raise_exception=True)
@require_http_methods(["GET", "POST"])
def credential_preconfigure(request, member_id):
    """Manager can create for an ordinary member, but cannot view stored keys."""
    member = get_object_or_404(
        get_user_model().objects.filter(is_staff=False, is_superuser=False).exclude(MANAGER_GRANT),
        pk=member_id,
    )
    ready = vault_ready()
    form = ModelCredentialCreateForm(request.POST or None)
    if request.method == "POST":
        if not ready:
            form.add_error(None, "服务端密钥保管尚未配置，暂不能保存。")
        elif not member.is_active:
            form.add_error(None, "账号已停用，不能预配。")
        elif form.is_valid():
            credential = ModelCredential(
                owner=member, label=form.cleaned_data["label"], provider=ModelCredential.Provider.QWEN,
                api_base_url=form.cleaned_data["api_base_url"], model_name=form.cleaned_data["model_name"],
            )
            try:
                with transaction.atomic():
                    seal_key(credential, form.cleaned_data["api_key"])
                    credential.save()
            except IntegrityError:
                form.add_error("label", "该成员已有同名配置。")
            except (CredentialInvalid, VaultUnavailable):
                form.add_error(None, "配置未保存；请核对地址、Key 和服务端密钥保管状态。")
            else:
                messages.success(request, "已为该成员保存模型配置；管理员不能查看已存 Key。")
                return redirect("member_list")
    return render(request, "workbench/credential_preconfigure.html", {
        "form": form, "member": member, "vault_ready": ready,
    })
