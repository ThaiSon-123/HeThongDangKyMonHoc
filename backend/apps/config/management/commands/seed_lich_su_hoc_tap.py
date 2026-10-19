"""Nạp LỊCH SỬ HỌC TẬP cho sinh viên mẫu: đăng ký + điểm (đã khóa) + học phí (đã thu đủ) cho mọi học kỳ ĐÃ ĐÓNG,
theo đúng khối "Học kỳ N" của CTĐT trong Excel. Học kỳ đang mở để trống để thử luồng đăng ký. Điểm mẫu — tên người giả.

Quy tắc:
  - mỗi kỳ: mọi môn bắt buộc (và các môn là tiên quyết của môn bắt buộc) + vài môn tự chọn cho đủ ~14–20 tín chỉ;
  - sinh viên thứ i của ngành chọn "lớp thứ (i mod 3)" của mọi môn → lịch không trùng (xem seed_lop_hoc_phan);
  - chỉ đăng ký môn khi đã ĐẠT mọi môn tiên quyết ở kỳ trước; môn là tiên quyết của môn khác không bao giờ trượt;
  - 2 sinh viên mỗi ngành học yếu (GPA < 2.0, diện cảnh báo học vụ → trần 14 tín chỉ khi đăng ký kỳ sau).
Chạy lại an toàn: xoá lịch sử cũ của sinh viên mẫu rồi sinh lại (kết quả cố định). Chạy SAU seed_lop_hoc_phan.
Sau khi có đăng ký, seed_lop_hoc_phan sẽ từ chối chạy lại.
"""

import random
from collections import defaultdict
from datetime import datetime, timedelta
from decimal import Decimal

from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction
from django.db.models import Count
from django.utils import timezone

from apps.auth.models import Role
from apps.config.management.commands.seed_lop_hoc_phan import doc_nhom
from apps.grades.models import Grade, TrangThaiDiem
from apps.grades.services import cap_nhat_ho_so, tinh_tong_ket, xep_loai_diem
from apps.registration.models import Registration, TrangThaiDangKy
from apps.profiles.models import StudentProfile
from apps.registration.services import lich_trung
from apps.training.models import (
    ClassSection,
    Course,
    CurriculumCourse,
    LoaiMon,
    Prerequisite,
    Semester,
    TrangThaiHocKy,
)
from apps.tuition.models import LoaiThanhToan, Payment, PhuongThuc, Tuition
from apps.tuition.services import tinh_hoc_phi

D = Decimal
SEED = 2028
SO_TKB = 3  # số "lớp thứ j" đầu tiên của mọi môn tạo thành thời khóa biểu không trùng
TIN_CHI_TOI_DA_KY = 24
SV_YEU_MOI_NGANH = 2


def kep(x):
    return D(str(round(min(10.0, max(0.0, x)), 1)))


def tao_diem(rng, nang_luc, la_tien_quyet):
    """(quá trình, giữa kỳ, cuối kỳ, tổng kết). Môn là tiên quyết của môn khác: nâng cuối kỳ cho tới khi đạt."""
    qt = kep(nang_luc + 0.5 + rng.gauss(0, 0.8))
    gk = kep(nang_luc + rng.gauss(0, 1.0))
    ck = kep(nang_luc + rng.gauss(0, 1.0))
    tong = tinh_tong_ket(qt, gk, ck)
    while la_tien_quyet and tong < D("4.00"):
        ck = min(D("10"), ck + D("0.5"))
        tong = tinh_tong_ket(qt, gk, ck)
    return qt, gk, ck, tong


class Command(BaseCommand):
    help = "Nạp lịch sử học tập (đăng ký + điểm + học phí) cho sinh viên mẫu ở mọi học kỳ đã đóng."

    @transaction.atomic
    def handle(self, *args, **options):
        User = get_user_model()
        svs = list(
            User.objects.filter(role=Role.SINH_VIEN, sinh_vien__ma_sv__regex=r"^\d{13}$")
            .select_related("sinh_vien__ctdt__nganh")
            .order_by("sinh_vien__ma_sv")
        )
        if not svs:
            raise CommandError("Chưa có sinh viên mẫu — chạy seed_sinh_vien trước.")
        admin = User.objects.filter(role=Role.ADMIN).order_by("id").first()
        if admin is None:
            raise CommandError("Cần một tài khoản ADMIN để ghi người thu học phí.")
        if not ClassSection.objects.exists():
            raise CommandError("Chưa có lớp học phần — chạy seed_lop_hoc_phan trước.")

        Payment.objects.filter(tuition__sinh_vien__in=svs).delete()
        for model in (Tuition, Grade, Registration):
            model.objects.filter(sinh_vien__in=svs).delete()
        ClassSection.objects.update(si_so_hien_tai=0)

        nhom = doc_nhom()
        mon_theo_ma = {c.ma_mon: c for c in Course.objects.all()}
        tien_quyet = defaultdict(set)
        for mon_id, tq_id in Prerequisite.objects.values_list("mon_hoc_id", "mon_tien_quyet_id"):
            tien_quyet[mon_id].add(tq_id)
        la_tien_quyet = {tq for ds in tien_quyet.values() for tq in ds}
        lop_theo = {}
        for lop in ClassSection.objects.select_related("hoc_ky", "mon_hoc"):
            lop_theo[(lop.hoc_ky_id, lop.mon_hoc.ma_mon, lop.ma_lop.split(".L")[1][:2])] = lop
        hoc_ky_dong = list(Semester.objects.filter(trang_thai=TrangThaiHocKy.DONG).order_by("ngay_bat_dau"))
        loai_mon = defaultdict(dict)  # ctdt_id → {mon_id: loai_mon}
        for cc in CurriculumCourse.objects.all():
            loai_mon[cc.ctdt_id][cc.mon_hoc_id] = cc.loai_mon

        chi_so_nganh = defaultdict(int)  # thứ tự sinh viên trong ngành → chọn "lớp thứ j"
        dang_ky, diem = [], []
        for sv in svs:
            ho_so = sv.sinh_vien
            ma_nganh = ho_so.nganh.ma_nganh
            i = chi_so_nganh[ma_nganh]
            chi_so_nganh[ma_nganh] += 1
            lane = f"{i % SO_TKB + 1:02d}"
            rng = random.Random(SEED + int(ho_so.ma_sv))
            yeu = i >= 20 - SV_YEU_MOI_NGANH
            nang_luc = rng.uniform(4.8, 5.3) if yeu else min(9.4, max(5.8, rng.gauss(7.6, 0.8)))

            # môn bắt buộc + mọi môn tiên quyết (bắc cầu) của chúng: sinh viên phải học để mở khóa các môn sau
            can_hoc = {m for m, loai in loai_mon[ho_so.ctdt_id].items() if loai == LoaiMon.BAT_BUOC}
            cho = list(can_hoc)
            while cho:
                for tq in tien_quyet[cho.pop()]:
                    if tq in loai_mon[ho_so.ctdt_id] and tq not in can_hoc:
                        can_hoc.add(tq)
                        cho.append(tq)

            da_dat = set()
            for hk in hoc_ky_dong:
                ds_ma = nhom.get(hk.ten_hk, {}).get(ma_nganh)
                if not ds_ma:
                    continue
                mon_ky = [mon_theo_ma[m] for m in ds_ma]
                chon = [m for m in mon_ky if m.id in can_hoc and tien_quyet[m.id] <= da_dat]
                tin_chi = sum(m.tong_tin_chi for m in chon)
                muc_tieu = rng.randint(14, 20)
                tu_chon = [m for m in mon_ky if m.id not in can_hoc and tien_quyet[m.id] <= da_dat]
                rng.shuffle(tu_chon)
                for m in tu_chon:
                    if tin_chi >= muc_tieu:
                        break
                    if tin_chi + m.tong_tin_chi <= TIN_CHI_TOI_DA_KY:
                        chon.append(m)
                        tin_chi += m.tong_tin_chi
                dat_ky = set()
                for m in chon:
                    lop = lop_theo[(hk.id, m.ma_mon, lane)]
                    dang_ky.append(Registration(sinh_vien=sv, lop_hoc_phan=lop))
                    qt, gk, ck, tong = tao_diem(rng, nang_luc, m.id in la_tien_quyet)
                    chu, gpa = xep_loai_diem(tong, m.loai_danh_gia)
                    diem.append(
                        Grade(
                            lop_hoc_phan=lop, sinh_vien=sv, diem_qua_trinh=qt, diem_giua_ky=gk, diem_cuoi_ky=ck,
                            diem_tong_ket=tong, diem_chu=chu, gpa_thang_4=gpa, trang_thai=TrangThaiDiem.KHOA,
                        )
                    )
                    if chu != "F":
                        dat_ky.add(m.id)
                da_dat |= dat_ky  # chỉ tính là đã đạt từ kỳ sau

        Registration.objects.bulk_create(dang_ky)
        Grade.objects.bulk_create(diem)
        for hk in hoc_ky_dong:  # ngày giả lập theo học kỳ (auto_now_add ghi ngày chạy lệnh)
            Registration.objects.filter(lop_hoc_phan__hoc_ky=hk).update(
                ngay_dang_ky=hk.cua_so_dk_bat_dau + timedelta(days=1)
            )
            ngay_nhap = timezone.make_aware(datetime.combine(hk.ngay_ket_thuc, datetime.min.time())) + timedelta(days=3)
            Grade.objects.filter(lop_hoc_phan__hoc_ky=hk).update(ngay_nhap=ngay_nhap)
        si_so = Registration.objects.values("lop_hoc_phan_id").annotate(n=Count("id"))
        lop_cap_nhat = []
        for r in si_so:
            lop = ClassSection(id=r["lop_hoc_phan_id"], si_so_hien_tai=r["n"])
            lop_cap_nhat.append(lop)
        ClassSection.objects.bulk_update(lop_cap_nhat, ["si_so_hien_tai"])

        for sv in svs:
            for hk_id in {r.lop_hoc_phan.hoc_ky_id for r in dang_ky if r.sinh_vien_id == sv.id}:
                hk = next(h for h in hoc_ky_dong if h.id == hk_id)
                tuition = tinh_hoc_phi(sv, hk)
                if tuition.tong_tien > 0:
                    Payment.objects.create(
                        tuition=tuition, loai=LoaiThanhToan.THU, so_tien=tuition.tong_tien,
                        phuong_thuc=PhuongThuc.CHUYEN_KHOAN, nguoi_thu=admin, bien_lai_ma=f"BL{tuition.id:06d}",
                    )
            cap_nhat_ho_so(sv)
        for hk in hoc_ky_dong:
            Payment.objects.filter(tuition__hoc_ky=hk).update(ngay=hk.cua_so_dk_ket_thuc + timedelta(days=5))

        self._kiem_tra(svs)
        self._tom_tat(svs, len(dang_ky))

    def _tom_tat(self, svs, so_dang_ky):
        ho_so = StudentProfile.objects.filter(user__in=svs).select_related("nganh")
        for ma in ("KTPM", "QTKD", "OTO", "GDTH", "QLMT"):
            nhom_sv = [h for h in ho_so if h.nganh.ma_nganh == ma]
            gpa = [float(h.gpa) for h in nhom_sv if h.gpa is not None]
            tl = [h.tin_chi_tich_luy for h in nhom_sv]
            self.stdout.write(
                f"{ma}: GPA {min(gpa):.2f}–{max(gpa):.2f} (TB {sum(gpa) / len(gpa):.2f}), "
                f"tín chỉ tích lũy {min(tl)}–{max(tl)}, {sum(g < 2 for g in gpa)} SV diện cảnh báo học vụ"
            )
        self.stdout.write(f"Đã nạp {so_dang_ky} đăng ký + điểm + học phí. Kiểm tra tiên quyết/trùng lịch/sĩ số: ĐẠT.")

    def _kiem_tra(self, svs):
        """Dò lại từ DB: tiên quyết đã đạt ở kỳ trước, không trùng lịch trong kỳ, không vượt sĩ số, mỗi môn một lần."""
        tien_quyet = defaultdict(set)
        for mon_id, tq_id in Prerequisite.objects.values_list("mon_hoc_id", "mon_tien_quyet_id"):
            tien_quyet[mon_id].add(tq_id)
        theo_sv = defaultdict(list)
        diem = {(g.lop_hoc_phan_id, g.sinh_vien_id): g.diem_chu for g in Grade.objects.filter(sinh_vien__in=svs)}
        for r in Registration.objects.filter(sinh_vien__in=svs).select_related("lop_hoc_phan__hoc_ky", "lop_hoc_phan__mon_hoc").prefetch_related("lop_hoc_phan__lich_hoc"):
            theo_sv[r.sinh_vien_id].append(r)
        for sv_id, ds in theo_sv.items():
            mon_ids = [r.lop_hoc_phan.mon_hoc_id for r in ds]
            if len(mon_ids) != len(set(mon_ids)):
                raise CommandError(f"SV {sv_id}: đăng ký trùng môn.")
            dat_truoc = defaultdict(set)  # ngày bắt đầu kỳ → môn đạt trong kỳ đó
            for r in ds:
                if diem[(r.lop_hoc_phan_id, sv_id)] != "F":
                    dat_truoc[r.lop_hoc_phan.hoc_ky.ngay_bat_dau].add(r.lop_hoc_phan.mon_hoc_id)
            for r in ds:
                bat_dau = r.lop_hoc_phan.hoc_ky.ngay_bat_dau
                da_dat = set().union(*(m for ngay, m in dat_truoc.items() if ngay < bat_dau), set())
                thieu = tien_quyet[r.lop_hoc_phan.mon_hoc_id] - da_dat
                if thieu:
                    raise CommandError(f"SV {sv_id}: {r.lop_hoc_phan.ma_lop} thiếu tiên quyết {sorted(thieu)}.")
            theo_ky = defaultdict(list)
            for r in ds:
                theo_ky[r.lop_hoc_phan.hoc_ky_id].extend(r.lop_hoc_phan.lich_hoc.all())
            for lich in theo_ky.values():
                for a_i, a in enumerate(lich):
                    for b in lich[a_i + 1 :]:
                        if a.lop_hoc_phan_id != b.lop_hoc_phan_id and lich_trung(a, b):
                            raise CommandError(f"SV {sv_id}: trùng lịch {a.lop_hoc_phan.ma_lop} và {b.lop_hoc_phan.ma_lop}.")
