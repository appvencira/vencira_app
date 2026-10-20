"""Superficie de datos deliberadamente reducida para evitar asignación de tenant."""
from rest_framework import serializers
from .models import Renewal, WorkspaceMember


class MembershipSerializer(serializers.ModelSerializer):
    id = serializers.UUIDField(source="workspace.id", read_only=True)
    name = serializers.CharField(source="workspace.name", read_only=True)

    class Meta:
        model = WorkspaceMember
        fields = ("id", "name", "role")
        read_only_fields = fields


class RenewalSerializer(serializers.ModelSerializer):
    class Meta:
        model = Renewal
        fields = ("id", "customer_reference", "expires_on", "notice_deadline_on", "status", "created_at", "updated_at")
        read_only_fields = ("id", "created_at", "updated_at")

    def validate(self, attrs):
        # Rechazo explícito de claves no editables y campos desconocidos:
        # no aceptar silenciosamente identificadores ajenos ni intentos de mass assignment.
        writable = {"customer_reference", "expires_on", "notice_deadline_on", "status"}
        forbidden = set(self.initial_data) - writable
        if forbidden:
            raise serializers.ValidationError({
                "fields": "No se permiten campos no editables o desconocidos."
            })
        expires = attrs.get("expires_on", getattr(self.instance, "expires_on", None))
        deadline = attrs.get(
            "notice_deadline_on", getattr(self.instance, "notice_deadline_on", None)
        )
        if expires is not None and deadline is not None and deadline > expires:
            raise serializers.ValidationError({
                "notice_deadline_on": "El límite de preaviso no puede ser posterior al vencimiento."
            })
        return attrs
