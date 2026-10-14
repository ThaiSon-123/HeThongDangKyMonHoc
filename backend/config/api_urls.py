"""Router API — mỗi app đăng ký viewset / urls vào đây."""

from django.urls import include, path
from rest_framework.routers import DefaultRouter

from apps.attendance import views as attendance
from apps.audit.views import AuditLogListView
from apps.auth.views import UserViewSet
from apps.config import views as config
from apps.grades import views as grades
from apps.notifications.views import NotificationViewSet
from apps.profiles.views import (
    MeView,
    PendingAccountViewSet,
    StudentProfileViewSet,
    TeacherProfileViewSet,
)
from apps.registration import views as registration
from apps.training import reports as training_reports
from apps.training import teacher
from apps.training import views as training
from apps.tuition import reports as tuition_reports
from apps.tuition import views as tuition
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
router.register("tuition/config", tuition.TuitionConfigViewSet, basename="tuition-config")
router.register("tuition/pricing", tuition.PricingViewSet, basename="tuition-pricing")
router.register("tuition/discounts", tuition.DiscountViewSet, basename="tuition-discount")
router.register("tuition/payments", tuition.PaymentViewSet, basename="tuition-payment")
router.register("notifications", NotificationViewSet, basename="notification")
router.register("registrations", registration.RegistrationViewSet, basename="registration")
router.register("attendance/sessions", attendance.SessionViewSet, basename="attendance-session")
router.register(
    "attendance/requests", attendance.AttendanceRequestViewSet, basename="attendance-request"
)

urlpatterns = [
    path("health/", HealthView.as_view()),
    path("auth/", include("apps.auth.urls")),
    path("profiles/me/", MeView.as_view()),
    # Đặt trước router: `courses/available/`, `curriculums/my/` không bị hiểu là `<pk>`.
    path("class-sections/<int:pk>/grades/", grades.ClassGradesView.as_view()),
    path("class-sections/<int:pk>/grades/lock/", grades.ClassGradesLockView.as_view()),
    path("class-sections/<int:pk>/grades/approve/", grades.ClassGradesApproveView.as_view()),
    path("class-sections/<int:pk>/students/", teacher.ClassStudentsView.as_view()),
    path("class-sections/<int:pk>/export/", teacher.ClassExportView.as_view()),
    path("admin/audit-logs/", AuditLogListView.as_view()),
    path("admin/permissions/", config.PermissionsView.as_view()),
    path("admin/config/", config.ConfigView.as_view()),
    path("admin/backups/", config.BackupsView.as_view()),
    path("reports/training/", training_reports.TrainingReportView.as_view()),
    path("reports/training/export/", training_reports.TrainingReportExportView.as_view()),
    path("reports/finance/", tuition_reports.FinanceReportView.as_view()),
    path("reports/finance/export/", tuition_reports.FinanceReportExportView.as_view()),
    path("tuition/my/", tuition.MyTuitionView.as_view()),
    path("tuition/debts/", tuition.TuitionDebtsView.as_view()),
    path("tuition/calculate/", tuition.TuitionCalculateView.as_view()),
    path("tuition/students/", tuition.TuitionStudentsView.as_view()),
    path("tuition/", tuition.TuitionListView.as_view()),
    path("tuition/<int:pk>/", tuition.TuitionDetailView.as_view()),
    path("grades/my/", grades.MyGradesView.as_view()),
    path("grade-sheets/", grades.GradeSheetListView.as_view()),
    path("class-sections/my/", training.MyClassSectionsView.as_view()),
    path("courses/available/", registration.AvailableCoursesView.as_view()),
    path("curriculums/my/", registration.MyCurriculumView.as_view()),
    path("timetable/my/", registration.MyTimetableView.as_view()),
    path("attendance/my/", attendance.MyAttendanceView.as_view()),
    *router.urls,
]
