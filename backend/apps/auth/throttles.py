import hashlib

from rest_framework.throttling import SimpleRateThrottle


class ForgotPasswordThrottle(SimpleRateThrottle):
    """3 lần / 15 phút / email (plan.md mục 8.2). Đếm theo email, không theo IP, và đếm cả
    email không tồn tại để phản hồi không lộ email nào có trong hệ thống.

    DRF chỉ parse được "3/min", "3/hour"… (không có "15min") nên tự khai báo số liệu."""

    scope = "forgot_password"

    def get_rate(self):
        return "3/15min"

    def parse_rate(self, rate):
        return 3, 15 * 60

    def get_cache_key(self, request, view):
        email = str(request.data.get("email", "")).strip().lower()
        if not email:
            return None
        ident = hashlib.sha256(email.encode()).hexdigest()
        return self.cache_format % {"scope": self.scope, "ident": ident}
