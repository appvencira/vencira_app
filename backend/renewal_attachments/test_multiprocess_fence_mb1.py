import os
import subprocess
import sys
import tempfile
from pathlib import Path
from django.test import SimpleTestCase
from .offline_multiprocess_fence_mb1 import IsolatedProcessFence, ProcessFenceError


class MB1MultiprocessFenceTests(SimpleTestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        os.chmod(self.tmp.name, 0o700)
        self.path = Path(self.tmp.name) / "capture.lock"
        self.fence = IsolatedProcessFence(self.path)

    def child(self, operation, timeout="0.15"):
        code = (
            "from renewal_attachments.offline_multiprocess_fence_mb1 "
            "import IsolatedProcessFence; import sys; "
            "f=IsolatedProcessFence(sys.argv[1]); "
            "with_context=f."+operation+"(timeout=float(sys.argv[2])); "
            "with_context.__enter__(); with_context.__exit__(None,None,None)"
        )
        return subprocess.run([sys.executable, "-c", code, str(self.path), timeout],
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                              timeout=5)

    def test_capture_blocks_writer_in_another_process(self):
        with self.fence.capture():
            self.assertNotEqual(self.child("writer").returncode, 0)
        self.assertEqual(self.child("writer").returncode, 0)

    def test_writer_blocks_capture_in_another_process(self):
        with self.fence.writer():
            self.assertNotEqual(self.child("capture").returncode, 0)
        self.assertEqual(self.child("capture").returncode, 0)

    def test_multiple_cooperative_writers_allowed(self):
        with self.fence.writer():
            self.assertEqual(self.child("writer").returncode, 0)

    def test_nested_capture_rejected_with_second_process(self):
        with self.fence.capture():
            self.assertNotEqual(self.child("capture").returncode, 0)

    def test_lock_released_after_exception(self):
        with self.assertRaises(ValueError):
            with self.fence.capture():
                raise ValueError("synthetic interruption")
        self.assertEqual(self.child("writer").returncode, 0)

    def test_invalid_permissions_rejected(self):
        self.path.touch(mode=0o600)
        os.chmod(self.path, 0o644)
        with self.assertRaises(ProcessFenceError):
            with self.fence.capture():
                pass
