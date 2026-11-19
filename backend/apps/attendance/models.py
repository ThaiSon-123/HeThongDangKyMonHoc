"""Điểm danh (BR-19/20): AttendanceSession = mẫu số tỷ lệ vắng, Attendance = 1 dòng/SV/buổi."""

from django.conf import settings
from django.core.exceptions import ValidationError
from django.core.validators import FileExtensionValidator
from django.db import models
from django.utils import timezone

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
    # --- Phiên tự điểm danh khuôn mặt + GPS (KH §9). mo_luc null = chưa từng mở.
    mo_luc = models.DateTimeField(null=True, blank=True)
    het_han_luc = models.DateTimeField(null=True, blank=True)
    dong_luc = models.DateTimeField(null=True, blank=True)
    nguoi_mo = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="phien_tu_diem_danh_da_mo",
    )
    kiem_tra_phong = models.BooleanField(default=False)
    ma_phong_bi_mat = models.BinaryField(null=True, blank=True)

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

    def dang_mo_tu_diem_danh(self, now=None):
        now = now or timezone.now()
        return (
            self.mo_luc is not None
            and self.dong_luc is None
            and self.het_han_luc is not None
            and now < self.het_han_luc
        )


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
    # Tự điểm danh: "đáng ngờ" = vắng + cờ này, chờ GV duyệt (KH §8).
    dang_ngo = models.BooleanField(default=False)
    luot_tot_nhat = models.ForeignKey(
        "CheckinAttempt", null=True, blank=True, on_delete=models.SET_NULL, related_name="+"
    )
    # GV đã quyết tay (lưu cả lớp / duyệt lượt / điểm danh thủ công) → tự điểm danh không ghi đè nữa.
    nguoi_quyet = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="diem_danh_da_quyet",
    )

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


MINH_CHUNG_TOI_DA = 5 * 1024 * 1024  # 5 MB


def validate_minh_chung(f):
    if f.size > MINH_CHUNG_TOI_DA:
        raise ValidationError("Minh chứng tối đa 5 MB.")


class AttendanceRequest(models.Model):
    attendance = models.ForeignKey(Attendance, on_delete=models.CASCADE, related_name="yeu_cau")
    sinh_vien = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="yeu_cau_sua_diem_danh"
    )
    ly_do = models.TextField()
    # SV chỉ xin sang có mặt / vắng có phép (không xin "vắng không phép").
    trang_thai_mong_muon = models.CharField(
        max_length=20,
        choices=[
            (TrangThaiDiemDanh.CO_MAT.value, TrangThaiDiemDanh.CO_MAT.label),
            (TrangThaiDiemDanh.VANG_CO_PHEP.value, TrangThaiDiemDanh.VANG_CO_PHEP.label),
        ],
    )
    di_tre_mong_muon = models.BooleanField(default=False)
    minh_chung = models.FileField(
        upload_to="minh_chung/",
        null=True,
        blank=True,
        validators=[
            FileExtensionValidator(["jpg", "jpeg", "png", "pdf"]),
            validate_minh_chung,
        ],
    )
    ngay_gui = models.DateTimeField(auto_now_add=True)
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
    ghi_chu = models.CharField(max_length=255, blank=True)

    class Meta:
        verbose_name = "Yêu cầu sửa điểm danh"
        verbose_name_plural = "Yêu cầu sửa điểm danh"
        ordering = ["-id"]
        constraints = [
            # Mỗi buổi (dòng điểm danh) tối đa 1 yêu cầu đang chờ duyệt.
            models.UniqueConstraint(
                fields=["attendance"],
                condition=models.Q(trang_thai="CHO_DUYET"),
                name="uniq_yeu_cau_cho_duyet_theo_buoi",
            )
        ]

    def __str__(self):
        return f"{self.attendance_id} — {self.trang_thai}"


class TrangThaiMau(models.TextChoices):
    CHO_DUYET = "CHO_DUYET", "Chờ duyệt"
    DUYET = "DUYET", "Đã duyệt"
    TU_CHOI = "TU_CHOI", "Từ chối"
    THU_HOI = "THU_HOI", "Thu hồi"


class FaceTemplate(models.Model):
    """Mẫu khuôn mặt của SV: embedding đã mã hóa AES-GCM; ảnh đăng ký (mã hóa) xóa ngay khi duyệt/từ chối."""

    sinh_vien = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="mau_khuon_mat"
    )
    ten_mo_hinh = models.CharField(max_length=50)
    embedding = models.BinaryField(null=True, blank=True)  # null khi đã thu hồi
    thu_muc_anh = models.CharField(max_length=100, blank=True)  # tương đối FACE_STORAGE_DIR
    so_anh = models.PositiveSmallIntegerField(default=0)
    trang_thai = models.CharField(
        max_length=20, choices=TrangThaiMau.choices, default=TrangThaiMau.CHO_DUYET
    )
    nguoi_duyet = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="mau_khuon_mat_da_duyet",
    )
    ngay_duyet = models.DateTimeField(null=True, blank=True)
    ly_do = models.CharField(max_length=255, blank=True)
    tao_luc = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = "Mẫu khuôn mặt"
        verbose_name_plural = "Mẫu khuôn mặt"
        ordering = ["-id"]
        constraints = [
            models.UniqueConstraint(
                fields=["sinh_vien"],
                condition=models.Q(trang_thai="DUYET"),
                name="uniq_mau_mat_da_duyet",
            ),
            models.UniqueConstraint(
                fields=["sinh_vien"],
                condition=models.Q(trang_thai="CHO_DUYET"),
                name="uniq_mau_mat_cho_duyet",
            ),
        ]

    def __str__(self):
        return f"{self.sinh_vien_id} {self.trang_thai}"


class Consent(models.Model):
    """SV đồng ý xử lý dữ liệu sinh trắc (Nghị định 13/2023) — lưu phiên bản văn bản."""

    sinh_vien = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="dong_y_sinh_trac"
    )
    phien_ban = models.CharField(max_length=20)
    dong_y_luc = models.DateTimeField(auto_now_add=True)
    rut_lai_luc = models.DateTimeField(null=True, blank=True)

    class Meta:
        verbose_name = "Đồng ý dữ liệu sinh trắc"
        verbose_name_plural = "Đồng ý dữ liệu sinh trắc"
        ordering = ["-id"]


class HanhDongThuThach(models.TextChoices):
    TRAI = "turn_left", "Quay trái"
    PHAI = "turn_right", "Quay phải"


class Challenge(models.Model):
    """Thử thách dùng 1 lần (nonce + hành động ngẫu nhiên, hạn 60 s). Mỗi lần xin = 1 lượt."""

    session = models.ForeignKey(
        AttendanceSession, on_delete=models.CASCADE, related_name="thu_thach"
    )
    sinh_vien = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="thu_thach_diem_danh"
    )
    nonce = models.CharField(max_length=40, unique=True)
    hanh_dong = models.CharField(max_length=20, choices=HanhDongThuThach.choices)
    het_han_luc = models.DateTimeField()
    da_dung = models.BooleanField(default=False)
    tao_luc = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [models.Index(fields=["session", "sinh_vien"])]


class KetQuaLuot(models.TextChoices):
    CO_MAT = "CO_MAT", "Có mặt"
    DANG_NGO = "DANG_NGO", "Đáng ngờ"
    KHONG_DAT = "KHONG_DAT", "Không đạt"


class CheckinAttempt(models.Model):
    """Mọi lượt SV gửi lên (kể cả bị chặn): để GV xem lại và để tính tâm lệch / bước nhảy."""

    session = models.ForeignKey(AttendanceSession, on_delete=models.CASCADE, related_name="luot")
    sinh_vien = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="luot_diem_danh"
    )
    challenge = models.ForeignKey(Challenge, null=True, blank=True, on_delete=models.SET_NULL)
    nen_tang = models.CharField(max_length=10, blank=True)  # android / web
    device_id = models.CharField(max_length=64, blank=True)
    ip = models.GenericIPAddressField(null=True, blank=True)  # chỉ để tra cứu, không dùng chấm
    mau_gps = models.JSONField(default=list)  # mẫu thô; xóa khi hết học kỳ
    lat = models.FloatField(null=True, blank=True)  # vị trí SV (trung vị)
    lng = models.FloatField(null=True, blank=True)
    sai_so_m = models.FloatField(null=True, blank=True)
    d_m = models.FloatField(null=True, blank=True)
    r_m = models.FloatField(null=True, blank=True)
    diem_mat = models.FloatField(null=True, blank=True)
    diem_that = models.FloatField(null=True, blank=True)
    ket_qua = models.CharField(max_length=20, choices=KetQuaLuot.choices)
    buoc_dung = models.PositiveSmallIntegerField(null=True, blank=True)  # null = qua cả 6 bước
    ly_do = models.CharField(max_length=40, blank=True)
    co = models.JSONField(default=list)
    anh_bang_chung = models.CharField(max_length=100, blank=True)  # tương đối FACE_STORAGE_DIR
    tao_luc = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = "Lượt tự điểm danh"
        verbose_name_plural = "Lượt tự điểm danh"
        ordering = ["-id"]
        indexes = [
            models.Index(fields=["session", "sinh_vien"]),
            models.Index(fields=["session", "device_id"]),
        ]

    def __str__(self):
        return f"{self.session_id} {self.sinh_vien_id} {self.ket_qua}"
