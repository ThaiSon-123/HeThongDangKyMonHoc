import pytest
from django.core.cache import cache
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from apps.auth.models import Role
from core.factories import UserFactory


@pytest.fixture(autouse=True)
def _clear_cache():
    """Throttle đếm trong cache → xóa trước mỗi test để không rò giữa các test."""
    cache.clear()


@pytest.fixture
def client():
    return APIClient()


@pytest.fixture
def login_as():
    """login_as(user) → APIClient đã gắn Bearer access token."""

    def _login(user):
        c = APIClient()
        c.credentials(HTTP_AUTHORIZATION=f"Bearer {RefreshToken.for_user(user).access_token}")
        return c

    return _login


@pytest.fixture
def make_user():
    def _make(role=Role.SINH_VIEN, **kw):
        return UserFactory(role=role, **kw)

    return _make
