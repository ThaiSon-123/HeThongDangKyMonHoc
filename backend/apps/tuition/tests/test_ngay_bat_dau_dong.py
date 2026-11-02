"""Ngày bắt đầu đóng học phí: trước ngày đó SV không tạo được giao dịch VNPay; hạn chia đợt không sớm hơn."""

from datetime import timedelta

import pytest
from django.utils import timezone

from apps.auth.models import Role
from apps.tuition.models import TuitionConfig
from apps.tuition.tests.test_installments import cau_hinh_dot, hoc_phi
from apps.tuition.tests.test_vnpay import vnp  # noqa: F401 — fixture cấu hình VNPay
from core.factories import SemesterFactory, StudentProfileFactory, UserFactory

pytestmark = pytest.mark.django_db
HOM_NAY = timezone.localdate()


def ngay(cach):
    return HOM_NAY + timedelta(days=cach)


@pytest.fixture
def kt(login_as):
    return login_as(UserFactory(role=Role.KE_TOAN))


def test_ngay_bat_dau_phai_truoc_han_dong(kt):
    hk = SemesterFactory()
    body = {"hoc_ky": hk.id, "ngay_bat_dau_dong": ngay(10), "han_dong": ngay(5)}
    res = kt.post("/api/tuition/config/", body, format="json")
    assert res.status_code == 400 and "ngay_bat_dau_dong" in res.data

    body["ngay_bat_dau_dong"] = ngay(1)
    assert kt.post("/api/tuition/config/", body, format="json").status_code == 201


def test_khong_dat_ngay_bat_dau_sau_han_dot_da_co(kt):
    hk = SemesterFactory()
    cau_hinh_dot(hk, han=(ngay(5), ngay(20), ngay(40)))
    res = kt.post(
        "/api/tuition/config/",
        {"hoc_ky": hk.id, "ngay_bat_dau_dong": ngay(10), "han_dong": ngay(40)},
        format="json",
    )
    assert res.status_code == 400 and "Hạn đợt 1" in res.data["ngay_bat_dau_dong"][0]


def test_chia_dot_khong_duoc_som_hon_ngay_bat_dau(kt):
    hk = SemesterFactory()
    TuitionConfig.objects.create(hoc_ky=hk, ngay_bat_dau_dong=ngay(10), han_dong=ngay(60))

    def dat(han1):
        return kt.put(
            f"/api/tuition/installments/?hoc_ky={hk.id}",
            {
                "dots": [
                    {"thu_tu": 1, "ty_le": 40, "han_dong": han1},
                    {"thu_tu": 2, "ty_le": 30, "han_dong": ngay(40)},
                    {"thu_tu": 3, "ty_le": 30, "han_dong": ngay(60)},
                ]
            },
            format="json",
        )

    assert dat(ngay(5)).status_code == 400
    assert dat(ngay(10)).status_code == 200


@pytest.mark.parametrize(("cach", "duoc"), [(3, False), (0, True), (-3, True), (None, True)])
def test_my_bao_da_toi_ngay_dong_chua(login_as, cach, duoc):
    hk, sv = SemesterFactory(), StudentProfileFactory()
    hoc_phi(sv, hk, 1000)
    TuitionConfig.objects.create(
        hoc_ky=hk, ngay_bat_dau_dong=None if cach is None else ngay(cach), han_dong=ngay(30)
    )

    d = login_as(sv.user).get(f"/api/tuition/my/?hoc_ky={hk.id}").data

    assert d["duoc_thanh_toan"] is duoc
    assert d["ngay_bat_dau_dong"] == (None if cach is None else str(ngay(cach)))


def test_chua_toi_ngay_thi_khong_tao_duoc_giao_dich_vnpay(vnp, login_as):  # noqa: F811
    hk, sv = SemesterFactory(), StudentProfileFactory()
    hoc_phi(sv, hk, 1000)
    cfg = TuitionConfig.objects.create(hoc_ky=hk, ngay_bat_dau_dong=ngay(3), han_dong=ngay(30))
    c = login_as(sv.user)

    res = c.post(f"/api/tuition/my/pay/?hoc_ky={hk.id}", {"muc": "TOAN_BO"}, format="json")
    assert (
        res.status_code == 409
        and "Chưa tới ngày bắt đầu đóng học phí" in res.data["error"]["message"]
    )

    cfg.ngay_bat_dau_dong = HOM_NAY
    cfg.save()
    assert (
        c.post(
            f"/api/tuition/my/pay/?hoc_ky={hk.id}", {"muc": "TOAN_BO"}, format="json"
        ).status_code
        == 201
    )
