"""Small account lifecycle for the first few workbench members."""

import secrets

from django.contrib import messages
from django.contrib.auth import get_user_model
from django.contrib.auth.decorators import login_required, permission_required
from django.contrib.auth.mixins import LoginRequiredMixin
from django.contrib.auth.views import PasswordChangeView
from django.db import IntegrityError, transaction
from django.db.models import Q
from django.http import Http404
from django.shortcuts import get_object_or_404, redirect, render
from django.urls import reverse_lazy
from django.views.decorators.cache import never_cache
from django.views.decorators.http import require_http_methods, require_POST
from django.utils import timezone

from .forms import CallAllowanceForm, MemberCreateForm
from .models import CallAllowance, MemberAccess, MemberAudit


MANAGER_GRANT = (
    Q(user_permissions__codename="manage_members", user_permissions__content_type__app_label="workbench")
    | Q(groups__permissions__codename="manage_members", groups__permissions__content_type__app_label="workbench")
)


def _temporary_password():
    return secrets.token_urlsafe(18)


def _secret_response(request, username, password):
    response = render(request, "workbench/member_secret_once.html", {
        "username": username, "temporary_password": password,
    })
    response["Cache-Control"] = "private, no-store"
    response["Pragma"] = "no-cache"
    return response


@never_cache
@login_required
@permission_required("workbench.manage_members", raise_exception=True)
@require_http_methods(["GET", "POST"])
def member_list(request):
    form = MemberCreateForm(request.POST or None)
    if request.method == "POST" and form.is_valid():
        username = form.cleaned_data["username"]
        password = _temporary_password()
        try:
            with transaction.atomic():
                member = get_user_model().objects.create_user(username=username, password=password)
                MemberAccess.objects.create(user=member, must_change_password=True)
                MemberAudit.objects.create(actor=request.user, target=member, action=MemberAudit.Action.CREATE)
        except IntegrityError:
            form.add_error("username", "该用户名已存在，请换一个。")
        else:
            return _secret_response(request, username, password)
    members = (get_user_model().objects.filter(is_staff=False, is_superuser=False)
               .exclude(MANAGER_GRANT).distinct().order_by("username"))
    return render(request, "workbench/member_list.html", {"form": form, "members": members})


def _ordinary_member_locked(member_id):
    member = get_object_or_404(get_user_model().objects.select_for_update(), pk=member_id)
    if (member.is_staff or member.is_superuser or
            get_user_model().objects.filter(pk=member.pk).filter(MANAGER_GRANT).exists()):
        raise Http404
    return member


@never_cache
@login_required
@permission_required("workbench.manage_members", raise_exception=True)
@require_http_methods(["GET", "POST"])
def member_allowance(request, member_id):
    # No credential or private teaching data is loaded into this page.
    member = get_object_or_404(get_user_model(), pk=member_id)
    if (member.is_staff or member.is_superuser or
            get_user_model().objects.filter(pk=member.pk).filter(MANAGER_GRANT).exists()):
        raise Http404
    allowance = CallAllowance.objects.filter(owner=member).first()
    initial = {}
    if allowance:
        initial = {"max_calls": allowance.max_calls,
                   "valid_until": timezone.localtime(allowance.valid_until).strftime("%Y-%m-%dT%H:%M")}
    form = CallAllowanceForm(request.POST or None, initial=initial)
    if request.method == "POST" and form.is_valid():
        with transaction.atomic():
            member = _ordinary_member_locked(member_id)
            current = CallAllowance.objects.select_for_update().filter(owner=member).first()
            minimum = current.used_calls + current.reserved_calls if current else 0
            if form.cleaned_data["max_calls"] < minimum:
                form.add_error("max_calls", f"至少要保留已用和已预留的 {minimum} 次。")
            else:
                if current is None:
                    CallAllowance.objects.create(owner=member, max_calls=form.cleaned_data["max_calls"],
                                                 valid_until=form.cleaned_data["valid_until"])
                else:
                    current.max_calls = form.cleaned_data["max_calls"]
                    current.valid_until = form.cleaned_data["valid_until"]
                    current.save(update_fields=["max_calls", "valid_until", "updated_at"])
                MemberAudit.objects.create(actor=request.user, target=member,
                                           action=MemberAudit.Action.ALLOWANCE)
                messages.success(request, "调用次数与有效期已保存。成员主动发起的模型请求受此额度限制。")
                return redirect("member_allowance", member_id=member.pk)
    return render(request, "workbench/member_allowance.html", {
        "member": member, "allowance": allowance, "form": form,
    })


@login_required
@permission_required("workbench.manage_members", raise_exception=True)
@require_POST
def member_reset_password(request, member_id):
    with transaction.atomic():
        member = _ordinary_member_locked(member_id)
        if not member.is_active:
            messages.error(request, "账号已停用，请先重新启用。")
            return redirect("member_list")
        password = _temporary_password()
        member.set_password(password)
        member.save(update_fields=["password"])
        access, _ = MemberAccess.objects.get_or_create(user=member)
        access.must_change_password = True
        access.save(update_fields=["must_change_password", "updated_at"])
        MemberAudit.objects.create(actor=request.user, target=member, action=MemberAudit.Action.RESET)
    return _secret_response(request, member.username, password)


@login_required
@permission_required("workbench.manage_members", raise_exception=True)
@require_POST
def member_deactivate(request, member_id):
    with transaction.atomic():
        member = _ordinary_member_locked(member_id)
        if member.is_active:
            member.is_active = False
            member.save(update_fields=["is_active"])
            MemberAudit.objects.create(actor=request.user, target=member, action=MemberAudit.Action.DEACTIVATE)
    messages.info(request, "账号已停用，已有资料保留。")
    return redirect("member_list")


@login_required
@permission_required("workbench.manage_members", raise_exception=True)
@require_POST
def member_reactivate(request, member_id):
    with transaction.atomic():
        member = _ordinary_member_locked(member_id)
        if member.is_active:
            messages.error(request, "账号已启用。")
            return redirect("member_list")
        password = _temporary_password()
        member.set_password(password)
        member.is_active = True
        member.save(update_fields=["password", "is_active"])
        access, _ = MemberAccess.objects.get_or_create(user=member)
        access.must_change_password = True
        access.save(update_fields=["must_change_password", "updated_at"])
        MemberAudit.objects.create(actor=request.user, target=member, action=MemberAudit.Action.REACTIVATE)
    return _secret_response(request, member.username, password)


class MemberPasswordChangeView(LoginRequiredMixin, PasswordChangeView):
    template_name = "workbench/member_change_password.html"
    success_url = reverse_lazy("dashboard")

    def form_valid(self, form):
        response = super().form_valid(form)
        MemberAccess.objects.filter(user=self.request.user).update(must_change_password=False)
        MemberAudit.objects.create(actor=self.request.user, target=self.request.user,
                                   action=MemberAudit.Action.CHANGE_PASSWORD)
        messages.success(self.request, "密码已修改，可以开始使用工作台。")
        return response
