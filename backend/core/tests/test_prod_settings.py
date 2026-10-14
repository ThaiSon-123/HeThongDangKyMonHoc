"""Checklist triển khai (plan mục 14): cấu hình `prod` phải an toàn mặc định. Chạy trong tiến trình con
vì `settings.prod` đọc biến môi trường ngay lúc import."""

import json
import os
import subprocess
import sys
from pathlib import Path

BACKEND = Path(__file__).resolve().parents[2]
DOC = (
    "import json, config.settings.prod as s;"
    "print(json.dumps({'debug': s.DEBUG, 'reset': s.PASSWORD_RESET_RETURN_TOKEN_IN_RESPONSE,"
    "'proxies': s.REST_FRAMEWORK['NUM_PROXIES'], 'cors': s.CORS_ALLOWED_ORIGINS,"
    "'regex': bool(getattr(s, 'CORS_ALLOWED_ORIGIN_REGEXES', []))}))"
)


def chay_prod(**env):
    moi_truong = {k: v for k, v in os.environ.items() if k not in ("DEBUG", "SECRET_KEY")}
    moi_truong |= {"DJANGO_SETTINGS_MODULE": "config.settings.prod", **env}
    return subprocess.run(
        [sys.executable, "-c", DOC], cwd=BACKEND, env=moi_truong, capture_output=True, text=True
    )


def test_prod_an_toan_mac_dinh():
    kq = chay_prod(
        DEBUG="False",
        SECRET_KEY="khoa-bi-mat-cua-prod",
        CORS_ALLOWED_ORIGINS="https://dkmh.truong.edu.vn",
    )
    assert kq.returncode == 0, kq.stderr
    cau_hinh = json.loads(kq.stdout)
    assert cau_hinh == {
        "debug": False,
        "reset": False,  # token đặt lại mật khẩu không bao giờ nằm trong response ở prod
        "proxies": 1,  # sau nginx; không tin X-Forwarded-For giả
        "cors": ["https://dkmh.truong.edu.vn"],  # origin tường minh
        "regex": False,  # không dùng regex localhost của dev
    }


def test_prod_tu_choi_khoi_dong_khi_debug_bat_hoac_thieu_secret_key():
    debug = chay_prod(DEBUG="True", SECRET_KEY="khoa-bi-mat-cua-prod")
    assert debug.returncode != 0 and "RuntimeError" in debug.stderr and "DEBUG" in debug.stderr
    thieu = chay_prod(DEBUG="False")
    assert thieu.returncode != 0 and "SECRET_KEY" in thieu.stderr
