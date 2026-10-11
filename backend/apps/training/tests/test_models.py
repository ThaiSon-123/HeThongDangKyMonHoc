"""Ràng buộc DB của model đào tạo + điểm danh theo plan.md mục 5."""

from datetime import UTC, date, datetime

import pytest
from django.core.management import call_command
from django.db import IntegrityError, transaction

from apps.attendance.models import Attendance, AttendanceRequest, AttendanceSession
from apps.training.models import ClassSection, Faculty, Semester
from core.factories import StudentProfileFactory

pytestmark = pytest.mark.django_db


def _hk(**kw):
    return Semester.objects.create(
        ten_hk=kw.pop("ten_hk", "HK1"),
        nam_hoc="2025-2026",
        ngay_bat_dau=date(2025, 9, 1),
        ngay_ket_thuc=date(2026, 1, 10),
        cua_so_dk_bat_dau=datetime(2025, 8, 1, tzinfo=UTC),
        cua_so_dk_ket_thuc=datetime(2025, 8, 20, tzinfo=UTC),
        **kw,
    )


def test_hoc_ky_mac_dinh_tran_tin_chi_12_24_14():
    hk = _hk()

    assert (hk.tin_chi_toi_thieu, hk.tin_chi_toi_da, hk.tin_chi_toi_da_canh_bao) == (12, 24, 14)


@pytest.mark.parametrize(
    "kw",
    [
        {"tin_chi_toi_thieu": 0},
        {"tin_chi_toi_thieu": 25},  # > tối đa
        {"tin_chi_toi_da_canh_bao": 25},  # > tối đa
    ],
)
def test_hoc_ky_chan_tran_tin_chi_sai(kw):
    with pytest.raises(IntegrityError), transaction.atomic():
        _hk(**kw)


def test_moi_buoi_chi_co_mot_yeu_cau_cho_duyet():
    sv = StudentProfileFactory().user
    seed_lop = _seed_lop()
    ss = AttendanceSession.objects.create(
        lop_hoc_phan=seed_lop, ngay_hoc=date(2025, 9, 8), buoi="SANG", tiet_bat_dau=1
    )
    dd = Attendance.objects.create(
        attendance_session=ss, lop_hoc_phan=seed_lop, ngay_hoc=ss.ngay_hoc, sinh_vien=sv
    )
    kw = {"attendance": dd, "sinh_vien": sv, "ly_do": "Ốm", "trang_thai_mong_muon": "VANG_CO_PHEP"}
    AttendanceRequest.objects.create(**kw)

    with pytest.raises(IntegrityError), transaction.atomic():
        AttendanceRequest.objects.create(**kw)
    # đã xử lý thì được gửi lại
    AttendanceRequest.objects.update(trang_thai="TU_CHOI")
    AttendanceRequest.objects.create(**kw)


def _seed_lop():
    call_command("seed_demo")
    return ClassSection.objects.get(ma_lop="IT2010.L01-HK1")


def test_seed_tao_khoa_va_chay_lai_an_toan():
    call_command("seed_demo")
    call_command("seed_demo")

    assert Faculty.objects.filter(ma_khoa__in=["CNTT", "KT"]).count() == 2
