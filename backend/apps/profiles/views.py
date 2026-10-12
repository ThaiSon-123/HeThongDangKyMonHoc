from django.db.models import Q
from drf_spectacular.utils import extend_schema
from rest_framework import mixins, viewsets
from rest_framework.exceptions import ValidationError
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.auth.models import Role, User
from apps.profiles import services
from apps.profiles.models import StudentProfile, TeacherProfile
from apps.profiles.serializers import (
    ContactSerializer,
    MeSerializer,
    PendingAccountSerializer,
    StudentProfileSerializer,
    TeacherProfileSerializer,
)
from core.mixins import AuditLogMixin
from core.permissions import ReadByAdminWriteByPdt


class MeView(APIView):
    """GET/PATCH /api/profiles/me/ — mọi vai trò; chỉ sửa email, sdt (không sửa trường học vụ)."""

    @extend_schema(responses=MeSerializer)
    def get(self, request):
        return Response(services.profile_payload(request.user))

    @extend_schema(request=ContactSerializer, responses=MeSerializer)
    def patch(self, request):
        cam = set(request.data) - services.CONTACT_FIELDS
        if cam:
            raise ValidationError({f: ["Không được sửa trường này."] for f in sorted(cam)})
        s = ContactSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        return Response(services.update_contact(request.user, s.validated_data))


class _ProfileViewSet(AuditLogMixin):
    permission_classes = [ReadByAdminWriteByPdt]
    http_method_names = ["get", "post", "patch", "head", "options"]
    ordering = ["-id"]


class StudentProfileViewSet(_ProfileViewSet):
    audit_model = "StudentProfile"
    queryset = StudentProfile.objects.select_related("user", "nganh", "ctdt")
    serializer_class = StudentProfileSerializer
    filterset_fields = ["nganh", "khoa_nhap_hoc", "ctdt"]
    search_fields = ["ma_sv", "ho_ten", "user__username"]
    ordering_fields = ["id", "ma_sv", "ho_ten"]


class TeacherProfileViewSet(_ProfileViewSet):
    audit_model = "TeacherProfile"
    queryset = TeacherProfile.objects.select_related("user", "khoa")
    serializer_class = TeacherProfileSerializer
    filterset_fields = ["khoa"]
    search_fields = ["ma_gv", "ho_ten", "user__username"]
    ordering_fields = ["id", "ma_gv", "ho_ten"]


class PendingAccountViewSet(mixins.ListModelMixin, viewsets.GenericViewSet):
    """GET /api/profiles/pending-accounts/ — tài khoản SV/GV chưa có hồ sơ (để PĐT tạo hồ sơ, PDT-01)."""

    permission_classes = [ReadByAdminWriteByPdt]
    serializer_class = PendingAccountSerializer
    queryset = User.objects.filter(
        Q(role=Role.SINH_VIEN, sinh_vien__isnull=True)
        | Q(role=Role.GIAO_VIEN, giang_vien__isnull=True)
    )
    filterset_fields = ["role"]
    search_fields = ["username", "email"]
    ordering_fields = ["id", "username"]
    ordering = ["id"]
