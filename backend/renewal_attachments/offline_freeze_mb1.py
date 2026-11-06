"""MB1-FREEZE: in-process synthetic writer gate and capture cut.

Scope: one explicitly owned test process. Not a cross-process / database /
filesystem lock. Never use as a production backup freeze.
"""
from contextlib import contextmanager
from threading import Condition
from time import monotonic


class FreezeError(RuntimeError):
    pass


class SyntheticWriterGate:
    def __init__(self):
        self._cv = Condition()
        self._active = 0
        self._frozen = False
        self._capture_active = False

    @contextmanager
    def writer(self):
        with self._cv:
            if self._frozen:
                raise FreezeError("FREEZE_REJECTS_NEW_WRITER")
            self._active += 1
        try:
            yield
        finally:
            with self._cv:
                self._active -= 1
                self._cv.notify_all()

    @contextmanager
    def freeze(self, *, timeout=3):
        if type(timeout) not in (int, float) or not 0 < timeout <= 30:
            raise FreezeError("INVALID_TIMEOUT")
        with self._cv:
            if self._frozen or self._capture_active:
                raise FreezeError("CAPTURE_ALREADY_ACTIVE")
            self._frozen = True
            end = monotonic() + timeout
            while self._active:
                remaining = end - monotonic()
                if remaining <= 0:
                    self._frozen = False
                    self._cv.notify_all()
                    raise FreezeError("ACTIVE_WRITERS_NOT_DRAINED")
                self._cv.wait(remaining)
            self._capture_active = True
        try:
            yield
        finally:
            with self._cv:
                self._capture_active = False
                self._frozen = False
                self._cv.notify_all()


def capture_synthetic_set(gate, *, sample_before, sample_components,
                          sample_after):
    from .offline_capture_set_b18e import verify_capture_set
    if not isinstance(gate, SyntheticWriterGate):
        raise FreezeError("UNKNOWN_GATE")
    if not all(callable(x) for x in (
        sample_before, sample_components, sample_after,
    )):
        raise FreezeError("INVALID_SAMPLERS")
    with gate.freeze():
        before = sample_before()
        components = sample_components()
        after = sample_after()
        if type(components) is not dict or set(components) != {
            "db_records", "encrypted_objects", "journals",
        }:
            raise FreezeError("MISSING_CAPTURE_COMPONENTS")
        return verify_capture_set(
            before=before, after=after,
            missing_writers=(), drained=True, **components,
        )
