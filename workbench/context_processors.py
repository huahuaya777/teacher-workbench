from django.conf import settings
from .models import TeacherProfile


def workbench_profile(request):
    return {
        "teacher_profile": (TeacherProfile.objects.filter(owner=request.user).first()
                            if request.user.is_authenticated else None),
        "portable_installation": getattr(settings, "PORTABLE_INSTALLATION", False),
    }
