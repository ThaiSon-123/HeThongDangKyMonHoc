"""Hàm vị trí thuần: gộp mẫu, khoảng cách tới khuôn viên, bước nhảy (docs/ke-hoach-gps-khuon-vien-va-esp32.md §3)."""

import math
from dataclasses import dataclass
from statistics import median
from typing import Literal

EARTH_R = 6_371_000


@dataclass(frozen=True)
class Sample:
    lat: float
    lng: float
    acc: float
    ts: int  # mili giây, đồng hồ điện thoại: chỉ dùng hiệu số, không dùng giờ tuyệt đối
    mock: bool = False


@dataclass(frozen=True)
class Fix:
    lat: float
    lng: float
    acc: float


def haversine_m(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp, dl = p2 - p1, math.radians(lng2 - lng1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * EARTH_R * math.asin(min(1.0, math.sqrt(a)))


def _sane(s: Sample) -> bool:
    return (
        all(math.isfinite(x) for x in (s.lat, s.lng, s.acc))
        and -90 <= s.lat <= 90
        and -180 <= s.lng <= 180
        and s.acc > 0
    )


def aggregate(
    samples: list[Sample], max_acc: float, min_count: int, max_span_s: float
) -> Fix | None:
    """Mục 6.2: bỏ mẫu rác và mẫu acc > max_acc; đủ min_count mẫu trong max_span_s giây thì lấy trung vị."""
    good = [s for s in samples if _sane(s) and s.acc <= max_acc]
    if len(good) < min_count:
        return None
    ts = [s.ts for s in good]
    if (max(ts) - min(ts)) / 1000 > max_span_s:
        return None
    return Fix(
        median(s.lat for s in good), median(s.lng for s in good), median(s.acc for s in good)
    )


def distance_to_polygon_m(lat: float, lng: float, polygon: list[tuple[float, float]]) -> float:
    """Khoảng cách (m) từ điểm tới đa giác khuôn viên; 0 nếu nằm trong. Chiếu phẳng quanh điểm (sai số
    không đáng kể ở cỡ khuôn viên vài km)."""
    k = math.radians(1) * EARTH_R
    pts = [((g - lng) * k * math.cos(math.radians(lat)), (a - lat) * k) for a, g in polygon]
    inside, best = False, math.inf
    for (x1, y1), (x2, y2) in zip(pts, pts[1:] + pts[:1], strict=True):
        if (y1 > 0) != (y2 > 0) and 0 < x1 - y1 * (x2 - x1) / (y2 - y1):
            inside = not inside  # tia từ điểm (gốc tọa độ) sang phải cắt cạnh
        dx, dy = x2 - x1, y2 - y1
        t = max(0.0, min(1.0, -(x1 * dx + y1 * dy) / (dx * dx + dy * dy or 1)))
        best = min(best, math.hypot(x1 + t * dx, y1 + t * dy))
    return 0.0 if inside else best


def classify(d: float, r: float) -> Literal["ok", "drift", "far"]:
    if d <= r:
        return "ok"
    return "drift" if d <= 2 * r else "far"


def _too_fast(meters: float, seconds: float, max_speed: float) -> bool:
    return meters / max(seconds, 1.0) > max_speed  # khoảng thời gian < 1 s (kể cả 0) tính như 1 s


def has_jump(samples: list[Sample], max_speed: float) -> bool:
    """Tốc độ giữa hai mẫu liên tiếp (theo ts) vượt max_speed m/s."""
    s = sorted((x for x in samples if _sane(x)), key=lambda x: x.ts)
    return any(
        _too_fast(haversine_m(a.lat, a.lng, b.lat, b.lng), (b.ts - a.ts) / 1000, max_speed)
        for a, b in zip(s, s[1:], strict=False)
    )


def jump_from_previous(prev: Fix, prev_t: float, cur: Fix, cur_t: float, max_speed: float) -> bool:
    """Lượt này cách lượt trước trong cùng phiên quá xa so với thời gian server ghi nhận (giây)."""
    return _too_fast(haversine_m(prev.lat, prev.lng, cur.lat, cur.lng), cur_t - prev_t, max_speed)
