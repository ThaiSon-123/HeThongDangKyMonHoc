"""Học phí (BR-15..18, KT-01..09) — `da_thu`/`mien_giam`/`hoan_tien` là cache rebase từ bảng con."""

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
        LECH_LT = "LECH_LT", "Lệch LT"
        LECH_TH = "LECH_TH", "Lệch TH"
        GIA_TH = "GIA_TH", "Giá TH"

    hoc_ky = models.ForeignKey(
        Semester, null=True, blank=True, on_delete=models.CASCADE, related_name="bang_gia"
    )
    pham_vi = models.CharField(max_length=20, choices=PhamVi.choices)
    tham_chieu = models.CharField(max_length=50, null=True, blank=True)
    don_gia = models.DecimalField(max_digits=14, decimal_places=2)
    hieu_luc_tu = models.DateField(null=True, blank=True)

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
            # don_gia ≥ 0, riêng LECH_* là hệ số nên âm vẫn hợp lệ.
            models.CheckConstraint(
                condition=models.Q(pham_vi__in=["LECH_LT", "LECH_TH"]) | models.Q(don_gia__gte=0),
                name="ck_gia_don_gia_khong_am",
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
    chinh_sach_hoan_giam = models.TextField(blank=True)

    class Meta:
        verbose_name = "Chính sách học phí"
        verbose_name_plural = "Chính sách học phí"

    def __str__(self):
        return f"{self.hoc_ky} — hạn {self.han_dong}"


class LoaiMienGiam(models.TextChoices):
    MIEN_GIAM = "MIEN_GIAM", "Miễn giảm"
    HOAN_TIEN = "HOAN_TIEN", "Hoàn tiền"
    GIAM_TRU = "GIAM_TRU", "Giảm trừ"
    HOC_BONG = "HOC_BONG", "Học bổng"


class TrangThaiMienGiam(models.TextChoices):
    AP_DUNG = "AP_DUNG", "Áp dụng"
    DA_CHI = "DA_CHI", "Đã chi"


class Discount(models.Model):
    sinh_vien = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="mien_giam"
    )
    hoc_ky = models.ForeignKey(Semester, on_delete=models.CASCADE, related_name="mien_giam")
    loai = models.CharField(max_length=20, choices=LoaiMienGiam.choices)
    so_tien = models.DecimalField(max_digits=14, decimal_places=2, null=True, blank=True)
    ty_le = models.DecimalField(max_digits=5, decimal_places=2, null=True, blank=True)
    ly_do = models.CharField(max_length=255, blank=True)
    trang_thai = models.CharField(
        max_length=20, choices=TrangThaiMienGiam.choices, default=TrangThaiMienGiam.AP_DUNG
    )

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
    CHUA_TINH = "CHUA_TINH", "Chưa tính"
    DA_TINH = "DA_TINH", "Đã tính"
    DA_DONG = "DA_DONG", "Đã đóng"
    CON_NO = "CON_NO", "Còn nợ"
    GIAM_TRU = "GIAM_TRU", "Giảm trừ"
    CHO_HOAN_TIEN = "CHO_HOAN_TIEN", "Chờ hoàn tiền"
    DA_HOAN_TIEN = "DA_HOAN_TIEN", "Đã hoàn tiền"


class Tuition(models.Model):
    sinh_vien = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="hoc_phi"
    )
    hoc_ky = models.ForeignKey(Semester, on_delete=models.PROTECT, related_name="hoc_phi")
    tong_tin_chi = models.PositiveSmallIntegerField(default=0)
    tong_tien = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    da_thu = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    mien_giam = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    hoan_tien = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    con_no = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    trang_thai = models.CharField(
        max_length=20, choices=TrangThaiHocPhi.choices, default=TrangThaiHocPhi.CHUA_TINH
    )

    class Meta:
        verbose_name = "Học phí"
        verbose_name_plural = "Học phí"
        ordering = ["hoc_ky_id", "sinh_vien_id"]
        constraints = [
            models.UniqueConstraint(fields=["sinh_vien", "hoc_ky"], name="uniq_sv_hoc_ky")
        ]

    @property
    def con_no_tinh_lai(self):
        """`con_no = max(0, tong_tien − da_thu − mien_giam)`."""
        return max(0, self.tong_tien - self.da_thu - self.mien_giam)

    def tinh_trang_thai(self):
        """Thứ tự ưu tiên: hoàn tiền > còn nợ > giảm trừ > đã đóng (mục 9)."""
        if self.hoan_tien > 0:
            return TrangThaiHocPhi.CHO_HOAN_TIEN
        if self.con_no > 0:
            return TrangThaiHocPhi.CON_NO
        if self.mien_giam > 0:
            return TrangThaiHocPhi.GIAM_TRU
        return TrangThaiHocPhi.DA_DONG

    def __str__(self):
        return f"{self.sinh_vien_id}/{self.hoc_ky_id} {self.trang_thai}"


class PhuongThuc(models.TextChoices):
    TIEN_MAT = "TIEN_MAT", "Tiền mặt"
    CHUYEN_KHOAN = "CHUYEN_KHOAN", "Chuyển khoản"
    KHAC = "KHAC", "Khác"


class Payment(models.Model):
    tuition = models.ForeignKey(Tuition, on_delete=models.CASCADE, related_name="payments")
    so_tien = models.DecimalField(max_digits=14, decimal_places=2)
    phuong_thuc = models.CharField(max_length=20, choices=PhuongThuc.choices)
    ngay_thu = models.DateTimeField(auto_now_add=True)
    nguoi_thu = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="thu_hoc_phi"
    )
    bien_lai_ma = models.CharField(max_length=50, blank=True)
    request_id = models.UUIDField(null=True, blank=True, unique=True)

    class Meta:
        verbose_name = "Thanh toán"
        verbose_name_plural = "Thanh toán"
        ordering = ["-ngay_thu"]

    def __str__(self):
        return f"{self.tuition_id} {self.so_tien}"
