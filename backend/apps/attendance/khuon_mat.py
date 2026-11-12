"""Nhận diện khuôn mặt cho tự điểm danh: OpenCV YuNet (tìm mặt) + SFace (vector đặc trưng 128 số).

Model ONNX tải sẵn vào `settings.FACE_MODEL_DIR` lúc build image (xem Dockerfile). Chạy offline, ảnh không
rời máy chủ. Không có chống giả mạo (liveness): ảnh in / ảnh trên màn hình vẫn có thể qua.
"""

from functools import cache
from pathlib import Path

from django.conf import settings

# Ngưỡng cosine OpenCV khuyến nghị cho SFace: ≥ 0.363 coi là cùng một người.
NGUONG = 0.363
YUNET = "face_detection_yunet_2023mar.onnx"
SFACE = "face_recognition_sface_2021dec.onnx"


@cache
def _model():
    import cv2

    thu_muc = Path(settings.FACE_MODEL_DIR)
    tim = cv2.FaceDetectorYN.create(str(thu_muc / YUNET), "", (320, 320), 0.8)
    nhan = cv2.FaceRecognizerSF.create(str(thu_muc / SFACE), "")
    return tim, nhan


def dac_trung(anh: bytes) -> list[float]:
    """Vector đặc trưng của khuôn mặt duy nhất trong ảnh. Không thấy mặt / nhiều mặt → `ValueError`."""
    import cv2
    import numpy as np

    img = cv2.imdecode(np.frombuffer(anh, np.uint8), cv2.IMREAD_COLOR)
    if img is None:
        raise ValueError("Không đọc được ảnh.")
    # Ảnh điện thoại rất lớn → thu về cạnh dài 640 cho nhanh, YuNet vẫn đủ chính xác.
    ti_le = 640 / max(img.shape[:2])
    if ti_le < 1:
        img = cv2.resize(img, None, fx=ti_le, fy=ti_le)
    tim, nhan = _model()
    tim.setInputSize((img.shape[1], img.shape[0]))
    mat = tim.detect(img)[1]
    if mat is None or len(mat) == 0:
        raise ValueError("Không thấy khuôn mặt trong ảnh. Chụp rõ mặt, đủ sáng.")
    if len(mat) > 1:
        raise ValueError("Ảnh có nhiều khuôn mặt. Chỉ chụp một mình bạn.")
    return nhan.feature(nhan.alignCrop(img, mat[0])).flatten().tolist()


def do_giong(a: list[float], b: list[float]) -> float:
    """Độ giống cosine của hai vector (càng gần 1 càng giống) — giống `FaceRecognizerSF.match(COSINE)`."""
    import numpy as np

    x, y = np.asarray(a, np.float32), np.asarray(b, np.float32)
    return float(x @ y / (np.linalg.norm(x) * np.linalg.norm(y)))
