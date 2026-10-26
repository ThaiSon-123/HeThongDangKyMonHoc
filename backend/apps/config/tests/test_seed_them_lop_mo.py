"""Lệnh `seed_them_lop_mo`: thêm lớp MỞ cho kỳ để mỗi môn đang mở có ≥ N lớp; chỉ thêm, GV/phòng không trùng giờ."""

from collections import defaultdict

import pytest
from django.core.management import call_command

from apps.training.models import ClassSection, Schedule, TrangThaiLop
from core.factories import (
    ClassSectionFactory,
    CourseFactory,
    FacultyFactory,
    ScheduleFactory,
    SemesterFactory,
    TeacherProfileFactory,
)

pytestmark = pytest.mark.django_db


def lop(hk, mon, n, gv, trang_thai=TrangThaiLop.MO, thu=2, dau=1, phong="A101"):
    c = ClassSectionFactory(
        ma_lop=f"{mon.ma_mon}.L{n:02d}-2627.1",
        mon_hoc=mon,
        hoc_ky=hk,
        giao_vien=gv,
        trang_thai=trang_thai,
    )
    ScheduleFactory(lop_hoc_phan=c, thu=thu, tiet_bat_dau=dau, so_tiet_moi_buoi=3, phong=phong)
    return c


@pytest.fixture
def kich_ban():
    khoa = FacultyFactory()
    gv = [TeacherProfileFactory(khoa=khoa) for _ in range(8)]
    hk = SemesterFactory(ten_hk="Học kỳ 1 - Năm học 2026 - 2027")
    a = CourseFactory(ma_mon="AAA101", khoa=khoa, so_tiet_ly_thuyet=45)
    b = CourseFactory(ma_mon="BBB101", khoa=khoa, so_tiet_ly_thuyet=45)
    c = CourseFactory(ma_mon="CCC101", khoa=khoa, so_tiet_ly_thuyet=45)  # chỉ có lớp đang học
    d = CourseFactory(ma_mon="DDD101", khoa=khoa, so_tiet_ly_thuyet=45)  # thuộc kỳ khác
    hk_khac = SemesterFactory(ten_hk="Học kỳ 2 - Năm học 2026 - 2027")
    lop(hk, a, 1, gv[0], thu=2, dau=1)
    lop(hk, a, 2, gv[1], thu=3, dau=6)
    lop(hk, b, 1, gv[0], thu=4, dau=1)  # cùng GV với lớp của A nhưng khác giờ
    lop(hk, c, 1, gv[2], trang_thai=TrangThaiLop.DANG_HOC, thu=5, dau=1)
    lop(hk_khac, d, 1, gv[3])
    return {"hk": hk, "a": a, "b": b, "c": c, "d": d, "hk_khac": hk_khac}


def so_lop_mo(hk, mon):
    return ClassSection.objects.filter(hoc_ky=hk, mon_hoc=mon, trang_thai=TrangThaiLop.MO).count()


def chay(hk, so_lop=6):
    call_command("seed_them_lop_mo", hoc_ky=hk.id, so_lop=so_lop, verbosity=0)


def test_moi_mon_dang_mo_du_so_lop_mo_con_mon_khac_khong_dong_toi(kich_ban):
    k = kich_ban
    chay(k["hk"])
    assert so_lop_mo(k["hk"], k["a"]) == 6
    assert so_lop_mo(k["hk"], k["b"]) == 6
    # Môn chỉ có lớp đang học (không có lớp mở) và môn của kỳ khác không bị thêm lớp.
    assert ClassSection.objects.filter(mon_hoc=k["c"]).count() == 1
    assert ClassSection.objects.filter(mon_hoc=k["d"]).count() == 1


def test_lop_moi_hop_le_ma_lop_khong_trung_va_co_lich(kich_ban):
    k = kich_ban
    chay(k["hk"])
    moi = ClassSection.objects.filter(hoc_ky=k["hk"], mon_hoc=k["a"]).exclude(
        ma_lop__in=["AAA101.L01-2627.1", "AAA101.L02-2627.1"]
    )
    assert moi.count() == 4
    assert sorted(m.ma_lop for m in moi) == [
        "AAA101.L03-2627.1",
        "AAA101.L04-2627.1",
        "AAA101.L05-2627.1",
        "AAA101.L06-2627.1",
    ]
    for m in moi:
        assert m.trang_thai == TrangThaiLop.MO and m.si_so_hien_tai == 0 and m.si_so_toi_da > 0
        assert (m.ngay_bat_dau, m.ngay_ket_thuc) == (k["hk"].ngay_bat_dau, k["hk"].ngay_ket_thuc)
        assert m.lich_hoc.count() >= 1


def test_chi_them_khong_sua_hay_xoa_lop_co_san(kich_ban):
    k = kich_ban
    truoc = {
        c.id: (
            c.ma_lop,
            c.giao_vien_id,
            c.trang_thai,
            [(s.thu, s.tiet_bat_dau, s.phong) for s in c.lich_hoc.all()],
        )
        for c in ClassSection.objects.all()
    }
    chay(k["hk"])
    for id_, du_lieu in truoc.items():
        c = ClassSection.objects.get(id=id_)
        assert (
            c.ma_lop,
            c.giao_vien_id,
            c.trang_thai,
            [(s.thu, s.tiet_bat_dau, s.phong) for s in c.lich_hoc.all()],
        ) == du_lieu


def test_gv_va_phong_khong_trung_gio_ca_ky(kich_ban):
    k = kich_ban
    chay(k["hk"])
    theo_gv, theo_phong = defaultdict(list), defaultdict(list)
    for s in Schedule.objects.filter(lop_hoc_phan__hoc_ky=k["hk"]).select_related("lop_hoc_phan"):
        buoi = (s.thu, s.tiet_bat_dau, s.tiet_ket_thuc, s.lop_hoc_phan_id)
        theo_gv[s.lop_hoc_phan.giao_vien_id].append(buoi)
        theo_phong[s.phong].append(buoi)
    for nhom in (theo_gv, theo_phong):
        for cac in nhom.values():
            for i, a in enumerate(cac):
                for b in cac[i + 1 :]:
                    trung = a[0] == b[0] and a[1] <= b[2] and b[1] <= a[2]
                    assert not trung or a[3] == b[3], (a, b)


def test_cac_lop_cua_mot_mon_khac_gio_nhau(kich_ban):
    k = kich_ban
    chay(k["hk"])
    lich = [
        tuple(sorted((s.thu, s.tiet_bat_dau) for s in c.lich_hoc.all()))
        for c in ClassSection.objects.filter(hoc_ky=k["hk"], mon_hoc=k["a"])
    ]
    assert len(set(lich)) == len(
        lich
    )  # không có hai lớp cùng khung giờ: mỗi lớp là một lựa chọn thật


def test_chay_lai_khong_them_nua(kich_ban):
    k = kich_ban
    chay(k["hk"])
    tong = ClassSection.objects.count()
    chay(k["hk"])
    assert ClassSection.objects.count() == tong


def test_ky_chua_co_lop_thi_khong_lam_gi():
    hk = SemesterFactory(ten_hk="Học kỳ 1 - Năm học 2030 - 2031")
    chay(hk)
    assert ClassSection.objects.count() == 0
