"""Hồ sơ SV/GV do PĐT quản lý, Admin chỉ đọc (PDT-01, ADM-03)."""

import pytest

from apps.audit.models import AuditLog, HanhDong
from apps.auth.models import Role
from apps.profiles.models import StudentProfile
from apps.training.models import TrangThaiDung
from core.factories import (
    CurriculumFactory,
    FacultyFactory,
    MajorFactory,
    StudentProfileFactory,
    TeacherProfileFactory,
    UserFactory,
)

pytestmark = pytest.mark.django_db
SV = "/api/profiles/students/"
GV = "/api/profiles/teachers/"


@pytest.fixture
def pdt_api(login_as):
    return login_as(UserFactory(role=Role.PHONG_DAO_TAO))


def test_phan_quyen_pdt_ghi_admin_chi_doc_con_lai_bi_chan(login_as):
    sp = StudentProfileFactory()
    admin = login_as(UserFactory(role=Role.ADMIN))
    assert admin.get(SV).status_code == 200
    assert admin.get(f"{SV}{sp.id}/").status_code == 200
    ghi = admin.patch(f"{SV}{sp.id}/", {"ho_ten": "X"})
    assert ghi.status_code == 403 and ghi.data["error"]["code"] == "KHONG_CO_QUYEN"

    for role in (Role.SINH_VIEN, Role.GIAO_VIEN, Role.KE_TOAN):
        assert login_as(UserFactory(role=role)).get(SV).status_code == 403


def test_tao_ho_so_sv_tu_chon_ctdt_hoat_dong_khop_nganh_va_khoa(pdt_api):
    ctdt = CurriculumFactory(khoa_tuyen_sinh="K22")
    CurriculumFactory(
        nganh=ctdt.nganh, khoa_tuyen_sinh="K22", ma_ctdt="CU", trang_thai=TrangThaiDung.NGUNG
    )
    user = UserFactory(role=Role.SINH_VIEN)

    res = pdt_api.post(
        SV,
        {
            "user": user.id,
            "ma_sv": "SV001",
            "ho_ten": "Nguyễn Văn An",
            "nganh": ctdt.nganh_id,
            "khoa_nhap_hoc": "K22",
        },
    )

    assert res.status_code == 201
    assert res.data["ctdt"] == ctdt.id
    assert res.data["ctdt_ma"] == ctdt.ma_ctdt and res.data["nganh_ten"] == ctdt.nganh.ten_nganh
    assert AuditLog.objects.filter(hanh_dong=HanhDong.CREATE, doi_tuong="StudentProfile").exists()


def test_tao_ho_so_sv_khong_co_ctdt_khop_bi_tu_choi(pdt_api):
    nganh = MajorFactory()

    res = pdt_api.post(
        SV,
        {
            "user": UserFactory().id,
            "ma_sv": "SV001",
            "ho_ten": "A",
            "nganh": nganh.id,
            "khoa_nhap_hoc": "K22",
        },
    )

    assert res.status_code == 400 and "ctdt" in res.data


def test_tao_ho_so_sv_ctdt_khac_nganh_bi_tu_choi(pdt_api):
    ctdt = CurriculumFactory()

    res = pdt_api.post(
        SV,
        {
            "user": UserFactory().id,
            "ma_sv": "SV001",
            "ho_ten": "A",
            "nganh": MajorFactory().id,
            "khoa_nhap_hoc": "K22",
            "ctdt": ctdt.id,
        },
    )

    assert res.status_code == 400 and "ctdt" in res.data


def test_tao_ho_so_sv_cho_tai_khoan_sai_vai_tro_hoac_da_co_ho_so(pdt_api):
    ctdt = CurriculumFactory()
    body = {"ma_sv": "SV001", "ho_ten": "A", "nganh": ctdt.nganh_id, "khoa_nhap_hoc": "K22"}

    sai_role = pdt_api.post(SV, {**body, "user": UserFactory(role=Role.GIAO_VIEN).id})
    da_co = StudentProfileFactory(nganh=ctdt.nganh, ctdt=ctdt)
    trung = pdt_api.post(SV, {**body, "user": da_co.user_id, "ma_sv": "SV002"})

    assert sai_role.status_code == 400 and "user" in sai_role.data
    assert trung.status_code == 400 and "user" in trung.data


def test_ma_sv_phai_duy_nhat(pdt_api):
    ctdt = CurriculumFactory()
    StudentProfileFactory(ma_sv="SV001", nganh=ctdt.nganh, ctdt=ctdt)

    res = pdt_api.post(
        SV,
        {
            "user": UserFactory().id,
            "ma_sv": "SV001",
            "ho_ten": "A",
            "nganh": ctdt.nganh_id,
            "khoa_nhap_hoc": "K22",
        },
    )

    assert res.status_code == 400 and "ma_sv" in res.data


def test_sua_ho_so_gpa_va_ma_sv_chi_doc_dong_bo_email(pdt_api):
    sp = StudentProfileFactory(ma_sv="SV001")

    res = pdt_api.patch(
        f"{SV}{sp.id}/",
        {"ho_ten": "Tên mới", "gpa": "4.00", "ma_sv": "SV999", "email": "moi@example.com"},
    )

    assert res.status_code == 200
    sp.refresh_from_db()
    assert (sp.ho_ten, sp.ma_sv, sp.gpa) == ("Tên mới", "SV001", None)
    assert sp.user.email == "moi@example.com"
    assert AuditLog.objects.filter(hanh_dong=HanhDong.UPDATE, doi_tuong="StudentProfile").exists()


def test_doi_nganh_ma_khong_gui_ctdt_thi_tim_lai_ctdt_khop(pdt_api):
    cu = CurriculumFactory()
    moi = CurriculumFactory()
    sp = StudentProfileFactory(nganh=cu.nganh, ctdt=cu)

    res = pdt_api.patch(f"{SV}{sp.id}/", {"nganh": moi.nganh_id})

    assert res.status_code == 200 and res.data["ctdt"] == moi.id


def test_tim_kiem_va_loc_ho_so(pdt_api):
    a = StudentProfileFactory(ma_sv="SV001", ho_ten="Nguyễn Văn An", khoa_nhap_hoc="K21")
    StudentProfileFactory(ma_sv="SV002", ho_ten="Trần Thị Bích", khoa_nhap_hoc="K22")

    theo_ten = pdt_api.get(SV, {"search": "Bích"})
    theo_khoa = pdt_api.get(SV, {"khoa_nhap_hoc": "K21"})

    assert [r["ma_sv"] for r in theo_ten.data["results"]] == ["SV002"]
    assert [r["id"] for r in theo_khoa.data["results"]] == [a.id]


def test_khong_co_xoa_va_put(pdt_api):
    sp = StudentProfileFactory()

    assert pdt_api.delete(f"{SV}{sp.id}/").status_code == 405
    assert StudentProfile.objects.filter(pk=sp.id).exists()


def test_tao_va_sua_ho_so_giao_vien(pdt_api):
    user = UserFactory(role=Role.GIAO_VIEN)

    khoa_a, khoa_b = FacultyFactory(), FacultyFactory(ten_khoa="Khoa CNTT")
    tao = pdt_api.post(
        GV,
        {
            "user": user.id,
            "ma_gv": "GV001",
            "ho_ten": "Đặng Văn Khoa",
            "hoc_vi": "TS",
            "khoa": khoa_a.id,
        },
    )
    sua = pdt_api.patch(f"{GV}{tao.data['id']}/", {"khoa": khoa_b.id})
    sai_role = pdt_api.post(
        GV,
        {
            "user": UserFactory(role=Role.SINH_VIEN).id,
            "ma_gv": "GV002",
            "ho_ten": "X",
            "khoa": khoa_a.id,
        },
    )

    assert (
        tao.status_code == 201
        and sua.status_code == 200
        and sua.data["khoa"] == khoa_b.id
        and sua.data["khoa_ten"] == "Khoa CNTT"
    )
    assert sai_role.status_code == 400 and "user" in sai_role.data


def test_danh_sach_giao_vien(pdt_api):
    TeacherProfileFactory(ma_gv="GV001")

    assert pdt_api.get(GV, {"search": "GV001"}).data["count"] == 1


def test_loc_giao_vien_theo_khoa(pdt_api):
    gv = TeacherProfileFactory()
    TeacherProfileFactory()

    res = pdt_api.get(GV, {"khoa": gv.khoa_id})

    assert [r["id"] for r in res.data["results"]] == [gv.id]


def test_tai_khoan_chua_co_ho_so_chi_sv_gv_va_loc_theo_vai_tro(pdt_api, login_as):
    sv_co = StudentProfileFactory()
    sv_chua = UserFactory(role=Role.SINH_VIEN, username="sv_chua")
    gv_chua = UserFactory(role=Role.GIAO_VIEN, username="gv_chua")
    UserFactory(role=Role.KE_TOAN)  # vai trò không cần hồ sơ
    TeacherProfileFactory()  # GV đã có hồ sơ

    res = pdt_api.get("/api/profiles/pending-accounts/")
    assert res.status_code == 200
    assert {u["username"] for u in res.data["results"]} == {"sv_chua", "gv_chua"}
    assert sv_co.user.username not in str(res.data)

    loc = pdt_api.get("/api/profiles/pending-accounts/?role=GIAO_VIEN")
    assert [u["id"] for u in loc.data["results"]] == [gv_chua.id]
    assert sv_chua.id not in [u["id"] for u in loc.data["results"]]

    assert (
        login_as(UserFactory(role=Role.ADMIN)).get("/api/profiles/pending-accounts/").status_code
        == 200
    )
    assert (
        login_as(UserFactory(role=Role.SINH_VIEN))
        .get("/api/profiles/pending-accounts/")
        .status_code
        == 403
    )
