"""Điểm danh (BR-20/BR-24): AttendanceSession = mẫu số vắng, Attendance = 1 dòng/SV/buổi."""

from django.conf import settings
from django.db import models

from apps.training.models import Buoi, ClassSection, TrangThaiDon


class TrangThaiSession(models.TextChoices):
    MO = "MO", "Mở"
    DA_DIEM_DANH = "DA_DIEM_DANH", "Đã điểm danh"


class AttendanceSession(models.Model):
    lop_hoc_phan = models.ForeignKey(
        ClassSection, on_delete=models.CASCADE, related_name="buoi_diem_danh"
    )
    ngay_hoc = models.DateField()
    buoi = models.CharField(max_length=10, choices=Buoi.choices)
    tiet_bat_dau = models.PositiveSmallIntegerField()
    trang_thai = models.CharField(
        max_length=20, choices=TrangThaiSession.choices, default=TrangThaiSession.MO
    )

    class Meta:
        verbose_name = "Buổi điểm danh"
        verbose_name_plural = "Buổi điểm danh"
        ordering = ["ngay_hoc", "buoi"]
        constraints = [
            # 1 buổi điểm danh mỗi (lớp, ngày, buổi) — 2 buổi khác buổi vẫn hợp lệ.
            models.UniqueConstraint(
                fields=["lop_hoc_phan", "ngay_hoc", "buoi"], name="uniq_buoi_diem_danh"
            )
        ]

    def __str__(self):
        return f"{self.lop_hoc_phan_id} {self.ngay_hoc} {self.buoi}"


class TrangThaiDiemDanh(models.TextChoices):
    CO_MAT = "CO_MAT", "Có mặt"
    VANG_CO_PHEP = "VANG_CO_PHEP", "Vắng có phép"
    VANG_KHONG_PHEP = "VANG_KHONG_PHEP", "Vắng không phép"


class Attendance(models.Model):
    attendance_session = models.ForeignKey(
        AttendanceSession, on_delete=models.CASCADE, related_name="chi_tiet"
    )
    lop_hoc_phan = models.ForeignKey(
        ClassSection, on_delete=models.CASCADE, related_name="diem_danh"
    )
    ngay_hoc = models.DateField()
    sinh_vien = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="diem_danh"
    )
    trang_thai = models.CharField(
        max_length=20, choices=TrangThaiDiemDanh.choices, default=TrangThaiDiemDanh.CO_MAT
    )
    di_tre = models.BooleanField(default=False)
    ghi_chu = models.CharField(max_length=255, blank=True)
    cap_nhat_luc = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Điểm danh"
        verbose_name_plural = "Điểm danh"
        ordering = ["ngay_hoc"]
        constraints = [
            models.UniqueConstraint(
                fields=["attendance_session", "sinh_vien"], name="uniq_diem_danh_theo_buoi"
            )
        ]

    @property
    def vang(self):
        return self.trang_thai == TrangThaiDiemDanh.VANG_KHONG_PHEP

    def __str__(self):
        return f"{self.sinh_vien_id} {self.ngay_hoc} {self.trang_thai}"


class AttendanceRequest(models.Model):
    attendance = models.ForeignKey(Attendance, on_delete=models.CASCADE, related_name="yeu_cau")
    sinh_vien = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="yeu_cau_sua_diem_danh"
    )
    ly_do = models.TextField()
    trang_thai_mong_muon = models.CharField(max_length=20, choices=TrangThaiDiemDanh.choices)
    trang_thai = models.CharField(
        max_length=20, choices=TrangThaiDon.choices, default=TrangThaiDon.CHO_DUYET
    )
    nguoi_duyet = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="duyet_yeu_cau_diem_danh",
    )
    ngay_duyet = models.DateTimeField(null=True, blank=True)

    class Meta:
        verbose_name = "Yêu cầu sửa điểm danh"
        verbose_name_plural = "Yêu cầu sửa điểm danh"
        ordering = ["-id"]

    def __str__(self):
        return f"{self.attendance_id} — {self.trang_thai}"
