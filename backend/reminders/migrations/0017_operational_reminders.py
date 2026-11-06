"""Macrobloque A: schema aditivo de ocurrencias; sin tareas, triggers ni envíos."""
import uuid
from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion

class Migration(migrations.Migration):
    dependencies = [
        ("reminders", "0016_renewal_control_responses"),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]
    operations = [
        migrations.CreateModel(name="OperationalReminder", fields=[
            ("id", models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False, serialize=False)),
            ("kind", models.CharField(max_length=16, choices=[("expiry", "Vencimiento"), ("control_repeat", "Repetir pregunta de control")])),
            ("scheduled_for", models.DateField()),
            ("original_scheduled_for", models.DateField()),
            ("days_before", models.PositiveSmallIntegerField(null=True, blank=True)),
            ("reason", models.CharField(max_length=160)),
            ("control_question", models.BooleanField(default=False)),
            ("state", models.CharField(max_length=16, choices=[("planned", "Planificado"), ("pending", "Pendiente"), ("snoozed", "Aplazado"), ("completed", "Atendido"), ("cancelled", "Cancelado")], default="planned")),
            ("source_key", models.CharField(max_length=96)),
            ("generation", models.PositiveIntegerField(default=1)),
            ("created_at", models.DateTimeField(auto_now_add=True)),
            ("updated_at", models.DateTimeField(auto_now=True)),
            ("renewal", models.ForeignKey(to="reminders.renewal", on_delete=django.db.models.deletion.PROTECT, related_name="operational_reminders")),
            ("created_by_response", models.ForeignKey(to="reminders.renewalcontrolresponse", on_delete=django.db.models.deletion.PROTECT, null=True, blank=True, related_name="scheduled_operational_reminders")),
        ], options={"constraints":[
            models.UniqueConstraint(fields=["renewal","source_key","generation"], name="uniq_op_reminder_generation"),
            models.CheckConstraint(condition=models.Q(generation__gte=1), name="operational_generation_positive"),
        ], "indexes":[
            models.Index(fields=["scheduled_for","state"], name="operational_due_idx"),
            models.Index(fields=["renewal","state"], name="operational_renewal_state_idx"),
        ]}),
        migrations.CreateModel(name="OperationalReminderEvent", fields=[
            ("id", models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False, serialize=False)),
            ("action", models.CharField(max_length=24)),
            ("previous_state", models.CharField(max_length=16)),
            ("next_state", models.CharField(max_length=16)),
            ("occurred_at", models.DateTimeField(auto_now_add=True)),
            ("scheduled_for", models.DateField()),
            ("idempotency_key", models.UUIDField()),
            ("reminder", models.ForeignKey(to="reminders.operationalreminder", on_delete=django.db.models.deletion.PROTECT, related_name="events")),
            ("actor", models.ForeignKey(to=settings.AUTH_USER_MODEL, on_delete=django.db.models.deletion.SET_NULL, null=True, blank=True, related_name="vencira_reminder_events")),
        ], options={"ordering":["occurred_at","id"], "constraints":[
            models.UniqueConstraint(fields=["reminder","idempotency_key"], name="uniq_op_reminder_event_retry"),
        ]}),
    ]
