"""API Admin: ma trận quyền (ADM-04), cấu hình hệ thống (ADM-05), sao lưu (ADM-08)."""

from drf_spectacular.utils import extend_schema, inline_serializer
from rest_framework import serializers
from rest_framework.exceptions import ValidationError
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.audit.models import HanhDong
from apps.config import services
from apps.config.matrix import CAC_VAI_TRO, ma_tran
from apps.config.models import SystemConfig
from core.exceptions import Codes, business_error
from core.mixins import write_audit
from core.permissions import IsAdmin


class ConfigItemSerializer(serializers.Serializer):
    khoa = serializers.CharField()
    nhom = serializers.CharField()
    mo_ta = serializers.CharField()
    mac_dinh = serializers.CharField(allow_blank=True)
    gia_tri = serializers.CharField(allow_blank=True)
    cap_nhat_luc = serializers.DateTimeField(allow_null=True)


class ConfigEditorSerializer(serializers.Serializer):
    boi = serializers.CharField()
    luc = serializers.DateTimeField()


class ConfigSerializer(serializers.Serializer):
    items = ConfigItemSerializer(many=True)
    sua_lan_cuoi = ConfigEditorSerializer(allow_null=True)


class BackupFileSerializer(serializers.Serializer):
    ten = serializers.CharField()
    dung_luong = serializers.IntegerField()
    tao_luc = serializers.DateTimeField()


class BackupListSerializer(serializers.Serializer):
    dang_chay = serializers.BooleanField()
    so_ngay_giu = serializers.IntegerField()
    results = BackupFileSerializer(many=True)


class PermissionsView(APIView):
    """`GET /api/admin/permissions/`: ma trận mục 9, **chỉ đọc**."""

    permission_classes = [IsAdmin]

    @extend_schema(
        responses=inline_serializer(
            "PermissionMatrix",
            {
                "vai_tro": serializers.ListField(child=serializers.CharField()),
                "results": serializers.ListField(child=serializers.DictField()),
            },
        )
    )
    def get(self, request):
        return Response(
            {"vai_tro": [v.value for v in CAC_VAI_TRO], "results": ma_tran()},
        )


def _cau_hinh():
    return {"items": services.doc_cau_hinh(), "sua_lan_cuoi": services.sua_lan_cuoi()}


class ConfigView(APIView):
    """`GET/PATCH /api/admin/config/`: 6 khóa `SystemConfig`. PATCH nhận `{khoa: giá_trị}` (một
    phần); có một khóa sai thì không lưu khóa nào. Mỗi khóa thật sự đổi ghi một dòng audit log."""

    permission_classes = [IsAdmin]

    @extend_schema(responses=ConfigSerializer)
    def get(self, request):
        return Response(_cau_hinh())

    @extend_schema(
        request=inline_serializer("ConfigPatch", {"khoa": serializers.CharField(required=False)}),
        responses=ConfigSerializer,
    )
    def patch(self, request):
        if not isinstance(request.data, dict) or not request.data:
            raise ValidationError({"detail": ["Cần gửi ít nhất một khóa cấu hình."]})
        loi, thay_doi = services.cap_nhat_cau_hinh(request.data)
        if loi:
            raise ValidationError(loi)
        for khoa, cu, moi in thay_doi:
            write_audit(request, HanhDong.UPDATE, "SystemConfig", khoa, {"tu": cu, "den": moi})
        return Response(_cau_hinh())


class BackupsView(APIView):
    """`GET/POST /api/admin/backups/`: danh sách file + tạo backup (chạy nền). Không restore."""

    permission_classes = [IsAdmin]

    @extend_schema(responses=BackupListSerializer)
    def get(self, request):
        return Response(
            {
                "dang_chay": services.dang_chay(),
                "so_ngay_giu": SystemConfig.get_int("backup_retention_days", 30),
                "results": services.liet_ke(),
            }
        )

    @extend_schema(
        request=None,
        responses={202: inline_serializer("BackupQueued", {"trang_thai": serializers.CharField()})},
    )
    def post(self, request):
        if services.dang_chay():
            raise business_error(
                Codes.TRANG_THAI_KHONG_HOP_LE, "Đang có một lần sao lưu chạy, hãy đợi nó xong."
            )
        from jobs.tasks import backup_daily

        backup_daily.delay()
        write_audit(request, HanhDong.CREATE, "Backup", "", {"hanh_dong": "tao_backup"})
        return Response({"trang_thai": "DANG_CHAY"}, status=202)
