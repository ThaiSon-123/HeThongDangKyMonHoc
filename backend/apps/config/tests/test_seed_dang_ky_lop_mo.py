"""Lệnh `seed_dang_ky_lop_mo`: cho sinh viên chưa đăng ký gì đăng ký THẬT vào lớp mở (qua dịch vụ đăng ký),
để sĩ số các lớp có số; không vi phạm quy tắc đăng ký; chỉ động tới sinh viên chưa có đăng ký."""

from collections import Counter, defaultdict
from datetime import timedelta

import pytest
from django.core.management import call_command
from django.utils import timezone

from apps.registration.models import Registration, TrangThaiDangKy
from apps.training.models import ClassSection, CurriculumCourse, TrangThaiLop
from core.factories import (
    ClassSectionFactory,
    CourseFactory,
    CurriculumFactory,
    ScheduleFactory,
    SemesterFactory,
    StudentProfileFactory,
)

pytestmark = pytest.mark.django_db


@pytest.fixture
def kich_ban():
    now = timezone.now()
    hk = SemesterFactory(
        cua_so_dk_bat_dau=now - timedelta(days=1),
        cua_so_dk_ket_thuc=now + timedelta(days=7),
        tin_chi_toi_thieu=12,
        tin_chi_toi_da=24,
    )
    ctdt = CurriculumFactory()
    mon = [CourseFactory() for _ in range(8)]  # mỗi môn 3 tín chỉ
    lop = []
    for i, m in enumerate(mon):
        CurriculumCourse.objects.create(ctdt=ctdt, mon_hoc=m, hoc_ky_goi_y=1 + i % 2)
        for j in range(4):  # 4 lớp mỗi môn, khung giờ khác nhau → có chỗ né trùng lịch
            c = ClassSectionFactory(
                mon_hoc=m, hoc_ky=hk, trang_thai=TrangThaiLop.MO, si_so_toi_da=60
            )
            ScheduleFactory(
                lop_hoc_phan=c,
                thu=2 + (i + j) % 6,
                tiet_bat_dau=1 + 5 * ((i + 2 * j) % 3),
                so_tiet_moi_buoi=3,
                phong=f"P{c.id}",
            )
            lop.append(c)
    sv = [StudentProfileFactory(nganh=ctdt.nganh, ctdt=ctdt) for _ in range(12)]
    return {"hk": hk, "ctdt": ctdt, "mon": mon, "lop": lop, "sv": sv}


def chay(hk, **kw):
    call_command("seed_dang_ky_lop_mo", hoc_ky=hk.id, verbosity=0, **kw)


def dang_ky_that(hk):
    return Registration.objects.filter(
        lop_hoc_phan__hoc_ky=hk, trang_thai=TrangThaiDangKy.DA_DANG_KY
    )


def test_tao_dang_ky_that_va_si_so_khop_dang_ky(kich_ban):
    k = kich_ban
    chay(k["hk"])
    assert dang_ky_that(k["hk"]).count() > 0
    dem = Counter(dang_ky_that(k["hk"]).values_list("lop_hoc_phan_id", flat=True))
    for c in ClassSection.objects.filter(hoc_ky=k["hk"]):
        assert c.si_so_hien_tai == dem.get(c.id, 0), c.ma_lop
    assert sum(1 for c in ClassSection.objects.filter(hoc_ky=k["hk"]) if c.si_so_hien_tai) >= 4


def test_moi_sinh_vien_du_tin_chi_va_khong_vi_pham_quy_tac(kich_ban):
    k = kich_ban
    chay(k["hk"])
    theo = defaultdict(list)
    for r in (
        dang_ky_that(k["hk"])
        .select_related("lop_hoc_phan__mon_hoc")
        .prefetch_related("lop_hoc_phan__lich_hoc")
    ):
        theo[r.sinh_vien_id].append(r)
    assert len(theo) == len(k["sv"])  # ai cũng đăng ký được
    for rs in theo.values():
        mon = [r.lop_hoc_phan.mon_hoc_id for r in rs]
        assert len(mon) == len(set(mon))  # không trùng môn
        tin_chi = sum(r.lop_hoc_phan.mon_hoc.tong_tin_chi for r in rs)
        assert 12 <= tin_chi <= 24
        buoi = [
            (s.thu, s.tiet_bat_dau, s.tiet_ket_thuc, r.id)
            for r in rs
            for s in r.lop_hoc_phan.lich_hoc.all()
        ]
        for i, a in enumerate(buoi):
            for b in buoi[i + 1 :]:
                assert not (a[0] == b[0] and a[1] <= b[2] and b[1] <= a[2]), (a, b)


def test_dang_ky_lech_ve_lop_pho_bien(kich_ban):
    """Lớp đầu của mỗi môn được chọn nhiều hơn lớp cuối → thanh tiến độ có độ cao khác nhau."""
    k = kich_ban
    chay(k["hk"])
    si_so = [c.si_so_hien_tai for c in ClassSection.objects.filter(hoc_ky=k["hk"])]
    assert max(si_so) > min(si_so)


def test_chi_dong_toi_sinh_vien_chua_co_dang_ky(kich_ban):
    k = kich_ban
    co_san = k["sv"][0]
    Registration.objects.create(sinh_vien=co_san.user, lop_hoc_phan=k["lop"][0])
    ClassSection.objects.filter(pk=k["lop"][0].pk).update(si_so_hien_tai=1)
    chay(k["hk"])
    assert dang_ky_that(k["hk"]).filter(sinh_vien=co_san.user).count() == 1


def test_chay_lai_khong_them_dang_ky(kich_ban):
    k = kich_ban
    chay(k["hk"])
    tong = Registration.objects.count()
    chay(k["hk"])
    assert Registration.objects.count() == tong


def test_ket_qua_co_dinh_theo_seed(kich_ban):
    k = kich_ban
    chay(k["hk"], seed=7)
    a = sorted(dang_ky_that(k["hk"]).values_list("sinh_vien_id", "lop_hoc_phan_id"))
    Registration.objects.all().delete()
    ClassSection.objects.update(si_so_hien_tai=0)
    chay(k["hk"], seed=7)
    assert sorted(dang_ky_that(k["hk"]).values_list("sinh_vien_id", "lop_hoc_phan_id")) == a


def test_de_trong_chua_lai_sinh_vien_dau_moi_ctdt(kich_ban):
    k = kich_ban
    chay(k["hk"], de_trong=3)
    co_dk = set(dang_ky_that(k["hk"]).values_list("sinh_vien_id", flat=True))
    sv_theo_id = sorted(k["sv"], key=lambda s: s.id)
    assert {s.user_id for s in sv_theo_id[:3]}.isdisjoint(co_dk)  # 3 người đầu để trống
    assert {s.user_id for s in sv_theo_id[3:]} <= co_dk
