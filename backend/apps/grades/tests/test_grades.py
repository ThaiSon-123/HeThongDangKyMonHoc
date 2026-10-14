"""Điểm (BR-10..14, BR-25): tổng kết, thang chữ, nhập cả lớp, khóa, duyệt, GPA, grades/my."""

from datetime import date, timedelta
from decimal import Decimal

import pytest
from django.utils import timezone

from apps.audit.models import AuditLog
from apps.auth.models import Role
from apps.grades.models import Grade
from apps.grades.services import cap_nhat_ho_so, tinh_tong_ket, tong_hop_diem, xep_loai_diem
from apps.notifications.models import Notification
from apps.profiles.models import StudentProfile
from apps.registration.models import Registration
from apps.training.models import TrangThaiLop
from apps.training.services import dong_lop
from core.factories import (
    ClassSectionFactory,
    CourseFactory,
    SemesterFactory,
    StudentProfileFactory,
    TeacherProfileFactory,
    UserFactory,
)

pytestmark = pytest.mark.django_db
D = Decimal


# --------------------------------------------------------------- BR-10 / BR-11 (hàm thuần)


@pytest.mark.parametrize(
    "qt,gk,ck,ket_qua",
    [
        (8, 7, 9, "8.10"),  # 0.8 + 2.8 + 4.5
        (8, None, 6, "6.40"),  # thiếu GK → 20/80
        (8, 0, 6, "3.80"),  # GK = 0 (đã nhập) KHÁC NULL: công thức thường 0.8 + 0 + 3.0
        (10, 5, None, "3.00"),  # thiếu CK → CK = 0
        (None, None, None, None),  # chưa nhập gì
        (D("8.45"), D("8.45"), D("8.45"), "8.45"),
        (7, 7, D("7.05"), "7.03"),  # 0.7 + 2.8 + 3.525 = 7.025 → làm tròn nửa lên
    ],
)
def test_tong_ket_br10(qt, gk, ck, ket_qua):
    r = tinh_tong_ket(qt, gk, ck)
    assert (None if r is None else str(r)) == ket_qua


def test_null_khac_khong_o_giua_ky():
    thieu = tinh_tong_ket(8, None, 6)  # bỏ GK, 20/80
    nhap_0 = tinh_tong_ket(8, 0, 6)  # GK = 0 vẫn tính 40%
    assert thieu == D("6.40") and nhap_0 == D("3.80")


@pytest.mark.parametrize(
    "tong,chu,gpa",
    [
        ("8.45", "B", "3.0"),
        ("6.95", "C", "2.0"),
        ("5.45", "D", "1.0"),
        ("8.50", "A", "4.0"),
        ("7.00", "B", "3.0"),
        ("5.50", "C", "2.0"),
        ("4.00", "D", "1.0"),
        ("3.99", "F", "0.0"),
        ("10", "A", "4.0"),
    ],
)
def test_thang_chu_br11_band_lien_tuc(tong, chu, gpa):
    assert xep_loai_diem(D(tong)) == (chu, D(gpa))


def test_mon_dat_khong_dat_p_khong_vao_gpa_f_van_vao():
    assert xep_loai_diem(D("5.00"), "DAT_KHONG_DAT") == ("P", None)
    assert xep_loai_diem(D("4.99"), "DAT_KHONG_DAT") == ("F", D("0.0"))
    assert xep_loai_diem(None) == ("", None)


# --------------------------------------------------------------- dựng dữ liệu


def tao_lop(n_sv=3, **kw):
    """Lớp `DANG_HOC` năm 2099 → còn trong hạn nhập điểm."""
    kw.setdefault("ngay_bat_dau", date(2099, 1, 5))
    kw.setdefault("ngay_ket_thuc", date(2099, 5, 1))
    kw.setdefault("trang_thai", TrangThaiLop.DANG_HOC)
    lop = ClassSectionFactory(**kw)
    sv = [StudentProfileFactory() for _ in range(n_sv)]
    for p in sv:
        Registration.objects.create(sinh_vien=p.user, lop_hoc_phan=lop)
    return lop, sv


def url(lop, tail=""):
    return f"/api/class-sections/{lop.id}/grades/{tail}"


def rec(sv, qt=None, gk=None, ck=None):
    return {"sinh_vien": sv.user_id, "diem_qua_trinh": qt, "diem_giua_ky": gk, "diem_cuoi_ky": ck}


@pytest.fixture
def pdt(login_as):
    return login_as(UserFactory(role=Role.PHONG_DAO_TAO))


def gv_api(login_as, lop):
    return login_as(lop.giao_vien.user)


def ma_loi(res):
    return res.data["error"]["code"]


# --------------------------------------------------------------- nhập điểm


def test_gv_nhap_ca_lop_luu_nhap_tam_va_tinh_tong_ket(login_as):
    lop, sv = tao_lop()
    gv = gv_api(login_as, lop)
    res = gv.put(
        url(lop),
        {"records": [rec(sv[0], 8, 7, 9), rec(sv[1], 8, None, 6), rec(sv[2], 10, 5, None)]},
        format="json",
    )
    assert res.status_code == 200
    by = {r["sinh_vien"]: r for r in res.data["records"]}
    assert (
        D(by[sv[0].user_id]["diem_tong_ket"]) == D("8.10") and by[sv[0].user_id]["diem_chu"] == "B"
    )
    assert (
        D(by[sv[1].user_id]["diem_tong_ket"]) == D("6.40") and by[sv[1].user_id]["diem_chu"] == "C"
    )
    assert (
        D(by[sv[2].user_id]["diem_tong_ket"]) == D("3.00") and by[sv[2].user_id]["diem_chu"] == "F"
    )
    assert {r["trang_thai"] for r in res.data["records"]} == {"NHAP_TAM"}
    assert res.data["co_the_nhap"] is True and res.data["co_the_khoa"] is True
    assert AuditLog.objects.filter(doi_tuong="Grade", chi_tiet__hanh_dong="nhap_diem").exists()

    # nhập lại (sửa) thay vì nhân đôi
    gv.put(url(lop), {"records": [rec(sv[0], 10, 10, 10)]}, format="json")
    assert Grade.objects.filter(lop_hoc_phan=lop).count() == 3
    assert Grade.objects.get(lop_hoc_phan=lop, sinh_vien=sv[0].user).diem_chu == "A"


def test_diem_ngoai_0_10_va_sv_la_bi_chan(login_as):
    lop, sv = tao_lop()
    gv = gv_api(login_as, lop)
    assert gv.put(url(lop), {"records": [rec(sv[0], 11)]}, format="json").status_code == 400
    assert gv.put(url(lop), {"records": [rec(sv[0], -1)]}, format="json").status_code == 400
    la = StudentProfileFactory()
    assert gv.put(url(lop), {"records": [rec(la)]}, format="json").status_code == 400
    assert gv.put(url(lop), {"records": [rec(sv[0]), rec(sv[0])]}, format="json").status_code == 400
    assert Grade.objects.count() == 0


def test_chi_gv_lop_minh_nhap_diem_br12(login_as):
    lop, sv = tao_lop()
    khac = login_as(TeacherProfileFactory().user)
    assert khac.get(url(lop)).status_code == 403
    assert khac.put(url(lop), {"records": [rec(sv[0], 5)]}, format="json").status_code == 403
    assert login_as(sv[0].user).get(url(lop)).status_code == 403
    assert login_as(UserFactory(role=Role.KE_TOAN)).get(url(lop)).status_code == 403


def test_qua_han_nhap_diem_br13_va_pdt_nhap_ho(login_as, pdt):
    lop, sv = tao_lop(han_nhap_diem=timezone.localdate() - timedelta(days=1))
    gv = gv_api(login_as, lop)
    res = gv.put(url(lop), {"records": [rec(sv[0], 5)]}, format="json")
    assert res.status_code == 409 and ma_loi(res) == "QUA_HAN_NHAP_DIEM"
    assert (
        gv.get(url(lop)).data["qua_han"] is True and gv.get(url(lop)).data["co_the_nhap"] is False
    )

    ho = pdt.put(url(lop), {"records": [rec(sv[0], 6, 6, 6)]}, format="json")  # PĐT nhập hộ
    assert ho.status_code == 200
    g = Grade.objects.get(lop_hoc_phan=lop, sinh_vien=sv[0].user)
    assert g.trang_thai == "CHINH_THUC" and g.diem_tong_ket == D("6.00")  # lưu thẳng CHINH_THUC
    log = AuditLog.objects.filter(doi_tuong="Grade", chi_tiet__hanh_dong="nhap_ho").get()
    assert log.user.role == Role.PHONG_DAO_TAO

    # gia hạn → GV nhập lại được
    pdt.post(f"/api/class-sections/{lop.id}/grade-deadline/", {"han_nhap_diem": "2099-12-31"})
    assert gv.put(url(lop), {"records": [rec(sv[1], 5)]}, format="json").status_code == 200


def test_fallback_han_nhap_diem_khi_ngay_ket_thuc_null(login_as):
    hk = SemesterFactory(ngay_ket_thuc=timezone.localdate() - timedelta(days=30))
    lop, sv = tao_lop(
        hoc_ky=hk, ngay_bat_dau=None, ngay_ket_thuc=None
    )  # 30 ngày trước + 14 = quá hạn
    res = gv_api(login_as, lop).put(url(lop), {"records": [rec(sv[0], 5)]}, format="json")
    assert res.status_code == 409 and ma_loi(res) == "QUA_HAN_NHAP_DIEM"

    hk2 = SemesterFactory(ngay_ket_thuc=timezone.localdate() - timedelta(days=5))
    lop2, sv2 = tao_lop(
        hoc_ky=hk2, ngay_bat_dau=None, ngay_ket_thuc=None
    )  # 5 + ... còn trong 14 ngày
    assert (
        gv_api(login_as, lop2)
        .put(url(lop2), {"records": [rec(sv2[0], 5)]}, format="json")
        .status_code
        == 200
    )


def test_chi_nhap_khi_lop_dang_hoc(login_as):
    for tt in (TrangThaiLop.MO, TrangThaiLop.DA_DONG):
        lop, sv = tao_lop(trang_thai=tt)
        res = gv_api(login_as, lop).put(url(lop), {"records": [rec(sv[0], 5)]}, format="json")
        assert res.status_code == 409 and ma_loi(res) == "TRANG_THAI_KHONG_HOP_LE"


# --------------------------------------------------------------- khóa / mở khóa (BR-14)


def test_khoa_can_du_diem_mo_khoa_ve_nhap_tam_chinh_thuc_khong_sua_truc_tiep(login_as, pdt):
    lop, sv = tao_lop()
    gv = gv_api(login_as, lop)
    gv.put(url(lop), {"records": [rec(sv[0], 8, 8, 8)]}, format="json")

    thieu = gv.post(url(lop, "lock/"), {"action": "lock"}, format="json")
    assert thieu.status_code == 409 and "chưa có điểm" in thieu.data["error"]["message"]

    gv.put(url(lop), {"records": [rec(sv[1], 7, 7, 7), rec(sv[2], 6, 6, 6)]}, format="json")
    ok = gv.post(url(lop, "lock/"), {"action": "lock"}, format="json")
    assert ok.status_code == 200 and {r["trang_thai"] for r in ok.data["records"]} == {"CHINH_THUC"}
    assert ok.data["co_the_mo_khoa"] is True and ok.data["co_the_khoa"] is False

    sua = gv.put(
        url(lop), {"records": [rec(sv[0], 9)]}, format="json"
    )  # đã khóa → phải mở khóa trước
    assert sua.status_code == 409 and ma_loi(sua) == "TRANG_THAI_KHONG_HOP_LE"
    assert pdt.put(url(lop), {"records": [rec(sv[0], 9)]}, format="json").status_code == 409

    mo = gv.post(url(lop, "lock/"), {"action": "unlock"}, format="json")
    assert {r["trang_thai"] for r in mo.data["records"]} == {"NHAP_TAM"}
    assert gv.put(url(lop), {"records": [rec(sv[0], 9)]}, format="json").status_code == 200
    assert AuditLog.objects.filter(chi_tiet__hanh_dong="mo_khoa_diem").exists()


def test_khoa_chi_gv_lop_do_va_trong_han(login_as, pdt):
    lop, sv = tao_lop(n_sv=1)
    gv_api(login_as, lop).put(url(lop), {"records": [rec(sv[0], 8)]}, format="json")
    body = {"action": "lock"}
    assert (
        pdt.post(url(lop, "lock/"), body, format="json").status_code == 403
    )  # PĐT không có quyền khóa
    assert (
        login_as(TeacherProfileFactory().user)
        .post(url(lop, "lock/"), body, format="json")
        .status_code
        == 403
    )
    assert (
        gv_api(login_as, lop).post(url(lop, "lock/"), {"action": "x"}, format="json").status_code
        == 400
    )

    gv_api(login_as, lop).post(url(lop, "lock/"), body, format="json")
    lop.han_nhap_diem = timezone.localdate() - timedelta(days=1)
    lop.save()
    res = gv_api(login_as, lop).post(url(lop, "lock/"), {"action": "unlock"}, format="json")
    assert (
        res.status_code == 409 and ma_loi(res) == "QUA_HAN_NHAP_DIEM"
    )  # hết hạn thì không mở khóa


def test_khoa_bat_bien_khong_mo_khoa_duoc(login_as):
    lop, sv = tao_lop(n_sv=1)
    Grade.objects.create(
        lop_hoc_phan=lop,
        sinh_vien=sv[0].user,
        diem_tong_ket=D("8"),
        diem_chu="B",
        trang_thai="KHOA",
    )
    gv = gv_api(login_as, lop)
    assert gv.post(url(lop, "lock/"), {"action": "unlock"}, format="json").status_code == 200
    assert Grade.objects.get().trang_thai == "KHOA"  # không đổi
    assert gv.put(url(lop), {"records": [rec(sv[0], 1)]}, format="json").status_code == 409


# --------------------------------------------------------------- duyệt (PDT-12) + GPA (BR-25)


def test_luong_day_du_nhap_khoa_dong_duyet_sv_xem_gpa_dung(login_as, pdt):
    lop, sv = tao_lop(n_sv=2, mon_hoc=CourseFactory(tin_chi_ly_thuyet=3, tong_tin_chi=3))
    gv = gv_api(login_as, lop)
    gv.put(url(lop), {"records": [rec(sv[0], 9, 9, 9), rec(sv[1], 5, 5, 5)]}, format="json")
    assert gv.post(url(lop, "lock/"), {"action": "lock"}, format="json").status_code == 200

    assert pdt.post(url(lop, "approve/")).status_code == 409  # lớp chưa đóng
    # lớp kết thúc → job/PĐT đóng (điều kiện: đủ điểm CHINH_THUC)
    lop.ngay_ket_thuc = date(2020, 1, 1)
    lop.han_nhap_diem = date(2099, 1, 1)
    lop.save()
    dong_lop(lop)
    lop.refresh_from_db()
    assert lop.trang_thai == TrangThaiLop.DA_DONG
    assert StudentProfile.objects.get(user=sv[0].user).gpa is None  # chưa duyệt → chưa có GPA
    assert login_as(sv[0].user).get("/api/grades/my/").data["diem"] == []  # SV chỉ thấy điểm KHOA

    res = pdt.post(url(lop, "approve/"))
    assert res.status_code == 200 and res.data["so_sinh_vien"] == 2
    assert set(Grade.objects.values_list("trang_thai", flat=True)) == {"KHOA"}
    assert Notification.objects.filter(tieu_de="Có điểm mới").count() == 2
    assert (
        pdt.post(url(lop, "approve/")).status_code == 200
    )  # duyệt lại: idempotent, không báo trùng
    assert Notification.objects.filter(tieu_de="Có điểm mới").count() == 2

    ho_so = StudentProfile.objects.get(user=sv[0].user)
    assert ho_so.gpa == D("4.00") and ho_so.tin_chi_tich_luy == 3
    me = login_as(sv[1].user).get("/api/grades/my/")
    assert me.status_code == 200
    assert D(me.data["gpa"]) == D("1.00") and me.data["xep_loai"] == "Yếu"  # 5.0 → D = 1.0
    assert me.data["tin_chi_tich_luy"] == 3  # D vẫn tích lũy tín chỉ
    assert len(me.data["diem"]) == 1 and me.data["diem"][0]["diem_chu"] == "D"
    st = me.data["thong_ke"][0]
    assert (st["so_mon"], st["tin_chi_hoc"], st["tin_chi_dat"]) == (1, 3, 3)
    assert D(st["diem_tb"]) == D("5.00") and D(st["gpa"]) == D("1.00")


def test_duyet_chan_khi_con_nhap_tam(pdt):
    lop, sv = tao_lop(n_sv=1, trang_thai=TrangThaiLop.DA_DONG)
    Grade.objects.create(
        lop_hoc_phan=lop, sinh_vien=sv[0].user, diem_chu="B", trang_thai="NHAP_TAM"
    )
    res = pdt.post(url(lop, "approve/"))
    assert res.status_code == 409 and "chưa khóa" in res.data["error"]["message"]
    lop2, _ = tao_lop(n_sv=1, trang_thai=TrangThaiLop.DA_DONG)
    assert pdt.post(url(lop2, "approve/")).status_code == 409  # chưa có điểm nào


def test_chi_pdt_duyet(login_as):
    lop, _ = tao_lop(trang_thai=TrangThaiLop.DA_DONG)
    for who in (Role.SINH_VIEN, Role.KE_TOAN, Role.ADMIN):
        assert login_as(UserFactory(role=who)).post(url(lop, "approve/")).status_code == 403
    assert gv_api(login_as, lop).post(url(lop, "approve/")).status_code == 403


# --------------------------------------------------------------- BR-25 chi tiết


def khoa(sv, lop, tong, chu, gpa):
    return Grade.objects.create(
        lop_hoc_phan=lop,
        sinh_vien=sv.user,
        diem_tong_ket=D(tong),
        diem_chu=chu,
        gpa_thang_4=None if gpa is None else D(gpa),
        trang_thai="KHOA",
    )


def lop_hk(mon, hk):
    return ClassSectionFactory(mon_hoc=mon, hoc_ky=hk, trang_thai=TrangThaiLop.DA_DONG)


def test_hoc_lai_mon_f_chi_tinh_lan_moi_nhat_theo_ngay_bat_dau_hoc_ky():
    sv = StudentProfileFactory()
    cu = SemesterFactory(ngay_bat_dau=date(2025, 2, 1))
    moi = SemesterFactory(ngay_bat_dau=date(2025, 9, 1))
    mon, mon2 = CourseFactory(tong_tin_chi=3, tin_chi_ly_thuyet=3), CourseFactory(
        tong_tin_chi=3, tin_chi_ly_thuyet=3
    )
    # tạo lớp HK mới TRƯỚC để id/ngày tạo bản ghi không thể đánh lừa: phải dùng ngay_bat_dau của học kỳ
    khoa(sv, lop_hk(mon, moi), "6.0", "C", "2.0")  # học lại, đạt C
    khoa(sv, lop_hk(mon, cu), "3.0", "F", "0.0")  # lần đầu F
    khoa(sv, lop_hk(mon2, cu), "9.0", "A", "4.0")

    tong = cap_nhat_ho_so(sv.user)
    # môn 1 chỉ tính lần C (2.0), môn 2 A (4.0): (2×3 + 4×3)/6 = 3.00 ; tín chỉ tích lũy = 6 (F cũ không tính)
    assert tong["gpa"] == D("3.00") and tong["tin_chi_tich_luy"] == 6
    ho_so = StudentProfile.objects.get(user=sv.user)
    assert (ho_so.gpa, ho_so.tin_chi_tich_luy) == (D("3.00"), 6)
    # thống kê học kỳ cũ vẫn thấy lần F (tin_chi_dat không tính F)
    hk_cu = next(s for s in tong["thong_ke"] if s["hoc_ky"] == cu.id)
    assert (hk_cu["so_mon"], hk_cu["tin_chi_hoc"], hk_cu["tin_chi_dat"]) == (2, 6, 3)
    assert hk_cu["gpa"] == D("2.00")  # (0×3 + 4×3)/6


def test_p_bi_loai_ca_tu_lan_mau_f_van_vao_mau_diem_d_cong_tin_chi():
    sv = StudentProfileFactory()
    hk = SemesterFactory()
    mon_p = CourseFactory(tong_tin_chi=2, tin_chi_ly_thuyet=2, loai_danh_gia="DAT_KHONG_DAT")
    mon_f = CourseFactory(tong_tin_chi=2, tin_chi_ly_thuyet=2)
    mon_d = CourseFactory(tong_tin_chi=4, tin_chi_ly_thuyet=4)
    khoa(sv, lop_hk(mon_p, hk), "8.0", "P", None)
    khoa(sv, lop_hk(mon_f, hk), "2.0", "F", "0.0")
    khoa(sv, lop_hk(mon_d, hk), "4.5", "D", "1.0")

    tong = tong_hop_diem(sv.user)
    assert tong["gpa"] == D("0.67")  # (0×2 + 1×4)/(2+4): P ngoài GPA, F vào mẫu
    assert tong["tin_chi_tich_luy"] == 6  # P (2) + D (4); F không tính
    st = tong["thong_ke"][0]
    assert (st["so_mon"], st["tin_chi_hoc"], st["tin_chi_dat"]) == (3, 8, 6)
    assert st["diem_tb"] == D("3.67")  # hệ 10, loại P: (2.0×2 + 4.5×4)/6
    assert st["xep_loai"] == "Kém"


def test_chua_co_diem_khoa_gpa_null():
    sv = StudentProfileFactory()
    tong = cap_nhat_ho_so(sv.user)
    assert tong["gpa"] is None and tong["tin_chi_tich_luy"] == 0 and tong["thong_ke"] == []
    assert StudentProfile.objects.get(user=sv.user).gpa is None


def test_grades_my_chi_sv_va_chi_diem_khoa(login_as):
    sv = StudentProfileFactory()
    hk = SemesterFactory()
    lop_a, lop_b = lop_hk(CourseFactory(), hk), lop_hk(CourseFactory(), hk)
    khoa(sv, lop_a, "8.0", "B", "3.0")
    Grade.objects.create(
        lop_hoc_phan=lop_b, sinh_vien=sv.user, diem_chu="A", trang_thai="CHINH_THUC"
    )
    res = login_as(sv.user).get("/api/grades/my/")
    assert [d["ma_lop"] for d in res.data["diem"]] == [lop_a.ma_lop]
    assert login_as(UserFactory(role=Role.GIAO_VIEN)).get("/api/grades/my/").status_code == 403


# --------------------------------------------------------------- danh sách duyệt


def test_danh_sach_bang_diem_cho_pdt(pdt, login_as):
    lop, sv = tao_lop(n_sv=2, trang_thai=TrangThaiLop.DA_DONG)
    Grade.objects.create(
        lop_hoc_phan=lop, sinh_vien=sv[0].user, trang_thai="CHINH_THUC", diem_chu="A"
    )
    Grade.objects.create(
        lop_hoc_phan=lop, sinh_vien=sv[1].user, trang_thai="NHAP_TAM", diem_chu="B"
    )
    tao_lop(trang_thai=TrangThaiLop.MO)  # lớp MO không có trong danh sách

    res = pdt.get("/api/grade-sheets/")
    assert res.status_code == 200 and res.data["count"] == 1
    row = res.data["results"][0]
    assert (row["so_sv"], row["nhap_tam"], row["chinh_thuc"], row["khoa"]) == (2, 1, 1, 0)
    assert pdt.get("/api/grade-sheets/?trang_thai=DANG_HOC").data["count"] == 0
    assert pdt.get(f"/api/grade-sheets/?search={lop.ma_lop}").data["count"] == 1
    assert login_as(UserFactory(role=Role.GIAO_VIEN)).get("/api/grade-sheets/").status_code == 403
