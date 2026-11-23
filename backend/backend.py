"""Private stdin/stdout JSON-lines bridge. Never opens a network control port."""
from __future__ import annotations

import asyncio
import contextlib
import importlib.metadata
import json
import logging
import signal
import sys
import time
from contextlib import AsyncExitStack

from route_engine import PlaybackClock, Point, Route


def emit(event: str, **data):
    print(json.dumps({"event": event, **data}, ensure_ascii=False, allow_nan=False), flush=True)


class Bridge:
    def __init__(self, sink=emit):
        self.emit = sink
        self.stack = None
        self.location = None
        self.lockdown = None
        self.serial = None
        self.affected_serial = None
        self.simulated = False
        self.uncertain = False
        self.connecting = False
        self.replay = None
        self.monitor = None
        self.clock = None
        self.route = None
        self.mode = "preview"
        self.state = "idle"
        self.operation_lock = asyncio.Lock()
        self.device_lock = asyncio.Lock()
        self.shutdown = asyncio.Event()
        self.operations = set()

    def status(self, state, message):
        self.state = state
        self.emit("status", state=state, message=message, mode=self.mode, simulated=self.simulated,
                  uncertain=self.uncertain, connected=self.location is not None)

    async def scan(self):
        from pymobiledevice3.usbmux import list_devices
        from pymobiledevice3.lockdown import create_using_usbmux
        devices = []
        for device in await asyncio.wait_for(list_devices(), 8):
            if not device.is_usb:
                continue
            item = {"id": device.serial, "name": "iPhone（请解锁并信任此电脑）", "version": "", "paired": False}
            try:
                async with await asyncio.wait_for(create_using_usbmux(serial=device.serial, connection_type="USB", autopair=False), 4) as lockdown:
                    item.update(name=lockdown.all_values.get("DeviceName", "iPhone"),
                                version=lockdown.product_version, paired=bool(lockdown.paired))
            except Exception:
                pass
            devices.append(item)
        self.emit("devices", devices=devices)

    async def connect(self, serial):
        if self.connecting or self.replay:
            raise ValueError("请先结束当前回放或等待连接完成。")
        if (self.simulated or self.uncertain) and self.location is not None:
            raise ValueError("请先恢复真实定位，再切换连接。")
        if self.affected_serial and serial != self.affected_serial:
            raise ValueError("请重新连接上次模拟位置的同一台 iPhone，先恢复其真实定位。")
        self.connecting = True
        try:
            async with self.operation_lock:
                await self.release()
                self.status("connecting", "正在配对；请解锁 iPhone，并在手机上信任此电脑…")
                await asyncio.wait_for(self.open_device(serial), 300)
                self.status("ready", "设备已就绪。" + ("上次恢复尚未确认，请先恢复真实定位。" if self.uncertain or self.simulated else "连接本身不会改变位置。"))
                self.monitor = asyncio.create_task(self.watch_usb())
        except BaseException:
            await self.release()
            raise
        finally:
            self.connecting = False

    async def open_device(self, serial):
        from pymobiledevice3.lockdown import create_using_usbmux
        from pymobiledevice3.remote.rsd_tunnel import PreferredRsdTunnel
        from pymobiledevice3.services.mobile_image_mounter import MobileImageMounterService, auto_mount
        from pymobiledevice3.services.dvt.instruments.dvt_provider import DvtProvider
        from pymobiledevice3.services.dvt.instruments.location_simulation import LocationSimulation
        from pymobiledevice3.exceptions import AlreadyMountedError
        from pymobiledevice3.usbmux import list_devices
        if serial not in {d.serial for d in await list_devices() if d.is_usb}:
            raise ValueError("未找到所选 USB 设备，请检查数据线。")
        self.stack = AsyncExitStack()
        self.serial = serial
        self.lockdown = await self.stack.enter_async_context(await create_using_usbmux(
            serial=serial, connection_type="USB", pair_timeout=45))
        if int(self.lockdown.product_version.split('.')[0]) < 17:
            raise ValueError("本版本面向 iOS 17 及以上设备。")
        async with MobileImageMounterService(self.lockdown) as mounter:
            if not await mounter.query_developer_mode_status():
                raise ValueError("请在 iPhone 设置 → 隐私与安全性中开启开发者模式，按提示重启后重新连接。")
        self.status("connecting", "正在建立开发连接…")
        rsd = await self.stack.enter_async_context(PreferredRsdTunnel(serial=serial))
        self.status("connecting", "正在准备开发镜像；首次可能需要从 Apple 下载，请保持联网…")
        try:
            await auto_mount(rsd)
        except AlreadyMountedError:
            pass
        dvt = await self.stack.enter_async_context(DvtProvider(rsd))
        self.location = await self.stack.enter_async_context(LocationSimulation(dvt))

    async def watch_usb(self):
        try:
            from pymobiledevice3.usbmux import list_devices
            while True:
                await asyncio.sleep(3)
                devices = await asyncio.wait_for(list_devices(), 5)
                if not any(d.serial == self.serial and d.is_usb for d in devices):
                    raise ConnectionError("USB 已断开。")
                await asyncio.wait_for(self.lockdown.get_value(key="DeviceName"), 5)
        except asyncio.CancelledError:
            return
        except Exception:
            self.uncertain = self.uncertain or self.simulated
            await self.cancel_replay()
            await self.release(from_monitor=True)
            self.status("disconnected", "连接已断开。若曾模拟位置，请重新连接后恢复真实定位，或重启 iPhone。")

    async def release(self, from_monitor=False):
        if self.monitor and not from_monitor:
            self.monitor.cancel()
            with contextlib.suppress(asyncio.CancelledError):
                await self.monitor
        self.monitor = None
        self.location = None
        self.lockdown = None
        self.serial = None
        if self.stack:
            stack, self.stack = self.stack, None
            try:
                await asyncio.wait_for(stack.aclose(), 8)
            except Exception:
                logging.exception("开发连接关闭失败")

    async def cancel_replay(self):
        task, self.replay = self.replay, None
        if task and task is not asyncio.current_task():
            task.cancel()
            with contextlib.suppress(asyncio.CancelledError):
                await task

    async def write_location(self, point):
        async with self.device_lock:
            if not self.location:
                raise ConnectionError("设备尚未连接。")
            # Mark before awaiting: a transport failure may occur after the device accepted the write.
            self.simulated = True
            self.uncertain = True
            self.affected_serial = self.serial
            await asyncio.wait_for(self.location.set(point["latitude"], point["longitude"]), 8)
            self.uncertain = False

    async def start(self, command):
        if self.connecting:
            raise ValueError("设备正在准备，请稍候。")
        if self.replay:
            raise ValueError("已有回放正在进行，请先结束。")
        mode = command.get("mode", "preview")
        if mode not in ("preview", "device"):
            raise ValueError("回放模式无效。")
        if mode == "device" and not self.location:
            raise ValueError("请先连接 iPhone。")
        if mode == "preview" and (self.simulated or self.uncertain):
            raise ValueError("请先恢复真实定位，再运行离线预览。")
        route = Route(command["route"])
        self.route, self.mode = route, mode
        first = route.sample(0)
        if mode == "device":
            await self.write_location(first)
        # Start the clock after the initial device call, not while the tunnel is warming up.
        self.clock = PlaybackClock(time.monotonic())
        self.emit("position", **first, mode=mode)
        self.status("playing", "正在离线预览" if mode == "preview" else "正在向 iPhone 回放路线")
        self.replay = asyncio.create_task(self.run_route())

    async def run_route(self):
        try:
            deadline = time.monotonic()
            while True:
                # Reassert the held point while paused; elapsed time stays frozen.
                sample = self.route.sample(self.clock.elapsed(time.monotonic()))
                if self.mode == "device":
                    await self.write_location(sample)
                self.emit("position", **sample, mode=self.mode)
                if sample["complete"]:
                    if self.mode == "device":
                        await self.clear_device()
                        self.status("completed", "路线完成，已发送恢复真实定位指令。请在手机地图确认。")
                    else:
                        self.status("completed", "离线预览完成。")
                    break
                deadline += 1.0
                now = time.monotonic()
                if deadline < now:
                    deadline = now  # Do not burst stale coordinates after a slow call.
                await asyncio.sleep(max(0, deadline - now))
        except asyncio.CancelledError:
            raise
        except Exception as exc:
            # A failed location write never gets counted as a successful restore.
            restored = False
            try:
                if self.mode == "device":
                    await self.clear_device()
                    restored = True
            except Exception:
                self.uncertain = True
            self.status("error", f"回放已停止：{type(exc).__name__}。" + (
                "已发送恢复指令。" if restored else "请检查 USB，并尝试恢复真实定位。"))
        finally:
            self.replay = None

    async def clear_device(self):
        async with self.device_lock:
            if not self.location:
                raise ConnectionError("设备未连接，无法发送恢复指令。")
            await asyncio.wait_for(self.location.clear(), 8)
            self.simulated = False
            self.uncertain = False
            self.affected_serial = None

    async def stop(self):
        await self.cancel_replay()
        if self.simulated or self.uncertain:
            await self.clear_device()
            self.status("ready", "已发送恢复真实定位指令。请在手机地图确认。")
        else:
            self.status("ready" if self.location else "idle", "回放已结束。")

    async def perform(self, op, command):
        if op == "start":
            await self.start(command)
        elif op == "pause":
            if not self.replay or self.state != "playing":
                raise ValueError("没有正在播放的路线。")
            self.clock.pause(time.monotonic())
            self.status("paused", "已暂停，位置保持在当前点。")
        elif op == "resume":
            if not self.replay or self.state != "paused":
                raise ValueError("没有已暂停的路线。")
            self.clock.resume(time.monotonic())
            self.status("playing", "已继续回放。")
        elif op == "stop":
            await self.stop()
        elif op == "restore":
            await self.cancel_replay()
            await self.clear_device()
            self.status("ready", "已发送恢复真实定位指令。请在手机地图确认。")
        elif op == "set":
            if self.replay or self.connecting:
                raise ValueError("请先结束回放或等待连接完成。")
            point = Point.parse(command["point"])
            self.mode = "device"
            await self.write_location(point.json())
            self.emit("position", **point.json(), mode="device", distance=0, elapsed=0)
            self.status("holding", "已设置固定位置；结束后请恢复真实定位。")
        else:
            raise ValueError("未知命令。")

    async def handle(self, command):
        request = command.get("id")
        op = command.get("command")
        try:
            if op == "scan":
                await self.scan()
            elif op == "connect":
                if self.operation_lock.locked():
                    raise ValueError("正在执行另一项操作，请稍候。")
                await self.connect(command["device"])
            elif op == "quit":
                others = [task for task in self.operations if task is not asyncio.current_task()]
                for task in others:
                    task.cancel()
                if others:
                    await asyncio.gather(*others, return_exceptions=True)
                await self.stop()
                self.shutdown.set()
            else:
                if self.connecting or self.operation_lock.locked():
                    raise ValueError("正在执行另一项操作，请稍候。")
                async with self.operation_lock:
                    await self.perform(op, command)
            self.emit("response", id=request, ok=True)
        except asyncio.CancelledError:
            raise
        except Exception as exc:
            detail = str(exc)[:350]
            if not detail:
                detail = type(exc).__name__
            self.emit("response", id=request, ok=False, message=detail, code=type(exc).__name__)
            if op == "connect":
                self.status("error", detail)
            elif op in ("set", "start", "stop", "restore") and (self.simulated or self.uncertain):
                self.status("error", "操作未完成，请检查连接并恢复真实定位。" + detail)

    async def run(self):
        self.emit("hello", version="1.0.0", dependency=importlib.metadata.version("pymobiledevice3"))
        loop = asyncio.get_running_loop()
        def request_shutdown():
            self.shutdown.set()
        for sig in (signal.SIGTERM, signal.SIGINT):
            loop.add_signal_handler(sig, request_shutdown)
        async def read_commands():
            # StreamReader avoids an executor thread stuck on stdin when the GUI is terminated.
            reader = asyncio.StreamReader(limit=4_000_000)
            protocol = asyncio.StreamReaderProtocol(reader)
            await loop.connect_read_pipe(lambda: protocol, sys.stdin.buffer)
            while not self.shutdown.is_set():
                line = await reader.readline()
                if not line:
                    self.shutdown.set()
                    break
                try:
                    command = json.loads(line)
                    if not isinstance(command, dict):
                        raise ValueError("命令必须为对象。")
                    task = asyncio.create_task(self.handle(command))
                    self.operations.add(task)
                    task.add_done_callback(self.operations.discard)
                except Exception as exc:
                    self.emit("response", ok=False, message=str(exc))
        reader_task = asyncio.create_task(read_commands())
        await self.shutdown.wait()
        reader_task.cancel()
        for task in list(self.operations):
            task.cancel()
        if self.operations:
            await asyncio.gather(*self.operations, return_exceptions=True)
        try:
            await self.stop()
        except Exception:
            self.emit("shutdown_warning", message="恢复定位未确认，请重连后恢复，或重启 iPhone。")
        await self.release()


if __name__ == "__main__":
    logging.basicConfig(level=logging.WARNING, stream=sys.stderr)
    if "--self-check" in sys.argv:
        from pymobiledevice3.remote.rsd_tunnel import PreferredRsdTunnel
        from pymobiledevice3.services.mobile_image_mounter import auto_mount
        from pymobiledevice3.services.dvt.instruments.location_simulation import LocationSimulation
        emit("self_check", ok=True, dependency=importlib.metadata.version("pymobiledevice3"))
    else:
        asyncio.run(Bridge().run())
