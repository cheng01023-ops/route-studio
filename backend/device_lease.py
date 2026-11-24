"""Local, cross-process ownership of a USB device; no device identifiers on disk."""
from __future__ import annotations

import errno
import asyncio
from contextlib import asynccontextmanager
import fcntl
import hashlib
import os
from pathlib import Path
import stat
import tempfile


class DeviceBusyError(RuntimeError):
    """Another bridge already owns the selected device."""


def normalize_serial(serial: str) -> str:
    if not isinstance(serial, str) or not serial or len(serial) > 1024:
        raise ValueError("设备标识无效。")
    normalized = serial.replace("-", "").lower()
    if not normalized:
        raise ValueError("设备标识无效。")
    return normalized


class DeviceLease:
    def __init__(self, descriptor: int, path: Path):
        self.descriptor = descriptor
        self.path = path

    @classmethod
    def acquire(cls, serial: str, directory: Path | None = None) -> "DeviceLease":
        serial = normalize_serial(serial)
        directory = Path(directory) if directory is not None else (
            Path(tempfile.gettempdir()) / f"route-studio-device-leases-{os.getuid()}")
        directory.mkdir(mode=0o700, parents=True, exist_ok=True)
        # Do not follow a replaced/symlinked lease directory or lease file.
        folder = os.open(directory, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC)
        try:
            info = os.fstat(folder)
            if info.st_uid != os.getuid():
                raise PermissionError("设备锁目录不属于当前用户。")
            os.fchmod(folder, 0o700)
            name = hashlib.sha256(serial.encode("utf-8")).hexdigest() + ".lock"
            descriptor = os.open(name, os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW | os.O_CLOEXEC,
                                 0o600, dir_fd=folder)
        finally:
            os.close(folder)
        try:
            info = os.fstat(descriptor)
            if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid():
                raise PermissionError("设备锁文件无效。")
            os.fchmod(descriptor, 0o600)
            try:
                fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except OSError as exc:
                if exc.errno in (errno.EACCES, errno.EAGAIN):
                    raise DeviceBusyError("该 iPhone 已被另一个通道或进程占用，请先断开原连接。") from None
                raise
            return cls(descriptor, directory / name)
        except BaseException:
            os.close(descriptor)
            raise

    def release(self):
        descriptor, self.descriptor = self.descriptor, None
        if descriptor is not None:
            try:
                fcntl.flock(descriptor, fcntl.LOCK_UN)
            finally:
                os.close(descriptor)
        # Never unlink the file: another process may already be waiting on, or
        # holding, this inode. The kernel also releases flock on process exit.

    def __enter__(self):
        return self

    def __exit__(self, *_):
        self.release()


@asynccontextmanager
async def ddi_preparation_lease(directory: Path | None = None, *, timeout: float = 240):
    """Serialize shared DDI cache preparation, without blocking the event loop."""
    lease = None

    async def acquire():
        nonlocal lease
        while lease is None:
            try:
                lease = DeviceLease.acquire("route-studio:shared-ddi-preparation:v1", directory)
            except DeviceBusyError:
                await asyncio.sleep(0.05)

    try:
        # Assign to the enclosing scope before returning so cancellation at the
        # wait_for boundary cannot lose a newly acquired lease.
        await asyncio.wait_for(acquire(), timeout)
        yield
    finally:
        if lease:
            lease.release()
