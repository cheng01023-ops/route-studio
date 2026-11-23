"""1000 m test route traced from the visible Apple Maps South Track outline.

Not a surveyed lane measurement or an official attendance route. Anchors were
collected in Route Studio's map UI; coordinates use the WGS84 convention.
"""
from pathlib import Path
import json
import math
import sys
from datetime import datetime, timedelta, timezone
import xml.etree.ElementTree as ET

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'backend'))
from route_engine import Point, distance, interpolate, Route
from coordinates import gcj_to_wgs

# Map-view anchors (image pixels -> coordinates, rounded by the UI to 6 decimals).
# y=768 -> 31.291505, y=1109 -> 31.291125
# x=793 -> 121.503115, x=873 -> 121.503219
def world(x, y):
    # Mainland MapKit provider is Amap/GCJ02; the device needs WGS84.
    return gcj_to_wgs(Point(31.291505 + (y - 768) * (31.291125 - 31.291505) / (1109 - 768),
                           121.503115 + (x - 793) * (121.503219 - 121.503115) / 80))

cx, left, right = 874, 588, 1160
top_join, bottom_join = 565, 1340
top_radius, bottom_radius = 251, 233
rx = (right - left) / 2
lap = []

def arc(cy, ry, start, end, segments):
    for i in range(segments + 1):
        angle = start + (end - start) * i / segments
        lap.append(world(cx + rx * math.cos(angle), cy + ry * math.sin(angle)))

# Start at the southernmost point, move counterclockwise around the oval.
arc(bottom_join, bottom_radius, math.pi / 2, 0, 24)
for i in range(1, 25): lap.append(world(right, bottom_join + (top_join - bottom_join) * i / 24))
arc(top_join, top_radius, 0, -math.pi, 48)
for i in range(1, 25): lap.append(world(left, top_join + (bottom_join - top_join) * i / 24))
arc(bottom_join, bottom_radius, math.pi, math.pi / 2, 24)

# Remove duplicated arc/straight joins.
clean = []
for point in lap:
    if not clean or distance(clean[-1], point) > .001: clean.append(point)
lap = clean
lap_distance = sum(distance(a, b) for a, b in zip(lap, lap[1:]))

points = [lap[0]]
total = 0.0
while total < 1000:
    for point in lap[1:]:
        segment = distance(points[-1], point)
        if total + segment >= 1000:
            points.append(interpolate(points[-1], point, (1000 - total) / segment))
            total = 1000
            break
        points.append(point)
        total += segment

document = dict(formatVersion=1, coordinateSystem='WGS84', name='南区田径场 · 1000米测试',
                points=[p.json() for p in points], closed=False, loops=1, paceSeconds=360)
route = Route(document)
assert abs(route.total_distance - 1000) < .001
destination = Path(__file__).resolve().parents[1] / 'examples'
destination.mkdir(parents=True, exist_ok=True)
json_path = destination / '南区田径场-1000米.json'
json_path.write_text(json.dumps(document, ensure_ascii=False, indent=2))
ET.register_namespace('', 'http://www.topografix.com/GPX/1/1')
ns = '{http://www.topografix.com/GPX/1/1}'
gpx = ET.Element(ns+'gpx', version='1.1', creator='Route Studio')
track = ET.SubElement(gpx, ns+'trk'); ET.SubElement(track, ns+'name').text=document['name']
segment = ET.SubElement(track, ns+'trkseg')
start = datetime(2026, 11, 23, tzinfo=timezone.utc); metres = 0
for i, point in enumerate(points):
    if i: metres += distance(points[i-1], point)
    node = ET.SubElement(segment, ns+'trkpt', lat=f'{point.latitude:.10f}', lon=f'{point.longitude:.10f}')
    ET.SubElement(node, ns+'time').text=(start+timedelta(seconds=metres*.36)).isoformat(timespec='milliseconds').replace('+00:00','Z')
ET.indent(gpx)
ET.ElementTree(gpx).write(destination/'南区田径场-1000米.gpx', encoding='utf-8', xml_declaration=True)
print(json.dumps(dict(points=len(points), lapMetres=lap_distance, totalMetres=route.total_distance, seconds=route.duration),ensure_ascii=False))
