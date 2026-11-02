from django.conf import settings
from django.db import transaction
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import extend_schema, inline_serializer
from rest_framework import serializers, status
from rest_framework.decorators import action
from rest_framework.exceptions import ValidationError
from rest_framework.parsers import MultiPartParser
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.views import APIView
from rest_framework_simplejwt.views import TokenViewBase

from apps.audit.models import HanhDong
from apps.auth import nhap_excel, services
from apps.auth.models import User
from apps.auth.serializers import (
    ChangePasswordSerializer,
    DetailSerializer,
    ForgotPasswordSerializer,
    LockedAwareRefreshSerializer,
    LockSerializer,
    LoginResponseSerializer,
    LoginSerializer,
    LogoutSerializer,
    NewPasswordSerializer,
    ResetPasswordSerializer,
    UserCreateSerializer,
    UserSerializer,
    UserUpdateSerializer,
)
from apps.auth.throttles import ForgotPasswordThrottle
from core.exceptions import Codes, business_error
from core.export import XLSX
from core.mixins import AuditLogMixin
from core.permissions import IsAdmin


class PublicView(APIView):
    """View không cần đăng nhập. Luôn trả 401 (không phải 403) khi AuthenticationFailed."""

    authentication_classes: list = []
    permission_classes = [AllowAny]

    def get_authenticate_header(self, request):
        return 'Bearer realm="api"'


class LoginView(PublicView):
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "login"

    @extend_schema(request=LoginSerializer, responses={200: LoginResponseSerializer})
    def post(self, request):
        s = LoginSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        return Response(services.login(request, **s.validated_data))


class RefreshView(TokenViewBase):
    serializer_class = LockedAwareRefreshSerializer


class LogoutView(APIView):
    @extend_schema(request=LogoutSerializer, responses={204: None})
    def post(self, request):
        s = LogoutSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        services.logout(request.user, s.validated_data["refresh"])
        return Response(status=status.HTTP_204_NO_CONTENT)


class ChangePasswordView(APIView):
    @extend_schema(request=ChangePasswordSerializer, responses={204: None})
    def post(self, request):
        s = ChangePasswordSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        services.change_password(request.user, **s.validated_data)
        return Response(status=status.HTTP_204_NO_CONTENT)


class ForgotPasswordView(PublicView):
    throttle_classes = [ForgotPasswordThrottle]

    @extend_schema(request=ForgotPasswordSerializer, responses={200: DetailSerializer})
    def post(self, request):
        s = ForgotPasswordSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        code = services.request_password_reset(s.validated_data["email"])
        body = {"detail": services.RESET_MESSAGE}
        if code and settings.PASSWORD_RESET_RETURN_TOKEN_IN_RESPONSE:
            body["code"] = code  # chỉ dev
        return Response(body)


class ResetPasswordView(PublicView):
    @extend_schema(request=ResetPasswordSerializer, responses={204: None})
    def post(self, request):
        s = ResetPasswordSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        services.confirm_password_reset(**s.validated_data)
        return Response(status=status.HTTP_204_NO_CONTENT)


class UserViewSet(AuditLogMixin):
    """Quản lý tài khoản (ADM-02) — chỉ Admin; không xóa, không PUT."""

    audit_model = "User"
    queryset = User.objects.select_related(
        "sinh_vien__nganh", "sinh_vien__ctdt", "giang_vien__khoa"
    )
    permission_classes = [IsAuthenticated, IsAdmin]
    http_method_names = ["get", "post", "patch", "head", "options"]
    filterset_fields = ["role", "is_locked", "is_active"]
    search_fields = ["username", "email", "first_name"]
    ordering_fields = ["id", "username", "last_login", "date_joined"]
    ordering = ["-id"]

    def get_serializer_class(self):
        if self.action == "create":
            return UserCreateSerializer
        if self.action == "partial_update":
            return UserUpdateSerializer
        return UserSerializer

    def perform_update(self, serializer):
        role_cu = serializer.instance.role
        instance = serializer.save()
        doi_role = instance.role != role_cu
        self._audit(
            HanhDong.PHAN_QUYEN if doi_role else HanhDong.UPDATE,
            instance,
            {"role": [role_cu, instance.role]} if doi_role else None,
        )

    @extend_schema(request=LockSerializer, responses={200: UserSerializer})
    @action(detail=True, methods=["patch"])
    def lock(self, request, pk=None):
        user = self.get_object()
        s = LockSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        is_locked = s.validated_data["is_locked"]
        if is_locked and user.pk == request.user.pk:
            raise business_error(
                Codes.TRANG_THAI_KHONG_HOP_LE, "Không thể tự khóa tài khoản của chính mình."
            )
        user.is_locked = is_locked
        user.save(update_fields=["is_locked"])
        self._audit(HanhDong.UPDATE, user, {"is_locked": is_locked})
        return Response(UserSerializer(user).data)

    @extend_schema(request=NewPasswordSerializer, responses={204: None})
    @action(detail=True, methods=["post"], url_path="reset-password")
    def reset_password(self, request, pk=None):
        user = self.get_object()
        s = NewPasswordSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        services.admin_reset_password(user, s.validated_data["new_password"])
        self._audit(HanhDong.UPDATE, user, {"hanh_dong": "reset_password"})
        return Response(status=status.HTTP_204_NO_CONTENT)

    @extend_schema(responses={(200, XLSX): OpenApiTypes.BINARY})
    @action(detail=False, methods=["get"], url_path="import-template")
    def import_template(self, request):
        """File Excel mẫu để tạo tài khoản hàng loạt."""
        return nhap_excel.file_mau()

    @extend_schema(
        request={
            "multipart/form-data": inline_serializer(
                "UserImport",
                {
                    "file": serializers.FileField(),
                    "xac_nhan": serializers.BooleanField(required=False),
                },
            )
        },
        responses=OpenApiTypes.OBJECT,
    )
    @action(detail=False, methods=["post"], url_path="import", parser_classes=[MultiPartParser])
    def import_excel(self, request):
        """Đọc file Excel theo mẫu → `{rows[], hop_le, loi}` (mỗi dòng kèm `loi[]`; không trả mật khẩu).
        `xac_nhan=true`: tạo các dòng hợp lệ (bỏ qua dòng lỗi) → thêm `da_tao`. Sai mẫu → `400` field `file`."""
        rows = nhap_excel.doc_file(request.FILES.get("file"))
        hop_le = sum(1 for r in rows if not r["loi"])
        body = {"rows": nhap_excel.xem_truoc(rows), "hop_le": hop_le, "loi": len(rows) - hop_le}
        if str(request.data.get("xac_nhan", "")).lower() in ("1", "true"):
            if not hop_le:
                raise ValidationError({"file": ["Không có tài khoản hợp lệ nào để tạo."]})
            with transaction.atomic():
                for u in nhap_excel.tao_tai_khoan(rows):
                    self._audit(HanhDong.CREATE, u, {"hanh_dong": "nhap_excel", "role": u.role})
            body["da_tao"] = hop_le
        return Response(body)
