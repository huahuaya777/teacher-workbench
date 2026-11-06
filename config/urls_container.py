import os
from pathlib import Path
from django.db import connection
from django.http import JsonResponse
from django.urls import path
from redis import Redis
from .urls import urlpatterns as base_patterns


def health(request):
    try:
        pids = Path("/tmp/workbench-ready").read_text().split()
        if len(pids) != 4:
            raise RuntimeError("Not ready")
        for pid in pids:
            os.kill(int(pid), 0)
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
            cursor.fetchone()
        Redis(host="127.0.0.1", socket_connect_timeout=1, socket_timeout=1).ping()
    except Exception:
        return JsonResponse({"status": "unavailable"}, status=503)
    return JsonResponse({"status": "ok"})


urlpatterns = [path("healthz/", health)] + base_patterns
