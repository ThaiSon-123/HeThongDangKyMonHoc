"""Đổi / quên / đặt lại mật khẩu: chính sách, blacklist, không lộ email, rate limit, mã xác thực 6 số."""

import pytest
from django.core import mail
from django.core.cache import cache
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
def test_quen_mat_khau_email_khong_ton_tai_bao_loi(client):
    UserFactory(email="co@example.com")

    co = client.post("/api/auth/forgot-password/", {"email": "co@example.com"})
    khong = client.post("/api/auth/forgot-password/", {"email": "khongco@example.com"})

    assert co.status_code == 200 and "code" not in co.data  # prod không trả mã
    assert khong.status_code == 400 and "email" in khong.data
    assert len(mail.outbox) == 1 and mail.outbox[0].to == ["co@example.com"]


def test_quen_mat_khau_dev_tra_ma_trong_response_va_mail_co_ma_6_so(client, settings):
    settings.PASSWORD_RESET_RETURN_TOKEN_IN_RESPONSE = True
    UserFactory(email="co@example.com")

    res = client.post("/api/auth/forgot-password/", {"email": "co@example.com"})

    code = res.data["code"]
    assert len(code) == 6 and code.isdigit()
    assert code in mail.outbox[0].body and code in mail.outbox[0].alternatives[0][0]


def test_quen_mat_khau_tai_khoan_khoa_bao_loi_khong_gui_mail(client):
    UserFactory(email="khoa@example.com", is_locked=True)

    res = client.post("/api/auth/forgot-password/", {"email": "khoa@example.com"})

    assert res.status_code == 400 and "bị khóa" in res.data["email"][0] and mail.outbox == []


def test_quen_mat_khau_toi_da_3_lan_moi_15_phut_theo_email(client):
    UserFactory(email="a@example.com")
    UserFactory(email="b@example.com")
    for _ in range(3):
        assert (
            client.post("/api/auth/forgot-password/", {"email": "a@example.com"}).status_code == 200
        )

    res = client.post("/api/auth/forgot-password/", {"email": "A@Example.com"})  # cùng email
    khac = client.post("/api/auth/forgot-password/", {"email": "b@example.com"})

    assert res.status_code == 429 and res.data["error"]["code"] == "QUA_NHIEU_YEU_CAU"
    assert khac.status_code == 200


# ---------------------------------------------------------------- đặt lại mật khẩu
EMAIL = "co@example.com"


def _xin_ma(client, settings, email=EMAIL):
    settings.PASSWORD_RESET_RETURN_TOKEN_IN_RESPONSE = True
    return client.post("/api/auth/forgot-password/", {"email": email}).data["code"]


def _dat_lai(client, code, mat_khau=MOI, email=EMAIL):
    return client.post(
        "/api/auth/reset-password/", {"email": email, "code": code, "new_password": mat_khau}
    )


def _ma_sai(code):
    return f"{(int(code) + 1) % 10**6:06d}"


def test_dat_lai_mat_khau_thanh_cong_va_ma_chi_dung_mot_lan(client, settings):
    u = UserFactory(username="sv1", email=EMAIL)
    refresh = str(RefreshToken.for_user(u))
    code = _xin_ma(client, settings)

    ok = _dat_lai(client, code)
    lai = _dat_lai(client, code, "KhacNua123")

    assert ok.status_code == 204
    assert lai.status_code == 400 and "code" in lai.data
    assert client.post("/api/auth/login/", {"username": "sv1", "password": MOI}).status_code == 200
    assert client.post("/api/auth/refresh/", {"refresh": refresh}).status_code == 401


def test_dat_lai_mat_khau_email_khong_phan_biet_hoa_thuong(client, settings):
    UserFactory(username="sv1", email=EMAIL)
    code = _xin_ma(client, settings)

    assert _dat_lai(client, code, email="Co@Example.com").status_code == 204


def test_dat_lai_mat_khau_ma_het_han(client, settings):
    UserFactory(email=EMAIL)
    code = _xin_ma(client, settings)
    cache.clear()  # cache hết TTL 30 phút

    res = _dat_lai(client, code)

    assert res.status_code == 400 and "code" in res.data


def test_dat_lai_mat_khau_sai_5_lan_thi_ma_bi_huy(client, settings):
    UserFactory(email=EMAIL)
    code = _xin_ma(client, settings)

    for _ in range(5):
        assert _dat_lai(client, _ma_sai(code)).status_code == 400

    assert _dat_lai(client, code).status_code == 400  # đúng mã nhưng đã bị hủy


def test_dat_lai_mat_khau_ma_cua_email_khac_khong_dung_duoc(client, settings):
    UserFactory(email=EMAIL)
    UserFactory(email="khac@example.com")
    code = _xin_ma(client, settings)

    assert _dat_lai(client, code, email="khac@example.com").status_code == 400


def test_dat_lai_mat_khau_ma_rac(client):
    for code in ("rac", "12345", "1234567", ""):
        res = _dat_lai(client, code)
        assert res.status_code == 400 and "code" in res.data


def test_dat_lai_mat_khau_mat_khau_yeu_bi_tu_choi(client, settings):
    UserFactory(email=EMAIL)
    code = _xin_ma(client, settings)

    res = _dat_lai(client, code, "yeu")

    assert res.status_code == 400 and "new_password" in res.data


def test_dat_lai_mat_khau_tai_khoan_bi_khoa_sau_khi_xin_ma_bi_tu_choi(client, settings):
    u = UserFactory(email=EMAIL)
    code = _xin_ma(client, settings)
    u.is_locked = True
    u.save()

    assert _dat_lai(client, code).status_code == 400
