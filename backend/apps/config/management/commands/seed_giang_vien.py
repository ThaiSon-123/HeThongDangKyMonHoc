"""Nạp giảng viên MẪU (tên giả), 15–20 người mỗi khoa/viện. Chạy lại an toàn (tên sinh cố định theo seed).

Username = email = <tên viết liền không dấu>@tdmu.edu.vn (ví dụ nguyenminhkhoi@tdmu.edu.vn); mã `GV<MÃ KHOA><nn>`.
Mật khẩu: SEED_DEMO_PASSWORD hoặc mặc định. Đây là người giả — không có hộp thư thật ở các địa chỉ này.
"""

import os
import random
import unicodedata

from django.contrib.auth import get_user_model
from django.core.management import call_command
from django.core.management.base import BaseCommand
from django.db import transaction

from apps.auth.models import Role
from apps.profiles.models import TeacherProfile
from apps.training.models import Faculty

MAT_KHAU_MAC_DINH = "123456"
TEN_MIEN = "tdmu.edu.vn"

# mã khoa/viện → số giảng viên (15–20)
SO_GV = {"VCNS": 20, "VKTCN": 18, "VCNXBV": 16, "SP": 20, "NN": 15, "KT": 18}

HO = ["Nguyễn", "Trần", "Lê", "Phạm", "Huỳnh", "Hoàng", "Phan", "Vũ", "Võ", "Đặng", "Bùi", "Đỗ", "Hồ", "Ngô",
      "Dương", "Lý", "Trương", "Đinh", "Lâm", "Mai"]
NAM = {
    "dem": ["Văn", "Minh", "Quốc", "Hoàng", "Đức", "Thanh", "Anh", "Hữu", "Gia", "Ngọc", "Xuân", "Thành"],
    "ten": ["Khôi", "Bảo", "Hùng", "Nam", "Thắng", "Phúc", "Tuấn", "Sơn", "Lợi", "Dũng", "Hải", "Long", "Trung",
            "Quang", "Kiên", "Tài", "Đạt", "Phong", "Vinh", "Khang"],
}
NU = {
    "dem": ["Thị", "Thị Thu", "Thị Ngọc", "Thị Kim", "Thị Mỹ", "Thị Thanh", "Thị Hồng", "Thị Bích", "Ngọc", "Thu"],
    "ten": ["Hà", "Lan", "Mai", "Xuân", "Nhung", "Oanh", "Tâm", "Linh", "Ngọc", "Hương", "Trang", "Thảo", "Vân",
            "Yến", "Loan", "Phương", "Hạnh", "Dung", "Hiền", "Châu"],
}


def khong_dau(ten):
    s = unicodedata.normalize("NFD", ten.replace("đ", "d").replace("Đ", "D"))
    return "".join(c for c in s if not unicodedata.combining(c)).replace(" ", "").lower()


def sinh_giang_vien():
    """{mã khoa: [(họ tên, học vị)]} — cố định theo seed, tên không trùng giữa các khoa/viện."""
    rng = random.Random(2026)
    da_co = set()
    ket_qua = {}
    for ma_khoa, so in SO_GV.items():
        ds = []
        while len(ds) < so:
            kho = rng.choice([NAM, NU])
            ten = f"{rng.choice(HO)} {rng.choice(kho['dem'])} {rng.choice(kho['ten'])}"
            if khong_dau(ten) in da_co:
                continue
            da_co.add(khong_dau(ten))
            ds.append((ten, "TS" if rng.random() < 0.3 else "ThS"))
        ket_qua[ma_khoa] = ds
    return ket_qua


class Command(BaseCommand):
    help = "Nạp giảng viên mẫu (15–20 người mỗi khoa/viện)."

    @transaction.atomic
    def handle(self, *args, **options):
        call_command("seed_khoa_vien", verbosity=0)
        mat_khau = os.environ.get("SEED_DEMO_PASSWORD", MAT_KHAU_MAC_DINH)
        User = get_user_model()
        tong = 0
        for ma_khoa, ds in sinh_giang_vien().items():
            khoa = Faculty.objects.get(ma_khoa=ma_khoa)
            for n, (ho_ten, hoc_vi) in enumerate(ds, 1):
                email = f"{khong_dau(ho_ten)}@{TEN_MIEN}"
                user, _ = User.objects.update_or_create(
                    username=email,
                    defaults={
                        "role": Role.GIAO_VIEN,
                        "first_name": ho_ten,
                        "email": email,
                        "is_locked": False,
                        "is_active": True,
                    },
                )
                user.set_password(mat_khau)
                user.save(update_fields=["password"])
                TeacherProfile.objects.update_or_create(
                    user=user,
                    defaults={
                        "ma_gv": f"GV{ma_khoa}{n:02d}",
                        "ho_ten": ho_ten,
                        "khoa": khoa,
                        "hoc_vi": hoc_vi,
                        "email": email,
                    },
                )
                tong += 1
        self.stdout.write(f"Đã nạp {tong} giảng viên mẫu.")
