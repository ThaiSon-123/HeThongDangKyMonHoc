"""Registration (plan.md mục 5). `request_id` UNIQUE khi khác NULL, gán một lần lúc tạo (8.3)."""

from django.conf import settings
from django.db import models

from apps.training.models import ClassSection


class TrangThaiDangKy(models.TextChoices):
    DA_DANG_KY = "DA_DANG_KY", "Đã đăng ký"
    DA_HUY = "DA_HUY", "Đã hủy"


class Registration(models.Model):
    sinh_vien = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="dang_ky"
    )
    lop_hoc_phan = models.ForeignKey(ClassSection, on_delete=models.PROTECT, related_name="dang_ky")
    trang_thai = models.CharField(
        max_length=20, choices=TrangThaiDangKy.choices, default=TrangThaiDangKy.DA_DANG_KY
    )
    ngay_dang_ky = models.DateTimeField(auto_now_add=True)
    ngay_huy = models.DateTimeField(null=True, blank=True)
    ly_do_huy = models.CharField(max_length=255, blank=True)
    request_id = models.UUIDField(null=True, blank=True, unique=True)

    class Meta:
        verbose_name = "Đăng ký môn học"
        verbose_name_plural = "Đăng ký môn học"
        ordering = ["-ngay_dang_ky"]
        constraints = [
            models.UniqueConstraint(fields=["sinh_vien", "lop_hoc_phan"], name="uniq_sv_lop_hp")
        ]
        indexes = [models.Index(fields=["sinh_vien", "trang_thai"])]

    def __str__(self):
        return f"{self.sinh_vien_id} → {self.lop_hoc_phan_id} ({self.trang_thai})"
