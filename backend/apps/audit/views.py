"""`GET /api/admin/audit-logs/` (ADM-06): Admin xem tất cả; PĐT chỉ scope `training`; KT chỉ `finance`."""

import django_filters
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework import generics

from apps.audit.models import SCOPE_FINANCE, SCOPE_TRAINING, AuditLog
from apps.audit.serializers import AuditLogSerializer
from apps.auth.models import Role
from core.permissions import HasRole


class NguoiXemNhatKy(HasRole):
    roles = (Role.ADMIN, Role.PHONG_DAO_TAO, Role.KE_TOAN)


class AuditLogFilter(django_filters.FilterSet):
    nguoi_thuc_hien = django_filters.CharFilter(
        field_name="user__username", lookup_expr="icontains"
    )
    tu_ngay = django_filters.DateFilter(field_name="thoi_gian", lookup_expr="date__gte")
    den_ngay = django_filters.DateFilter(field_name="thoi_gian", lookup_expr="date__lte")
    doi_tuong = django_filters.CharFilter(lookup_expr="iexact")
    scope = django_filters.ChoiceFilter(
        choices=[("training", "training"), ("finance", "finance"), ("other", "other")],
        method="loc_scope",
        help_text="Chỉ thu hẹp thêm; phạm vi tối đa do vai trò quyết định.",
    )

    class Meta:
        model = AuditLog
        fields = ["hanh_dong"]

    def loc_scope(self, qs, name, value):
        if value == "training":
            return qs.filter(doi_tuong__in=SCOPE_TRAINING)
        if value == "finance":
            return qs.filter(doi_tuong__in=SCOPE_FINANCE)
        return qs.exclude(doi_tuong__in=SCOPE_TRAINING | SCOPE_FINANCE)


class AuditLogListView(generics.ListAPIView):
    permission_classes = [NguoiXemNhatKy]
    serializer_class = AuditLogSerializer
    filterset_class = AuditLogFilter
    search_fields = ["doi_tuong", "doi_tuong_id", "user__username"]
    ordering_fields = ["thoi_gian", "id"]
    ordering = ["-thoi_gian", "-id"]

    def get_queryset(self):
        qs = AuditLog.objects.select_related("user")
        if getattr(self, "swagger_fake_view", False):
            return qs.none()
        role = self.request.user.role
        if role == Role.PHONG_DAO_TAO:
            return qs.filter(doi_tuong__in=SCOPE_TRAINING)
        if role == Role.KE_TOAN:
            return qs.filter(doi_tuong__in=SCOPE_FINANCE)
        return qs  # Admin: tất cả

    @extend_schema(parameters=[OpenApiParameter("page", int), OpenApiParameter("page_size", int)])
    def get(self, request, *args, **kwargs):
        return super().get(request, *args, **kwargs)
