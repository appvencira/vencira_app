"""Genera datos sintéticos y credenciales de prueba solo en preview aislada."""
import os
import secrets
from datetime import timedelta

from django.conf import settings
from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction
from django.utils import timezone

from reminders.models import Renewal, Workspace, WorkspaceMember


class Command(BaseCommand):
    help = "Inicializa un usuario y vencimientos ficticios SOLO para preview local."

    def handle(self, *args, **options):
        if settings.VENCIRA_ENV != "development" or os.getenv("VENCIRA_PREVIEW_MODE") != "1":
            raise CommandError("seed_preview permitido solo en preview de desarrollo aislada.")
        username = "vencira_demo"
        password = secrets.token_urlsafe(24)
        with transaction.atomic():
            User = get_user_model()
            user, _ = User.objects.get_or_create(
                username=username,
                defaults={"is_staff": False, "is_superuser": False},
            )
            if user.is_staff or user.is_superuser:
                raise CommandError("La cuenta de pruebas tiene privilegios indebidos.")
            user.set_password(password)
            user.save(update_fields=["password"])
            workspace, _ = Workspace.objects.get_or_create(name="VENCIRA / DEMOSTRACIÓN")
            WorkspaceMember.objects.get_or_create(
                workspace=workspace,
                user=user,
                defaults={"role": WorkspaceMember.Role.OWNER},
            )
            today = timezone.localdate()
            examples = [
                ("DEMO-HOGAR-001", 7, 2, Renewal.Status.PENDING),
                ("DEMO-VEHICULO-002", 14, 8, Renewal.Status.PENDING),
                ("DEMO-SALUD-003", 30, 15, Renewal.Status.PENDING),
                ("DEMO-NEGOCIO-004", 45, 28, Renewal.Status.CONTACTED),
                ("DEMO-SERVICIO-005", 60, None, Renewal.Status.PENDING),
                ("DEMO-RENOVADO-006", 90, 70, Renewal.Status.CLOSED),
            ]
            for reference, days_to_expiry, days_to_notice, status in examples:
                Renewal.objects.get_or_create(
                    workspace=workspace,
                    customer_reference=reference,
                    defaults={
                        "expires_on": today + timedelta(days=days_to_expiry),
                        "notice_deadline_on": (
                            today + timedelta(days=days_to_notice)
                            if days_to_notice is not None else None
                        ),
                        "status": status,
                    },
                )
        self.stdout.write(self.style.SUCCESS(
            "VENCIRA preview creada con un usuario sin privilegios y seis referencias ficticias."
        ))
        self.stdout.write("USUARIO: " + username)
        self.stdout.write("CONTRASEÑA DE PRUEBA (se muestra una vez): " + password)
        self.stdout.write("No compartir la contraseña ni usar estos datos fuera del túnel SSH.")
