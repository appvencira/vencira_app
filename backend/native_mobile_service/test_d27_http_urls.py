"""Only included through override_settings(ROOT_URLCONF=...) in D27 tests."""
from django.urls import path

from . import test_d27_http_views as views

urlpatterns = [
    path("api/v1/mobile/auth/password/", views.password),
    path("api/v1/mobile/auth/mfa/", views.mfa),
    path("api/v1/mobile/auth/recover/password/", views.recover_password),
    path("api/v1/mobile/auth/recover/mfa/", views.recover_mfa),
    path("api/v1/mobile/token/refresh/", views.refresh),
    path("api/v1/mobile/token/revoke/", views.revoke),
    path("api/v1/mobile/me/", views.me),
]
