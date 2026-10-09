"""User — `role` là enum cứng 5 giá trị (ADM-04), `is_locked` chặn login + refresh."""

from django.contrib.auth.models import AbstractUser
from django.db import models


class Role(models.TextChoices):
    ADMIN = "ADMIN", "Quản trị viên"
    PHONG_DAO_TAO = "PHONG_DAO_TAO", "Phòng đào tạo"
    SINH_VIEN = "SINH_VIEN", "Sinh viên"
    GIAO_VIEN = "GIAO_VIEN", "Giảng viên"
    KE_TOAN = "KE_TOAN", "Kế toán"


class User(AbstractUser):
    role = models.CharField(max_length=30, choices=Role.choices, default=Role.SINH_VIEN)
    is_locked = models.BooleanField(default=False)

    class Meta:
        ordering = ["username"]

    @property
    def is_admin(self):
        return self.role == Role.ADMIN

    def __str__(self):
        return f"{self.username} ({self.role})"
