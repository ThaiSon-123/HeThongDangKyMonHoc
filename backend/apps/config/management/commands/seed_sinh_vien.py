"""Nạp sinh viên MẪU (tên giả): 20 người mỗi ngành, đúng khóa tuyển sinh của CTĐT. Chạy lại an toàn.

Username = mã số sinh viên 13 chữ số: <khóa 2 số><nhóm ngành 2 số><mã ngành bỏ 2 số đầu><0><số thứ tự 3 số>,
ví dụ KTPM D23 người thứ 10 = 23 24 80103 0 010 = 2324801030010. Email <mssv>@student.tdmu.edu.vn.
Mật khẩu: SEED_DEMO_PASSWORD hoặc mặc định. Đây là người giả — không có hộp thư thật ở các địa chỉ này.
"""

import os
import random

from django.contrib.auth import get_user_model
from django.core.management import call_command
from django.core.management.base import BaseCommand
from django.db import transaction

from apps.auth.models import Role
from apps.config.management.commands.seed_ctdt import NGANH
from apps.config.management.commands.seed_giang_vien import HO, NAM, NU, khong_dau
from apps.profiles.models import StudentProfile
from apps.training.models import Curriculum

MAT_KHAU_MAC_DINH = "123456"
SO_SV_MOI_NGANH = 20

# mã ngành của trường (bảng học phí 2026-2027) và "nhóm ngành" 2 số trong mã số sinh viên
MA_NGANH_TRUONG = {"QTKD": "7340101", "KTPM": "7480103", "OTO": "7510205", "GDTH": "7140202", "QLMT": "7850101"}
NHOM_NGANH = {"KTPM": "24", "GDTH": "26", "OTO": "27", "QTKD": "23", "QLMT": "28"}  # QTKD, QLMT: giả định


def mssv(khoa_ts, ma_nganh, n):
    """D23 + KTPM + 10 → '2324801030010'."""
    return f"{khoa_ts[1:]}{NHOM_NGANH[ma_nganh]}{MA_NGANH_TRUONG[ma_nganh][2:]}0{n:03d}"


def sinh_ten(rng, da_co):
    while True:
        kho = rng.choice([NAM, NU])
        ten = f"{rng.choice(HO)} {rng.choice(kho['dem'])} {rng.choice(kho['ten'])}"
        if khong_dau(ten) not in da_co:
            da_co.add(khong_dau(ten))
            return ten


class Command(BaseCommand):
    help = "Nạp sinh viên mẫu (mặc định 20 người mỗi ngành, gắn với CTĐT của ngành)."

    def add_arguments(self, parser):
        parser.add_argument(
            "--moi-nganh",
            type=int,
            default=SO_SV_MOI_NGANH,
            help="số sinh viên mỗi ngành (tối đa 999); 20 người đầu mỗi ngành luôn có tên như cũ",
        )
        parser.add_argument(
            "--chi-nguoi-moi",
            action="store_true",
            help="bỏ qua sinh viên đã có (không đặt lại mật khẩu/hồ sơ), chỉ tạo người chưa có",
        )

    @transaction.atomic
    def handle(self, *args, **options):
        call_command("seed_ctdt", verbosity=0)
        mat_khau = os.environ.get("SEED_DEMO_PASSWORD", MAT_KHAU_MAC_DINH)
        User = get_user_model()
        rng = random.Random(2027)
        da_co = set()
        tong = 0
        moi_nganh = min(options["moi_nganh"], 999)
        # Lượt 1 đúng thứ tự cũ (20 người/ngành) để tên không đổi; lượt 2 là người thêm.
        luot = [
            (ng, n)
            for tu, den in ((1, SO_SV_MOI_NGANH), (SO_SV_MOI_NGANH + 1, moi_nganh))
            for ng in NGANH
            for n in range(tu, den + 1)
        ]
        ctdt_cua = {
            ng[1]: Curriculum.objects.select_related("nganh").get(ma_ctdt=f"CT-{ng[1]}-{ng[6]}")
            for ng in NGANH
        }
        for (_file, ma_nganh, _ten, _khoa, _nam, _tc, khoa_ts), n in luot:
            ctdt = ctdt_cua[ma_nganh]
            ho_ten = sinh_ten(rng, da_co)  # luôn sinh tên để dãy tên không đổi dù bỏ qua người đã có
            ma_sv = mssv(khoa_ts, ma_nganh, n)
            if options["chi_nguoi_moi"] and User.objects.filter(username=ma_sv).exists():
                continue
            email = f"{ma_sv}@student.tdmu.edu.vn"
            user, _ = User.objects.update_or_create(
                username=ma_sv,
                defaults={
                    "role": Role.SINH_VIEN,
                    "first_name": ho_ten,
                    "email": email,
                    "is_locked": False,
                    "is_active": True,
                },
            )
            user.set_password(mat_khau)
            user.save(update_fields=["password"])
            StudentProfile.objects.update_or_create(
                user=user,
                defaults={
                    "ma_sv": ma_sv,
                    "ho_ten": ho_ten,
                    "nganh": ctdt.nganh,
                    "ctdt": ctdt,
                    "khoa_nhap_hoc": khoa_ts,
                    "email": email,
                },
            )
            tong += 1
        self.stdout.write(f"Đã nạp {tong} sinh viên mẫu.")
