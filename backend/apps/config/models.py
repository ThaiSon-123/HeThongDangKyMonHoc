"""SystemConfig (ADM-05, plan.md mục 5). Quyền theo vai trò cố định trong code (mục 9)."""

from django.db import models


class SystemConfig(models.Model):
    khoa = models.CharField(max_length=100, unique=True)
    gia_tri = models.CharField(
        max_length=200
    )  # lưu chuỗi, nơi đọc tự parse (get_int/get_decimal/get_bool)
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
