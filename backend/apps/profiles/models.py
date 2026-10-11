"""Hồ sơ SV/GV. `gpa` + `tin_chi_tich_luy` là cache BR-25, không nhập tay."""

from django.conf import settings
from django.db import models


class StudentProfile(models.Model):
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="sinh_vien"
    )
    ma_sv = models.CharField(max_length=20, unique=True)
    ho_ten = models.CharField(max_length=150)
    nganh = models.ForeignKey("training.Major", on_delete=models.PROTECT, related_name="sinh_vien")
    khoa_nhap_hoc = models.CharField(max_length=20)
    ctdt = models.ForeignKey(
        "training.Curriculum",
        null=True,
        blank=True,
        on_delete=models.PROTECT,
        related_name="sinh_vien",
    )
    gpa = models.DecimalField(max_digits=3, decimal_places=2, null=True, blank=True)
    tin_chi_tich_luy = models.PositiveIntegerField(default=0)
    email = models.EmailField(blank=True)
    sdt = models.CharField(max_length=15, blank=True)

    class Meta:
        verbose_name = "Hồ sơ sinh viên"
        verbose_name_plural = "Hồ sơ sinh viên"
        ordering = ["ma_sv"]

    def __str__(self):
        return f"{self.ma_sv} — {self.ho_ten}"


class TeacherProfile(models.Model):
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="giang_vien"
    )
    ma_gv = models.CharField(max_length=20, unique=True)
    ho_ten = models.CharField(max_length=150)
    khoa = models.ForeignKey("training.Faculty", on_delete=models.PROTECT, related_name="giao_vien")
    hoc_vi = models.CharField(max_length=100, blank=True)
    email = models.EmailField(blank=True)
    sdt = models.CharField(max_length=15, blank=True)

    class Meta:
        verbose_name = "Hồ sơ giảng viên"
        verbose_name_plural = "Hồ sơ giảng viên"
        ordering = ["ma_gv"]

    def __str__(self):
        return f"{self.ma_gv} — {self.ho_ten}"
