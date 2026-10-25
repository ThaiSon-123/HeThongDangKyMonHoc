from rest_framework import serializers

from apps.attendance.models import (
    AttendanceRequest,
    AttendanceSession,
    TrangThaiDiemDanh,
)
from apps.training.models import TrangThaiDon


class SessionSerializer(serializers.ModelSerializer):
    class Meta:
        model = AttendanceSession
        fields = ["id", "lop_hoc_phan", "ngay_hoc", "buoi", "tiet_bat_dau", "trang_thai"]
        read_only_fields = fields


class SessionListSerializer(serializers.Serializer):
    """Chỉ để mô tả Swagger: phân trang + `tong_so_buoi` (mẫu số tỷ lệ vắng, BR-20)."""

    count = serializers.IntegerField()
    next = serializers.CharField(allow_null=True)
    previous = serializers.CharField(allow_null=True)
    tong_so_buoi = serializers.IntegerField()
    results = SessionSerializer(many=True)


class RecordSerializer(serializers.Serializer):
    sinh_vien = serializers.IntegerField()
    trang_thai = serializers.ChoiceField(choices=TrangThaiDiemDanh.choices)
    di_tre = serializers.BooleanField(required=False, default=False)
    ghi_chu = serializers.CharField(required=False, allow_blank=True, max_length=255, default="")


class RecordsPutSerializer(serializers.Serializer):
    records = RecordSerializer(many=True, allow_empty=False)


class RecordRowSerializer(RecordSerializer):
    """Một dòng của `GET records`: kèm thông tin SV và tỷ lệ vắng cả khóa (cờ cảnh báo, BR-20)."""

    ma_sv = serializers.CharField()
    ho_ten = serializers.CharField()
    da_luu = serializers.BooleanField()
    so_buoi_vang_kp = serializers.IntegerField()
    ty_le_vang = serializers.FloatField()
    canh_bao_vang = serializers.BooleanField()


class RecordsSerializer(serializers.Serializer):
    session = SessionSerializer()
    lop_trang_thai = serializers.CharField()
    co_the_diem_danh = serializers.BooleanField()
    con_han_sua = serializers.BooleanField()  # còn trong hạn sửa điểm danh (BR-20e)
    so_ngay_xin_sua = serializers.IntegerField()
    tong_so_buoi = serializers.IntegerField()
    max_absent_pct = serializers.IntegerField()
    records = RecordRowSerializer(many=True)


class MyBuoiSerializer(serializers.Serializer):
    session = serializers.IntegerField()
    attendance = serializers.IntegerField(allow_null=True)
    ngay_hoc = serializers.DateField()
    buoi = serializers.CharField()
    tiet_bat_dau = serializers.IntegerField()
    trang_thai = serializers.CharField(allow_null=True, help_text="null = buổi chưa điểm danh")
    di_tre = serializers.BooleanField()
    ghi_chu = serializers.CharField()
    yeu_cau = serializers.DictField(allow_null=True)
    con_han_xin_sua = serializers.BooleanField()


class MyLopSerializer(serializers.Serializer):
    lop_hoc_phan = serializers.IntegerField()
    ma_lop = serializers.CharField()
    ma_mon = serializers.CharField()
    ten_mon = serializers.CharField()
    lop_trang_thai = serializers.CharField()
    tong_so_buoi = serializers.IntegerField()
    so_co_mat = serializers.IntegerField()
    so_di_tre = serializers.IntegerField()
    so_vang_co_phep = serializers.IntegerField()
    so_vang_kp = serializers.IntegerField()
    ty_le_vang = serializers.FloatField()
    canh_bao_vang = serializers.BooleanField()
    so_buoi_vang_cho_phep = serializers.IntegerField()
    buoi = MyBuoiSerializer(many=True)


class HocKyCoDangKySerializer(serializers.Serializer):
    id = serializers.IntegerField()
    ten_hk = serializers.CharField()


class MyAttendanceSerializer(serializers.Serializer):
    hoc_ky = serializers.IntegerField()
    ten_hk = serializers.CharField()
    cac_hoc_ky = HocKyCoDangKySerializer(many=True)  # kỳ tôi có đăng ký, mới nhất trước — để chọn xem kỳ khác
    max_absent_pct = serializers.IntegerField()
    so_ngay_xin_sua = serializers.IntegerField()
    lop_hoc_phan = MyLopSerializer(many=True)


class AttendanceRequestSerializer(serializers.ModelSerializer):
    """Yêu cầu sửa điểm danh kèm buổi, lớp, SV; `minh_chung` là đường dẫn tải (chỉ GV lớp đó xem)."""

    ngay_hoc = serializers.DateField(source="attendance.ngay_hoc", read_only=True)
    buoi = serializers.CharField(source="attendance.attendance_session.buoi", read_only=True)
    lop_hoc_phan = serializers.IntegerField(source="attendance.lop_hoc_phan_id", read_only=True)
    ma_lop = serializers.CharField(source="attendance.lop_hoc_phan.ma_lop", read_only=True)
    ten_mon = serializers.CharField(
        source="attendance.lop_hoc_phan.mon_hoc.ten_mon", read_only=True
    )
    ma_sv = serializers.CharField(source="sinh_vien.sinh_vien.ma_sv", read_only=True, default=None)
    ho_ten = serializers.CharField(
        source="sinh_vien.sinh_vien.ho_ten", read_only=True, default=None
    )
    trang_thai_hien_tai = serializers.CharField(source="attendance.trang_thai", read_only=True)
    di_tre_hien_tai = serializers.BooleanField(source="attendance.di_tre", read_only=True)
    minh_chung = serializers.SerializerMethodField()

    class Meta:
        model = AttendanceRequest
        fields = [
            "id",
            "attendance",
            "ngay_hoc",
            "buoi",
            "lop_hoc_phan",
            "ma_lop",
            "ten_mon",
            "ma_sv",
            "ho_ten",
            "trang_thai_hien_tai",
            "di_tre_hien_tai",
            "trang_thai_mong_muon",
            "di_tre_mong_muon",
            "ly_do",
            "minh_chung",
            "ngay_gui",
            "trang_thai",
            "ngay_duyet",
            "ghi_chu",
        ]
        read_only_fields = fields

    def get_minh_chung(self, obj) -> str | None:
        return f"/api/attendance/requests/{obj.id}/minh-chung/" if obj.minh_chung else None


class RequestCreateSerializer(serializers.Serializer):
    """`POST` dạng `multipart/form-data` (kèm tệp `minh_chung` tùy chọn ≤ 5 MB: jpg/png/pdf)."""

    attendance = serializers.IntegerField()
    trang_thai_mong_muon = serializers.ChoiceField(
        choices=[
            (TrangThaiDiemDanh.CO_MAT.value, TrangThaiDiemDanh.CO_MAT.label),
            (TrangThaiDiemDanh.VANG_CO_PHEP.value, TrangThaiDiemDanh.VANG_CO_PHEP.label),
        ]
    )
    di_tre_mong_muon = serializers.BooleanField(required=False, default=False)
    ly_do = serializers.CharField(max_length=2000)
    minh_chung = serializers.FileField(required=False, allow_null=True)

    def validate_minh_chung(self, f):
        # Dùng đúng validator của model (đuôi tệp + 5 MB) để một nơi quy định.
        field = AttendanceRequest._meta.get_field("minh_chung")
        for v in field.validators:
            try:
                v(f)
            except Exception as e:  # django ValidationError → lỗi field DRF
                raise serializers.ValidationError(getattr(e, "messages", [str(e)])) from None
        return f


class RequestDecisionSerializer(serializers.Serializer):
    trang_thai = serializers.ChoiceField(
        choices=[(TrangThaiDon.DUYET.value, "Duyệt"), (TrangThaiDon.TU_CHOI.value, "Từ chối")]
    )
    ghi_chu = serializers.CharField(required=False, allow_blank=True, max_length=255, default="")
