from django.urls import path
from . import views
from .modality_catalog import modalities, modality_detail
from .insurer_catalog import insurers, insurer_detail
from .agenda_month import agenda_month
from .person_suggestions import person_suggestions
from .follow_up import manual_follow_up
from .outcomes import renewal_outcomes
from .results import results_summary
from .reminder_preview import renewal_reminder_preview
from .reminder_draft import reminder_draft
from .control_assessment_api import control_assessment
from .control_response_api import control_responses
from .operational_api import operational_reminders

urlpatterns = [
    path("me/", views.me, name="api-me"),
    path("workspaces/", views.workspaces, name="api-workspaces"),
    path("workspaces/<uuid:workspace_id>/members/", views.workspace_members, name="api-workspace-members"),
    path("workspaces/<uuid:workspace_id>/results/", results_summary, name="api-results-summary"),
    path("workspaces/<uuid:workspace_id>/modalities/", modalities, name="api-modalities"),
    path("workspaces/<uuid:workspace_id>/insurers/", insurers, name="api-insurers"),
    path("workspaces/<uuid:workspace_id>/insurers/<uuid:insurer_id>/", insurer_detail, name="api-insurer-detail"),
    path("workspaces/<uuid:workspace_id>/modalities/<str:code>/", modality_detail, name="api-modality-detail"),
    path("workspaces/<uuid:workspace_id>/agenda/", views.agenda_day, name="api-agenda-day"),
    path("workspaces/<uuid:workspace_id>/agenda/month/", agenda_month, name="api-agenda-month"),
    path("workspaces/<uuid:workspace_id>/renewals/suggestions/", person_suggestions, name="api-person-suggestions"),
    path("workspaces/<uuid:workspace_id>/renewals/", views.renewals, name="api-renewals"),
    path("workspaces/<uuid:workspace_id>/renewals/<uuid:renewal_id>/", views.renewal_detail, name="api-renewal-detail"),
    path("workspaces/<uuid:workspace_id>/renewals/<uuid:renewal_id>/history/", views.renewal_history, name="api-renewal-history"),
    path("workspaces/<uuid:workspace_id>/renewals/<uuid:renewal_id>/reminder-preview/", renewal_reminder_preview, name="api-reminder-preview"),
    path("workspaces/<uuid:workspace_id>/renewals/<uuid:renewal_id>/reminder-config/", reminder_draft, name="api-reminder-draft"),
    path("workspaces/<uuid:workspace_id>/renewals/<uuid:renewal_id>/control-assessment/", control_assessment, name="api-control-assessment"),
    path("workspaces/<uuid:workspace_id>/renewals/<uuid:renewal_id>/control-responses/", control_responses, name="api-control-responses"),
    path("workspaces/<uuid:workspace_id>/renewals/<uuid:renewal_id>/operational-reminders/", operational_reminders, name="api-operational-reminders"),
    path("workspaces/<uuid:workspace_id>/renewals/<uuid:renewal_id>/follow-up/", manual_follow_up, name="api-manual-follow-up"),
    path("workspaces/<uuid:workspace_id>/renewals/<uuid:renewal_id>/outcomes/", renewal_outcomes, name="api-renewal-outcomes"),
]
