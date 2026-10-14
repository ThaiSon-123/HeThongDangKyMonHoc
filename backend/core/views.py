from django.core.cache import cache
from django.db import OperationalError, connection
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import OpenApiParameter, extend_schema, inline_serializer
from rest_framework import serializers
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView


def _redis_ok():
    try:
        cache.set("health", "1", 5)
        return cache.get("health") == "1"
    except Exception:  # noqa: BLE001 — mọi lỗi kết nối đều nghĩa là "không sống"
        return False


def _worker_ok():
    from config.celery import app

    try:
        return bool(app.control.ping(timeout=1))
    except Exception:  # noqa: BLE001
        return False


class HealthView(APIView):
    """GET /api/health/ — hệ thống còn sống + DB kết nối được (plan.md mục 8.1).

    `?full=1` kiểm thêm Redis và Celery worker (chậm tới ~1 giây nên chỉ dùng cho giám sát, không
    dùng cho healthcheck của Docker). Chỉ DB hỏng mới `503`; Redis/worker hỏng thì `status=degraded`.
    """

    authentication_classes: list = []
    permission_classes = [AllowAny]

    @extend_schema(
        parameters=[OpenApiParameter("full", OpenApiTypes.BOOL)],
        responses=inline_serializer(
            "Health",
            {
                "status": serializers.CharField(),
                "db": serializers.BooleanField(),
                "redis": serializers.BooleanField(required=False),
                "worker": serializers.BooleanField(required=False),
            },
        ),
    )
    def get(self, request):
        try:
            connection.ensure_connection()
        except OperationalError:
            return Response({"status": "error", "db": False}, status=503)
        body = {"status": "ok", "db": True}
        if request.query_params.get("full") in ("1", "true"):
            body["redis"], body["worker"] = _redis_ok(), _worker_ok()
            if not (body["redis"] and body["worker"]):
                body["status"] = "degraded"
        return Response(body)
