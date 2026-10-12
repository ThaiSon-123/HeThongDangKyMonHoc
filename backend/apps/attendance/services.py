"""Điểm danh (BR-19/20): sinh sẵn buổi, lưu điểm danh cả lớp, tỷ lệ vắng + cờ, yêu cầu sửa điểm danh."""

from datetime import timedelta

from django.db import transaction
from django.db.models import Count, Q
from django.utils import timezone
from rest_framework.exceptions import ValidationError

from apps.attendance.models import (
    Attendance,
    AttendanceRequest,
    AttendanceSession,
    TrangThaiDiemDanh,
    TrangThaiSession,
)
from apps.config.models import SystemConfig
from apps.registration.models import Registration, TrangThaiDangKy
from apps.training.models import ClassSection, TrangThaiDon, TrangThaiLop
from core.exceptions import Codes, business_error

MAX_ABSENT_PCT_MAC_DINH = 20


def max_absent_pct():
    return SystemConfig.get_int("max_absent_pct", MAX_ABSENT_PCT_MAC_DINH)


# ----------------------------------------------------------------- sinh buổi (BR-20a)


@transaction.atomic
def dong_bo_buoi(lop, hom_nay=None):
    """Sinh `AttendanceSession` cho mọi ngày trong [ngày bắt đầu, ngày kết thúc] của lớp (NULL → theo
    học kỳ) có `thu` trùng một lịch (mỗi ngày × buổi một phiên). Gọi lại khi lớp mở và mỗi lần PĐT sửa
    lịch / ngày: chỉ sinh thêm hoặc xóa các buổi **tương lai chưa điểm danh**; buổi đã điểm danh giữ
    nguyên. Trả `(số buổi sinh thêm, số buổi xóa)`."""
    hom_nay = hom_nay or timezone.localdate()
    tu = lop.ngay_bat_dau or lop.hoc_ky.ngay_bat_dau
    den = lop.ngay_ket_thuc or lop.hoc_ky.ngay_ket_thuc
    lich = list(lop.lich_hoc.all())

    can = {}  # (ngày, buổi) → tiết bắt đầu sớm nhất
    ngay = tu
    while ngay <= den:
        thu = ngay.isoweekday() + 1  # thứ 2 = 2 … Chủ nhật = 8 (BR-08)
        for lh in lich:
            if lh.thu == thu:
                khoa = (ngay, lh.buoi)
                can[khoa] = min(can.get(khoa, lh.tiet_bat_dau), lh.tiet_bat_dau)
        ngay += timedelta(days=1)

    co = {(s.ngay_hoc, s.buoi): s for s in lop.buoi_diem_danh.all()}
    moi = [
        AttendanceSession(lop_hoc_phan=lop, ngay_hoc=n, buoi=b, tiet_bat_dau=t)
        for (n, b), t in can.items()
        if (n, b) not in co
    ]
    AttendanceSession.objects.bulk_create(moi)

    xoa = [
        s.id
        for k, s in co.items()
        if k not in can and s.ngay_hoc > hom_nay and s.trang_thai == TrangThaiSession.MO
    ]
    AttendanceSession.objects.filter(id__in=xoa).delete()
    # Lịch đổi tiết nhưng giữ ngày/buổi: cập nhật tiết cho buổi tương lai chưa điểm danh.
    for k, s in co.items():
        t = can.get(k)
        if (
            t is not None
            and t != s.tiet_bat_dau
            and s.ngay_hoc > hom_nay
            and s.trang_thai == TrangThaiSession.MO
        ):
            s.tiet_bat_dau = t
            s.save(update_fields=["tiet_bat_dau"])
    return len(moi), len(xoa)


# ----------------------------------------------------------------- tỷ lệ vắng (BR-20c)


def chi_so_vang(tong_so_buoi, so_vang_kp, pct=None):
    """Tỷ lệ vắng = vắng không phép / tổng buổi theo lịch (vắng có phép không tính). Cờ khi
    vượt `max_absent_pct`; `so_buoi_vang_cho_phep` = số buổi vắng tối đa mà chưa bị cờ."""
    pct = max_absent_pct() if pct is None else pct
    cho_phep = (tong_so_buoi * pct) // 100
    return {
        "ty_le_vang": round(100 * so_vang_kp / tong_so_buoi, 1) if tong_so_buoi else 0.0,
        "so_buoi_vang_cho_phep": cho_phep,
        "canh_bao_vang": so_vang_kp > cho_phep,
    }


def thong_ke_lop(lop):
    """`{sinh_vien_id: {so_vang_kp, so_vang_co_phep, so_co_mat, so_di_tre}}` + tổng số buổi của lớp."""
    tong = lop.buoi_diem_danh.count()
    rows = (
        Attendance.objects.filter(lop_hoc_phan=lop)
        .values("sinh_vien_id")
        .annotate(
            vang_kp=Count("id", filter=Q(trang_thai=TrangThaiDiemDanh.VANG_KHONG_PHEP)),
            vang_cp=Count("id", filter=Q(trang_thai=TrangThaiDiemDanh.VANG_CO_PHEP)),
            co_mat=Count("id", filter=Q(trang_thai=TrangThaiDiemDanh.CO_MAT)),
            di_tre=Count("id", filter=Q(di_tre=True)),
        )
    )
    return tong, {
        r["sinh_vien_id"]: {
            "so_vang_kp": r["vang_kp"],
            "so_vang_co_phep": r["vang_cp"],
            "so_co_mat": r["co_mat"],
            "so_di_tre": r["di_tre"],
        }
        for r in rows
    }


# ----------------------------------------------------------------- điểm danh cả lớp


def _chuan_hoa(trang_thai, di_tre):
    """BR-19: `di_tre` chỉ hợp lệ khi `CO_MAT`; vắng thì server tự đặt false."""
    return trang_thai, bool(di_tre) and trang_thai == TrangThaiDiemDanh.CO_MAT


def kiem_tra_gv_lop(user, lop):
    if lop.giao_vien.user_id != user.id:
        raise business_error(Codes.KHONG_CO_QUYEN, "Bạn không phụ trách lớp này.")


def sinh_vien_dang_ky(lop):
    return list(
        Registration.objects.filter(lop_hoc_phan=lop, trang_thai=TrangThaiDangKy.DA_DANG_KY)
        .select_related("sinh_vien__sinh_vien")
        .order_by("sinh_vien__sinh_vien__ma_sv")
    )


@transaction.atomic
def luu_diem_danh(session_id, gv, records, hom_nay=None):
    """`PUT records` — lưu **cả lớp**: `records` phải gồm đúng các SV đang đăng ký, mỗi SV một dòng
    `{sinh_vien, trang_thai, di_tre, ghi_chu}`. Chỉ lớp `DANG_HOC` và buổi `ngay_hoc` ≤ hôm nay;
    lần lưu đầu chuyển buổi sang `DA_DIEM_DANH`. Trả `(session, số dòng)`."""
    hom_nay = hom_nay or timezone.localdate()
    session = (
        AttendanceSession.objects.select_for_update()
        .select_related("lop_hoc_phan__giao_vien")
        .get(pk=session_id)
    )
    lop = session.lop_hoc_phan
    kiem_tra_gv_lop(gv, lop)
    if lop.trang_thai != TrangThaiLop.DANG_HOC:
        raise business_error(Codes.TRANG_THAI_KHONG_HOP_LE, "Chỉ điểm danh được khi lớp đang học.")
    if session.ngay_hoc > hom_nay:
        raise business_error(
            Codes.TRANG_THAI_KHONG_HOP_LE, "Chưa tới ngày học, chưa điểm danh được."
        )

    dang_ky = {r.sinh_vien_id for r in sinh_vien_dang_ky(lop)}
    gui = [r["sinh_vien"] for r in records]
    if len(set(gui)) != len(gui):
        raise ValidationError({"records": ["Một sinh viên xuất hiện nhiều lần."]})
    if set(gui) != dang_ky:
        thieu = len(dang_ky - set(gui))
        thua = len(set(gui) - dang_ky)
        raise ValidationError(
            {
                "records": [
                    f"Danh sách phải gồm đúng sinh viên đang đăng ký lớp (thiếu {thieu}, thừa {thua})."
                ]
            }
        )

    co = {a.sinh_vien_id: a for a in Attendance.objects.filter(attendance_session=session)}
    for r in records:
        trang_thai, di_tre = _chuan_hoa(r["trang_thai"], r.get("di_tre"))
        a = co.get(r["sinh_vien"])
        if a is None:
            Attendance.objects.create(
                attendance_session=session,
                lop_hoc_phan=lop,
                ngay_hoc=session.ngay_hoc,
                sinh_vien_id=r["sinh_vien"],
                trang_thai=trang_thai,
                di_tre=di_tre,
                ghi_chu=r.get("ghi_chu", ""),
            )
        else:
            a.trang_thai, a.di_tre, a.ghi_chu = trang_thai, di_tre, r.get("ghi_chu", "")
            a.save(update_fields=["trang_thai", "di_tre", "ghi_chu", "cap_nhat_luc"])
    if session.trang_thai != TrangThaiSession.DA_DIEM_DANH:
        session.trang_thai = TrangThaiSession.DA_DIEM_DANH
        session.save(update_fields=["trang_thai"])
    return session, len(records)


# ----------------------------------------------------------------- yêu cầu sửa điểm danh


def tao_yeu_cau(sv, attendance_id, trang_thai_mong_muon, di_tre_mong_muon, ly_do, minh_chung=None):
    att = (
        Attendance.objects.select_related("lop_hoc_phan")
        .filter(pk=attendance_id, sinh_vien=sv)
        .first()
    )
    if att is None:
        raise ValidationError({"attendance": ["Không tìm thấy buổi điểm danh của bạn."]})
    if att.lop_hoc_phan.trang_thai != TrangThaiLop.DANG_HOC:
        raise business_error(Codes.TRANG_THAI_KHONG_HOP_LE, "Chỉ gửi yêu cầu khi lớp đang học.")
    if att.yeu_cau.filter(trang_thai=TrangThaiDon.CHO_DUYET).exists():
        raise business_error(
            Codes.TRANG_THAI_KHONG_HOP_LE, "Buổi này đã có yêu cầu đang chờ duyệt."
        )
    trang_thai, di_tre = _chuan_hoa(trang_thai_mong_muon, di_tre_mong_muon)
    if (trang_thai, di_tre) == (att.trang_thai, att.di_tre):
        raise ValidationError(
            {"trang_thai_mong_muon": ["Trạng thái mong muốn trùng với hiện tại."]}
        )
    return AttendanceRequest.objects.create(
        attendance=att,
        sinh_vien=sv,
        ly_do=ly_do,
        trang_thai_mong_muon=trang_thai,
        di_tre_mong_muon=di_tre,
        minh_chung=minh_chung,
    )


@transaction.atomic
def xu_ly_yeu_cau(request_id, gv, duyet, ghi_chu=""):
    """GV phụ trách lớp duyệt / từ chối. Duyệt → ghi lại `Attendance` (BR-19)."""
    yc = (
        AttendanceRequest.objects.select_for_update()
        .select_related("attendance__lop_hoc_phan__giao_vien")
        .get(pk=request_id)
    )
    att = yc.attendance
    kiem_tra_gv_lop(gv, att.lop_hoc_phan)
    if yc.trang_thai != TrangThaiDon.CHO_DUYET:
        raise business_error(Codes.TRANG_THAI_KHONG_HOP_LE, "Yêu cầu đã được xử lý.")
    if att.lop_hoc_phan.trang_thai != TrangThaiLop.DANG_HOC:
        raise business_error(Codes.TRANG_THAI_KHONG_HOP_LE, "Chỉ duyệt được khi lớp đang học.")
    yc.trang_thai = TrangThaiDon.DUYET if duyet else TrangThaiDon.TU_CHOI
    yc.nguoi_duyet = gv
    yc.ngay_duyet = timezone.now()
    yc.ghi_chu = ghi_chu
    yc.save(update_fields=["trang_thai", "nguoi_duyet", "ngay_duyet", "ghi_chu"])
    if duyet:
        att.trang_thai, att.di_tre = _chuan_hoa(yc.trang_thai_mong_muon, yc.di_tre_mong_muon)
        att.save(update_fields=["trang_thai", "di_tre", "cap_nhat_luc"])
    return yc


def lop_cua_gv(user):
    return ClassSection.objects.filter(giao_vien__user=user)
