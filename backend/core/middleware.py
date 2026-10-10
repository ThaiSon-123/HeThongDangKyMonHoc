"""Idempotency-Key (plan.md mục 8.3).

Chỉ `POST /api/registrations/` và `POST /api/tuition/payments/` nhận Idempotency-Key.
Middleware ở đây chỉ làm 2 việc: gắn key vào request và chặn endpoint bắt buộc key
khi thiếu. Logic replay (UNIQUE `request_id` ở DB) nằm ở `core.idempotency`
vì nó cần transaction của endpoint.
"""

from django.http import JsonResponse

HEADER = "HTTP_IDEMPOTENCY_KEY"

# (path prefix, key bắt buộc)
IDEMPOTENT_ENDPOINTS = [
    ("/api/registrations/", True),
    ("/api/tuition/payments/", False),
]


class IdempotencyKeyMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        key = request.META.get(HEADER, "").strip()
        request.idempotency_key = key or None

        if request.method == "POST":
            for prefix, required in IDEMPOTENT_ENDPOINTS:
                if request.path.rstrip("/").endswith(prefix.rstrip("/")):
                    if required and not key:
                        # Lỗi field kiểu DRF (mục 8.4) — không tự chế mã nghiệp vụ mới.
                        return JsonResponse(
                            {"Idempotency-Key": ["Thiếu header Idempotency-Key."]}, status=400
                        )
                    break

        response = self.get_response(request)
        if key:
            response["Idempotency-Key"] = key
        return response
