from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("reminders", "0004_renewal_audit"),
    ]

    operations = [
        migrations.AddField(
            model_name="renewal",
            name="notice_deadline_on",
            field=models.DateField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="reminderpolicy",
            name="basis",
            field=models.CharField(
                choices=[("expiry", "Vencimiento"), ("notice_deadline", "Límite de preaviso")],
                default="expiry",
                max_length=16,
            ),
        ),
        migrations.RemoveConstraint(
            model_name="reminderpolicy",
            name="uniq_reminder_policy_ws_day",
        ),
        migrations.AddConstraint(
            model_name="reminderpolicy",
            constraint=models.UniqueConstraint(
                fields=("workspace", "basis", "days_before"),
                name="uniq_policy_workspace_basis_day",
            ),
        ),
    ]
