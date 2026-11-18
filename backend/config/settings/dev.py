"""Môi trường dev — cài đặt ở container."""

from .base import *  # noqa: F401,F403
from .base import GPS as _GPS
from .base import env_bool, env_int

DEBUG = env_bool("DEBUG", True)
CORS_ALLOWED_ORIGIN_REGEXES = [
    r"^http://(localhost|127\.0\.0\.1):\d+$"
]  # Flutter Web dev: cổng ngẫu nhiên
# Email: mặc định in ra console (base.py); đặt EMAIL_BACKEND=smtp trong .env để gửi thật.
# ponytail: chỉ dev mới trả mã reset trong response; prod bắt buộc False
PASSWORD_RESET_RETURN_TOKEN_IN_RESPONSE = env_bool("PASSWORD_RESET_RETURN_TOKEN_IN_RESPONSE", True)

# Laptop không có GPS thật (định vị qua Wi-Fi/IP, sai số 30–1000 m) → nới ngưỡng sai số khi test trên web bằng .env.
# Mặc định giữ đúng ngưỡng của base.py; prod không dùng file này.
GPS = {
    **_GPS,
    "max_acc_gv_m": env_int("GPS_MAX_ACC_GV_M", _GPS["max_acc_gv_m"]),
    "max_acc_sv_m": env_int("GPS_MAX_ACC_SV_M", _GPS["max_acc_sv_m"]),
}
