from django.urls import path
from . import views

urlpatterns = [
    path("me/", views.me, name="api-me"),
    path("workspaces/", views.workspaces, name="api-workspaces"),
    path("workspaces/<uuid:workspace_id>/members/", views.workspace_members, name="api-workspace-members"),
    path("workspaces/<uuid:workspace_id>/renewals/", views.renewals, name="api-renewals"),
    path("workspaces/<uuid:workspace_id>/renewals/<uuid:renewal_id>/", views.renewal_detail, name="api-renewal-detail"),
]
