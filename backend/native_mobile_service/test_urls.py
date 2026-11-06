"""ONLY a standalone URLConf for tests: never imported by config.urls."""
from django.urls import path
from . import test_views

urlpatterns = [
    path("api/v1/mobile/me/", test_views.CandidateMobileMe.as_view()),
    path(
        "api/v1/mobile/workspaces/<uuid:workspace_id>/renewals/",
        test_views.CandidateWorkspaceRenewals.as_view(),
    ),
]
