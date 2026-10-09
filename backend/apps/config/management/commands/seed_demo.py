"""Seed dữ liệu demo — plan.md mục 24 / checklist 1.5.

Idempotent: update_or_create toàn bộ, chạy lại an toàn.
Mật khẩu tài khoản demo lấy từ env `SEED_DEMO_PASSWORD`
(mặc định Demo@12345) và chỉ ghi ra console khi chạy.

Chạy:  python manage.py seed_demo
"""

import os
from datetime import date, datetime, timedelta, timezone as dt_timezone
from decimal import Decimal

from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand
from django.db import transaction
from django.utils import timezone

from apps.attendance.models import Attendance, AttendanceSession
from apps.auth.models import Role
from apps.config.models import SystemConfig
from apps.grades.models import Grade, TrangThaiDiem
from apps.profiles.models import StudentProfile, TeacherProfile
from apps.registration.models import LoaiDangKy, Registration, TrangThaiDangKy
from apps.training.models import (
    Buoi,
    ClassSection,
    Course,
    Curriculum,
    CurriculumCourse,
    KhoiKienThuc,
    LoaiMon,
    Major,
    Prerequisite,
    Schedule,
    Semester,
    TrangThaiDung,
    TrangThaiHocKy,
    TrangThaiLop,
)
from apps.tuition.models import HocPhanGia, TuitionConfig

MAT_KHAU_MAC_DINH = "Demo@12345"


class Command(BaseCommand):
    help = "Seed dữ liệu demo đầy đủ (checklist 1.5 / plan.md mục 24)"

    def handle(self, *args, **options):
        self.mat_khau = os.environ.get("SEED_DEMO_PASSWORD", MAT_KHAU_MAC_DINH)

        with transaction.atomic():
            dao_tao = self._seed_dao_tao()
            users = self._seed_users(
                dao_tao["nganh_cntt"], dao_tao["nganh_ktpm"],
                dao_tao["ctdt_cntt"], dao_tao["ctdt_ktpm"],
            )
            hk_dong, hk_mo = self._seed_hoc_ky()
            lops = self._seed_lop_hoc_phan(users["gv"], hk_mo, hk_dong, dao_tao["mons"])
            self._seed_bang_gia(hk_mo)
            self._seed_dang_ky_diem(users["sv"], lops, hk_mo)
            self._seed_diem_danh(users["sv"], lops["lop_dang_hoc"])
            self._seed_cau_hinh(hk_mo)

        self.stdout.write(self.style.SUCCESS("=" * 62))
        self.stdout.write(self.style.SUCCESS("Seed demo hoàn tất. Tài khoản / mật khẩu:"))
        self.stdout.write(f"  admin    / {self.mat_khau}   (Quản trị)")
        self.stdout.write(f"  pdt1-2   / {self.mat_khau}   (Phòng đào tạo)")
        self.stdout.write(f"  kt1-2    / {self.mat_khau}   (Kế toán)")
        self.stdout.write(f"  gv1-3    / {self.mat_khau}   (Giảng viên)")
        self.stdout.write(f"  sv01-10  / {self.mat_khau}   (Sinh viên)")
        self.stdout.write(self.style.SUCCESS("=" * 62))

    # ------------------------------------------------------------ tài khoản

    def _seed_users(self, nganh_cntt, nganh_ktpm, ctdt_cntt, ctdt_ktpm):
        User = get_user_model()

        def tao(username, role, ho_ten):
            user, _ = User.objects.update_or_create(
                username=username,
                defaults={
                    "role": role,
                    "first_name": ho_ten,
                    "is_locked": False,
                    "is_active": True,
                },
            )
            user.set_password(self.mat_khau)
            user.save(update_fields=["password"])
            return user

        tao("admin", Role.ADMIN, "Quản trị hệ thống")
        tao("pdt1", Role.PHONG_DAO_TAO, "Nguyễn Thị Phòng")
        tao("pdt2", Role.PHONG_DAO_TAO, "Trần Văn Đào")
        tao("kt1", Role.KE_TOAN, "Lê Thị Kế")
        tao("kt2", Role.KE_TOAN, "Phạm Văn Toán")

        gv = []
        for i, ten in enumerate(["Nguyễn Văn Bảy", "Trịnh Thị Thủy", "Đặng Văn Khoa"], 1):
            u = tao(f"gv{i}", Role.GIAO_VIEN, ten)
            TeacherProfile.objects.update_or_create(
                user=u,
                defaults={
                    "ma_gv": f"GV{i:05d}",
                    "ho_ten": ten,
                    "khoa_bo_mon": "Khoa Công nghệ thông tin",
                    "hoc_vi": "ThS",
                    "email": f"gv{i}@university.edu.vn",
                },
            )
            gv.append(u)

        ten_sv = [
            "Nguyễn Văn An", "Trần Thị Bích", "Lê Văn Cường", "Phạm Thị Dung",
            "Hoàng Văn Em", "Đỗ Thị Phương", "Vũ Văn Giang", "Bùi Thị Hạnh",
            "Đinh Văn Khanh", "Ngô Thị Loan",
        ]
        sv = []
        for i, ten in enumerate(ten_sv, 1):
            u = tao(f"sv{i:02d}", Role.SINH_VIEN, ten)
            nganh = nganh_cntt if i <= 5 else nganh_ktpm
            ctdt = ctdt_cntt if i <= 5 else ctdt_ktpm
            StudentProfile.objects.update_or_create(
                user=u,
                defaults={
                    "ma_sv": f"SV{i:05d}",
                    "ho_ten": ten,
                    "nganh": nganh,
                    "ctdt": ctdt,
                    "khoa_nhap_hoc": "K22",
                    "email": f"sv{i:02d}@university.edu.vn",
                },
            )
            sv.append(u)

        return {"gv": gv, "sv": sv}

    # ------------------------------------------------------- đào tạo (1.5.2)

    def _seed_dao_tao(self):
        nganh_cntt = Major.objects.update_or_create(
            ma_nganh="CNTT", defaults={"ten_nganh": "Công nghệ thông tin"}
        )[0]
        nganh_ktpm = Major.objects.update_or_create(
            ma_nganh="KTPM", defaults={"ten_nganh": "Kỹ thuật phần mềm"}
        )[0]

        ctdt_cntt = Curriculum.objects.update_or_create(
            ma_ctdt="CT-CNTT-K22",
            defaults={
                "nganh": nganh_cntt,
                "khoa_tuyen_sinh": "K22",
                "tong_tin_chi_yeu_cau": 145,
                "trang_thai": TrangThaiDung.HOAT_DONG,
            },
        )[0]
        ctdt_ktpm = Curriculum.objects.update_or_create(
            ma_ctdt="CT-KTPM-K22",
            defaults={
                "nganh": nganh_ktpm,
                "khoa_tuyen_sinh": "K22",
                "tong_tin_chi_yeu_cau": 145,
                "trang_thai": TrangThaiDung.HOAT_DONG,
            },
        )[0]

        # 8 môn: 6 bắt buộc (đủ 5 khối kiến thức) + 2 tự chọn.
        # 1 môn 12 tín chỉ (IT9000, "số gấp 4" so với môn 3 tín).
        # 1 môn loai_danh_gia = DAT_KHONG_DAT (IT4020).
        # 2 cặp tiên quyết: IT2010←IT1010, IT3010←IT2010.
        mons = {}
        for ma_mon, ten_mon, tc, tc_lt, tc_th, tiet_lt, tiet_th in [
            ("IT1010", "Nhập môn lập trình", 3, 2, 1, 30, 15),
            ("IT1020", "Toán rời rạc", 3, 3, 0, 45, 0),
            ("IT2010", "Cấu trúc dữ liệu", 3, 2, 1, 30, 15),
            ("IT2020", "Kiến trúc máy tính", 3, 3, 0, 45, 0),
            ("IT3010", "Lập trình hướng đối tượng", 3, 2, 1, 30, 15),
            ("IT9000", "Đồ án tốt nghiệp", 12, 6, 6, 90, 90),
            ("IT4010", "Trí tuệ nhân tạo", 3, 2, 1, 30, 15),
            ("IT4020", "Kỹ năng khởi nghiệp", 3, 3, 0, 45, 0),
        ]:
            mons[ma_mon] = Course.objects.update_or_create(
                ma_mon=ma_mon,
                defaults={
                    "ten_mon": ten_mon,
                    "tong_tin_chi": tc,
                    "tin_chi_ly_thuyet": tc_lt,
                    "tin_chi_thuc_hanh": tc_th,
                    "so_tiet_ly_thuyet": tiet_lt,
                    "so_tiet_thuc_hanh": tiet_th,
                    "loai_danh_gia": "DAT_KHONG_DAT" if ma_mon == "IT4020" else "DIEM",
                    "trang_thai": TrangThaiDung.HOAT_DONG,
                },
            )[0]

        Prerequisite.objects.update_or_create(
            mon_hoc=mons["IT2010"], defaults={"mon_tien_quyet": mons["IT1010"]}
        )
        Prerequisite.objects.update_or_create(
            mon_hoc=mons["IT3010"], defaults={"mon_tien_quyet": mons["IT2010"]}
        )

        # Gán 8 môn cho cả 2 CTĐT (5 khối: chung 2, co_so 2, chuyen_nganh 1,
        # tot_nghiep 1, tu_chon 2).
        phan_bo = [
            ("IT1010", KhoiKienThuc.CHUNG, LoaiMon.BAT_BUOC, 1),
            ("IT1020", KhoiKienThuc.CHUNG, LoaiMon.BAT_BUOC, 1),
            ("IT2010", KhoiKienThuc.CO_SO_NGANH, LoaiMon.BAT_BUOC, 2),
            ("IT2020", KhoiKienThuc.CO_SO_NGANH, LoaiMon.BAT_BUOC, 2),
            ("IT3010", KhoiKienThuc.CHUYEN_NGANH, LoaiMon.BAT_BUOC, 3),
            ("IT9000", KhoiKienThuc.TOT_NGHIEP, LoaiMon.BAT_BUOC, 8),
            ("IT4010", KhoiKienThuc.TU_CHON, LoaiMon.TU_CHON, 4),
            ("IT4020", KhoiKienThuc.TU_CHON, LoaiMon.TU_CHON, 4),
        ]
        for ctdt in (ctdt_cntt, ctdt_ktpm):
            for ma_mon, khoi, loai, hk_goi_y in phan_bo:
                CurriculumCourse.objects.update_or_create(
                    ctdt=ctdt,
                    mon_hoc=mons[ma_mon],
                    defaults={
                        "khoi_kien_thuc": khoi,
                        "loai_mon": loai,
                        "hoc_ky_goi_y": hk_goi_y,
                    },
                )

        return {
            "mons": mons,
            "nganh_cntt": nganh_cntt,
            "nganh_ktpm": nganh_ktpm,
            "ctdt_cntt": ctdt_cntt,
            "ctdt_ktpm": ctdt_ktpm,
        }

    # ------------------------------------------------------------ học kỳ

    def _seed_hoc_ky(self):
        """1 HK trước đã đóng (có điểm KHOA) + HK hiện tại mở, cửa sổ ĐK mở."""
        hk_dong = Semester.objects.update_or_create(
            ten_hk="HK1 2024-2025",
            defaults={
                "nam_hoc": "2024-2025",
                "ngay_bat_dau": date(2024, 9, 2),
                "ngay_ket_thuc": date(2025, 1, 10),
                "cua_so_dk_bat_dau": datetime(2024, 8, 1, 8, 0, tzinfo=dt_timezone.utc),
                "cua_so_dk_ket_thuc": datetime(2024, 8, 20, 23, 59, tzinfo=dt_timezone.utc),
                "tin_chi_toi_thieu": 12,
                "tin_chi_toi_da": 24,
                "tin_chi_toi_da_canh_bao": 14,
                "trang_thai": TrangThaiHocKy.DONG,
            },
        )[0]

        hom_qua = timezone.now() - timedelta(days=1)
        sau_14_ngay = timezone.now() + timedelta(days=14)
        hk_mo = Semester.objects.update_or_create(
            ten_hk="HK2 2024-2025",
            defaults={
                "nam_hoc": "2024-2025",
                "ngay_bat_dau": date(2025, 2, 10),
                "ngay_ket_thuc": date(2025, 6, 10),
                "cua_so_dk_bat_dau": hom_qua,
                "cua_so_dk_ket_thuc": sau_14_ngay,
                "tin_chi_toi_thieu": 12,
                "tin_chi_toi_da": 24,
                "tin_chi_toi_da_canh_bao": 14,
                "trang_thai": TrangThaiHocKy.MO,
            },
        )[0]
        return hk_dong, hk_mo

    # ------------------------------------------------------- lớp học phần

    def _seed_lop_hoc_phan(self, gv, hk_mo, hk_dong, mons):
        """6 lớp: 4 lớp MO (1 lớp si_so_toi_da=2), 1 DANG_HOC, 1 DA_DONG.
        1 cặp lịch trùng giờ: IT1010.L01 và IT2010.L01 cùng thứ 2 tiết 1-3."""

        def tao_lop(ma_lop, mon, hk, gv_idx, si_so, trang_thai):
            return ClassSection.objects.update_or_create(
                ma_lop=ma_lop,
                defaults={
                    "mon_hoc": mon,
                    "hoc_ky": hk,
                    "giao_vien": TeacherProfile.objects.get(user=gv[gv_idx]),
                    "si_so_toi_da": si_so,
                    "ngay_bat_dau": hk.ngay_bat_dau,
                    "ngay_ket_thuc": hk.ngay_ket_thuc,
                    "han_nhap_diem": hk.ngay_ket_thuc + timedelta(days=14),
                    "trang_thai": trang_thai,
                },
            )[0]

        def tao_lich(lop, cac_buoi):
            for thu, tiet, so_tiet, phong in cac_buoi:
                Schedule.objects.update_or_create(
                    lop_hoc_phan=lop,
                    thu=thu,
                    tiet_bat_dau=tiet,
                    defaults={"so_tiet_moi_buoi": so_tiet, "phong": phong},
                )

        # --- HK hiện tại (MO): 4 lớp
        lop_it1010 = tao_lop("IT1010.L01-HK2", mons["IT1010"], hk_mo, 0, 60, TrangThaiLop.MO)
        lop_it2010 = tao_lop("IT2010.L01-HK2", mons["IT2010"], hk_mo, 1, 60, TrangThaiLop.MO)
        lop_it3010 = tao_lop("IT3010.L01-HK2", mons["IT3010"], hk_mo, 2, 60, TrangThaiLop.MO)
        # Lớp sĩ số 2 để test chặn vượt sĩ số (BR-02).
        lop_it4010 = tao_lop("IT4010.L01-HK2", mons["IT4010"], hk_mo, 0, 2, TrangThaiLop.MO)

        tao_lich(lop_it1010, [(2, 1, 3, "A101"), (4, 1, 3, "A101")])
        # TRÙNG với IT1010 thứ 2 tiết 1-3 — test chặn trùng lịch (BR-03).
        tao_lich(lop_it2010, [(2, 1, 3, "B202"), (5, 6, 3, "B202")])
        tao_lich(lop_it3010, [(3, 6, 4, "C303"), (6, 6, 3, "C303")])
        tao_lich(lop_it4010, [(3, 11, 3, "D404"), (5, 11, 3, "D404")])

        # --- HK trước (ĐÓNG): lớp DA_DONG + lớp DANG_HOC (dùng cho điểm danh)
        lop_dong = tao_lop("IT1010.L01-HK1", mons["IT1010"], hk_dong, 0, 60, TrangThaiLop.DA_DONG)
        lop_dang_hoc = tao_lop("IT2010.L01-HK1", mons["IT2010"], hk_dong, 1, 60, TrangThaiLop.DANG_HOC)
        tao_lich(lop_dong, [(2, 1, 3, "A101"), (4, 1, 3, "A101")])
        tao_lich(lop_dang_hoc, [(2, 4, 3, "B201"), (5, 4, 3, "B201")])

        return {
            "mo": [lop_it1010, lop_it2010, lop_it3010, lop_it4010],
            "lop_dong": lop_dong,
            "lop_dang_hoc": lop_dang_hoc,
        }

    # ------------------------------------------------------------ bảng giá

    def _seed_bang_gia(self, hk_mo):
        PV = HocPhanGia.PhamVi
        rows = [
            (PV.MAC_DINH, None, Decimal("500000")),
            (PV.NGANH, "CNTT", Decimal("550000")),
            (PV.NGANH, "KTPM", Decimal("520000")),
            (PV.KHOI_KIEN_THUC, "tu_chon", Decimal("480000")),
            (PV.LECH_LT, None, Decimal("0.9")),
            (PV.GIA_TH, None, Decimal("700000")),
        ]
        for pham_vi, tham_chieu, don_gia in rows:
            HocPhanGia.objects.update_or_create(
                hoc_ky=hk_mo,
                pham_vi=pham_vi,
                tham_chieu=tham_chieu,
                defaults={"don_gia": don_gia, "hieu_luc_tu": hk_mo.ngay_bat_dau},
            )
        TuitionConfig.objects.update_or_create(
            hoc_ky=hk_mo,
            defaults={
                "han_dong": hk_mo.ngay_ket_thuc - timedelta(days=30),
                "chinh_sach_hoan_giam": "Hủy trong 2 tuần đầu: hoàn 100%. "
                "Từ tuần 3: không hoàn.",
            },
        )

    # --------------------------------------------- đăng ký + điểm (1.5.4/5)

    def _seed_dang_ky_diem(self, sv_users, lops, hk_mo):
        """HK trước: 10 SV đăng ký 2 lớp, điểm KHOA (sv05 F môn CSDL-like).
        HK hiện tại: 10 SV đăng ký 3 lớp; sv01+sv02 đăng ký lớp sĩ số 2.
        GPA cache: sv01 = 3.99, sv02 = 2.10."""

        lop_dong = lops["lop_dong"]
        lop_dang_hoc = lops["lop_dang_hoc"]
        User = get_user_model()

        for i, sv in enumerate(sv_users, 1):
            for lop in (lop_dong, lop_dang_hoc):
                Registration.objects.update_or_create(
                    sinh_vien=sv, lop_hoc_phan=lop,
                    defaults={
                        "hoc_ky": lop.hoc_ky,
                        "trang_thai": TrangThaiDangKy.DA_DANG_KY,
                        "loai_dang_ky": LoaiDangKy.BINH_THUONG,
                    },
                )

        # Điểm KHOA cho lớp đã đóng. sv05 F (BR-24 → phải học lại).
        diem_sv = {i: Decimal("8.0") for i in range(1, 11)}
        diem_sv[5] = Decimal("3.5")  # F
        for i, sv in enumerate(sv_users, 1):
            self._tao_diem(lop_dong, sv, diem_sv[i], TrangThaiDiem.KHOA)
            self._tao_diem(lop_dang_hoc, sv, diem_sv[i] + Decimal("0.5"), TrangThaiDiem.KHOA)

        # GPA cache (test BR-24): sv01 3.99, sv02 2.10.
        StudentProfile.objects.filter(user=sv_users[0]).update(
            gpa=Decimal("3.99"), tin_chi_tich_luy=6
        )
        StudentProfile.objects.filter(user=sv_users[1]).update(
            gpa=Decimal("2.10"), tin_chi_tich_luy=6
        )

        # HK hiện tại: 10 SV đăng ký 3 lớp MO; sv01+sv02 đăng ký lớp sĩ số 2.
        lop_mo = lops["mo"]
        for sv in sv_users:
            for lop in lop_mo[:3]:
                Registration.objects.update_or_create(
                    sinh_vien=sv, lop_hoc_phan=lop,
                    defaults={
                        "hoc_ky": hk_mo,
                        "trang_thai": TrangThaiDangKy.DA_DANG_KY,
                        "loai_dang_ky": LoaiDangKy.BINH_THUONG,
                    },
                )
        for sv in sv_users[:2]:
            Registration.objects.update_or_create(
                sinh_vien=sv, lop_hoc_phan=lop_mo[3],
                defaults={
                    "hoc_ky": hk_mo,
                    "trang_thai": TrangThaiDangKy.DA_DANG_KY,
                    "loai_dang_ky": LoaiDangKy.BINH_THUONG,
                },
            )

        # Cập nhật si_so_hien_tai = số đăng ký hiệu lực.
        for lop in [lop_dong, lop_dang_hoc, *lop_mo]:
            lop.si_so_hien_tai = Registration.objects.filter(
                lop_hoc_phan=lop, trang_thai=TrangThaiDangKy.DA_DANG_KY
            ).count()
            lop.save(update_fields=["si_so_hien_tai"])

        # Đơn học lại cho sv05 (F phải học lại — BR-24).
        from apps.training.models import GradeRetake, TrangThaiDon

        GradeRetake.objects.update_or_create(
            sinh_vien=User.objects.get(username="sv05"),
            mon_hoc=lop_dong.mon_hoc,
            defaults={
                "hoc_ky": hk_mo,
                "trang_thai": TrangThaiDon.DUYET,
            },
        )

    def _tao_diem(self, lop, sv, tong_ket, trang_thai):
        from decimal import ROUND_HALF_UP

        bang_chu = Decimal("8.5"), Decimal("7.0"), Decimal("5.5"), Decimal("4.0")
        g4 = {True: "4.0", 8.5: "4.0"}.get(True)
        if tong_ket >= bang_chu[0]:
            chu, g4 = "A", Decimal("4.0")
        elif tong_ket >= bang_chu[1]:
            chu, g4 = "B", Decimal("3.0")
        elif tong_ket >= bang_chu[2]:
            chu, g4 = "C", Decimal("2.0")
        elif tong_ket >= bang_chu[3]:
            chu, g4 = "D", Decimal("1.0")
        else:
            chu, g4 = "F", Decimal("0")

        # Công thức: 40% QT + 60% CK (không có giữa kỳ trong demo này).
        qt = (tong_ket * Decimal("2")).quantize(Decimal("0.01"), ROUND_HALF_UP) - Decimal("6")
        ck = tong_ket + Decimal("1")
        Grade.objects.update_or_create(
            lop_hoc_phan=lop,
            sinh_vien=sv,
            defaults={
                "diem_qua_trinh": qt,
                "diem_giua_ky": None,
                "diem_cuoi_ky": ck,
                "diem_tong_ket": tong_ket,
                "diem_chu": chu,
                "gpa_thang_4": g4,
                "trang_thai": trang_thai,
            },
        )

    # ---------------------------------------------------------- điểm danh

    def _seed_diem_danh(self, sv_users, lop):
        """10 buổi đã điểm danh trên lớp đang học.
        sv01 vắng 3/10 không phép (30% > 20% — test BR-20/BR-24)."""
        AttendanceSession.objects.filter(lop_hoc_phan=lop).delete()

        buoi_dau = date.today() - timedelta(days=date.today().weekday() + 7 * 9)
        sessions = []
        for t in range(10):
            ngay = buoi_dau + timedelta(days=7 * t)
            s = AttendanceSession.objects.create(
                lop_hoc_phan=lop,
                ngay_hoc=ngay,
                buoi=Buoi.SANG,
                tiet_bat_dau=4,
                trang_thai="DA_DIEM_DANH",
            )
            sessions.append(s)

        vang_sv01 = {2, 5, 8}  # 3/10 buổi = 30%
        for s in sessions:
            Attendance.objects.bulk_create(
                Attendance(
                    attendance_session=s,
                    lop_hoc_phan=lop,
                    ngay_hoc=s.ngay_hoc,
                    sinh_vien=sv,
                    trang_thai=(
                        "VANG_KHONG_PHEP"
                        if (sv == sv_users[0] and s.ngay_hoc in {sessions[i].ngay_hoc for i in vang_sv01})
                        else "CO_MAT"
                    ),
                )
                for sv in sv_users
            )

    # ------------------------------------------------------------ cấu hình

    def _seed_cau_hinh(self, hk_mo):
        configs = [
            ("tin_chi_toi_thieu", "INT", "12", "Số tín chỉ đăng ký tối thiểu"),
            ("tin_chi_toi_da", "INT", "24", "Số tín chỉ đăng ký tối đa"),
            ("tin_chi_toi_da_canh_bao", "INT", "14", "Ngưỡng cảnh báo tín chỉ"),
            ("max_absent_pct", "DECIMAL", "20", "% vắng tối đa bị cấm thi"),
            ("so_ngay_cho_phep_nhap_diem", "INT", "14", "Hạn nhập điểm sau khi lớp kết thúc"),
        ]
        for khoa, kieu, gia_tri, mo_ta in configs:
            SystemConfig.objects.update_or_create(
                khoa=khoa,
                defaults={"kieu": kieu, "gia_tri": gia_tri, "mo_ta": mo_ta},
            )
