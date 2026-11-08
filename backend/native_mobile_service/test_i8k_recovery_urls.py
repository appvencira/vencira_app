"""I8-K recovery-only URLconf; MUST NEVER enter config.urls."""
from django.urls import path
from . import test_i8k_recovery_views as views

urlpatterns = [
    path("api/v1/mobile/auth/recover/password/", views.recover_password),
    path("api/v1/mobile/auth/recover/mfa/", views.recover_mfa),
    path("api/v1/mobile/me/", views.me),
]
