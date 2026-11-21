"""Chống giả mạo bằng hai mô hình (MiniFASNetV2 + MiniFASNetV1SE, như Silent-Face gốc): không cần file mô hình."""

import numpy as np
import pytest

pytest.importorskip("cv2")
pytest.importorskip("onnxruntime")

from apps.attendance.face import onnx_engine  # noqa: E402


class _Phien:
    """Phiên ONNX giả: trả logits sao cho softmax lớp 1 (người thật) = p."""

    def __init__(self, p):
        self.p, self.shapes = p, []

    def get_inputs(self):
        return [type("I", (), {"name": "x"})()]

    def run(self, _out, feed):
        self.shapes.append(feed["x"].shape)
        q = (1 - self.p) / 2
        return [np.log(np.array([[q, self.p, q]], dtype=np.float32))]


def test_hai_mo_hinh_mac_dinh_dung_ti_le_cat_cua_silent_face():
    assert onnx_engine.SPOOF_MODELS == (("MiniFASNetV2.onnx", 2.7), ("MiniFASNetV1SE.onnx", 4.0))


def test_diem_nguoi_that_la_trung_binh_hai_mo_hinh(monkeypatch):
    ti_le = []
    that = onnx_engine.crop_scaled

    def cat(img, box, scale, size):
        ti_le.append(scale)
        return that(img, box, scale, size)

    monkeypatch.setattr(onnx_engine, "crop_scaled", cat)
    eng = object.__new__(onnx_engine.OnnxFaceEngine)
    v2, v1se = _Phien(0.9), _Phien(0.5)
    eng.spoof = [(v2, 2.7), (v1se, 4.0)]
    img = np.zeros((400, 400, 3), np.uint8)
    diem = eng._spoof(img, (150.0, 150.0, 60.0, 60.0))
    assert diem == pytest.approx(0.7, abs=1e-5)
    assert ti_le == [2.7, 4.0]
    assert v2.shapes == v1se.shapes == [(1, 3, 80, 80)]
