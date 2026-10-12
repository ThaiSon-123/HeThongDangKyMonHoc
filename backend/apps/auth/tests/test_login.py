"""Đăng nhập (BR-22): sai thông tin, tài khoản khóa, rate limit, audit."""

import pytest

from apps.audit.models import AuditLog, HanhDong
from apps.auth.models import Role
from core.factories import MAT_KHAU, StudentProfileFactory, UserFactory

pytestmark = pytest.mark.django_db
URL = "/api/auth/login/"


def test_login_thanh_cong_tra_token_va_thong_tin_user(client):
    sp = StudentProfileFactory(user__username="sv1", ho_ten="Nguyễn Văn An")

    res = client.post(URL, {"username": "sv1", "password": MAT_KHAU})

    assert res.status_code == 200
    assert res.data["access"] and res.data["refresh"]
    assert res.data["user"] == {
        "id": sp.user_id,
        "username": "sv1",
        "full_name": "Nguyễn Văn An",
        "role": Role.SINH_VIEN,
        "email": sp.user.email,
    }


def test_login_sai_mat_khau_va_user_khong_ton_tai_tra_cung_mot_loi(client):
    UserFactory(username="sv1")

    sai_mk = client.post(URL, {"username": "sv1", "password": "SaiMatKhau1"})
    khong_ton_tai = client.post(URL, {"username": "khongco", "password": "SaiMatKhau1"})

    assert sai_mk.status_code == khong_ton_tai.status_code == 401
    assert sai_mk.data == khong_ton_tai.data  # không lộ user có tồn tại hay không


def test_tai_khoan_bi_khoa_dang_nhap_dung_mat_khau_bi_chan(client):
    UserFactory(username="sv1", is_locked=True)

    res = client.post(URL, {"username": "sv1", "password": MAT_KHAU})

    assert res.status_code == 403
    assert res.data["error"]["code"] == "TAI_KHOAN_BI_KHOA"
    assert "access" not in res.data


def test_tai_khoan_bi_khoa_nhap_sai_mat_khau_khong_lo_trang_thai_khoa(client):
    UserFactory(username="sv1", is_locked=True)

    res = client.post(URL, {"username": "sv1", "password": "SaiMatKhau1"})

    assert res.status_code == 401


def test_login_ghi_audit_log_va_cap_nhat_last_login(client):
    u = UserFactory(username="sv1")

    client.post(URL, {"username": "sv1", "password": MAT_KHAU})

    u.refresh_from_db()
    assert u.last_login is not None
    log = AuditLog.objects.get(hanh_dong=HanhDong.LOGIN)
    assert log.user_id == u.id and log.doi_tuong == "User" and log.doi_tuong_id == str(u.id)


def test_login_qua_10_lan_moi_phut_bi_429(client):
    for _ in range(10):
        assert client.post(URL, {"username": "x", "password": "y"}).status_code == 401

    res = client.post(URL, {"username": "x", "password": "y"})

    assert res.status_code == 429
    assert res.data["error"]["code"] == "QUA_NHIEU_YEU_CAU"


def test_health_khong_can_dang_nhap(client):
    res = client.get("/api/health/")

    assert res.status_code == 200
    assert res.data["status"] == "ok"
