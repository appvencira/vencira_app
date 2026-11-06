"""MB1 cross-process cooperative fence on isolated POSIX filesystem.

Linux flock: writers take LOCK_SH, capture takes LOCK_EX.
Only protects participants using this exact inode. Not an OS-wide write ban.
"""
from contextlib import contextmanager
import fcntl
import os
from pathlib import Path
import stat
import time


class ProcessFenceError(RuntimeError):
    pass


class IsolatedProcessFence:
    def __init__(self, lockfile):
        self.path = Path(lockfile)
        if not self.path.is_absolute() or self.path.is_symlink():
            raise ProcessFenceError("UNSAFE_LOCK_PATH")
        parent = self.path.parent
        if parent.is_symlink() or not parent.is_dir():
            raise ProcessFenceError("UNSAFE_LOCK_DIRECTORY")
        if parent.stat().st_mode & 0o077:
            raise ProcessFenceError("INSECURE_LOCK_DIRECTORY")

    @contextmanager
    def _acquire(self, operation, timeout):
        if type(timeout) not in (int, float) or not 0 < timeout <= 30:
            raise ProcessFenceError("INVALID_TIMEOUT")
        flags = os.O_RDWR | os.O_CREAT | os.O_CLOEXEC | getattr(os, "O_NOFOLLOW", 0)
        fd = os.open(str(self.path), flags, 0o600)
        try:
            info = os.fstat(fd)
            if not stat.S_ISREG(info.st_mode) or info.st_mode & 0o077 or info.st_nlink != 1:
                raise ProcessFenceError("INSECURE_LOCK_FILE")
            end = time.monotonic() + timeout
            while True:
                try:
                    fcntl.flock(fd, operation | fcntl.LOCK_NB)
                    break
                except BlockingIOError:
                    if time.monotonic() >= end:
                        raise ProcessFenceError("FENCE_TIMEOUT")
                    time.sleep(0.02)
            try:
                yield
            finally:
                fcntl.flock(fd, fcntl.LOCK_UN)
        finally:
            os.close(fd)

    def writer(self, timeout=3):
        return self._acquire(fcntl.LOCK_SH, timeout)

    def capture(self, timeout=3):
        return self._acquire(fcntl.LOCK_EX, timeout)
