"""Môi trường prod — bắt buộc SECRET_KEY/DEBUG=False (plan.md mục 23)."""

from .base import *  # noqa: F401,F403
from .base import REST_FRAMEWORK as _REST_FRAMEWORK
from .base import SECRET_KEY as _SECRET_KEY
from .base import env_int

if DEBUG:  # noqa: F405
    raise RuntimeError("DEBUG phải False ở prod.")
if _SECRET_KEY.startswith("dev-insecure-key"):
    raise RuntimeError("Thiếu SECRET_KEY ở prod.")

# Sau nginx (1 proxy): IP thật nằm ở phần tử cuối của X-Forwarded-For. Không publish cổng `web`
# ra ngoài ở prod — nếu không client gọi thẳng vào gunicorn vẫn giả được header.
REST_FRAMEWORK = {**_REST_FRAMEWORK, "NUM_PROXIES": env_int("NUM_PROXIES", 1)}

# Token reset mật khẩu KHÔNG bao giờ trả trong response ở prod
PASSWORD_RESET_RETURN_TOKEN_IN_RESPONSE = False

SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
