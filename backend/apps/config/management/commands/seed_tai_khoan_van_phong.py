"""Nạp tài khoản MẪU của Phòng đào tạo và Kế toán (tên giả). Chạy lại an toàn.

Username = email = <tên viết liền không dấu>@tdmu.edu.vn (giống giảng viên). Mật khẩu: SEED_DEMO_PASSWORD hoặc mặc định.
"""

import os

from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from apps.auth.models import Role
from apps.config.management.commands.seed_giang_vien import khong_dau

MAT_KHAU_MAC_DINH = "123456"
TEN_MIEN = "tdmu.edu.vn"

TAI_KHOAN = [
    (Role.PHONG_DAO_TAO, "Nguyễn Thị Phương Anh"),
    (Role.PHONG_DAO_TAO, "Trần Quốc Việt"),
    (Role.KE_TOAN, "Lê Thị Hồng Nhung"),
    (Role.KE_TOAN, "Phạm Văn Thịnh"),
]


class Command(BaseCommand):
    help = "Nạp 2 tài khoản Phòng đào tạo và 2 tài khoản Kế toán mẫu."

    @transaction.atomic
    def handle(self, *args, **options):
        mat_khau = os.environ.get("SEED_DEMO_PASSWORD", MAT_KHAU_MAC_DINH)
        User = get_user_model()
        for role, ho_ten in TAI_KHOAN:
            email = f"{khong_dau(ho_ten)}@{TEN_MIEN}"
            cu = User.objects.filter(username=email).exclude(role=role).first()
            if cu:  # không ghi đè tài khoản của vai trò khác (vd. trùng tên giảng viên)
                raise CommandError(f"{email} đã là tài khoản {cu.role} — đổi tên trong TAI_KHOAN.")
            user, _ = User.objects.update_or_create(
                username=email,
                defaults={"role": role, "first_name": ho_ten, "email": email, "is_locked": False, "is_active": True},
            )
            user.set_password(mat_khau)
            user.save(update_fields=["password"])
        self.stdout.write(f"Đã nạp {len(TAI_KHOAN)} tài khoản Phòng đào tạo / Kế toán.")
