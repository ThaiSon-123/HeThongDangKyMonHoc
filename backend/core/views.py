from django.db import OperationalError, connection
from drf_spectacular.utils import extend_schema, inline_serializer
from rest_framework import serializers
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView


class HealthView(APIView):
    """GET /api/health/ — hệ thống còn sống + DB kết nối được (plan.md mục 8.1)."""

    authentication_classes: list = []
    permission_classes = [AllowAny]

    @extend_schema(
        responses=inline_serializer(
            "Health", {"status": serializers.CharField(), "db": serializers.BooleanField()}
        )
    )
    def get(self, request):
        try:
            connection.ensure_connection()
        except OperationalError:
            return Response({"status": "error", "db": False}, status=503)
        return Response({"status": "ok", "db": True})
