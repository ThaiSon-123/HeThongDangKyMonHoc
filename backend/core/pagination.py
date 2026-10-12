"""Phân trang — mặc định 25, tối đa 50 (plan.md mục 13.7)."""

from django.conf import settings
from rest_framework.pagination import PageNumberPagination


class StandardPagination(PageNumberPagination):
    page_size = 25
    page_size_query_param = "page_size"
    max_page_size = 50

    def get_page_size(self, request):
        size = super().get_page_size(request)
        return min(size, getattr(settings, "API_MAX_PAGE_SIZE", 50))
