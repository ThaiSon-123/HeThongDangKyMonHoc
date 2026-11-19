from dataclasses import replace

import numpy as np
import pytest

from apps.attendance.face.checks import (
    action_done,
    face_status,
    live_hint,
    match_scores,
    quality_reason,
)
from apps.attendance.tests.face_fakes import CFG as cfg
from apps.attendance.tests.face_fakes import E0, NO_FACE, fa, vec


def test_quality_reasons():
    assert quality_reason(fa(face_count=0), cfg) == "FACE_NOT_FOUND"
    assert quality_reason(fa(face_count=2), cfg) == "MULTIPLE_FACES"
    assert quality_reason(fa(face_width_px=99), cfg) == "FACE_NOT_FOUND"
    assert quality_reason(fa(brightness=59), cfg) == "LOW_LIGHT"
    assert quality_reason(fa(sharpness=49), cfg) == "BLURRY"
    assert (
        quality_reason(fa(face_width_px=100, brightness=60, sharpness=50), cfg) is None
    )  # đúng biên vẫn đạt
    assert quality_reason(fa(), cfg) is None


def test_action_turn_left_needs_frontal_then_turn():
    # quy ước: giá trị * yaw_sign < 0 là quay sang trái của sinh viên
    assert action_done([0.0, -0.1, -0.3], "turn_left", cfg) is True
    assert action_done([-0.3, 0.0], "turn_left", cfg) is False  # quay trước rồi mới nhìn thẳng
    assert action_done([0.0, 0.3], "turn_left", cfg) is False  # sai hướng
    assert action_done([0.0, -0.2], "turn_left", cfg) is False  # chưa đủ ngưỡng
    assert action_done([None, 0.05, None, -0.26], "turn_left", cfg) is True
    assert action_done([0.0, 0.3], "turn_right", cfg) is True
    assert action_done([0.2, 0.3], "turn_right", cfg) is False  # chưa từng nhìn thẳng (|yaw| > T/2)
    assert action_done([], "turn_left", cfg) is False
    assert action_done([None, None], "turn_left", cfg) is False


def test_action_respects_yaw_sign():
    flipped = replace(cfg, yaw_sign=-1)  # camera trước lật ảnh: đổi chiều quy ước
    assert action_done([0.0, 0.3], "turn_left", flipped) is True
    assert action_done([0.0, -0.3], "turn_left", flipped) is False


def test_action_unknown_raises():
    with pytest.raises(ValueError):
        action_done([0.0, 0.3], "blink", cfg)


def test_match_scores_median_and_min():
    med, low = match_scores([vec(0.9), vec(0.6), vec(0.7)], E0)
    assert med == pytest.approx(0.7, abs=1e-6) and low == pytest.approx(0.6, abs=1e-6)


def test_match_scores_normalizes_inputs():
    med, low = match_scores([vec(0.8) * 5], E0 * 3)
    assert med == pytest.approx(0.8, abs=1e-6) and low == pytest.approx(0.8, abs=1e-6)


def test_face_status_thresholds():
    assert face_status(0.55, 0.45, cfg) == "pass"
    assert face_status(0.50, 0.40, cfg) == "pass"  # đúng hai ngưỡng
    assert face_status(0.45, 0.42, cfg) == "borderline"
    assert face_status(0.60, 0.39, cfg) == "fail"  # một khung dưới ngưỡng nghi ngờ → không đạt
    assert face_status(0.39, 0.39, cfg) == "fail"


def test_vec_helper_is_unit():
    assert np.linalg.norm(vec(0.3)) == pytest.approx(1.0)


@pytest.mark.parametrize(
    ("khung", "tu_the", "ma"),
    [
        (NO_FACE, "thang", "KHONG_THAY_MAT"),
        (fa(face_count=2), "thang", "NHIEU_MAT"),
        (fa(face_width_px=80), "thang", "LAI_GAN"),
        (fa(brightness=40), "thang", "THIEU_SANG"),
        (fa(sharpness=10), "thang", "ANH_MO"),
        (fa(yaw_proxy=0.2), "thang", "NHIN_THANG"),
        (fa(yaw_proxy=0.1), "thang", None),
        (fa(yaw_proxy=-0.13), "hoi_trai", None),  # quay nhẹ: ≥ T/2
        (fa(yaw_proxy=-0.05), "hoi_trai", "QUAY_TRAI"),
        (fa(yaw_proxy=0.2), "turn_right", "QUAY_PHAI"),  # hành động: phải ≥ T
        (fa(yaw_proxy=0.3), "turn_right", None),
        (fa(yaw_proxy=0.3), "turn_left", "QUAY_TRAI"),  # sai hướng
    ],
)
def test_live_hint(khung, tu_the, ma):
    assert live_hint(khung, cfg, tu_the) == ma
