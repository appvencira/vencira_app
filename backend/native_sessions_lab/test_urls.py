"""Standalone Django URLConf for disposable N1 HTTP-contract tests ONLY.

NEVER include this file from config.urls or reminders.urls.
Requires ROOT_URLCONF override inside a test suite, and each view rejects
any runtime that isn't explicitly VENCIRA_ENV=test + lab enabled.
"""
from django.urls import path
from . import test_http_contract as views

urlpatterns = [
    path("api/v1/mobile/auth/password/", views.password, name="lab-native-password"),
    path("api/v1/mobile/auth/mfa/", views.mfa, name="lab-native-mfa"),
    path("api/v1/mobile/auth/recover/password/",
         views.recovery_password, name="lab-native-recovery-password"),
    path("api/v1/mobile/auth/recover/mfa/",
         views.recovery_mfa, name="lab-native-recovery-mfa"),
    path("api/v1/mobile/token/refresh/", views.refresh, name="lab-native-refresh"),
    path("api/v1/mobile/token/revoke/", views.revoke, name="lab-native-revoke"),
    path("api/v1/mobile/me/", views.me, name="lab-native-me"),
    path("api/v1/mobile/workspaces/<uuid:workspace_id>/renewals/",
         views.workspace_renewals, name="lab-native-workspace-renewals"),
]
