"""Refresh / logout / khóa tài khoản chặn token đang dùng (BR-22)."""

import pytest
from rest_framework_simplejwt.tokens import RefreshToken

from core.factories import UserFactory

pytestmark = pytest.mark.django_db


def test_refresh_xoay_vong_va_refresh_cu_het_hieu_luc(client):
    old = str(RefreshToken.for_user(UserFactory()))

    res = client.post("/api/auth/refresh/", {"refresh": old})

    assert res.status_code == 200
    assert res.data["access"] and res.data["refresh"] != old
    assert client.post("/api/auth/refresh/", {"refresh": old}).status_code == 401


def test_refresh_cua_tai_khoan_da_khoa_bi_chan(client):
    u = UserFactory()
    refresh = str(RefreshToken.for_user(u))
    u.is_locked = True
    u.save()

    res = client.post("/api/auth/refresh/", {"refresh": refresh})

    assert res.status_code == 403
    assert res.data["error"]["code"] == "TAI_KHOAN_BI_KHOA"


def test_refresh_token_rac_tra_401(client):
    assert client.post("/api/auth/refresh/", {"refresh": "rac"}).status_code == 401


def test_access_token_dang_dung_bi_chan_ngay_khi_admin_khoa_tai_khoan(login_as):
    u = UserFactory()
    api = login_as(u)
    assert api.get("/api/profiles/me/").status_code == 200

    u.is_locked = True
    u.save()
    res = api.get("/api/profiles/me/")

    assert res.status_code == 403
    assert res.data["error"]["code"] == "TAI_KHOAN_BI_KHOA"


def test_logout_blacklist_refresh_token(client, login_as):
    u = UserFactory()
    refresh = str(RefreshToken.for_user(u))

    res = login_as(u).post("/api/auth/logout/", {"refresh": refresh})

    assert res.status_code == 204
    assert client.post("/api/auth/refresh/", {"refresh": refresh}).status_code == 401


def test_logout_khong_blacklist_duoc_token_cua_nguoi_khac(login_as):
    a, b = UserFactory(), UserFactory()
    token_cua_b = str(RefreshToken.for_user(b))

    res = login_as(a).post("/api/auth/logout/", {"refresh": token_cua_b})

    assert res.status_code == 400


def test_logout_can_dang_nhap(client):
    assert client.post("/api/auth/logout/", {"refresh": "x"}).status_code == 401
