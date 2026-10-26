"""Cho sinh viên CHƯA đăng ký gì trong kỳ đăng ký THẬT vào lớp mở, để thanh tiến độ sĩ số có số.

Đi qua chính `registration.services.dang_ky` (BR-01..07: cửa sổ đăng ký, còn chỗ, trùng lịch, tiên quyết,
tín chỉ) nên sĩ số, học phí và thông báo luôn khớp; đăng ký bị từ chối thì thử lớp/môn khác. Mỗi sinh viên
đăng ký các môn trong CTĐT của mình có lớp mở, đến khi đủ số tín chỉ mục tiêu. Lớp đứng đầu mỗi môn được
chọn nhiều hơn (trọng số 1, 1/2, 1/3…) nên sĩ số các lớp không đều nhau. Kết quả cố định theo `--seed`.
Chỉ động tới sinh viên chưa có đăng ký nào trong kỳ; chạy lại không thêm gì.
"""

import random
from collections import Counter, defaultdict

from django.core.management.base import BaseCommand, CommandError
from rest_framework.exceptions import ValidationError

from apps.profiles.models import StudentProfile
from apps.registration.models import Registration, TrangThaiDangKy
from apps.registration.services import dang_ky
from apps.training.models import ClassSection, CurriculumCourse, Semester, TrangThaiLop
from apps.training.services import hoc_ky_mac_dinh
from core.exceptions import BusinessError


def thu_tu_uu_tien(rng, lop_ids):
    """Xáo trộn có trọng số 1/(hạng+1): lớp đầu danh sách hay được thử trước."""
    con = list(lop_ids)
    ra = []
    while con:
        w = [1 / (i + 1) for i in range(len(con))]
        ra.append(con.pop(rng.choices(range(len(con)), weights=w)[0]))
    return ra


class Command(BaseCommand):
    help = (
        "Đăng ký thật vào lớp mở cho sinh viên chưa đăng ký gì (qua dịch vụ đăng ký, đủ quy tắc)."
    )

    def add_arguments(self, parser):
        parser.add_argument("--hoc-ky", type=int, help="id học kỳ (mặc định: học kỳ hiện tại)")
        parser.add_argument("--seed", type=int, default=2027)
        parser.add_argument("--tin-chi-min", type=int, default=15)
        parser.add_argument("--tin-chi-max", type=int, default=21)
        parser.add_argument(
            "--de-trong",
            type=int,
            default=0,
            help="chừa lại N sinh viên đầu (theo id) chưa đăng ký của mỗi CTĐT để tự thử đăng ký",
        )

    def handle(self, *args, **options):
        hk = (
            Semester.objects.filter(pk=options["hoc_ky"]).first()
            if options["hoc_ky"]
            else hoc_ky_mac_dinh()
        )
        if hk is None:
            raise CommandError("Không xác định được học kỳ.")
        rng = random.Random(options["seed"])

        lop_mo = defaultdict(list)  # môn → id các lớp mở (theo mã lớp: L01 trước)
        for lop_id, mon_id in (
            ClassSection.objects.filter(hoc_ky=hk, trang_thai=TrangThaiLop.MO)
            .order_by("ma_lop")
            .values_list("id", "mon_hoc_id")
        ):
            lop_mo[mon_id].append(lop_id)
        mon_ctdt = defaultdict(list)  # CTĐT → [(môn, tín chỉ, bắt buộc)]
        for cc in CurriculumCourse.objects.select_related("mon_hoc"):
            if cc.mon_hoc_id in lop_mo:
                mon_ctdt[cc.ctdt_id].append(
                    (cc.mon_hoc_id, cc.mon_hoc.tong_tin_chi, cc.loai_mon == "bat_buoc")
                )
        da_dk = set(
            Registration.objects.filter(
                lop_hoc_phan__hoc_ky=hk, trang_thai=TrangThaiDangKy.DA_DANG_KY
            ).values_list("sinh_vien_id", flat=True)
        )

        so_sv = so_dk = 0
        de_lai = Counter()  # CTĐT → số sinh viên đã chừa trống
        for ho_so in StudentProfile.objects.select_related("user").order_by("id"):
            if ho_so.user_id in da_dk or ho_so.ctdt_id is None:
                continue
            if de_lai[ho_so.ctdt_id] < options["de_trong"]:
                de_lai[ho_so.ctdt_id] += 1
                continue
            muc_tieu = rng.randint(options["tin_chi_min"], options["tin_chi_max"])
            mon = sorted(mon_ctdt[ho_so.ctdt_id], key=lambda m: (not m[2], rng.random()))
            tin_chi = 0
            for mon_id, tc, _bat_buoc in mon:
                if tin_chi >= muc_tieu:
                    break
                for lop_id in thu_tu_uu_tien(rng, lop_mo[mon_id]):
                    try:
                        dang_ky(ho_so.user, lop_id)
                    except (BusinessError, ValidationError):
                        continue  # vướng quy tắc (trùng lịch, đầy, tiên quyết, vượt tín chỉ): thử lớp khác
                    tin_chi += tc
                    so_dk += 1
                    break
            if tin_chi:
                so_sv += 1
        self.stdout.write(f"{hk.ten_hk}: {so_dk} đăng ký mới cho {so_sv} sinh viên.")
