"""Idempotency-Key (plan.md mục 13.7).

Chỉ `POST /api/registrations/` và `POST /api/tuition/payments/` nhận Idempotency-Key.
Middleware ở đây chỉ làm 2 việc: gắn key vào request và chặn endpoint bắt buộc key
khi thiếu. Logic replay (Redis fast-path 24h + UNIQUE DB bền vững) nằm ở
`core.idempotency` vì nó cần transaction của endpoint.
"""

import json

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
                        return JsonResponse(
                            {
                                "error": {
                                    "code": "TRANG_THAI_KHONG_HOP_LE",
                                    "message": "Thiếu header Idempotency-Key.",
                                }
                            },
                            status=400,
                        )
                    break

        response = self.get_response(request)
        if key:
            response["Idempotency-Key"] = key
        return response


def load_cached_response(raw):
    """Redis fast-path: trả lại response cũ nguyên vẹn (kể cả status 201)."""
    if not raw:
        return None
    data = json.loads(raw)
    return data["status"], json.loads(data["body"])
