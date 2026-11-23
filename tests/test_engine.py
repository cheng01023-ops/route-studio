import asyncio
import math
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'backend'))
from route_engine import Point, Route, PlaybackClock, distance, interpolate
from backend import Bridge
from coordinates import gcj_to_wgs, wgs_to_gcj


def route_payload(**changes):
    data = dict(points=[dict(latitude=0, longitude=0), dict(latitude=0, longitude=0.01)], paceSeconds=360, loops=1, closed=False)
    data.update(changes)
    return data


class GeometryTests(unittest.TestCase):
    def test_mainland_map_coordinates_are_not_gps_coordinates(self):
        map_point = Point(31.291315, 121.503115)
        gps = gcj_to_wgs(map_point)
        # Independent OSM pitch bounds put this stadium near 121.4987 E.
        self.assertTrue(121.498 < gps.longitude < 121.4995)
        self.assertTrue(31.292 < gps.latitude < 31.2945)
        self.assertGreater(distance(map_point, gps), 400)
        self.assertLess(distance(wgs_to_gcj(gps), map_point), .001)

    def test_coordinate_roundtrip_and_outside_china(self):
        for p in [Point(31.2932,121.4987),Point(39.9,116.4),Point(22.55,114.05)]:
            self.assertLess(distance(gcj_to_wgs(wgs_to_gcj(p)),p),.001)
        p=Point(37.77,-122.42)
        self.assertEqual(wgs_to_gcj(p),p);self.assertEqual(gcj_to_wgs(p),p)

    def test_equatorial_distance_and_constant_pace(self):
        route = Route(route_payload())
        self.assertAlmostEqual(route.total_distance, 1111.9508, places=3)
        sample = route.sample(180)
        self.assertAlmostEqual(sample['distance'], 500)
        self.assertAlmostEqual(distance(Point(0, 0), Point(sample['latitude'], sample['longitude'])), 500, places=3)
        self.assertFalse(sample['complete'])

    def test_corners_follow_segment_not_diagonal(self):
        route = Route(route_payload(points=[dict(latitude=0, longitude=0), dict(latitude=0, longitude=0.01), dict(latitude=0.01, longitude=0.01)]))
        sample = route.sample(route.duration * 0.75)
        self.assertAlmostEqual(sample['longitude'], 0.01, places=7)
        self.assertGreater(sample['latitude'], 0)

    def test_closing_segment_and_loop_boundary(self):
        route = Route(route_payload(closed=True, loops=3))
        self.assertEqual(len(route.points), 3)
        sample = route.sample(route.duration / 3)
        self.assertAlmostEqual(sample['longitude'], 0, places=7)
        self.assertEqual(sample['lap'], 2)
        end = route.sample(route.duration + 100)
        self.assertTrue(end['complete']); self.assertEqual(end['lap'], 3)
        self.assertEqual(end['distance'], route.total_distance)
        self.assertEqual(end['longitude'], 0)

    def test_open_loop_is_rejected(self):
        with self.assertRaises(ValueError): Route(route_payload(loops=2))

    def test_repeated_points_are_safe(self):
        route = Route(route_payload(points=[dict(latitude=0, longitude=0)] * 3 + [dict(latitude=0, longitude=0.01)]))
        self.assertAlmostEqual(route.sample(0)['longitude'], 0)
        self.assertGreater(route.sample(1)['longitude'], 0)

    def test_invalid_data_rejected(self):
        for changes in [dict(paceSeconds=float('nan')), dict(paceSeconds=0), dict(loops=0), dict(points=[]),
                        dict(coordinateSystem='GCJ02'), dict(points=[dict(latitude=100, longitude=0)] * 2),
                        dict(points=[dict(latitude=0, longitude=0)] * 2)]:
            with self.subTest(changes=changes), self.assertRaises((ValueError, OverflowError)): Route(route_payload(**changes))

    def test_antimeridian_uses_short_arc(self):
        midpoint = interpolate(Point(10, 179.99), Point(10, -179.99), .5)
        self.assertAlmostEqual(abs(midpoint.longitude), 180, places=7)

    def test_clock_pauses_without_jump(self):
        clock = PlaybackClock(10)
        self.assertEqual(clock.elapsed(25), 15)
        clock.pause(25); clock.pause(30)
        self.assertEqual(clock.elapsed(100), 15)
        clock.resume(100); clock.resume(102)
        self.assertEqual(clock.elapsed(105), 20)


class FakeLocation:
    def __init__(self, fail_set=False, fail_clear=False):
        self.points = []; self.clears = 0; self.fail_set = fail_set; self.fail_clear = fail_clear
    async def set(self, lat, lon):
        self.points.append((lat, lon))
        if self.fail_set: raise ConnectionError('test link failure')
    async def clear(self):
        self.clears += 1
        if self.fail_clear: raise ConnectionError('test restore failure')


class PlaybackTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.events = []
        self.bridge = Bridge(lambda event, **values: self.events.append(dict(event=event, **values)))
    async def asyncTearDown(self):
        await self.bridge.cancel_replay()
    async def test_preview_does_not_touch_device(self):
        fake = FakeLocation(); self.bridge.location = fake
        await self.bridge.start(dict(route=route_payload(), mode='preview'))
        await asyncio.sleep(.02)
        await self.bridge.stop()
        self.assertEqual(fake.points, []); self.assertEqual(fake.clears, 0)
    async def test_device_requires_connection(self):
        with self.assertRaises(ValueError): await self.bridge.start(dict(route=route_payload(), mode='device'))
    async def test_stop_restores_after_start(self):
        fake = FakeLocation(); self.bridge.location = fake
        await self.bridge.start(dict(route=route_payload(), mode='device'))
        await self.bridge.stop()
        self.assertGreaterEqual(len(fake.points), 1); self.assertEqual(fake.clears, 1)
        self.assertFalse(self.bridge.simulated); self.assertFalse(self.bridge.uncertain)
    async def test_natural_completion_restores(self):
        fake = FakeLocation(); self.bridge.location = fake
        short = route_payload(points=[dict(latitude=0, longitude=0), dict(latitude=0, longitude=0.00001)], paceSeconds=30)
        await self.bridge.start(dict(route=short, mode='device'))
        await asyncio.wait_for(self.bridge.replay, 2)
        self.assertEqual(self.bridge.state, 'completed'); self.assertEqual(fake.clears, 1)
    async def test_failed_write_preserves_uncertainty(self):
        self.bridge.location = FakeLocation(fail_set=True)
        await self.bridge.handle(dict(command='start', mode='device', route=route_payload(), id='a'))
        response = next(x for x in self.events if x['event'] == 'response')
        self.assertFalse(response['ok']); self.assertTrue(self.bridge.uncertain)
        self.assertTrue(self.bridge.simulated)
    async def test_failed_restore_never_reports_success(self):
        self.bridge.location = FakeLocation(fail_clear=True); self.bridge.simulated = True
        await self.bridge.handle(dict(command='restore', id='x'))
        self.assertTrue(self.bridge.simulated)
        self.assertTrue(any(x.get('id') == 'x' and not x['ok'] for x in self.events if x['event'] == 'response'))
    async def test_overlapping_mutations_are_rejected(self):
        async with self.bridge.operation_lock:
            await self.bridge.handle(dict(command='start', mode='preview', route=route_payload(), id='a'))
        self.assertIsNone(self.bridge.replay)
        self.assertFalse(next(x for x in self.events if x.get('id') == 'a')['ok'])
    async def test_pause_resume_keeps_elapsed(self):
        await self.bridge.start(dict(route=route_payload(), mode='preview'))
        await self.bridge.handle(dict(command='pause'))
        frozen = self.bridge.clock.elapsed(100000000)
        await asyncio.sleep(.02)
        self.assertEqual(self.bridge.clock.elapsed(200000000), frozen)
        await self.bridge.handle(dict(command='resume'))
        self.assertEqual(self.bridge.state, 'playing')
    async def test_preview_cannot_hide_active_fixed_location(self):
        self.bridge.simulated = True
        with self.assertRaises(ValueError): await self.bridge.start(dict(route=route_payload(), mode='preview'))


if __name__ == '__main__': unittest.main()
