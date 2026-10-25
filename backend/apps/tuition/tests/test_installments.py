"""Chia đợt học phí: mô hình, lịch đợt dẫn xuất, API cấu hình, đổi hình thức, quá hạn theo đợt."""

import uuid
from datetime import date
from decimal import Decimal

import pytest
from django.db import IntegrityError, transaction

from apps.audit.models import AuditLog
from apps.auth.models import Role
from apps.tuition.models import (
    OnlineTransaction,
    Payment,
    Tuition,
    TuitionConfig,
    TuitionInstallment,
)
from apps.tuition.services import dot_tiep_theo, han_va_qua_han, lich_dot, thong_bao_qua_han
from core.factories import SemesterFactory, StudentProfileFactory, UserFactory

pytestmark = pytest.mark.django_db
D = Decimal
URL = "/api/tuition/installments/"


@pytest.fixture
def kt(login_as):
    return login_as(UserFactory(role=Role.KE_TOAN))


def dots_body(a="40", b="30", c="30", han=("2027-01-01", "2027-02-01", "2027-03-01")):
    return {
        "dots": [
            {"thu_tu": i + 1, "ty_le": ty, "han_dong": h}
            for i, (ty, h) in enumerate(zip((a, b, c), han, strict=False))
        ]
    }


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


# --------------------------------------------------------------- API cấu hình 3 đợt (KT)


def test_put_ba_dot_hop_le_roi_get(kt):
    hk = SemesterFactory()
    res = kt.put(f"{URL}?hoc_ky={hk.id}", dots_body(), format="json")
    assert res.status_code == 200, res.data
    got = kt.get(f"{URL}?hoc_ky={hk.id}").json()
    assert got["hoc_ky"] == hk.id
    assert [(d["thu_tu"], d["ty_le"], d["han_dong"]) for d in got["dots"]] == [
        (1, "40.00", "2027-01-01"),
        (2, "30.00", "2027-02-01"),
        (3, "30.00", "2027-03-01"),
    ]
    assert AuditLog.objects.filter(doi_tuong="TuitionInstallment").count() == 1


def test_get_chua_cau_hinh_tra_danh_sach_rong(kt):
    hk = SemesterFactory()
    assert kt.get(f"{URL}?hoc_ky={hk.id}").json()["dots"] == []


@pytest.mark.parametrize(
    "body",
    [
        dots_body("40", "30", "20"),  # tổng 90
        dots_body("50", "30", "30"),  # tổng 110
        dots_body(han=("2027-01-01", "2027-01-01", "2027-03-01")),  # hạn không tăng ngặt
        dots_body(han=("2027-03-01", "2027-02-01", "2027-01-01")),  # hạn giảm dần
        dots_body("0", "50", "50"),  # tỷ lệ 0
        {"dots": dots_body()["dots"][:2]},  # thiếu đợt
        {"dots": [{**d, "thu_tu": 1} for d in dots_body()["dots"]]},  # trùng thứ tự
    ],
)
def test_put_cau_hinh_sai_bi_tu_choi(kt, body):
    hk = SemesterFactory()
    assert kt.put(f"{URL}?hoc_ky={hk.id}", body, format="json").status_code == 400
    assert TuitionInstallment.objects.filter(hoc_ky=hk).count() == 0


def test_put_hai_lan_thay_the_khong_nhan_doi(kt):
    hk = SemesterFactory()
    kt.put(f"{URL}?hoc_ky={hk.id}", dots_body(), format="json")
    res = kt.put(f"{URL}?hoc_ky={hk.id}", dots_body("20", "30", "50"), format="json")
    assert res.status_code == 200
    assert TuitionInstallment.objects.filter(hoc_ky=hk).count() == 3
    assert [d["ty_le"] for d in res.json()["dots"]] == ["20.00", "30.00", "50.00"]


@pytest.mark.parametrize("role", [Role.SINH_VIEN, Role.PHONG_DAO_TAO, Role.GIAO_VIEN])
def test_chi_ke_toan_duoc_cau_hinh(login_as, role):
    hk = SemesterFactory()
    c = login_as(UserFactory(role=role))
    assert c.get(f"{URL}?hoc_ky={hk.id}").status_code == 403
    assert c.put(f"{URL}?hoc_ky={hk.id}", dots_body(), format="json").status_code == 403


# --------------------------------------------------------------- tuition/my, đổi hình thức, quá hạn theo đợt


def cau_hinh_dot(hk, han=(date(2027, 1, 1), date(2027, 2, 1), date(2027, 3, 1)), tl=(40, 30, 30)):
    for i in range(3):
        TuitionInstallment.objects.create(hoc_ky=hk, thu_tu=i + 1, ty_le=D(tl[i]), han_dong=han[i])


def thu_tien(t, so_tien):
    return Payment.objects.create(
        tuition=t,
        loai="THU",
        so_tien=D(so_tien),
        phuong_thuc="TIEN_MAT",
        nguoi_thu=UserFactory(role=Role.KE_TOAN),
    )


def test_my_chia_dot_tra_ba_dot_va_dot_tiep_theo(login_as):
    hk, sv = SemesterFactory(), StudentProfileFactory()
    cau_hinh_dot(hk)
    t = hoc_phi(sv, hk, 1000, hinh_thuc="CHIA_DOT")
    thu_tien(t, 500)
    d = login_as(sv.user).get(f"/api/tuition/my/?hoc_ky={hk.id}").json()
    assert d["hinh_thuc"] == "CHIA_DOT"
    assert [x["da_dong"] for x in d["cac_dot"]] == [True, False, False]
    assert d["dot_tiep_theo"] == {"thu_tu": 2, "can_dong": "200.00"}
    assert d["han_dong"] == "2027-02-01"


def test_my_mot_lan_van_thay_lich_nhung_khong_co_dot_tiep_theo(login_as):
    hk, sv = SemesterFactory(), StudentProfileFactory()
    hoc_phi(sv, hk, 1000)
    c = login_as(sv.user)
    assert c.get(f"/api/tuition/my/?hoc_ky={hk.id}").json()["cac_dot"] == []
    cau_hinh_dot(hk)
    d = c.get(f"/api/tuition/my/?hoc_ky={hk.id}").json()
    assert len(d["cac_dot"]) == 3 and d["dot_tiep_theo"] is None and d["hinh_thuc"] == "MOT_LAN"


def test_plan_doi_giua_chung_khong_doi_con_no(login_as):
    hk, sv = SemesterFactory(), StudentProfileFactory()
    cau_hinh_dot(hk)
    t = hoc_phi(sv, hk, 1000)
    thu_tien(t, 500)
    c = login_as(sv.user)
    truoc = c.get(f"/api/tuition/my/?hoc_ky={hk.id}").json()["con_no"]
    res = c.patch(f"/api/tuition/my/plan/?hoc_ky={hk.id}", {"hinh_thuc": "CHIA_DOT"}, format="json")
    assert res.status_code == 200 and res.json() == {"hinh_thuc": "CHIA_DOT"}
    t.refresh_from_db()
    assert t.hinh_thuc == "CHIA_DOT"
    assert c.get(f"/api/tuition/my/?hoc_ky={hk.id}").json()["con_no"] == truoc
    c.patch(f"/api/tuition/my/plan/?hoc_ky={hk.id}", {"hinh_thuc": "MOT_LAN"}, format="json")
    t.refresh_from_db()
    assert t.hinh_thuc == "MOT_LAN"


def test_plan_chia_dot_khi_chua_cau_hinh_bi_tu_choi(login_as):
    hk, sv = SemesterFactory(), StudentProfileFactory()
    hoc_phi(sv, hk, 1000)
    res = login_as(sv.user).patch(
        f"/api/tuition/my/plan/?hoc_ky={hk.id}", {"hinh_thuc": "CHIA_DOT"}, format="json"
    )
    assert res.status_code == 409 and res.data["error"]["code"] == "TRANG_THAI_KHONG_HOP_LE"


def test_plan_khong_co_hoc_phi_hoac_chua_tinh_bi_tu_choi(login_as):
    hk, sv = SemesterFactory(), StudentProfileFactory()
    cau_hinh_dot(hk)
    c = login_as(sv.user)
    body = {"hinh_thuc": "CHIA_DOT"}
    assert c.patch(f"/api/tuition/my/plan/?hoc_ky={hk.id}", body, format="json").status_code == 409
    hoc_phi(sv, hk, 1000, trang_thai="CHUA_TINH")
    assert c.patch(f"/api/tuition/my/plan/?hoc_ky={hk.id}", body, format="json").status_code == 409


def test_plan_gia_tri_la_va_phan_quyen(login_as):
    hk, sv = SemesterFactory(), StudentProfileFactory()
    hoc_phi(sv, hk, 1000)
    url = f"/api/tuition/my/plan/?hoc_ky={hk.id}"
    assert login_as(sv.user).patch(url, {"hinh_thuc": "BA_LAN"}, format="json").status_code == 400
    kt = login_as(UserFactory(role=Role.KE_TOAN))
    assert kt.patch(url, {"hinh_thuc": "MOT_LAN"}, format="json").status_code == 403


def test_danh_sach_kt_qua_han_theo_dot(login_as):
    hk, sv = SemesterFactory(), StudentProfileFactory()
    cau_hinh_dot(hk, han=(date(2020, 1, 1), date(2999, 2, 1), date(2999, 3, 1)))
    hoc_phi(sv, hk, 1000, hinh_thuc="CHIA_DOT")
    kt = login_as(UserFactory(role=Role.KE_TOAN))
    row = kt.get(f"/api/tuition/?hoc_ky={hk.id}").json()["results"][0]
    assert row["qua_han"] is True and row["han_dong"] == "2020-01-01"
    assert row["hinh_thuc"] == "CHIA_DOT"


def test_job_qua_han_bao_theo_dot():
    hk, sv = SemesterFactory(), StudentProfileFactory()
    cau_hinh_dot(hk, han=(date(2026, 3, 1), date(2026, 4, 1), date(2026, 5, 1)))
    hoc_phi(sv, hk, 1000, hinh_thuc="CHIA_DOT")
    assert thong_bao_qua_han(hom_nay=date(2026, 3, 2)) == 1
    assert thong_bao_qua_han(hom_nay=date(2026, 3, 3)) == 0  # không báo trùng


def test_job_qua_han_mot_lan_van_theo_tuition_config():
    hk, sv = SemesterFactory(), StudentProfileFactory()
    TuitionConfig.objects.create(hoc_ky=hk, han_dong=date(2026, 3, 1))
    cau_hinh_dot(hk, han=(date(2099, 1, 1), date(2099, 2, 1), date(2099, 3, 1)))
    hoc_phi(sv, hk, 1000)  # MOT_LAN: chỉ xét hạn một lần, bỏ qua hạn các đợt
    assert thong_bao_qua_han(hom_nay=date(2026, 3, 2)) == 1
