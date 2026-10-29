from .models import TeacherProfile


def workbench_profile(request):
    if not request.user.is_authenticated:
        return {"teacher_profile": None}
    return {"teacher_profile": TeacherProfile.objects.filter(owner=request.user).first()}
