from rest_framework import serializers
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.serializers import TokenRefreshSerializer
from rest_framework_simplejwt.tokens import RefreshToken

from apps.auth import services
from apps.auth.models import Role, User
from core.exceptions import Codes, business_error


class LoginSerializer(serializers.Serializer):
    username = serializers.CharField()
    password = serializers.CharField(trim_whitespace=False)


class LockedAwareRefreshSerializer(TokenRefreshSerializer):
    """Refresh có xoay vòng + blacklist; tài khoản bị khóa không refresh được (BR-22)."""

    def validate(self, attrs):
        refresh = RefreshToken(attrs["refresh"])  # TokenError (hỏng/hết hạn/đã blacklist) → 401
        user = User.objects.filter(pk=refresh["user_id"]).first()
        if user is None or not user.is_active:
            raise TokenError("Token không hợp lệ.")
        if user.is_locked:
            raise business_error(Codes.TAI_KHOAN_BI_KHOA, "Tài khoản đang bị khóa.")
        return super().validate(attrs)


class LogoutSerializer(serializers.Serializer):
    refresh = serializers.CharField()


class ChangePasswordSerializer(serializers.Serializer):
    old_password = serializers.CharField(trim_whitespace=False)
    new_password = serializers.CharField(trim_whitespace=False)


class ForgotPasswordSerializer(serializers.Serializer):
    email = serializers.EmailField()


class ResetPasswordSerializer(serializers.Serializer):
    token = serializers.CharField()
    new_password = serializers.CharField(trim_whitespace=False)


class NewPasswordSerializer(serializers.Serializer):
    new_password = serializers.CharField(trim_whitespace=False)


def _profile_of(user):
    """Hồ sơ học vụ gắn với tài khoản SV/GV (None nếu vai trò khác hoặc chưa có hồ sơ)."""
    if user.role == Role.SINH_VIEN:
        return getattr(user, "sinh_vien", None)
    if user.role == Role.GIAO_VIEN:
        return getattr(user, "giang_vien", None)
    return None


class UserSerializer(serializers.ModelSerializer):
    """Đọc tài khoản (ADM-02). Kèm tóm tắt hồ sơ học vụ để Admin biết tài khoản nào còn thiếu hồ sơ
    (PĐT mới là người tạo hồ sơ — PDT-01). Queryset nên `select_related` hồ sơ để tránh N+1."""

    full_name = serializers.SerializerMethodField()
    has_profile = serializers.SerializerMethodField()
    profile = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            "id",
            "username",
            "email",
            "full_name",
            "role",
            "is_locked",
            "is_active",
            "last_login",
            "date_joined",
            "has_profile",
            "profile",
        ]
        read_only_fields = fields

    def get_full_name(self, user) -> str:
        profile = _profile_of(user)
        return user.first_name or (profile.ho_ten if profile else "")

    def get_has_profile(self, user) -> bool | None:
        """`None` = vai trò không cần hồ sơ (Admin, PĐT, KT)."""
        if user.role not in (Role.SINH_VIEN, Role.GIAO_VIEN):
            return None
        return _profile_of(user) is not None

    def get_profile(self, user) -> dict | None:
        p = _profile_of(user)
        if p is None:
            return None
        if user.role == Role.SINH_VIEN:
            return {
                "ma_sv": p.ma_sv,
                "ho_ten": p.ho_ten,
                "nganh": p.nganh.ten_nganh,
                "khoa_nhap_hoc": p.khoa_nhap_hoc,
                "ctdt": p.ctdt.ma_ctdt if p.ctdt else None,
                "gpa": None if p.gpa is None else str(p.gpa),
                "tin_chi_tich_luy": p.tin_chi_tich_luy,
            }
        return {
            "ma_gv": p.ma_gv,
            "ho_ten": p.ho_ten,
            "khoa_bo_mon": p.khoa_bo_mon,
            "hoc_vi": p.hoc_vi,
        }


class UserCreateSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, trim_whitespace=False)
    full_name = serializers.CharField(source="first_name", required=False, allow_blank=True)
    role = serializers.ChoiceField(choices=Role.choices)

    class Meta:
        model = User
        fields = ["username", "password", "email", "full_name", "role"]

    def validate(self, attrs):
        services.check_password_policy(
            attrs["password"], User(username=attrs["username"]), "password"
        )
        return attrs

    def create(self, validated_data):
        return User.objects.create_user(**validated_data)

    def to_representation(self, instance):
        return UserSerializer(instance).data


class UserUpdateSerializer(serializers.ModelSerializer):
    """Sửa tài khoản: không đổi username/mật khẩu (mật khẩu có endpoint reset riêng)."""

    full_name = serializers.CharField(source="first_name", required=False, allow_blank=True)
    role = serializers.ChoiceField(choices=Role.choices, required=False)

    class Meta:
        model = User
        fields = ["email", "full_name", "role"]

    def validate_role(self, value):
        request = self.context["request"]
        if self.instance.pk == request.user.pk and value != self.instance.role:
            raise business_error(
                Codes.TRANG_THAI_KHONG_HOP_LE, "Không thể tự đổi vai trò của chính mình."
            )
        return value

    def to_representation(self, instance):
        return UserSerializer(instance).data


class LockSerializer(serializers.Serializer):
    is_locked = serializers.BooleanField()


class UserBriefSerializer(serializers.Serializer):
    """Payload `user` của login và nền của `profiles/me` (chỉ để mô tả Swagger)."""

    id = serializers.IntegerField()
    username = serializers.CharField()
    full_name = serializers.CharField()
    role = serializers.ChoiceField(choices=Role.choices)
    email = serializers.CharField(allow_blank=True)


class LoginResponseSerializer(serializers.Serializer):
    access = serializers.CharField()
    refresh = serializers.CharField()
    user = UserBriefSerializer()


class DetailSerializer(serializers.Serializer):
    detail = serializers.CharField()
    token = serializers.CharField(required=False, help_text="Chỉ có ở môi trường dev.")
