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
        fields = ("id", "customer_reference", "expires_on", "status", "created_at", "updated_at")
        read_only_fields = ("id", "created_at", "updated_at")

    def validate(self, attrs):
        # Ni la organización ni el propietario pueden asignarse mediante JSON.
        if "workspace" in self.initial_data or "workspace_id" in self.initial_data:
            raise serializers.ValidationError({"workspace": "La organización procede de la URL autorizada."})
        return attrs
