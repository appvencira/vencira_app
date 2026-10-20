from django.contrib import admin
from django.urls import path
from .views import health, ready

urlpatterns = [
    path("api/health/", health, name="health"),
    path("api/ready/", ready, name="ready"),
    path("admin/", admin.site.urls),
]
