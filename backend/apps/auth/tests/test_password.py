"""Đổi / quên / đặt lại mật khẩu: chính sách, blacklist, không lộ email, rate limit, TTL token."""

from datetime import datetime, timedelta

import pytest
from django.contrib.auth.tokens import PasswordResetTokenGenerator
from django.core import mail
from rest_framework_simplejwt.tokens import RefreshToken

from core.factories import MAT_KHAU, UserFactory

pytestmark = pytest.mark.django_db
MOI = "MatKhauMoi99"


# ---------------------------------------------------------------- đổi mật khẩu
def test_doi_mat_khau_thanh_cong_blacklist_refresh_cu_va_dang_nhap_bang_mat_khau_moi(
    client, login_as
):
    u = UserFactory(username="sv1")
    refresh = str(RefreshToken.for_user(u))

    res = login_as(u).post(
        "/api/auth/change-password/", {"old_password": MAT_KHAU, "new_password": MOI}
    )

    assert res.status_code == 204
    assert client.post("/api/auth/refresh/", {"refresh": refresh}).status_code == 401
    assert client.post("/api/auth/login/", {"username": "sv1", "password": MOI}).status_code == 200
    assert (
        client.post("/api/auth/login/", {"username": "sv1", "password": MAT_KHAU}).status_code
        == 401
    )


def test_doi_mat_khau_sai_mat_khau_cu(login_as):
    res = login_as(UserFactory()).post(
        "/api/auth/change-password/", {"old_password": "Sai12345", "new_password": MOI}
    )

    assert res.status_code == 400 and "old_password" in res.data


@pytest.mark.parametrize("mat_khau", ["Ab1", "chuchuchuchu", "12345678901"])
def test_chinh_sach_mat_khau_toi_thieu_8_ky_tu_co_chu_va_so(login_as, mat_khau):
    res = login_as(UserFactory()).post(
        "/api/auth/change-password/", {"old_password": MAT_KHAU, "new_password": mat_khau}
    )

    assert res.status_code == 400 and "new_password" in res.data


def test_doi_mat_khau_can_dang_nhap(client):
    assert client.post("/api/auth/change-password/", {}).status_code == 401


# ---------------------------------------------------------------- quên mật khẩu
def test_quen_mat_khau_email_co_va_khong_ton_tai_tra_cung_phan_hoi(client):
    UserFactory(email="co@example.com")

    co = client.post("/api/auth/forgot-password/", {"email": "co@example.com"})
    khong = client.post("/api/auth/forgot-password/", {"email": "khongco@example.com"})

    assert co.status_code == khong.status_code == 200
    assert co.data == khong.data  # prod không được lộ email có tồn tại hay không
    assert len(mail.outbox) == 1 and mail.outbox[0].to == ["co@example.com"]


def test_quen_mat_khau_dev_tra_token_trong_response(client, settings):
    settings.PASSWORD_RESET_RETURN_TOKEN_IN_RESPONSE = True
    UserFactory(email="co@example.com")

    res = client.post("/api/auth/forgot-password/", {"email": "co@example.com"})

    assert res.data["token"] and res.data["token"] in mail.outbox[0].body


def test_quen_mat_khau_tai_khoan_khoa_khong_gui_mail_nhung_phan_hoi_van_giong_nhau(client):
    UserFactory(email="khoa@example.com", is_locked=True)

    res = client.post("/api/auth/forgot-password/", {"email": "khoa@example.com"})

    assert res.status_code == 200 and mail.outbox == []


def test_quen_mat_khau_toi_da_3_lan_moi_15_phut_theo_email(client):
    for _ in range(3):
        assert (
            client.post("/api/auth/forgot-password/", {"email": "a@example.com"}).status_code == 200
        )

    res = client.post("/api/auth/forgot-password/", {"email": "A@Example.com"})  # cùng email
    khac = client.post("/api/auth/forgot-password/", {"email": "b@example.com"})

    assert res.status_code == 429 and res.data["error"]["code"] == "QUA_NHIEU_YEU_CAU"
    assert khac.status_code == 200


# ---------------------------------------------------------------- đặt lại mật khẩu
def _xin_token(client, settings, email="co@example.com"):
    settings.PASSWORD_RESET_RETURN_TOKEN_IN_RESPONSE = True
    return client.post("/api/auth/forgot-password/", {"email": email}).data["token"]


def test_dat_lai_mat_khau_thanh_cong_va_token_chi_dung_mot_lan(client, settings):
    u = UserFactory(username="sv1", email="co@example.com")
    refresh = str(RefreshToken.for_user(u))
    token = _xin_token(client, settings)

    ok = client.post("/api/auth/reset-password/", {"token": token, "new_password": MOI})
    lai = client.post("/api/auth/reset-password/", {"token": token, "new_password": "KhacNua123"})

    assert ok.status_code == 204
    assert lai.status_code == 400 and "token" in lai.data
    assert client.post("/api/auth/login/", {"username": "sv1", "password": MOI}).status_code == 200
    assert client.post("/api/auth/refresh/", {"refresh": refresh}).status_code == 401


def test_dat_lai_mat_khau_token_het_han_sau_30_phut(client, settings, monkeypatch):
    UserFactory(email="co@example.com")
    token = _xin_token(client, settings)
    sau_31_phut = datetime.now() + timedelta(minutes=31)
    monkeypatch.setattr(PasswordResetTokenGenerator, "_now", lambda self: sau_31_phut)

    res = client.post("/api/auth/reset-password/", {"token": token, "new_password": MOI})

    assert res.status_code == 400 and "token" in res.data


def test_dat_lai_mat_khau_token_rac(client):
    for token in ("rac", "abc.def", ""):
        res = client.post("/api/auth/reset-password/", {"token": token, "new_password": MOI})
        assert res.status_code == 400 and "token" in res.data


def test_dat_lai_mat_khau_mat_khau_yeu_bi_tu_choi(client, settings):
    UserFactory(email="co@example.com")
    token = _xin_token(client, settings)

    res = client.post("/api/auth/reset-password/", {"token": token, "new_password": "yeu"})

    assert res.status_code == 400 and "new_password" in res.data


def test_dat_lai_mat_khau_tai_khoan_bi_khoa_sau_khi_xin_token_bi_tu_choi(client, settings):
    u = UserFactory(email="co@example.com")
    token = _xin_token(client, settings)
    u.is_locked = True
    u.save()

    res = client.post("/api/auth/reset-password/", {"token": token, "new_password": MOI})

    assert res.status_code == 400
