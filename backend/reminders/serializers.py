"""Superficie de datos deliberadamente reducida para evitar asignación de tenant."""
from django.contrib.auth import get_user_model
from rest_framework import serializers
from .models import Renewal, WorkspaceMember, WorkspaceInsurer
from .modality_catalog import modality_valid


class MembershipSerializer(serializers.ModelSerializer):
    id = serializers.UUIDField(source="workspace.id", read_only=True)
    name = serializers.CharField(source="workspace.name", read_only=True)

    class Meta:
        model = WorkspaceMember
        fields = ("id", "name", "role")
        read_only_fields = fields


class RenewalSerializer(serializers.ModelSerializer):
    insurer = serializers.PrimaryKeyRelatedField(
        queryset=WorkspaceInsurer.objects.all(), allow_null=True, required=False,
    )
    assigned_to = serializers.PrimaryKeyRelatedField(
        queryset=get_user_model().objects.all(),
        allow_null=True,
        required=False,
    )

    class Meta:
        model = Renewal
        fields = ("id", "customer_reference", "entry", "modality", "insurer",
                  "expires_on", "notice_deadline_on", "status",
                  "assigned_to", "created_at", "updated_at")
        read_only_fields = ("id", "created_at", "updated_at")

    def validate(self, attrs):
        # Rechazo explícito de claves no editables y campos desconocidos:
        # no aceptar silenciosamente identificadores ajenos ni intentos de mass assignment.
        writable = {"customer_reference", "entry", "modality", "expires_on",
                    "notice_deadline_on", "status", "assigned_to", "insurer"}
        forbidden = set(self.initial_data) - writable
        if forbidden:
            raise serializers.ValidationError({
                "fields": "No se permiten campos no editables o desconocidos."
            })
        # Legacy: filas previas sin Entrada continúan legibles/editables.
        # La UI de creación nueva exige elección; API conserva compatibilidad
        # con clientes provisionales anteriores durante la migración.
        if "entry" in self.initial_data and self.initial_data["entry"] in ("", None):
            raise serializers.ValidationError({
                "entry": "Selecciona Clientes o Candidatos.",
            })
        if "modality" in attrs:
            code = attrs["modality"].strip()
            attrs["modality"] = code
            membership = self.context.get("membership")
            if membership is None:
                raise serializers.ValidationError({"modality": "Sin organización autorizada."})
            # Registro legado con opción inactiva: permitir conservarla si no se cambia.
            unchanged = self.instance is not None and self.instance.modality == code
            if not unchanged and not modality_valid(membership.workspace_id, code):
                raise serializers.ValidationError({
                    "modality": "Modalidad inexistente o desactivada en esta cuenta."
                })
        membership = self.context.get("membership")
        if "insurer" in attrs and attrs["insurer"] is not None:
            company = attrs["insurer"]
            # El ID es una referencia opaca: comprobar pertenencia y activación.
            if membership is None or company.workspace_id != membership.workspace_id:
                raise serializers.ValidationError({
                    "insurer": "Aseguradora no disponible en esta cuenta.",
                })
            unchanged = self.instance is not None and self.instance.insurer_id == company.pk
            if not company.active and not unchanged:
                raise serializers.ValidationError({
                    "insurer": "La aseguradora está desactivada.",
                })
        if "assigned_to" in self.initial_data:
            # Sólo el propietario puede reasignar; comprobar que el usuario
            # sea miembro de ESTE workspace, nunca de otro tenant.
            if membership is None or membership.role != WorkspaceMember.Role.OWNER:
                raise serializers.ValidationError({
                    "assigned_to": "Solo el propietario puede asignar vencimientos."
                })
            assigned = attrs.get("assigned_to")
            if assigned is not None and not WorkspaceMember.objects.filter(
                workspace_id=membership.workspace_id, user=assigned
            ).exists():
                raise serializers.ValidationError({
                    "assigned_to": "El responsable debe pertenecer a esta organización."
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
