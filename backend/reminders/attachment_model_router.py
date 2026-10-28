"""Single attachment model resolver. No runtime release of independent schema.

The existing model remains the default for all environments. Independent
model is available only in the explicit isolated PG17 rehearsal mode.
"""
from django.apps import apps
from django.conf import settings
from django.core.exceptions import ImproperlyConfigured


def attachment_model():
    split = getattr(settings, "VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED", False)
    if not split:
        from .models import RenewalAttachment
        return RenewalAttachment
    if getattr(settings, "VENCIRA_ENV", None) != "test":
        raise ImproperlyConfigured("Independent attachment model restricted to tests")
    if not apps.is_installed("renewal_attachments"):
        raise ImproperlyConfigured("Independent attachment app not installed")
    return apps.get_model("renewal_attachments", "RenewalAttachment")
