"""Fail-closed, read-only preflight for deploying older auth code.

Requires an explicit declaration about MFA enforcement in the candidate build.
Never changes data or treats unknown database state as zero accounts.
"""
from django.core.management.base import BaseCommand, CommandError
from django.db import connection
from django.db.migrations.recorder import MigrationRecorder

REQUIRED = (
    "0019_user_mfa_state", "0020_mfa_attempt_limits", "0021_mfa_prepared_at",
    "0022_mfa_admin_recovery_cases", "0023_user_mfa_session_epoch",
    "0024_mfa_pending_rotation", "0025_mfa_pending_rotation_codes",
)


def check_candidate(*, candidate_enforces_mfa: bool) -> tuple[bool, str]:
    try:
        recorder = MigrationRecorder(connection)
        if not recorder.has_table():
            return False, "UNKNOWN_SCHEMA"
        applied = recorder.applied_migrations()
        if not all(("reminders", name) in applied for name in REQUIRED):
            return False, "MFA_SCHEMA_NOT_READY"
        from reminders.models import UserMfaState
        active = UserMfaState.objects.filter(enabled=True).exists()
    except Exception:
        return False, "MFA_STATE_UNAVAILABLE"
    if active and not candidate_enforces_mfa:
        return False, "MFA_DOWNGRADE_FORBIDDEN"
    return True, "MFA_ENFORCEMENT_COMPATIBLE" if active else "NO_ACTIVE_MFA_ACCOUNTS"


class Command(BaseCommand):
    help = "Preflight de rollback MFA de solo lectura; bloquear ante estado desconocido."

    def add_arguments(self, parser):
        group = parser.add_mutually_exclusive_group(required=True)
        group.add_argument("--candidate-enforces-mfa", action="store_true")
        group.add_argument("--candidate-lacks-mfa", action="store_true")

    def handle(self, *args, **options):
        allowed, reason = check_candidate(
            candidate_enforces_mfa=bool(options["candidate_enforces_mfa"]),
        )
        self.stdout.write(f"MFA_ROLLBACK_GUARD={reason}")
        if not allowed:
            raise CommandError("Despliegue/reversión bloqueados por protección MFA.")
        self.stdout.write("MFA_ROLLBACK_PRECHECK=OK")
