"""D22 isolated URLconf: never import/include from operational config.urls."""
from django.urls import path
from . import test_d22_http_views as views

urlpatterns = [
    path("api/v1/mobile/auth/password/", views.password),
    path("api/v1/mobile/auth/mfa/", views.mfa),
    path("api/v1/mobile/auth/recover/password/", views.recover_password),
    path("api/v1/mobile/auth/recover/mfa/", views.recover_mfa),
    path("api/v1/mobile/token/revoke/", views.revoke),
    path("api/v1/mobile/me/", views.me),
    path("api/v1/mobile/workspaces/<uuid:workspace_id>/renewals/", views.workspace_renewals),
    path("api/v1/mobile/workspaces/<uuid:workspace_id>/renewals/cursor/", views.workspace_cursor_renewals),
]
