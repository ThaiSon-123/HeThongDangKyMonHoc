from decimal import Decimal

from rest_framework import serializers

from apps.auth.models import Role
from apps.training.models import KhoiKienThuc, Major
from apps.tuition.models import (
    Discount,
    HinhThucDong,
    HocPhanGia,
    LoaiThanhToan,
    Payment,
    PhuongThuc,
    TuitionConfig,
)

TIEN = {"max_digits": 14, "decimal_places": 2}


class TuitionConfigSerializer(serializers.ModelSerializer):
    ten_hk = serializers.CharField(source="hoc_ky.ten_hk", read_only=True)

    class Meta:
        model = TuitionConfig
        fields = ["id", "hoc_ky", "ten_hk", "han_dong", "ghi_chu"]


class InstallmentSerializer(serializers.Serializer):
    thu_tu = serializers.IntegerField(min_value=1, max_value=3)
    ty_le = serializers.DecimalField(
        max_digits=5, decimal_places=2, min_value=Decimal("0.01"), max_value=Decimal(100)
    )
    han_dong = serializers.DateField()


class InstallmentsPutSerializer(serializers.Serializer):
    dots = InstallmentSerializer(many=True)

    def validate_dots(self, dots):
        if sorted(d["thu_tu"] for d in dots) != [1, 2, 3]:
            raise serializers.ValidationError("Phải có đủ 3 đợt với thứ tự 1, 2, 3.")
        dots = sorted(dots, key=lambda d: d["thu_tu"])
        if sum(d["ty_le"] for d in dots) != 100:
            raise serializers.ValidationError("Tổng tỷ lệ 3 đợt phải bằng 100%.")
        if not dots[0]["han_dong"] < dots[1]["han_dong"] < dots[2]["han_dong"]:
            raise serializers.ValidationError("Hạn đóng phải tăng dần theo đợt.")
        return dots


class InstallmentsSerializer(InstallmentsPutSerializer):
    hoc_ky = serializers.IntegerField(read_only=True)


class HocPhanGiaSerializer(serializers.ModelSerializer):
    ten_hk = serializers.CharField(source="hoc_ky.ten_hk", read_only=True, default=None)

    class Meta:
        model = HocPhanGia
        fields = ["id", "hoc_ky", "ten_hk", "pham_vi", "tham_chieu", "don_gia"]
        extra_kwargs = {"don_gia": {"min_value": 0}}  # DB cũng chặn (ck_gia_don_gia_khong_am)

    def validate(self, attrs):
        inst = self.instance

        def g(k):
            return attrs[k] if k in attrs else getattr(inst, k, None)

        pham_vi, tham_chieu = g("pham_vi"), (g("tham_chieu") or None)
        P = HocPhanGia.PhamVi
        if pham_vi in (P.MAC_DINH, P.GIA_TH):
            if tham_chieu:
                raise serializers.ValidationError(
                    {"tham_chieu": ["Phạm vi này không có tham chiếu (để trống)."]}
                )
        elif not tham_chieu:
            raise serializers.ValidationError({"tham_chieu": ["Bắt buộc với phạm vi này."]})
        elif pham_vi == P.NGANH and not Major.objects.filter(ma_nganh=tham_chieu).exists():
            raise serializers.ValidationError({"tham_chieu": ["Mã ngành không tồn tại."]})
        elif pham_vi == P.KHOI_KIEN_THUC and tham_chieu not in KhoiKienThuc.values:
            raise serializers.ValidationError({"tham_chieu": ["Khối kiến thức không hợp lệ."]})
        attrs["tham_chieu"] = tham_chieu
        trung = HocPhanGia.objects.filter(
            hoc_ky=g("hoc_ky"), pham_vi=pham_vi, tham_chieu=tham_chieu
        )
        if inst:
            trung = trung.exclude(pk=inst.pk)
        if trung.exists():
            raise serializers.ValidationError(
                {"pham_vi": ["Đã có bảng giá cùng học kỳ, phạm vi và tham chiếu."]}
            )
        return attrs


class DiscountSerializer(serializers.ModelSerializer):
    ma_sv = serializers.CharField(source="sinh_vien.sinh_vien.ma_sv", read_only=True, default=None)
    ho_ten = serializers.CharField(
        source="sinh_vien.sinh_vien.ho_ten", read_only=True, default=None
    )
    ten_hk = serializers.CharField(source="hoc_ky.ten_hk", read_only=True)

    class Meta:
        model = Discount
        fields = [
            "id",
            "sinh_vien",
            "ma_sv",
            "ho_ten",
            "hoc_ky",
            "ten_hk",
            "loai",
            "so_tien",
            "ty_le",
            "ly_do",
        ]
        extra_kwargs = {
            "so_tien": {"required": False, "allow_null": True},
            "ty_le": {"required": False, "allow_null": True},
        }

    def validate_sinh_vien(self, user):
        if user.role != Role.SINH_VIEN:
            raise serializers.ValidationError("Chỉ miễn giảm cho sinh viên.")
        return user

    def validate(self, attrs):
        inst = self.instance

        def g(k):
            return attrs[k] if k in attrs else getattr(inst, k, None)

        so_tien, ty_le = g("so_tien"), g("ty_le")
        if (so_tien is None) == (ty_le is None):
            raise serializers.ValidationError(
                {"so_tien": ["Nhập đúng một trong hai: số tiền hoặc tỷ lệ (%)."]}
            )
        if so_tien is not None and so_tien <= 0:
            raise serializers.ValidationError({"so_tien": ["Số tiền phải lớn hơn 0."]})
        if ty_le is not None and not Decimal(0) < ty_le <= Decimal(100):
            raise serializers.ValidationError({"ty_le": ["Tỷ lệ phải trong (0, 100]."]})
        return attrs

    def update(self, instance, validated_data):
        validated_data.pop("sinh_vien", None)  # đổi người nhận thì tạo bản ghi mới
        validated_data.pop("hoc_ky", None)
        return super().update(instance, validated_data)


class SinhVienKtSerializer(serializers.Serializer):
    """KT chỉ thấy tối thiểu (mục 9): mã SV, họ tên, ngành — không lộ liên hệ/GPA."""

    id = serializers.IntegerField(source="user_id")
    ma_sv = serializers.CharField()
    ho_ten = serializers.CharField()
    nganh_ten = serializers.CharField(source="nganh.ten_nganh")


class PaymentSerializer(serializers.ModelSerializer):
    nguoi_thu_ten = serializers.CharField(source="nguoi_thu.username", read_only=True)

    class Meta:
        model = Payment
        fields = [
            "id",
            "tuition",
            "loai",
            "so_tien",
            "phuong_thuc",
            "ngay",
            "nguoi_thu_ten",
            "bien_lai_ma",
        ]
        read_only_fields = ["id", "ngay", "nguoi_thu_ten", "bien_lai_ma"]


class PaymentCreateSerializer(serializers.Serializer):
    tuition = serializers.IntegerField()
    loai = serializers.ChoiceField(choices=LoaiThanhToan.choices)
    so_tien = serializers.DecimalField(min_value=Decimal("0.01"), **TIEN)
    phuong_thuc = serializers.ChoiceField(choices=PhuongThuc.choices)


class ChiTietMonSerializer(serializers.Serializer):
    ma_mon = serializers.CharField()
    ten_mon = serializers.CharField()
    ma_lop = serializers.CharField()
    tin_chi_ly_thuyet = serializers.IntegerField()
    tin_chi_thuc_hanh = serializers.IntegerField()
    don_gia_goc = serializers.DecimalField(**TIEN)
    don_gia_th = serializers.DecimalField(**TIEN)
    thanh_tien = serializers.DecimalField(**TIEN)


class ThanhToanSerializer(serializers.Serializer):
    ngan_hang = serializers.CharField(allow_blank=True)
    so_tai_khoan = serializers.CharField(allow_blank=True)
    chu_tai_khoan = serializers.CharField(allow_blank=True)
    noi_dung_ck = serializers.CharField()


class TuitionRowSerializer(serializers.Serializer):
    id = serializers.IntegerField(allow_null=True)
    sinh_vien = serializers.IntegerField()
    ma_sv = serializers.CharField()
    ho_ten = serializers.CharField()
    nganh_ma = serializers.CharField()
    nganh_ten = serializers.CharField()
    hoc_ky = serializers.IntegerField()
    ten_hk = serializers.CharField()
    tong_tin_chi = serializers.IntegerField()
    tong_tien = serializers.DecimalField(**TIEN)
    trang_thai = serializers.CharField()
    mien_giam = serializers.DecimalField(**TIEN)
    phai_nop = serializers.DecimalField(**TIEN)
    thuc_thu = serializers.DecimalField(**TIEN)
    con_no = serializers.DecimalField(**TIEN)
    can_hoan = serializers.DecimalField(**TIEN)
    hien_thi = serializers.CharField()
    hinh_thuc = serializers.CharField()
    han_dong = serializers.DateField(allow_null=True)
    qua_han = serializers.BooleanField()


class TuitionDetailSerializer(TuitionRowSerializer):
    chi_tiet = ChiTietMonSerializer(many=True)
    payments = PaymentSerializer(many=True)


class HocKyCoHocPhiSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    ten_hk = serializers.CharField()


class DotMySerializer(serializers.Serializer):
    thu_tu = serializers.IntegerField()
    han_dong = serializers.DateField()
    phai_nop = serializers.DecimalField(**TIEN)
    luy_ke = serializers.DecimalField(**TIEN)
    da_dong = serializers.BooleanField()


class DotTiepTheoSerializer(serializers.Serializer):
    thu_tu = serializers.IntegerField()
    can_dong = serializers.DecimalField(**TIEN)


class MyPlanSerializer(serializers.Serializer):
    hinh_thuc = serializers.ChoiceField(choices=HinhThucDong.choices)


class MyPaySerializer(serializers.Serializer):
    muc = serializers.ChoiceField(choices=["DOT_TIEP", "TOAN_BO", "TUY_Y"])
    so_tien = serializers.DecimalField(required=False, **TIEN)


class MyPayResultSerializer(serializers.Serializer):
    payment_url = serializers.CharField()
    txn_ref = serializers.CharField()
    so_tien = serializers.DecimalField(**TIEN)


class MyPayStatusSerializer(serializers.Serializer):
    txn_ref = serializers.CharField()
    trang_thai = serializers.CharField()
    so_tien = serializers.DecimalField(**TIEN)


class MyTuitionSerializer(TuitionDetailSerializer):
    thanh_toan = ThanhToanSerializer()
    cac_dot = DotMySerializer(many=True)  # lịch 3 đợt nếu học kỳ đã cấu hình, ngược lại []
    dot_tiep_theo = DotTiepTheoSerializer(allow_null=True)  # chỉ có khi CHIA_DOT
    cac_hoc_ky = HocKyCoHocPhiSerializer(
        many=True
    )  # kỳ tôi có học phí (+ kỳ đang xem), mới nhất trước


class CalculateResultSerializer(serializers.Serializer):
    so_sinh_vien = serializers.IntegerField()
