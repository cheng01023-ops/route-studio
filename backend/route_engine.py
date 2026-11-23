"""Deterministic, wall-clock paced WGS84 route playback. No device dependencies."""
from __future__ import annotations

import bisect
import math
from dataclasses import dataclass

EARTH_RADIUS = 6_371_008.8


@dataclass(frozen=True)
class Point:
    latitude: float
    longitude: float

    @classmethod
    def parse(cls, value: dict) -> "Point":
        lat, lon = float(value["latitude"]), float(value["longitude"])
        if not (math.isfinite(lat) and math.isfinite(lon) and -90 <= lat <= 90 and -180 <= lon <= 180):
            raise ValueError("经纬度无效；纬度须在 -90～90，经度须在 -180～180。")
        return cls(lat, lon)

    def json(self) -> dict:
        return {"latitude": self.latitude, "longitude": self.longitude}


def distance(a: Point, b: Point) -> float:
    la, lb = math.radians(a.latitude), math.radians(b.latitude)
    dlat, dlon = lb - la, math.radians(b.longitude - a.longitude)
    h = math.sin(dlat / 2) ** 2 + math.cos(la) * math.cos(lb) * math.sin(dlon / 2) ** 2
    return 2 * EARTH_RADIUS * math.asin(math.sqrt(min(1, max(0, h))))


def interpolate(a: Point, b: Point, fraction: float) -> Point:
    """Spherical interpolation, including segments across the antimeridian."""
    if fraction <= 0:
        return a
    if fraction >= 1:
        return b
    def xyz(p):
        lat, lon = math.radians(p.latitude), math.radians(p.longitude)
        return math.cos(lat) * math.cos(lon), math.cos(lat) * math.sin(lon), math.sin(lat)
    va, vb = xyz(a), xyz(b)
    omega = math.acos(max(-1, min(1, sum(x * y for x, y in zip(va, vb)))))
    if omega < 1e-10:
        return a
    if abs(math.sin(omega)) < 1e-10:
        raise ValueError("路线包含对跖点，请增加中间途经点。")
    sa, sb = math.sin((1 - fraction) * omega) / math.sin(omega), math.sin(fraction * omega) / math.sin(omega)
    x, y, z = [sa * x + sb * y for x, y in zip(va, vb)]
    return Point(math.degrees(math.atan2(z, math.hypot(x, y))), math.degrees(math.atan2(y, x)))


class Route:
    def __init__(self, payload: dict):
        if payload.get("coordinateSystem", "WGS84") != "WGS84":
            raise ValueError("仅支持 WGS84 路线。请先转换坐标系，避免地图偏移。")
        raw = payload.get("points", [])
        if not isinstance(raw, list) or not 2 <= len(raw) <= 10000:
            raise ValueError("路线需要 2～10000 个途经点。")
        self.points = [Point.parse(x) for x in raw]
        self.closed = bool(payload.get("closed", False))
        self.loops = int(payload.get("loops", 1))
        if not 1 <= self.loops <= 1000:
            raise ValueError("循环次数须在 1～1000。")
        self.pace = float(payload.get("paceSeconds", 360))
        if not math.isfinite(self.pace) or not 30 <= self.pace <= 3600:
            raise ValueError("配速须在 0:30～60:00 分钟/公里。")
        if self.loops > 1 and not self.closed:
            raise ValueError("多圈回放需要闭合路线，避免每圈结束后位置跳回起点。")
        if self.closed and distance(self.points[-1], self.points[0]) > 0.001:
            self.points.append(self.points[0])
        self.cumulative = [0.0]
        for a, b in zip(self.points, self.points[1:]):
            segment = distance(a, b)
            if segment > 1_000_000:
                raise ValueError("单段路线超过 1000 公里，请增加途经点。")
            self.cumulative.append(self.cumulative[-1] + segment)
        self.lap_distance = self.cumulative[-1]
        if self.lap_distance < 1:
            raise ValueError("路线长度至少需要 1 米。")
        self.total_distance = self.lap_distance * self.loops
        self.duration = self.total_distance * self.pace / 1000

    def sample(self, elapsed: float) -> dict:
        elapsed = max(0.0, min(self.duration, elapsed))
        travelled = min(self.total_distance, elapsed * 1000 / self.pace)
        done = elapsed >= self.duration
        lap = min(self.loops - 1, int(travelled / self.lap_distance))
        along = self.lap_distance if done else travelled % self.lap_distance
        if done:
            point = self.points[-1]
        else:
            i = min(len(self.points) - 2, max(0, bisect.bisect_right(self.cumulative, along) - 1))
            length = self.cumulative[i + 1] - self.cumulative[i]
            point = interpolate(self.points[i], self.points[i + 1], (along - self.cumulative[i]) / length if length else 0)
        return {**point.json(), "elapsed": elapsed, "distance": travelled, "totalDistance": self.total_distance,
                "duration": self.duration, "lap": lap + 1, "loops": self.loops, "complete": done}


class PlaybackClock:
    """Monotonic timing: pauses never count toward travelled distance."""
    def __init__(self, now: float):
        self.base = 0.0
        self.started = now
        self.paused = False

    def elapsed(self, now: float) -> float:
        return self.base + (0 if self.paused else max(0, now - self.started))

    def pause(self, now: float):
        if not self.paused:
            self.base = self.elapsed(now)
            self.paused = True

    def resume(self, now: float):
        if self.paused:
            self.started = now
            self.paused = False
