"""Standalone Django URLConf for disposable N1 HTTP-contract tests ONLY.

NEVER include this file from config.urls or reminders.urls.
Requires ROOT_URLCONF override inside a test suite, and each view rejects
any runtime that isn't explicitly VENCIRA_ENV=test + lab enabled.
"""
from django.urls import path
from . import test_http_contract as views

urlpatterns = [
    path("lab/mobile/auth/password/", views.password, name="lab-native-password"),
    path("lab/mobile/auth/mfa/", views.mfa, name="lab-native-mfa"),
    path("lab/mobile/token/refresh/", views.refresh, name="lab-native-refresh"),
    path("lab/mobile/token/revoke/", views.revoke, name="lab-native-revoke"),
    path("lab/mobile/me/", views.me, name="lab-native-me"),
]
