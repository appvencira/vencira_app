from django.contrib import admin
from django.contrib.auth import views as auth_views
from reminders.login_security import ProtectedLoginView
from django.urls import include, path

from .views import health, ready, csrf

urlpatterns = [
    path("api/health/", health, name="health"),
    path("api/v1/csrf/", csrf, name="api-csrf"),
    path("api/ready/", ready, name="ready"),
    path("api/v1/", include("reminders.urls")),
    path("accounts/login/", ProtectedLoginView.as_view(), name="login"),
    path("accounts/logout/", auth_views.LogoutView.as_view(), name="logout"),
    path("admin/", admin.site.urls),
]
