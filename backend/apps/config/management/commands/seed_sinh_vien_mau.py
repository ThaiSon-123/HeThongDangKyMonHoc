"""Làm đầy dữ liệu cho MỘT sinh viên để demo: đổi họ tên; lịch sử học tập ở mọi học kỳ ĐÃ ĐÓNG (đăng ký + điểm đã
khóa, học lực Giỏi, học phí kỳ cũ đã thu đủ); điểm danh kỳ cũ và các buổi đã điểm danh của kỳ hiện tại (có mặt, đi trễ,
vắng có phép kèm đơn đã duyệt, rất ít vắng không phép). Đăng ký và học phí kỳ hiện tại giữ nguyên — CHƯA đóng.

Môn sinh viên đang học ở kỳ hiện tại không xếp vào kỳ cũ (mỗi môn một lần). Các môn `--mon-truot` bị điểm F (để có
môn cần học lại và môn sau "chưa đủ tiên quyết" khi đăng ký); GPA vẫn phải ở khoảng Giỏi. Chạy lại an toàn (xóa dữ liệu kỳ cũ +
điểm danh của sinh viên rồi sinh lại, kết quả cố định). Chạy SAU seed_lich_su_hoc_tap và seed_diem_danh.

    python manage.py seed_sinh_vien_mau --ma-sv 2324801030030 --ho-ten "Võ Thái Sơn" --mon-truot LING189
"""

import random
from collections import Counter, defaultdict
from datetime import timedelta
from decimal import Decimal

from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from apps.attendance.models import (
    Attendance,
    AttendanceRequest,
    AttendanceSession,
    TrangThaiDiemDanh,
    TrangThaiSession,
)
from apps.attendance.services import dong_bo_buoi
from apps.auth.models import Role
from apps.config.management.commands.seed_diem_danh import LY_DO, nua_dem
from apps.config.management.commands.seed_lich_su_hoc_tap import (
    SO_TKB,
    TIN_CHI_TOI_DA_KY,
    tao_diem,
)
from apps.config.management.commands.seed_lop_hoc_phan import doc_nhom
from apps.grades.models import Grade, TrangThaiDiem
from apps.grades.services import cap_nhat_ho_so, tinh_tong_ket, xep_loai_diem
from apps.profiles.models import StudentProfile
from apps.profiles.services import xep_loai
from apps.registration.models import Registration, TrangThaiDangKy
from apps.training.models import (
    ClassSection,
    Course,
    CurriculumCourse,
    LoaiMon,
    Prerequisite,
    Semester,
    TrangThaiDon,
    TrangThaiHocKy,
)
from apps.tuition.models import LoaiThanhToan, Payment, PhuongThuc, Tuition
from apps.tuition.services import dan_xuat_cua, tinh_hoc_phi

D = Decimal
SEED = 2030
GIOI = (D("3.20"), D("3.60"))  # GPA thang 4 xếp loại Giỏi (BR-25f)


class Command(BaseCommand):
    help = "Làm đầy dữ liệu (lịch sử học tập loại Giỏi, điểm danh, học phí kỳ hiện tại chưa đóng) cho một sinh viên."

    def add_arguments(self, parser):
        parser.add_argument("--ma-sv", default="2324801030030")
        parser.add_argument("--ho-ten", default="Võ Thái Sơn")
        parser.add_argument(
            "--mon-truot", default="LING189", help="Mã môn bị điểm F, cách nhau dấu phẩy"
        )

    @transaction.atomic
    def handle(self, *args, ma_sv, ho_ten, mon_truot, **options):
        ho_so = (
            StudentProfile.objects.select_related("user", "nganh", "ctdt")
            .filter(ma_sv=ma_sv)
            .first()
        )
        if ho_so is None:
            raise CommandError(f"Không có sinh viên {ma_sv}.")
        sv = ho_so.user
        admin = get_user_model().objects.filter(role=Role.ADMIN).order_by("id").first()
        if admin is None:
            raise CommandError("Cần một tài khoản ADMIN để ghi người thu học phí.")
        ho_so.ho_ten = ho_ten
        ho_so.save(update_fields=["ho_ten"])
        sv.first_name = ho_ten
        sv.save(update_fields=["first_name"])

        hoc_ky_dong = list(
            Semester.objects.filter(trang_thai=TrangThaiHocKy.DONG).order_by("ngay_bat_dau")
        )
        lop_anh_huong = self._xoa_cu(sv, hoc_ky_dong)
        truot = {m.strip() for m in mon_truot.split(",") if m.strip()}
        lops = self._lich_su(sv, ho_so, hoc_ky_dong, truot)
        lop_anh_huong |= {lop.id for lop in lops}
        for lop_id in lop_anh_huong:  # sĩ số = số đăng ký còn hiệu lực
            ClassSection.objects.filter(id=lop_id).update(
                si_so_hien_tai=Registration.objects.filter(
                    lop_hoc_phan_id=lop_id, trang_thai=TrangThaiDangKy.DA_DANG_KY
                ).count()
            )
        self._hoc_phi_ky_cu(sv, admin, hoc_ky_dong)
        tong = cap_nhat_ho_so(sv)
        if tong["gpa"] is None or not GIOI[0] <= tong["gpa"] < GIOI[1]:
            raise CommandError(f"GPA {tong['gpa']} không thuộc loại Giỏi.")
        diem_danh = self._diem_danh(sv)
        self._tom_tat(sv, tong, len(lops), diem_danh)

    def _xoa_cu(self, sv, hoc_ky_dong):
        cu = Registration.objects.filter(sinh_vien=sv, lop_hoc_phan__hoc_ky__in=hoc_ky_dong)
        lop_cu = set(cu.values_list("lop_hoc_phan_id", flat=True))
        Payment.objects.filter(tuition__sinh_vien=sv, tuition__hoc_ky__in=hoc_ky_dong).delete()
        Tuition.objects.filter(sinh_vien=sv, hoc_ky__in=hoc_ky_dong).delete()
        Grade.objects.filter(sinh_vien=sv, lop_hoc_phan__hoc_ky__in=hoc_ky_dong).delete()
        AttendanceRequest.objects.filter(sinh_vien=sv).delete()
        Attendance.objects.filter(sinh_vien=sv).delete()
        cu.delete()
        return lop_cu

    def _lich_su(self, sv, ho_so, hoc_ky_dong, truot):
        """Như seed_lich_su_hoc_tap cho một sinh viên; thử năng lực/seed tới khi GPA rơi vào khoảng Giỏi."""
        nhom = doc_nhom()
        ma_nganh = ho_so.nganh.ma_nganh
        mon_theo_ma = {c.ma_mon: c for c in Course.objects.all()}
        tien_quyet = defaultdict(set)
        for mon_id, tq_id in Prerequisite.objects.values_list("mon_hoc_id", "mon_tien_quyet_id"):
            tien_quyet[mon_id].add(tq_id)
        loai_mon = dict(
            CurriculumCourse.objects.filter(ctdt=ho_so.ctdt).values_list("mon_hoc_id", "loai_mon")
        )
        dang_hoc = set(
            Registration.objects.filter(
                sinh_vien=sv, trang_thai=TrangThaiDangKy.DA_DANG_KY
            ).values_list("lop_hoc_phan__mon_hoc_id", flat=True)
        )
        lop_theo = {}
        for lop in ClassSection.objects.filter(hoc_ky__in=hoc_ky_dong).select_related("mon_hoc"):
            lop_theo[(lop.hoc_ky_id, lop.mon_hoc.ma_mon, lop.ma_lop.split(".L")[1][:2])] = lop
        lane = f"{int(ho_so.ma_sv) % SO_TKB + 1:02d}"  # mọi môn cùng "lớp thứ j" → không trùng lịch

        can_hoc = {m for m, loai in loai_mon.items() if loai == LoaiMon.BAT_BUOC}
        cho = list(can_hoc)
        while cho:
            for tq in tien_quyet[cho.pop()]:
                if tq in loai_mon and tq not in can_hoc:
                    can_hoc.add(tq)
                    cho.append(tq)
        can_hoc -= dang_hoc

        for lan in range(200):
            rng = random.Random(SEED + int(ho_so.ma_sv) + lan)
            nang_luc = rng.uniform(8.0, 8.8)
            ket_qua, da_dat = [], set()
            for hk in hoc_ky_dong:
                ds_ma = nhom.get(hk.ten_hk, {}).get(ma_nganh)
                if not ds_ma:
                    continue
                mon_ky = [mon_theo_ma[m] for m in ds_ma if mon_theo_ma[m].id not in dang_hoc]
                chon = [m for m in mon_ky if m.id in can_hoc and tien_quyet[m.id] <= da_dat]
                tin_chi = sum(m.tong_tin_chi for m in chon)
                muc_tieu = rng.randint(16, 20)
                tu_chon = [m for m in mon_ky if m.id not in can_hoc and tien_quyet[m.id] <= da_dat]
                rng.shuffle(tu_chon)
                for m in tu_chon:
                    if tin_chi >= muc_tieu:
                        break
                    if tin_chi + m.tong_tin_chi <= TIN_CHI_TOI_DA_KY:
                        chon.append(m)
                        tin_chi += m.tong_tin_chi
                for m in chon:
                    if m.ma_mon in truot:  # bỏ thi cuối kỳ → F, môn sau cần nó chưa đủ tiên quyết
                        qt, gk, ck = D("7.0"), D("3.0"), D("2.0")
                        tong = tinh_tong_ket(qt, gk, ck)
                    else:  # SV giỏi: các môn khác không trượt
                        qt, gk, ck, tong = tao_diem(rng, nang_luc, True)
                    chu, gpa = xep_loai_diem(tong, m.loai_danh_gia)
                    ket_qua.append(
                        (lop_theo[(hk.id, m.ma_mon, lane)], m, qt, gk, ck, tong, chu, gpa)
                    )
                    if chu != "F":
                        da_dat.add(m.id)
            co_gpa = [(gpa, m.tong_tin_chi) for _, m, *_r, gpa in ket_qua if gpa is not None]
            mau = sum(tc for _, tc in co_gpa)
            if mau and GIOI[0] + D("0.05") <= sum(g * tc for g, tc in co_gpa) / mau < GIOI[1] - D(
                "0.05"
            ):
                break
        else:
            raise CommandError("Không sinh được bộ điểm loại Giỏi.")

        Registration.objects.bulk_create(
            Registration(sinh_vien=sv, lop_hoc_phan=lop) for lop, *_ in ket_qua
        )
        Grade.objects.bulk_create(
            Grade(
                lop_hoc_phan=lop,
                sinh_vien=sv,
                diem_qua_trinh=qt,
                diem_giua_ky=gk,
                diem_cuoi_ky=ck,
                diem_tong_ket=tong,
                diem_chu=chu,
                gpa_thang_4=gpa,
                trang_thai=TrangThaiDiem.KHOA,
            )
            for lop, _m, qt, gk, ck, tong, chu, gpa in ket_qua
        )
        for hk in hoc_ky_dong:  # ngày giả lập theo học kỳ (auto_now_add ghi ngày chạy lệnh)
            Registration.objects.filter(sinh_vien=sv, lop_hoc_phan__hoc_ky=hk).update(
                ngay_dang_ky=hk.cua_so_dk_bat_dau + timedelta(days=1)
            )
            Grade.objects.filter(sinh_vien=sv, lop_hoc_phan__hoc_ky=hk).update(
                ngay_nhap=nua_dem(hk.ngay_ket_thuc) + timedelta(days=3)
            )
        return [lop for lop, *_ in ket_qua]

    def _hoc_phi_ky_cu(self, sv, admin, hoc_ky_dong):
        """Kỳ cũ: tính học phí và thu đủ. Kỳ hiện tại không động tới (vẫn còn nợ)."""
        for hk in hoc_ky_dong:
            if not Registration.objects.filter(sinh_vien=sv, lop_hoc_phan__hoc_ky=hk).exists():
                continue
            t = tinh_hoc_phi(sv, hk)
            if t.tong_tien > 0:
                p = Payment.objects.create(
                    tuition=t,
                    loai=LoaiThanhToan.THU,
                    so_tien=t.tong_tien,
                    phuong_thuc=PhuongThuc.CHUYEN_KHOAN,
                    nguoi_thu=admin,
                    bien_lai_ma=f"BL{t.id:06d}",
                )
                Payment.objects.filter(pk=p.pk).update(
                    ngay=hk.cua_so_dk_ket_thuc + timedelta(days=5)
                )

    def _diem_danh(self, sv):
        """Mọi buổi đã điểm danh của các lớp sinh viên học: chủ yếu có mặt, ~5% vắng có phép (kèm đơn đã duyệt),
        ~1.5% vắng không phép, ~5% đi trễ."""
        lops = list(
            ClassSection.objects.filter(
                dang_ky__sinh_vien=sv, dang_ky__trang_thai=TrangThaiDangKy.DA_DANG_KY
            )
            .select_related("hoc_ky", "giao_vien__user")
            .distinct()
        )
        for (
            lop
        ) in lops:  # lớp kỳ cũ chưa có buổi (chưa ai học lane này) → sinh buổi như seed_diem_danh
            if lop.hoc_ky.trang_thai == TrangThaiHocKy.DONG and not lop.buoi_diem_danh.exists():
                dong_bo_buoi(lop, hom_nay=lop.hoc_ky.ngay_ket_thuc)
                lop.buoi_diem_danh.update(trang_thai=TrangThaiSession.DA_DIEM_DANH)
        rng = random.Random(SEED + int(sv.username))
        dong = []
        buoi = AttendanceSession.objects.filter(
            lop_hoc_phan__in=lops, trang_thai=TrangThaiSession.DA_DIEM_DANH
        ).order_by("lop_hoc_phan_id", "ngay_hoc", "buoi")
        for s in buoi:
            x = rng.random()
            if x < 0.015:
                tt, tre = TrangThaiDiemDanh.VANG_KHONG_PHEP, False
            elif x < 0.065:
                tt, tre = TrangThaiDiemDanh.VANG_CO_PHEP, False
            else:
                tt, tre = TrangThaiDiemDanh.CO_MAT, rng.random() < 0.05
            dong.append(
                Attendance(
                    attendance_session=s,
                    lop_hoc_phan_id=s.lop_hoc_phan_id,
                    ngay_hoc=s.ngay_hoc,
                    sinh_vien=sv,
                    trang_thai=tt,
                    di_tre=tre,
                )
            )
        Attendance.objects.bulk_create(dong)
        gv_cua = {lop.id: lop.giao_vien.user for lop in lops}
        for a in Attendance.objects.filter(sinh_vien=sv, trang_thai=TrangThaiDiemDanh.VANG_CO_PHEP):
            ngay_gui = nua_dem(a.ngay_hoc) + timedelta(days=1)
            yc = AttendanceRequest.objects.create(
                attendance=a,
                sinh_vien=sv,
                ly_do=rng.choice(LY_DO),
                trang_thai_mong_muon=TrangThaiDiemDanh.VANG_CO_PHEP,
                trang_thai=TrangThaiDon.DUYET,
                nguoi_duyet=gv_cua[a.lop_hoc_phan_id],
                ngay_duyet=ngay_gui + timedelta(days=2),
                ghi_chu="Đã xác nhận minh chứng.",
            )
            AttendanceRequest.objects.filter(pk=yc.pk).update(ngay_gui=ngay_gui)  # bỏ auto_now_add
        for lop in lops:
            if lop.hoc_ky.trang_thai == TrangThaiHocKy.DONG:
                Attendance.objects.filter(sinh_vien=sv, lop_hoc_phan=lop).update(
                    cap_nhat_luc=nua_dem(lop.hoc_ky.ngay_ket_thuc)
                )
        return Counter("đi trễ" if a.di_tre else a.get_trang_thai_display().lower() for a in dong)

    def _tom_tat(self, sv, tong, so_lop_cu, diem_danh):
        ho_so = StudentProfile.objects.get(user=sv)
        self.stdout.write(
            f"{ho_so.ma_sv} {ho_so.ho_ten}: {so_lop_cu} môn ở các kỳ đã đóng, GPA {tong['gpa']} "
            f"({xep_loai(tong['gpa'])}), {tong['tin_chi_tich_luy']} tín chỉ tích lũy."
        )
        self.stdout.write(
            "Điểm danh: " + ", ".join(f"{k} {v}" for k, v in diem_danh.most_common()) + "."
        )
        for t in (
            Tuition.objects.filter(sinh_vien=sv)
            .select_related("hoc_ky")
            .exclude(hoc_ky__trang_thai=TrangThaiHocKy.DONG)
        ):
            self.stdout.write(
                f"Học phí {t.hoc_ky.ten_hk}: còn nợ {dan_xuat_cua(t)['con_no']:,.0f} ₫ (chưa đóng)."
            )
