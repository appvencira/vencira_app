"""CLI exclusivamente local: crea/cancela candidatos, NO los envía."""
from uuid import UUID

from django.core.management.base import BaseCommand, CommandError
from reminders.candidate_service import refresh_candidates


class Command(BaseCommand):
    help = "Prepara previsiones de aviso de una organización; nunca envía mensajes."

    def add_arguments(self, parser):
        parser.add_argument("--workspace", required=True, help="UUID de organización de pruebas")
        parser.add_argument("--horizon-days", type=int, default=30)

    def handle(self, *args, **options):
        try:
            workspace_id = UUID(options["workspace"])
            result = refresh_candidates(workspace_id, horizon_days=options["horizon_days"])
        except (ValueError, TypeError):
            raise CommandError("UUID u horizonte no válido") from None
        except Exception as exc:
            from reminders.models import Workspace
            if isinstance(exc, Workspace.DoesNotExist):
                raise CommandError("Organización inexistente") from None
            raise
        self.stdout.write(self.style.SUCCESS(
            f"Solo candidatos (sin envíos): {result['created']} nuevos, "
            f"{result['restored']} reactivados, {result['cancelled']} cancelados."
        ))
