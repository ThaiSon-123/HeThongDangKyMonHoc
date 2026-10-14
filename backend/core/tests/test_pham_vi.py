"""Phạm vi dữ liệu (BR-23): GV chỉ lớp mình, SV chỉ dữ liệu của mình — mọi endpoint theo lớp/theo SV."""

from datetime import date

import pytest

from apps.attendance.models import Attendance, AttendanceRequest, AttendanceSession
from apps.registration.models import Registration
from apps.training.models import TrangThaiLop
from core.factories import ClassSectionFactory, StudentProfileFactory

pytestmark = pytest.mark.django_db


@pytest.fixture
def lop_cua_gv_a():
    lop = ClassSectionFactory(
        trang_thai=TrangThaiLop.DANG_HOC,
        ngay_bat_dau=date(2020, 9, 1),
        ngay_ket_thuc=date(2020, 12, 1),
    )
    sv = StudentProfileFactory()
    Registration.objects.create(sinh_vien=sv.user, lop_hoc_phan=lop)
    buoi = AttendanceSession.objects.create(
        lop_hoc_phan=lop, ngay_hoc=date(2020, 9, 3), buoi="SANG", tiet_bat_dau=1
    )
    diem_danh = Attendance.objects.create(
        attendance_session=buoi,
        lop_hoc_phan=lop,
        ngay_hoc=buoi.ngay_hoc,
        sinh_vien=sv.user,
        trang_thai="VANG_KHONG_PHEP",
    )
    yeu_cau = AttendanceRequest.objects.create(
        attendance=diem_danh, sinh_vien=sv.user, ly_do="Ốm", trang_thai_mong_muon="CO_MAT"
    )
    return lop, sv, buoi, yeu_cau


def test_gv_khac_khong_dung_duoc_lop_cua_gv_a(login_as, lop_cua_gv_a):
    lop, _, buoi, yeu_cau = lop_cua_gv_a
    gv_b = login_as(ClassSectionFactory().giao_vien.user)
    gv_a = login_as(lop.giao_vien.user)
    gv_b_endpoints = [
        ("get", f"/api/class-sections/{lop.id}/"),
        ("get", f"/api/class-sections/{lop.id}/students/"),
        ("get", f"/api/class-sections/{lop.id}/export/"),
        ("get", f"/api/class-sections/{lop.id}/grades/"),
        ("put", f"/api/class-sections/{lop.id}/grades/"),
        ("post", f"/api/class-sections/{lop.id}/grades/lock/"),
        ("get", f"/api/attendance/sessions/{buoi.id}/records/"),
        ("put", f"/api/attendance/sessions/{buoi.id}/records/"),
        ("patch", f"/api/attendance/requests/{yeu_cau.id}/"),
        ("get", f"/api/attendance/requests/{yeu_cau.id}/minh-chung/"),
    ]
    for method, url in gv_b_endpoints:
        kw = (
            {} if method == "get" else {"data": {"records": [], "action": "lock"}, "format": "json"}
        )
        res = getattr(gv_b, method)(url, **kw)
        assert res.status_code in (403, 404), f"GV khác {method.upper()} {url} → {res.status_code}"
    # Danh sách của GV khác không lẫn lớp của GV A.
    assert gv_b.get("/api/class-sections/my/").data["count"] == 1
    assert (
        gv_b.get(f"/api/attendance/requests/?attendance__lop_hoc_phan={lop.id}").data["count"] == 0
    )
    assert gv_a.get(f"/api/class-sections/{lop.id}/students/").status_code == 200  # đối chứng


def test_sv_khac_khong_thay_du_lieu_sv_a(login_as, lop_cua_gv_a):
    lop, sv_a, buoi, yeu_cau = lop_cua_gv_a
    sv_b = login_as(StudentProfileFactory().user)
    assert sv_b.get(f"/api/attendance/requests/{yeu_cau.id}/minh-chung/").status_code in (403, 404)
    assert sv_b.get("/api/attendance/requests/").data["count"] == 0
    assert sv_b.get("/api/attendance/my/").data["lop_hoc_phan"] == []
    assert sv_b.get("/api/registrations/history/").data["count"] == 0
    assert sv_b.get("/api/grades/my/").data["diem"] == []
    assert login_as(sv_a.user).get("/api/attendance/requests/").data["count"] == 1  # đối chứng
