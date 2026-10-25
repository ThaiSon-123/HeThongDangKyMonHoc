"""Chia đợt học phí: mô hình, lịch đợt dẫn xuất, API cấu hình, đổi hình thức, quá hạn theo đợt."""

import uuid
from decimal import Decimal

import pytest
from django.db import IntegrityError, transaction

from apps.tuition.models import OnlineTransaction, Tuition, TuitionInstallment
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
