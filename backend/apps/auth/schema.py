"""Cho Swagger biết cách xác thực của LockedAwareJWTAuthentication (nút Authorize)."""

from drf_spectacular.extensions import OpenApiAuthenticationExtension


class LockedAwareJWTScheme(OpenApiAuthenticationExtension):
    target_class = "apps.auth.authentication.LockedAwareJWTAuthentication"
    name = "jwtAuth"

    def get_security_definition(self, auto_schema):
        return {"type": "http", "scheme": "bearer", "bearerFormat": "JWT"}
