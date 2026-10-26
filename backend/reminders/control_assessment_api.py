"""O9a API GET: assessment only, no recording, queueing or delivery."""
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .control_assessment import assess_control
from .c2_control_policy import evaluate_c2_control_policy
from .default_reminders import DEFAULT_DAYS_BEFORE
from .models import Renewal, RenewalReminderDraft, OperationalReminder
from .views import _membership, _visible_renewals


def _result(body, code=status.HTTP_200_OK):
    response = Response(body, status=code)
    response["Cache-Control"] = "no-store"
    return response


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def control_assessment(request, workspace_id, renewal_id):
    membership = _membership(request, workspace_id)
    renewal = get_object_or_404(
        _visible_renewals(membership), pk=renewal_id,
    )
    if renewal.status == Renewal.Status.CLOSED or renewal.archived_at is not None:
        return _result(
            {"detail": "Anotación cerrada o archivada."},
            status.HTTP_409_CONFLICT,
        )
    if request.query_params:
        return _result(
            {"detail": "No se admiten parámetros de simulación."},
            status.HTTP_400_BAD_REQUEST,
        )

    saved = RenewalReminderDraft.objects.filter(renewal_id=renewal.pk).first()
    days = list(saved.days_before) if saved else list(DEFAULT_DAYS_BEFORE)
    assessment = assess_control(
        renewal.expires_on, days, as_of=timezone.localdate(),
        requires_life_review=(renewal.modality == "vida"),
    )
    policy = evaluate_c2_control_policy(
        renewal.expires_on, days, as_of=assessment.reference_day,
        is_life=(renewal.modality == "vida"),
    )
    return _result({
        "explicit_control_existing": OperationalReminder.objects.filter(
            renewal=renewal, source_key__startswith="explicit-control:",
            control_question=True,
            state__in=("planned", "pending", "snoozed"),
        ).exists(),
        "c2_policy": {
            "allow_save": policy.allow_save,
            "manual_review_required": policy.manual_review_required,
            "warning_code": policy.warning_code,
            "warning_severity": policy.warning_severity,
            "cutoff_on": policy.cutoff_on.isoformat() if policy.cutoff_on else None,
            "offer_explicit_control": policy.offer_explicit_control,
            "latest_explicit_control_day": (
                policy.latest_explicit_control_day.isoformat()
                if policy.latest_explicit_control_day else None),
            "future_notice_days": list(policy.future_notice_days),
            "is_life": policy.is_life,
            "delivery_status": policy.delivery_status,
        },
        "assessment_only": True,
        "answer_recorded": False,
        "scheduled": False,
        "delivered": False,
        "status": assessment.status,
        "reasons": list(assessment.reasons),
        "reference_day": assessment.reference_day.isoformat(),
        "informational_cutoff_on": assessment.cutoff_on.isoformat(),
        "control_day": (assessment.control_day.isoformat()
                        if assessment.control_day else None),
        "control_days_before": assessment.control_days_before,
        "days_before": days,
        "draft_persisted": saved is not None,
        "draft_revision": saved.revision if saved else 0,
    })
