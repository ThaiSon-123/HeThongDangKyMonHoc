"""Nghiệp vụ xác thực (BR-22): đăng nhập, đổi/đặt lại mật khẩu, thu hồi refresh token."""

import logging

from django.conf import settings
from django.contrib.auth import authenticate, password_validation
from django.contrib.auth.models import update_last_login
from django.contrib.auth.tokens import default_token_generator
from django.core.exceptions import ValidationError as DjangoValidationError
from django.core.mail import send_mail
from django.utils.encoding import force_bytes, force_str
from django.utils.http import urlsafe_base64_decode, urlsafe_base64_encode
from rest_framework.exceptions import AuthenticationFailed, ValidationError
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.token_blacklist.models import BlacklistedToken, OutstandingToken
from rest_framework_simplejwt.tokens import RefreshToken

from apps.audit.models import AuditLog, HanhDong
from apps.auth.models import User
from core.exceptions import Codes, business_error
from core.utils import client_ip

logger = logging.getLogger(__name__)

RESET_MESSAGE = "Nếu email tồn tại, chúng tôi đã gửi hướng dẫn đặt lại mật khẩu."


def full_name(user):
    """Họ tên hiển thị: ưu tiên hồ sơ SV/GV, sau đó `first_name`, cuối cùng `username`."""
    for related in ("sinh_vien", "giang_vien"):
        profile = getattr(user, related, None)
        if profile is not None:
            return profile.ho_ten
    return user.first_name or user.username


def user_payload(user):
    return {
        "id": user.id,
        "username": user.username,
        "full_name": full_name(user),
        "role": user.role,
        "email": user.email,
    }


def check_password_policy(password, user=None, field="new_password"):
    """Áp chính sách mật khẩu (AUTH_PASSWORD_VALIDATORS); lỗi dạng field-level → 400."""
    try:
        password_validation.validate_password(password, user)
    except DjangoValidationError as e:
        raise ValidationError({field: list(e.messages)}) from e


def revoke_refresh_tokens(user):
    """Blacklist mọi refresh token còn hiệu lực của user (đổi/reset mật khẩu)."""
    for token in OutstandingToken.objects.filter(user=user):
        BlacklistedToken.objects.get_or_create(token=token)


def login(request, username, password):
    user = authenticate(request, username=username, password=password)
    if user is None:  # sai user hoặc sai mật khẩu → cùng một lỗi, không lộ user có tồn tại
        raise AuthenticationFailed("Sai tên đăng nhập hoặc mật khẩu.")
    if user.is_locked:  # chỉ lộ trạng thái khóa SAU khi đã đúng mật khẩu
        raise business_error(Codes.TAI_KHOAN_BI_KHOA, "Tài khoản đang bị khóa.")
    refresh = RefreshToken.for_user(user)
    update_last_login(None, user)
    AuditLog.objects.create(
        user=user,
        hanh_dong=HanhDong.LOGIN,
        doi_tuong="User",
        doi_tuong_id=str(user.pk),
        ip=client_ip(request),
    )
    return {
        "access": str(refresh.access_token),
        "refresh": str(refresh),
        "user": user_payload(user),
    }


def logout(user, raw_refresh):
    """Blacklist refresh token. Token hỏng/đã dùng coi như đã đăng xuất; token người khác → 400."""
    try:
        token = RefreshToken(raw_refresh)
    except TokenError:
        return
    if str(token["user_id"]) != str(user.pk):  # simplejwt ≥ 5.5 lưu claim dạng chuỗi
        raise ValidationError({"refresh": ["Token không thuộc tài khoản này."]})
    token.blacklist()


def change_password(user, old_password, new_password):
    if not user.check_password(old_password):
        raise ValidationError({"old_password": ["Mật khẩu hiện tại không đúng."]})
    check_password_policy(new_password, user)
    user.set_password(new_password)
    user.save(update_fields=["password"])
    revoke_refresh_tokens(user)


def admin_reset_password(user, new_password):
    check_password_policy(new_password, user)
    user.set_password(new_password)
    user.save(update_fields=["password"])
    revoke_refresh_tokens(user)


# ---- quên / đặt lại mật khẩu -------------------------------------------------
# Token = "<uid base64>.<token Django>". Django gắn hash mật khẩu + last_login vào token nên
# dùng 1 lần là tự nhiên (đổi mật khẩu xong token cũ vô hiệu); TTL = PASSWORD_RESET_TIMEOUT (30 phút).


def _make_reset_token(user):
    uid = urlsafe_base64_encode(force_bytes(user.pk))
    return f"{uid}.{default_token_generator.make_token(user)}"


def _user_from_reset_token(token):
    try:
        uid, raw = token.split(".", 1)
        user = User.objects.get(pk=force_str(urlsafe_base64_decode(uid)))
    except (ValueError, TypeError, OverflowError, User.DoesNotExist):
        return None
    if user.is_locked or not user.is_active:
        return None
    return user if default_token_generator.check_token(user, raw) else None


def request_password_reset(email):
    """Gửi mail hướng dẫn nếu có tài khoản khớp. Trả token đầu tiên (chỉ để dev trả về trong
    response); view luôn trả cùng một phản hồi dù có hay không."""
    first_token = None
    for user in User.objects.filter(email__iexact=email, is_active=True, is_locked=False):
        token = _make_reset_token(user)
        first_token = first_token or token
        try:
            send_mail(
                "Đặt lại mật khẩu — Hệ thống Đăng ký Môn học",
                f"Mã đặt lại mật khẩu (hiệu lực 30 phút, dùng 1 lần):\n\n{token}\n",
                None,
                [user.email],
            )
        except Exception:  # lỗi SMTP không được làm lộ email có tồn tại → chỉ log
            logger.exception("Không gửi được mail đặt lại mật khẩu cho user %s", user.pk)
    return first_token if settings.PASSWORD_RESET_RETURN_TOKEN_IN_RESPONSE else None


def confirm_password_reset(token, new_password):
    user = _user_from_reset_token(token)
    if user is None:
        raise ValidationError({"token": ["Token không hợp lệ hoặc đã hết hạn."]})
    check_password_policy(new_password, user)
    user.set_password(new_password)
    user.save(update_fields=["password"])
    revoke_refresh_tokens(user)
