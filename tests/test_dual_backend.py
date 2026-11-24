"""Two independent bridges with fake USB transports; never touches a real iPhone."""
import asyncio
from contextlib import AsyncExitStack
import hashlib
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import time
import types
import unittest
from unittest.mock import AsyncMock, patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'backend'))
import backend as backend_module
from backend import Bridge
from device_lease import DeviceBusyError, DeviceLease, ddi_preparation_lease, normalize_serial


class FixtureDirectory:
    def setUp(self):
        parent = ROOT / 'build/test-fixtures'
        parent.mkdir(parents=True, exist_ok=True)
        self.temporary = tempfile.TemporaryDirectory(dir=parent)
        self.directory = Path(self.temporary.name) / 'leases'

    def tearDown(self):
        self.temporary.cleanup()


class LeaseTests(FixtureDirectory, unittest.TestCase):
    def child(self, serial):
        script = '''
import sys
sys.path.insert(0, sys.argv[1])
from device_lease import DeviceLease, DeviceBusyError
try:
    lease = DeviceLease.acquire(sys.argv[3], sys.argv[2])
except DeviceBusyError:
    print("busy", flush=True)
else:
    print("owned", flush=True)
    sys.stdin.readline()
    lease.release()
'''
        return subprocess.Popen([sys.executable, '-c', script, str(ROOT / 'backend'),
                                 str(self.directory), serial], stdin=subprocess.PIPE,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

    def test_same_device_conflicts_across_processes_and_release_keeps_inode(self):
        lease = DeviceLease.acquire('FAKE-device-A', self.directory)
        try:
            inode = lease.path.stat().st_ino
            child = self.child('fakedevicea')
            output, error = child.communicate(timeout=5)
            self.assertEqual(child.returncode, 0, error)
            self.assertEqual(output.strip(), 'busy')
            with DeviceLease.acquire('fake-device-B', self.directory):
                self.assertEqual(len(list(self.directory.iterdir())), 2)
            self.assertEqual(stat.S_IMODE(self.directory.stat().st_mode), 0o700)
            self.assertEqual(stat.S_IMODE(lease.path.stat().st_mode), 0o600)
            self.assertEqual(lease.path.stat().st_size, 0)
            self.assertEqual(lease.path.name, hashlib.sha256(b'fakedevicea').hexdigest() + '.lock')
        finally:
            lease.release()
        self.assertEqual(lease.path.stat().st_ino, inode)
        child = self.child('fake-device-A')
        output, error = child.communicate(input='release\n', timeout=5)
        self.assertEqual(child.returncode, 0, error)
        self.assertEqual(output.strip(), 'owned')
        self.assertEqual(lease.path.stat().st_ino, inode)

    def test_process_exit_releases_kernel_lock(self):
        child = self.child('fake-device-A')
        try:
            self.assertEqual(child.stdout.readline().strip(), 'owned')
            with self.assertRaises(DeviceBusyError):
                DeviceLease.acquire('fake-device-A', self.directory)
            child.kill()
            child.wait(timeout=5)
            with DeviceLease.acquire('fake-device-A', self.directory):
                pass
        finally:
            if child.poll() is None:
                child.kill()
            child.communicate(timeout=5)

    def test_lock_file_symlink_is_rejected(self):
        self.directory.mkdir()
        target = self.directory.parent / 'unrelated'
        target.write_text('untouched')
        lock = self.directory / (hashlib.sha256(b'fakedevicea').hexdigest() + '.lock')
        lock.symlink_to(target)
        with self.assertRaises(OSError):
            DeviceLease.acquire('fake-device-A', self.directory)
        self.assertEqual(target.read_text(), 'untouched')


class FakeLocation:
    def __init__(self):
        self.points = []
        self.clears = 0
        self.fail_set = False
        self.fail_clear = False

    async def set(self, latitude, longitude):
        self.points.append((latitude, longitude))
        if self.fail_set:
            raise ConnectionError('fake write failure')

    async def clear(self):
        self.clears += 1
        if self.fail_clear:
            raise ConnectionError('fake restore failure')


class FakeSession:
    def __init__(self, value):
        self.value = value
        self.closed = False

    async def __aenter__(self):
        return self.value

    async def __aexit__(self, *_):
        self.closed = True


class MockBridge(Bridge):
    def __init__(self):
        self.events = []
        super().__init__(lambda event, **values: self.events.append(dict(event=event, **values)))
        self.locations = {}
        self.opened = []
        self.sessions = []
        self.fail_open = False
        self.open_gate = None

    async def open_device(self, serial):
        self.opened.append(serial)
        self.stack = AsyncExitStack()
        session = FakeSession(None)
        self.sessions.append(session)
        await self.stack.enter_async_context(session)
        if self.open_gate:
            await self.open_gate.wait()
        if self.fail_open:
            raise ConnectionError('fake open failure')
        self.location = self.locations.setdefault(serial, FakeLocation())

    async def watch_usb(self):
        await asyncio.Event().wait()


def route(latitude, longitude, pace):
    return dict(points=[dict(latitude=latitude, longitude=longitude),
                        dict(latitude=latitude, longitude=longitude + .02)],
                paceSeconds=pace, loops=1, closed=False)


async def until(predicate, timeout=2):
    async def wait():
        while not predicate():
            await asyncio.sleep(.005)
    await asyncio.wait_for(wait(), timeout)


class DualBridgeTests(FixtureDirectory, unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.real_acquire = DeviceLease.acquire
        self.patch = patch.object(backend_module.DeviceLease, 'acquire',
                                  side_effect=lambda serial, directory=None: self.real_acquire(
                                      serial, directory if directory is not None else self.directory))
        self.patch.start()
        self.a, self.b = MockBridge(), MockBridge()

    async def asyncTearDown(self):
        for bridge in (self.a, self.b):
            await bridge.cancel_replay()
            await bridge.release()
        self.patch.stop()

    async def connect_both(self):
        await asyncio.gather(self.a.connect('fake-A'), self.b.connect('fake-B'))

    async def test_different_routes_and_paces_pause_stop_one_leave_other_running(self):
        await self.connect_both()
        await asyncio.gather(self.a.start(dict(mode='device', route=route(10, 20, 300))),
                             self.b.start(dict(mode='device', route=route(30, 40, 600))))
        for bridge in (self.a, self.b):
            bridge.clock.base = 120
            bridge.clock.started = time.monotonic()
        await until(lambda: all(any(event['event'] == 'position' and event['elapsed'] >= 120
                                   for event in bridge.events) for bridge in (self.a, self.b)))
        positions = [next(event for event in reversed(bridge.events) if event['event'] == 'position')
                     for bridge in (self.a, self.b)]
        self.assertGreaterEqual(positions[0]['distance'], 400)
        self.assertGreaterEqual(positions[1]['distance'], 200)
        self.assertAlmostEqual(positions[0]['distance'], 2 * positions[1]['distance'], delta=1)
        self.assertAlmostEqual(self.a.location.points[-1][0], 10, places=5)
        self.assertAlmostEqual(self.b.location.points[-1][0], 30, places=5)
        await self.a.handle(dict(command='pause', id='pause-A'))
        held = self.a.clock.elapsed(time.monotonic())
        self.assertEqual(self.a.state, 'paused')
        self.assertFalse(self.b.clock.paused)
        self.assertEqual(self.a.clock.elapsed(time.monotonic() + 100), held)
        await self.a.handle(dict(command='stop', id='stop-A'))
        count = len(self.b.location.points)
        await until(lambda: len(self.b.location.points) > count)
        self.assertEqual(self.a.location.clears, 1)
        self.assertEqual(self.b.location.clears, 0)
        self.assertEqual(self.b.state, 'playing')
        self.assertTrue(self.b.simulated)
        self.assertEqual(self.b.serial, 'fake-B')

    async def test_same_device_is_rejected_before_open_device(self):
        await self.a.connect('fake-A')
        await self.b.handle(dict(command='connect', device='fake-A', id='duplicate'))
        self.assertEqual(self.b.opened, [])
        self.assertIsNone(self.b.serial)
        self.assertEqual(self.a.serial, 'fake-A')
        response = next(event for event in self.b.events if event.get('id') == 'duplicate')
        self.assertFalse(response['ok'])
        self.assertEqual(response['code'], 'DeviceBusyError')

    async def test_release_keeps_lease_until_inflight_device_operation_finishes(self):
        await self.a.connect('fake-A')
        async with self.a.device_lock:
            releasing = asyncio.create_task(self.a.release())
            await until(lambda: self.a.serial is None)
            self.assertFalse(releasing.done())
            with self.assertRaises(DeviceBusyError):
                self.real_acquire('fake-A', self.directory)
        await releasing
        await self.b.connect('fake-A')

    async def test_failure_and_recovery_never_clear_other_device(self):
        await self.connect_both()
        self.a.location.fail_set = self.a.location.fail_clear = True
        await self.b.start(dict(mode='device', route=route(30, 40, 600)))
        await self.a.handle(dict(command='set', point=dict(latitude=10, longitude=20), id='fail-A'))
        self.assertTrue(self.a.uncertain)
        self.assertEqual(self.a.affected_serial, 'fake-A')
        await self.a.release()
        await self.a.handle(dict(command='connect', device='fake-B', id='wrong-target'))
        self.assertIsNone(self.a.serial)
        self.assertEqual(self.a.opened, ['fake-A'])
        self.assertEqual(self.b.location.clears, 0)
        await self.a.connect('fake-A')
        self.a.location.fail_clear = False
        await self.a.handle(dict(command='restore', id='restore-A'))
        self.assertFalse(self.a.uncertain)
        self.assertIsNone(self.a.affected_serial)
        self.assertEqual(self.a.location.clears, 1)
        self.assertEqual(self.b.location.clears, 0)
        self.assertEqual(self.b.state, 'playing')

    async def test_clear_checks_actual_target_even_if_transport_is_misassigned(self):
        await self.connect_both()
        self.a.affected_serial = 'fake-A'
        self.a.simulated = self.a.uncertain = True
        self.a.serial = 'fake-B'
        self.a.location = self.b.location
        with self.assertRaises(ConnectionError):
            await self.a.clear_device()
        self.assertEqual(self.b.location.clears, 0)
        self.assertEqual(self.a.affected_serial, 'fake-A')

    async def test_connect_failure_and_cancel_release_lease_and_resources(self):
        self.a.fail_open = True
        await self.a.handle(dict(command='connect', device='fake-A', id='failed'))
        self.assertIsNone(self.a.lease)
        self.assertTrue(self.a.sessions[-1].closed)
        self.assertIsNone(self.a.events[-1]['serial'])
        self.a.fail_open = False
        self.a.open_gate = asyncio.Event()
        task = asyncio.create_task(self.a.connect('fake-A'))
        await until(lambda: self.a.lease is not None)
        task.cancel()
        with self.assertRaises(asyncio.CancelledError):
            await task
        self.assertIsNone(self.a.lease)
        await self.b.connect('fake-A')

    async def test_disconnect_rejects_active_or_unresolved_then_allows_switch(self):
        await self.a.connect('fake-A')
        await self.a.start(dict(mode='device', route=route(10, 20, 300)))
        await self.a.handle(dict(command='disconnect', id='active'))
        self.assertIsNotNone(self.a.lease)
        self.a.location.fail_clear = True
        await self.a.handle(dict(command='stop', id='uncertain-stop'))
        await self.a.handle(dict(command='disconnect', id='uncertain'))
        self.assertIsNotNone(self.a.lease)
        self.a.location.fail_clear = False
        await self.a.perform('restore', {})
        await self.a.handle(dict(command='disconnect', id='idle'))
        self.assertIsNone(self.a.lease)
        self.assertIsNone(self.a.serial)
        self.assertEqual(self.a.state, 'idle')
        await self.b.connect('fake-A')
        await self.a.connect('fake-B')

    async def test_quit_releases_lease_even_when_restore_fails(self):
        await self.a.connect('fake-A')
        await self.a.perform('set', dict(point=dict(latitude=10, longitude=20)))
        self.a.location.fail_clear = True
        await self.a.handle(dict(command='quit', id='quit'))
        self.assertTrue(self.a.shutdown.is_set())
        self.assertIsNone(self.a.lease)
        self.assertIsNone(self.a.serial)
        self.assertEqual(self.a.affected_serial, 'fake-A')
        self.assertTrue(self.a.uncertain or self.a.simulated)
        await self.b.connect('fake-A')

    async def test_run_cancellation_always_closes_connection_and_releases_lease(self):
        await self.a.connect('fake-A')
        loop = asyncio.get_running_loop()
        with patch.object(loop, 'add_signal_handler'), \
             patch.object(loop, 'connect_read_pipe', new=AsyncMock(return_value=(None, None))), \
             patch.object(backend_module.importlib.metadata, 'version', return_value='test'):
            task = asyncio.create_task(self.a.run())
            await until(lambda: any(event['event'] == 'hello' for event in self.a.events))
            task.cancel()
            with self.assertRaises(asyncio.CancelledError):
                await task
        self.assertIsNone(self.a.lease)
        self.assertIsNone(self.a.serial)
        self.assertTrue(self.a.sessions[-1].closed)
        await self.b.connect('fake-A')

    async def test_status_connection_target_and_recovery_fields(self):
        await self.a.connect('fake-A')
        connecting = next(event for event in self.a.events if event.get('state') == 'connecting')
        self.assertEqual(connecting['serial'], 'fake-A')
        self.assertFalse(connecting['connected'])
        self.assertIsNone(connecting['affectedSerial'])
        await self.a.perform('set', dict(point=dict(latitude=10, longitude=20)))
        self.assertEqual(self.a.events[-1]['affectedSerial'], 'fake-A')
        await self.a.perform('restore', {})
        self.assertEqual(self.a.events[-1]['serial'], 'fake-A')
        self.assertIsNone(self.a.events[-1]['affectedSerial'])
        await self.a.disconnect()
        self.assertIsNone(self.a.events[-1]['serial'])


class PreparationTests(FixtureDirectory, unittest.IsolatedAsyncioTestCase):
    async def test_two_workers_prepare_exclusively_but_event_loop_keeps_running(self):
        entered, release_first = [], asyncio.Event()

        async def prepare(name):
            async with ddi_preparation_lease(self.directory, timeout=2):
                entered.append(name)
                if name == 'A':
                    await release_first.wait()

        first = asyncio.create_task(prepare('A'))
        await until(lambda: entered == ['A'])
        second = asyncio.create_task(prepare('B'))
        await asyncio.sleep(.07)
        self.assertEqual(entered, ['A'])
        release_first.set()
        await asyncio.gather(first, second)
        self.assertEqual(entered, ['A', 'B'])

    async def test_preparation_timeout_and_cancellation_release_lease(self):
        async with ddi_preparation_lease(self.directory):
            with self.assertRaises(asyncio.TimeoutError):
                async with ddi_preparation_lease(self.directory, timeout=.01):
                    self.fail('must not enter')
            entered = asyncio.Event()

            async def waiting():
                entered.set()
                async with ddi_preparation_lease(self.directory):
                    self.fail('must not enter')

            task = asyncio.create_task(waiting())
            await entered.wait()
            task.cancel()
            with self.assertRaises(asyncio.CancelledError):
                await task
        entered = asyncio.Event()

        async def holding():
            async with ddi_preparation_lease(self.directory):
                entered.set()
                await asyncio.Event().wait()

        task = asyncio.create_task(holding())
        await entered.wait()
        task.cancel()
        with self.assertRaises(asyncio.CancelledError):
            await task
        async with ddi_preparation_lease(self.directory, timeout=.1):
            pass


class IdentityTests(FixtureDirectory, unittest.IsolatedAsyncioTestCase):
    async def test_rsd_identity_is_checked_before_mount_or_location_service(self):
        for identity, accepted in [('FA-KEA', True), ('fake-B', False), ('', False), (None, False), ('---', False)]:
            with self.subTest(identity=identity):
                bridge = Bridge(lambda *args, **kwargs: None)
                mount = AsyncMock()
                remote = types.SimpleNamespace(udid=identity)
                lockdown = types.SimpleNamespace(product_version='27.0')
                mounter = types.SimpleNamespace(query_developer_mode_status=AsyncMock(return_value=True))
                modules = {}

                def module(name, **attributes):
                    value = types.ModuleType(name)
                    value.__dict__.update(attributes)
                    modules[name] = value

                module('pymobiledevice3.lockdown', create_using_usbmux=AsyncMock(return_value=FakeSession(lockdown)))
                module('pymobiledevice3.remote.rsd_tunnel', PreferredRsdTunnel=lambda **kwargs: FakeSession(remote))
                module('pymobiledevice3.services.mobile_image_mounter', MobileImageMounterService=lambda value: FakeSession(mounter), auto_mount=mount)
                module('pymobiledevice3.services.dvt.instruments.dvt_provider', DvtProvider=lambda value: FakeSession(None))
                location = FakeLocation()
                module('pymobiledevice3.services.dvt.instruments.location_simulation', LocationSimulation=lambda value: FakeSession(location))
                module('pymobiledevice3.exceptions', AlreadyMountedError=type('AlreadyMountedError', (Exception,), {}))
                module('pymobiledevice3.usbmux', list_devices=AsyncMock(return_value=[types.SimpleNamespace(serial='fake-A', is_usb=True)]))
                with patch.dict(sys.modules, modules), \
                     patch.object(backend_module, 'ddi_preparation_lease', side_effect=lambda: ddi_preparation_lease(self.directory)):
                    try:
                        if accepted:
                            await bridge.open_device('fake-A')
                            mount.assert_awaited_once_with(remote)
                            self.assertIs(bridge.location, location)
                        else:
                            with self.assertRaises(ValueError):
                                await bridge.open_device('fake-A')
                            mount.assert_not_awaited()
                            self.assertIsNone(bridge.location)
                    finally:
                        await bridge.release()
        for invalid in (None, '', '---'):
            with self.assertRaises(ValueError):
                normalize_serial(invalid)


if __name__ == '__main__':
    unittest.main()
