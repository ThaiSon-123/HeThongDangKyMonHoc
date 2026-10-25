"""Nạp ĐĂNG KÝ + SĨ SỐ + HỌC PHÍ + ĐIỂM DANH cho học kỳ ĐANG MỞ (hiện tại), nối tiếp lịch sử học tập đã nạp.

Đồng bộ với dữ liệu sẵn có:
  - sinh viên thứ i của ngành chọn "lớp thứ (i mod 3)" của mọi môn (giống seed_lich_su_hoc_tap) → không trùng lịch;
  - chỉ đăng ký môn khi đã ĐẠT mọi môn tiên quyết (điểm KHÓA ở các kỳ trước), tối đa 24 tín chỉ;
  - 4 sinh viên cuối mỗi ngành (kể cả 2 sinh viên học yếu) để trống để thử luồng đăng ký;
  - sĩ số lớp = số đăng ký thật; lớp có sinh viên chuyển sang ĐANG HỌC (lớp trống vẫn MỞ); học phí tính bằng `tinh_hoc_phi` theo bảng giá kỳ này; một phần đã thu, một phần còn nợ;
  - buổi học sinh bằng `dong_bo_buoi`; các buổi TRƯỚC hôm nay của lớp có sinh viên đã điểm danh, buổi hôm nay/sau còn mở.
Chạy SAU seed_lich_su_hoc_tap, seed_diem_danh, seed_hoc_phi. Chạy lại an toàn (xoá phần của học kỳ này rồi nạp lại).
"""

import random
from collections import defaultdict
from datetime import timedelta
from decimal import Decimal

from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction
from django.db.models import Count
from django.utils import timezone

from apps.attendance.models import (
    Attendance,
    AttendanceRequest,
    AttendanceSession,
    TrangThaiDiemDanh,
    TrangThaiSession,
)
from apps.attendance.services import dong_bo_buoi
from apps.auth.models import Role
from apps.config.management.commands.seed_diem_danh import nua_dem, xac_suat_vang
from apps.config.management.commands.seed_lop_hoc_phan import doc_nhom
from apps.grades.models import Grade
from apps.registration.models import Registration, TrangThaiDangKy
from apps.registration.services import lich_trung
from apps.training.models import (
    ClassSection,
    Course,
    CurriculumCourse,
    LoaiMon,
    Prerequisite,
    Semester,
    TrangThaiDon,
    TrangThaiHocKy,
    TrangThaiLop,
)
from apps.tuition.models import LoaiThanhToan, Payment, PhuongThuc, Tuition
from apps.tuition.services import ma_bien_lai, tinh_hoc_phi

D = Decimal
SEED = 2030
SO_TKB = 3
TIN_CHI_TOI_DA_KY = 24
SO_DANG_KY_MOI_NGANH = 16  # sinh viên thứ 0..15 của mỗi ngành; 4 người cuối để trống
LY_DO = [
    "Ốm, có giấy khám bệnh",
    "Đi thi chứng chỉ ngoại ngữ",
    "Việc gia đình đột xuất",
    "Trùng lịch thực tập",
]


class Command(BaseCommand):
    help = "Nạp đăng ký, học phí và điểm danh cho học kỳ đang mở."

    @transaction.atomic
    def handle(self, *args, **options):
        User = get_user_model()
        hom_nay = timezone.localdate()
        bay_gio = timezone.now()
        nhom = doc_nhom()
        hk = (
            Semester.objects.filter(trang_thai=TrangThaiHocKy.MO, ten_hk__in=list(nhom))
            .order_by("-ngay_bat_dau")
            .first()
        )
        if hk is None:
            raise CommandError(
                "Không có học kỳ đang mở có trong CTĐT — chạy seed_hoc_ky + seed_lop_hoc_phan trước."
            )
        svs = list(
            User.objects.filter(role=Role.SINH_VIEN, sinh_vien__ma_sv__regex=r"^\d{13}$")
            .select_related("sinh_vien__nganh")
            .order_by("sinh_vien__ma_sv")
        )
        if not svs or not Grade.objects.filter(sinh_vien__in=svs).exists():
            raise CommandError("Chưa có lịch sử học tập — chạy seed_lich_su_hoc_tap trước.")
        admin = User.objects.filter(role=Role.ADMIN).order_by("id").first()
        if admin is None:
            raise CommandError("Cần một tài khoản ADMIN để ghi người thu học phí.")
        lops = list(
            ClassSection.objects.filter(hoc_ky=hk).select_related("mon_hoc", "giao_vien__user")
        )
        if not lops:
            raise CommandError(f"{hk.ten_hk} chưa có lớp học phần — chạy seed_lop_hoc_phan trước.")

        self._xoa_cu(hk, lops)

        mon_theo_ma = {c.ma_mon: c for c in Course.objects.all()}
        tien_quyet = defaultdict(set)
        for mon_id, tq_id in Prerequisite.objects.values_list("mon_hoc_id", "mon_tien_quyet_id"):
            tien_quyet[mon_id].add(tq_id)
        loai_mon = defaultdict(dict)
        for cc in CurriculumCourse.objects.all():
            loai_mon[cc.ctdt_id][cc.mon_hoc_id] = cc.loai_mon
        da_dat = defaultdict(set)  # sv_id → môn đã đạt (điểm khóa, khác F)
        for sv_id, mon_id in (
            Grade.objects.filter(sinh_vien__in=svs)
            .exclude(diem_chu="F")
            .values_list("sinh_vien_id", "lop_hoc_phan__mon_hoc_id")
        ):
            da_dat[sv_id].add(mon_id)
        lop_theo = {(lop.mon_hoc.ma_mon, lop.ma_lop.split(".L")[1][:2]): lop for lop in lops}

        chi_so_nganh = defaultdict(int)
        dang_ky, ngay_dk = [], {}
        cua_so = (hk.cua_so_dk_bat_dau, min(hk.cua_so_dk_ket_thuc, bay_gio))
        gio_dk = max(1, int((cua_so[1] - cua_so[0]).total_seconds() // 3600))
        for sv in svs:
            ho_so = sv.sinh_vien
            ma_nganh = ho_so.nganh.ma_nganh
            i = chi_so_nganh[ma_nganh]
            chi_so_nganh[ma_nganh] += 1
            if i >= SO_DANG_KY_MOI_NGANH:
                continue
            ds_ma = nhom[hk.ten_hk].get(ma_nganh, [])
            rng = random.Random(SEED + int(ho_so.ma_sv))
            lane = f"{i % SO_TKB + 1:02d}"
            can_hoc = {m for m, loai in loai_mon[ho_so.ctdt_id].items() if loai == LoaiMon.BAT_BUOC}
            cho = list(can_hoc)
            while cho:
                for tq in tien_quyet[cho.pop()]:
                    if tq in loai_mon[ho_so.ctdt_id] and tq not in can_hoc:
                        can_hoc.add(tq)
                        cho.append(tq)
            mon_ky = [mon_theo_ma[m] for m in ds_ma if mon_theo_ma[m].id not in da_dat[sv.id]]
            chon = [m for m in mon_ky if m.id in can_hoc and tien_quyet[m.id] <= da_dat[sv.id]]
            tin_chi = sum(m.tong_tin_chi for m in chon)
            muc_tieu = rng.randint(14, 20)
            tu_chon = [
                m for m in mon_ky if m.id not in can_hoc and tien_quyet[m.id] <= da_dat[sv.id]
            ]
            rng.shuffle(tu_chon)
            for m in tu_chon:
                if tin_chi >= muc_tieu:
                    break
                if tin_chi + m.tong_tin_chi <= TIN_CHI_TOI_DA_KY:
                    chon.append(m)
                    tin_chi += m.tong_tin_chi
            for m in chon:
                dang_ky.append(Registration(sinh_vien=sv, lop_hoc_phan=lop_theo[(m.ma_mon, lane)]))
            ngay_dk[sv.id] = cua_so[0] + timedelta(hours=rng.randint(1, gio_dk))
        Registration.objects.bulk_create(dang_ky)
        for (
            sv_id,
            ngay,
        ) in ngay_dk.items():  # auto_now_add ghi giờ chạy lệnh → đặt lại trong cửa sổ đăng ký
            Registration.objects.filter(sinh_vien_id=sv_id, lop_hoc_phan__hoc_ky=hk).update(
                ngay_dang_ky=ngay
            )
        for r in (
            Registration.objects.filter(lop_hoc_phan__hoc_ky=hk)
            .values("lop_hoc_phan_id")
            .annotate(n=Count("id"))
        ):
            ClassSection.objects.filter(pk=r["lop_hoc_phan_id"]).update(si_so_hien_tai=r["n"])
        # Lớp đã có sinh viên và đã tới ngày bắt đầu thì ĐANG HỌC (chỉ lớp đang học mới điểm danh / nhập điểm được);
        # lớp chưa có ai vẫn MỞ để sinh viên còn lại thử đăng ký.
        ClassSection.objects.filter(
            hoc_ky=hk, si_so_hien_tai__gt=0, trang_thai=TrangThaiLop.MO
        ).update(trang_thai=TrangThaiLop.DANG_HOC)

        so_no, so_du = self._hoc_phi(hk, svs, ngay_dk, admin, bay_gio)
        so_buoi, so_dd, so_yc = self._diem_danh(hk, lops, hom_nay)
        self._kiem_tra(hk)
        self.stdout.write(
            f"{hk.ten_hk}: {len(dang_ky)} đăng ký của {len(ngay_dk)} sinh viên; học phí: {so_du} đã đóng đủ, "
            f"{so_no} còn nợ; {so_buoi} buổi, {so_dd} dòng điểm danh, {so_yc} yêu cầu sửa. Kiểm tra: ĐẠT."
        )

    def _xoa_cu(self, hk, lops):
        AttendanceRequest.objects.filter(attendance__lop_hoc_phan__in=lops).delete()
        Attendance.objects.filter(lop_hoc_phan__in=lops).delete()
        AttendanceSession.objects.filter(lop_hoc_phan__in=lops).delete()
        Payment.objects.filter(tuition__hoc_ky=hk).delete()
        Tuition.objects.filter(hoc_ky=hk).delete()
        Registration.objects.filter(lop_hoc_phan__hoc_ky=hk).delete()
        ClassSection.objects.filter(hoc_ky=hk).update(si_so_hien_tai=0, trang_thai=TrangThaiLop.MO)

    def _hoc_phi(self, hk, svs, ngay_dk, admin, bay_gio):
        """Tính học phí theo đăng ký; ~50% đóng đủ, ~15% đóng một nửa, còn lại chưa đóng (hạn đóng còn xa)."""
        so_no = so_du = 0
        for sv in svs:
            if sv.id not in ngay_dk:
                continue
            rng = random.Random(SEED * 7 + sv.id)
            tuition = tinh_hoc_phi(sv, hk)
            x = rng.random()
            so_tien = (
                tuition.tong_tien
                if x < 0.5
                else (tuition.tong_tien / 2 // 1000) * 1000
                if x < 0.65
                else D(0)
            )
            if tuition.tong_tien <= 0 or so_tien <= 0:
                so_no += 1 if tuition.tong_tien > 0 else 0
                continue
            p = Payment.objects.create(
                tuition=tuition,
                loai=LoaiThanhToan.THU,
                so_tien=so_tien,
                phuong_thuc=rng.choice([PhuongThuc.CHUYEN_KHOAN, PhuongThuc.TIEN_MAT]),
                nguoi_thu=admin,
            )
            ngay = min(bay_gio, ngay_dk[sv.id] + timedelta(hours=rng.randint(2, 72)))
            Payment.objects.filter(pk=p.pk).update(ngay=ngay)
            p.refresh_from_db()
            Payment.objects.filter(pk=p.pk).update(bien_lai_ma=ma_bien_lai(p))
            if so_tien >= tuition.tong_tien:
                so_du += 1
            else:
                so_no += 1
        return so_no, so_du

    def _diem_danh(self, hk, lops, hom_nay):
        for lop in lops:
            dong_bo_buoi(lop, hom_nay=hom_nay)
        sv_cua_lop, ma_sv = defaultdict(list), {}
        dang_ky = Registration.objects.filter(
            lop_hoc_phan__in=lops, trang_thai=TrangThaiDangKy.DA_DANG_KY
        )
        for r in dang_ky.select_related("sinh_vien__sinh_vien").order_by("sinh_vien_id"):
            sv_cua_lop[r.lop_hoc_phan_id].append(r.sinh_vien_id)
            ma_sv[r.sinh_vien_id] = r.sinh_vien.sinh_vien.ma_sv
        p_vang = {sv: xac_suat_vang(ma) for sv, ma in ma_sv.items()}

        rng = random.Random(SEED)
        qua = AttendanceSession.objects.filter(
            lop_hoc_phan__in=[lop for lop in lops if sv_cua_lop[lop.id]], ngay_hoc__lt=hom_nay
        ).order_by("lop_hoc_phan_id", "ngay_hoc", "buoi")
        diem_danh = []
        for s in qua:
            for sv in sv_cua_lop[s.lop_hoc_phan_id]:
                x = rng.random()
                if x < p_vang[sv]:
                    tt, tre = TrangThaiDiemDanh.VANG_KHONG_PHEP, False
                elif x < p_vang[sv] + 0.04:
                    tt, tre = TrangThaiDiemDanh.VANG_CO_PHEP, False
                else:
                    tt, tre = TrangThaiDiemDanh.CO_MAT, rng.random() < 0.05
                diem_danh.append(
                    Attendance(
                        attendance_session=s,
                        lop_hoc_phan_id=s.lop_hoc_phan_id,
                        ngay_hoc=s.ngay_hoc,
                        sinh_vien_id=sv,
                        trang_thai=tt,
                        di_tre=tre,
                    )
                )
        Attendance.objects.bulk_create(diem_danh, batch_size=5000)
        qua.update(trang_thai=TrangThaiSession.DA_DIEM_DANH)
        for ngay in {
            a.ngay_hoc for a in diem_danh
        }:  # auto_now ghi giờ chạy lệnh → đặt lại tối hôm đó
            Attendance.objects.filter(lop_hoc_phan__in=lops, ngay_hoc=ngay).update(
                cap_nhat_luc=nua_dem(ngay) + timedelta(hours=21)
            )
        so_yc = self._yeu_cau(rng, lops, hom_nay)
        so_buoi = AttendanceSession.objects.filter(lop_hoc_phan__in=lops).count()
        return so_buoi, len(diem_danh), so_yc

    def _yeu_cau(self, rng, lops, hom_nay):
        """6 yêu cầu sửa điểm danh của buổi vắng không phép gần đây: 4 chờ duyệt, 1 đã duyệt, 1 từ chối."""
        lop_cua = {lop.id: lop for lop in lops}
        ung_vien = list(
            Attendance.objects.filter(
                lop_hoc_phan__in=lops, trang_thai=TrangThaiDiemDanh.VANG_KHONG_PHEP
            ).order_by("id")
        )
        rng.shuffle(ung_vien)
        trang_thai = [TrangThaiDon.CHO_DUYET] * 4 + [TrangThaiDon.DUYET, TrangThaiDon.TU_CHOI]
        so = 0
        for a, tt in zip(ung_vien, trang_thai, strict=False):
            ngay_gui = min(nua_dem(a.ngay_hoc) + timedelta(days=1), timezone.now())
            xu_ly = tt != TrangThaiDon.CHO_DUYET
            yc = AttendanceRequest.objects.create(
                attendance=a,
                sinh_vien_id=a.sinh_vien_id,
                ly_do=rng.choice(LY_DO),
                trang_thai_mong_muon=TrangThaiDiemDanh.VANG_CO_PHEP,
                trang_thai=tt,
                nguoi_duyet=lop_cua[a.lop_hoc_phan_id].giao_vien.user if xu_ly else None,
                ngay_duyet=ngay_gui + timedelta(hours=20) if xu_ly else None,
                ghi_chu=""
                if not xu_ly
                else "Đã xác nhận minh chứng."
                if tt == TrangThaiDon.DUYET
                else "Không có minh chứng hợp lệ.",
            )
            AttendanceRequest.objects.filter(pk=yc.pk).update(ngay_gui=ngay_gui)
            if tt == TrangThaiDon.DUYET:
                Attendance.objects.filter(pk=a.pk).update(trang_thai=TrangThaiDiemDanh.VANG_CO_PHEP)
            so += 1
        return so

    def _kiem_tra(self, hk):
        """Dò lại từ DB: không trùng lịch trong kỳ, sĩ số khớp đăng ký và không vượt tối đa, mỗi môn một lần."""
        theo_sv = defaultdict(list)
        for r in (
            Registration.objects.filter(lop_hoc_phan__hoc_ky=hk)
            .select_related("lop_hoc_phan")
            .prefetch_related("lop_hoc_phan__lich_hoc")
        ):
            theo_sv[r.sinh_vien_id].append(r.lop_hoc_phan)
        for sv_id, ds in theo_sv.items():
            if len({lop.mon_hoc_id for lop in ds}) != len(ds):
                raise CommandError(f"SV {sv_id}: đăng ký trùng môn.")
            lich = [s for lop in ds for s in lop.lich_hoc.all()]
            for a_i, a in enumerate(lich):
                for b in lich[a_i + 1 :]:
                    if a.lop_hoc_phan_id != b.lop_hoc_phan_id and lich_trung(a, b):
                        raise CommandError(
                            f"SV {sv_id}: trùng lịch giữa lớp {a.lop_hoc_phan_id} và {b.lop_hoc_phan_id}."
                        )
        for lop in ClassSection.objects.filter(hoc_ky=hk):
            n = lop.dang_ky.filter(trang_thai=TrangThaiDangKy.DA_DANG_KY).count()
            if lop.si_so_hien_tai != n or n > lop.si_so_toi_da:
                raise CommandError(
                    f"{lop.ma_lop}: sĩ số {lop.si_so_hien_tai} ≠ {n} đăng ký hoặc vượt {lop.si_so_toi_da}."
                )
