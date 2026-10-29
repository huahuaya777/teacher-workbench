"""Require a member's first password change before any workbench action."""

from django.shortcuts import redirect
from django.urls import reverse

from .models import MemberAccess


class ForcePasswordChangeMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        if request.user.is_authenticated:
            required = MemberAccess.objects.filter(user_id=request.user.pk, must_change_password=True).exists()
            if required and request.path_info not in {
                reverse("member_change_password"), reverse("logout"), reverse("login"),
            }:
                return redirect("member_change_password")
        return self.get_response(request)
