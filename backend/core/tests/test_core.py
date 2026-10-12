"""Hạ tầng dùng chung của Pha 0: envelope lỗi, phân trang, middleware Idempotency, IP client, Swagger."""

import pytest
from django.core.management import call_command
from django.test import RequestFactory

from apps.auth.models import Role
from core.factories import UserFactory
from core.utils import client_ip

pytestmark = pytest.mark.django_db


# ---- envelope lỗi (plan mục 8.4) ---------------------------------------------
def test_loi_nghiep_vu_dung_envelope_code_message(login_as):
    res = login_as(UserFactory(role=Role.SINH_VIEN)).get("/api/users/")

    assert res.status_code == 403
    assert set(res.data) == {"error"}
    assert set(res.data["error"]) == {"code", "message"}
    assert res.data["error"]["code"] == "KHONG_CO_QUYEN"


def test_loi_validation_field_giu_nguyen_dang_drf(client):
    res = client.post("/api/auth/login/", {})

    assert res.status_code == 400
    assert set(res.data) == {"username", "password"}


def test_loi_rate_limit_co_envelope_retry_after_va_header(client):
    for _ in range(10):
        client.post("/api/auth/login/", {"username": "x", "password": "y"})

    res = client.post("/api/auth/login/", {"username": "x", "password": "y"})

    assert res.status_code == 429
    assert res.data["error"]["code"] == "QUA_NHIEU_YEU_CAU"
    assert res.data["error"]["details"]["retry_after"] > 0
    assert int(res["Retry-After"]) > 0


# ---- phân trang: mặc định 25, tối đa 50 (mục 8.2) ------------------------------
def test_phan_trang_mac_dinh_25_toi_da_50(login_as):
    UserFactory.create_batch(54)  # + admin = 55
    admin = login_as(UserFactory(role=Role.ADMIN))

    mac_dinh = admin.get("/api/users/")
    vuot = admin.get("/api/users/", {"page_size": 100})

    assert mac_dinh.data["count"] == 55 and len(mac_dinh.data["results"]) == 25
    assert len(vuot.data["results"]) == 50


# ---- middleware Idempotency-Key (mục 8.3) ----------------------------------
def test_dang_ky_mon_bat_buoc_idempotency_key(client):
    res = client.post("/api/registrations/", {})

    assert res.status_code == 400
    assert "Idempotency-Key" in res.json()  # JsonResponse của middleware, chưa qua DRF


def test_idempotency_key_duoc_echo_lai_trong_header(client):
    res = client.post(
        "/api/registrations/", {}, HTTP_IDEMPOTENCY_KEY="3f2c1b6e-0000-4000-8000-000000000001"
    )

    assert res["Idempotency-Key"] == "3f2c1b6e-0000-4000-8000-000000000001"
    assert res.status_code != 400  # qua middleware (endpoint chưa có ở Pha 1 nên 404)


def test_thanh_toan_nhan_key_nhung_khong_bat_buoc(client):
    res = client.post("/api/tuition/payments/", {})

    assert res.status_code != 400 or "Idempotency-Key" not in res.data


# ---- IP client / rate limit không bị lách (NUM_PROXIES) ------------------------
def test_ip_client_bo_qua_x_forwarded_for_khi_khong_co_proxy_tin_cay():
    req = RequestFactory().get("/", HTTP_X_FORWARDED_FOR="1.1.1.1, 2.2.2.2", REMOTE_ADDR="9.9.9.9")

    assert client_ip(req) == "9.9.9.9"


def test_ip_client_lay_dia_chi_do_proxy_cuoi_ghi_khi_sau_nginx(settings):
    settings.REST_FRAMEWORK = {**settings.REST_FRAMEWORK, "NUM_PROXIES": 1}
    req = RequestFactory().get("/", HTTP_X_FORWARDED_FOR="1.1.1.1, 2.2.2.2", REMOTE_ADDR="9.9.9.9")

    assert client_ip(req) == "2.2.2.2"  # phần tử đầu (1.1.1.1) do client tự điền → không tin


def test_doi_x_forwarded_for_khong_lach_duoc_gioi_han_dang_nhap(client):
    for i in range(10):
        client.post(
            "/api/auth/login/",
            {"username": "x", "password": "y"},
            HTTP_X_FORWARDED_FOR=f"10.0.0.{i}",
        )

    res = client.post(
        "/api/auth/login/", {"username": "x", "password": "y"}, HTTP_X_FORWARDED_FOR="10.9.9.9"
    )

    assert res.status_code == 429


# ---- Swagger -----------------------------------------------------------------
def test_openapi_schema_hop_le_khong_canh_bao(tmp_path):
    call_command("spectacular", "--validate", "--fail-on-warn", "--file", str(tmp_path / "s.yml"))

    text = (tmp_path / "s.yml").read_text(encoding="utf-8")
    assert "/api/auth/login/" in text and "jwtAuth" in text
