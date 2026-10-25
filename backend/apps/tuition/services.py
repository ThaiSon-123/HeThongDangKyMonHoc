"""Học phí (BR-15..18, BR-26): tính theo bảng giá, giá trị dẫn xuất, thu/hoàn tiền, công nợ quá hạn."""

from collections.abc import Sequence
from datetime import date
from decimal import ROUND_HALF_UP, Decimal

from django.db import IntegrityError, transaction
from django.db.models import Q, Sum
from django.utils import timezone
from rest_framework.exceptions import ValidationError

from apps.auth.models import Role, User
from apps.config.models import SystemConfig
from apps.notifications.models import Audience, Notification
from apps.notifications.services import gui_cho_nguoi_dung
from apps.profiles.models import StudentProfile
from apps.registration.models import Registration, TrangThaiDangKy
from apps.training.models import CurriculumCourse, Semester
from apps.tuition.models import (
    Discount,
    HinhThucDong,
    HocPhanGia,
    LoaiThanhToan,
    Payment,
    TrangThaiHocPhi,
    Tuition,
    TuitionConfig,
    TuitionInstallment,
)
from apps.tuition.pricing import tra_bang_gia
from core.exceptions import Codes, business_error

D = Decimal
HAI_SO = D("0.01")


def _lam_tron(x):
    return D(x).quantize(HAI_SO, rounding=ROUND_HALF_UP)


# ----------------------------------------------------------------- tính học phí (BR-15..17)


def chi_tiet_hoc_phi(sinh_vien, hoc_ky):
    """Học phí từng môn của các đăng ký `DA_DANG_KY` trong học kỳ, theo bảng giá hiện tại (BR-16/17).
    Trả `(chi_tiet, tong_tien, tong_tin_chi)`. Thiếu giá → `CHUA_CAU_HINH_GIA` (400)."""
    ho_so = StudentProfile.objects.select_related("nganh").get(user=sinh_vien)
    dang_ky = list(
        Registration.objects.filter(
            sinh_vien=sinh_vien, trang_thai=TrangThaiDangKy.DA_DANG_KY, lop_hoc_phan__hoc_ky=hoc_ky
        )
        .select_related("lop_hoc_phan__mon_hoc")
        .order_by("lop_hoc_phan__mon_hoc__ma_mon")
    )
    khoi = dict(
        CurriculumCourse.objects.filter(
            ctdt_id=ho_so.ctdt_id, mon_hoc__in=[r.lop_hoc_phan.mon_hoc_id for r in dang_ky]
        ).values_list("mon_hoc_id", "khoi_kien_thuc")
    )
    bang_gia = list(HocPhanGia.objects.filter(Q(hoc_ky=hoc_ky) | Q(hoc_ky__isnull=True)))
    chi_tiet, tong_tien, tong_tin_chi = [], D(0), 0
    for r in dang_ky:
        mon = r.lop_hoc_phan.mon_hoc
        try:
            gia = tra_bang_gia(
                bang_gia,
                ho_so.nganh.ma_nganh,
                khoi.get(mon.id, ""),  # môn ngoài CTĐT của SV: bỏ qua trục khối kiến thức
                tin_chi_lt=mon.tin_chi_ly_thuyet,
                tin_chi_th=mon.tin_chi_thuc_hanh,
                hoc_ky_id=hoc_ky.id,
            )
        except ValueError:
            raise business_error(
                Codes.CHUA_CAU_HINH_GIA, f"Chưa cấu hình giá cho môn {mon.ma_mon}."
            ) from None
        chi_tiet.append(
            {
                "ma_mon": mon.ma_mon,
                "ten_mon": mon.ten_mon,
                "ma_lop": r.lop_hoc_phan.ma_lop,
                "tin_chi_ly_thuyet": mon.tin_chi_ly_thuyet,
                "tin_chi_thuc_hanh": mon.tin_chi_thuc_hanh,
                "don_gia_goc": gia.don_gia_goc,
                "don_gia_th": gia.don_gia_th,
                "thanh_tien": gia.tong_tien,
            }
        )
        tong_tien += gia.tong_tien
        tong_tin_chi += mon.tong_tin_chi
    return chi_tiet, tong_tien, tong_tin_chi


def tinh_hoc_phi(sinh_vien, hoc_ky):
    """Tính lại `Tuition` của (sinh_vien, hoc_ky) chỉ từ đăng ký hiện tại + bảng giá hiện tại
    (BR-15) — không đụng Payment/Discount. Thiếu giá → `CHUA_CAU_HINH_GIA`; bản ghi giữ nguyên
    (tạo mới thì ở `CHUA_TINH`)."""
    tuition, _ = Tuition.objects.get_or_create(sinh_vien=sinh_vien, hoc_ky=hoc_ky)
    _, tong_tien, tong_tin_chi = chi_tiet_hoc_phi(sinh_vien, hoc_ky)
    tuition.tong_tien = tong_tien
    tuition.tong_tin_chi = tong_tin_chi
    tuition.trang_thai = TrangThaiHocPhi.DA_TINH
    tuition.save(update_fields=["tong_tien", "tong_tin_chi", "trang_thai"])
    return tuition


def tinh_hang_loat(hoc_ky):
    """`POST /tuition/calculate/` — tính lại cho mọi SV có đăng ký (hoặc đã có học phí) trong học kỳ.
    Tất cả hoặc không: một SV thiếu giá thì cả lô bị hủy và trả `CHUA_CAU_HINH_GIA`."""
    sv_ids = set(
        Registration.objects.filter(
            trang_thai=TrangThaiDangKy.DA_DANG_KY, lop_hoc_phan__hoc_ky=hoc_ky
        ).values_list("sinh_vien_id", flat=True)
    ) | set(Tuition.objects.filter(hoc_ky=hoc_ky).values_list("sinh_vien_id", flat=True))
    with transaction.atomic():
        for u in User.objects.filter(id__in=sv_ids, role=Role.SINH_VIEN):
            tinh_hoc_phi(u, hoc_ky)
    return len(sv_ids)


def tong_tin_chi_dang_ky(sinh_vien, hoc_ky):
    return (
        Registration.objects.filter(
            sinh_vien=sinh_vien, trang_thai=TrangThaiDangKy.DA_DANG_KY, lop_hoc_phan__hoc_ky=hoc_ky
        ).aggregate(t=Sum("lop_hoc_phan__mon_hoc__tong_tin_chi"))["t"]
        or 0
    )


# ----------------------------------------------------------------- giá trị dẫn xuất (mục 5)


def gia_tri_dan_xuat(tuition, discounts, payments):
    """Tính khi đọc, không lưu: `mien_giam`, `phai_nop`, `thuc_thu`, `con_no`, `can_hoan`, `hien_thi`.

    mien_giam = min(tong_tien, Σ so_tien | ty_le% × tong_tien); phai_nop = tong_tien − mien_giam;
    thuc_thu = Σ THU − Σ HOAN; con_no = max(0, phai_nop − thuc_thu); can_hoan = max(0, thuc_thu − phai_nop).
    """
    tong = D(tuition.tong_tien)
    mien = sum(
        (D(d.so_tien) if d.so_tien is not None else tong * D(d.ty_le) / 100 for d in discounts),
        D(0),
    )
    mien_giam = _lam_tron(min(tong, mien))
    phai_nop = tong - mien_giam
    thuc_thu = sum(
        (D(p.so_tien) if p.loai == LoaiThanhToan.THU else -D(p.so_tien) for p in payments), D(0)
    )
    con_no = max(D(0), phai_nop - thuc_thu)
    can_hoan = max(D(0), thuc_thu - phai_nop)
    if tuition.trang_thai == TrangThaiHocPhi.CHUA_TINH:
        hien_thi = "CHUA_TINH"
    elif can_hoan > 0:
        hien_thi = "CHO_HOAN_TIEN"
    elif con_no > 0:
        hien_thi = "CON_NO"
    else:
        hien_thi = "DA_DONG"
    return {
        "mien_giam": mien_giam,
        "phai_nop": phai_nop,
        "thuc_thu": thuc_thu,
        "con_no": con_no,
        "can_hoan": can_hoan,
        "hien_thi": hien_thi,
    }


def dan_xuat_cua(tuition):
    return gia_tri_dan_xuat(
        tuition,
        Discount.objects.filter(sinh_vien_id=tuition.sinh_vien_id, hoc_ky_id=tuition.hoc_ky_id),
        tuition.payments.all(),
    )


def han_dong(hoc_ky_id):
    cfg = TuitionConfig.objects.filter(hoc_ky_id=hoc_ky_id).first()
    return cfg.han_dong if cfg else None


def dot_cua_hoc_ky(hoc_ky_id):
    """3 đợt đã cấu hình của học kỳ theo `thu_tu`; `[]` nếu chưa đủ 3 đợt."""
    dots = list(TuitionInstallment.objects.filter(hoc_ky_id=hoc_ky_id).order_by("thu_tu"))
    return dots if len(dots) == 3 else []


def lich_dot(
    phai_nop: Decimal, thuc_thu: Decimal, dots: Sequence[TuitionInstallment]
) -> list[dict]:
    """Lịch đợt dẫn xuất: `luy_ke` đợt n = phai_nop × Σ ty_le[1..n]/100 (đợt cuối = phai_nop).
    Tiền chảy từ đợt 1 xuống: đợt n đã đóng khi `thuc_thu ≥ luy_ke`."""
    lich, ty_le_luy_ke, luy_ke_truoc = [], D(0), D(0)
    for i, d in enumerate(dots):
        ty_le_luy_ke += D(d.ty_le)
        luy_ke = phai_nop if i == len(dots) - 1 else _lam_tron(phai_nop * ty_le_luy_ke / 100)
        lich.append(
            {
                "thu_tu": d.thu_tu,
                "ty_le": D(d.ty_le),
                "han_dong": d.han_dong,
                "phai_nop": luy_ke - luy_ke_truoc,
                "luy_ke": luy_ke,
                "da_dong": thuc_thu >= luy_ke,
            }
        )
        luy_ke_truoc = luy_ke
    return lich


def dot_tiep_theo(lich: list[dict], thuc_thu: Decimal):
    """Đợt đầu tiên chưa đóng: `{"thu_tu", "can_dong"}`; `None` nếu đã đóng hết / không có lịch."""
    for d in lich:
        if not d["da_dong"]:
            return {"thu_tu": d["thu_tu"], "can_dong": d["luy_ke"] - thuc_thu}
    return None


def han_va_qua_han(
    hinh_thuc: str, dx: dict, han_mot_lan: date | None, lich: list[dict], hom_nay: date
) -> tuple[date | None, bool]:
    """Hạn đang áp dụng và cờ quá hạn. `CHIA_DOT` có lịch: hạn của đợt chưa đóng đầu tiên (đợt cuối
    nếu đã đóng hết), quá hạn khi có đợt chưa đóng đã qua hạn. Còn lại: hạn một lần của học kỳ."""
    if hinh_thuc == HinhThucDong.CHIA_DOT and lich:
        chua = [d for d in lich if not d["da_dong"]]
        han = (chua[0] if chua else lich[-1])["han_dong"]
        return han, any(d["han_dong"] < hom_nay for d in chua)
    return han_mot_lan, bool(han_mot_lan and hom_nay > han_mot_lan and dx["con_no"] > 0)


# ----------------------------------------------------------------- thu / hoàn tiền (BR-26)


def ma_bien_lai(payment):
    return f"BL{timezone.localtime(payment.ngay):%Y%m%d}-{payment.id:06d}"


def ghi_thanh_toan(kt, tuition_id, loai, so_tien, phuong_thuc, request_id=None):
    """Ghi `Payment` THU/HOAN. Transaction + `SELECT … FOR UPDATE` trên `Tuition`; THU không vượt
    `con_no`, HOAN không vượt `can_hoan` (`SO_TIEN_KHONG_HOP_LE`). Idempotent theo `request_id`
    (key đã dùng → trả lại bản ghi cũ). Trả `(payment, moi)`."""
    if request_id:
        cu = Payment.objects.filter(request_id=request_id).first()
        if cu is not None:
            return cu, False
    try:
        with transaction.atomic():
            tuition = Tuition.objects.select_for_update().filter(pk=tuition_id).first()
            if tuition is None:
                raise ValidationError({"tuition": ["Không tìm thấy học phí."]})
            if tuition.trang_thai != TrangThaiHocPhi.DA_TINH:
                raise business_error(
                    Codes.TRANG_THAI_KHONG_HOP_LE, "Học phí chưa được tính, chưa thu/hoàn được."
                )
            dx = dan_xuat_cua(tuition)
            if so_tien <= 0:
                raise business_error(Codes.SO_TIEN_KHONG_HOP_LE, "Số tiền phải lớn hơn 0.")
            if loai == LoaiThanhToan.THU and so_tien > dx["con_no"]:
                raise business_error(
                    Codes.SO_TIEN_KHONG_HOP_LE,
                    f"Số tiền thu vượt công nợ còn lại ({dx['con_no']}).",
                )
            if loai == LoaiThanhToan.HOAN and so_tien > dx["can_hoan"]:
                raise business_error(
                    Codes.SO_TIEN_KHONG_HOP_LE, f"Số tiền hoàn vượt số cần hoàn ({dx['can_hoan']})."
                )
            p = Payment.objects.create(
                tuition=tuition,
                loai=loai,
                so_tien=so_tien,
                phuong_thuc=phuong_thuc,
                nguoi_thu=kt,
                request_id=request_id,
            )
            p.bien_lai_ma = ma_bien_lai(p)
            p.save(update_fields=["bien_lai_ma"])
    except IntegrityError:  # hai yêu cầu cùng key đến đồng thời
        cu = Payment.objects.filter(request_id=request_id).first() if request_id else None
        if cu is None:
            raise
        return cu, False
    return p, True


# ----------------------------------------------------------------- thanh toán QR cho SV


def thong_tin_chuyen_khoan(ho_so, hoc_ky):
    return {
        "ngan_hang": SystemConfig.objects.filter(khoa="ck_ngan_hang")
        .values_list("gia_tri", flat=True)
        .first()
        or "",
        "so_tai_khoan": SystemConfig.objects.filter(khoa="ck_so_tai_khoan")
        .values_list("gia_tri", flat=True)
        .first()
        or "",
        "chu_tai_khoan": SystemConfig.objects.filter(khoa="ck_chu_tai_khoan")
        .values_list("gia_tri", flat=True)
        .first()
        or "",
        # KT đối soát theo nội dung này (KT-08)
        "noi_dung_ck": f"HOCPHI {ho_so.ma_sv} HK{hoc_ky.id}",
    }


# ----------------------------------------------------------------- job quá hạn (mục 7.8)


def thong_bao_qua_han(hom_nay=None):
    """Job `tuition_overdue_notify`: `Tuition` `DA_TINH` còn nợ và quá hạn (một lần hoặc theo đợt, xem
    `han_va_qua_han`) → báo SV (một lần mỗi học kỳ) + một thông báo tổng hợp cho Kế toán khi có sinh
    viên mới. Idempotent. Trả số SV mới báo.
    """
    hom_nay = hom_nay or timezone.localdate()
    moi = {}  # hoc_ky → số SV vừa báo
    hoc_ky_ids = set(
        TuitionConfig.objects.filter(han_dong__lt=hom_nay).values_list("hoc_ky_id", flat=True)
    ) | set(
        TuitionInstallment.objects.filter(han_dong__lt=hom_nay).values_list("hoc_ky_id", flat=True)
    )
    for hoc_ky in Semester.objects.filter(id__in=hoc_ky_ids):
        han_mot_lan, dots = han_dong(hoc_ky.id), dot_cua_hoc_ky(hoc_ky.id)
        for t in Tuition.objects.filter(
            hoc_ky=hoc_ky, trang_thai=TrangThaiHocPhi.DA_TINH
        ).select_related("sinh_vien"):
            dx = dan_xuat_cua(t)
            if dx["con_no"] <= 0:
                continue
            lich = lich_dot(dx["phai_nop"], dx["thuc_thu"], dots)
            han, qua_han = han_va_qua_han(t.hinh_thuc, dx, han_mot_lan, lich, hom_nay)
            if not qua_han:
                continue
            tieu_de = f"Học phí quá hạn — {hoc_ky.ten_hk}"
            if Notification.objects.filter(
                tieu_de=tieu_de, audience=Audience.USER, target_refs=[t.sinh_vien_id]
            ).exists():
                continue
            gui_cho_nguoi_dung(
                t.sinh_vien,
                tieu_de,
                f"Học phí {hoc_ky.ten_hk} đã quá hạn đóng ({han:%d/%m/%Y}). "
                "Vui lòng thanh toán sớm.",
            )
            moi[hoc_ky] = moi.get(hoc_ky, 0) + 1
    kt_ids = list(
        User.objects.filter(role=Role.KE_TOAN, is_locked=False).values_list("id", flat=True)
    )
    for hk, n in moi.items():
        if kt_ids:
            Notification.objects.create(
                tieu_de=f"Công nợ quá hạn — {hk.ten_hk}",
                noi_dung=f"Có {n} sinh viên mới quá hạn đóng học phí {hk.ten_hk}.",
                audience=Audience.USER,
                target_refs=kt_ids,
                nguoi_gui=None,
            )
    return sum(moi.values())
