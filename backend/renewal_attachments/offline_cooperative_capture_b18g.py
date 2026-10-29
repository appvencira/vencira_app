"""B18G synthetic capture coordinator: fail-closed, test/PG17 only.

Coordinates only cooperative writers using B06B. It does NOT protect
filesystem from noncooperative actors, guarantee universal writer coverage,
or authorize an operational backup.
"""
from django.conf import settings
from django.core.exceptions import PermissionDenied
from django.db import connection
from .offline_write_barrier_b06b import advisory_barrier
from .offline_capture_set_b18e import verify_capture_set, CaptureSetError

# Explicit finite allowlist. Adding a writer requires a deliberate review.
REQUIRED_WRITERS = frozenset({
    "offline_intake",
    "offline_transport_receiver_b17",
    "offline_rejection_recovery",
    "offline_recovery_persistence_d10",
})

class SyntheticCaptureRejected(RuntimeError):
    pass


def capture_cooperative_synthetic(*, registered_writers, drained,
                                  sample_before, sample_components,
                                  sample_after):
    """Callers provide independent samplers; no writes, persistence or I/O here.

    Samplers execute under the same exclusive advisory lock; writers using
    B06B shared mode wait until it is released. Any mismatch rejects capture.
    """
    if (settings.VENCIRA_ENV != "test"
            or not getattr(settings, "VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED", False)
            or connection.vendor != "postgresql"):
        raise PermissionDenied("B18G_TEST_PG17_ONLY")
    if (type(registered_writers) not in (set, frozenset)
            or registered_writers != REQUIRED_WRITERS
            or drained is not True
            or not callable(sample_before)
            or not callable(sample_components)
            or not callable(sample_after)):
        raise SyntheticCaptureRejected("B18G_WRITER_COVERAGE_OR_DRAIN_INVALID")
    try:
        with advisory_barrier(capture=True):
            before = sample_before()
            components = sample_components()
            after = sample_after()
            if type(components) is not dict or set(components) != {
                "db_records", "encrypted_objects", "journals"
            }:
                raise SyntheticCaptureRejected("B18G_INVALID_COMPONENTS")
            return verify_capture_set(
                before=before, after=after, drained=True, missing_writers=(),
                **components,
            )
    except CaptureSetError as exc:
        raise SyntheticCaptureRejected("B18G_INCONSISTENT_CUT") from exc
