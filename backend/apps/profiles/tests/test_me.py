"""GET/PATCH /api/profiles/me/ — chỉ sửa email, sdt (SV-02, GV-02)."""

from decimal import Decimal

import pytest

from apps.auth.models import Role
from apps.profiles.services import xep_loai
from core.factories import (
    CurriculumFactory,
    StudentProfileFactory,
    TeacherProfileFactory,
    UserFactory,
)

pytestmark = pytest.mark.django_db
URL = "/api/profiles/me/"


def test_can_dang_nhap(client):
    assert client.get(URL).status_code == 401


def test_sinh_vien_xem_ho_so_day_du(login_as):
    ctdt = CurriculumFactory()
    sp = StudentProfileFactory(
        nganh=ctdt.nganh, ctdt=ctdt, gpa=Decimal("3.25"), tin_chi_tich_luy=60
    )

    res = login_as(sp.user).get(URL)

    assert res.status_code == 200
    d = res.data
    assert d["role"] == Role.SINH_VIEN
    assert (d["ma_sv"], d["ho_ten"], d["khoa_nhap_hoc"]) == (sp.ma_sv, sp.ho_ten, "K22")
    assert d["nganh"]["ma_nganh"] == ctdt.nganh.ma_nganh
    assert d["ctdt"] == {
        "id": ctdt.id,
        "ma_ctdt": ctdt.ma_ctdt,
        "tong_tin_chi_yeu_cau": ctdt.tong_tin_chi_yeu_cau,
    }
    assert d["gpa"] == "3.25" and d["tin_chi_tich_luy"] == 60
    assert d["xep_loai"] == "Giỏi"


def test_sinh_vien_chua_co_diem_gpa_null_va_khong_xep_loai(login_as):
    sp = StudentProfileFactory()

    d = login_as(sp.user).get(URL).data

    assert d["gpa"] is None and d["xep_loai"] is None


def test_giao_vien_xem_ho_so(login_as):
    tp = TeacherProfileFactory(khoa__ten_khoa="CNTT", hoc_vi="ThS")

    d = login_as(tp.user).get(URL).data

    assert d["role"] == Role.GIAO_VIEN
    assert (d["ma_gv"], d["khoa"], d["hoc_vi"]) == (tp.ma_gv, "CNTT", "ThS")


@pytest.mark.parametrize("role", [Role.ADMIN, Role.PHONG_DAO_TAO, Role.KE_TOAN])
def test_vai_tro_khong_co_ho_so_van_xem_duoc_thong_tin_tai_khoan(login_as, role):
    u = UserFactory(role=role, first_name="Lê Văn A")

    d = login_as(u).get(URL).data

    assert d["role"] == role and d["full_name"] == "Lê Văn A" and d["email"] == u.email


def test_sua_email_sdt_dong_bo_ca_user_va_ho_so(login_as):
    sp = StudentProfileFactory()

    res = login_as(sp.user).patch(URL, {"email": "moi@example.com", "sdt": "0901234567"})

    assert res.status_code == 200
    sp.refresh_from_db()
    sp.user.refresh_from_db()
    assert (sp.email, sp.sdt, sp.user.email) == ("moi@example.com", "0901234567", "moi@example.com")


def test_khong_duoc_sua_truong_hoc_vu(login_as):
    sp = StudentProfileFactory(ma_sv="SV00001")

    res = login_as(sp.user).patch(
        URL, {"ma_sv": "SV99999", "gpa": "4.00", "email": "a@example.com"}
    )

    assert res.status_code == 400
    assert set(res.data) == {"ma_sv", "gpa"}
    sp.refresh_from_db()
    assert sp.ma_sv == "SV00001" and sp.gpa is None


@pytest.mark.parametrize("body", [{"email": "khong-phai-email"}, {"sdt": "abc"}, {"sdt": "1" * 20}])
def test_email_sdt_sai_dinh_dang(login_as, body):
    res = login_as(StudentProfileFactory().user).patch(URL, body)

    assert res.status_code == 400


def test_admin_khong_co_sdt(login_as):
    res = login_as(UserFactory(role=Role.ADMIN)).patch(URL, {"sdt": "0901234567"})

    assert res.status_code == 400 and "sdt" in res.data


@pytest.mark.parametrize(
    ("gpa", "ket_qua"),
    [
        ("4.00", "Xuất sắc"),
        ("3.60", "Xuất sắc"),
        ("3.59", "Giỏi"),
        ("3.20", "Giỏi"),
        ("3.19", "Khá"),
        ("2.50", "Khá"),
        ("2.49", "Trung bình"),
        ("2.00", "Trung bình"),
        ("1.99", "Yếu"),
        ("1.00", "Yếu"),
        ("0.99", "Kém"),
        ("0", "Kém"),
        (None, None),
    ],
)
def test_xep_loai_hoc_luc_theo_br25f(gpa, ket_qua):
    assert xep_loai(None if gpa is None else Decimal(gpa)) == ket_qua
