"""Nạp BẢNG GIÁ học phí thật cho các học kỳ đã có. Chạy lại an toàn.

Giá gốc (năm học 2026 - 2027): "Học phí đại học chính quy năm học 2026-2027 (dự kiến)" của trường — đơn giá
đồng/tín chỉ theo ngành, cộng hai mức do PĐT/KT chỉ định: khối kiến thức chung 700.000, tín chỉ thực hành 650.000.
Các năm học trước lùi theo công thức tuyến tính so với giá gốc, mỗi năm lùi:
  - giá ngành: giảm 10% giá gốc (2025-26 = 90%, 2024-25 = 80%, 2023-24 = 70%);
  - giá khối chung và giá thực hành: giảm 50.000 đồng.
Thứ tự tra giá (BR-16/17): khối kiến thức → ngành → mặc định cho phần lý thuyết; GIA_TH cho phần thực hành.
"""

import datetime as dt
from decimal import ROUND_HALF_UP, Decimal

from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from apps.training.models import Semester
from apps.tuition.models import HocPhanGia, TuitionConfig

TEN_HK_HIEN_TAI = "Học kỳ 1 - Năm học 2026 - 2027"
NAM_HIEN_TAI = 2026  # năm bắt đầu của năm học có giá gốc

# mã ngành trong hệ thống → đơn giá gốc (đồng/tín chỉ); dòng PDF tương ứng ghi bên phải
DON_GIA = {
    "QTKD": Decimal("895000"),  # Quản trị kinh doanh (7340101)
    "KTPM": Decimal("979688"),  # Kỹ thuật phần mềm (7480103)
    "OTO": Decimal("940500"),  # Công nghệ kỹ thuật ô tô (7510205)
    "GDTH": Decimal("895000"),  # Giáo dục Tiểu học (7140202)
    "QLMT": Decimal("955000"),  # Quản lý tài nguyên và môi trường (7850101)
}
GIA_KHOI_KIEN_THUC = {"chung": Decimal("700000")}  # thắng giá ngành với môn thuộc khối chung
GIA_THUC_HANH = Decimal("650000")  # mọi tín chỉ thực hành, kể cả môn khối chung
GIAM_NGANH_MOI_NAM = Decimal("0.10")  # lùi 1 năm: -10% giá gốc
GIAM_KHOI_VA_TH_MOI_NAM = Decimal("50000")  # lùi 1 năm: -50.000
HAN_DONG = dt.date(2026, 12, 10)  # ước lượng — KT chỉnh trên màn Chính sách học phí
HAN_DONG_SAU_NGAY = 30  # kỳ đã đóng: hạn đóng = ngày bắt đầu kỳ + 30 ngày (ước lượng)


def lui_nam(nam_hoc):
    """Số năm lùi so với năm học có giá gốc: '2025 - 2026' → 1."""
    return NAM_HIEN_TAI - int(nam_hoc.split("-")[0])


def giam_phan_tram(gia, so_nam):
    return (gia * (1 - GIAM_NGANH_MOI_NAM * so_nam)).quantize(Decimal("1"), ROUND_HALF_UP)


class Command(BaseCommand):
    help = "Nạp bảng giá học phí cho mọi học kỳ đã có (giá gốc 2026-2027, các năm trước lùi 10% / 50.000 mỗi năm)."

    @transaction.atomic
    def handle(self, *args, **options):
        if not Semester.objects.filter(ten_hk=TEN_HK_HIEN_TAI).exists():
            raise CommandError(f"Chưa có học kỳ '{TEN_HK_HIEN_TAI}' — chạy seed_hoc_ky trước.")
        so_hoc_ky = 0
        for hk in Semester.objects.order_by("ngay_bat_dau"):
            n = lui_nam(hk.nam_hoc)
            if n < 0:
                continue  # học kỳ sau năm học có giá gốc: chưa có bảng giá
            gia = [(HocPhanGia.PhamVi.NGANH, ma, giam_phan_tram(g, n)) for ma, g in DON_GIA.items()]
            gia += [
                (HocPhanGia.PhamVi.KHOI_KIEN_THUC, khoi, g - GIAM_KHOI_VA_TH_MOI_NAM * n)
                for khoi, g in GIA_KHOI_KIEN_THUC.items()
            ]
            gia.append((HocPhanGia.PhamVi.GIA_TH, None, GIA_THUC_HANH - GIAM_KHOI_VA_TH_MOI_NAM * n))
            for pham_vi, tham_chieu, don_gia in gia:
                HocPhanGia.objects.update_or_create(
                    hoc_ky=hk, pham_vi=pham_vi, tham_chieu=tham_chieu, defaults={"don_gia": don_gia}
                )
            hien_tai = hk.ten_hk == TEN_HK_HIEN_TAI
            TuitionConfig.objects.update_or_create(
                hoc_ky=hk,
                defaults={
                    "han_dong": HAN_DONG if hien_tai else hk.ngay_bat_dau + dt.timedelta(days=HAN_DONG_SAU_NGAY),
                    "ghi_chu": "Theo bảng học phí dự kiến năm học 2026 - 2027." if hien_tai else "Học kỳ đã đóng.",
                },
            )
            so_hoc_ky += 1
        self.stdout.write(f"Đã nạp bảng giá cho {so_hoc_ky} học kỳ ({len(DON_GIA)} ngành + khối chung + thực hành).")
