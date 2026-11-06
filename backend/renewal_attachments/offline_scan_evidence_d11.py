"""D11: preflight puro y cerrado para evidencias de análisis de adjuntos.

No es un antivirus, no firma evidencias ni concede descargas.
La validación no permite modificar archivos ni estados persistentes.
"""
import hashlib
import hmac
import re

from django.core.exceptions import PermissionDenied
from django.conf import settings


def verify_scan_evidence_offline(*, content, expected_digest, evidence, signature, secret):
    """Valida estructura, integridad, vínculo a bytes y autenticación de evidencia."""
    if settings.VENCIRA_ENV != "test" or not getattr(settings, "VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED", False):
        raise PermissionDenied("ISOLATED_REHEARSAL_ONLY")
    if not isinstance(content, bytes):
        raise PermissionDenied("INVALID_CONTENT")
    if not isinstance(expected_digest, str) or not re.fullmatch(r"[0-9a-f]{64}", expected_digest):
        raise PermissionDenied("INVALID_DIGEST")
    if not isinstance(secret, bytes) or len(secret) < 32:
        raise PermissionDenied("INVALID_VERIFIER_KEY")
    if not isinstance(evidence, dict) or set(evidence) != {"sha256", "verdict", "engine", "version"}:
        raise PermissionDenied("INVALID_EVIDENCE")
    if not all(isinstance(evidence[k], str) for k in evidence):
        raise PermissionDenied("INVALID_EVIDENCE")
    if evidence["verdict"] != "clean":
        return False
    if not (0 < len(evidence["engine"]) <= 80 and 0 < len(evidence["version"]) <= 80):
        raise PermissionDenied("INVALID_ENGINE")
    if not isinstance(signature, str) or not re.fullmatch(r"[0-9a-f]{64}", signature):
        raise PermissionDenied("INVALID_SIGNATURE")
    digest = hashlib.sha256(content).hexdigest()
    if not hmac.compare_digest(digest, expected_digest):
        return False
    if not hmac.compare_digest(evidence["sha256"], expected_digest):
        return False
    message = "|".join((evidence["sha256"], evidence["verdict"], evidence["engine"], evidence["version"])).encode()
    expected_sig = hmac.new(secret, message, hashlib.sha256).hexdigest()
    return hmac.compare_digest(signature, expected_sig)
