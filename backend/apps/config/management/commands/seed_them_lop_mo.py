"""Thêm lớp MỞ cho một học kỳ để mỗi môn đang có lớp mở có ít nhất N lớp mở (mặc định 6).

Dùng để thử "TKB tự động" với nhiều lựa chọn. Chỉ THÊM: không sửa/xóa lớp, lịch hay đăng ký có sẵn.
Chỉ xét môn đang có ≥ 1 lớp ở trạng thái MO trong kỳ (môn chỉ có lớp đang học/đã đóng giữ nguyên).
Lớp mới có giảng viên cùng khoa với môn (ưu tiên người chưa dạy môn này trong kỳ, ít lớp nhất), phòng
và khung giờ không trùng với bất kỳ lớp nào của kỳ; hai lớp cùng môn không cùng khung giờ.
Chạy lại an toàn: môn đã đủ lớp thì không thêm.
"""

import re
from collections import Counter, defaultdict
from datetime import timedelta

from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from apps.config.management.commands.seed_lop_hoc_phan import (
    PHONG_LY_THUYET,
    PHONG_THUC_HANH,
    cac_buoi_hoc,
    giao,
    ung_vien,
)
from apps.profiles.models import TeacherProfile
from apps.training.models import ClassSection, Schedule, Semester, TrangThaiLop
from apps.training.services import hoc_ky_mac_dinh

SO_LOP_MAC_DINH = 6
SO_THU_TU = re.compile(r"\.L(\d+)")


def ma_lop_moi(mau, ma_mon, n, hoc_ky_id):
    """Mã lớp theo đúng dạng của lớp có sẵn (`<mã môn>.L<nn>-<hậu tố>`); lạ dạng thì dùng hậu tố là id kỳ."""
    hau_to = mau.partition("-")[2] or str(hoc_ky_id)
    return f"{ma_mon}.L{n:02d}-{hau_to}"


class Command(BaseCommand):
    help = "Thêm lớp mở cho một học kỳ để mỗi môn đang mở có ít nhất N lớp (chỉ thêm, không sửa lớp có sẵn)."

    def add_arguments(self, parser):
        parser.add_argument("--hoc-ky", type=int, help="id học kỳ (mặc định: học kỳ hiện tại)")
        parser.add_argument(
            "--so-lop", type=int, default=SO_LOP_MAC_DINH, help="số lớp mở tối thiểu mỗi môn"
        )

    @transaction.atomic
    def handle(self, *args, **options):
        hk = (
            Semester.objects.filter(pk=options["hoc_ky"]).first()
            if options["hoc_ky"]
            else hoc_ky_mac_dinh()
        )
        if hk is None:
            raise CommandError("Không xác định được học kỳ.")
        so_lop = options["so_lop"]

        lop_ky = list(
            ClassSection.objects.filter(hoc_ky=hk)
            .select_related("mon_hoc")
            .prefetch_related("lich_hoc")
        )
        ma_da_co = {c.ma_lop for c in lop_ky}
        gv_ban, phong_ban = defaultdict(list), defaultdict(list)
        tai = Counter()
        gv_cua_mon, khung_cua_mon = defaultdict(set), defaultdict(set)
        mau_cua_mon, ds_mon = {}, {}
        for c in lop_ky:
            buoi = [(s.thu, s.tiet_bat_dau, s.tiet_ket_thuc) for s in c.lich_hoc.all()]
            gv_ban[c.giao_vien_id].extend(buoi)
            for s in c.lich_hoc.all():
                phong_ban[s.phong].append((s.thu, s.tiet_bat_dau, s.tiet_ket_thuc))
            tai[c.giao_vien_id] += 1
            gv_cua_mon[c.mon_hoc_id].add(c.giao_vien_id)
            khung_cua_mon[c.mon_hoc_id].add(tuple(sorted(buoi)))
            mau_cua_mon.setdefault(c.mon_hoc_id, c.ma_lop)
            ds_mon.setdefault(c.mon_hoc_id, c.mon_hoc)

        so_mo = Counter(c.mon_hoc_id for c in lop_ky if c.trang_thai == TrangThaiLop.MO)
        gv_theo_khoa = defaultdict(list)
        for g in TeacherProfile.objects.order_by("id"):
            gv_theo_khoa[g.khoa_id].append(g)

        them, bo_qua = 0, []
        for mon_id in sorted(so_mo, key=lambda m: ds_mon[m].ma_mon):
            mon = ds_mon[mon_id]
            do_dai = cac_buoi_hoc(mon)
            phong_ds = PHONG_THUC_HANH if mon.so_tiet_ly_thuyet == 0 else PHONG_LY_THUYET
            n = max(
                (
                    int(m.group(1))
                    for c in lop_ky
                    if c.mon_hoc_id == mon_id and (m := SO_THU_TU.search(c.ma_lop))
                ),
                default=0,
            )
            while so_mo[mon_id] < so_lop:
                n += 1
                while ma_lop_moi(mau_cua_mon[mon_id], mon.ma_mon, n, hk.id) in ma_da_co:
                    n += 1
                ket_qua = self._tim_cho(
                    mon,
                    do_dai,
                    n,
                    phong_ds,
                    gv_theo_khoa,
                    gv_ban,
                    phong_ban,
                    tai,
                    gv_cua_mon,
                    khung_cua_mon,
                )
                if ket_qua is None:
                    bo_qua.append(mon.ma_mon)
                    break
                gv, phong, buoi = ket_qua
                ma = ma_lop_moi(mau_cua_mon[mon_id], mon.ma_mon, n, hk.id)
                lop = ClassSection.objects.create(
                    ma_lop=ma,
                    mon_hoc=mon,
                    hoc_ky=hk,
                    giao_vien=gv,
                    si_so_toi_da=40 if mon.so_tiet_ly_thuyet == 0 else 60,
                    ngay_bat_dau=hk.ngay_bat_dau,
                    ngay_ket_thuc=hk.ngay_ket_thuc,
                    han_nhap_diem=hk.ngay_ket_thuc + timedelta(days=14),
                    trang_thai=TrangThaiLop.MO,
                )
                Schedule.objects.bulk_create(
                    Schedule(
                        lop_hoc_phan=lop,
                        thu=thu,
                        tiet_bat_dau=dau,
                        so_tiet_moi_buoi=cuoi - dau + 1,
                        phong=phong,
                    )
                    for thu, dau, cuoi in buoi
                )
                ma_da_co.add(ma)
                gv_ban[gv.id].extend(buoi)
                phong_ban[phong].extend(buoi)
                tai[gv.id] += 1
                gv_cua_mon[mon_id].add(gv.id)
                khung_cua_mon[mon_id].add(tuple(sorted(buoi)))
                so_mo[mon_id] += 1
                them += 1

        self._kiem_tra(hk)
        self.stdout.write(
            f"{hk.ten_hk}: thêm {them} lớp mở (mỗi môn đang mở có tối thiểu {so_lop} lớp trừ môn không xếp được)."
        )
        if bo_qua:
            self.stdout.write(f"Không xếp đủ lớp cho {len(bo_qua)} môn: {', '.join(bo_qua)}")

    @staticmethod
    def _tim_cho(
        mon, do_dai, n, phong_ds, gv_theo_khoa, gv_ban, phong_ban, tai, gv_cua_mon, khung_cua_mon
    ):
        """(giảng viên, phòng, [buổi]) đầu tiên hợp lệ cho lớp thứ n của môn, hoặc None."""
        ung_cu_vien = gv_theo_khoa[mon.khoa_id] or [g for ds in gv_theo_khoa.values() for g in ds]
        chua_day = [g for g in ung_cu_vien if g.id not in gv_cua_mon[mon.id]]
        # Ưu tiên người chưa dạy môn này; hết người mới thì cho dạy thêm lớp khác giờ.
        thu_tu_gv = sorted(chua_day, key=lambda g: (tai[g.id], g.id)) + sorted(
            (g for g in ung_cu_vien if g.id in gv_cua_mon[mon.id]), key=lambda g: (tai[g.id], g.id)
        )

        def ranh(ban, khoa, buoi):
            return not any(giao(b, x) for b in buoi for x in ban[khoa])

        for b1 in ung_vien(do_dai[0], n - 1, mon.ma_mon):
            if len(do_dai) == 1:
                kha_di = [[b1]]
            else:
                kha_di = [
                    [b1, b2] for b2 in ung_vien(do_dai[1], n - 1, mon.ma_mon) if b2[0] != b1[0]
                ]
            for buoi in kha_di:
                if tuple(sorted(buoi)) in khung_cua_mon[mon.id]:
                    continue
                gv = next((g for g in thu_tu_gv if ranh(gv_ban, g.id, buoi)), None)
                phong = next((p for p in phong_ds if ranh(phong_ban, p, buoi)), None)
                if gv and phong:
                    return gv, phong, buoi
        return None

    @staticmethod
    def _kiem_tra(hk):
        """Dò lại từ DB: GV hoặc phòng trùng giờ trong kỳ thì CommandError → rollback."""
        theo_gv, theo_phong = defaultdict(list), defaultdict(list)
        for s in Schedule.objects.filter(lop_hoc_phan__hoc_ky=hk).select_related("lop_hoc_phan"):
            buoi = (s.thu, s.tiet_bat_dau, s.tiet_ket_thuc)
            theo_gv[s.lop_hoc_phan.giao_vien_id].append((s.lop_hoc_phan.ma_lop, buoi))
            theo_phong[s.phong].append((s.lop_hoc_phan.ma_lop, buoi))
        for ten, nhom in (("giảng viên", theo_gv), ("phòng", theo_phong)):
            for khoa, cac in nhom.items():
                for i, (ma_a, a) in enumerate(cac):
                    for ma_b, b in cac[i + 1 :]:
                        if ma_a != ma_b and giao(a, b):
                            raise CommandError(f"{ten} {khoa} trùng giờ giữa {ma_a} và {ma_b}.")
