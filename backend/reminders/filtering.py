"""Filtros de anotaciones previos a paginación y agregaciones por día/mes."""
from rest_framework.exceptions import ValidationError
import uuid
from .models import Renewal


def filtered_renewals(query_params, queryset):
    entry = query_params.get("entry", "")
    modality = query_params.get("modality", "")
    insurer = query_params.get("insurer", "")
    if entry and entry not in Renewal.Entry.values:
        raise ValidationError({"entry": "Entrada no válida."})
    if modality and (
        not isinstance(modality, str) or
        len(modality) > 64 or
        not modality[0].islower() or
        not all(ch in "abcdefghijklmnopqrstuvwxyz0123456789_-" for ch in modality)
    ):
        raise ValidationError({"modality": "Modalidad no válida."})
    if any(len(query_params.getlist(k)) > 1 for k in ("entry", "modality", "insurer")):
        raise ValidationError({"filters": "Filtros duplicados."})
    if insurer:
        try:
            if str(uuid.UUID(insurer)) != insurer.lower():
                raise ValueError("Non-canonical")
        except (ValueError, AttributeError):
            raise ValidationError({"insurer": "Aseguradora no válida."})
        queryset = queryset.filter(insurer_id=insurer)
    if entry:
        queryset = queryset.filter(entry=entry)
    if modality:
        queryset = queryset.filter(modality=modality)
    return queryset
