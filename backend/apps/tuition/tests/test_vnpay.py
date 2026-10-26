"""VNPay: ký/kiểm chữ ký/dựng URL, tạo giao dịch thanh toán, xác nhận return URL + IPN."""

import hashlib
import hmac
from datetime import UTC, datetime
from decimal import Decimal
from urllib.parse import parse_qsl, urlsplit

import pytest
from rest_framework.test import APIClient

from apps.audit.models import AuditLog
from apps.auth.models import Role
from apps.tuition import vnpay
from apps.tuition.models import Discount, OnlineTransaction, Payment
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


def test_kiem_chu_ky_tu_choi_khi_chua_cau_hinh_khoa(settings):
    """Khóa rỗng: ai cũng ký được bằng HMAC khóa rỗng → không được coi là chữ ký hợp lệ."""
    settings.VNPAY_TMN_CODE, settings.VNPAY_HASH_SECRET = "", ""
    params = {"vnp_Command": "pay", "vnp_Amount": "1000000"}
    gia = hmac.new(b"", b"vnp_Amount=1000000&vnp_Command=pay", hashlib.sha512).hexdigest()
    assert vnpay.kiem_chu_ky({**params, "vnp_SecureHash": gia}) is False


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


# --------------------------------------------------------------- return URL + IPN

IPN = "/api/tuition/vnpay/ipn/"
RETURN = "/api/tuition/vnpay/return/"


def gd_cho(hk=None, tong=1000, so_tien=1000):
    """SV có học phí `tong` và một giao dịch VNPay đang chờ `so_tien`."""
    hk, sv = hk or SemesterFactory(), StudentProfileFactory()
    t = hoc_phi(sv, hk, tong)
    return sv, t, OnlineTransaction.objects.create(tuition=t, so_tien=D(so_tien))


def callback(gd, code="00", status="00", amount=None, **them):
    """Tham số VNPay gọi về, đã ký đúng."""
    params = {
        "vnp_TmnCode": "TESTTMN1",
        "vnp_Amount": str(amount if amount is not None else int(gd.so_tien * 100)),
        "vnp_BankCode": "NCB",
        "vnp_OrderInfo": "HOCPHI test",
        "vnp_PayDate": "20261025101000",
        "vnp_ResponseCode": code,
        "vnp_TransactionNo": "14226112",
        "vnp_TransactionStatus": status,
        "vnp_TxnRef": gd.txn_ref.hex,
        **them,
    }
    return {**params, "vnp_SecureHash": vnpay.ky(params)}


def test_ipn_thanh_cong_ghi_mot_payment(vnp):
    sv, t, gd = gd_cho()
    res = APIClient().get(IPN, callback(gd))
    assert res.status_code == 200
    assert res.json() == {"RspCode": "00", "Message": "Confirm Success"}
    gd.refresh_from_db()
    assert (gd.trang_thai, gd.vnp_transaction_no) == ("THANH_CONG", "14226112")
    assert gd.ket_thuc_luc is not None
    p = Payment.objects.get()
    assert (p.loai, p.phuong_thuc, p.so_tien, p.nguoi_thu) == ("THU", "VNPAY", D(1000), sv.user)
    assert p.request_id == gd.txn_ref and p.bien_lai_ma
    from apps.tuition.services import dan_xuat_cua

    assert dan_xuat_cua(t)["con_no"] == D(0)
    assert AuditLog.objects.filter(doi_tuong="OnlineTransaction", hanh_dong="UPDATE").count() == 1


def test_return_va_ipn_hai_lan_chi_mot_payment(vnp):
    _, _, gd = gd_cho()
    c, ps = APIClient(), callback(gd)
    r1 = c.get(RETURN, ps)
    assert r1.status_code == 302
    assert r1["Location"] == f"{vnp.APP_RESULT_URL}?status=thanh_cong&txn={gd.txn_ref.hex}"
    assert c.get(IPN, ps).json()["RspCode"] == "02"
    assert c.get(RETURN, ps)["Location"].endswith(f"status=thanh_cong&txn={gd.txn_ref.hex}")
    assert Payment.objects.count() == 1


def test_sai_chu_ky_bi_tu_choi(vnp):
    _, _, gd = gd_cho()
    ps = {**callback(gd), "vnp_Amount": "100"}  # đổi số tiền sau khi ký
    assert APIClient().get(IPN, ps).json()["RspCode"] == "97"
    gd.refresh_from_db()
    assert gd.trang_thai == "CHO" and Payment.objects.count() == 0


def test_so_tien_lech_nhung_chu_ky_dung(vnp):
    _, _, gd = gd_cho()
    res = APIClient().get(IPN, callback(gd, amount=100))  # ký lại với số tiền sai
    assert res.json()["RspCode"] == "04"
    gd.refresh_from_db()
    assert gd.trang_thai == "CHO" and Payment.objects.count() == 0


def test_tham_so_vnp_la_van_nam_trong_chu_ky(vnp):
    _, _, gd = gd_cho()
    c = APIClient()
    ps = callback(gd, vnp_Extra="1")
    assert c.get(IPN, {**ps, "vnp_Extra": "2"}).json()["RspCode"] == "97"  # sửa sau khi ký
    assert c.get(IPN, {k: v for k, v in ps.items() if k != "vnp_Extra"}).json()["RspCode"] == "97"
    assert c.get(IPN, ps).json()["RspCode"] == "00"  # tham số lạ đã ký vẫn được chấp nhận


@pytest.mark.parametrize("code,status", [("24", "02"), ("00", "02"), ("11", "00")])
def test_that_bai_khi_khong_phai_00_ca_hai(vnp, code, status):
    _, _, gd = gd_cho()
    c = APIClient()
    ps = callback(gd, code=code, status=status)
    assert c.get(IPN, ps).json()["RspCode"] == "00"
    gd.refresh_from_db()
    assert gd.trang_thai == "THAT_BAI" and Payment.objects.count() == 0
    assert c.get(RETURN, ps)["Location"].endswith(f"status=that_bai&txn={gd.txn_ref.hex}")


def test_con_no_giam_giua_chung_danh_dau_loi(vnp):
    _, t, gd = gd_cho(so_tien=1000)
    thu_tien(t, 500)  # KT thu tiền mặt trong lúc SV đang thanh toán → con_no còn 500 < 1000
    c, ps = APIClient(), callback(gd)
    assert c.get(IPN, ps).json()["RspCode"] == "00"
    gd.refresh_from_db()
    assert gd.trang_thai == "LOI"
    assert Payment.objects.filter(phuong_thuc="VNPAY").count() == 0
    assert AuditLog.objects.filter(doi_tuong="OnlineTransaction", doi_tuong_id=str(gd.id)).exists()
    assert c.get(RETURN, ps)["Location"].endswith(f"status=loi&txn={gd.txn_ref.hex}")


def test_khong_thay_giao_dich(vnp):
    _, _, gd = gd_cho()
    c = APIClient()
    xa_la = callback(gd, vnp_TxnRef="f" * 32)
    # ký lại: callback() đã ghi đè vnp_TxnRef qua **them nên chữ ký khớp
    assert c.get(IPN, xa_la).json()["RspCode"] == "01"
    khong_hex = callback(gd, vnp_TxnRef="khong-phai-hex")
    assert c.get(IPN, khong_hex).json()["RspCode"] == "01"
    assert c.get(RETURN, xa_la)["Location"] == f"{vnp.APP_RESULT_URL}?status=khong_hop_le&txn="


def test_return_redirect_sai_chu_ky(vnp):
    _, _, gd = gd_cho()
    res = APIClient().get(RETURN, {**callback(gd), "vnp_Amount": "1"})
    assert res["Location"] == f"{vnp.APP_RESULT_URL}?status=sai_chu_ky&txn="


def test_callback_khong_can_dang_nhap(vnp):
    _, _, gd = gd_cho()
    assert APIClient().get(IPN, callback(gd)).status_code == 200
    assert APIClient().get(RETURN, callback(gd)).status_code == 302
