"""VNPay: ký/kiểm chữ ký/dựng URL, tạo giao dịch thanh toán, xác nhận return URL + IPN."""

import hashlib
import hmac
from datetime import UTC, datetime
from decimal import Decimal
from urllib.parse import parse_qsl, urlsplit

import pytest

from apps.auth.models import Role
from apps.tuition import vnpay
from apps.tuition.models import Discount, OnlineTransaction
from apps.tuition.tests.test_installments import cau_hinh_dot, hoc_phi, thu_tien
from core.factories import SemesterFactory, StudentProfileFactory, UserFactory

pytestmark = pytest.mark.django_db
D = Decimal
PAY = "/api/tuition/my/pay/"


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


# --------------------------------------------------------------- POST /my/pay/ và GET /my/pay/{txn_ref}/


def tao(c, hk, **body):
    return c.post(f"{PAY}?hoc_ky={hk.id}", body, format="json")


def test_pay_toan_bo(vnp, login_as):
    hk, sv = SemesterFactory(), StudentProfileFactory()
    t = hoc_phi(sv, hk, 1000)
    res = tao(login_as(sv.user), hk, muc="TOAN_BO")
    assert res.status_code == 201, res.data
    gd = OnlineTransaction.objects.get()
    assert (gd.tuition, gd.so_tien, gd.trang_thai) == (t, D(1000), "CHO")
    assert res.json()["txn_ref"] == gd.txn_ref.hex and res.json()["so_tien"] == "1000.00"
    assert res.json()["payment_url"].startswith(vnp.VNPAY_URL)
    assert "vnp_Amount=100000&" in res.json()["payment_url"]


def test_pay_dot_tiep_chia_dot(vnp, login_as):
    hk, sv = SemesterFactory(), StudentProfileFactory()
    cau_hinh_dot(hk)
    t = hoc_phi(sv, hk, 1000, hinh_thuc="CHIA_DOT")
    c = login_as(sv.user)
    assert tao(c, hk, muc="DOT_TIEP").json()["so_tien"] == "400.00"
    thu_tien(t, 400)
    assert tao(c, hk, muc="DOT_TIEP").json()["so_tien"] == "300.00"


def test_pay_dot_tiep_mot_lan_bang_con_no(vnp, login_as):
    hk, sv = SemesterFactory(), StudentProfileFactory()
    cau_hinh_dot(hk)
    t = hoc_phi(sv, hk, 1000)  # MOT_LAN dù học kỳ có đợt
    thu_tien(t, 100)
    assert tao(login_as(sv.user), hk, muc="DOT_TIEP").json()["so_tien"] == "900.00"


@pytest.mark.parametrize("so_tien", [1001, 0, -5])
def test_pay_tuy_y_khong_hop_le_bi_tu_choi(vnp, login_as, so_tien):
    hk, sv = SemesterFactory(), StudentProfileFactory()
    hoc_phi(sv, hk, 1000)
    res = tao(login_as(sv.user), hk, muc="TUY_Y", so_tien=so_tien)
    assert res.status_code == 400
    assert OnlineTransaction.objects.count() == 0


def test_pay_tuy_y_thieu_so_tien_hoac_muc_la(vnp, login_as):
    hk, sv = SemesterFactory(), StudentProfileFactory()
    hoc_phi(sv, hk, 1000)
    c = login_as(sv.user)
    assert tao(c, hk, muc="TUY_Y").status_code == 400
    assert tao(c, hk, muc="NHIEU").status_code == 400
    assert tao(c, hk).status_code == 400


def test_pay_tuy_y_hop_le(vnp, login_as):
    hk, sv = SemesterFactory(), StudentProfileFactory()
    hoc_phi(sv, hk, 1000)
    res = tao(login_as(sv.user), hk, muc="TUY_Y", so_tien="250.50")
    assert res.status_code == 201 and res.json()["so_tien"] == "250.50"


def test_pay_khi_phai_nop_bang_0_bi_tu_choi(vnp, login_as):
    hk, sv = SemesterFactory(), StudentProfileFactory()
    cau_hinh_dot(hk)
    hoc_phi(sv, hk, 1000, hinh_thuc="CHIA_DOT")
    Discount.objects.create(sinh_vien=sv.user, hoc_ky=hk, loai="HOC_BONG", ty_le=D(100))
    c = login_as(sv.user)
    for muc in ("DOT_TIEP", "TOAN_BO"):
        res = tao(c, hk, muc=muc)
        assert res.status_code == 409 and res.data["error"]["code"] == "TRANG_THAI_KHONG_HOP_LE"
    assert OnlineTransaction.objects.count() == 0


def test_pay_chua_cau_hinh_vnpay_tra_400(settings, login_as):
    settings.VNPAY_TMN_CODE, settings.VNPAY_HASH_SECRET = "", ""
    hk, sv = SemesterFactory(), StudentProfileFactory()
    hoc_phi(sv, hk, 1000)
    res = tao(login_as(sv.user), hk, muc="TOAN_BO")
    assert res.status_code == 400
    assert OnlineTransaction.objects.count() == 0


def test_pay_chua_tinh_hoc_phi_hoac_khong_co_bi_tu_choi(vnp, login_as):
    hk, sv = SemesterFactory(), StudentProfileFactory()
    c = login_as(sv.user)
    assert tao(c, hk, muc="TOAN_BO").status_code == 409  # chưa có học phí
    hoc_phi(sv, hk, 1000, trang_thai="CHUA_TINH")
    assert tao(c, hk, muc="TOAN_BO").status_code == 409


def test_status_cua_toi_va_cua_nguoi_khac(vnp, login_as):
    hk, a, b = SemesterFactory(), StudentProfileFactory(), StudentProfileFactory()
    hoc_phi(a, hk, 1000)
    hoc_phi(b, hk, 1000)
    ref = tao(login_as(a.user), hk, muc="TOAN_BO").json()["txn_ref"]
    res = login_as(a.user).get(f"{PAY}{ref}/")
    assert res.status_code == 200
    assert res.json() == {"txn_ref": ref, "trang_thai": "CHO", "so_tien": "1000.00"}
    assert login_as(b.user).get(f"{PAY}{ref}/").status_code == 404
    assert login_as(a.user).get(f"{PAY}khong-co/").status_code == 404
    assert login_as(a.user).get(f"{PAY}{'0' * 32}/").status_code == 404


def test_pay_chi_sinh_vien(vnp, login_as):
    hk = SemesterFactory()
    for role in (Role.KE_TOAN, Role.PHONG_DAO_TAO, Role.GIAO_VIEN):
        c = login_as(UserFactory(role=role))
        assert tao(c, hk, muc="TOAN_BO").status_code == 403
        assert c.get(f"{PAY}{'0' * 32}/").status_code == 403
