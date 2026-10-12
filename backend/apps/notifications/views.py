"""API thông báo (ADM-07, PDT-13, GV-11, SV-13): hộp thư, đã đọc, gửi, thu hồi."""

from django.db.models import Q
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework import viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import NotFound
from rest_framework.response import Response

from apps.audit.models import HanhDong
from apps.auth.models import Role, User
from apps.notifications import services
from apps.notifications.models import Audience, Notification, TrangThaiThongBao
from apps.notifications.serializers import (
    NotificationCreateSerializer,
    NotificationListSerializer,
    NotificationSerializer,
    RecipientSerializer,
)
from apps.training.models import ClassSection
from core.exceptions import Codes, business_error
from core.mixins import write_audit
from core.pagination import StandardPagination
from core.permissions import HasRole


class MoiVaiTro(HasRole):
    """Mọi vai trò đăng nhập đều nhận thông báo."""


class NguoiGui(HasRole):
    roles = (Role.ADMIN, Role.PHONG_DAO_TAO, Role.KE_TOAN, Role.GIAO_VIEN)


class NotificationViewSet(viewsets.GenericViewSet):
    """`GET/POST /api/notifications/`, `PATCH …/{id}/read/`, `POST …/read-all/`, `DELETE …/{id}/`."""

    serializer_class = NotificationSerializer
    pagination_class = StandardPagination
    queryset = Notification.objects.all()
    filter_backends: list = []

    def get_permissions(self):
        if self.action in ("create", "recipients"):
            return [NguoiGui()]
        return [MoiVaiTro()]

    def _hop_thu(self):
        return services.hop_thu(self.request.user)

    def _dich_vu(self, ds, request, **extra):
        page = self.paginate_queryset(ds)
        res = self.get_paginated_response(
            self.get_serializer(page, many=True, context={"request": request}).data
        )
        res.data.update(extra)
        return res

    @extend_schema(
        parameters=[
            OpenApiParameter("da_doc", bool, description="false = chỉ chưa đọc"),
            OpenApiParameter("gui", bool, description="true = thông báo tôi đã gửi"),
        ],
        responses=NotificationListSerializer,
    )
    def list(self, request):
        """Thông báo của mình (hoặc `?gui=true`: thông báo mình đã gửi, kể cả đã thu hồi)."""
        if request.query_params.get("gui") in ("1", "true", "True"):
            ds = list(
                Notification.objects.filter(nguoi_gui=request.user)
                .select_related("nguoi_gui")
                .order_by("-ngay_gui", "-id")
            )
            return self._dich_vu(ds, request, chua_doc=0)
        ds = self._hop_thu()
        chua_doc = sum(1 for n in ds if not n.da_doc)
        if request.query_params.get("da_doc") in ("0", "false", "False"):
            ds = [n for n in ds if not n.da_doc]
        return self._dich_vu(ds, request, chua_doc=chua_doc)

    @extend_schema(request=NotificationCreateSerializer, responses={201: NotificationSerializer})
    def create(self, request):
        """Gửi thông báo tới vai trò / lớp / người dùng. GV chỉ gửi cho **lớp mình** (`CLASS`)."""
        s = NotificationCreateSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        d = s.validated_data
        if request.user.role == Role.GIAO_VIEN:
            cua_toi = set(
                ClassSection.objects.filter(giao_vien__user=request.user).values_list(
                    "id", flat=True
                )
            )
            if d["audience"] != Audience.CLASS or not set(d["target_refs"]) <= cua_toi:
                raise business_error(
                    Codes.KHONG_CO_QUYEN, "Giáo viên chỉ gửi thông báo cho lớp mình phụ trách."
                )
        n = Notification.objects.create(
            tieu_de=d["tieu_de"],
            noi_dung=d["noi_dung"],
            audience=d["audience"],
            target_refs=d["target_refs"],
            nguoi_gui=request.user,
        )
        write_audit(
            request,
            HanhDong.CREATE,
            "Notification",
            n.id,
            {"audience": n.audience, "target_refs": n.target_refs, "tieu_de": n.tieu_de},
        )
        n.da_doc = False
        return Response(NotificationSerializer(n, context={"request": request}).data, status=201)

    def _cua_toi(self, pk):
        n = next((x for x in self._hop_thu() if x.id == int(pk)), None)
        if n is None:
            raise NotFound("Không tìm thấy thông báo.")
        return n

    @extend_schema(request=None, responses=NotificationSerializer)
    @action(detail=True, methods=["patch"])
    def read(self, request, pk=None):
        """Đánh dấu đã đọc."""
        n = self._cua_toi(pk)
        services.danh_dau_da_doc(request.user, n)
        n.da_doc = True
        return Response(NotificationSerializer(n, context={"request": request}).data)

    @extend_schema(request=None, responses=None)
    @action(detail=False, methods=["post"], url_path="read-all")
    def read_all(self, request):
        """Đánh dấu tất cả đã đọc."""
        return Response({"da_danh_dau": services.danh_dau_tat_ca(request.user)})

    @extend_schema(request=None, responses={204: None})
    def destroy(self, request, pk=None):
        """Thu hồi (`THU_HOI`): Admin hoặc người gửi; biến khỏi hộp thư người nhận."""
        n = Notification.objects.filter(pk=pk).first()
        if n is None:
            raise NotFound("Không tìm thấy thông báo.")
        if not (request.user.role == Role.ADMIN or n.nguoi_gui_id == request.user.id):
            raise business_error(Codes.KHONG_CO_QUYEN, "Chỉ người gửi hoặc Admin được thu hồi.")
        if n.trang_thai != TrangThaiThongBao.THU_HOI:
            n.trang_thai = TrangThaiThongBao.THU_HOI
            n.save(update_fields=["trang_thai"])
            write_audit(request, HanhDong.UPDATE, "Notification", n.id, {"hanh_dong": "thu_hoi"})
        return Response(status=204)

    @extend_schema(
        parameters=[OpenApiParameter("search", str), OpenApiParameter("role", str)],
        responses=RecipientSerializer(many=True),
    )
    @action(detail=False, methods=["get"])
    def recipients(self, request):
        """Tra người nhận để gửi riêng (`USER`): tối đa 20 kết quả. Giáo viên không dùng."""
        if request.user.role == Role.GIAO_VIEN:
            raise business_error(Codes.KHONG_CO_QUYEN, "Giáo viên chỉ gửi theo lớp.")
        qs = User.objects.filter(is_locked=False)
        if request.query_params.get("role"):
            qs = qs.filter(role=request.query_params["role"])
        t = request.query_params.get("search", "").strip()
        if t:
            qs = qs.filter(
                Q(username__icontains=t)
                | Q(first_name__icontains=t)
                | Q(sinh_vien__ho_ten__icontains=t)
                | Q(sinh_vien__ma_sv__icontains=t)
                | Q(giang_vien__ho_ten__icontains=t)
                | Q(giang_vien__ma_gv__icontains=t)
            )
        qs = qs.select_related("sinh_vien", "giang_vien").order_by("username")[:20]
        return Response(RecipientSerializer(qs, many=True).data)
