"""AuditLog (ADM-06, plan.md mục 5). doi_tuong_id là chuỗi id bất kỳ (PK là bigint), KHÔNG FK."""

from django.conf import settings
from django.db import models


class HanhDong(models.TextChoices):
    CREATE = "CREATE", "CREATE"
    UPDATE = "UPDATE", "UPDATE"
    DELETE = "DELETE", "DELETE"
    LOGIN = "LOGIN", "LOGIN"
    PHAN_QUYEN = "PHAN_QUYEN", "PHAN_QUYEN"


# scope theo tiền tố doi_tuong — bảng mapping chuẩn (plan.md mục 5)
SCOPE_TRAINING = {
    "User",
    "StudentProfile",
    "TeacherProfile",
    "Major",
    "Curriculum",
    "CurriculumCourse",
    "Course",
    "Prerequisite",
    "Semester",
    "ClassSection",
    "Schedule",
    "Registration",
    "AttendanceSession",
    "Attendance",
    "AttendanceRequest",
    "Grade",
    "Notification",
}
SCOPE_FINANCE = {
    "HocPhanGia",
    "TuitionConfig",
    "Discount",
    "Payment",
    "Tuition",
}


class AuditLog(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="audit_logs",
    )
    hanh_dong = models.CharField(max_length=20, choices=HanhDong.choices)
    doi_tuong = models.CharField(max_length=50)
    doi_tuong_id = models.CharField(max_length=64, blank=True)
    chi_tiet = models.JSONField(default=dict, blank=True)
    thoi_gian = models.DateTimeField(auto_now_add=True, db_index=True)
    ip = models.GenericIPAddressField(null=True, blank=True)

    class Meta:
        ordering = ["-thoi_gian"]
        indexes = [models.Index(fields=["doi_tuong", "doi_tuong_id"])]

    @property
    def scope(self):
        if self.doi_tuong in SCOPE_FINANCE:
            return "finance"
        if self.doi_tuong in SCOPE_TRAINING:
            return "training"
        return "other"

    def __str__(self):
        return f"{self.hanh_dong} {self.doi_tuong}#{self.doi_tuong_id}"
