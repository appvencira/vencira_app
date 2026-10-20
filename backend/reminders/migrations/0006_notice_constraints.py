from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("reminders", "0005_notice_deadline_policy_basis"),
    ]

    operations = [
        migrations.AddConstraint(
            model_name="renewal",
            constraint=models.CheckConstraint(
                condition=(
                    models.Q(notice_deadline_on__isnull=True)
                    | models.Q(notice_deadline_on__lte=models.F("expires_on"))
                ),
                name="renewal_notice_lte_expiry",
            ),
        ),
        migrations.AddConstraint(
            model_name="reminderpolicy",
            constraint=models.CheckConstraint(
                condition=models.Q(basis__in=["expiry", "notice_deadline"]),
                name="policy_basis_valid",
            ),
        ),
    ]
