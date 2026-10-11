"""Quản lý tài khoản của Admin (ADM-02): tạo, sửa, khóa, reset mật khẩu, audit."""

import pytest
from rest_framework_simplejwt.tokens import RefreshToken

from apps.audit.models import AuditLog, HanhDong
from apps.auth.models import Role, User
from core.factories import MAT_KHAU, UserFactory

pytestmark = pytest.mark.django_db
URL = "/api/users/"
MOI = "MatKhauMoi99"


@pytest.fixture
def admin_api(login_as):
    admin = UserFactory(role=Role.ADMIN, username="admin")
    return login_as(admin), admin


def test_chi_admin_duoc_quan_ly_tai_khoan(login_as):
    for role in (Role.PHONG_DAO_TAO, Role.SINH_VIEN, Role.GIAO_VIEN, Role.KE_TOAN):
        res = login_as(UserFactory(role=role)).get(URL)
        assert res.status_code == 403 and res.data["error"]["code"] == "KHONG_CO_QUYEN"


def test_admin_tao_tai_khoan_va_dang_nhap_duoc(admin_api, client):
    api, admin = admin_api

    res = api.post(
        URL,
        {
            "username": "gv9",
            "password": MOI,
            "role": Role.GIAO_VIEN,
            "email": "gv9@example.com",
            "full_name": "Trần Giáo",
        },
    )

    assert res.status_code == 201
    assert res.data["role"] == Role.GIAO_VIEN and "password" not in res.data
    assert client.post("/api/auth/login/", {"username": "gv9", "password": MOI}).status_code == 200
    log = AuditLog.objects.get(hanh_dong=HanhDong.CREATE, doi_tuong="User")
    assert log.user_id == admin.id


def test_tao_tai_khoan_ap_dung_chinh_sach_mat_khau_va_chong_trung_username(admin_api):
    api, _ = admin_api
    UserFactory(username="trung")

    yeu = api.post(URL, {"username": "moi", "password": "yeu", "role": Role.SINH_VIEN})
    trung = api.post(URL, {"username": "trung", "password": MOI, "role": Role.SINH_VIEN})

    assert yeu.status_code == 400 and "password" in yeu.data
    assert trung.status_code == 400 and "username" in trung.data


def test_role_la_enum_cung_khong_nhan_gia_tri_la(admin_api):
    api, _ = admin_api

    res = api.post(URL, {"username": "x", "password": MOI, "role": "SUPER_ADMIN"})

    assert res.status_code == 400 and "role" in res.data


def test_danh_sach_loc_theo_role_va_tim_kiem(admin_api):
    api, _ = admin_api
    UserFactory(role=Role.KE_TOAN, username="kt_an")
    UserFactory(role=Role.SINH_VIEN, username="sv_binh")

    kt = api.get(URL, {"role": Role.KE_TOAN})
    tim = api.get(URL, {"search": "binh"})

    assert [u["username"] for u in kt.data["results"]] == ["kt_an"]
    assert [u["username"] for u in tim.data["results"]] == ["sv_binh"]


def test_khoa_va_mo_khoa_tai_khoan(admin_api, client):
    api, _ = admin_api
    u = UserFactory(username="sv1")

    khoa = api.patch(f"{URL}{u.id}/lock/", {"is_locked": True})
    bi_chan = client.post("/api/auth/login/", {"username": "sv1", "password": MAT_KHAU})
    mo = api.patch(f"{URL}{u.id}/lock/", {"is_locked": False})
    dang_nhap = client.post("/api/auth/login/", {"username": "sv1", "password": MAT_KHAU})

    assert khoa.status_code == 200 and khoa.data["is_locked"] is True
    assert bi_chan.status_code == 403
    assert mo.status_code == 200 and dang_nhap.status_code == 200


def test_admin_khong_tu_khoa_chinh_minh(admin_api):
    api, admin = admin_api

    res = api.patch(f"{URL}{admin.id}/lock/", {"is_locked": True})

    assert res.status_code == 409
    assert res.data["error"]["code"] == "TRANG_THAI_KHONG_HOP_LE"


def test_doi_role_ghi_audit_phan_quyen_va_khong_tu_doi_role_cua_minh(admin_api):
    api, admin = admin_api
    u = UserFactory(role=Role.SINH_VIEN)

    ok = api.patch(f"{URL}{u.id}/", {"role": Role.KE_TOAN})
    tu_doi = api.patch(f"{URL}{admin.id}/", {"role": Role.SINH_VIEN})

    assert ok.status_code == 200 and User.objects.get(pk=u.id).role == Role.KE_TOAN
    assert AuditLog.objects.filter(hanh_dong=HanhDong.PHAN_QUYEN, doi_tuong_id=str(u.id)).exists()
    assert tu_doi.status_code == 409


def test_patch_khong_doi_duoc_mat_khau(admin_api):
    api, _ = admin_api
    u = UserFactory()

    api.patch(f"{URL}{u.id}/", {"password": MOI, "first_name": "Tên mới"})

    u.refresh_from_db()
    assert u.check_password(MAT_KHAU)


def test_khong_co_xoa_va_put(admin_api):
    api, _ = admin_api
    u = UserFactory()

    assert api.delete(f"{URL}{u.id}/").status_code == 405
    assert api.put(f"{URL}{u.id}/", {}).status_code == 405


def test_reset_mat_khau_dat_mat_khau_moi_va_thu_hoi_refresh_cu(admin_api, client):
    api, _ = admin_api
    u = UserFactory(username="sv1")
    refresh = str(RefreshToken.for_user(u))

    res = api.post(f"{URL}{u.id}/reset-password/", {"new_password": MOI})

    assert res.status_code == 204
    assert client.post("/api/auth/login/", {"username": "sv1", "password": MOI}).status_code == 200
    assert client.post("/api/auth/refresh/", {"refresh": refresh}).status_code == 401


def test_reset_mat_khau_ap_dung_chinh_sach(admin_api):
    api, _ = admin_api
    u = UserFactory()

    res = api.post(f"{URL}{u.id}/reset-password/", {"new_password": "yeu"})

    assert res.status_code == 400 and "new_password" in res.data


def test_createsuperuser_tao_tai_khoan_admin_dung_duoc_api():
    root = User.objects.create_superuser("root", password=MOI)

    assert root.role == Role.ADMIN and root.is_superuser


def test_danh_sach_cho_biet_tai_khoan_nao_con_thieu_ho_so(admin_api):
    from core.factories import StudentProfileFactory, TeacherProfileFactory

    api, _ = admin_api
    co_hs = StudentProfileFactory(
        user__username="sv_co", ho_ten="Trần Hoàng Nam", khoa_nhap_hoc="K23"
    )
    gv = TeacherProfileFactory(user__username="gv_co", khoa__ten_khoa="CNTT", hoc_vi="ThS")
    UserFactory(role=Role.SINH_VIEN, username="sv_chua", first_name="")
    UserFactory(role=Role.KE_TOAN, username="kt_1")

    rows = {r["username"]: r for r in api.get(URL, {"page_size": 50}).data["results"]}

    assert rows["sv_co"]["has_profile"] is True
    assert rows["sv_co"]["full_name"] == co_hs.user.first_name  # first_name ưu tiên
    assert rows["sv_co"]["profile"]["khoa_nhap_hoc"] == "K23"
    assert rows["sv_chua"]["has_profile"] is False and rows["sv_chua"]["profile"] is None
    assert rows["sv_chua"]["full_name"] == ""
    assert rows["gv_co"]["profile"] == {
        "ma_gv": gv.ma_gv,
        "ho_ten": gv.ho_ten,
        "khoa": "CNTT",
        "hoc_vi": "ThS",
    }
    assert rows["kt_1"]["has_profile"] is None  # vai trò không cần hồ sơ


def test_danh_sach_tai_khoan_khong_bi_n_cong_1_truy_van(admin_api, django_assert_max_num_queries):
    from core.factories import StudentProfileFactory

    api, _ = admin_api
    for _ in range(30):
        StudentProfileFactory()

    with django_assert_max_num_queries(8):
        assert api.get(URL, {"page_size": 50}).status_code == 200
