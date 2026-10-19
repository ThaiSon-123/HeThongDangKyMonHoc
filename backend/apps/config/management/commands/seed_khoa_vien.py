"""Nạp danh sách khoa/viện THẬT (không phải demo). Chạy lại an toàn.

Tách riêng khỏi seed_demo để xoá dữ liệu demo không đụng tới các khoa/viện này.
"""

from django.core.management.base import BaseCommand

from apps.training.models import Faculty

KHOA_VIEN = [
    ("KT", "Khoa Kinh tế"),
    ("VCNS", "Viện Công nghệ số"),
    ("VKTCN", "Viện Kỹ thuật công nghệ"),
    ("VCNXBV", "Viện Công nghệ xanh và bền vững"),
    ("SP", "Khoa Sư phạm"),
    ("NN", "Khoa Ngoại ngữ"),
]


class Command(BaseCommand):
    help = "Nạp khoa/viện thật (KT, VCNS, VKTCN, VCNXBV, SP, NN)."

    def handle(self, *args, **options):
        for ma, ten in KHOA_VIEN:
            Faculty.objects.update_or_create(ma_khoa=ma, defaults={"ten_khoa": ten})
        self.stdout.write(f"Đã nạp {len(KHOA_VIEN)} khoa/viện.")
