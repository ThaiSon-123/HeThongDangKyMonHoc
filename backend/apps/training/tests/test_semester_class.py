"""Học kỳ, lớp học phần, lịch học, job chuyển trạng thái lớp (PDT-06..09, mục 6, BR-08/09)."""

from datetime import date, timedelta

import pytest
from django.utils import timezone

from apps.attendance.models import Attendance, AttendanceRequest, AttendanceSession
from apps.audit.models import AuditLog
from apps.auth.models import Role
from apps.grades.models import Grade, TrangThaiDiem
from apps.registration.models import Registration
from apps.training.models import (
    TrangThaiDon,
    TrangThaiHocKy,
    TrangThaiLop,
    TrangThaiMon,
)
from apps.training.services import chuyen_trang_thai_lop_hang_ngay
from core.factories import (
    ClassSectionFactory,
    CourseFactory,
    ScheduleFactory,
    SemesterFactory,
    StudentProfileFactory,
    TeacherProfileFactory,
    UserFactory,
)
from jobs.tasks import classes_transition_daily

pytestmark = pytest.mark.django_db
SEM, CLS, SCH = "/api/semesters/", "/api/class-sections/", "/api/schedules/"


@pytest.fixture
def pdt(login_as):
    return login_as(UserFactory(role=Role.PHONG_DAO_TAO))


def lop_co_lich(**kw):
    lop = ClassSectionFactory(**kw)
    ScheduleFactory(lop_hoc_phan=lop)
    return lop


# ----------------------------------------------------------------------- học kỳ

HK_BODY = {
    "ten_hk": "HK1 2026",
    "nam_hoc": "2026-2027",
    "ngay_bat_dau": "2026-09-01",
    "ngay_ket_thuc": "2027-01-15",
    "cua_so_dk_bat_dau": "2026-08-01T08:00:00+07:00",
    "cua_so_dk_ket_thuc": "2026-08-20T08:00:00+07:00",
}


def test_tao_hoc_ky_mac_dinh_tin_chi_12_24_14(pdt):
    res = pdt.post(SEM, HK_BODY)
    # cửa sổ nằm TRƯỚC ngày bắt đầu học kỳ → vi phạm "cửa sổ ⊂ thời gian học kỳ"
    assert res.status_code == 400 and "cua_so_dk_bat_dau" in res.data

    res = pdt.post(
        SEM,
        {
            **HK_BODY,
            "cua_so_dk_bat_dau": "2026-09-01T08:00:00+07:00",
            "cua_so_dk_ket_thuc": "2026-09-14T08:00:00+07:00",
        },
    )
    assert res.status_code == 201
    assert (res.data["tin_chi_toi_thieu"], res.data["tin_chi_toi_da"]) == (12, 24)
    assert res.data["tin_chi_toi_da_canh_bao"] == 14
    assert res.data["trang_thai"] == "MO"


@pytest.mark.parametrize(
    "sua,truong",
    [
        ({"ngay_ket_thuc": "2026-01-01"}, "ngay_ket_thuc"),
        ({"cua_so_dk_ket_thuc": "2026-01-01T00:00:00+07:00"}, "cua_so_dk_ket_thuc"),
        ({"tin_chi_toi_thieu": 0}, "tin_chi_toi_thieu"),
        ({"tin_chi_toi_thieu": 30}, "tin_chi_toi_thieu"),
        ({"tin_chi_toi_da_canh_bao": 25}, "tin_chi_toi_da_canh_bao"),
    ],
)
def test_hoc_ky_du_lieu_sai_bi_chan(pdt, sua, truong):
    hk = SemesterFactory()
    res = pdt.patch(f"{SEM}{hk.id}/", sua)
    assert res.status_code == 400 and truong in res.data


def test_pdt_sua_gioi_han_tin_chi_va_trang_thai_khong_patch_duoc(pdt):
    hk = SemesterFactory()
    res = pdt.patch(
        f"{SEM}{hk.id}/",
        {
            "tin_chi_toi_thieu": 10,
            "tin_chi_toi_da": 20,
            "tin_chi_toi_da_canh_bao": 12,
            "trang_thai": "DONG",
        },
    )
    assert res.status_code == 200
    assert (res.data["tin_chi_toi_da"], res.data["trang_thai"]) == (20, "MO")


def test_sua_cua_so_dang_ky_qua_window(pdt):
    hk = SemesterFactory()
    res = pdt.patch(
        f"{SEM}{hk.id}/window/",
        {
            "cua_so_dk_bat_dau": "2026-02-02T08:00:00+07:00",
            "cua_so_dk_ket_thuc": "2026-02-10T08:00:00+07:00",
        },
    )
    assert res.status_code == 200 and res.data["cua_so_dk_ket_thuc"].startswith("2026-02-10")
    ngoai = pdt.patch(
        f"{SEM}{hk.id}/window/",
        {
            "cua_so_dk_bat_dau": "2026-02-02T08:00:00+07:00",
            "cua_so_dk_ket_thuc": "2026-08-10T08:00:00+07:00",
        },
    )
    assert ngoai.status_code == 400
    assert pdt.patch(f"{SEM}{hk.id}/window/", {"ten_hk": "x"}).status_code == 400


def test_dong_hoc_ky_bi_chan_khi_con_lop_mo_hoac_dang_hoc(pdt):
    hk = SemesterFactory()
    lop = ClassSectionFactory(hoc_ky=hk, trang_thai=TrangThaiLop.MO)
    res = pdt.post(f"{SEM}{hk.id}/close/")
    assert res.status_code == 409 and res.data["error"]["code"] == "TRANG_THAI_KHONG_HOP_LE"

    lop.trang_thai = TrangThaiLop.DANG_HOC
    lop.save()
    assert pdt.post(f"{SEM}{hk.id}/close/").status_code == 409

    lop.trang_thai = TrangThaiLop.DA_DONG
    lop.save()
    ok = pdt.post(f"{SEM}{hk.id}/close/")
    assert ok.status_code == 200 and ok.data["trang_thai"] == "DONG"
    assert pdt.post(f"{SEM}{hk.id}/close/").status_code == 409  # đã đóng


def test_mo_lai_hoc_ky_va_ghi_audit(pdt):
    hk = SemesterFactory(trang_thai=TrangThaiHocKy.DONG)
    assert pdt.post(f"{SEM}{hk.id}/open/").data["trang_thai"] == "MO"
    assert pdt.post(f"{SEM}{hk.id}/open/").status_code == 409
    assert AuditLog.objects.filter(doi_tuong="Semester", doi_tuong_id=str(hk.id)).exists()


# ----------------------------------------------------------------------- lớp học phần


def body_lop(**kw):
    hk = kw.pop("hoc_ky", None) or SemesterFactory()
    return {
        "ma_lop": "L01",
        "mon_hoc": CourseFactory().id,
        "hoc_ky": hk.id,
        "giao_vien": TeacherProfileFactory().id,
        "si_so_toi_da": 50,
        **kw,
    }


def test_tao_lop_o_ke_hoach_sieu_du_lieu_hop_le(pdt):
    res = pdt.post(CLS, {**body_lop(), "trang_thai": "MO", "si_so_hien_tai": 9})
    assert res.status_code == 201
    assert (res.data["trang_thai"], res.data["si_so_hien_tai"]) == ("KE_HOACH", 0)
    assert res.data["lich_hoc"] == []


def test_tao_lop_chan_mon_ngung_va_ngay_ngoai_hoc_ky(pdt):
    mon = CourseFactory(trang_thai=TrangThaiMon.NGUNG_SU_DUNG)
    assert pdt.post(CLS, body_lop(mon_hoc=mon.id)).status_code == 400
    ngoai = pdt.post(CLS, body_lop(ngay_bat_dau="2020-01-01"))
    assert ngoai.status_code == 400 and "ngay_bat_dau" in ngoai.data
    nguoc = pdt.post(CLS, body_lop(ngay_bat_dau="2026-05-01", ngay_ket_thuc="2026-04-01"))
    assert nguoc.status_code == 400 and "ngay_ket_thuc" in nguoc.data


def test_mo_lop_can_lich_va_mon_dang_dung(pdt):
    lop = ClassSectionFactory()
    res = pdt.post(f"{CLS}{lop.id}/open/")
    assert res.status_code == 409 and res.data["error"]["code"] == "TRANG_THAI_KHONG_HOP_LE"

    ScheduleFactory(lop_hoc_phan=lop)
    lop.mon_hoc.trang_thai = TrangThaiMon.NGUNG_SU_DUNG
    lop.mon_hoc.save()
    assert pdt.post(f"{CLS}{lop.id}/open/").status_code == 409

    lop.mon_hoc.trang_thai = TrangThaiMon.HOAT_DONG
    lop.mon_hoc.save()
    ok = pdt.post(f"{CLS}{lop.id}/open/")
    assert ok.status_code == 200 and ok.data["trang_thai"] == "MO"
    assert len(ok.data["lich_hoc"]) == 1
    assert pdt.post(f"{CLS}{lop.id}/open/").status_code == 409  # đã mở


def test_sua_lop_si_so_khong_nho_hon_hien_tai_va_khong_doi_mon_khi_co_dang_ky(pdt):
    lop = lop_co_lich(trang_thai=TrangThaiLop.MO, si_so_hien_tai=1)
    Registration.objects.create(sinh_vien=StudentProfileFactory().user, lop_hoc_phan=lop)
    assert pdt.patch(f"{CLS}{lop.id}/", {"si_so_toi_da": 30}).status_code == 200
    res = pdt.patch(f"{CLS}{lop.id}/", {"si_so_toi_da": 0})
    assert res.status_code == 400 and "si_so_toi_da" in res.data
    doi = pdt.patch(f"{CLS}{lop.id}/", {"mon_hoc": CourseFactory().id})
    assert doi.status_code == 400 and "mon_hoc" in doi.data
    cung = pdt.patch(f"{CLS}{lop.id}/", {"mon_hoc": lop.mon_hoc_id})
    assert cung.status_code == 200


def test_lop_da_dong_khong_sua_duoc(pdt):
    lop = lop_co_lich(trang_thai=TrangThaiLop.DA_DONG)
    res = pdt.patch(f"{CLS}{lop.id}/", {"si_so_toi_da": 10})
    assert res.status_code == 409
    assert (
        pdt.post(
            f"{SCH}",
            {
                "lop_hoc_phan": lop.id,
                "thu": 3,
                "tiet_bat_dau": 1,
                "so_tiet_moi_buoi": 2,
                "phong": "X",
            },
        ).status_code
        == 409
    )


def test_doi_giao_vien_trung_lich_bi_chan(pdt):
    hk = SemesterFactory()
    gv = TeacherProfileFactory()
    ScheduleFactory(lop_hoc_phan=ClassSectionFactory(hoc_ky=hk, giao_vien=gv), phong="P1")
    lop = ClassSectionFactory(hoc_ky=hk)
    ScheduleFactory(lop_hoc_phan=lop, phong="P2")  # thứ 2 tiết 1–3, trùng giờ với lớp của gv
    res = pdt.patch(f"{CLS}{lop.id}/", {"giao_vien": gv.id})
    assert res.status_code == 400 and "giao_vien" in res.data
    assert (
        pdt.patch(f"{CLS}{lop.id}/", {"giao_vien": TeacherProfileFactory().id}).status_code == 200
    )


def test_loc_lop_theo_hoc_ky_khoa_nganh(pdt):
    from core.factories import CurriculumFactory

    lop = lop_co_lich()
    ct = CurriculumFactory()
    pdt.post("/api/curriculum-courses/", {"ctdt": ct.id, "mon_hoc": lop.mon_hoc_id})
    lop_khac = lop_co_lich()
    assert pdt.get(f"{CLS}?hoc_ky={lop.hoc_ky_id}").data["count"] == 1
    assert pdt.get(f"{CLS}?khoa={lop_khac.mon_hoc.khoa_id}").data["count"] == 1
    assert [x["id"] for x in pdt.get(f"{CLS}?nganh={ct.nganh_id}").data["results"]] == [lop.id]


def test_gia_han_nhap_diem_ghi_audit(pdt):
    lop = lop_co_lich(trang_thai=TrangThaiLop.DANG_HOC)
    res = pdt.post(f"{CLS}{lop.id}/grade-deadline/", {"han_nhap_diem": "2026-07-15"})
    assert res.status_code == 200 and res.data["han_nhap_diem"] == "2026-07-15"
    log = AuditLog.objects.filter(doi_tuong="ClassSection", doi_tuong_id=str(lop.id)).latest("id")
    assert log.chi_tiet["den"] == "2026-07-15"
    assert pdt.post(f"{CLS}{lop.id}/grade-deadline/", {}).status_code == 400
    # gia hạn phải dời hạn ra xa hơn hạn hiện tại
    lui = pdt.post(f"{CLS}{lop.id}/grade-deadline/", {"han_nhap_diem": "2026-07-15"})
    assert lui.status_code == 400 and "han_nhap_diem" in lui.data


# ----------------------------------------------------------------------- lịch học


def body_lich(lop, **kw):
    return {
        "lop_hoc_phan": lop.id,
        "thu": 3,
        "tiet_bat_dau": 1,
        "so_tiet_moi_buoi": 3,
        "phong": "B1",
        **kw,
    }


def test_lich_thu_2_den_8_chu_nhat_hop_le_thu_1_9_bi_chan(pdt):
    lop = ClassSectionFactory()
    for thu in (2, 7, 8):
        assert pdt.post(SCH, body_lich(lop, thu=thu, phong=f"R{thu}")).status_code == 201
    for thu in (1, 9):
        assert pdt.post(SCH, body_lich(lop, thu=thu)).status_code == 400


@pytest.mark.parametrize(
    "bat_dau,so_tiet,ok",
    [
        (1, 5, True),
        (1, 6, False),
        (4, 2, True),
        (4, 3, False),
        (6, 5, True),
        (9, 2, True),
        (9, 3, False),
        (11, 5, True),
        (13, 4, False),
    ],
)
def test_lich_khong_vuot_nhom_tiet(pdt, bat_dau, so_tiet, ok):
    lop = ClassSectionFactory()
    res = pdt.post(SCH, body_lich(lop, tiet_bat_dau=bat_dau, so_tiet_moi_buoi=so_tiet))
    assert res.status_code == (201 if ok else 400)
    if ok:
        assert res.data["tiet_ket_thuc"] == bat_dau + so_tiet - 1


def test_phong_va_giao_vien_khong_giao_tiet_cung_thu(pdt):
    hk = SemesterFactory()
    gv = TeacherProfileFactory()
    lop_a = ClassSectionFactory(hoc_ky=hk, giao_vien=gv)
    ScheduleFactory(lop_hoc_phan=lop_a, thu=2, tiet_bat_dau=1, so_tiet_moi_buoi=3, phong="A101")

    lop_b = ClassSectionFactory(hoc_ky=hk)
    trung_phong = pdt.post(
        SCH, body_lich(lop_b, thu=2, tiet_bat_dau=3, so_tiet_moi_buoi=2, phong="a101")
    )
    assert trung_phong.status_code == 400 and "phong" in trung_phong.data
    ke_nhau = pdt.post(
        SCH, body_lich(lop_b, thu=2, tiet_bat_dau=4, so_tiet_moi_buoi=2, phong="A101")
    )
    assert ke_nhau.status_code == 201  # tiết 4–5 không giao tiết 1–3
    khac_thu = pdt.post(
        SCH, body_lich(lop_b, thu=3, tiet_bat_dau=1, so_tiet_moi_buoi=3, phong="A101")
    )
    assert khac_thu.status_code == 201

    lop_c = ClassSectionFactory(hoc_ky=hk, giao_vien=gv)
    trung_gv = pdt.post(
        SCH, body_lich(lop_c, thu=2, tiet_bat_dau=2, so_tiet_moi_buoi=2, phong="Z9")
    )
    assert trung_gv.status_code == 400 and "giao_vien" in trung_gv.data

    # học kỳ khác: cùng phòng/GV/giờ vẫn hợp lệ
    lop_d = ClassSectionFactory(giao_vien=gv)
    assert pdt.post(SCH, body_lich(lop_d, thu=2, tiet_bat_dau=1, phong="A101")).status_code == 201


def test_sua_lich_khong_tu_xung_dot_voi_chinh_no_va_khong_doi_lop(pdt):
    lop = ClassSectionFactory()
    lich = ScheduleFactory(lop_hoc_phan=lop, thu=2, tiet_bat_dau=1, so_tiet_moi_buoi=3)
    assert pdt.patch(f"{SCH}{lich.id}/", {"so_tiet_moi_buoi": 4}).status_code == 200
    doi = pdt.patch(f"{SCH}{lich.id}/", {"lop_hoc_phan": ClassSectionFactory().id})
    assert doi.status_code == 400 and "lop_hoc_phan" in doi.data


def test_hai_lich_cung_lop_cung_thu_khong_giao_tiet_duoc_phep(pdt):
    lop = ClassSectionFactory()
    assert (
        pdt.post(SCH, body_lich(lop, thu=2, tiet_bat_dau=1, so_tiet_moi_buoi=2)).status_code == 201
    )
    assert (
        pdt.post(SCH, body_lich(lop, thu=2, tiet_bat_dau=3, so_tiet_moi_buoi=2)).status_code == 201
    )
    assert (
        pdt.post(SCH, body_lich(lop, thu=2, tiet_bat_dau=2, so_tiet_moi_buoi=2)).status_code == 400
    )


def test_khong_xoa_lich_cuoi_cua_lop_da_mo(pdt):
    lop = ClassSectionFactory(trang_thai=TrangThaiLop.MO)
    l1 = ScheduleFactory(lop_hoc_phan=lop, thu=2)
    l2 = ScheduleFactory(lop_hoc_phan=lop, thu=3)
    assert pdt.delete(f"{SCH}{l1.id}/").status_code == 204
    assert pdt.delete(f"{SCH}{l2.id}/").status_code == 409
    ke_hoach = ScheduleFactory()
    assert pdt.delete(f"{SCH}{ke_hoach.id}/").status_code == 204


# ----------------------------------------------------------------------- đóng lớp + job

HOM_NAY = date(2026, 6, 1)


def lop_da_qua_han(**kw):
    kw.setdefault("trang_thai", TrangThaiLop.DANG_HOC)
    return ClassSectionFactory(ngay_bat_dau=date(2026, 3, 1), ngay_ket_thuc=date(2026, 5, 31), **kw)


def dang_ky(lop, diem=None):
    sv = StudentProfileFactory().user
    Registration.objects.create(sinh_vien=sv, lop_hoc_phan=lop)
    if diem:
        Grade.objects.create(lop_hoc_phan=lop, sinh_vien=sv, trang_thai=diem)
    return sv


def test_dong_lop_can_het_han_va_du_diem_chinh_thuc(pdt):
    lop = lop_co_lich(trang_thai=TrangThaiLop.DANG_HOC)
    lop.ngay_ket_thuc = timezone.localdate() + timedelta(days=5)
    lop.ngay_bat_dau = timezone.localdate() - timedelta(days=30)
    lop.save()
    assert pdt.post(f"{CLS}{lop.id}/close/").status_code == 409  # chưa kết thúc

    lop.ngay_ket_thuc = timezone.localdate() - timedelta(days=1)
    lop.save()
    dang_ky(lop, TrangThaiDiem.CHINH_THUC)
    sv2 = dang_ky(lop, TrangThaiDiem.NHAP_TAM)
    res = pdt.post(f"{CLS}{lop.id}/close/")
    assert res.status_code == 409 and "chưa có điểm" in res.data["error"]["message"]

    Grade.objects.filter(sinh_vien=sv2).update(trang_thai=TrangThaiDiem.CHINH_THUC)
    ok = pdt.post(f"{CLS}{lop.id}/close/")
    assert ok.status_code == 200 and ok.data["trang_thai"] == "DA_DONG"


def test_dong_lop_bo_qua_dang_ky_da_huy_va_tu_choi_yeu_cau_cho_duyet():
    lop = lop_da_qua_han()
    huy = dang_ky(lop)
    Registration.objects.filter(sinh_vien=huy).update(trang_thai="DA_HUY")
    sv = dang_ky(lop, TrangThaiDiem.KHOA)
    phien = AttendanceSession.objects.create(
        lop_hoc_phan=lop, ngay_hoc=date(2026, 3, 5), buoi="SANG", tiet_bat_dau=1
    )
    dd = Attendance.objects.create(
        attendance_session=phien,
        lop_hoc_phan=lop,
        ngay_hoc=phien.ngay_hoc,
        sinh_vien=sv,
        trang_thai="VANG_KHONG_PHEP",
    )
    yc = AttendanceRequest.objects.create(
        attendance=dd, sinh_vien=sv, ly_do="Ốm", trang_thai_mong_muon="VANG_CO_PHEP"
    )
    from apps.training.services import dong_lop

    dong_lop(lop, HOM_NAY)
    yc.refresh_from_db()
    assert (yc.trang_thai, yc.ghi_chu, yc.nguoi_duyet) == (
        TrangThaiDon.TU_CHOI,
        "Quá hạn — lớp đã đóng",
        None,
    )


def test_job_chuyen_trang_thai_hang_ngay_idempotent():
    mo_chua_toi = ClassSectionFactory(
        trang_thai=TrangThaiLop.MO, ngay_bat_dau=date(2026, 6, 10), ngay_ket_thuc=date(2026, 6, 20)
    )
    mo_toi_ngay = ClassSectionFactory(
        trang_thai=TrangThaiLop.MO, ngay_bat_dau=date(2026, 6, 1), ngay_ket_thuc=date(2026, 6, 20)
    )
    theo_hoc_ky = ClassSectionFactory(trang_thai=TrangThaiLop.MO)  # ngay_bat_dau NULL → 01/02/2026
    du_dieu_kien = lop_da_qua_han()
    dang_ky(du_dieu_kien, TrangThaiDiem.CHINH_THUC)
    thieu_diem = lop_da_qua_han()
    dang_ky(thieu_diem)
    chua_het = ClassSectionFactory(
        trang_thai=TrangThaiLop.DANG_HOC,
        ngay_bat_dau=date(2026, 5, 1),
        ngay_ket_thuc=date(2026, 6, 30),
    )
    ke_hoach = ClassSectionFactory(ngay_bat_dau=date(2026, 3, 1))

    assert chuyen_trang_thai_lop_hang_ngay(HOM_NAY) == (2, 1)
    assert chuyen_trang_thai_lop_hang_ngay(HOM_NAY) == (0, 0)  # chạy lại không đổi gì thêm

    for lop in (
        mo_chua_toi,
        mo_toi_ngay,
        theo_hoc_ky,
        du_dieu_kien,
        thieu_diem,
        chua_het,
        ke_hoach,
    ):
        lop.refresh_from_db()
    assert mo_chua_toi.trang_thai == TrangThaiLop.MO
    assert mo_toi_ngay.trang_thai == theo_hoc_ky.trang_thai == TrangThaiLop.DANG_HOC
    assert du_dieu_kien.trang_thai == TrangThaiLop.DA_DONG
    assert thieu_diem.trang_thai == chua_het.trang_thai == TrangThaiLop.DANG_HOC
    assert ke_hoach.trang_thai == TrangThaiLop.KE_HOACH


def test_task_celery_goi_service():
    homnay = timezone.localdate()
    lop = ClassSectionFactory(
        trang_thai=TrangThaiLop.MO,
        ngay_bat_dau=homnay - timedelta(days=1),
        ngay_ket_thuc=homnay + timedelta(days=30),
    )
    assert classes_transition_daily()[0] >= 1
    lop.refresh_from_db()
    assert lop.trang_thai == TrangThaiLop.DANG_HOC
