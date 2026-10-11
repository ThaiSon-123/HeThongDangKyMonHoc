"""JWT + khóa tài khoản (BR-22). Tài khoản `is_locked` không được đăng nhập."""

from rest_framework_simplejwt.authentication import JWTAuthentication

from core.exceptions import Codes, business_error


class LockedAwareJWTAuthentication(JWTAuthentication):
    def get_user(self, validated_token):
        user = super().get_user(validated_token)
        if getattr(user, "is_locked", False):
            raise business_error(Codes.TAI_KHOAN_BI_KHOA, "Tài khoản đang bị khóa.")
        return user
