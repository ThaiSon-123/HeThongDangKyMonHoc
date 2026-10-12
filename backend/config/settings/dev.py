"""Môi trường dev — cài đặt ở container."""

from .base import *  # noqa: F401,F403
from .base import env_bool

DEBUG = env_bool("DEBUG", True)
CORS_ALLOWED_ORIGIN_REGEXES = [
    r"^http://(localhost|127\.0\.0\.1):\d+$"
]  # Flutter Web dev: cổng ngẫu nhiên
EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"
# ponytail: chỉ dev mới trả token reset trong response; prod bắt buộc False
PASSWORD_RESET_RETURN_TOKEN_IN_RESPONSE = env_bool("PASSWORD_RESET_RETURN_TOKEN_IN_RESPONSE", True)
