"""Thông báo (ADM-07): tập nhận = audience × target_refs, thu hồi = THU_HOI."""

from django.conf import settings
from django.db import models


class Audience(models.TextChoices):
    ROLE = "ROLE", "Vai trò"
    MAJOR = "MAJOR", "Ngành"
    CLASS = "CLASS", "Lớp học phần"
    SEMESTER = "SEMESTER", "Học kỳ"
    USER = "USER", "Người dùng"


class TrangThaiThongBao(models.TextChoices):
    DA_GUI = "DA_GUI", "Đã gửi"
    THU_HOI = "THU_HOI", "Thu hồi"


class Notification(models.Model):
    tieu_de = models.CharField(max_length=255)
    noi_dung = models.TextField()
    audience = models.CharField(max_length=20, choices=Audience.choices)
    target_refs = models.JSONField(default=list)
    nguoi_gui = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, related_name="thong_bao_gui"
    )
    ngay_gui = models.DateTimeField(auto_now_add=True)
    trang_thai = models.CharField(
        max_length=20, choices=TrangThaiThongBao.choices, default=TrangThaiThongBao.DA_GUI
    )

    class Meta:
        verbose_name = "Thông báo"
        verbose_name_plural = "Thông báo"
        ordering = ["-ngay_gui"]

    def __str__(self):
        return self.tieu_de


class NotificationRead(models.Model):
    notification = models.ForeignKey(Notification, on_delete=models.CASCADE, related_name="reads")
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="thong_bao_da_doc"
    )
    da_doc = models.BooleanField(default=True)
    ngay_doc = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = "Đã đọc"
        verbose_name_plural = "Đã đọc"
        constraints = [
            models.UniqueConstraint(fields=["notification", "user"], name="uniq_doc_thong_bao")
        ]

    def __str__(self):
        return f"{self.user_id}/{self.notification_id}"
