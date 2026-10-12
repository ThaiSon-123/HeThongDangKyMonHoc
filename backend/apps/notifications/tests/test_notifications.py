"""Thông báo (ADM-07, PDT-13, GV-11, SV-13): hộp thư theo ROLE/CLASS/USER, đã đọc, gửi, thu hồi, trigger."""

import pytest

from apps.audit.models import AuditLog
from apps.auth.models import Role
from apps.notifications.models import Audience, Notification, NotificationRead
from apps.registration.models import Registration
from apps.training.models import TrangThaiLop
from core.factories import (
    ClassSectionFactory,
    ScheduleFactory,
    StudentProfileFactory,
    TeacherProfileFactory,
    UserFactory,
)

pytestmark = pytest.mark.django_db
URL = "/api/notifications/"


def tao(audience, refs, tieu_de="Tiêu đề", gui=None, **kw):
    return Notification.objects.create(
        tieu_de=tieu_de,
        noi_dung="Nội dung",
        audience=audience,
        target_refs=refs,
        nguoi_gui=gui,
        **kw,
    )


def ids(res):
    return [n["id"] for n in res.data["results"]]


# --------------------------------------------------------------- hộp thư


def test_hop_thu_theo_user_role_class_va_chi_dung_doi_tuong(login_as):
    sv = StudentProfileFactory()
    sv_khac = StudentProfileFactory()
    lop = ClassSectionFactory()
    Registration.objects.create(sinh_vien=sv.user, lop_hoc_phan=lop)
    Registration.objects.create(
        sinh_vien=sv_khac.user, lop_hoc_phan=lop, trang_thai="DA_HUY"
    )  # đã hủy
    gv = lop.giao_vien.user

    n_user = tao(Audience.USER, [sv.user_id])
    n_user_khac = tao(Audience.USER, [sv_khac.user_id])
    n_nhieu = tao(Audience.USER, [sv_khac.user_id, sv.user_id])  # nhiều người nhận
    n_role = tao(Audience.ROLE, [Role.SINH_VIEN])
    n_role_gv = tao(Audience.ROLE, [Role.GIAO_VIEN])
    n_lop = tao(Audience.CLASS, [lop.id])
    n_lop_khac = tao(Audience.CLASS, [ClassSectionFactory().id])

    mine = login_as(sv.user).get(URL)
    assert set(ids(mine)) == {n_user.id, n_nhieu.id, n_role.id, n_lop.id}
    assert set(ids(login_as(sv_khac.user).get(URL))) == {
        n_user_khac.id,
        n_nhieu.id,
        n_role.id,
    }  # hủy → không nhận CLASS
    assert set(ids(login_as(gv).get(URL))) == {
        n_role_gv.id,
        n_lop.id,
    }  # GV phụ trách lớp nhận CLASS
    assert ids(login_as(UserFactory(role=Role.KE_TOAN)).get(URL)) == []
    assert n_lop_khac.id not in ids(mine)


def test_thu_hoi_bien_khoi_hop_thu_va_moi_nhat_truoc(login_as):
    sv = StudentProfileFactory()
    cu = tao(Audience.USER, [sv.user_id], "Cũ")
    moi = tao(Audience.USER, [sv.user_id], "Mới")
    res = login_as(sv.user).get(URL)
    assert ids(res) == [moi.id, cu.id]
    moi.trang_thai = "THU_HOI"
    moi.save()
    assert ids(login_as(sv.user).get(URL)) == [cu.id]


def test_chua_doc_da_doc_va_doc_het(login_as):
    sv = StudentProfileFactory()
    api = login_as(sv.user)
    a, b, c = (tao(Audience.USER, [sv.user_id], f"T{i}") for i in range(3))

    res = api.get(URL)
    assert res.data["chua_doc"] == 3 and all(n["da_doc"] is False for n in res.data["results"])

    r = api.patch(f"{URL}{a.id}/read/")
    assert r.status_code == 200 and r.data["da_doc"] is True
    api.patch(f"{URL}{a.id}/read/")  # đọc lại không lỗi / không nhân đôi
    assert NotificationRead.objects.filter(user=sv.user).count() == 1

    assert api.get(URL).data["chua_doc"] == 2
    assert set(ids(api.get(f"{URL}?da_doc=false"))) == {b.id, c.id}

    done = api.post(f"{URL}read-all/")
    assert done.status_code == 200 and done.data["da_danh_dau"] == 2
    assert api.get(URL).data["chua_doc"] == 0 and ids(api.get(f"{URL}?da_doc=false")) == []
    assert api.post(f"{URL}read-all/").data["da_danh_dau"] == 0


def test_khong_doc_duoc_thong_bao_cua_nguoi_khac(login_as):
    a, b = StudentProfileFactory(), StudentProfileFactory()
    n = tao(Audience.USER, [b.user_id])
    assert login_as(a.user).patch(f"{URL}{n.id}/read/").status_code == 404
    assert NotificationRead.objects.count() == 0


# --------------------------------------------------------------- gửi


def gui(api, **kw):
    body = {
        "tieu_de": "Thông báo",
        "noi_dung": "Nội dung",
        "audience": "ROLE",
        "target_refs": ["SINH_VIEN"],
        **kw,
    }
    return api.post(URL, body, format="json")


@pytest.mark.parametrize("role", [Role.PHONG_DAO_TAO, Role.KE_TOAN, Role.ADMIN])
def test_admin_pdt_kt_gui_theo_vai_tro_lop_nguoi_dung(login_as, role):
    api = login_as(UserFactory(role=role))
    lop = ClassSectionFactory()
    sv = StudentProfileFactory()
    assert gui(api).status_code == 201
    assert gui(api, audience="CLASS", target_refs=[lop.id]).status_code == 201
    res = gui(api, audience="USER", target_refs=[sv.user_id])
    assert res.status_code == 201 and res.data["tu_toi"] is True and res.data["nguoi_gui_ten"]
    assert AuditLog.objects.filter(doi_tuong="Notification", hanh_dong="CREATE").count() == 3


def test_sv_khong_duoc_gui(login_as):
    res = gui(login_as(StudentProfileFactory().user))
    assert res.status_code == 403 and res.data["error"]["code"] == "KHONG_CO_QUYEN"


def test_gv_chi_gui_cho_lop_minh(login_as):
    lop = ClassSectionFactory()
    khac = ClassSectionFactory()
    gv = login_as(lop.giao_vien.user)
    assert gui(gv, audience="CLASS", target_refs=[lop.id]).status_code == 201
    assert gui(gv, audience="CLASS", target_refs=[khac.id]).status_code == 403  # lớp người khác
    assert gui(gv, audience="CLASS", target_refs=[lop.id, khac.id]).status_code == 403
    assert gui(gv).status_code == 403  # theo vai trò: không
    assert gui(gv, audience="USER", target_refs=[UserFactory().id]).status_code == 403


def test_gui_validate_doi_tuong(login_as):
    pdt = login_as(UserFactory(role=Role.PHONG_DAO_TAO))
    assert gui(pdt, target_refs=["QUAN_LY"]).status_code == 400  # vai trò không có
    assert gui(pdt, audience="CLASS", target_refs=[999999]).status_code == 400
    assert gui(pdt, audience="USER", target_refs=[999999]).status_code == 400
    assert gui(pdt, audience="USER", target_refs=["x"]).status_code == 400
    assert gui(pdt, target_refs=[]).status_code == 400
    assert gui(pdt, tieu_de="").status_code == 400


def test_nguoi_nhan_thay_thong_bao_vua_gui_va_gv_gui_den_sv_cua_lop(login_as):
    lop = ClassSectionFactory()
    sv = StudentProfileFactory()
    Registration.objects.create(sinh_vien=sv.user, lop_hoc_phan=lop)
    gui(
        login_as(lop.giao_vien.user),
        audience="CLASS",
        target_refs=[lop.id],
        tieu_de="Nghỉ học thứ 5",
    )
    res = login_as(sv.user).get(URL)
    assert [n["tieu_de"] for n in res.data["results"]] == ["Nghỉ học thứ 5"]
    assert res.data["results"][0]["tu_toi"] is False


# --------------------------------------------------------------- thu hồi


def test_thu_hoi_nguoi_gui_hoac_admin_va_ghi_audit(login_as):
    pdt_user = UserFactory(role=Role.PHONG_DAO_TAO)
    sv = StudentProfileFactory()
    n = gui(login_as(pdt_user), audience="USER", target_refs=[sv.user_id]).data
    ds_gui = login_as(pdt_user).get(f"{URL}?gui=true")
    assert [x["id"] for x in ds_gui.data["results"]] == [n["id"]]

    assert (
        login_as(UserFactory(role=Role.PHONG_DAO_TAO)).delete(f"{URL}{n['id']}/").status_code == 403
    )
    assert login_as(sv.user).delete(f"{URL}{n['id']}/").status_code == 403
    assert login_as(pdt_user).delete(f"{URL}{n['id']}/").status_code == 204
    assert login_as(pdt_user).delete(f"{URL}{n['id']}/").status_code == 204  # lặp lại không lỗi
    assert ids(login_as(sv.user).get(URL)) == []
    assert Notification.objects.get(pk=n["id"]).trang_thai == "THU_HOI"
    assert [x["trang_thai"] for x in login_as(pdt_user).get(f"{URL}?gui=true").data["results"]] == [
        "THU_HOI"
    ]
    assert (
        AuditLog.objects.filter(doi_tuong="Notification", chi_tiet__hanh_dong="thu_hoi").count()
        == 1
    )

    n2 = gui(login_as(pdt_user), audience="USER", target_refs=[sv.user_id]).data
    assert (
        login_as(UserFactory(role=Role.ADMIN)).delete(f"{URL}{n2['id']}/").status_code == 204
    )  # Admin thu hồi hộ
    assert login_as(pdt_user).delete(f"{URL}999999/").status_code == 404


# --------------------------------------------------------------- tra người nhận


def test_tra_nguoi_nhan_theo_ten_ma_va_vai_tro(login_as):
    sv = StudentProfileFactory(ho_ten="Nguyễn Văn An", ma_sv="SV12345")
    gv = TeacherProfileFactory(ho_ten="Trần Thị Bình")
    pdt = login_as(UserFactory(role=Role.PHONG_DAO_TAO))
    r = pdt.get(f"{URL}recipients/?search=SV12345")
    assert [(x["id"], x["full_name"]) for x in r.data["results"]] == [(sv.user_id, "Nguyễn Văn An")]
    assert [x["id"] for x in pdt.get(f"{URL}recipients/?search=Bình").data["results"]] == [
        gv.user_id
    ]
    assert all(
        x["role"] == "GIAO_VIEN"
        for x in pdt.get(f"{URL}recipients/?role=GIAO_VIEN").data["results"]
    )
    assert login_as(lop_gv()).get(f"{URL}recipients/").status_code == 403  # GV chỉ gửi theo lớp
    assert login_as(sv.user).get(f"{URL}recipients/").status_code == 403


def lop_gv():
    return ClassSectionFactory().giao_vien.user


# --------------------------------------------------------------- trigger: lớp đổi lịch (mục 7.6)


def test_pdt_doi_lich_lop_da_mo_bao_sv_va_gv_cua_lop(login_as):
    pdt = login_as(UserFactory(role=Role.PHONG_DAO_TAO))
    lop = ClassSectionFactory(trang_thai=TrangThaiLop.MO)
    lich = ScheduleFactory(lop_hoc_phan=lop, thu=2, tiet_bat_dau=1, so_tiet_moi_buoi=3, phong="A1")
    sv = StudentProfileFactory()
    Registration.objects.create(sinh_vien=sv.user, lop_hoc_phan=lop)
    Notification.objects.all().delete()

    assert pdt.patch(f"/api/schedules/{lich.id}/", {"phong": "B2"}).status_code == 200
    n = Notification.objects.get()
    assert n.audience == "CLASS" and n.target_refs == [lop.id] and "thay đổi lịch" in n.tieu_de
    assert "B2" in n.noi_dung
    assert n.id in ids(login_as(sv.user).get(URL)) and n.id in ids(
        login_as(lop.giao_vien.user).get(URL)
    )

    assert (
        pdt.post(
            "/api/schedules/",
            {
                "lop_hoc_phan": lop.id,
                "thu": 4,
                "tiet_bat_dau": 1,
                "so_tiet_moi_buoi": 2,
                "phong": "C3",
            },
        ).status_code
        == 201
    )
    assert pdt.delete(f"/api/schedules/{lich.id}/").status_code == 204
    assert Notification.objects.count() == 3


def test_lop_ke_hoach_doi_lich_khong_bao(login_as):
    pdt = login_as(UserFactory(role=Role.PHONG_DAO_TAO))
    lop = ClassSectionFactory()  # KE_HOACH
    lich = ScheduleFactory(lop_hoc_phan=lop)
    assert pdt.patch(f"/api/schedules/{lich.id}/", {"phong": "Z9"}).status_code == 200
    assert Notification.objects.count() == 0
