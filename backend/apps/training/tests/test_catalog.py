"""Khoa/viện, ngành, CTĐT, môn, tiên quyết (PDT-02..05)."""

import pytest

from apps.audit.models import AuditLog, HanhDong
from apps.auth.models import Role
from apps.training.models import TrangThaiDung
from core.factories import (
    CourseFactory,
    CurriculumFactory,
    FacultyFactory,
    MajorFactory,
    TeacherProfileFactory,
    UserFactory,
)

pytestmark = pytest.mark.django_db


@pytest.fixture
def pdt(login_as):
    return login_as(UserFactory(role=Role.PHONG_DAO_TAO))


@pytest.mark.parametrize(
    "url",
    ["faculties", "majors", "curriculums", "curriculum-courses", "courses", "prerequisites"]
    + ["semesters", "class-sections", "schedules"],
)
def test_chi_pdt_duoc_truy_cap(login_as, url):
    # Kế toán đọc được học kỳ / ngành / lớp học phần (để lập giá, thu phí); ghi thì không.
    kt_doc = {"semesters", "majors", "class-sections"}
    for role in (Role.ADMIN, Role.SINH_VIEN, Role.GIAO_VIEN, Role.KE_TOAN):
        api = login_as(UserFactory(role=role))
        res = api.get(f"/api/{url}/")
        if role == Role.KE_TOAN and url in kt_doc:
            assert res.status_code == 200
            assert api.post(f"/api/{url}/", {}).status_code == 403
        else:
            assert res.status_code == 403 and res.data["error"]["code"] == "KHONG_CO_QUYEN"


def test_khoa_tao_sua_ghi_audit_va_khong_xoa(pdt):
    res = pdt.post("/api/faculties/", {"ma_khoa": "CNTT", "ten_khoa": "Công nghệ thông tin"})
    assert res.status_code == 201
    fid = res.data["id"]
    assert pdt.patch(f"/api/faculties/{fid}/", {"ten_khoa": "CNTT & TT"}).status_code == 200
    assert pdt.delete(f"/api/faculties/{fid}/").status_code == 405
    assert AuditLog.objects.filter(doi_tuong="Faculty", hanh_dong=HanhDong.CREATE).exists()
    assert AuditLog.objects.filter(doi_tuong="Faculty", hanh_dong=HanhDong.UPDATE).exists()


def test_ngung_khoa_bi_chan_khi_con_nganh_hoac_giao_vien_hoat_dong(pdt):
    khoa = FacultyFactory()
    nganh = MajorFactory(khoa=khoa)
    res = pdt.patch(f"/api/faculties/{khoa.id}/", {"trang_thai": "NGUNG"})
    assert res.status_code == 409 and res.data["error"]["code"] == "TRANG_THAI_KHONG_HOP_LE"

    nganh.trang_thai = TrangThaiDung.NGUNG
    nganh.save()
    gv = TeacherProfileFactory(khoa=khoa)
    assert pdt.patch(f"/api/faculties/{khoa.id}/", {"trang_thai": "NGUNG"}).status_code == 409

    gv.user.is_locked = True
    gv.user.save()
    assert pdt.patch(f"/api/faculties/{khoa.id}/", {"trang_thai": "NGUNG"}).status_code == 200
    assert pdt.patch(f"/api/faculties/{khoa.id}/", {"trang_thai": "HOAT_DONG"}).status_code == 200


def test_nganh_khong_gan_vao_khoa_da_ngung(pdt):
    khoa = FacultyFactory(trang_thai=TrangThaiDung.NGUNG)
    res = pdt.post("/api/majors/", {"ma_nganh": "X", "ten_nganh": "X", "khoa": khoa.id})
    assert res.status_code == 400 and "khoa" in res.data


def test_loc_nganh_theo_khoa(pdt):
    khoa = FacultyFactory()
    MajorFactory(khoa=khoa)
    MajorFactory()
    res = pdt.get(f"/api/majors/?khoa={khoa.id}")
    assert res.data["count"] == 1


def test_ctdt_chi_mot_hoat_dong_moi_nganh_khoa(pdt):
    ct = CurriculumFactory(khoa_tuyen_sinh="K22")
    body = {
        "ma_ctdt": "MOI",
        "nganh": ct.nganh_id,
        "khoa_tuyen_sinh": "K22",
        "tong_tin_chi_yeu_cau": 120,
    }
    res = pdt.post("/api/curriculums/", body)
    assert res.status_code == 400  # DRF dịch UniqueConstraint có điều kiện

    ok = pdt.post("/api/curriculums/", {**body, "trang_thai": "NGUNG"})
    assert ok.status_code == 201
    kich_hoat = pdt.patch(f"/api/curriculums/{ok.data['id']}/", {"trang_thai": "HOAT_DONG"})
    assert kich_hoat.status_code == 400

    pdt.patch(f"/api/curriculums/{ct.id}/", {"trang_thai": "NGUNG"})
    assert (
        pdt.patch(f"/api/curriculums/{ok.data['id']}/", {"trang_thai": "HOAT_DONG"}).status_code
        == 200
    )


def test_mon_hoc_tong_tin_chi_do_server_tinh(pdt):
    khoa = FacultyFactory()
    res = pdt.post(
        "/api/courses/",
        {
            "ma_mon": "IT1",
            "ten_mon": "Lập trình",
            "tin_chi_ly_thuyet": 2,
            "tin_chi_thuc_hanh": 1,
            "khoa": khoa.id,
        },
    )
    assert res.status_code == 201 and res.data["tong_tin_chi"] == 3
    sua = pdt.patch(f"/api/courses/{res.data['id']}/", {"tin_chi_thuc_hanh": 2})
    assert sua.data["tong_tin_chi"] == 4

    khong = pdt.post(
        "/api/courses/",
        {
            "ma_mon": "IT0",
            "ten_mon": "0",
            "tin_chi_ly_thuyet": 0,
            "tin_chi_thuc_hanh": 0,
            "khoa": khoa.id,
        },
    )
    assert khong.status_code == 400


def test_loc_mon_theo_khoa_va_nganh_qua_ctdt(pdt):
    ct = CurriculumFactory()
    mon_a, mon_b = CourseFactory(), CourseFactory()
    r = pdt.post(
        "/api/curriculum-courses/", {"ctdt": ct.id, "mon_hoc": mon_a.id, "hoc_ky_goi_y": 1}
    )
    assert r.status_code == 201
    # gán trùng môn trong cùng CTĐT bị chặn
    assert (
        pdt.post("/api/curriculum-courses/", {"ctdt": ct.id, "mon_hoc": mon_a.id}).status_code
        == 400
    )

    res = pdt.get(f"/api/courses/?nganh={ct.nganh_id}")
    assert [m["id"] for m in res.data["results"]] == [mon_a.id]
    res = pdt.get(f"/api/courses/?khoa={mon_b.khoa_id}")
    assert [m["id"] for m in res.data["results"]] == [mon_b.id]


def test_curriculum_course_sua_khong_doi_mon_va_xoa_duoc(pdt):
    ct = CurriculumFactory()
    mon, khac = CourseFactory(), CourseFactory()
    cc = pdt.post("/api/curriculum-courses/", {"ctdt": ct.id, "mon_hoc": mon.id}).data
    sua = pdt.patch(
        f"/api/curriculum-courses/{cc['id']}/",
        {"mon_hoc": khac.id, "khoi_kien_thuc": "tu_chon", "loai_mon": "tu_chon"},
    )
    assert sua.status_code == 200 and sua.data["mon_hoc"] == mon.id
    assert sua.data["khoi_kien_thuc"] == "tu_chon"
    assert pdt.delete(f"/api/curriculum-courses/{cc['id']}/").status_code == 204


def test_tien_quyet_chan_tu_tham_chieu_va_chu_trinh(pdt):
    a, b, c = CourseFactory(), CourseFactory(), CourseFactory()
    tao = lambda mon, tq: pdt.post(  # noqa: E731
        "/api/prerequisites/", {"mon_hoc": mon.id, "mon_tien_quyet": tq.id}
    )
    assert tao(b, a).status_code == 201  # b cần a
    assert tao(c, b).status_code == 201  # c cần b
    assert tao(a, a).status_code == 400
    assert tao(b, a).status_code == 400  # trùng cặp
    assert tao(a, c).status_code == 400  # a cần c → a→c→b→a: chu trình
    assert tao(a, b).status_code == 400  # chu trình trực tiếp
    kep = tao(c, a)  # c cần a: đường chéo, không chu trình
    assert kep.status_code == 201
    assert pdt.delete(f"/api/prerequisites/{kep.data['id']}/").status_code == 204
    assert pdt.patch(f"/api/prerequisites/{kep.data['id']}/", {}).status_code == 405


def test_khoa_va_nganh_tra_so_luong_dang_hoat_dong(pdt):
    khoa = FacultyFactory()
    MajorFactory(khoa=khoa)
    MajorFactory(khoa=khoa, trang_thai=TrangThaiDung.NGUNG)
    CourseFactory(khoa=khoa)
    TeacherProfileFactory(khoa=khoa)
    gv_khoa = TeacherProfileFactory(khoa=khoa)
    gv_khoa.user.is_locked = True
    gv_khoa.user.save()

    ds = pdt.get(f"/api/faculties/?search={khoa.ma_khoa}").data["results"][0]
    assert (ds["so_nganh"], ds["so_giao_vien"], ds["so_mon"]) == (1, 1, 1)
    chi_tiet = pdt.get(f"/api/faculties/{khoa.id}/").data
    assert (chi_tiet["so_nganh"], chi_tiet["so_giao_vien"], chi_tiet["so_mon"]) == (1, 1, 1)

    nganh = pdt.get(f"/api/majors/?khoa={khoa.id}").data["results"]
    assert sorted(n["so_ctdt"] for n in nganh) == [0, 0]
    CurriculumFactory(nganh_id=nganh[0]["id"])
    assert pdt.get(f"/api/majors/{nganh[0]['id']}/").data["so_ctdt"] == 1
