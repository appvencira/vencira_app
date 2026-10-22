"""Filtros de anotaciones previos a paginación y agregaciones por día/mes."""
from rest_framework.exceptions import ValidationError
from .models import Renewal


def filtered_renewals(query_params, queryset):
    entry = query_params.get("entry", "")
    modality = query_params.get("modality", "")
    if entry and entry not in Renewal.Entry.values:
        raise ValidationError({"entry": "Entrada no válida."})
    if modality and (
        not isinstance(modality, str) or
        len(modality) > 64 or
        not modality[0].islower() or
        not all(ch in "abcdefghijklmnopqrstuvwxyz0123456789_-" for ch in modality)
    ):
        raise ValidationError({"modality": "Modalidad no válida."})
    if len(query_params.getlist("entry")) > 1 or len(query_params.getlist("modality")) > 1:
        raise ValidationError({"filters": "Filtros duplicados."})
    if entry:
        queryset = queryset.filter(entry=entry)
    if modality:
        queryset = queryset.filter(modality=modality)
    return queryset
