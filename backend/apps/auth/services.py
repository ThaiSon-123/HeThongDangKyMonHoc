"""Nghiệp vụ xác thực (BR-22): đăng nhập, đổi/đặt lại mật khẩu, thu hồi refresh token."""

import hashlib
import logging
import secrets

from django.conf import settings
from django.contrib.auth import authenticate, password_validation
from django.contrib.auth.models import update_last_login
from django.core.cache import cache
from django.core.exceptions import ValidationError as DjangoValidationError
from django.core.mail import send_mail
from django.utils.crypto import constant_time_compare, salted_hmac
from django.utils.html import format_html
from rest_framework.exceptions import AuthenticationFailed, ValidationError
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.token_blacklist.models import BlacklistedToken, OutstandingToken
from rest_framework_simplejwt.tokens import RefreshToken

from apps.audit.models import AuditLog, HanhDong
from apps.auth.models import User
from core.exceptions import Codes, business_error
from core.utils import client_ip

logger = logging.getLogger(__name__)

RESET_MESSAGE = "Đã gửi mã xác thực đặt lại mật khẩu tới email của bạn."


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
# Mã xác thực 6 số gửi qua email, lưu dạng HMAC trong cache (Redis) theo email; sống
# PASSWORD_RESET_TIMEOUT (30 phút), dùng 1 lần, sai quá RESET_MAX_TRIES lần thì mã bị hủy.

RESET_MAX_TRIES = 5
RESET_CODE_INVALID = "Mã xác thực không đúng hoặc đã hết hạn."


def _reset_key(email):
    return "pwreset:" + hashlib.sha256(email.strip().lower().encode()).hexdigest()


def _hash_code(email, code):
    return salted_hmac("pwreset", f"{email.strip().lower()}:{code}").hexdigest()


def _reset_email_html(name, code):
    minutes = settings.PASSWORD_RESET_TIMEOUT // 60
    return format_html(
        '<div style="font-family:Arial,sans-serif;background:#F4F5FA;padding:32px 16px">'
        '<div style="max-width:480px;margin:0 auto;background:#fff;border-radius:16px;'
        'overflow:hidden;border:1px solid #E3E6EE">'
        '<div style="background:#1F2A5C;color:#fff;padding:20px 28px;font-size:18px;'
        'font-weight:700">Hệ thống Đăng ký Môn học</div>'
        '<div style="padding:28px;color:#212121;font-size:15px;line-height:1.6">'
        "<p>Xin chào <b>{}</b>,</p>"
        "<p>Bạn vừa yêu cầu đặt lại mật khẩu. Mã xác thực của bạn là:</p>"
        '<div style="margin:20px 0;text-align:center;font-size:34px;font-weight:700;'
        "letter-spacing:10px;color:#3F51B5;background:#E8EAF6;border-radius:12px;"
        'padding:16px 0">{}</div>'
        "<p>Mã có hiệu lực <b>{} phút</b> và chỉ dùng được một lần.</p>"
        '<p style="color:#6B7280;font-size:13px">Nếu bạn không yêu cầu, hãy bỏ qua email '
        "này — mật khẩu của bạn vẫn giữ nguyên. Không chia sẻ mã cho bất kỳ ai.</p>"
        "</div></div></div>",
        name,
        code,
        minutes,
    )


def request_password_reset(email):
    """Gửi mã xác thực tới email của tài khoản. Email không có trong hệ thống / tài khoản bị khóa
    → 400 field `email` (chấp nhận lộ email có tồn tại: email SV vốn suy ra được từ mã SV; rate limit
    3 lần/15 phút/email vẫn chặn dò hàng loạt). Trả mã (chỉ để dev trả về trong response)."""
    users = list(User.objects.filter(email__iexact=email, is_active=True))
    if not users:
        raise ValidationError({"email": ["Email này không có trong hệ thống."]})
    users = [u for u in users if not u.is_locked]
    if not users:
        raise ValidationError(
            {"email": ["Tài khoản gắn với email này đang bị khóa. Liên hệ Phòng đào tạo."]}
        )
    code = f"{secrets.randbelow(10**6):06d}"
    key = _reset_key(email)
    cache.set(key, _hash_code(email, code), settings.PASSWORD_RESET_TIMEOUT)
    cache.set(f"{key}:tries", 0, settings.PASSWORD_RESET_TIMEOUT)
    minutes = settings.PASSWORD_RESET_TIMEOUT // 60
    try:
        send_mail(
            f"[{code}] Mã xác thực đặt lại mật khẩu",
            f"Mã xác thực đặt lại mật khẩu của bạn: {code}\n\n"
            f"Mã có hiệu lực {minutes} phút và chỉ dùng được một lần. "
            "Nếu bạn không yêu cầu, hãy bỏ qua email này.\n",
            None,
            [users[0].email],
            html_message=_reset_email_html(full_name(users[0]), code),
        )
    except Exception:  # lỗi SMTP không được làm lộ email có tồn tại → chỉ log
        logger.exception("Không gửi được mail đặt lại mật khẩu cho user %s", users[0].pk)
    return code if settings.PASSWORD_RESET_RETURN_TOKEN_IN_RESPONSE else None


def confirm_password_reset(email, code, new_password):
    """Mọi tài khoản dùng chung email đều được đặt lại (người giữ hộp thư là chủ của tất cả)."""
    key = _reset_key(email)
    stored = cache.get(key)
    try:
        tries = cache.incr(f"{key}:tries")  # atomic trên Redis → đoán song song không lách được
    except ValueError:  # khóa đếm đã hết hạn
        tries = RESET_MAX_TRIES + 1
    if stored is None or tries > RESET_MAX_TRIES:
        cache.delete_many([key, f"{key}:tries"])
        raise ValidationError({"code": [RESET_CODE_INVALID]})
    if not constant_time_compare(stored, _hash_code(email, code)):
        raise ValidationError({"code": [RESET_CODE_INVALID]})
    users = list(User.objects.filter(email__iexact=email, is_active=True, is_locked=False))
    if not users:
        raise ValidationError({"code": [RESET_CODE_INVALID]})
    check_password_policy(new_password, users[0])
    for user in users:
        user.set_password(new_password)
        user.save(update_fields=["password"])
        revoke_refresh_tokens(user)
    cache.delete_many([key, f"{key}:tries"])
