"""Dữ liệu đào tạo: ngành, CTĐT, môn, học kỳ, lớp HP, lịch (plan.md mục 9)."""

from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models


class TrangThaiDung(models.TextChoices):
    """Trạng thái Ngành / CTĐT."""

    HOAT_DONG = "HOAT_DONG", "Hoạt động"
    NGUNG = "NGUNG", "Ngừng"


class TrangThaiMon(models.TextChoices):
    HOAT_DONG = "HOAT_DONG", "Hoạt động"
    NGUNG_SU_DUNG = "NGUNG_SU_DUNG", "Ngừng sử dụng"


class Faculty(models.Model):
    """Khoa/viện — PĐT quản lý; không xóa, chỉ ngừng (plan.md mục 5)."""

    ma_khoa = models.CharField(max_length=20, unique=True)
    ten_khoa = models.CharField(max_length=200)
    trang_thai = models.CharField(
        max_length=20, choices=TrangThaiDung.choices, default=TrangThaiDung.HOAT_DONG
    )

    class Meta:
        verbose_name = "Khoa/viện"
        verbose_name_plural = "Khoa/viện"
        ordering = ["ma_khoa"]

    def __str__(self):
        return f"{self.ma_khoa} — {self.ten_khoa}"


class Major(models.Model):
    ma_nganh = models.CharField(max_length=20, unique=True)
    ten_nganh = models.CharField(max_length=200)
    thoi_gian_dao_tao = models.PositiveSmallIntegerField(default=4)
    khoa = models.ForeignKey(Faculty, on_delete=models.PROTECT, related_name="nganh")
    trang_thai = models.CharField(
        max_length=20, choices=TrangThaiDung.choices, default=TrangThaiDung.HOAT_DONG
    )

    class Meta:
        verbose_name = "Ngành"
        verbose_name_plural = "Ngành"
        ordering = ["ma_nganh"]

    def __str__(self):
        return f"{self.ma_nganh} — {self.ten_nganh}"


class Curriculum(models.Model):
    ma_ctdt = models.CharField(max_length=20, unique=True)
    nganh = models.ForeignKey(Major, on_delete=models.PROTECT, related_name="ctdts")
    khoa_tuyen_sinh = models.CharField(max_length=20)
    tong_tin_chi_yeu_cau = models.PositiveSmallIntegerField(validators=[MinValueValidator(1)])
    trang_thai = models.CharField(
        max_length=20, choices=TrangThaiDung.choices, default=TrangThaiDung.HOAT_DONG
    )

    class Meta:
        verbose_name = "Chương trình đào tạo"
        verbose_name_plural = "Chương trình đào tạo"
        ordering = ["ma_ctdt"]
        constraints = [
            # Chỉ 1 CTĐT HOAT_DONG mỗi (nganh, khoa_tuyen_sinh) — unique có điều kiện.
            models.UniqueConstraint(
                fields=["nganh", "khoa_tuyen_sinh"],
                condition=models.Q(trang_thai="HOAT_DONG"),
                name="uniq_ctdt_hoat_dong_theo_nganh_khoa",
            )
        ]

    def __str__(self):
        return self.ma_ctdt


class KhoiKienThuc(models.TextChoices):
    CHUNG = "chung", "Chung"
    CO_SO_NGANH = "co_so_nganh", "Cơ sở ngành"
    CHUYEN_NGANH = "chuyen_nganh", "Chuyên ngành"
    TU_CHON = "tu_chon", "Tự chọn"
    TOT_NGHIEP = "tot_nghiep", "Tốt nghiệp"


class LoaiMon(models.TextChoices):
    BAT_BUOC = "bat_buoc", "Bắt buộc"
    TU_CHON = "tu_chon", "Tự chọn"


class Course(models.Model):
    ma_mon = models.CharField(max_length=20, unique=True)
    ten_mon = models.CharField(max_length=200)
    tong_tin_chi = models.PositiveSmallIntegerField()
    tin_chi_ly_thuyet = models.PositiveSmallIntegerField(default=0)
    tin_chi_thuc_hanh = models.PositiveSmallIntegerField(default=0)
    so_tiet_ly_thuyet = models.PositiveSmallIntegerField(default=0)
    so_tiet_thuc_hanh = models.PositiveSmallIntegerField(default=0)
    loai_danh_gia = models.CharField(
        max_length=20,
        choices=[("DIEM", "Điểm"), ("DAT_KHONG_DAT", "Đạt/Không đạt")],
        default="DIEM",
    )
    khoa = models.ForeignKey(Faculty, on_delete=models.PROTECT, related_name="mon_hoc")
    trang_thai = models.CharField(
        max_length=20, choices=TrangThaiMon.choices, default=TrangThaiMon.HOAT_DONG
    )

    class Meta:
        verbose_name = "Môn học"
        verbose_name_plural = "Môn học"
        ordering = ["ma_mon"]
        constraints = [
            models.CheckConstraint(
                condition=models.Q(
                    tong_tin_chi=models.F("tin_chi_ly_thuyet") + models.F("tin_chi_thuc_hanh")
                ),
                name="ck_mon_tong_tin_chi_bang_tong_phan",
            )
        ]

    def __str__(self):
        return f"{self.ma_mon} — {self.ten_mon}"


class CurriculumCourse(models.Model):
    ctdt = models.ForeignKey(Curriculum, on_delete=models.CASCADE, related_name="mon_ctdt")
    mon_hoc = models.ForeignKey(Course, on_delete=models.PROTECT, related_name="mon_ctdt")
    khoi_kien_thuc = models.CharField(
        max_length=20, choices=KhoiKienThuc.choices, default=KhoiKienThuc.CHUNG
    )
    loai_mon = models.CharField(max_length=20, choices=LoaiMon.choices, default=LoaiMon.BAT_BUOC)
    hoc_ky_goi_y = models.PositiveSmallIntegerField(default=1)

    class Meta:
        verbose_name = "Môn trong CTĐT"
        verbose_name_plural = "Môn trong CTĐT"
        ordering = ["ctdt", "hoc_ky_goi_y", "mon_hoc"]
        constraints = [
            models.UniqueConstraint(fields=["ctdt", "mon_hoc"], name="uniq_mon_theo_ctdt")
        ]

    def __str__(self):
        return f"{self.ctdt.ma_ctdt}/{self.mon_hoc.ma_mon}"


class Prerequisite(models.Model):
    mon_hoc = models.ForeignKey(Course, on_delete=models.CASCADE, related_name="mon_tien_quyet_roi")
    mon_tien_quyet = models.ForeignKey(Course, on_delete=models.CASCADE, related_name="biet_mon")

    class Meta:
        verbose_name = "Môn tiên quyết"
        verbose_name_plural = "Môn tiên quyết"
        constraints = [
            models.UniqueConstraint(fields=["mon_hoc", "mon_tien_quyet"], name="uniq_tien_quyet"),
            # mon_hoc ≠ mon_tien_quyet — ràng buộc logic, DB chặn trước cho rẻ.
            models.CheckConstraint(
                condition=~models.Q(mon_hoc=models.F("mon_tien_quyet")),
                name="ck_tien_quyet_khong_tu_tham_chieu",
            ),
        ]

    def __str__(self):
        return f"{self.mon_hoc.ma_mon} ← {self.mon_tien_quyet.ma_mon}"


class TrangThaiHocKy(models.TextChoices):
    MO = "MO", "Mở"
    DONG = "DONG", "Đóng"


class Semester(models.Model):
    ten_hk = models.CharField(max_length=50, unique=True)
    nam_hoc = models.CharField(max_length=20)
    ngay_bat_dau = models.DateField()
    ngay_ket_thuc = models.DateField()
    cua_so_dk_bat_dau = models.DateTimeField()
    cua_so_dk_ket_thuc = models.DateTimeField()
    # Trần tín chỉ theo học kỳ, PĐT cấu hình (BR-07).
    tin_chi_toi_thieu = models.PositiveSmallIntegerField(default=12)
    tin_chi_toi_da = models.PositiveSmallIntegerField(default=24)
    tin_chi_toi_da_canh_bao = models.PositiveSmallIntegerField(default=14)
    trang_thai = models.CharField(
        max_length=10, choices=TrangThaiHocKy.choices, default=TrangThaiHocKy.MO
    )

    class Meta:
        verbose_name = "Học kỳ"
        verbose_name_plural = "Học kỳ"
        ordering = ["-ngay_bat_dau"]
        constraints = [
            models.CheckConstraint(
                condition=models.Q(tin_chi_toi_thieu__gte=1)
                & models.Q(tin_chi_toi_thieu__lte=models.F("tin_chi_toi_da")),
                name="ck_hk_tin_chi_toi_thieu_hop_le",
            ),
            models.CheckConstraint(
                condition=models.Q(tin_chi_toi_da_canh_bao__lte=models.F("tin_chi_toi_da")),
                name="ck_hk_tin_chi_canh_bao_khong_vuot_toi_da",
            ),
        ]

    def __str__(self):
        return self.ten_hk


class TrangThaiLop(models.TextChoices):
    KE_HOACH = "KE_HOACH", "Kế hoạch"
    MO = "MO", "Mở"
    DANG_HOC = "DANG_HOC", "Đang học"
    DA_DONG = "DA_DONG", "Đã đóng"


class ClassSection(models.Model):
    ma_lop = models.CharField(max_length=30, unique=True)
    mon_hoc = models.ForeignKey(Course, on_delete=models.PROTECT, related_name="lop_hoc_phan")
    hoc_ky = models.ForeignKey(Semester, on_delete=models.PROTECT, related_name="lop_hoc_phan")
    giao_vien = models.ForeignKey(
        "profiles.TeacherProfile", on_delete=models.PROTECT, related_name="lop_hoc_phan"
    )
    si_so_toi_da = models.PositiveSmallIntegerField()
    si_so_hien_tai = models.PositiveSmallIntegerField(default=0)
    ngay_bat_dau = models.DateField(null=True, blank=True)
    ngay_ket_thuc = models.DateField(null=True, blank=True)
    han_nhap_diem = models.DateField(null=True, blank=True)
    trang_thai = models.CharField(
        max_length=20, choices=TrangThaiLop.choices, default=TrangThaiLop.KE_HOACH
    )

    class Meta:
        verbose_name = "Lớp học phần"
        verbose_name_plural = "Lớp học phần"
        ordering = ["ma_lop"]
        constraints = [
            models.CheckConstraint(
                condition=models.Q(si_so_hien_tai__lte=models.F("si_so_toi_da")),
                name="ck_lop_si_so_khong_vuot_toi_da",
            )
        ]

    def __str__(self):
        return self.ma_lop


class Buoi(models.TextChoices):
    SANG = "SANG", "Sáng"
    CHIEU = "CHIEU", "Chiều"
    TOI = "TOI", "Tối"


class Schedule(models.Model):
    lop_hoc_phan = models.ForeignKey(
        ClassSection, on_delete=models.CASCADE, related_name="lich_hoc"
    )
    # 2..7 = thứ 2..thứ 7, 8 = Chủ nhật (BR-08)
    thu = models.PositiveSmallIntegerField(validators=[MinValueValidator(2), MaxValueValidator(8)])
    tiet_bat_dau = models.PositiveSmallIntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(15)]
    )
    so_tiet_moi_buoi = models.PositiveSmallIntegerField(validators=[MinValueValidator(1)])
    phong = models.CharField(max_length=30)

    class Meta:
        verbose_name = "Lịch học"
        verbose_name_plural = "Lịch học"
        ordering = ["thu", "tiet_bat_dau"]

    @property
    def tiet_ket_thuc(self):
        """Dẫn xuất (mục 9): tiet_bat_dau + so_tiet_moi_buoi − 1."""
        return self.tiet_bat_dau + self.so_tiet_moi_buoi - 1

    @property
    def buoi(self):
        """Dẫn xuất từ tiết: 1–5 sáng, 6–10 chiều, 11–15 tối (BR-08)."""
        if self.tiet_bat_dau <= 5:
            return Buoi.SANG
        if self.tiet_bat_dau <= 10:
            return Buoi.CHIEU
        return Buoi.TOI

    def __str__(self):
        return f"{self.lop_hoc_phan.ma_lop} thứ {self.thu} tiết {self.tiet_bat_dau}-{self.tiet_ket_thuc}"


class TrangThaiDon(models.TextChoices):
    CHO_DUYET = "CHO_DUYET", "Chờ duyệt"
    DUYET = "DUYET", "Đã duyệt"
    TU_CHOI = "TU_CHOI", "Từ chối"
