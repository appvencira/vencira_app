"""Read-only MFA release guard. Never exposes secrets or mutates DB."""
from django.conf import settings
from django.core.management.base import BaseCommand
from django.db import connection
from django.db.migrations.recorder import MigrationRecorder

from reminders.mfa_key_config import load_mfa_keys

from reminders.management.commands.mfa_rollback_guard import REQUIRED


def readiness_report():
    checks = {}
    checks["enrollment_flag_off"] = not getattr(settings, "VENCIRA_MFA_ENROLLMENT_ENABLED", False)
    try:
        checks["mfa_keyring_valid"] = bool(load_mfa_keys())
    except (ValueError, TypeError):
        checks["mfa_keyring_valid"] = False
    try:
        recorder = MigrationRecorder(connection)
        applied = recorder.applied_migrations() if recorder.has_table() else set()
        checks["mfa_migrations_applied"] = all(
            ("reminders", name) in applied for name in REQUIRED
        )
    except Exception:
        checks["mfa_migrations_applied"] = False
    try:
        if checks["mfa_migrations_applied"]:
            from reminders.models import UserMfaState
            checks["active_accounts"] = UserMfaState.objects.filter(enabled=True).count()
        else:
            checks["active_accounts"] = None
    except Exception:
        checks["active_accounts"] = None
    return checks


class Command(BaseCommand):
    help = "Inspección MFA solo lectura; nunca activa flags ni aplica migraciones."

    def handle(self, *args, **options):
        checks = readiness_report()
        for name in ("enrollment_flag_off", "mfa_keyring_valid", "mfa_migrations_applied"):
            self.stdout.write(f"{name.upper()}={'OK' if checks[name] else 'PENDING'}")
        active = checks["active_accounts"]
        self.stdout.write(f"MFA_ACTIVE_ACCOUNTS={active if active is not None else 'UNKNOWN'}")
        self.stdout.write("MFA_READINESS_REPORT=READ_ONLY")
        self.stdout.write("MFA_RELEASE_AUTHORIZED=NO")
