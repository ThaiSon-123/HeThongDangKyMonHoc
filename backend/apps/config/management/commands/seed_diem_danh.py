"""Nạp ĐIỂM DANH cho mọi lớp đã đóng có sinh viên: sinh buổi học bằng chính `dong_bo_buoi` của hệ thống, rồi điểm danh
từng sinh viên từng buổi (có mặt / vắng có phép / vắng không phép / đi trễ), cùng vài yêu cầu sửa điểm danh đã xử lý.

Phần lớn sinh viên chuyên cần (vắng không phép ~3–6%); mỗi ngành 2 sinh viên học yếu hay vắng (~14%) và ~7% sinh viên
vắng nhiều (~26%) để có ca vượt ngưỡng cảnh báo vắng. Chạy lại an toàn (xoá điểm danh cũ của các lớp này, kết quả cố định).
Chạy SAU seed_lich_su_hoc_tap.
"""

import random
from collections import Counter
from datetime import datetime, timedelta

from django.core.management.base import BaseCommand, CommandError
from django.db import transaction
from django.utils import timezone

from apps.attendance.models import (
    Attendance,
    AttendanceRequest,
    AttendanceSession,
    TrangThaiDiemDanh,
    TrangThaiSession,
)
from apps.attendance.services import chi_so_vang, dong_bo_buoi
from apps.registration.models import Registration, TrangThaiDangKy
from apps.training.models import ClassSection, TrangThaiDon, TrangThaiHocKy

SEED = 2029
LY_DO = ["Ốm, có giấy khám bệnh", "Đi thi chứng chỉ ngoại ngữ", "Việc gia đình đột xuất", "Trùng lịch thực tập"]


def xac_suat_vang(ma_sv):
    """Xác suất vắng không phép của một sinh viên — cố định theo mã số."""
    if int(ma_sv[-3:]) >= 19:  # 2 sinh viên cuối mỗi ngành: học yếu
        return 0.14
    r = random.Random(SEED + int(ma_sv)).random()
    return 0.26 if r < 0.07 else 0.03 + r * 0.03


def nua_dem(ngay):
    return timezone.make_aware(datetime.combine(ngay, datetime.min.time()))


class Command(BaseCommand):
    help = "Nạp điểm danh cho mọi lớp đã đóng có sinh viên đăng ký."

    @transaction.atomic
    def handle(self, *args, **options):
        lops = list(
            ClassSection.objects.filter(
                hoc_ky__trang_thai=TrangThaiHocKy.DONG, dang_ky__trang_thai=TrangThaiDangKy.DA_DANG_KY
            )
            .distinct()
            .select_related("hoc_ky", "giao_vien__user")
            .order_by("id")
        )
        if not lops:
            raise CommandError("Chưa có đăng ký ở kỳ đã đóng — chạy seed_lich_su_hoc_tap trước.")
        AttendanceRequest.objects.filter(attendance__lop_hoc_phan__in=lops).delete()
        Attendance.objects.filter(lop_hoc_phan__in=lops).delete()
        AttendanceSession.objects.filter(lop_hoc_phan__in=lops).delete()

        for lop in lops:
            dong_bo_buoi(lop, hom_nay=lop.hoc_ky.ngay_ket_thuc)  # sinh buổi theo lịch lớp
        AttendanceSession.objects.filter(lop_hoc_phan__in=lops).update(trang_thai=TrangThaiSession.DA_DIEM_DANH)

        sv_cua_lop, ma_sv = {}, {}
        dang_ky = Registration.objects.filter(lop_hoc_phan__in=lops, trang_thai=TrangThaiDangKy.DA_DANG_KY)
        for r in dang_ky.select_related("sinh_vien__sinh_vien").order_by("sinh_vien_id"):
            sv_cua_lop.setdefault(r.lop_hoc_phan_id, []).append(r.sinh_vien_id)
            ma_sv[r.sinh_vien_id] = r.sinh_vien.sinh_vien.ma_sv
        p_vang = {sv: xac_suat_vang(ma) for sv, ma in ma_sv.items()}

        rng = random.Random(SEED)
        diem_danh = []
        buoi = AttendanceSession.objects.filter(lop_hoc_phan__in=lops).order_by("lop_hoc_phan_id", "ngay_hoc", "buoi")
        for s in buoi:
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
                        attendance_session=s, lop_hoc_phan_id=s.lop_hoc_phan_id, ngay_hoc=s.ngay_hoc,
                        sinh_vien_id=sv, trang_thai=tt, di_tre=tre,
                    )
                )
        Attendance.objects.bulk_create(diem_danh, batch_size=5000)
        for hk in {lop.hoc_ky for lop in lops}:
            Attendance.objects.filter(lop_hoc_phan__hoc_ky=hk).update(cap_nhat_luc=nua_dem(hk.ngay_ket_thuc))

        so_yc = self._yeu_cau(rng, lops)
        self._tom_tat(lops, so_yc)

    def _yeu_cau(self, rng, lops):
        """20 yêu cầu sửa điểm danh đã xử lý ở kỳ đóng gần nhất có điểm danh: 16 duyệt (→ vắng có phép), 4 từ chối."""
        hk_cuoi = max((lop.hoc_ky for lop in lops), key=lambda h: h.ngay_bat_dau)
        lop_cua = {lop.id: lop for lop in lops}
        ung_vien = list(
            Attendance.objects.filter(
                lop_hoc_phan__hoc_ky=hk_cuoi, trang_thai=TrangThaiDiemDanh.VANG_KHONG_PHEP
            ).order_by("id")
        )
        rng.shuffle(ung_vien)
        so = 0
        for n, a in enumerate(ung_vien[:20]):
            duyet = n % 5 != 4
            ngay_gui = nua_dem(a.ngay_hoc) + timedelta(days=1)
            yc = AttendanceRequest.objects.create(
                attendance=a,
                sinh_vien_id=a.sinh_vien_id,
                ly_do=rng.choice(LY_DO),
                trang_thai_mong_muon=TrangThaiDiemDanh.VANG_CO_PHEP,
                trang_thai=TrangThaiDon.DUYET if duyet else TrangThaiDon.TU_CHOI,
                nguoi_duyet=lop_cua[a.lop_hoc_phan_id].giao_vien.user,
                ngay_duyet=ngay_gui + timedelta(days=2),
                ghi_chu="Đã xác nhận minh chứng." if duyet else "Không có minh chứng hợp lệ.",
            )
            AttendanceRequest.objects.filter(pk=yc.pk).update(ngay_gui=ngay_gui)  # bỏ auto_now_add
            if duyet:
                Attendance.objects.filter(pk=a.pk).update(trang_thai=TrangThaiDiemDanh.VANG_CO_PHEP)
            so += 1
        return so

    def _tom_tat(self, lops, so_yc):
        tong_buoi = Counter(AttendanceSession.objects.filter(lop_hoc_phan__in=lops).values_list("lop_hoc_phan_id", flat=True))
        vang_kp = Counter(
            Attendance.objects.filter(lop_hoc_phan__in=lops, trang_thai=TrangThaiDiemDanh.VANG_KHONG_PHEP)
            .values_list("lop_hoc_phan_id", "sinh_vien_id")
        )
        cap = set(Attendance.objects.filter(lop_hoc_phan__in=lops).values_list("lop_hoc_phan_id", "sinh_vien_id"))
        canh_bao = sum(1 for lop_id, sv in cap if chi_so_vang(tong_buoi[lop_id], vang_kp[(lop_id, sv)])["canh_bao_vang"])
        self.stdout.write(
            f"{len(lops)} lớp, {sum(tong_buoi.values())} buổi, {Attendance.objects.filter(lop_hoc_phan__in=lops).count()} "
            f"dòng điểm danh, {so_yc} yêu cầu sửa; {canh_bao}/{len(cap)} cặp (sinh viên, lớp) vượt ngưỡng vắng cảnh báo."
        )
