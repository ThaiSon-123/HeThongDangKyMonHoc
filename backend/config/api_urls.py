"""Router API — mỗi app đăng ký viewset / urls vào đây."""

from django.urls import include, path
from rest_framework.routers import DefaultRouter

from apps.auth.views import UserViewSet
from apps.profiles.views import MeView, StudentProfileViewSet, TeacherProfileViewSet
from core.views import HealthView

router = DefaultRouter()
router.register("users", UserViewSet, basename="user")
router.register("profiles/students", StudentProfileViewSet, basename="student-profile")
router.register("profiles/teachers", TeacherProfileViewSet, basename="teacher-profile")

urlpatterns = [
    path("health/", HealthView.as_view()),
    path("auth/", include("apps.auth.urls")),
    path("profiles/me/", MeView.as_view()),
    *router.urls,
]
