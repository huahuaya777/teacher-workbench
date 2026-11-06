"""Self-contained PostgreSQL/Redis distribution, isolated from the home-server stack."""
import os
from django.core.exceptions import ImproperlyConfigured
from docker.runtime import configure_environment

configure_environment()
from .settings import *  # noqa: E402,F403

DEBUG = False
PORTABLE_INSTALLATION = True
ROOT_URLCONF = "config.urls_container"
ALLOWED_HOSTS = ["localhost", "127.0.0.1"] + [
    host.strip() for host in os.getenv("TW_ALLOWED_HOSTS", "").split(",") if host.strip()
]
if "*" in ALLOWED_HOSTS:
    raise ImproperlyConfigured("TW_ALLOWED_HOSTS must list specific hostnames or IP addresses")
CSRF_TRUSTED_ORIGINS = [origin.strip() for origin in os.getenv("TW_TRUSTED_ORIGINS", "").split(",") if origin.strip()]
SESSION_COOKIE_SECURE = CSRF_COOKIE_SECURE = os.getenv("TW_HTTPS", "0") == "1"
SECURE_SSL_REDIRECT = SESSION_COOKIE_SECURE
SECURE_REDIRECT_EXEMPT = [r"^healthz/$"]
SECURE_HSTS_SECONDS = 31536000 if SESSION_COOKIE_SECURE else 0
SECURE_PROXY_SSL_HEADER = (("HTTP_X_FORWARDED_PROTO", "https")
                           if os.getenv("TW_TRUST_PROXY", "0") == "1" else None)
MIDDLEWARE = list(MIDDLEWARE)  # noqa: F405
MIDDLEWARE.insert(1, "whitenoise.middleware.WhiteNoiseMiddleware")
STORAGES = {
    "default": {"BACKEND": "django.core.files.storage.FileSystemStorage"},
    "staticfiles": {"BACKEND": "whitenoise.storage.CompressedStaticFilesStorage"},
}
