"""Tính học phí của một sinh viên trong một học kỳ (BR-15..17). Pha 6 thêm `calculate` hàng loạt,
thu/hoàn tiền; ở đây chỉ phần Pha 3 cần: tính lại sau đăng ký/hủy."""

from decimal import Decimal

from django.db.models import Q, Sum

from apps.profiles.models import StudentProfile
from apps.registration.models import Registration, TrangThaiDangKy
from apps.training.models import CurriculumCourse
from apps.tuition.models import HocPhanGia, TrangThaiHocPhi, Tuition
from apps.tuition.pricing import tra_bang_gia
from core.exceptions import Codes, business_error


def tinh_hoc_phi(sinh_vien, hoc_ky):
    """Tính lại `Tuition` của (sinh_vien, hoc_ky) chỉ từ đăng ký `DA_DANG_KY` + bảng giá hiện tại
    (BR-15) — không đụng Payment/Discount. Thiếu giá → `CHUA_CAU_HINH_GIA`; bản ghi giữ nguyên
    (tạo mới thì ở `CHUA_TINH`)."""
    tuition, _ = Tuition.objects.get_or_create(sinh_vien=sinh_vien, hoc_ky=hoc_ky)
    ho_so = StudentProfile.objects.select_related("nganh").get(user=sinh_vien)
    dang_ky = list(
        Registration.objects.filter(
            sinh_vien=sinh_vien, trang_thai=TrangThaiDangKy.DA_DANG_KY, lop_hoc_phan__hoc_ky=hoc_ky
        ).select_related("lop_hoc_phan__mon_hoc")
    )
    khoi = dict(
        CurriculumCourse.objects.filter(
            ctdt_id=ho_so.ctdt_id, mon_hoc__in=[r.lop_hoc_phan.mon_hoc_id for r in dang_ky]
        ).values_list("mon_hoc_id", "khoi_kien_thuc")
    )
    bang_gia = list(HocPhanGia.objects.filter(Q(hoc_ky=hoc_ky) | Q(hoc_ky__isnull=True)))
    tong_tien, tong_tin_chi = Decimal(0), 0
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
        tong_tien += gia.tong_tien
        tong_tin_chi += mon.tong_tin_chi
    tuition.tong_tien = tong_tien
    tuition.tong_tin_chi = tong_tin_chi
    tuition.trang_thai = TrangThaiHocPhi.DA_TINH
    tuition.save(update_fields=["tong_tien", "tong_tin_chi", "trang_thai"])
    return tuition


def tong_tin_chi_dang_ky(sinh_vien, hoc_ky):
    return (
        Registration.objects.filter(
            sinh_vien=sinh_vien, trang_thai=TrangThaiDangKy.DA_DANG_KY, lop_hoc_phan__hoc_ky=hoc_ky
        ).aggregate(t=Sum("lop_hoc_phan__mon_hoc__tong_tin_chi"))["t"]
        or 0
    )
