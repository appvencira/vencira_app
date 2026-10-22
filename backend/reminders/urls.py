from django.urls import path
from . import views
from .modality_catalog import modalities, modality_detail
from .insurer_catalog import insurers, insurer_detail
from .agenda_month import agenda_month

urlpatterns = [
    path("me/", views.me, name="api-me"),
    path("workspaces/", views.workspaces, name="api-workspaces"),
    path("workspaces/<uuid:workspace_id>/members/", views.workspace_members, name="api-workspace-members"),
    path("workspaces/<uuid:workspace_id>/modalities/", modalities, name="api-modalities"),
    path("workspaces/<uuid:workspace_id>/insurers/", insurers, name="api-insurers"),
    path("workspaces/<uuid:workspace_id>/insurers/<uuid:insurer_id>/", insurer_detail, name="api-insurer-detail"),
    path("workspaces/<uuid:workspace_id>/modalities/<str:code>/", modality_detail, name="api-modality-detail"),
    path("workspaces/<uuid:workspace_id>/agenda/", views.agenda_day, name="api-agenda-day"),
    path("workspaces/<uuid:workspace_id>/agenda/month/", agenda_month, name="api-agenda-month"),
    path("workspaces/<uuid:workspace_id>/renewals/", views.renewals, name="api-renewals"),
    path("workspaces/<uuid:workspace_id>/renewals/<uuid:renewal_id>/", views.renewal_detail, name="api-renewal-detail"),
    path("workspaces/<uuid:workspace_id>/renewals/<uuid:renewal_id>/history/", views.renewal_history, name="api-renewal-history"),
]
