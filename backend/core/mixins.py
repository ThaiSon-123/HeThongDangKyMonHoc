"""Mixin dùng chung: AuditLogMixin (ghi audit log mọi thay đổi) và ScopeFilter (lọc theo vai trò)."""

from rest_framework import viewsets

from apps.audit.models import AuditLog, HanhDong
from core.permissions import Role


class AuditLogMixin(viewsets.ModelViewSet):
    """Ghi AuditLog cho mọi create/update/delete.

    View tự khai báo: audit_model = "Registration" (tên class thật trong doi_tuong).
    Không ghi log thao tác đọc.
    """

    audit_model: str | None = None
    audit_actions = {
        "create": HanhDong.CREATE,
        "update": HanhDong.UPDATE,
        "partial_update": HanhDong.UPDATE,
        "destroy": HanhDong.DELETE,
    }

    def _audit(self, hanh_dong, instance, chi_tiet=None):
        AuditLog.objects.create(
            user=getattr(self.request, "user", None),
            hanh_dong=hanh_dong,
            doi_tuong=self.audit_model or instance.__class__.__name__,
            doi_tuong_id=getattr(instance, "uuid", None) or getattr(instance, "id", None),
            chi_tiet=chi_tiet or {"serialized": self._safe_repr(instance)},
            ip=self._client_ip(),
        )

    @staticmethod
    def _safe_repr(instance):
        data = {}
        for field in instance._meta.fields:
            value = getattr(instance, field.attname, None)
            if isinstance(value, int | float | bool | str) or value is None:
                data[field.name] = value
            else:
                data[field.name] = str(value)
        return data

    def _client_ip(self):
        forwarded = self.request.META.get("HTTP_X_FORWARDED_FOR")
        if forwarded:
            return forwarded.split(",")[0].strip()
        return self.request.META.get("REMOTE_ADDR")

    def perform_create(self, serializer):
        instance = serializer.save()
        self._audit(HanhDong.CREATE, instance)
        return instance

    def perform_update(self, serializer):
        instance = serializer.save()
        self._audit(HanhDong.UPDATE, instance)
        return instance

    def perform_destroy(self, instance):
        self._audit(HanhDong.DELETE, instance)
        instance.delete()


class ScopeFilterMixin:
    """Lọc queryset theo scope của vai trò (BR-21/23).

    View đặt scope_fields = {"sinh_vien", "giang_vien"} để lọc theo quan hệ.
    """

    scope_fields: tuple[str, ...] = ()

    def get_queryset(self):
        qs = super().get_queryset()
        user = self.request.user
        if not (user and user.is_authenticated):
            return qs.none()
        if user.role in (Role.ADMIN, Role.PHONG_DAO_TAO):
            return qs
        # scope_fields trỏ tới FK User (`giang_vien`, `sinh_vien`, …) → `__id` chạy cho cả 2 vai trò.
        if user.role in (Role.GIAO_VIEN, Role.SINH_VIEN):
            return qs.filter(**{f"{f}__id": user.id for f in self.scope_fields})
        if user.role == Role.KE_TOAN:
            return qs
        return qs.none()
