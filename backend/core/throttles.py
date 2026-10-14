"""Giới hạn tần suất chung cho thao tác ghi (plan.md mục 8.2: 120 lần/phút/người dùng)."""

from rest_framework.permissions import SAFE_METHODS
from rest_framework.throttling import UserRateThrottle


class WriteThrottle(UserRateThrottle):
    """Chỉ đếm POST/PUT/PATCH/DELETE; đọc (GET/HEAD/OPTIONS) không bị giới hạn. Đếm theo người dùng,
    chưa đăng nhập thì theo IP (đã tính `NUM_PROXIES`). Đăng nhập / quên mật khẩu / đăng ký môn còn có
    giới hạn riêng chặt hơn (`throttle_scope`)."""

    scope = "write"

    def allow_request(self, request, view):
        if request.method in SAFE_METHODS:
            return True
        return super().allow_request(request, view)
