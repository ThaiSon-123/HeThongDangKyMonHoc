from rest_framework import serializers

from apps.auth.models import Role, User
from apps.auth.serializers import _profile_of
from apps.notifications.models import Audience, Notification
from apps.training.models import ClassSection


class NotificationSerializer(serializers.ModelSerializer):
    nguoi_gui_ten = serializers.SerializerMethodField()
    da_doc = serializers.SerializerMethodField()
    tu_toi = serializers.SerializerMethodField()

    class Meta:
        model = Notification
        fields = [
            "id",
            "tieu_de",
            "noi_dung",
            "audience",
            "target_refs",
            "nguoi_gui_ten",
            "ngay_gui",
            "trang_thai",
            "da_doc",
            "tu_toi",
        ]
        read_only_fields = fields

    def get_nguoi_gui_ten(self, obj) -> str:
        return obj.nguoi_gui.username if obj.nguoi_gui_id else "Hệ thống"

    def get_da_doc(self, obj) -> bool:
        return bool(getattr(obj, "da_doc", False))

    def get_tu_toi(self, obj) -> bool:
        user = self.context["request"].user
        return obj.nguoi_gui_id == user.id


class NotificationListSerializer(serializers.Serializer):
    """Chỉ để mô tả Swagger: phân trang + `chua_doc`."""

    count = serializers.IntegerField()
    next = serializers.CharField(allow_null=True)
    previous = serializers.CharField(allow_null=True)
    chua_doc = serializers.IntegerField()
    results = NotificationSerializer(many=True)


class NotificationCreateSerializer(serializers.Serializer):
    tieu_de = serializers.CharField(max_length=255)
    noi_dung = serializers.CharField()
    audience = serializers.ChoiceField(choices=Audience.choices)
    target_refs = serializers.ListField(
        child=serializers.JSONField(), allow_empty=False, max_length=1000
    )

    def validate(self, attrs):
        refs, audience = attrs["target_refs"], attrs["audience"]
        if audience == Audience.ROLE:
            if not set(refs) <= set(Role.values):
                raise serializers.ValidationError({"target_refs": ["Vai trò không hợp lệ."]})
        else:
            if not all(isinstance(r, int) and not isinstance(r, bool) for r in refs):
                raise serializers.ValidationError({"target_refs": ["Phải là danh sách mã số."]})
            model = ClassSection if audience == Audience.CLASS else User
            if model.objects.filter(id__in=refs).count() != len(set(refs)):
                raise serializers.ValidationError({"target_refs": ["Có đối tượng không tồn tại."]})
        attrs["target_refs"] = sorted(set(refs))
        return attrs


class RecipientSerializer(serializers.ModelSerializer):
    full_name = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = ["id", "username", "full_name", "role"]
        read_only_fields = fields

    def get_full_name(self, user) -> str:
        profile = _profile_of(user)
        return (profile.ho_ten if profile else "") or user.first_name  # hồ sơ học vụ là nguồn chuẩn
