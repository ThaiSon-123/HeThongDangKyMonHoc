from rest_framework import serializers

from apps.audit.models import AuditLog, HanhDong


class AuditLogSerializer(serializers.ModelSerializer):
    nguoi_thuc_hien = serializers.SerializerMethodField()
    scope = serializers.CharField(read_only=True)
    hanh_dong = serializers.ChoiceField(choices=HanhDong.choices, read_only=True)

    class Meta:
        model = AuditLog
        fields = [
            "id",
            "nguoi_thuc_hien",
            "hanh_dong",
            "doi_tuong",
            "doi_tuong_id",
            "chi_tiet",
            "thoi_gian",
            "ip",
            "scope",
        ]
        read_only_fields = fields

    def get_nguoi_thuc_hien(self, obj) -> str:
        return obj.user.username if obj.user_id else "Hệ thống"
