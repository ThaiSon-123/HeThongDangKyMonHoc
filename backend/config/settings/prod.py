"""Môi trường prod — bắt buộc SECRET_KEY/DEBUG=False (plan.md mục 23)."""

from .base import *  # noqa: F401,F403
from .base import SECRET_KEY as _SECRET_KEY

if DEBUG:  # noqa: F405
    raise RuntimeError("DEBUG phải False ở prod.")
if _SECRET_KEY.startswith("dev-insecure-key"):
    raise RuntimeError("Thiếu SECRET_KEY ở prod.")

# Token reset mật khẩu KHÔNG bao giờ trả trong response ở prod
PASSWORD_RESET_RETURN_TOKEN_IN_RESPONSE = False

SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
