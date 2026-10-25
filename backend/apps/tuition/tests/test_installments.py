"""Chia đợt học phí: mô hình, lịch đợt dẫn xuất, API cấu hình, đổi hình thức, quá hạn theo đợt."""

import uuid
from datetime import date
from decimal import Decimal

import pytest
from django.db import IntegrityError, transaction

from apps.tuition.models import OnlineTransaction, Tuition, TuitionInstallment
from apps.tuition.services import dot_tiep_theo, han_va_qua_han, lich_dot
from core.factories import SemesterFactory, StudentProfileFactory

pytestmark = pytest.mark.django_db
D = Decimal


def hoc_phi(sv, hk, tong, trang_thai="DA_TINH", **kw):
    return Tuition.objects.create(
        sinh_vien=sv.user, hoc_ky=hk, tong_tien=D(tong), tong_tin_chi=3, trang_thai=trang_thai, **kw
    )


# --------------------------------------------------------------- mô hình


def test_dot_trung_thu_tu_bi_chan():
    hk = SemesterFactory()
    TuitionInstallment.objects.create(hoc_ky=hk, thu_tu=1, ty_le=D(40), han_dong="2027-01-01")
    with pytest.raises(IntegrityError), transaction.atomic():
        TuitionInstallment.objects.create(hoc_ky=hk, thu_tu=1, ty_le=D(30), han_dong="2027-02-01")


def test_online_transaction_mac_dinh_cho_va_txn_ref_la_uuid():
    t = hoc_phi(StudentProfileFactory(), SemesterFactory(), 1000)
    gd = OnlineTransaction.objects.create(tuition=t, so_tien=D(500))
    assert gd.trang_thai == "CHO"
    assert isinstance(gd.txn_ref, uuid.UUID)


def test_tuition_mac_dinh_mot_lan():
    t = hoc_phi(StudentProfileFactory(), SemesterFactory(), 1000)
    assert t.hinh_thuc == "MOT_LAN"


# --------------------------------------------------------------- lịch đợt dẫn xuất (hàm thuần)


class _Dot:
    def __init__(self, thu_tu, ty_le, han_dong):
        self.thu_tu, self.ty_le, self.han_dong = thu_tu, D(ty_le), han_dong


def ba_dot(a="40", b="30", c="30", han=(date(2027, 1, 1), date(2027, 2, 1), date(2027, 3, 1))):
    return [_Dot(1, a, han[0]), _Dot(2, b, han[1]), _Dot(3, c, han[2])]


def test_lich_dot_40_30_30():
    lich = lich_dot(D(1000), D(0), ba_dot())
    assert [d["phai_nop"] for d in lich] == [D(400), D(300), D(300)]
    assert [d["luy_ke"] for d in lich] == [D(400), D(700), D(1000)]


def test_lich_dot_lam_tron_dot_cuoi_bu_lech():
    lich = lich_dot(D(100), D(0), ba_dot("33.33", "33.33", "33.34"))
    assert sum(d["phai_nop"] for d in lich) == D(100)
    assert lich[-1]["luy_ke"] == D(100)


def test_da_dong_theo_thuc_thu_chay_tu_dot_1():
    lich = lich_dot(D(1000), D(500), ba_dot())
    assert [d["da_dong"] for d in lich] == [True, False, False]
    assert dot_tiep_theo(lich, D(500)) == {"thu_tu": 2, "can_dong": D(200)}
    assert dot_tiep_theo(lich_dot(D(1000), D(1000), ba_dot()), D(1000)) is None


def test_phai_nop_0_moi_dot_da_dong():
    lich = lich_dot(D(0), D(0), ba_dot())
    assert all(d["da_dong"] for d in lich)
    assert dot_tiep_theo(lich, D(0)) is None


def test_lich_dot_rong_khi_khong_co_dot():
    assert lich_dot(D(1000), D(0), []) == []
    assert dot_tiep_theo([], D(0)) is None


def test_han_va_qua_han_chia_dot():
    han = (date(2027, 1, 1), date(2027, 2, 1), date(2027, 3, 1))
    dx = {"con_no": D(1000)}
    lich = lich_dot(D(1000), D(0), ba_dot())
    assert han_va_qua_han("CHIA_DOT", dx, None, lich, date(2027, 1, 5)) == (han[0], True)
    lich = lich_dot(D(1000), D(400), ba_dot())
    assert han_va_qua_han("CHIA_DOT", dx, None, lich, date(2027, 1, 5)) == (han[1], False)
    lich = lich_dot(D(1000), D(1000), ba_dot())
    assert han_va_qua_han("CHIA_DOT", {"con_no": D(0)}, None, lich, date(2027, 5, 1)) == (
        han[2],
        False,
    )


def test_han_va_qua_han_mot_lan_va_thieu_dot():
    hom_nay = date(2027, 1, 5)
    dx = {"con_no": D(10)}
    assert han_va_qua_han("MOT_LAN", dx, date(2027, 1, 1), [], hom_nay) == (date(2027, 1, 1), True)
    assert han_va_qua_han("MOT_LAN", {"con_no": D(0)}, date(2027, 1, 1), [], hom_nay)[1] is False
    # CHIA_DOT nhưng chưa cấu hình đợt: rơi về hạn một lần
    assert han_va_qua_han("CHIA_DOT", dx, date(2027, 1, 1), [], hom_nay) == (date(2027, 1, 1), True)
    assert han_va_qua_han("MOT_LAN", dx, None, [], hom_nay) == (None, False)
