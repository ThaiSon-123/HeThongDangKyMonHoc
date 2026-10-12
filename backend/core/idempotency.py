"""Idempotency (plan.md mục 8.3).

Chân lý duy nhất là UNIQUE `request_id` (khi khác NULL) trong DB — không có cache Redis.
Key đã dùng → trả lại đúng payload cũ.
"""

from django.db import IntegrityError, transaction


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
