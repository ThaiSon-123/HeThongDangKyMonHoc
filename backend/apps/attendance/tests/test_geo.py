import math

import pytest

from apps.attendance.geo import (
    Fix,
    Sample,
    aggregate,
    classify,
    distance_to_polygon_m,
    has_jump,
    haversine_m,
    jump_from_previous,
)


def test_haversine():
    assert haversine_m(21.0, 105.0, 21.0, 105.001) == pytest.approx(103.8, abs=0.5)
    assert haversine_m(21.0, 105.0, 21.0, 105.0) == 0
    assert haversine_m(21.0, 105.0, 21.001, 105.0) == pytest.approx(111.2, abs=0.5)


def test_aggregate_median_and_filter():
    s = [
        Sample(21.0, 105.0, 10, 0),
        Sample(21.0002, 105.0, 12, 1000),
        Sample(21.0001, 105.0, 8, 2000),
        Sample(22.0, 106.0, 80, 3000),
    ]  # mẫu cuối: acc 80 > 30 bị bỏ
    f = aggregate(s, max_acc=30, min_count=3, max_span_s=20)
    assert (f.lat, f.lng, f.acc) == (21.0001, 105.0, 10)


def test_aggregate_rejects():
    ok = [Sample(21, 105, 10, i * 1000) for i in range(3)]
    assert aggregate(ok, 30, 3, 20) is not None
    assert aggregate(ok[:2], 30, 3, 20) is None  # thiếu mẫu
    assert aggregate(ok[:2] + [Sample(21, 105, 10, 25_000)], 30, 3, 20) is None  # span 25 s > 20 s
    assert aggregate([], 30, 3, 20) is None


def test_aggregate_ignores_garbage():
    good = [Sample(21, 105, 10, i * 1000) for i in range(3)]
    junk = [
        Sample(91, 105, 10, 0),
        Sample(21, 181, 10, 0),
        Sample(21, 105, 0, 0),
        Sample(21, 105, -5, 0),
        Sample(math.nan, 105, 10, 0),
        Sample(21, 105, math.inf, 0),
    ]
    assert aggregate(junk, 30, 3, 20) is None
    assert aggregate(good + junk, 30, 3, 20) == Fix(21, 105, 10)


def test_aggregate_span_uses_unordered_ts():
    s = [Sample(21, 105, 10, 5000), Sample(21, 105, 10, 0), Sample(21, 105, 10, 2000)]
    assert aggregate(s, 30, 3, 4) is None and aggregate(s, 30, 3, 5) is not None


def test_classify_boundaries():
    assert classify(30, 30) == "ok" and classify(30.1, 30) == "drift"
    assert classify(60, 30) == "drift" and classify(60.1, 30) == "far"


M = 1 / 111_195  # ~1 m theo vĩ độ
L = M / math.cos(math.radians(21))  # ~1 m theo kinh độ ở vĩ độ 21
VUONG = [
    (21 - 50 * M, 105 - 50 * L),
    (21 - 50 * M, 105 + 50 * L),
    (21 + 50 * M, 105 + 50 * L),
    (21 + 50 * M, 105 - 50 * L),
]
CHU_L = [
    (21, 105),
    (21, 105 + 100 * L),
    (21 + 50 * M, 105 + 100 * L),
    (21 + 50 * M, 105 + 50 * L),
    (21 + 100 * M, 105 + 50 * L),
    (21 + 100 * M, 105),
]


@pytest.mark.parametrize(
    ("lat", "lng", "d"),
    [
        (21, 105, 0),  # giữa
        (21 + 49 * M, 105 + 49 * L, 0),  # sát góc, vẫn trong
        (21 + 80 * M, 105, 30),  # ngoài cạnh bắc 30 m
        (21, 105 - 90 * L, 40),  # ngoài cạnh tây 40 m
        (21 + 80 * M, 105 + 90 * L, 50),  # chéo góc: căn(30² + 40²)
    ],
)
def test_distance_to_polygon_vuong(lat, lng, d):
    assert distance_to_polygon_m(lat, lng, VUONG) == pytest.approx(d, abs=0.5)


def test_distance_to_polygon_lom():
    # Chữ L: chỗ khuyết góc trên phải nằm ngoài dù nằm trong hình bao.
    assert distance_to_polygon_m(21 + 25 * M, 105 + 25 * L, CHU_L) == 0
    assert distance_to_polygon_m(21 + 80 * M, 105 + 80 * L, CHU_L) == pytest.approx(30, abs=0.5)


def test_has_jump():
    near = 10 / 111_195  # ~10 m theo vĩ độ
    far = 100 / 111_195
    assert has_jump([Sample(21, 105, 10, 0), Sample(21 + far, 105, 10, 1000)], max_speed=30) is True
    assert (
        has_jump([Sample(21, 105, 10, 0), Sample(21 + near, 105, 10, 1000)], max_speed=30) is False
    )
    assert (
        has_jump([Sample(21, 105, 10, 0), Sample(21 + far, 105, 10, 0)], max_speed=30) is True
    )  # ts trùng
    assert has_jump([Sample(21, 105, 10, 0), Sample(21 + near, 105, 10, 0)], max_speed=30) is False
    assert has_jump([Sample(21, 105, 10, 0)], max_speed=30) is False
    # sắp theo ts trước khi so: mẫu đến lộn xộn không tạo bước nhảy giả
    assert (
        has_jump(
            [
                Sample(21 + 2 * near, 105, 10, 2000),
                Sample(21, 105, 10, 0),
                Sample(21 + near, 105, 10, 1000),
            ],
            max_speed=30,
        )
        is False
    )


def test_jump_from_previous():
    a, b = Fix(21, 105, 10), Fix(21 + 1000 / 111_195, 105, 10)  # cách ~1 km
    assert jump_from_previous(a, 0, b, 10, max_speed=30) is True  # 100 m/s
    assert jump_from_previous(a, 0, b, 100, max_speed=30) is False  # 10 m/s
    assert jump_from_previous(a, 5, b, 5, max_speed=30) is True  # cùng thời điểm
