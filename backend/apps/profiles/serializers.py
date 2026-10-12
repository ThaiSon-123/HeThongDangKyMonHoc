from django.core.validators import RegexValidator
from rest_framework import serializers

from apps.auth.models import Role, User
from apps.auth.serializers import UserBriefSerializer
from apps.profiles import services
from apps.profiles.models import StudentProfile, TeacherProfile
from apps.training.models import Curriculum, TrangThaiDung

SDT_VALIDATOR = RegexValidator(r"^\+?[0-9]{8,14}$", "Số điện thoại không hợp lệ.")


class ContactSerializer(serializers.Serializer):
    """PATCH /profiles/me/ — chỉ email, sdt."""

    email = serializers.EmailField(required=False)
    sdt = serializers.CharField(required=False, allow_blank=True, validators=[SDT_VALIDATOR])


class _ProfileBase(serializers.ModelSerializer):
    username = serializers.CharField(source="user.username", read_only=True)
    ROLE: str

    def validate_user(self, user):
        if user.role != self.ROLE:
            raise serializers.ValidationError("Tài khoản không đúng vai trò của hồ sơ này.")
        return user

    def _sync(self, profile):
        services.sync_user_email(profile)
        return profile

    def create(self, validated_data):
        return self._sync(super().create(validated_data))

    def update(self, instance, validated_data):
        # user và mã (ma_sv/ma_gv) chỉ đặt lúc tạo hồ sơ.
        validated_data.pop("user", None)
        validated_data.pop(self.CODE_FIELD, None)
        return self._sync(super().update(instance, validated_data))


class StudentProfileSerializer(_ProfileBase):
    ROLE = Role.SINH_VIEN
    CODE_FIELD = "ma_sv"
    nganh_ten = serializers.CharField(source="nganh.ten_nganh", read_only=True)
    ctdt_ma = serializers.CharField(source="ctdt.ma_ctdt", read_only=True, default=None)
    sdt = serializers.CharField(required=False, allow_blank=True, validators=[SDT_VALIDATOR])

    class Meta:
        model = StudentProfile
        fields = [
            "id",
            "user",
            "username",
            "ma_sv",
            "ho_ten",
            "nganh",
            "nganh_ten",
            "khoa_nhap_hoc",
            "ctdt",
            "ctdt_ma",
            "gpa",
            "tin_chi_tich_luy",
            "email",
            "sdt",
        ]
        read_only_fields = ["gpa", "tin_chi_tich_luy"]  # cache BR-25, không nhập tay
        extra_kwargs = {"ctdt": {"required": False}}

    def validate(self, attrs):
        """`ctdt` gán tường minh (phải cùng ngành) hoặc suy ra từ (ngành, khóa) → CTĐT `HOAT_DONG`."""
        instance = self.instance
        nganh = attrs.get("nganh", instance.nganh if instance else None)
        khoa = attrs.get("khoa_nhap_hoc", instance.khoa_nhap_hoc if instance else None)
        ctdt = attrs.get("ctdt")
        if ctdt is not None:
            if ctdt.nganh_id != nganh.id:
                raise serializers.ValidationError({"ctdt": ["CTĐT không thuộc ngành đã chọn."]})
        elif instance is None or "nganh" in attrs or "khoa_nhap_hoc" in attrs:
            ctdt = Curriculum.objects.filter(
                nganh=nganh, khoa_tuyen_sinh=khoa, trang_thai=TrangThaiDung.HOAT_DONG
            ).first()
            if ctdt is None:
                raise serializers.ValidationError(
                    {"ctdt": ["Không có CTĐT đang hoạt động khớp ngành và khóa."]}
                )
            attrs["ctdt"] = ctdt
        return attrs


class TeacherProfileSerializer(_ProfileBase):
    ROLE = Role.GIAO_VIEN
    CODE_FIELD = "ma_gv"
    khoa_ten = serializers.CharField(source="khoa.ten_khoa", read_only=True)
    sdt = serializers.CharField(required=False, allow_blank=True, validators=[SDT_VALIDATOR])

    class Meta:
        model = TeacherProfile
        fields = [
            "id",
            "user",
            "username",
            "ma_gv",
            "ho_ten",
            "khoa",
            "khoa_ten",
            "hoc_vi",
            "email",
            "sdt",
        ]


class PendingAccountSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ["id", "username", "email", "role"]


class MeSerializer(UserBriefSerializer):
    """Payload của `GET/PATCH /profiles/me/` (chỉ để mô tả Swagger): trường học vụ phụ thuộc vai trò."""

    ma_sv = serializers.CharField(required=False)
    ma_gv = serializers.CharField(required=False)
    ho_ten = serializers.CharField(required=False)
    nganh = serializers.DictField(required=False)
    khoa_nhap_hoc = serializers.CharField(required=False)
    ctdt = serializers.DictField(required=False, allow_null=True)
    gpa = serializers.CharField(required=False, allow_null=True)
    tin_chi_tich_luy = serializers.IntegerField(required=False)
    xep_loai = serializers.CharField(required=False, allow_null=True)
    khoa = serializers.CharField(required=False)
    hoc_vi = serializers.CharField(required=False)
    sdt = serializers.CharField(required=False)
