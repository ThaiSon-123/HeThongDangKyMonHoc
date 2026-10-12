from django.apps import AppConfig


class AuthConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.auth"
    label = "user"

    def ready(self):
        from apps.auth import schema  # noqa: F401  (đăng ký extension cho Swagger)
