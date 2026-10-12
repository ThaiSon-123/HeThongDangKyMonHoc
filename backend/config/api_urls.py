"""Router API — mỗi app đăng ký viewset / urls vào đây."""

from django.urls import include, path
from rest_framework.routers import DefaultRouter

from apps.auth.views import UserViewSet
from apps.profiles.views import (
    MeView,
    PendingAccountViewSet,
    StudentProfileViewSet,
    TeacherProfileViewSet,
)
from apps.registration import views as registration
from apps.training import views as training
from core.views import HealthView

router = DefaultRouter()
router.register("users", UserViewSet, basename="user")
router.register("profiles/pending-accounts", PendingAccountViewSet, basename="pending-account")
router.register("profiles/students", StudentProfileViewSet, basename="student-profile")
router.register("profiles/teachers", TeacherProfileViewSet, basename="teacher-profile")
router.register("faculties", training.FacultyViewSet, basename="faculty")
router.register("majors", training.MajorViewSet, basename="major")
router.register("curriculums", training.CurriculumViewSet, basename="curriculum")
router.register(
    "curriculum-courses", training.CurriculumCourseViewSet, basename="curriculum-course"
)
router.register("courses", training.CourseViewSet, basename="course")
router.register("prerequisites", training.PrerequisiteViewSet, basename="prerequisite")
router.register("semesters", training.SemesterViewSet, basename="semester")
router.register("class-sections", training.ClassSectionViewSet, basename="class-section")
router.register("schedules", training.ScheduleViewSet, basename="schedule")
router.register("registrations", registration.RegistrationViewSet, basename="registration")

urlpatterns = [
    path("health/", HealthView.as_view()),
    path("auth/", include("apps.auth.urls")),
    path("profiles/me/", MeView.as_view()),
    # Đặt trước router: `courses/available/`, `curriculums/my/` không bị hiểu là `<pk>`.
    path("courses/available/", registration.AvailableCoursesView.as_view()),
    path("curriculums/my/", registration.MyCurriculumView.as_view()),
    path("timetable/my/", registration.MyTimetableView.as_view()),
    *router.urls,
]
