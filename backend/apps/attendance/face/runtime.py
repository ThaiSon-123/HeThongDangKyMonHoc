"""Engine khuôn mặt dùng chung cho cả tiến trình: nạp mô hình một lần, giới hạn số lượt suy luận chạy cùng lúc."""

import os
import threading
from collections.abc import Callable
from functools import cache
from typing import TypeVar

from django.conf import settings

from apps.attendance.face.types import FaceEngine

T = TypeVar("T")

# ponytail: semaphore theo từng worker gunicorn; nhiều worker thì mỗi worker giữ mô hình riêng trong RAM (~0,5 GB).
_slots = threading.BoundedSemaphore(os.cpu_count() or 2)


@cache
def get_engine() -> FaceEngine:
    """Test thay bằng FakeEngine qua `monkeypatch` hàm này."""
    from apps.attendance.face.onnx_engine import (
        OnnxFaceEngine,  # chỉ nạp onnxruntime/opencv khi thật sự cần
    )

    cfg = settings.FACE
    return OnnxFaceEngine(
        settings.FACE_MODEL_DIR, embed_model=cfg["embed_file"], threads=cfg["threads"]
    )


def infer(fn: Callable[..., T], *args, **kwargs) -> T:
    """Chạy một lượt suy luận khi còn chỗ; nhiều SV điểm danh cùng lúc thì xếp hàng thay vì làm nghẽn CPU."""
    with _slots:
        return fn(*args, **kwargs)
