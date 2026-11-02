"""Mở một học kỳ MỚI cho sinh viên đăng ký trước: tạo học kỳ `MO` (ngày theo lịch ước lượng của seed_hoc_ky), cửa sổ
đăng ký mở từ hôm nay tới 2 tuần sau ngày bắt đầu kỳ, xếp lớp học phần theo khối "Học kỳ N - Năm học ..." của file Excel
CTĐT (cùng bộ xếp lịch với seed_lop_hoc_phan) cộng các môn `--them-mon` (lớp học lại / học vượt), chép bảng giá học phí của kỳ gần nhất, hạn đóng = bắt đầu kỳ + 30 ngày.

Chạy lại an toàn khi kỳ chưa có đăng ký (xếp lại lớp); đã có đăng ký thì chỉ cập nhật học kỳ, không đụng lớp.

    python manage.py mo_hoc_ky_moi --ten "Học kỳ 2 - Năm học 2026 - 2027"         --them-mon LING189,LING022,LING344,KTPM023,LING190
"""

import datetime as dt
from collections import defaultdict

from django.core.management.base import BaseCommand, CommandError
from django.db import transaction
from django.utils import timezone

from apps.config.management.commands import seed_lop_hoc_phan
from apps.config.management.commands.seed_hoc_ky import gio, hoc_ky_da_dong
from apps.config.management.commands.seed_lop_hoc_phan import TEN_HK, doc_nhom, tao_lop_hoc_ky
from apps.profiles.models import TeacherProfile
from apps.registration.models import Registration
from apps.training.models import Course, Semester, TrangThaiHocKy
from apps.tuition.models import HocPhanGia, TuitionConfig

HAN_DONG_SAU_NGAY = 30


class Command(BaseCommand):
    help = "Mở học kỳ mới (lớp học phần + bảng giá + cửa sổ đăng ký từ hôm nay) để sinh viên đăng ký trước."

    def add_arguments(self, parser):
        parser.add_argument("--ten", default="Học kỳ 2 - Năm học 2026 - 2027")
        parser.add_argument(
            "--them-mon",
            default="",
            help="Mã môn mở thêm lớp (học lại / học vượt), cách nhau dấu phẩy",
        )

    @transaction.atomic
    def handle(self, *args, ten, them_mon, **options):
        khop = TEN_HK.fullmatch(ten)
        if not khop:
            raise CommandError('Tên học kỳ phải có dạng "Học kỳ N - Năm học YYYY - YYYY".')
        nhom = doc_nhom()
        if ten not in nhom:
            raise CommandError(f"File Excel CTĐT không có khối '{ten}'.")
        ky, nam = int(khop[1]), int(khop[2])
        mau = hoc_ky_da_dong(nam, ky)
        hom_nay = timezone.localdate()
        dong_dk = mau["ngay_bat_dau"] + dt.timedelta(days=14)
        hk, _ = Semester.objects.update_or_create(
            ten_hk=ten,
            defaults={
                **{k: v for k, v in mau.items() if k != "ten_hk"},
                "cua_so_dk_bat_dau": gio(hom_nay.year, hom_nay.month, hom_nay.day),
                "cua_so_dk_ket_thuc": gio(dong_dk.year, dong_dk.month, dong_dk.day, 23, 59),
                "trang_thai": TrangThaiHocKy.MO,
            },
        )

        if Registration.objects.filter(lop_hoc_phan__hoc_ky=hk).exists():
            self.stdout.write(f"{ten}: đã có đăng ký — giữ nguyên lớp học phần.")
        else:
            mon = {c.ma_mon: c for c in Course.objects.all()}
            them = [m.strip() for m in them_mon.split(",") if m.strip()]
            if sai := [m for m in them if m not in mon]:
                raise CommandError(f"Không có môn: {', '.join(sai)}.")
            nhom_hk = {**nhom[ten], **({"MO_THEM": them} if them else {})}
            gv_theo_khoa = defaultdict(list)
            for g in TeacherProfile.objects.order_by("id"):
                gv_theo_khoa[g.khoa_id].append(g)
            so_lop, so_mon = tao_lop_hoc_ky(hk, nhom_hk, mon, gv_theo_khoa)
            seed_lop_hoc_phan.Command()._kiem_tra({ten: nhom_hk})  # sai thì CommandError → rollback
            self.stdout.write(f"{ten}: {so_lop} lớp ({so_mon} môn), không trùng lịch GV/phòng.")

        self._bang_gia(hk)
        self.stdout.write(
            f"Cửa sổ đăng ký {hk.cua_so_dk_bat_dau:%d/%m/%Y} – {timezone.localtime(hk.cua_so_dk_ket_thuc):%d/%m/%Y}; "
            f"học từ {hk.ngay_bat_dau:%d/%m/%Y} đến {hk.ngay_ket_thuc:%d/%m/%Y}."
        )

    def _bang_gia(self, hk):
        """Chép đơn giá của kỳ gần nhất trước đó có bảng giá (cùng năm học thì giá không đổi)."""
        nguon = (
            Semester.objects.filter(ngay_bat_dau__lt=hk.ngay_bat_dau, bang_gia__isnull=False)
            .order_by("-ngay_bat_dau")
            .first()
        )
        if nguon is None:
            raise CommandError("Chưa có bảng giá học phí nào để chép — chạy seed_hoc_phi trước.")
        for g in HocPhanGia.objects.filter(hoc_ky=nguon):
            HocPhanGia.objects.update_or_create(
                hoc_ky=hk,
                pham_vi=g.pham_vi,
                tham_chieu=g.tham_chieu,
                defaults={"don_gia": g.don_gia},
            )
        TuitionConfig.objects.update_or_create(
            hoc_ky=hk,
            defaults={
                "han_dong": hk.ngay_bat_dau + dt.timedelta(days=HAN_DONG_SAU_NGAY),
                "ghi_chu": f"Chép bảng giá từ {nguon.ten_hk}.",
            },
        )
        self.stdout.write(
            f"Bảng giá: chép {HocPhanGia.objects.filter(hoc_ky=hk).count()} dòng từ {nguon.ten_hk}."
        )
