"""Cấu hình chung — mọi giá trị nhạy cảm đến từ biến môi trường (plan.md mục 14)."""

import os
from datetime import timedelta
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent.parent


def env(key: str, default: str = "") -> str:
    return os.environ.get(key, default)


def env_bool(key: str, default: bool = False) -> bool:
    return env(key, str(default)).strip().lower() in {"1", "true", "yes", "on"}


def env_int(key: str, default: int) -> int:
    try:
        return int(env(key, str(default)))
    except ValueError:
        return default


def env_list(key: str, default: str = "") -> list[str]:
    return [v.strip() for v in env(key, default).split(",") if v.strip()]


# --- Core ---
SECRET_KEY = env("SECRET_KEY") or "dev-insecure-key-set-SECRET_KEY-in-env"
DEBUG = env_bool("DEBUG", False)
ALLOWED_HOSTS = env_list("ALLOWED_HOSTS", "localhost,127.0.0.1")

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    # third-party
    "rest_framework",
    "rest_framework_simplejwt.token_blacklist",
    "django_filters",
    "corsheaders",
    "drf_spectacular",
    "django_celery_beat",
    # local
    "apps.auth",
    "apps.profiles",
    "apps.training",
    "apps.registration",
    "apps.attendance",
    "apps.grades",
    "apps.tuition",
    "apps.notifications",
    "apps.audit",
    "apps.config",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "corsheaders.middleware.CorsMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
    "core.middleware.IdempotencyKeyMiddleware",
]

ROOT_URLCONF = "config.urls"
TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]
WSGI_APPLICATION = "config.wsgi.application"
ASGI_APPLICATION = "config.asgi.application"

# --- Database (PostgreSQL 16) ---
DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": env("DB_NAME", "hpsv"),
        "USER": env("DB_USER", "postgres"),
        "PASSWORD": env("DB_PASSWORD"),
        "HOST": env("DB_HOST", "db"),
        "PORT": env("DB_PORT", "5432"),
        "CONN_MAX_AGE": env_int("DB_CONN_MAX_AGE", 60),
    }
}
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

# --- Password ---
AUTH_USER_MODEL = "user.User"
AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {
        "NAME": "django.contrib.auth.password_validation.MinimumLengthValidator",
        "OPTIONS": {"min_length": 8},
    },
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

# --- I18N / TZ ---
LANGUAGE_CODE = "vi"
TIME_ZONE = env("TZ", "Asia/Ho_Chi_Minh")
USE_I18N = True
USE_TZ = True

# --- Static ---
STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
MEDIA_URL = "media/"
MEDIA_ROOT = Path(env("MEDIA_DIR", str(BASE_DIR / "media")))

# --- CORS ---
# django-cors-headers không hỗ trợ wildcard port ("localhost:*") → dev dùng regex (dev.py), prod liệt kê origin.
CORS_ALLOWED_ORIGINS = env_list("CORS_ALLOWED_ORIGINS", "")
CORS_ALLOW_CREDENTIALS = True
CSRF_TRUSTED_ORIGINS = env_list("CSRF_TRUSTED_ORIGINS", "")

# --- DRF ---
REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": ("apps.auth.authentication.LockedAwareJWTAuthentication",),
    "DEFAULT_PERMISSION_CLASSES": ("rest_framework.permissions.IsAuthenticated",),
    "DEFAULT_PAGINATION_CLASS": "core.pagination.StandardPagination",
    "PAGE_SIZE": 25,
    "DEFAULT_SCHEMA_CLASS": "drf_spectacular.openapi.AutoSchema",
    "EXCEPTION_HANDLER": "core.exceptions.api_exception_handler",
    "DEFAULT_THROTTLE_CLASSES": ("rest_framework.throttling.ScopedRateThrottle",),
    "DEFAULT_THROTTLE_RATES": {
        "login": env("RATE_LOGIN", "10/min"),
        "forgot_password": "3/15min",
        "registration": "30/min",
        "write": "120/min",
    },
}
SPECTACULAR_SETTINGS = {
    "TITLE": "Hệ thống Đăng ký Môn học API",
    "DESCRIPTION": "Backend là nguồn sự thật duy nhất — mọi BR kiểm tra tại API.",
    "VERSION": "3.0",
    "SERVE_INCLUDE_SCHEMA": False,
}

# --- JWT (plan.md mục 8.2) ---
SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(minutes=env_int("JWT_ACCESS_LIFETIME_MIN", 60)),
    "REFRESH_TOKEN_LIFETIME": timedelta(days=env_int("JWT_REFRESH_LIFETIME_DAYS", 7)),
    "ROTATE_REFRESH_TOKENS": True,
    "BLACKLIST_AFTER_ROTATION": True,
    "UPDATE_LAST_LOGIN": True,
}
PASSWORD_RESET_RETURN_TOKEN_IN_RESPONSE = env_bool("PASSWORD_RESET_RETURN_TOKEN_IN_RESPONSE", False)

# --- Pagination (mục 8.2) ---
API_MAX_PAGE_SIZE = 50

# --- Celery ---
REDIS_URL = env("REDIS_URL", "redis://redis:6379/0")
CELERY_BROKER_URL = env("CELERY_BROKER_URL", "redis://redis:6379/1")
CELERY_RESULT_BACKEND = env("CELERY_RESULT_BACKEND", "redis://redis:6379/2")
CELERY_TIMEZONE = TIME_ZONE
CELERY_BEAT_SCHEDULER = "django_celery_beat.schedulers:DatabaseScheduler"

# --- Email ---
EMAIL_BACKEND = env("EMAIL_BACKEND", "django.core.mail.backends.console.EmailBackend")
EMAIL_HOST = env("EMAIL_HOST", "localhost")
EMAIL_PORT = env_int("EMAIL_PORT", 25)
EMAIL_HOST_USER = env("EMAIL_HOST_USER")
EMAIL_HOST_PASSWORD = env("EMAIL_HOST_PASSWORD")
EMAIL_USE_TLS = env_bool("EMAIL_USE_TLS", False)
DEFAULT_FROM_EMAIL = env("DEFAULT_FROM_EMAIL", "no-reply@hpsv.local")

# --- Backup ---
BACKUP_DIR = Path(env("BACKUP_DIR", str(BASE_DIR / "backups")))

# --- Observability ---
SENTRY_DSN = env("SENTRY_DSN")
