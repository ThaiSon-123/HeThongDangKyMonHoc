"""VNPay: ký/kiểm chữ ký/dựng URL, tạo giao dịch thanh toán, xác nhận return URL + IPN."""

import hashlib
import hmac
from datetime import UTC, datetime
from decimal import Decimal
from urllib.parse import parse_qsl, urlsplit

import pytest

from apps.tuition import vnpay

D = Decimal


@pytest.fixture
def vnp(settings):
    settings.VNPAY_TMN_CODE = "TESTTMN1"
    settings.VNPAY_HASH_SECRET = "secret"
    settings.VNPAY_URL = "https://sandbox.vnpayment.vn/paymentv2/vpcpay.html"
    settings.VNPAY_RETURN_URL = "http://localhost:8000/api/tuition/vnpay/return/"
    settings.APP_RESULT_URL = "http://localhost:8080/student/tuition/pay-result"
    return settings


# --------------------------------------------------------------- ký / kiểm / dựng URL


def test_ky_khop_vector_tu_tinh(vnp):
    params = {"vnp_Command": "pay", "vnp_Amount": "1000000", "vnp_OrderInfo": "HOCPHI SV01 HK1"}
    chuoi = b"vnp_Amount=1000000&vnp_Command=pay&vnp_OrderInfo=HOCPHI+SV01+HK1"
    assert vnpay.ky(params) == hmac.new(b"secret", chuoi, hashlib.sha512).hexdigest()


def test_ky_bo_qua_truong_chu_ky(vnp):
    params = {"vnp_Command": "pay", "vnp_Amount": "1000000"}
    them = {**params, "vnp_SecureHash": "abc", "vnp_SecureHashType": "HmacSHA512"}
    assert vnpay.ky(them) == vnpay.ky(params)


def test_kiem_chu_ky_dung_sai_va_thieu(vnp):
    params = {"vnp_Command": "pay", "vnp_Amount": "1000000"}
    dung = {**params, "vnp_SecureHash": vnpay.ky(params)}
    assert vnpay.kiem_chu_ky(dung) is True
    assert vnpay.kiem_chu_ky({**dung, "vnp_Amount": "1000001"}) is False
    assert vnpay.kiem_chu_ky(params) is False


def test_tao_url_co_du_tham_so(vnp):
    now = datetime(2026, 10, 25, 3, 0, tzinfo=UTC)  # 10:00 giờ VN
    url = vnpay.tao_url("a" * 32, D("1000000.50"), "HOCPHI SV01 HK1", "1.2.3.4", now)
    assert url.startswith(vnp.VNPAY_URL + "?")
    q = dict(parse_qsl(urlsplit(url).query))
    assert q["vnp_Amount"] == "100000050"
    assert q["vnp_TxnRef"] == "a" * 32
    assert q["vnp_CreateDate"] == "20261025100000"
    assert q["vnp_ExpireDate"] == "20261025101500"
    assert (q["vnp_Version"], q["vnp_Command"], q["vnp_CurrCode"]) == ("2.1.0", "pay", "VND")
    assert q["vnp_TmnCode"] == "TESTTMN1" and q["vnp_ReturnUrl"] == vnp.VNPAY_RETURN_URL
    assert q["vnp_OrderInfo"] == "HOCPHI SV01 HK1" and q["vnp_IpAddr"] == "1.2.3.4"
    assert "vnp_BankCode" not in q
    assert vnpay.kiem_chu_ky(q) is True


def test_da_cau_hinh(settings):
    settings.VNPAY_TMN_CODE, settings.VNPAY_HASH_SECRET = "", ""
    assert vnpay.da_cau_hinh() is False
    settings.VNPAY_TMN_CODE = "X"
    assert vnpay.da_cau_hinh() is False
    settings.VNPAY_HASH_SECRET = "y"
    assert vnpay.da_cau_hinh() is True
