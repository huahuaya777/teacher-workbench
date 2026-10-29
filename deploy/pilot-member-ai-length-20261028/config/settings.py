"""Settings for the local validation app; production requires explicit secrets."""

import os
from pathlib import Path
from django.core.exceptions import ImproperlyConfigured

BASE_DIR = Path(__file__).resolve().parent.parent
DEBUG = os.getenv("DJANGO_DEBUG", "0") == "1"
SECRET_KEY = os.getenv("DJANGO_SECRET_KEY", "")
if not SECRET_KEY:
    if DEBUG:
        SECRET_KEY = "development-only-change-before-deployment"
    else:
        raise ImproperlyConfigured("DJANGO_SECRET_KEY is required when DJANGO_DEBUG=0")

ALLOWED_HOSTS = [x.strip() for x in os.getenv("DJANGO_ALLOWED_HOSTS", "localhost,127.0.0.1,testserver").split(",") if x.strip()]
CSRF_TRUSTED_ORIGINS = [x.strip() for x in os.getenv("DJANGO_CSRF_TRUSTED_ORIGINS", "").split(",") if x.strip()]

INSTALLED_APPS = [
    "config.admin_app.WorkbenchAdminConfig", "django.contrib.auth", "django.contrib.contenttypes",
    "django.contrib.sessions", "django.contrib.messages", "django.contrib.staticfiles",
    "workbench",
]
MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "workbench.member_middleware.ForcePasswordChangeMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]
ROOT_URLCONF = "config.urls"
TEMPLATES = [{
    "BACKEND": "django.template.backends.django.DjangoTemplates",
    "DIRS": [BASE_DIR / "templates"],
    "APP_DIRS": True,
    "OPTIONS": {"context_processors": [
        "django.template.context_processors.debug",
        "django.template.context_processors.request",
        "django.contrib.auth.context_processors.auth",
        "django.contrib.messages.context_processors.messages",
        "workbench.context_processors.workbench_profile",
    ]},
}]
WSGI_APPLICATION = "config.wsgi.application"

if os.getenv("DB_HOST"):
    DATABASES = {"default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": os.getenv("DB_NAME", "teacher_workbench"),
        "USER": os.getenv("DB_USER", "teacher_workbench"),
        "PASSWORD": os.getenv("DB_PASSWORD", ""),
        "HOST": os.environ["DB_HOST"],
        "PORT": os.getenv("DB_PORT", "5432"),
    }}
else:
    local_data_dir = BASE_DIR / "data"
    local_data_dir.mkdir(parents=True, exist_ok=True)
    DATABASES = {"default": {"ENGINE": "django.db.backends.sqlite3", "NAME": local_data_dir / "dev.sqlite3"}}

AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]
LANGUAGE_CODE = "zh-hans"
TIME_ZONE = "Asia/Shanghai"
USE_I18N = True
USE_TZ = True
STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
MEDIA_ROOT = Path(os.getenv("PRIVATE_FILE_ROOT", str(BASE_DIR / "data" / "private")))
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"
LOGIN_URL = "login"
LOGIN_REDIRECT_URL = "dashboard"
LOGOUT_REDIRECT_URL = "login"
DATA_UPLOAD_MAX_MEMORY_SIZE = 20 * 1024 * 1024
FILE_UPLOAD_MAX_MEMORY_SIZE = 2 * 1024 * 1024

# Explicit opt-in. Merely supplying a key never starts a model call.
AI_ENABLED = os.getenv("AI_ENABLED", "0") == "1"
AI_PROVIDER = os.getenv("AI_PROVIDER", "openai-compatible")
AI_BASE_URL = os.getenv("AI_BASE_URL", "")
AI_MODEL = os.getenv("AI_MODEL", "")
AI_API_KEY = os.getenv("AI_API_KEY", "")
# Independent member credentials are dormant until an external keyring is configured.
MODEL_KEYRING_DIR = os.getenv("MODEL_KEYRING_DIR", "")
MODEL_ACTIVE_KEY_VERSION = int(os.getenv("MODEL_ACTIVE_KEY_VERSION", "1"))
AI_MAX_OUTPUT_TOKENS = max(200, min(int(os.getenv("AI_MAX_OUTPUT_TOKENS", "1500")), 2000))
AI_MEMBER_MAX_OUTPUT_TOKENS = max(200, min(int(os.getenv("AI_MEMBER_MAX_OUTPUT_TOKENS", "3000")), 4000))
REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379/0")
if not DEBUG:
    # All production web processes must share the same login throttle counters.
    # A Redis outage fails closed for authentication rather than using per-process memory.
    CACHES = {"default": {
        "BACKEND": "django.core.cache.backends.redis.RedisCache",
        "LOCATION": REDIS_URL,
    }}
AI_LOCAL_QUEUE = (
    DEBUG
    and DATABASES["default"]["ENGINE"] == "django.db.backends.sqlite3"
    and os.getenv("AI_LOCAL_QUEUE", "0") == "1"
)
AI_STAGING_MANUAL_QUEUE = (
    DEBUG
    and DATABASES["default"]["ENGINE"] == "django.db.backends.postgresql"
    and DATABASES["default"]["NAME"] == "teacher_workbench_staging"
    and os.getenv("TW_STAGING") == "1"
    and os.getenv("AI_STAGING_MANUAL_QUEUE", "0") == "1"
    and not AI_ENABLED
    and not AI_API_KEY
)
AI_MEMBER_TASKS_ENABLED = (
    os.getenv("AI_MEMBER_TASKS_ENABLED", "0") == "1"
    and AI_ENABLED
    and not AI_STAGING_MANUAL_QUEUE
)

SESSION_COOKIE_HTTPONLY = True
CSRF_COOKIE_HTTPONLY = True
SESSION_COOKIE_SECURE = not DEBUG
CSRF_COOKIE_SECURE = not DEBUG
SECURE_CONTENT_TYPE_NOSNIFF = True
X_FRAME_OPTIONS = "DENY"
SECURE_SSL_REDIRECT = not DEBUG and os.getenv("DJANGO_SECURE_SSL_REDIRECT", "0") == "1"
SECURE_HSTS_SECONDS = int(os.getenv("DJANGO_HSTS_SECONDS", "0")) if not DEBUG else 0
SECURE_HSTS_INCLUDE_SUBDOMAINS = False
SECURE_HSTS_PRELOAD = False
if not DEBUG and os.getenv("DJANGO_TRUST_PROXY_SSL_HEADER", "0") == "1":
    SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
