"""Grade (BR-10/11/13/24). UNIQUE(lop_hoc_phan, sinh_vien) — cả F tự sinh cũng ở đây."""

from django.conf import settings
from django.db import models

from apps.training.models import ClassSection


class TrangThaiDiem(models.TextChoices):
    NHAP_TAM = "NHAP_TAM", "Nhập tạm"
    CHINH_THUC = "CHINH_THUC", "Chính thức"
    KHOA = "KHOA", "Khóa"


class Grade(models.Model):
    lop_hoc_phan = models.ForeignKey(ClassSection, on_delete=models.CASCADE, related_name="diem")
    sinh_vien = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="diem"
    )
    diem_qua_trinh = models.DecimalField(max_digits=4, decimal_places=2, null=True, blank=True)
    diem_giua_ky = models.DecimalField(max_digits=4, decimal_places=2, null=True, blank=True)
    diem_cuoi_ky = models.DecimalField(max_digits=4, decimal_places=2, null=True, blank=True)
    diem_tong_ket = models.DecimalField(max_digits=4, decimal_places=2, null=True, blank=True)
    diem_chu = models.CharField(max_length=2, blank=True)
    gpa_thang_4 = models.DecimalField(max_digits=3, decimal_places=2, null=True, blank=True)
    trang_thai = models.CharField(
        max_length=20, choices=TrangThaiDiem.choices, default=TrangThaiDiem.NHAP_TAM
    )
    ngay_nhap = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = "Điểm"
        verbose_name_plural = "Điểm"
        ordering = ["lop_hoc_phan_id", "sinh_vien_id"]
        constraints = [
            models.UniqueConstraint(fields=["lop_hoc_phan", "sinh_vien"], name="uniq_diem_lop_sv")
        ]

    def __str__(self):
        return f"{self.lop_hoc_phan_id}/{self.sinh_vien_id} {self.diem_tong_ket or '-'}"
