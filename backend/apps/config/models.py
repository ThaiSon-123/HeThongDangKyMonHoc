"""SystemConfig + RolePermission (ADM-05/ADM-04, plan.md mục 9)."""

from django.db import models


class KieuGiaTri(models.TextChoices):
    INT = "INT", "INT"
    DECIMAL = "DECIMAL", "DECIMAL"
    STRING = "STRING", "STRING"
    BOOL = "BOOL", "BOOL"
    JSON = "JSON", "JSON"


class SystemConfig(models.Model):
    khoa = models.CharField(max_length=100, unique=True)
    kieu = models.CharField(max_length=10, choices=KieuGiaTri.choices, default=KieuGiaTri.STRING)
    gia_tri = models.CharField(max_length=200)  # lưu chuỗi, parse theo kieu (mục 9)
    mo_ta = models.CharField(max_length=255, blank=True)
    cap_nhat_luc = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "SystemConfig"
        verbose_name_plural = "SystemConfig"

    def __str__(self):
        return f"{self.khoa}={self.gia_tri}"

    @classmethod
    def get_bool(cls, khoa, default=True):
        raw = cls.objects.filter(khoa=khoa).values_list("gia_tri", flat=True).first()
        if raw is None:
            return default
        return str(raw).strip().lower() in {"1", "true", "yes", "on"}

    @classmethod
    def get_int(cls, khoa, default):
        raw = cls.objects.filter(khoa=khoa).values_list("gia_tri", flat=True).first()
        if raw is None:
            return default
        try:
            return int(raw)
        except (TypeError, ValueError):
            return default

    @classmethod
    def get_decimal(cls, khoa, default):
        from decimal import Decimal, InvalidOperation

        raw = cls.objects.filter(khoa=khoa).values_list("gia_tri", flat=True).first()
        if raw is None:
            return default
        try:
            return Decimal(str(raw))
        except (InvalidOperation, ValueError):
            return default


class RolePermission(models.Model):
    role = models.CharField(max_length=30)
    permission = models.CharField(max_length=100)
    trang_thai = models.BooleanField(default=True)

    class Meta:
        unique_together = [("role", "permission")]
        ordering = ["role", "permission"]

    def __str__(self):
        return f"{self.role}:{self.permission}"
