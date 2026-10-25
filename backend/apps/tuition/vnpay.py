"""Cổng thanh toán VNPay 2.1.0 (sandbox): ký, kiểm chữ ký, dựng URL thanh toán. Không đụng DB."""

import hashlib
import hmac
from collections.abc import Mapping
from datetime import datetime, timedelta
from decimal import Decimal
from urllib.parse import quote_plus
from zoneinfo import ZoneInfo

from django.conf import settings

GIO_VN = ZoneInfo("Asia/Ho_Chi_Minh")
HET_HAN_PHUT = 15
_BO_QUA = {"vnp_SecureHash", "vnp_SecureHashType"}


def da_cau_hinh() -> bool:
    return bool(settings.VNPAY_TMN_CODE and settings.VNPAY_HASH_SECRET)


def _chuoi_ky(params: Mapping[str, str]) -> str:
    return "&".join(
        f"{k}={quote_plus(str(v))}" for k, v in sorted(params.items()) if k not in _BO_QUA
    )


def ky(params: Mapping[str, str]) -> str:
    key = settings.VNPAY_HASH_SECRET.encode()
    return hmac.new(key, _chuoi_ky(params).encode(), hashlib.sha512).hexdigest()


def kiem_chu_ky(params: Mapping[str, str]) -> bool:
    nhan = params.get("vnp_SecureHash")
    return bool(nhan) and hmac.compare_digest(nhan.lower(), ky(params))


def tao_url(txn_ref: str, so_tien: Decimal, order_info: str, ip: str, now: datetime) -> str:
    """URL chuyển hướng sang VNPay. `now` là datetime aware; không gửi `vnp_BankCode` để người dùng
    tự chọn phương thức trên trang VNPay."""
    bay_gio = now.astimezone(GIO_VN)
    params = {
        "vnp_Version": "2.1.0",
        "vnp_Command": "pay",
        "vnp_TmnCode": settings.VNPAY_TMN_CODE,
        "vnp_Amount": str(int(so_tien * 100)),
        "vnp_CreateDate": bay_gio.strftime("%Y%m%d%H%M%S"),
        "vnp_CurrCode": "VND",
        "vnp_IpAddr": ip,
        "vnp_Locale": "vn",
        "vnp_OrderInfo": order_info,
        "vnp_OrderType": "other",
        "vnp_ReturnUrl": settings.VNPAY_RETURN_URL,
        "vnp_TxnRef": txn_ref,
        "vnp_ExpireDate": (bay_gio + timedelta(minutes=HET_HAN_PHUT)).strftime("%Y%m%d%H%M%S"),
    }
    return f"{settings.VNPAY_URL}?{_chuoi_ky(params)}&vnp_SecureHash={ky(params)}"
