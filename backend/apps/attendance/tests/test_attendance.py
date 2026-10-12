"""Điểm danh (BR-19/20): buổi sinh sẵn, lưu cả lớp, tỷ lệ vắng + cờ, yêu cầu sửa điểm danh."""

from datetime import date

import pytest
from django.core.files.uploadedfile import SimpleUploadedFile

from apps.attendance.models import Attendance, AttendanceRequest, AttendanceSession
from apps.attendance.services import chi_so_vang, dong_bo_buoi
from apps.audit.models import AuditLog
from apps.auth.models import Role
from apps.config.models import SystemConfig
from apps.registration.models import Registration
from apps.training.models import Schedule, TrangThaiDon, TrangThaiLop
from core.factories import (
    ClassSectionFactory,
    ScheduleFactory,
    StudentProfileFactory,
    TeacherProfileFactory,
    UserFactory,
)

pytestmark = pytest.mark.django_db
SES, REQ = "/api/attendance/sessions/", "/api/attendance/requests/"
PNG = b"\x89PNG\r\n\x1a\n" + b"0" * 64


def tao_lop(tu, den, thu=(5,), trang_thai=TrangThaiLop.DANG_HOC, n_sv=3, **kw):
    lop = ClassSectionFactory(ngay_bat_dau=tu, ngay_ket_thuc=den, trang_thai=trang_thai, **kw)
    for i, t in enumerate(thu):
        ScheduleFactory(
            lop_hoc_phan=lop, thu=t, tiet_bat_dau=1, so_tiet_moi_buoi=3, phong=f"P{lop.id}-{i}"
        )
    sv = [StudentProfileFactory() for _ in range(n_sv)]
    for p in sv:
        Registration.objects.create(sinh_vien=p.user, lop_hoc_phan=lop)
    return lop, sv


@pytest.fixture
def lop_cu():
    """Lớp 03/09–08/10/2020, chỉ thứ 5 → 6 buổi (03, 10, 17, 24/09, 01, 08/10), đều ở quá khứ."""
    lop, sv = tao_lop(date(2020, 9, 3), date(2020, 10, 8))
    dong_bo_buoi(lop, hom_nay=date(2020, 9, 1))
    return lop, sv


def api_gv(login_as, lop):
    return login_as(lop.giao_vien.user)


def body(sv, trang_thai="CO_MAT", **kw):
    return {"records": [{"sinh_vien": p.user_id, "trang_thai": trang_thai, **kw} for p in sv]}


# --------------------------------------------------------------- sinh buổi (BR-20a)


def test_lop_thu_5_tu_01_10_den_05_11_co_dung_6_buoi():
    lop, _ = tao_lop(date(2026, 10, 1), date(2026, 11, 5), trang_thai=TrangThaiLop.MO)
    moi, xoa = dong_bo_buoi(lop, hom_nay=date(2026, 9, 1))
    ngay = [s.ngay_hoc for s in lop.buoi_diem_danh.all()]
    assert (moi, xoa) == (6, 0)
    assert ngay == [date(2026, 10, d) for d in (1, 8, 15, 22, 29)] + [date(2026, 11, 5)]
    assert dong_bo_buoi(lop, hom_nay=date(2026, 9, 1)) == (0, 0)  # chạy lại không đổi gì


def test_buoi_sinh_san_khi_mo_lop_qua_api(login_as):
    from apps.training.models import TrangThaiLop as T

    pdt = login_as(UserFactory(role=Role.PHONG_DAO_TAO))
    lop, _ = tao_lop(date(2030, 10, 3), date(2030, 11, 7), trang_thai=T.KE_HOACH, n_sv=0)
    assert pdt.post(f"/api/class-sections/{lop.id}/open/").status_code == 200
    assert lop.buoi_diem_danh.count() == 6


def test_sua_lich_chi_doi_buoi_tuong_lai_chua_diem_danh():
    lop, sv = tao_lop(date(2026, 10, 1), date(2026, 11, 5), trang_thai=TrangThaiLop.DANG_HOC)
    dong_bo_buoi(lop, hom_nay=date(2026, 9, 1))
    da_dd = lop.buoi_diem_danh.get(ngay_hoc=date(2026, 10, 8))
    da_dd.trang_thai = "DA_DIEM_DANH"
    da_dd.save()
    Attendance.objects.create(
        attendance_session=da_dd, lop_hoc_phan=lop, ngay_hoc=da_dd.ngay_hoc, sinh_vien=sv[0].user
    )

    # Đổi từ thứ 5 sang thứ 2; "hôm nay" = 16/10 → buổi 22/10, 29/10, 05/11 (tương lai, chưa ĐD) bị xóa
    Schedule.objects.filter(lop_hoc_phan=lop).update(thu=2)
    moi, xoa = dong_bo_buoi(lop, hom_nay=date(2026, 10, 16))
    ngay = {s.ngay_hoc for s in lop.buoi_diem_danh.all()}
    assert xoa == 3 and date(2026, 10, 22) not in ngay
    assert {date(2026, 10, 1), date(2026, 10, 8), date(2026, 10, 15)} <= ngay  # quá khứ giữ nguyên
    assert date(2026, 10, 8) in ngay  # buổi đã điểm danh giữ nguyên
    assert date(2026, 10, 19) in ngay and date(2026, 11, 2) in ngay  # thứ 2 mới


def _hoc_ky_tuong_lai():
    from core.factories import SemesterFactory

    return SemesterFactory(
        ngay_bat_dau=date(2099, 1, 1),
        ngay_ket_thuc=date(2099, 6, 30),
        cua_so_dk_bat_dau=date(2099, 1, 1).isoformat() + "T01:00:00+00:00",
        cua_so_dk_ket_thuc=date(2099, 1, 10).isoformat() + "T01:00:00+00:00",
    )


def test_doi_ngay_ket_thuc_qua_api_xoa_buoi_tuong_lai_chua_diem_danh(login_as):
    pdt = login_as(UserFactory(role=Role.PHONG_DAO_TAO))
    lop, _ = tao_lop(
        date(2099, 2, 5),
        date(2099, 3, 12),
        trang_thai=TrangThaiLop.MO,
        n_sv=0,
        hoc_ky=_hoc_ky_tuong_lai(),
    )
    dong_bo_buoi(lop, hom_nay=date(2098, 1, 1))
    assert lop.buoi_diem_danh.count() == 6  # 05, 12, 19, 26/02, 05, 12/03

    res = pdt.patch(f"/api/class-sections/{lop.id}/", {"ngay_ket_thuc": "2099-02-20"})
    assert res.status_code == 200
    assert lop.buoi_diem_danh.count() == 3  # chỉ còn 05, 12, 19/02


def test_them_lich_qua_api_sinh_buoi_xoa_lich_cuoi_bi_chan(login_as):
    pdt = login_as(UserFactory(role=Role.PHONG_DAO_TAO))
    lop, _ = tao_lop(
        date(2099, 2, 1),
        date(2099, 2, 28),
        trang_thai=TrangThaiLop.MO,
        n_sv=0,
        thu=(),
        hoc_ky=_hoc_ky_tuong_lai(),
    )
    ok = pdt.post(
        "/api/schedules/",
        {"lop_hoc_phan": lop.id, "thu": 3, "tiet_bat_dau": 1, "so_tiet_moi_buoi": 3, "phong": "R1"},
    )
    assert ok.status_code == 201
    # thứ 3 trong 01–28/02/2099: 03, 10, 17, 24 → 4 buổi, sinh ngay vì lớp đang MO
    assert lop.buoi_diem_danh.count() == 4
    # lớp MO phải còn ít nhất một lịch → không xóa được lịch cuối, buổi giữ nguyên
    assert pdt.delete(f"/api/schedules/{ok.data['id']}/").status_code == 409
    assert lop.buoi_diem_danh.count() == 4


# --------------------------------------------------------------- tỷ lệ vắng (BR-20c)


@pytest.mark.parametrize(
    "tong,vang,co_co",
    [
        (6, 0, False),
        (6, 1, False),
        (6, 2, True),
        (10, 2, False),
        (10, 3, True),
        (5, 1, False),
        (5, 2, True),
    ],
)
def test_co_canh_bao_khi_vang_khong_phep_vuot_20_phan_tram(tong, vang, co_co):
    assert chi_so_vang(tong, vang, 20)["canh_bao_vang"] is co_co


def test_chi_so_vang_cho_phep_va_ty_le():
    r = chi_so_vang(6, 2, 20)
    assert r["so_buoi_vang_cho_phep"] == 1 and r["ty_le_vang"] == 33.3
    assert chi_so_vang(0, 0, 20) == {
        "ty_le_vang": 0.0,
        "so_buoi_vang_cho_phep": 0,
        "canh_bao_vang": False,
    }


# --------------------------------------------------------------- xem buổi


def test_danh_sach_buoi_kem_tong_so_buoi_va_phan_quyen(login_as, lop_cu):
    lop, _ = lop_cu
    res = api_gv(login_as, lop).get(f"{SES}?lop_hoc_phan={lop.id}")
    assert res.status_code == 200 and res.data["tong_so_buoi"] == 6 and res.data["count"] == 6

    assert (
        login_as(UserFactory(role=Role.PHONG_DAO_TAO))
        .get(f"{SES}?lop_hoc_phan={lop.id}")
        .status_code
        == 200
    )
    khac = login_as(TeacherProfileFactory().user)
    assert khac.get(f"{SES}?lop_hoc_phan={lop.id}").status_code == 403
    assert (
        login_as(UserFactory(role=Role.SINH_VIEN)).get(f"{SES}?lop_hoc_phan={lop.id}").status_code
        == 403
    )
    assert api_gv(login_as, lop).get(SES).status_code == 400
    assert api_gv(login_as, lop).post(SES, {}).status_code == 405  # không có API tạo buổi


# --------------------------------------------------------------- lưu điểm danh cả lớp


def test_gv_luu_ca_lop_buoi_chuyen_da_diem_danh_vang_thi_bo_di_tre(login_as, lop_cu):
    lop, sv = lop_cu
    gv = api_gv(login_as, lop)
    buoi = lop.buoi_diem_danh.first()
    url = f"{SES}{buoi.id}/records/"

    ds = gv.get(url)
    assert ds.status_code == 200 and ds.data["co_the_diem_danh"] is True
    assert [r["da_luu"] for r in ds.data["records"]] == [False] * 3
    assert {r["trang_thai"] for r in ds.data["records"]} == {"CO_MAT"}  # mặc định

    payload = {
        "records": [
            {"sinh_vien": sv[0].user_id, "trang_thai": "CO_MAT", "di_tre": True},
            {
                "sinh_vien": sv[1].user_id,
                "trang_thai": "VANG_KHONG_PHEP",
                "di_tre": True,
                "ghi_chu": "Không báo",
            },
            {"sinh_vien": sv[2].user_id, "trang_thai": "VANG_CO_PHEP"},
        ]
    }
    res = gv.put(url, payload, format="json")
    assert res.status_code == 200
    buoi.refresh_from_db()
    assert buoi.trang_thai == "DA_DIEM_DANH"
    a = {x.sinh_vien_id: x for x in Attendance.objects.filter(attendance_session=buoi)}
    assert a[sv[0].user_id].di_tre is True  # đi trễ = CO_MAT + di_tre
    assert a[sv[1].user_id].di_tre is False  # vắng → server tự đặt false (BR-19)
    assert a[sv[1].user_id].ghi_chu == "Không báo"
    assert AuditLog.objects.filter(
        doi_tuong="AttendanceSession", doi_tuong_id=str(buoi.id)
    ).exists()

    # Lưu lại (sửa) vẫn được và không nhân đôi dòng
    payload["records"][1]["trang_thai"] = "CO_MAT"
    assert gv.put(url, payload, format="json").status_code == 200
    assert Attendance.objects.filter(attendance_session=buoi).count() == 3


def test_luu_phai_dung_danh_sach_sv_dang_ky(login_as, lop_cu):
    lop, sv = lop_cu
    gv = api_gv(login_as, lop)
    url = f"{SES}{lop.buoi_diem_danh.first().id}/records/"
    thieu = gv.put(url, body(sv[:2]), format="json")
    assert thieu.status_code == 400 and "records" in thieu.data

    la = StudentProfileFactory()  # không đăng ký lớp
    thua = gv.put(url, body([*sv, la]), format="json")
    assert thua.status_code == 400

    lap = gv.put(url, body([*sv, sv[0]]), format="json")
    assert lap.status_code == 400
    sai = gv.put(
        url, {"records": [{"sinh_vien": sv[0].user_id, "trang_thai": "KHAC"}]}, format="json"
    )
    assert sai.status_code == 400
    assert Attendance.objects.count() == 0


def test_sv_huy_dang_ky_khong_con_trong_danh_sach(login_as, lop_cu):
    lop, sv = lop_cu
    Registration.objects.filter(sinh_vien=sv[2].user).update(trang_thai="DA_HUY")
    gv = api_gv(login_as, lop)
    url = f"{SES}{lop.buoi_diem_danh.first().id}/records/"
    assert len(gv.get(url).data["records"]) == 2
    assert gv.put(url, body(sv[:2]), format="json").status_code == 200


def test_chi_diem_danh_buoi_den_ngay_va_lop_dang_hoc(login_as):
    lop, sv = tao_lop(date(2099, 1, 7), date(2099, 2, 4))  # buổi ở tương lai
    dong_bo_buoi(lop, hom_nay=date(2098, 1, 1))
    gv = api_gv(login_as, lop)
    url = f"{SES}{lop.buoi_diem_danh.first().id}/records/"
    res = gv.put(url, body(sv), format="json")
    assert res.status_code == 409 and res.data["error"]["code"] == "TRANG_THAI_KHONG_HOP_LE"
    assert gv.get(url).data["co_the_diem_danh"] is False

    cu, sv2 = tao_lop(date(2020, 9, 3), date(2020, 10, 8), trang_thai=TrangThaiLop.DA_DONG)
    dong_bo_buoi(cu, hom_nay=date(2020, 9, 1))
    res = api_gv(login_as, cu).put(
        f"{SES}{cu.buoi_diem_danh.first().id}/records/", body(sv2), format="json"
    )
    assert res.status_code == 409


def test_phan_quyen_records(login_as, lop_cu):
    lop, sv = lop_cu
    url = f"{SES}{lop.buoi_diem_danh.first().id}/records/"
    khac = login_as(TeacherProfileFactory().user)
    assert khac.get(url).status_code == 403
    assert khac.put(url, body(sv), format="json").status_code == 403
    pdt = login_as(UserFactory(role=Role.PHONG_DAO_TAO))
    assert pdt.get(url).status_code == 200  # PĐT xem được
    assert pdt.put(url, body(sv), format="json").status_code == 403  # nhưng không điểm danh
    assert login_as(sv[0].user).get(url).status_code == 403
    assert api_gv(login_as, lop).get(f"{SES}999999/records/").status_code == 404


def test_ty_le_vang_tren_records_va_attendance_my(login_as, lop_cu):
    lop, sv = lop_cu
    gv = api_gv(login_as, lop)
    for i, buoi in enumerate(lop.buoi_diem_danh.all()[:3]):
        records = [
            {"sinh_vien": sv[0].user_id, "trang_thai": "VANG_KHONG_PHEP"},
            {"sinh_vien": sv[1].user_id, "trang_thai": "VANG_KHONG_PHEP" if i == 0 else "CO_MAT"},
            {"sinh_vien": sv[2].user_id, "trang_thai": "VANG_CO_PHEP"},  # vắng có phép: không tính
        ]
        assert (
            gv.put(f"{SES}{buoi.id}/records/", {"records": records}, format="json").status_code
            == 200
        )

    ds = gv.get(f"{SES}{lop.buoi_diem_danh.all()[3].id}/records/").data
    assert ds["tong_so_buoi"] == 6 and ds["max_absent_pct"] == 20
    by = {r["sinh_vien"]: r for r in ds["records"]}
    assert (by[sv[0].user_id]["so_buoi_vang_kp"], by[sv[0].user_id]["canh_bao_vang"]) == (3, True)
    assert (by[sv[1].user_id]["so_buoi_vang_kp"], by[sv[1].user_id]["canh_bao_vang"]) == (
        1,
        False,
    )  # 1/6 không cờ
    assert by[sv[2].user_id]["so_buoi_vang_kp"] == 0 and not by[sv[2].user_id]["canh_bao_vang"]

    SystemConfig.objects.create(khoa="max_absent_pct", gia_tri="50")  # cấu hình đổi → ngưỡng đổi
    ds = gv.get(f"{SES}{lop.buoi_diem_danh.all()[3].id}/records/").data
    assert {r["sinh_vien"]: r["canh_bao_vang"] for r in ds["records"]}[
        sv[0].user_id
    ] is False  # 3/6 = 50%, không > 50%
    SystemConfig.objects.all().delete()

    from django.utils import timezone

    me = login_as(sv[0].user).get(f"/api/attendance/my/?hoc_ky={lop.hoc_ky_id}")
    assert me.status_code == 200
    mon = me.data["lop_hoc_phan"][0]
    assert (
        mon["tong_so_buoi"],
        mon["so_vang_kp"],
        mon["canh_bao_vang"],
        mon["so_buoi_vang_cho_phep"],
    ) == (6, 3, True, 1)
    trang_thai = [b["trang_thai"] for b in mon["buoi"]]
    assert trang_thai == ["VANG_KHONG_PHEP"] * 3 + [None] * 3  # buổi chưa điểm danh = null
    assert me.data["ten_hk"] == lop.hoc_ky.ten_hk
    assert timezone.now()
    assert login_as(UserFactory(role=Role.GIAO_VIEN)).get("/api/attendance/my/").status_code == 403


# --------------------------------------------------------------- yêu cầu sửa điểm danh


@pytest.fixture
def da_diem_danh(login_as, lop_cu):
    """Buổi đầu đã điểm danh: sv[0] vắng không phép."""
    lop, sv = lop_cu
    buoi = lop.buoi_diem_danh.first()
    records = [{"sinh_vien": p.user_id, "trang_thai": "CO_MAT"} for p in sv]
    records[0]["trang_thai"] = "VANG_KHONG_PHEP"
    assert (
        api_gv(login_as, lop)
        .put(f"{SES}{buoi.id}/records/", {"records": records}, format="json")
        .status_code
        == 200
    )
    return lop, sv, Attendance.objects.get(attendance_session=buoi, sinh_vien=sv[0].user)


def gui(api, att, **kw):
    data = {
        "attendance": att.id,
        "trang_thai_mong_muon": "VANG_CO_PHEP",
        "ly_do": "Ốm có giấy bác sĩ",
        **kw,
    }
    return api.post(REQ, data, format="multipart")


def test_sv_gui_yeu_cau_kem_minh_chung_gv_lop_do_xem_va_tai(
    login_as, da_diem_danh, settings, tmp_path
):
    settings.MEDIA_ROOT = tmp_path
    lop, sv, att = da_diem_danh
    sv_api = login_as(sv[0].user)
    res = gui(sv_api, att, minh_chung=SimpleUploadedFile("giay.png", PNG, content_type="image/png"))
    assert res.status_code == 201
    assert (
        res.data["trang_thai"] == "CHO_DUYET"
        and res.data["trang_thai_hien_tai"] == "VANG_KHONG_PHEP"
    )
    assert res.data["minh_chung"] == f"/api/attendance/requests/{res.data['id']}/minh-chung/"
    assert res.data["ma_sv"] == sv[0].ma_sv

    gv = api_gv(login_as, lop)
    ds = gv.get(REQ)
    assert ds.data["count"] == 1 and ds.data["results"][0]["id"] == res.data["id"]
    tai = gv.get(res.data["minh_chung"])
    assert tai.status_code == 200 and b"".join(tai.streaming_content) == PNG
    assert sv_api.get(res.data["minh_chung"]).status_code == 200  # SV chủ yêu cầu

    assert login_as(sv[1].user).get(res.data["minh_chung"]).status_code == 404  # SV khác
    assert (
        login_as(UserFactory(role=Role.PHONG_DAO_TAO)).get(res.data["minh_chung"]).status_code
        == 403
    )
    assert login_as(TeacherProfileFactory().user).get(REQ).data["count"] == 0  # GV lớp khác
    assert login_as(sv[1].user).get(REQ).data["count"] == 0


def test_rang_buoc_khi_gui_yeu_cau(login_as, da_diem_danh):
    lop, sv, att = da_diem_danh
    api = login_as(sv[0].user)
    assert gui(api, att, ly_do="").status_code == 400  # lý do bắt buộc
    assert (
        gui(api, att, trang_thai_mong_muon="VANG_KHONG_PHEP").status_code == 400
    )  # SV không xin vắng KP
    trung = gui(api, att, trang_thai_mong_muon="VANG_KHONG_PHEP")
    assert trung.status_code == 400
    hien_tai = api.post(
        REQ,
        {
            "attendance": att.id,
            "trang_thai_mong_muon": "CO_MAT",
            "ly_do": "x",
            "di_tre_mong_muon": "false",
        },
        format="multipart",
    )
    assert hien_tai.status_code == 201  # đổi vắng KP → có mặt là khác trạng thái hiện tại
    lan_hai = gui(api, att)
    assert lan_hai.status_code == 409 and lan_hai.data["error"]["code"] == "TRANG_THAI_KHONG_HOP_LE"

    # điểm danh của SV khác
    khac = Attendance.objects.filter(lop_hoc_phan=lop).exclude(sinh_vien=sv[0].user).first()
    assert gui(api, khac).status_code == 400
    assert gui(login_as(UserFactory(role=Role.GIAO_VIEN)), att).status_code == 403


def test_khong_gui_khi_lop_da_dong_va_tep_sai(login_as, da_diem_danh, settings, tmp_path):
    settings.MEDIA_ROOT = tmp_path
    lop, sv, att = da_diem_danh
    api = login_as(sv[0].user)
    lon = SimpleUploadedFile("lon.png", b"0" * (5 * 1024 * 1024 + 1), content_type="image/png")
    assert gui(api, att, minh_chung=lon).status_code == 400
    sai_duoi = SimpleUploadedFile("x.exe", b"MZ", content_type="application/octet-stream")
    assert gui(api, att, minh_chung=sai_duoi).status_code == 400

    lop.trang_thai = TrangThaiLop.DA_DONG
    lop.save()
    res = gui(api, att)
    assert res.status_code == 409 and res.data["error"]["code"] == "TRANG_THAI_KHONG_HOP_LE"


def test_gv_duyet_ghi_lai_diem_danh_tu_choi_giu_nguyen(login_as, da_diem_danh):
    lop, sv, att = da_diem_danh
    gv = api_gv(login_as, lop)
    api = login_as(sv[0].user)
    yc = gui(api, att, trang_thai_mong_muon="CO_MAT", di_tre_mong_muon="true").data

    ok = gv.patch(
        f"{REQ}{yc['id']}/", {"trang_thai": "DUYET", "ghi_chu": "Đã xác minh"}, format="json"
    )
    assert ok.status_code == 200 and ok.data["trang_thai"] == "DUYET"
    att.refresh_from_db()
    assert (att.trang_thai, att.di_tre) == ("CO_MAT", True)  # đi trễ = CO_MAT + di_tre
    obj = AttendanceRequest.objects.get(pk=yc["id"])
    assert obj.nguoi_duyet == lop.giao_vien.user and obj.ngay_duyet is not None
    assert (
        gv.patch(f"{REQ}{yc['id']}/", {"trang_thai": "TU_CHOI"}, format="json").status_code == 409
    )  # đã xử lý

    yc2 = gui(api, att, trang_thai_mong_muon="VANG_CO_PHEP").data
    tu_choi = gv.patch(
        f"{REQ}{yc2['id']}/",
        {"trang_thai": "TU_CHOI", "ghi_chu": "Thiếu minh chứng"},
        format="json",
    )
    assert tu_choi.status_code == 200 and tu_choi.data["trang_thai"] == TrangThaiDon.TU_CHOI
    att.refresh_from_db()
    assert att.trang_thai == "CO_MAT"  # từ chối không đổi điểm danh
    assert AuditLog.objects.filter(doi_tuong="AttendanceRequest", hanh_dong="UPDATE").count() == 2


def test_chi_gv_lop_do_duyet_pdt_va_sv_khong(login_as, da_diem_danh):
    lop, sv, att = da_diem_danh
    yc = gui(login_as(sv[0].user), att).data
    url = f"{REQ}{yc['id']}/"
    quyet = {"trang_thai": "DUYET"}
    assert (
        login_as(UserFactory(role=Role.PHONG_DAO_TAO)).patch(url, quyet, format="json").status_code
        == 403
    )
    assert login_as(sv[0].user).patch(url, quyet, format="json").status_code == 403
    assert (
        login_as(TeacherProfileFactory().user).patch(url, quyet, format="json").status_code == 404
    )
    assert AttendanceRequest.objects.get(pk=yc["id"]).trang_thai == "CHO_DUYET"

    lop.trang_thai = TrangThaiLop.DA_DONG
    lop.save()
    res = api_gv(login_as, lop).patch(url, quyet, format="json")
    assert res.status_code == 409  # lớp đã đóng: không duyệt nữa


def test_attendance_my_hien_yeu_cau_gan_nhat(login_as, da_diem_danh):
    lop, sv, att = da_diem_danh
    api = login_as(sv[0].user)
    gui(api, att)
    buoi = api.get(f"/api/attendance/my/?hoc_ky={lop.hoc_ky_id}").data["lop_hoc_phan"][0]["buoi"][0]
    assert buoi["yeu_cau"]["trang_thai"] == "CHO_DUYET" and buoi["attendance"] == att.id
    assert AttendanceSession.objects.filter(pk=buoi["session"]).exists()


def test_lop_phu_trach_cua_gv(login_as, lop_cu):
    lop, _ = lop_cu
    ClassSectionFactory(giao_vien=lop.giao_vien, hoc_ky=lop.hoc_ky, ma_lop="KHAC")
    ClassSectionFactory()  # lớp của GV khác
    gv = api_gv(login_as, lop)

    res = gv.get(f"/api/class-sections/my/?hoc_ky={lop.hoc_ky_id}")
    assert res.status_code == 200 and res.data["count"] == 2
    row = next(r for r in res.data["results"] if r["id"] == lop.id)
    assert row["si_so_toi_da"] == lop.si_so_toi_da and row["lich_hoc"][0]["thu"] == 5
    only = gv.get(f"/api/class-sections/my/?hoc_ky={lop.hoc_ky_id}&trang_thai=DANG_HOC")
    assert [r["id"] for r in only.data["results"]] == [lop.id]
    assert (
        login_as(UserFactory(role=Role.SINH_VIEN)).get("/api/class-sections/my/").status_code == 403
    )
    assert gv.get("/api/class-sections/my/?hoc_ky=abc").status_code == 400
