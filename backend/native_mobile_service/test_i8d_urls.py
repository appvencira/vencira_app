"""I8-D disposable native HTTP contract only. NEVER include in config.urls.

Routes can be selected only by ROOT_URLCONF override in an isolated test
runtime. No operational Django URL, DRF bearer class or web session changes.
"""
from django.urls import path
from . import test_i8d_http_views as views

urlpatterns = [
    path("api/v1/mobile/auth/password/", views.password),
    path("api/v1/mobile/auth/mfa/", views.mfa),
    path("api/v1/mobile/token/refresh/", views.refresh),
    path("api/v1/mobile/token/revoke/", views.revoke),
    path("api/v1/mobile/me/", views.me),
]
