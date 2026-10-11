from django.urls import path

from apps.auth import views

urlpatterns = [
    path("login/", views.LoginView.as_view()),
    path("logout/", views.LogoutView.as_view()),
    path("refresh/", views.RefreshView.as_view()),
    path("forgot-password/", views.ForgotPasswordView.as_view()),
    path("reset-password/", views.ResetPasswordView.as_view()),
    path("change-password/", views.ChangePasswordView.as_view()),
]
