"""Nạp học kỳ THẬT (không phải demo). Chạy lại an toàn.

Ngày tháng bên dưới là ước lượng — PĐT sửa lại trên màn Học kỳ khi có lịch chính thức.
"""

import datetime as dt

from django.core.management.base import BaseCommand
from django.utils import timezone

from apps.training.models import Semester, TrangThaiHocKy


def gio(nam, thang, ngay, gio_=0, phut=0):
    return timezone.make_aware(dt.datetime(nam, thang, ngay, gio_, phut))


def hoc_ky_da_dong(nam, ky):
    """Học kỳ `ky` (1 = HK1, 2 = HK2, 3 = hè) của năm học nam-(nam+1), đã đóng. Ngày ước lượng theo lịch HK1/HK2/hè."""
    bat_dau, ket_thuc = {
        1: (dt.date(nam, 9, 7), dt.date(nam + 1, 1, 17)),
        2: (dt.date(nam + 1, 2, 1), dt.date(nam + 1, 6, 6)),
        3: (dt.date(nam + 1, 6, 15), dt.date(nam + 1, 8, 15)),
    }[ky]
    dong_dk = bat_dau + dt.timedelta(days=14)
    return {
        "ten_hk": f"Học kỳ {ky} - Năm học {nam} - {nam + 1}",
        "nam_hoc": f"{nam} - {nam + 1}",
        "ngay_bat_dau": bat_dau,
        "ngay_ket_thuc": ket_thuc,
        "cua_so_dk_bat_dau": gio(bat_dau.year, bat_dau.month, bat_dau.day),
        "cua_so_dk_ket_thuc": gio(dong_dk.year, dong_dk.month, dong_dk.day, 23, 59),
        "trang_thai": TrangThaiHocKy.DONG,
    }


# Các kỳ trước theo CTĐT (file Excel có đủ HK1/HK2 mỗi năm, riêng OTO/QTKD có thêm HK3 hè), từ 2023.
HOC_KY = [hoc_ky_da_dong(nam, ky) for nam in (2023, 2024, 2025) for ky in (1, 2, 3)] + [
    {
        "ten_hk": "Học kỳ 1 - Năm học 2026 - 2027",
        "nam_hoc": "2026 - 2027",
        "ngay_bat_dau": dt.date(2026, 9, 7),
        "ngay_ket_thuc": dt.date(2027, 1, 17),
        # Cửa sổ đăng ký phải nằm trong thời gian học kỳ (serializer chặn nếu lệch).
        "cua_so_dk_bat_dau": gio(2026, 10, 15),
        "cua_so_dk_ket_thuc": gio(2026, 11, 15, 23, 59),
        "trang_thai": TrangThaiHocKy.MO,
    },
]


class Command(BaseCommand):
    help = "Nạp học kỳ thật: các kỳ đã đóng từ 2023 và Học kỳ 1 - Năm học 2026 - 2027 (đang mở)."

    def handle(self, *args, **options):
        for hk in HOC_KY:
            ten = hk["ten_hk"]
            Semester.objects.update_or_create(
                ten_hk=ten, defaults={k: v for k, v in hk.items() if k != "ten_hk"}
            )
        self.stdout.write(f"Đã nạp {len(HOC_KY)} học kỳ.")
