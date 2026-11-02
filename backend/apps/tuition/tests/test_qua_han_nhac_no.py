"""Học phí quá hạn → không xem được TKB; Kế toán gửi mail nhắc đóng học phí; đăng ký lấy kỳ MỞ mới nhất."""

import uuid
from datetime import timedelta

import pytest
from django.core import mail
from django.utils import timezone

from apps.auth.models import Role
from apps.training.services import hoc_ky_dang_ky
from apps.tuition.models import TuitionConfig
from apps.tuition.tests.test_installments import hoc_phi, thu_tien
from core.factories import SemesterFactory, StudentProfileFactory, UserFactory

pytestmark = pytest.mark.django_db
TKB = "/api/timetable/my/"
REMIND = "/api/tuition/remind/"


def hoc_ky(bat_dau_cach=-30, han_cach=-1, **kw):
    """Học kỳ bắt đầu `bat_dau_cach` ngày so với hôm nay, hạn đóng học phí `han_cach` ngày."""
    hom_nay = timezone.localdate()
    hk = SemesterFactory(
        ngay_bat_dau=hom_nay + timedelta(days=bat_dau_cach),
        ngay_ket_thuc=hom_nay + timedelta(days=bat_dau_cach + 120),
        **kw,
    )
    TuitionConfig.objects.create(hoc_ky=hk, han_dong=hom_nay + timedelta(days=han_cach))
    return hk


# --------------------------------------------------------------- chặn xem TKB


def test_qua_han_khong_xem_duoc_tkb_ky_da_bat_dau(login_as):
    hk, sv = hoc_ky(), StudentProfileFactory()
    hoc_phi(sv, hk, 1_500_000)

    res = login_as(sv.user).get(f"{TKB}?hoc_ky={hk.id}")

    assert res.status_code == 403 and res.data["error"]["code"] == "HOC_PHI_QUA_HAN"
    assert "1.500.000 ₫" in res.data["error"]["message"]


def test_chua_den_han_hoac_da_dong_du_thi_xem_duoc(login_as):
    hk, sv = hoc_ky(han_cach=5), StudentProfileFactory()
    hoc_phi(sv, hk, 1000)
    assert login_as(sv.user).get(f"{TKB}?hoc_ky={hk.id}").status_code == 200

    hk2, sv2 = hoc_ky(), StudentProfileFactory()
    thu_tien(hoc_phi(sv2, hk2, 1000), 1000)
    assert login_as(sv2.user).get(f"{TKB}?hoc_ky={hk2.id}").status_code == 200


def test_qua_han_van_xem_tkb_ky_chua_bat_dau_de_xep_lich(login_as):
    hk, sv = hoc_ky(), StudentProfileFactory()
    hoc_phi(sv, hk, 1000)
    sau = hoc_ky(bat_dau_cach=60, han_cach=90)

    assert login_as(sv.user).get(f"{TKB}?hoc_ky={sau.id}").status_code == 200


def test_qua_han_khong_dang_ky_duoc_mon(login_as):
    from core.factories import ClassSectionFactory, ScheduleFactory

    hk, sv = hoc_ky(), StudentProfileFactory()
    hoc_phi(sv, hk, 1000)
    sau = hoc_ky(bat_dau_cach=60, han_cach=90)
    lop = ClassSectionFactory(hoc_ky=sau)
    ScheduleFactory(lop_hoc_phan=lop)
    c = login_as(sv.user)

    res = c.post(
        "/api/registrations/",
        {"lop_hoc_phan": lop.id},
        format="json",
        HTTP_IDEMPOTENCY_KEY=str(uuid.uuid4()),
    )

    assert res.status_code == 403 and res.data["error"]["code"] == "HOC_PHI_QUA_HAN"
    assert "đăng ký môn học" in res.data["error"]["message"]


def test_qua_han_khong_dung_duoc_tkb_tu_dong(login_as):
    hk, sv = hoc_ky(), StudentProfileFactory()
    hoc_phi(sv, hk, 1000)

    res = login_as(sv.user).get("/api/auto-schedule/available-courses/")

    assert res.status_code == 403 and res.data["error"]["code"] == "HOC_PHI_QUA_HAN"
    assert "thời khóa biểu tự động" in res.data["error"]["message"]


# --------------------------------------------------------------- kỳ đăng ký


def test_ky_dang_ky_la_ky_mo_moi_nhat():
    hoc_ky(bat_dau_cach=-30)
    sau = hoc_ky(bat_dau_cach=90)
    hoc_ky(bat_dau_cach=200, trang_thai="DONG")

    assert hoc_ky_dang_ky() == sau


# --------------------------------------------------------------- mail nhắc nợ


@pytest.fixture
def kt(login_as):
    return login_as(UserFactory(role=Role.KE_TOAN))


def test_nhac_tat_ca_sv_con_no_bo_qua_sv_da_dong(kt):
    hk = hoc_ky()
    no, xong = StudentProfileFactory(), StudentProfileFactory()
    hoc_phi(no, hk, 2_000_000)
    thu_tien(hoc_phi(xong, hk, 1000), 1000)

    res = kt.post(f"{REMIND}?hoc_ky={hk.id}", {}, format="json")

    assert res.status_code == 200 and res.data == {"da_gui": 1, "khong_co_email": 0}
    assert mail.outbox[0].to == [no.user.email]
    assert "QUÁ HẠN" in mail.outbox[0].subject and "2.000.000 ₫" in mail.outbox[0].body


def test_nhac_theo_danh_sach_va_chi_qua_han(kt):
    hk = hoc_ky(han_cach=5)  # chưa tới hạn
    a, b = StudentProfileFactory(), StudentProfileFactory()
    ta, _ = hoc_phi(a, hk, 1000), hoc_phi(b, hk, 1000)

    chi_a = kt.post(f"{REMIND}?hoc_ky={hk.id}", {"tuition_ids": [ta.id]}, format="json")
    qua_han = kt.post(f"{REMIND}?hoc_ky={hk.id}", {"qua_han": True}, format="json")

    assert chi_a.data["da_gui"] == 1 and mail.outbox[0].to == [a.user.email]
    assert qua_han.status_code == 400  # không ai quá hạn
