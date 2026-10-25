"""Điểm (BR-10..14, BR-25): tổng kết, thang chữ, nhập cả lớp, khóa/mở khóa, duyệt, GPA."""

from collections import defaultdict
from decimal import ROUND_HALF_UP, Decimal

from django.db import transaction
from django.utils import timezone

from apps.auth.models import Role
from apps.grades.models import Grade, TrangThaiDiem
from apps.notifications.services import gui_cho_nguoi_dung
from apps.profiles.models import StudentProfile
from apps.profiles.services import xep_loai
from apps.registration.models import Registration, TrangThaiDangKy
from apps.training.models import ClassSection, TrangThaiLop
from apps.training.services import han_nhap_diem_hieu_luc
from core.exceptions import Codes, business_error

D = Decimal
HAI_SO = D("0.01")
# (ngưỡng tổng kết tối thiểu, chữ) — band liên tục, chỉ để hiển thị và xác định đạt/không đạt (BR-11)
_THANG_CHU = [
    (D("8.50"), "A"),
    (D("7.00"), "B"),
    (D("5.50"), "C"),
    (D("4.00"), "D"),
]
# Điểm hệ 4 của môn = tổng kết × 4 / 10 (tuyến tính, làm tròn 2 số lẻ); không đạt (F) = 0 (BR-11)
HE_SO_THANG_4 = D("0.4")


def lam_tron(x):
    return D(x).quantize(HAI_SO, rounding=ROUND_HALF_UP)


# ----------------------------------------------------------------- BR-10 / BR-11


def tinh_tong_ket(qt, gk, ck):
    """Tổng kết = QT×0.1 + GK×0.4 + CK×0.5 (làm tròn 2 chữ số). Thiếu GK (NULL) → QT/CK = 20%/80%;
    thiếu CK (NULL) → coi CK = 0. NULL ≠ 0: NULL là chưa nhập, `0` là GV nhập 0. QT NULL coi như 0.
    Chưa nhập điểm nào → None."""
    if qt is None and gk is None and ck is None:
        return None
    qt = D(0) if qt is None else D(qt)
    ck = D(0) if ck is None else D(ck)
    if gk is None:
        return lam_tron(qt * D("0.2") + ck * D("0.8"))
    return lam_tron(qt * D("0.1") + D(gk) * D("0.4") + ck * D("0.5"))


def xep_loai_diem(tong_ket, loai_danh_gia="DIEM"):
    """`(diem_chu, gpa_thang_4)`. Môn Đạt/Không đạt: ≥ 5.00 → `P` (không vào GPA), ngược lại `F`."""
    if tong_ket is None:
        return "", None
    if loai_danh_gia == "DAT_KHONG_DAT":
        return ("P", None) if tong_ket >= D("5.00") else ("F", D("0.0"))
    for nguong, chu in _THANG_CHU:
        if tong_ket >= nguong:
            return chu, lam_tron(tong_ket * HE_SO_THANG_4)
    return "F", D("0.0")


# ----------------------------------------------------------------- bảng điểm lớp


def kiem_tra_gv_lop(user, lop):
    if lop.giao_vien.user_id != user.id:
        raise business_error(Codes.KHONG_CO_QUYEN, "Bạn không phụ trách lớp này.")  # BR-12


def sinh_vien_lop(lop):
    return list(
        Registration.objects.filter(lop_hoc_phan=lop, trang_thai=TrangThaiDangKy.DA_DANG_KY)
        .select_related("sinh_vien__sinh_vien")
        .order_by("sinh_vien__sinh_vien__ma_sv")
    )


def _qua_han(lop, hom_nay=None):
    return (hom_nay or timezone.localdate()) > han_nhap_diem_hieu_luc(lop)


def bang_diem_lop(lop, user):
    """Dữ liệu `GET grades/`: từng SV đang đăng ký + điểm hiện có + cờ thao tác theo vai trò."""
    grades = {g.sinh_vien_id: g for g in Grade.objects.filter(lop_hoc_phan=lop)}
    rows = []
    for r in sinh_vien_lop(lop):
        g = grades.get(r.sinh_vien_id)
        ho_so = r.sinh_vien.sinh_vien
        rows.append(
            {
                "sinh_vien": r.sinh_vien_id,
                "ma_sv": ho_so.ma_sv,
                "ho_ten": ho_so.ho_ten,
                "diem_qua_trinh": g.diem_qua_trinh if g else None,
                "diem_giua_ky": g.diem_giua_ky if g else None,
                "diem_cuoi_ky": g.diem_cuoi_ky if g else None,
                "diem_tong_ket": g.diem_tong_ket if g else None,
                "diem_chu": g.diem_chu if g else "",
                "gpa_thang_4": g.gpa_thang_4 if g else None,
                "trang_thai": g.trang_thai if g else None,
            }
        )
    dang_hoc = lop.trang_thai == TrangThaiLop.DANG_HOC
    qua_han = _qua_han(lop)
    la_gv = user.role == Role.GIAO_VIEN
    co_nhap_tam = any(
        r["trang_thai"] == TrangThaiDiem.NHAP_TAM or r["trang_thai"] is None for r in rows
    )
    co_chinh_thuc = any(r["trang_thai"] == TrangThaiDiem.CHINH_THUC for r in rows)
    return {
        "lop_hoc_phan": lop.id,
        "ma_lop": lop.ma_lop,
        "ten_mon": lop.mon_hoc.ten_mon,
        "loai_danh_gia": lop.mon_hoc.loai_danh_gia,
        "lop_trang_thai": lop.trang_thai,
        "han_nhap_diem": han_nhap_diem_hieu_luc(lop),
        "qua_han": qua_han,
        "co_the_nhap": dang_hoc and (not qua_han if la_gv else True),
        "co_the_khoa": la_gv and dang_hoc and not qua_han and bool(rows) and co_nhap_tam,
        "co_the_mo_khoa": la_gv and dang_hoc and not qua_han and co_chinh_thuc,
        "co_the_duyet": user.role == Role.PHONG_DAO_TAO
        and lop.trang_thai == TrangThaiLop.DA_DONG
        and bool(rows)
        and all(r["trang_thai"] == TrangThaiDiem.CHINH_THUC for r in rows),
        "records": rows,
    }


def _khoa_lop(lop_id):
    return (
        ClassSection.objects.select_for_update()
        .select_related("giao_vien", "mon_hoc", "hoc_ky")
        .get(pk=lop_id)
    )


@transaction.atomic
def luu_diem(lop_id, user, rows, hom_nay=None):
    """`PUT grades/` — nhập/sửa điểm. GV (lớp mình, `DANG_HOC`, trong hạn): lưu `NHAP_TAM`.
    PĐT **nhập hộ** (lớp `DANG_HOC`): lưu thẳng `CHINH_THUC`. Chỉ ghi đè dòng `NHAP_TAM` hoặc chưa có
    (`CHINH_THUC` phải mở khóa trước, `KHOA` bất biến). Trả `(lop, số dòng)`."""
    lop = _khoa_lop(lop_id)
    la_gv = user.role == Role.GIAO_VIEN
    if la_gv:
        kiem_tra_gv_lop(user, lop)
    if lop.trang_thai != TrangThaiLop.DANG_HOC:
        raise business_error(Codes.TRANG_THAI_KHONG_HOP_LE, "Chỉ nhập điểm khi lớp đang học.")
    if la_gv and _qua_han(lop, hom_nay):
        raise business_error(Codes.QUA_HAN_NHAP_DIEM, "Đã quá hạn nhập điểm của lớp.")

    dang_ky = {r.sinh_vien_id for r in sinh_vien_lop(lop)}
    gui = [r["sinh_vien"] for r in rows]
    if len(set(gui)) != len(gui) or not set(gui) <= dang_ky:
        from rest_framework.exceptions import ValidationError

        raise ValidationError({"records": ["Danh sách có sinh viên trùng hoặc không đăng ký lớp."]})

    co = {g.sinh_vien_id: g for g in Grade.objects.filter(lop_hoc_phan=lop, sinh_vien_id__in=gui)}
    khong_sua_duoc = [g for g in co.values() if g.trang_thai != TrangThaiDiem.NHAP_TAM]
    if khong_sua_duoc:
        raise business_error(
            Codes.TRANG_THAI_KHONG_HOP_LE,
            "Có sinh viên đã khóa điểm (cần mở khóa trước khi sửa).",
        )
    dich = TrangThaiDiem.NHAP_TAM if la_gv else TrangThaiDiem.CHINH_THUC
    for r in rows:
        tong = tinh_tong_ket(r.get("diem_qua_trinh"), r.get("diem_giua_ky"), r.get("diem_cuoi_ky"))
        chu, gpa = xep_loai_diem(tong, lop.mon_hoc.loai_danh_gia)
        Grade.objects.update_or_create(
            lop_hoc_phan=lop,
            sinh_vien_id=r["sinh_vien"],
            defaults={
                "diem_qua_trinh": r.get("diem_qua_trinh"),
                "diem_giua_ky": r.get("diem_giua_ky"),
                "diem_cuoi_ky": r.get("diem_cuoi_ky"),
                "diem_tong_ket": tong,
                "diem_chu": chu,
                "gpa_thang_4": gpa,
                "trang_thai": dich,
            },
        )
    return lop, len(rows)


@transaction.atomic
def doi_khoa_lop(lop_id, gv, khoa, hom_nay=None):
    """GV khóa (`NHAP_TAM` → `CHINH_THUC`) hoặc mở khóa cả lớp (BR-14). Lớp `DANG_HOC` + trong hạn.
    Khóa cần mọi SV đang đăng ký đã có điểm. `KHOA` bất biến. Trả số dòng đổi."""
    lop = _khoa_lop(lop_id)
    kiem_tra_gv_lop(gv, lop)
    if lop.trang_thai != TrangThaiLop.DANG_HOC:
        raise business_error(
            Codes.TRANG_THAI_KHONG_HOP_LE, "Chỉ khóa/mở khóa điểm khi lớp đang học."
        )
    if _qua_han(lop, hom_nay):
        raise business_error(Codes.QUA_HAN_NHAP_DIEM, "Đã quá hạn nhập điểm của lớp.")
    if khoa:
        thieu = len(
            {r.sinh_vien_id for r in sinh_vien_lop(lop)}
            - set(Grade.objects.filter(lop_hoc_phan=lop).values_list("sinh_vien_id", flat=True))
        )
        if thieu:
            raise business_error(
                Codes.TRANG_THAI_KHONG_HOP_LE,
                f"Còn {thieu} sinh viên chưa có điểm, chưa khóa được.",
            )
        return Grade.objects.filter(lop_hoc_phan=lop, trang_thai=TrangThaiDiem.NHAP_TAM).update(
            trang_thai=TrangThaiDiem.CHINH_THUC
        )
    return Grade.objects.filter(lop_hoc_phan=lop, trang_thai=TrangThaiDiem.CHINH_THUC).update(
        trang_thai=TrangThaiDiem.NHAP_TAM
    )


@transaction.atomic
def duyet_lop(lop_id):
    """PĐT duyệt cả lớp `DA_DONG`: `CHINH_THUC` → `KHOA`, cập nhật GPA/tín chỉ tích lũy đồng bộ
    (BR-25e) và báo cho từng SV. Trả số SV."""
    lop = _khoa_lop(lop_id)
    if lop.trang_thai != TrangThaiLop.DA_DONG:
        raise business_error(Codes.TRANG_THAI_KHONG_HOP_LE, "Chỉ duyệt điểm khi lớp đã đóng.")
    diem = list(Grade.objects.filter(lop_hoc_phan=lop))
    if not diem:
        raise business_error(Codes.TRANG_THAI_KHONG_HOP_LE, "Lớp chưa có điểm để duyệt.")
    if any(g.trang_thai == TrangThaiDiem.NHAP_TAM for g in diem):
        raise business_error(
            Codes.TRANG_THAI_KHONG_HOP_LE, "Còn điểm chưa khóa (giáo viên chưa khóa điểm)."
        )
    moi_duyet = [g for g in diem if g.trang_thai == TrangThaiDiem.CHINH_THUC]
    Grade.objects.filter(lop_hoc_phan=lop, trang_thai=TrangThaiDiem.CHINH_THUC).update(
        trang_thai=TrangThaiDiem.KHOA
    )
    for g in moi_duyet:  # duyệt lại lớp đã KHOA: không báo trùng
        cap_nhat_ho_so(g.sinh_vien)
        gui_cho_nguoi_dung(
            g.sinh_vien,
            "Có điểm mới",
            f"Điểm môn {lop.mon_hoc.ten_mon} (lớp {lop.ma_lop}) đã được công bố.",
        )
    return len(diem)


# ----------------------------------------------------------------- BR-25: GPA


def _gpa(rows):
    """Σ(gpa4 × tín chỉ) / Σ tín chỉ trên các dòng có `gpa_thang_4` (P bị loại cả tử lẫn mẫu)."""
    co = [(g.gpa_thang_4, tc) for g, tc in rows if g.gpa_thang_4 is not None]
    mau = sum(tc for _, tc in co)
    return lam_tron(sum(gpa * tc for gpa, tc in co) / mau) if mau else None


def moi_nhat_moi_mon(grades):
    """(c) mỗi môn chỉ tính lần học mới nhất — `hoc_ky.ngay_bat_dau` lớn nhất (không dùng ngày tạo)."""
    cuoi = {}
    for g in grades:
        mon = g.lop_hoc_phan.mon_hoc_id
        khoa = (g.lop_hoc_phan.hoc_ky.ngay_bat_dau, g.id)
        if mon not in cuoi or khoa > cuoi[mon][0]:
            cuoi[mon] = (khoa, g)
    return [g for _, g in cuoi.values()]


def _grades_khoa(sv):
    return list(
        Grade.objects.filter(sinh_vien=sv, trang_thai=TrangThaiDiem.KHOA).select_related(
            "lop_hoc_phan__mon_hoc", "lop_hoc_phan__hoc_ky"
        )
    )


def tong_hop_diem(sv):
    """GPA tích lũy, tín chỉ tích lũy và thống kê từng học kỳ (BR-25a..g) từ điểm `KHOA`."""
    tat_ca = _grades_khoa(sv)
    moi_nhat = moi_nhat_moi_mon(tat_ca)
    gpa_tl = _gpa([(g, g.lop_hoc_phan.mon_hoc.tong_tin_chi) for g in moi_nhat])
    tin_chi_tl = sum(
        g.lop_hoc_phan.mon_hoc.tong_tin_chi for g in moi_nhat if g.diem_chu not in ("F", "")
    )

    theo_hk = defaultdict(list)
    for g in tat_ca:
        theo_hk[g.lop_hoc_phan.hoc_ky].append(g)
    thong_ke = []
    for hk in sorted(theo_hk, key=lambda h: h.ngay_bat_dau):
        rows = [(g, g.lop_hoc_phan.mon_hoc.tong_tin_chi) for g in theo_hk[hk]]
        gpa_hk = _gpa(rows)
        co_diem = [
            (g, tc) for g, tc in rows if g.lop_hoc_phan.mon_hoc.loai_danh_gia != "DAT_KHONG_DAT"
        ]
        mau = sum(tc for _, tc in co_diem)
        thong_ke.append(
            {
                "hoc_ky": hk.id,
                "ten_hk": hk.ten_hk,
                "so_mon": len(rows),
                "tin_chi_hoc": sum(tc for _, tc in rows),
                "tin_chi_dat": sum(tc for g, tc in rows if g.diem_chu != "F"),
                "diem_tb": (
                    lam_tron(sum((g.diem_tong_ket or 0) * tc for g, tc in co_diem) / mau)
                    if mau
                    else None
                ),
                "gpa": gpa_hk,
                "xep_loai": xep_loai(gpa_hk),
            }
        )
    return {
        "gpa": gpa_tl,
        "tin_chi_tich_luy": tin_chi_tl,
        "xep_loai": xep_loai(gpa_tl),
        "thong_ke": thong_ke,
    }


def cap_nhat_ho_so(sv):
    """Đồng bộ `StudentProfile.gpa` / `tin_chi_tich_luy` (cache BR-25e)."""
    tong = tong_hop_diem(sv)
    StudentProfile.objects.filter(user=sv).update(
        gpa=tong["gpa"], tin_chi_tich_luy=tong["tin_chi_tich_luy"]
    )
    return tong
