from rest_framework import serializers

from apps.registration.models import Registration
from apps.training.models import ClassSection
from apps.training.serializers import ScheduleSerializer


class WarningSerializer(serializers.Serializer):
    code = serializers.CharField()
    message = serializers.CharField()


class RegistrationSerializer(serializers.ModelSerializer):
    """Một đăng ký kèm thông tin lớp/môn (SV xem lịch sử) và SV (PĐT theo dõi)."""

    ma_lop = serializers.CharField(source="lop_hoc_phan.ma_lop", read_only=True)
    ma_mon = serializers.CharField(source="lop_hoc_phan.mon_hoc.ma_mon", read_only=True)
    ten_mon = serializers.CharField(source="lop_hoc_phan.mon_hoc.ten_mon", read_only=True)
    tong_tin_chi = serializers.IntegerField(
        source="lop_hoc_phan.mon_hoc.tong_tin_chi", read_only=True
    )
    hoc_ky = serializers.IntegerField(source="lop_hoc_phan.hoc_ky_id", read_only=True)
    ten_hk = serializers.CharField(source="lop_hoc_phan.hoc_ky.ten_hk", read_only=True)
    giao_vien_ten = serializers.CharField(source="lop_hoc_phan.giao_vien.ho_ten", read_only=True)
    lop_trang_thai = serializers.CharField(source="lop_hoc_phan.trang_thai", read_only=True)
    lich_hoc = ScheduleSerializer(source="lop_hoc_phan.lich_hoc", many=True, read_only=True)
    ma_sv = serializers.CharField(source="sinh_vien.sinh_vien.ma_sv", read_only=True, default=None)
    ho_ten = serializers.CharField(
        source="sinh_vien.sinh_vien.ho_ten", read_only=True, default=None
    )
    nganh_ten = serializers.CharField(
        source="sinh_vien.sinh_vien.nganh.ten_nganh", read_only=True, default=None
    )

    class Meta:
        model = Registration
        fields = [
            "id",
            "lop_hoc_phan",
            "ma_lop",
            "ma_mon",
            "ten_mon",
            "tong_tin_chi",
            "hoc_ky",
            "ten_hk",
            "giao_vien_ten",
            "lop_trang_thai",
            "lich_hoc",
            "trang_thai",
            "ngay_dang_ky",
            "ngay_huy",
            "ly_do_huy",
            "ma_sv",
            "ho_ten",
            "nganh_ten",
        ]
        read_only_fields = fields


class RegistrationResultSerializer(RegistrationSerializer):
    """Phản hồi `POST`/`DELETE`: bản ghi + `warnings[]` (cảnh báo không chặn, mục 8.4)."""

    warnings = WarningSerializer(many=True, read_only=True)

    class Meta(RegistrationSerializer.Meta):
        fields = [*RegistrationSerializer.Meta.fields, "warnings"]
        read_only_fields = fields


class RegistrationCreateSerializer(serializers.Serializer):
    lop_hoc_phan = serializers.IntegerField()


class CancelSerializer(serializers.Serializer):
    ly_do = serializers.CharField(required=False, allow_blank=True, max_length=255)


class ClassBriefSerializer(serializers.ModelSerializer):
    """Lớp học phần cho SV/GV (lớp có thể đăng ký, thời khóa biểu). `khoi_kien_thuc`, `loai_mon`,
    `hoc_ky_goi_y` lấy từ CTĐT của SV (context `cau_hinh_mon`)."""

    ma_mon = serializers.CharField(source="mon_hoc.ma_mon", read_only=True)
    ten_mon = serializers.CharField(source="mon_hoc.ten_mon", read_only=True)
    tong_tin_chi = serializers.IntegerField(source="mon_hoc.tong_tin_chi", read_only=True)
    giao_vien_ten = serializers.CharField(source="giao_vien.ho_ten", read_only=True)
    lich_hoc = ScheduleSerializer(many=True, read_only=True)
    khoi_kien_thuc = serializers.SerializerMethodField()
    loai_mon = serializers.SerializerMethodField()
    hoc_ky_goi_y = serializers.SerializerMethodField()

    class Meta:
        model = ClassSection
        fields = [
            "id",
            "ma_lop",
            "mon_hoc",
            "ma_mon",
            "ten_mon",
            "tong_tin_chi",
            "hoc_ky",
            "giao_vien",
            "giao_vien_ten",
            "si_so_toi_da",
            "si_so_hien_tai",
            "ngay_bat_dau",
            "ngay_ket_thuc",
            "trang_thai",
            "lich_hoc",
            "khoi_kien_thuc",
            "loai_mon",
            "hoc_ky_goi_y",
        ]
        read_only_fields = fields

    def _cc(self, obj):
        return self.context.get("cau_hinh_mon", {}).get(obj.mon_hoc_id)

    def get_khoi_kien_thuc(self, obj) -> str | None:
        cc = self._cc(obj)
        return cc.khoi_kien_thuc if cc else None

    def get_loai_mon(self, obj) -> str | None:
        cc = self._cc(obj)
        return cc.loai_mon if cc else None

    def get_hoc_ky_goi_y(self, obj) -> int | None:
        cc = self._cc(obj)
        return cc.hoc_ky_goi_y if cc else None


class AvailableMetaSerializer(serializers.Serializer):
    hoc_ky = serializers.IntegerField()
    ten_hk = serializers.CharField()
    trong_cua_so = serializers.BooleanField()
    tin_chi_toi_thieu = serializers.IntegerField()
    tin_chi_toi_da = serializers.IntegerField()
    tin_chi_toi_da_canh_bao = serializers.IntegerField()
    tin_chi_da_dang_ky = serializers.IntegerField()
    bi_canh_bao_hoc_vu = serializers.BooleanField()


class AvailableCoursesSerializer(serializers.Serializer):
    """Chỉ để mô tả Swagger: phân trang DRF + `meta`."""

    count = serializers.IntegerField()
    next = serializers.CharField(allow_null=True)
    previous = serializers.CharField(allow_null=True)
    results = ClassBriefSerializer(many=True)
    meta = AvailableMetaSerializer()


class MyCurriculumCourseSerializer(serializers.Serializer):
    mon_hoc = serializers.IntegerField()
    ma_mon = serializers.CharField()
    ten_mon = serializers.CharField()
    tong_tin_chi = serializers.IntegerField()
    khoi_kien_thuc = serializers.CharField()
    loai_mon = serializers.CharField()
    hoc_ky_goi_y = serializers.IntegerField()
    da_dat = serializers.BooleanField()
    tien_quyet = serializers.ListField(child=serializers.CharField())


class MyCurriculumSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    ma_ctdt = serializers.CharField()
    nganh_ten = serializers.CharField()
    khoa_tuyen_sinh = serializers.CharField()
    tong_tin_chi_yeu_cau = serializers.IntegerField()
    mon = MyCurriculumCourseSerializer(many=True)


class HocKyCoLopSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    ten_hk = serializers.CharField()


class TimetableSerializer(serializers.Serializer):
    hoc_ky = serializers.IntegerField()
    ten_hk = serializers.CharField()
    cac_hoc_ky = HocKyCoLopSerializer(many=True)  # kỳ tôi có lớp (+ kỳ đang xem), mới nhất trước
    ngay_bat_dau = serializers.DateField()
    ngay_ket_thuc = serializers.DateField()
    lop_hoc_phan = ClassBriefSerializer(many=True)
