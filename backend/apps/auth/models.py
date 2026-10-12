"""User — `role` là enum cứng 5 giá trị (ADM-04), `is_locked` chặn login + refresh."""

from typing import ClassVar

from django.contrib.auth.models import AbstractUser
from django.contrib.auth.models import UserManager as DjangoUserManager
from django.db import models


class Role(models.TextChoices):
    ADMIN = "ADMIN", "Quản trị viên"
    PHONG_DAO_TAO = "PHONG_DAO_TAO", "Phòng đào tạo"
    SINH_VIEN = "SINH_VIEN", "Sinh viên"
    GIAO_VIEN = "GIAO_VIEN", "Giảng viên"
    KE_TOAN = "KE_TOAN", "Kế toán"


class UserManager(DjangoUserManager):
    """`createsuperuser` phải tạo tài khoản ADMIN (mặc định `role` là SINH_VIEN → không vào được trang quản trị)."""

    def create_superuser(self, username, email=None, password=None, **extra_fields):
        extra_fields.setdefault("role", Role.ADMIN)
        return super().create_superuser(username, email, password, **extra_fields)


class User(AbstractUser):
    role = models.CharField(max_length=30, choices=Role.choices, default=Role.SINH_VIEN)
    is_locked = models.BooleanField(default=False)

    objects: ClassVar[UserManager] = UserManager()

    class Meta:
        ordering = ["username"]

    @property
    def is_admin(self):
        return self.role == Role.ADMIN

    def __str__(self):
        return f"{self.username} ({self.role})"
