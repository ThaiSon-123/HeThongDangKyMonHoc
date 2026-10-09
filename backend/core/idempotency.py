"""Idempotency bền vững (plan.md mục 13.7).

Chân lý là UNIQUE `request_id` (khi khác NULL) trong DB — Redis chỉ là fast-path 24h
nên bỏ qua được mà không sai kết quả. Key đã dùng → trả lại đúng payload cũ.
"""

from django.db import IntegrityError, transaction
from rest_framework.response import Response


def run_once(request, model, handler, replay):
    """Chạy `handler()` một lần cho mỗi `request.idempotency_key`.

    - `handler()` → tạo bản ghi, trả `(instance, Response)`.
    - `replay(instance)` → dựng lại `Response` từ bản ghi cũ.

    Key trùng → trả payload cũ, KHÔNG chạy lại handler.
    """
    key = getattr(request, "idempotency_key", None)
    if not key:
        return handler()[1]

    existing = model._default_manager.filter(request_id=key).first()
    if existing is not None:
        return replay(existing)

    with transaction.atomic():
        try:
            instance, response = handler()
        except IntegrityError:
            existing = model._default_manager.filter(request_id=key).first()
            if existing is None:
                raise
            return replay(existing)
        return response


def cached_response(status, body):
    """Redis fast-path 24h — chỉ là cache, DB vẫn là chân lý."""
    return Response(body, status=status)
