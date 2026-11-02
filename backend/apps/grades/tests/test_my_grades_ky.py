"""`grades/my`: có đủ mọi học kỳ SV có đăng ký + học kỳ đang mở; môn/kỳ chưa có điểm chính thức để trống."""

from datetime import date

import pytest

from apps.grades.models import Grade, TrangThaiDiem
from apps.registration.models import Registration
from apps.training.models import TrangThaiHocKy
from core.factories import (
    ClassSectionFactory,
    CourseFactory,
    SemesterFactory,
    StudentProfileFactory,
)

pytestmark = pytest.mark.django_db


def test_ky_dang_hoc_va_ky_mo_hien_du_mon_chua_diem_de_trong(login_as):
    sv = StudentProfileFactory()
    cu = SemesterFactory(
        ten_hk="HK cũ", ngay_bat_dau=date(2025, 9, 1), trang_thai=TrangThaiHocKy.DONG
    )
    dang = SemesterFactory(ten_hk="HK đang học", ngay_bat_dau=date(2026, 9, 1))
    SemesterFactory(ten_hk="HK sau", ngay_bat_dau=date(2027, 2, 1))  # MO, chưa đăng ký gì
    lop_cu = ClassSectionFactory(hoc_ky=cu, mon_hoc=CourseFactory(ma_mon="CU1", tong_tin_chi=3))
    lop_dang = ClassSectionFactory(hoc_ky=dang, mon_hoc=CourseFactory(ma_mon="DANG1"))
    for lop in (lop_cu, lop_dang):
        Registration.objects.create(sinh_vien=sv.user, lop_hoc_phan=lop)
    Grade.objects.create(
        lop_hoc_phan=lop_cu,
        sinh_vien=sv.user,
        diem_tong_ket=8,
        diem_chu="B+",
        gpa_thang_4="3.20",
        trang_thai=TrangThaiDiem.KHOA,
    )

    d = login_as(sv.user).get("/api/grades/my/").data

    assert [s["ten_hk"] for s in d["thong_ke"]] == ["HK cũ", "HK đang học", "HK sau"]
    dang_hoc = d["thong_ke"][1]
    assert (dang_hoc["so_mon"], dang_hoc["tin_chi_dat"], dang_hoc["gpa"]) == (1, None, None)
    assert d["thong_ke"][2]["so_mon"] == 0
    dong = {r["ma_mon"]: r for r in d["diem"]}
    assert dong["CU1"]["diem_chu"] == "B+"
    assert (dong["DANG1"]["diem_chu"], dong["DANG1"]["diem_tong_ket"]) == ("", None)
    assert [r["ma_mon"] for r in d["diem"]] == ["DANG1", "CU1"]  # kỳ mới trước
    assert d["gpa"] == "3.20"  # GPA chỉ tính điểm chính thức
