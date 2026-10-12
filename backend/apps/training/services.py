"""Nghiệp vụ dữ liệu đào tạo (PDT-02..09): chống chu trình tiên quyết, vòng đời học kỳ/lớp (mục 6),
kiểm tra lịch (BR-08/09). View chỉ parse + permission + serialize."""

from collections import defaultdict
from datetime import timedelta

from django.db import transaction
from django.db.models import Exists, OuterRef
from django.utils import timezone
from rest_framework.exceptions import ValidationError

from apps.attendance.models import AttendanceRequest
from apps.attendance.services import dong_bo_buoi
from apps.config.models import SystemConfig
from apps.grades.models import Grade, TrangThaiDiem
from apps.notifications.services import gui_cho_lop
from apps.profiles.models import TeacherProfile
from apps.registration.models import Registration, TrangThaiDangKy
from apps.training.models import (
    ClassSection,
    Major,
    Prerequisite,
    Schedule,
    Semester,
    TrangThaiDon,
    TrangThaiDung,
    TrangThaiHocKy,
    TrangThaiLop,
    TrangThaiMon,
)
from core.exceptions import Codes, business_error

# Tiết cuối của nhóm tiết chứa tiết bắt đầu (BR-08/09): sáng 1–5, chiều 6–10, tối 11–15.
_TIET_CUOI_NHOM = (5, 10, 15)


def sai_trang_thai(message):
    return business_error(Codes.TRANG_THAI_KHONG_HOP_LE, message)


# --------------------------------------------------------------------- Khoa/viện


def kiem_tra_ngung_khoa(khoa):
    """Chỉ ngừng được khi không còn ngành hoặc giáo viên đang hoạt động (plan mục 5)."""
    if Major.objects.filter(khoa=khoa, trang_thai=TrangThaiDung.HOAT_DONG).exists():
        raise sai_trang_thai("Khoa/viện còn ngành đang hoạt động.")
    if TeacherProfile.objects.filter(khoa=khoa, user__is_locked=False).exists():
        raise sai_trang_thai("Khoa/viện còn giáo viên đang hoạt động.")


# --------------------------------------------------------------------- Tiên quyết


def tao_chu_trinh(mon_hoc_id, mon_tien_quyet_id):
    """Thêm cạnh `mon_hoc ← mon_tien_quyet` có tạo chu trình không (DFS)? True nếu có."""
    can = defaultdict(list)  # môn → các môn tiên quyết của nó
    for mon, tq in Prerequisite.objects.values_list("mon_hoc_id", "mon_tien_quyet_id"):
        can[mon].append(tq)
    da_xet, ngan_xep = set(), [mon_tien_quyet_id]
    while ngan_xep:
        mon = ngan_xep.pop()
        if mon == mon_hoc_id:
            return True
        if mon not in da_xet:
            da_xet.add(mon)
            ngan_xep.extend(can[mon])
    return False


# --------------------------------------------------------------------- Học kỳ


@transaction.atomic
def mo_hoc_ky(hoc_ky):
    hoc_ky = Semester.objects.select_for_update().get(pk=hoc_ky.pk)
    if hoc_ky.trang_thai == TrangThaiHocKy.MO:
        raise sai_trang_thai("Học kỳ đã mở.")
    hoc_ky.trang_thai = TrangThaiHocKy.MO
    hoc_ky.save(update_fields=["trang_thai"])
    return hoc_ky


@transaction.atomic
def dong_hoc_ky(hoc_ky):
    hoc_ky = Semester.objects.select_for_update().get(pk=hoc_ky.pk)
    if hoc_ky.trang_thai == TrangThaiHocKy.DONG:
        raise sai_trang_thai("Học kỳ đã đóng.")
    if hoc_ky.lop_hoc_phan.filter(trang_thai__in=[TrangThaiLop.MO, TrangThaiLop.DANG_HOC]).exists():
        raise sai_trang_thai("Không đóng được: học kỳ còn lớp đang mở hoặc đang học.")
    hoc_ky.trang_thai = TrangThaiHocKy.DONG
    hoc_ky.save(update_fields=["trang_thai"])
    return hoc_ky


def hoc_ky_mac_dinh():
    """`?hoc_ky=` mặc định (plan 8.2): học kỳ chứa ngày hiện tại, rồi học kỳ `MO` gần nhất, rồi None."""
    hom_nay = timezone.localdate()
    return (
        Semester.objects.filter(ngay_bat_dau__lte=hom_nay, ngay_ket_thuc__gte=hom_nay).first()
        or Semester.objects.filter(trang_thai=TrangThaiHocKy.MO).order_by("-ngay_bat_dau").first()
    )


def chon_hoc_ky(hoc_ky_id=None):
    """Học kỳ theo `?hoc_ky=` hoặc mặc định; không có thì ValidationError field `hoc_ky` (400)."""
    if hoc_ky_id:
        hoc_ky = Semester.objects.filter(pk=hoc_ky_id).first() if str(hoc_ky_id).isdigit() else None
        if hoc_ky is None:
            raise ValidationError({"hoc_ky": ["Học kỳ không tồn tại."]})
        return hoc_ky
    hoc_ky = hoc_ky_mac_dinh()
    if hoc_ky is None:
        raise ValidationError({"hoc_ky": ["Không xác định được học kỳ, hãy chọn học kỳ."]})
    return hoc_ky


# --------------------------------------------------------------------- Lớp học phần


def ngay_bat_dau_lop(lop):
    return lop.ngay_bat_dau or lop.hoc_ky.ngay_bat_dau


def ngay_ket_thuc_lop(lop):
    return lop.ngay_ket_thuc or lop.hoc_ky.ngay_ket_thuc


def han_nhap_diem_hieu_luc(lop, so_ngay=None):
    """Hạn nhập điểm thực tế (BR-13): `han_nhap_diem` của lớp; NULL thì
    ngày kết thúc (lớp ?? học kỳ) + `so_ngay_cho_phep_nhap_diem` (mặc định 14)."""
    if lop.han_nhap_diem:
        return lop.han_nhap_diem
    if so_ngay is None:
        so_ngay = SystemConfig.get_int("so_ngay_cho_phep_nhap_diem", 14)
    return ngay_ket_thuc_lop(lop) + timedelta(days=so_ngay)


def kiem_tra_sua_lop(lop):
    """Lớp `DA_DONG` không sửa lớp/lịch nữa."""
    if lop.trang_thai == TrangThaiLop.DA_DONG:
        raise sai_trang_thai("Lớp đã đóng, không sửa được.")


def bao_doi_lich(lop, nguoi_gui, noi_dung):
    """Thông báo CLASS khi PĐT đổi lịch / phòng / ngày của lớp đã mở (mục 7.6)."""
    if lop.trang_thai in (TrangThaiLop.MO, TrangThaiLop.DANG_HOC):
        gui_cho_lop(lop, f"Lớp {lop.ma_lop} thay đổi lịch học", noi_dung, nguoi_gui)


def dong_bo_buoi_diem_danh(lop):
    """BR-20: lớp `MO`/`DANG_HOC` luôn có buổi điểm danh sinh sẵn khớp lịch hiện tại."""
    if lop.trang_thai in (TrangThaiLop.MO, TrangThaiLop.DANG_HOC):
        dong_bo_buoi(lop)


@transaction.atomic
def mo_lop(lop):
    lop = ClassSection.objects.select_for_update().select_related("mon_hoc").get(pk=lop.pk)
    if lop.trang_thai != TrangThaiLop.KE_HOACH:
        raise sai_trang_thai("Chỉ mở được lớp ở trạng thái kế hoạch.")
    if lop.mon_hoc.trang_thai == TrangThaiMon.NGUNG_SU_DUNG:
        raise sai_trang_thai("Môn học đã ngừng sử dụng, không mở lớp được.")
    if not lop.lich_hoc.exists():
        raise sai_trang_thai("Lớp chưa có lịch học.")
    lop.trang_thai = TrangThaiLop.MO
    lop.save(update_fields=["trang_thai"])
    dong_bo_buoi_diem_danh(lop)
    return lop


def ly_do_chua_dong_duoc(lop, hom_nay=None):
    """Lý do lớp chưa đóng được (mục 6), hoặc None nếu đủ điều kiện."""
    hom_nay = hom_nay or timezone.localdate()
    if lop.trang_thai != TrangThaiLop.DANG_HOC:
        return "Chỉ đóng được lớp đang học."
    if hom_nay <= ngay_ket_thuc_lop(lop):
        return "Lớp chưa kết thúc."
    co_diem = Grade.objects.filter(
        lop_hoc_phan=lop,
        sinh_vien=OuterRef("sinh_vien"),
        trang_thai__in=[TrangThaiDiem.CHINH_THUC, TrangThaiDiem.KHOA],
    )
    thieu_diem = Registration.objects.filter(
        lop_hoc_phan=lop, trang_thai=TrangThaiDangKy.DA_DANG_KY
    ).exclude(Exists(co_diem))
    if thieu_diem.exists():
        return "Còn sinh viên chưa có điểm chính thức."
    return None


@transaction.atomic
def dong_lop(lop, hom_nay=None):
    lop = ClassSection.objects.select_for_update().select_related("hoc_ky").get(pk=lop.pk)
    ly_do = ly_do_chua_dong_duoc(lop, hom_nay)
    if ly_do:
        raise sai_trang_thai(ly_do)
    lop.trang_thai = TrangThaiLop.DA_DONG
    lop.save(update_fields=["trang_thai"])
    # Yêu cầu sửa điểm danh còn chờ → tự từ chối (plan mục 5/6).
    AttendanceRequest.objects.filter(
        attendance__lop_hoc_phan=lop, trang_thai=TrangThaiDon.CHO_DUYET
    ).update(
        trang_thai=TrangThaiDon.TU_CHOI,
        ghi_chu="Quá hạn — lớp đã đóng",
        nguoi_duyet=None,
        ngay_duyet=timezone.now(),
    )
    return lop


def chuyen_trang_thai_lop_hang_ngay(hom_nay=None):
    """Job `classes_transition_daily` (mục 7.8). Idempotent: lớp đã ở trạng thái đích bị bỏ qua.
    Trả (số lớp → DANG_HOC, số lớp → DA_DONG)."""
    hom_nay = hom_nay or timezone.localdate()
    bat_dau = dong = 0
    for lop in ClassSection.objects.filter(trang_thai=TrangThaiLop.MO).select_related("hoc_ky"):
        if ngay_bat_dau_lop(lop) <= hom_nay:
            lop.trang_thai = TrangThaiLop.DANG_HOC
            lop.save(update_fields=["trang_thai"])
            bat_dau += 1
    for lop in ClassSection.objects.filter(trang_thai=TrangThaiLop.DANG_HOC).select_related(
        "hoc_ky"
    ):
        if ly_do_chua_dong_duoc(lop, hom_nay) is None:
            dong_lop(lop, hom_nay)
            dong += 1
    return bat_dau, dong


# --------------------------------------------------------------------- Lịch học


def tiet_cuoi_nhom(tiet_bat_dau):
    return next(cuoi for cuoi in _TIET_CUOI_NHOM if tiet_bat_dau <= cuoi)


def xung_dot_lich(hoc_ky_id, giao_vien_id, thu, tiet_bat_dau, tiet_ket_thuc, phong, bo_qua=None):
    """Phòng hoặc GV bị trùng với lịch khác cùng học kỳ, cùng `thu`, giao tiết (mục 5).
    `bo_qua`: queryset Schedule không xét (lịch đang sửa / lịch của lớp đang đổi GV).
    Trả {field: thông báo}."""
    qs = Schedule.objects.filter(
        lop_hoc_phan__hoc_ky_id=hoc_ky_id,
        thu=thu,
        tiet_bat_dau__lte=tiet_ket_thuc,
    ).select_related("lop_hoc_phan")
    if bo_qua is not None:
        qs = qs.exclude(pk__in=bo_qua.values("pk"))
    loi = {}
    for lich in qs:
        if lich.tiet_ket_thuc < tiet_bat_dau:
            continue
        if phong and lich.phong.casefold() == phong.casefold():
            loi["phong"] = f"Phòng {phong} đã có lớp {lich.lop_hoc_phan.ma_lop} học giờ này."
        if lich.lop_hoc_phan.giao_vien_id == giao_vien_id:
            loi["giao_vien"] = f"Giáo viên đã dạy lớp {lich.lop_hoc_phan.ma_lop} giờ này."
    return loi
