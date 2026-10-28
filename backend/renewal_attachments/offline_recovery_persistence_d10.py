"""Recuperación persistente solo en PostgreSQL 17 de ensayo.

Ninguna transición cierra expedientes ni autoriza archivos.
"""
from django.conf import settings
from django.core.exceptions import PermissionDenied
from django.db import connection, transaction
from django.db.models import F

from .models import (
    AttachmentRecoveryCase,
    RenewalAttachment,
)
from .offline_recovery_states_d10c import evaluate_recovery


def record_recovery_offline(*, attachment_id, classification):
    if (
        settings.VENCIRA_ENV != "test"
        or not getattr(
            settings,
            "VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED",
            False,
        )
        or connection.vendor != "postgresql"
    ):
        raise PermissionDenied("PG17_REHEARSAL_ONLY")

    decision = evaluate_recovery(classification)

    # Se bloquea la fila padre, existente antes de crear el expediente.
    # Esto serializa incluso la primera inserción de dos trabajadores.
    with transaction.atomic():
        attachment = (
            RenewalAttachment.objects
            .select_for_update()
            .get(pk=attachment_id)
        )

        if attachment.state != RenewalAttachment.State.QUARANTINED:
            raise PermissionDenied("ATTACHMENT_NOT_QUARANTINED")

        case, created = AttachmentRecoveryCase.objects.get_or_create(
            attachment=attachment,
            defaults={
                "status": decision.status,
                "classification": classification,
                "attempts": 1,
            },
        )

        if created:
            return case

        if (
            case.status == decision.status
            and case.classification == classification
        ):
            return case

        # No actualizar una decisión de revisión existente a partir
        # de una observación diferente: requiere intervención humana.
        raise PermissionDenied("RECOVERY_CONFLICT_REQUIRES_REVIEW")
