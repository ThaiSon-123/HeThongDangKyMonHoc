"""Đăng ký / hủy môn học (BR-01..07, BR-05, BR-06). View chỉ parse + permission + serialize.

Luồng (plan 7.1): kiểm tra BR-01→04, 07 NGOÀI lock → BR-06 (transaction, `FOR UPDATE` lớp, đọc lại
chỗ trống) → NGOÀI transaction: tính lại học phí (lỗi → warning) + thông báo."""

from django.db import IntegrityError, transaction
from django.db.models import F, Q
from django.db.models.functions import Greatest
from django.utils import timezone
from rest_framework.exceptions import ValidationError

from apps.auth.models import Role
from apps.grades.models import Grade, TrangThaiDiem
from apps.notifications.services import gui_cho_nguoi_dung
from apps.profiles.models import StudentProfile
from apps.registration.models import Registration, TrangThaiDangKy
from apps.training.models import (
    ClassSection,
    Prerequisite,
    Schedule,
    TrangThaiHocKy,
    TrangThaiLop,
)
from apps.tuition.services import tinh_hoc_phi, tong_tin_chi_dang_ky
from core.exceptions import BusinessError, Codes, business_error

GPA_CANH_BAO = 2  # BR-07: GPA < 2.0 → diện cảnh báo học vụ
DUOI_TIN_CHI_TOI_THIEU = "DUOI_TIN_CHI_TOI_THIEU"  # mã warning (không phải lỗi)


def ho_so_sinh_vien(user):
    ho_so = StudentProfile.objects.select_related("ctdt", "nganh").filter(user=user).first()
    if ho_so is None:
        raise business_error(Codes.KHONG_CO_QUYEN, "Tài khoản chưa có hồ sơ sinh viên.")
    return ho_so


def mon_da_dat_ids(user):
    """Môn đã đạt: có `Grade` `KHOA` với `diem_chu ≠ F` (BR-04; `P` của môn Đạt/Không đạt là đạt)."""
    return set(
        Grade.objects.filter(sinh_vien=user, trang_thai=TrangThaiDiem.KHOA)
        .exclude(diem_chu__in=["F", ""])
        .values_list("lop_hoc_phan__mon_hoc_id", flat=True)
    )


# ---------------------------------------------------------------- kiểm tra


def kiem_tra_mo_dang_ky(lop, now=None):
    """BR-01: lớp `MO`, học kỳ `MO` và đang trong cửa sổ đăng ký."""
    now = now or timezone.now()
    hoc_ky = lop.hoc_ky
    if lop.trang_thai != TrangThaiLop.MO:
        raise business_error(Codes.LOP_CHUA_MO, "Lớp chưa mở đăng ký.")
    if hoc_ky.trang_thai != TrangThaiHocKy.MO or not (
        hoc_ky.cua_so_dk_bat_dau <= now <= hoc_ky.cua_so_dk_ket_thuc
    ):
        raise business_error(Codes.NGOAI_CUA_SO_DANG_KY, "Ngoài thời gian đăng ký của học kỳ.")


def kiem_tra_con_cho(lop):
    """BR-02."""
    if lop.si_so_hien_tai >= lop.si_so_toi_da:
        raise business_error(Codes.LOP_DAY, "Lớp đã đủ sĩ số.")


def lich_trung(lich_a, lich_b):
    """BR-03: cùng `thu` và khoảng tiết giao nhau."""
    return (
        lich_a.thu == lich_b.thu
        and lich_a.tiet_bat_dau <= lich_b.tiet_ket_thuc
        and lich_b.tiet_bat_dau <= lich_a.tiet_ket_thuc
    )


def lich_da_dang_ky(user, hoc_ky):
    return list(
        Schedule.objects.filter(
            lop_hoc_phan__dang_ky__sinh_vien=user,
            lop_hoc_phan__dang_ky__trang_thai=TrangThaiDangKy.DA_DANG_KY,
            lop_hoc_phan__hoc_ky=hoc_ky,
        ).select_related("lop_hoc_phan")
    )


def lop_trung_lich(lop, lich_da_co):
    """Mã lớp đã đăng ký mà `lop` trùng lịch, hoặc None."""
    for moi in lop.lich_hoc.all():
        for cu in lich_da_co:
            if cu.lop_hoc_phan_id != lop.id and lich_trung(moi, cu):
                return cu.lop_hoc_phan.ma_lop
    return None


def kiem_tra_trung_lich(user, lop):
    ma = lop_trung_lich(lop, lich_da_dang_ky(user, lop.hoc_ky))
    if ma:
        raise business_error(Codes.TRUNG_LICH, f"Trùng lịch với lớp {ma}.", {"lop_hoc_phan": ma})


def kiem_tra_tien_quyet(user, lop):
    """BR-04: (a) tiên quyết, (b) đã đạt, (d) một môn một lớp mỗi học kỳ."""
    da_dat = mon_da_dat_ids(user)
    thieu = list(
        Prerequisite.objects.filter(mon_hoc=lop.mon_hoc)
        .exclude(mon_tien_quyet_id__in=da_dat)
        .values_list("mon_tien_quyet__ma_mon", flat=True)
    )
    if thieu:
        raise business_error(
            Codes.THIEU_TIEN_QUYET,
            "Chưa đạt môn tiên quyết: " + ", ".join(thieu) + ".",
            {"mon_tien_quyet": thieu},
        )
    if lop.mon_hoc_id in da_dat:
        raise business_error(Codes.DA_DAT_MON, "Môn học này đã đạt, không đăng ký lại.")
    cung_mon = (
        Registration.objects.filter(
            sinh_vien=user,
            trang_thai=TrangThaiDangKy.DA_DANG_KY,
            lop_hoc_phan__hoc_ky_id=lop.hoc_ky_id,
            lop_hoc_phan__mon_hoc_id=lop.mon_hoc_id,
        )
        .exclude(lop_hoc_phan=lop)
        .select_related("lop_hoc_phan")
        .first()
    )
    if cung_mon:
        raise business_error(
            Codes.DA_DANG_KY_MON,
            f"Đã đăng ký lớp {cung_mon.lop_hoc_phan.ma_lop} của môn này trong học kỳ.",
        )


def tran_tin_chi(ho_so, hoc_ky):
    """Trần tín chỉ áp cho SV (BR-07): diện cảnh báo học vụ thì thấp hơn."""
    if ho_so.gpa is not None and ho_so.gpa < GPA_CANH_BAO:
        return min(hoc_ky.tin_chi_toi_da, hoc_ky.tin_chi_toi_da_canh_bao)
    return hoc_ky.tin_chi_toi_da


def kiem_tra_tin_chi(user, ho_so, lop):
    """BR-07: vượt tối đa / cảnh báo học vụ → chặn; dưới tối thiểu → warning."""
    hoc_ky = lop.hoc_ky
    tong = tong_tin_chi_dang_ky(user, hoc_ky) + lop.mon_hoc.tong_tin_chi
    if tong > hoc_ky.tin_chi_toi_da:
        raise business_error(
            Codes.VUOT_TIN_TC_TOI_DA, f"Vượt tối đa {hoc_ky.tin_chi_toi_da} tín chỉ mỗi học kỳ."
        )
    tran = tran_tin_chi(ho_so, hoc_ky)
    if tong > tran:
        raise business_error(
            Codes.VUOT_TIN_TC_CANH_BAO,
            f"Đang bị cảnh báo học vụ, tối đa {tran} tín chỉ mỗi học kỳ.",
        )
    if tong < hoc_ky.tin_chi_toi_thieu:
        return [
            {
                "code": DUOI_TIN_CHI_TOI_THIEU,
                "message": f"Hiện {tong} tín chỉ, chưa đạt tối thiểu {hoc_ky.tin_chi_toi_thieu}.",
            }
        ]
    return []


# ---------------------------------------------------------------- sau commit


def _sau_commit(user, hoc_ky, tieu_de, noi_dung):
    """Tính lại học phí + thông báo — ngoài transaction, KHÔNG làm hỏng đăng ký/hủy đã commit."""
    warnings = []
    try:
        tinh_hoc_phi(user, hoc_ky)
    except BusinessError as e:
        warnings.append({"code": e.code, "message": e.message})
    gui_cho_nguoi_dung(user, tieu_de, noi_dung)
    return warnings


# ---------------------------------------------------------------- đăng ký


def dang_ky(user, lop_id, request_id=None):
    """Đăng ký một lớp cho SV `user`. Trả `(registration, warnings, moi)`; `moi=False` khi replay.

    Idempotent theo `request_id` (mục 8.3): key đã dùng → trả lại bản ghi cũ, không chạy lại."""
    ho_so = ho_so_sinh_vien(user)
    if request_id:
        cu = Registration.objects.filter(request_id=request_id, sinh_vien=user).first()
        if cu is not None:
            return cu, [], False
    lop = (
        ClassSection.objects.select_related("hoc_ky", "mon_hoc")
        .prefetch_related("lich_hoc")
        .filter(pk=lop_id)
        .first()
    )
    if lop is None:
        raise ValidationError({"lop_hoc_phan": ["Lớp học phần không tồn tại."]})

    da_co = Registration.objects.filter(sinh_vien=user, lop_hoc_phan=lop).first()
    if da_co and da_co.trang_thai == TrangThaiDangKy.DA_DANG_KY:
        raise business_error(Codes.DA_DANG_KY, "Bạn đã đăng ký lớp này.")

    kiem_tra_mo_dang_ky(lop)  # BR-01
    kiem_tra_con_cho(lop)  # BR-02
    kiem_tra_trung_lich(user, lop)  # BR-03
    kiem_tra_tien_quyet(user, lop)  # BR-04
    warnings = kiem_tra_tin_chi(user, ho_so, lop)  # BR-07

    try:
        with transaction.atomic():  # BR-06
            khoa = ClassSection.objects.select_for_update().select_related("hoc_ky").get(pk=lop.id)
            kiem_tra_mo_dang_ky(khoa)  # lớp có thể vừa đóng
            kiem_tra_con_cho(khoa)  # đọc lại sĩ số TRONG lock
            reg = (
                Registration.objects.select_for_update()
                .filter(sinh_vien=user, lop_hoc_phan=khoa)
                .first()
            )
            if reg and reg.trang_thai == TrangThaiDangKy.DA_DANG_KY:
                if request_id and reg.request_id == request_id:
                    return reg, [], False  # cùng key đến đồng thời: replay
                raise business_error(Codes.DA_DANG_KY, "Bạn đã đăng ký lớp này.")
            if reg is None:
                reg = Registration.objects.create(
                    sinh_vien=user, lop_hoc_phan=khoa, request_id=request_id
                )
            else:  # kích hoạt lại bản đã hủy — KHÔNG đổi request_id
                reg.trang_thai = TrangThaiDangKy.DA_DANG_KY
                reg.ngay_huy = None
                reg.ly_do_huy = ""
                reg.save(update_fields=["trang_thai", "ngay_huy", "ly_do_huy"])
            ClassSection.objects.filter(pk=khoa.pk).update(si_so_hien_tai=F("si_so_hien_tai") + 1)
    except IntegrityError:
        raise ValidationError({"Idempotency-Key": ["Key đã được dùng cho yêu cầu khác."]}) from None

    warnings += _sau_commit(
        user,
        lop.hoc_ky,
        "Đăng ký môn học thành công",
        f"Bạn đã đăng ký lớp {lop.ma_lop} — {lop.mon_hoc.ten_mon}.",
    )
    return reg, warnings, True


def lop_co_the_dang_ky(user, ho_so, hoc_ky, search=""):
    """`GET /courses/available/` (SV-04): lớp `MO` của học kỳ, môn thuộc CTĐT của SV, còn chỗ,
    chưa đăng ký và không trùng lịch với các lớp đã đăng ký."""
    qs = (
        ClassSection.objects.filter(
            hoc_ky=hoc_ky,
            trang_thai=TrangThaiLop.MO,
            si_so_hien_tai__lt=F("si_so_toi_da"),
            mon_hoc__mon_ctdt__ctdt_id=ho_so.ctdt_id,
        )
        .exclude(dang_ky__sinh_vien=user, dang_ky__trang_thai=TrangThaiDangKy.DA_DANG_KY)
        .select_related("mon_hoc", "giao_vien", "hoc_ky")
        .prefetch_related("lich_hoc")
        .order_by("mon_hoc__ma_mon", "ma_lop")
    )
    if search.strip():
        t = search.strip()
        qs = qs.filter(
            Q(ma_lop__icontains=t)
            | Q(mon_hoc__ma_mon__icontains=t)
            | Q(mon_hoc__ten_mon__icontains=t)
        )
    lich_da_co = lich_da_dang_ky(user, hoc_ky)
    return [lop for lop in qs if lop_trung_lich(lop, lich_da_co) is None]


# ---------------------------------------------------------------- hủy


def huy_dang_ky(reg_id, actor, ly_do=""):
    """Hủy đăng ký (BR-05). `actor` là SV chủ bản ghi hoặc PĐT (hủy hộ: bắt buộc `ly_do`).
    Trả `(registration, warnings)`."""
    la_pdt = actor.role == Role.PHONG_DAO_TAO
    ly_do = (ly_do or "").strip()
    if la_pdt and not ly_do:
        raise ValidationError({"ly_do": ["Hủy hộ phải có lý do."]})

    lop_id = Registration.objects.values_list("lop_hoc_phan_id", flat=True).get(pk=reg_id)
    with transaction.atomic():
        lop = ClassSection.objects.select_for_update().select_related("hoc_ky").get(pk=lop_id)
        reg = Registration.objects.select_for_update().select_related("sinh_vien").get(pk=reg_id)
        if reg.trang_thai != TrangThaiDangKy.DA_DANG_KY:
            raise business_error(Codes.TRANG_THAI_KHONG_HOP_LE, "Đăng ký này đã được hủy.")
        if la_pdt:
            if lop.trang_thai not in (TrangThaiLop.MO, TrangThaiLop.DANG_HOC):
                raise business_error(
                    Codes.TRANG_THAI_KHONG_HOP_LE,
                    "Chỉ hủy hộ được khi lớp đang mở hoặc đang học.",
                )
        else:
            if lop.trang_thai != TrangThaiLop.MO:
                raise business_error(
                    Codes.TRANG_THAI_KHONG_HOP_LE, "Chỉ hủy được khi lớp còn mở đăng ký."
                )
            kiem_tra_mo_dang_ky(lop)  # còn trong cửa sổ đăng ký
        reg.trang_thai = TrangThaiDangKy.DA_HUY
        reg.ngay_huy = timezone.now()
        reg.ly_do_huy = ly_do
        reg.save(update_fields=["trang_thai", "ngay_huy", "ly_do_huy"])
        ClassSection.objects.filter(pk=lop.pk).update(
            si_so_hien_tai=Greatest(F("si_so_hien_tai") - 1, 0)  # không xuống dưới 0
        )

    noi_dung = f"Đăng ký lớp {lop.ma_lop} đã được hủy."
    if la_pdt:
        noi_dung += f" Lý do: {ly_do}."
    warnings = _sau_commit(reg.sinh_vien, lop.hoc_ky, "Hủy đăng ký môn học", noi_dung)
    return reg, warnings
