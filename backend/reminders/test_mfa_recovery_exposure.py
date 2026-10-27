"""Contrato de bloqueo de recuperación administrativa hasta revisión operacional."""
from django.conf import settings
from django.test import SimpleTestCase
from django.urls import get_resolver


class AdministrativeRecoveryExposureTests(SimpleTestCase):
    def test_no_public_mfa_reset_endpoint_registered(self):
        # Resolver recursivo: ni include() ni rutas anidadas pueden publicar reset.
        def walk(patterns, prefix=""):
            for entry in patterns:
                path = prefix + str(entry.pattern)
                if hasattr(entry, "url_patterns"):
                    yield from walk(entry.url_patterns, path)
                else:
                    yield path
        paths = tuple(walk(get_resolver().url_patterns))
        forbidden = ("mfa/reset", "mfa/admin-recovery", "mfa/recovery/reset", "mfa/recovery/approve", "mfa/recovery/complete")
        # me/mfa/recovery/ack/ solo confirma posesión de códigos al activar MFA.
        self.assertFalse(
            [path for path in paths if any(piece in path.casefold() for piece in forbidden)],
            "La recuperación administrativa no puede exponerse públicamente",
        )

    def test_no_operational_reviewer_roster_by_default(self):
        self.assertEqual(settings.VENCIRA_MFA_RECOVERY_REVIEWER_IDS, ())
