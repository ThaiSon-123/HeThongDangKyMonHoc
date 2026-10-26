"""Học phí (BR-15..18, BR-26). Tuition chỉ lưu tong_*; con_no/can_hoan/... dẫn xuất (plan.md mục 5)."""

import uuid

from django.conf import settings
from django.db import models
from django.db.models import BigIntegerField, CharField, Value
from django.db.models.functions import Coalesce

from apps.training.models import Semester


class HocPhanGia(models.Model):
    """Bảng giá (BR-16). `tham_chieu IS NULL` ⇔ `pham_vi = MAC_DINH`."""

    class PhamVi(models.TextChoices):
        MAC_DINH = "MAC_DINH", "Mặc định"
        KHOI_KIEN_THUC = "KHOI_KIEN_THUC", "Khối kiến thức"
        NGANH = "NGANH", "Ngành"
        GIA_TH = "GIA_TH", "Giá TH"

    hoc_ky = models.ForeignKey(
        Semester, null=True, blank=True, on_delete=models.CASCADE, related_name="bang_gia"
    )
    pham_vi = models.CharField(max_length=20, choices=PhamVi.choices)
    tham_chieu = models.CharField(max_length=50, null=True, blank=True)
    don_gia = models.DecimalField(max_digits=14, decimal_places=2)

    class Meta:
        verbose_name = "Bảng giá học phí"
        verbose_name_plural = "Bảng giá học phí"
        ordering = ["hoc_ky_id", "pham_vi"]
        constraints = [
            # COALESCE vì Postgres UNIQUE coi NULL ≠ NULL → nhiều bảng giá
            # MAC_DINH cùng học kỳ (hoặc cùng học kỳ rỗng) sẽ lọt.
            models.UniqueConstraint(
                Coalesce("hoc_ky_id", Value(0, output_field=BigIntegerField())),
                "pham_vi",
                Coalesce("tham_chieu", Value("", output_field=CharField())),
                name="uniq_bang_gia",
            ),
            models.CheckConstraint(
                condition=models.Q(don_gia__gte=0), name="ck_gia_don_gia_khong_am"
            ),
        ]

    def __str__(self):
        return f"{self.pham_vi}/{self.tham_chieu or '-'} {self.don_gia}"


class TuitionConfig(models.Model):
    """Chính sách học phí theo học kỳ (KT-01)."""

    hoc_ky = models.OneToOneField(
        Semester, on_delete=models.CASCADE, related_name="chinh_sach_hoc_phi"
    )
    han_dong = models.DateField()
    ghi_chu = models.TextField(blank=True)

    class Meta:
        verbose_name = "Chính sách học phí"
        verbose_name_plural = "Chính sách học phí"

    def __str__(self):
        return f"{self.hoc_ky} — hạn {self.han_dong}"


class LoaiMienGiam(models.TextChoices):
    MIEN_GIAM = "MIEN_GIAM", "Miễn giảm"
    HOC_BONG = "HOC_BONG", "Học bổng"


class Discount(models.Model):
    sinh_vien = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="mien_giam"
    )
    hoc_ky = models.ForeignKey(Semester, on_delete=models.CASCADE, related_name="mien_giam")
    loai = models.CharField(max_length=20, choices=LoaiMienGiam.choices)
    so_tien = models.DecimalField(max_digits=14, decimal_places=2, null=True, blank=True)
    ty_le = models.DecimalField(max_digits=5, decimal_places=2, null=True, blank=True)
    ly_do = models.CharField(max_length=255, blank=True)

    class Meta:
        verbose_name = "Miễn giảm"
        verbose_name_plural = "Miễn giảm"
        ordering = ["-id"]
        constraints = [
            # Đúng một hình thức: số tiền hoặc tỷ lệ.
            models.CheckConstraint(
                condition=models.Q(so_tien__isnull=False, ty_le__isnull=True)
                | models.Q(so_tien__isnull=True, ty_le__isnull=False),
                name="ck_mien_giam_du_hinh_thuc",
            ),
        ]

    def __str__(self):
        return f"{self.sinh_vien_id} {self.loai} {self.so_tien or self.ty_le}"


class TrangThaiHocPhi(models.TextChoices):
    """Chỉ trạng thái lưu. Trạng thái hiển thị (CON_NO/CHO_HOAN_TIEN/DA_DONG) dẫn xuất."""

    CHUA_TINH = "CHUA_TINH", "Chưa tính"
    DA_TINH = "DA_TINH", "Đã tính"


class HinhThucDong(models.TextChoices):
    MOT_LAN = "MOT_LAN", "Đóng một lần"
    CHIA_DOT = "CHIA_DOT", "Chia 3 đợt"


class Tuition(models.Model):
    sinh_vien = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="hoc_phi"
    )
    hoc_ky = models.ForeignKey(Semester, on_delete=models.PROTECT, related_name="hoc_phi")
    tong_tin_chi = models.PositiveSmallIntegerField(default=0)
    tong_tien = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    trang_thai = models.CharField(
        max_length=20, choices=TrangThaiHocPhi.choices, default=TrangThaiHocPhi.CHUA_TINH
    )
    hinh_thuc = models.CharField(
        max_length=10, choices=HinhThucDong.choices, default=HinhThucDong.MOT_LAN
    )

    class Meta:
        verbose_name = "Học phí"
        verbose_name_plural = "Học phí"
        ordering = ["hoc_ky_id", "sinh_vien_id"]
        constraints = [
            models.UniqueConstraint(fields=["sinh_vien", "hoc_ky"], name="uniq_sv_hoc_ky")
        ]

    def __str__(self):
        return f"{self.sinh_vien_id}/{self.hoc_ky_id} {self.trang_thai}"


class PhuongThuc(models.TextChoices):
    TIEN_MAT = "TIEN_MAT", "Tiền mặt"
    CHUYEN_KHOAN = "CHUYEN_KHOAN", "Chuyển khoản"
    KHAC = "KHAC", "Khác"
    VNPAY = "VNPAY", "VNPay"


class LoaiThanhToan(models.TextChoices):
    THU = "THU", "Thu"
    HOAN = "HOAN", "Hoàn tiền"


class TuitionInstallment(models.Model):
    """Một trong 3 đợt đóng học phí của học kỳ (tỷ lệ % + hạn). Lịch đợt của từng SV là dẫn xuất."""

    hoc_ky = models.ForeignKey(Semester, on_delete=models.CASCADE, related_name="dot_hoc_phi")
    thu_tu = models.PositiveSmallIntegerField()
    ty_le = models.DecimalField(max_digits=5, decimal_places=2)
    han_dong = models.DateField()

    class Meta:
        verbose_name = "Đợt đóng học phí"
        verbose_name_plural = "Đợt đóng học phí"
        ordering = ["hoc_ky_id", "thu_tu"]
        constraints = [
            models.UniqueConstraint(fields=["hoc_ky", "thu_tu"], name="uniq_dot_hoc_ky_thu_tu"),
            models.CheckConstraint(
                condition=models.Q(thu_tu__gte=1, thu_tu__lte=3), name="ck_dot_thu_tu_1_3"
            ),
        ]

    def __str__(self):
        return f"{self.hoc_ky_id} đợt {self.thu_tu} {self.ty_le}%"


class Payment(models.Model):
    tuition = models.ForeignKey(Tuition, on_delete=models.CASCADE, related_name="payments")
    loai = models.CharField(max_length=10, choices=LoaiThanhToan.choices, default=LoaiThanhToan.THU)
    so_tien = models.DecimalField(max_digits=14, decimal_places=2)
    phuong_thuc = models.CharField(max_length=20, choices=PhuongThuc.choices)
    ngay = models.DateTimeField(auto_now_add=True)
    nguoi_thu = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="thu_hoc_phi"
    )
    bien_lai_ma = models.CharField(max_length=50, blank=True)
    request_id = models.UUIDField(null=True, blank=True, unique=True)

    class Meta:
        verbose_name = "Thanh toán"
        verbose_name_plural = "Thanh toán"
        ordering = ["-ngay"]
        constraints = [
            models.CheckConstraint(
                condition=models.Q(so_tien__gt=0), name="ck_payment_so_tien_duong"
            )
        ]

    def __str__(self):
        return f"{self.tuition_id} {self.so_tien}"


class TrangThaiGiaoDich(models.TextChoices):
    CHO = "CHO", "Chờ thanh toán"
    THANH_CONG = "THANH_CONG", "Thành công"
    THAT_BAI = "THAT_BAI", "Thất bại"
    LOI = "LOI", "Lỗi cần xử lý"


class OnlineTransaction(models.Model):
    """Giao dịch VNPay đã khởi tạo; `txn_ref` (dạng hex) là `vnp_TxnRef` và `Payment.request_id`."""

    txn_ref = models.UUIDField(unique=True, default=uuid.uuid4, editable=False)
    tuition = models.ForeignKey(Tuition, on_delete=models.CASCADE, related_name="giao_dich_online")
    so_tien = models.DecimalField(max_digits=14, decimal_places=2)
    trang_thai = models.CharField(
        max_length=12, choices=TrangThaiGiaoDich.choices, default=TrangThaiGiaoDich.CHO
    )
    vnp_transaction_no = models.CharField(max_length=30, blank=True)
    tao_luc = models.DateTimeField(auto_now_add=True)
    ket_thuc_luc = models.DateTimeField(null=True, blank=True)

    class Meta:
        verbose_name = "Giao dịch VNPay"
        verbose_name_plural = "Giao dịch VNPay"
        ordering = ["-tao_luc"]

    def __str__(self):
        return f"{self.txn_ref.hex} {self.trang_thai}"
