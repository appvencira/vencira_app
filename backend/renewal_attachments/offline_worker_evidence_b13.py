"""B13A: recepción offline de una evidencia externa.

El receptor no escanea ni firma documentos.
No acepta resultados sin firma ni habilita descargas.
Solo ensayos con PostgreSQL temporal y datos sintéticos.
"""
from django.conf import settings
from django.core.exceptions import PermissionDenied

from reminders.attachment_scanner_worker import WorkerOutcome
from .offline_scan_evidence import persist_scan_evidence_offline


def accept_worker_evidence_offline(
    *,
    attachment_id,
    outcome,
    verification_key,
    expected_fingerprint,
    now=None,
):
    if (
        settings.VENCIRA_ENV != "test"
        or not getattr(
            settings,
            "VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED",
            False,
        )
    ):
        raise PermissionDenied("B13_TEST_ONLY")

    if (
        type(outcome) is not WorkerOutcome
        or outcome.verdict != "attested"
        or outcome.release_allowed is not False
        or type(outcome.attestation) is not dict
        or type(outcome.signature) is not str
        or type(verification_key) is not bytes
        or len(verification_key) < 32
        or type(expected_fingerprint) is not tuple
        or len(expected_fingerprint) != 6
    ):
        raise PermissionDenied("B13_UNTRUSTED_OUTCOME")

    return persist_scan_evidence_offline(
        attachment_id=attachment_id,
        payload=outcome.attestation,
        signature=outcome.signature,
        verification_key=verification_key,
        expected_fingerprint=expected_fingerprint,
        now=now,
    )
