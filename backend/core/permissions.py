"""Quyền theo vai trò (plan.md mục 13.8, BR-21/23) — backend là nơi kiểm tra, không tin frontend."""

from rest_framework.permissions import SAFE_METHODS, BasePermission

from apps.auth.models import Role
from core.exceptions import Codes, business_error

ALL = tuple(Role.values)


class HasRole(BasePermission):
    """Cho phép nếu user.role nằm trong `roles`."""

    roles: tuple[str, ...] = ALL

    def has_permission(self, request, view):
        roles = getattr(view, "roles", None) or self.roles
        user = request.user
        if not (user and user.is_authenticated):
            return False
        if getattr(user, "role", None) in roles:
            return True
        raise business_error(Codes.KHONG_CO_QUYEN, "Bạn không có quyền thực hiện thao tác này.")


class IsAdmin(HasRole):
    roles = (Role.ADMIN,)


class IsPhongDaoTao(HasRole):
    roles = (Role.PHONG_DAO_TAO,)


class IsKeToan(HasRole):
    roles = (Role.KE_TOAN,)


class IsSinhVien(HasRole):
    roles = (Role.SINH_VIEN,)


class IsGiaoVien(HasRole):
    roles = (Role.GIAO_VIEN,)


class IsAdminOrPhongDaoTao(HasRole):
    roles = (Role.ADMIN, Role.PHONG_DAO_TAO)


class ReadByAdminWriteByPdt(BasePermission):
    """PĐT đọc + ghi; Admin chỉ đọc (PDT-01 / ADM-03); vai trò khác bị từ chối."""

    def has_permission(self, request, view):
        user = request.user
        if not (user and user.is_authenticated):
            return False
        if user.role == Role.PHONG_DAO_TAO:
            return True
        if user.role == Role.ADMIN and request.method in SAFE_METHODS:
            return True
        raise business_error(Codes.KHONG_CO_QUYEN, "Bạn không có quyền thực hiện thao tác này.")
