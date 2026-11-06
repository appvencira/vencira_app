from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [
        ("renewal_attachments", "0004_attachmentdiscardjob"),
    ]

    operations = [
        migrations.CreateModel(
            name="AttachmentRecoveryCase",
            fields=[
                (
                    "id",
                    models.BigAutoField(
                        auto_created=True,
                        primary_key=True,
                        serialize=False,
                        verbose_name="ID",
                    ),
                ),
                (
                    "status",
                    models.CharField(
                        max_length=20,
                        choices=[
                            ("review_required", "Revisión requerida"),
                            ("retry_required", "Reintento requerido"),
                        ],
                    ),
                ),
                (
                    "classification",
                    models.CharField(max_length=20),
                ),
                (
                    "attempts",
                    models.PositiveIntegerField(default=0),
                ),
                (
                    "last_error",
                    models.CharField(
                        max_length=80,
                        blank=True,
                        default="",
                    ),
                ),
                (
                    "created_at",
                    models.DateTimeField(auto_now_add=True),
                ),
                (
                    "updated_at",
                    models.DateTimeField(auto_now=True),
                ),
                (
                    "attachment",
                    models.OneToOneField(
                        to="renewal_attachments.renewalattachment",
                        on_delete=django.db.models.deletion.PROTECT,
                        related_name="recovery_case",
                    ),
                ),
            ],
        ),
        migrations.AddConstraint(
            model_name="attachmentrecoverycase",
            constraint=models.CheckConstraint(
                condition=models.Q(
                    status__in=[
                        "review_required",
                        "retry_required",
                    ],
                ),
                name="ratt_recovery_status_safe",
            ),
        ),
    ]
