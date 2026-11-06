"""MFA: revocación técnica de sesiones, SIN restablecer factores ni contraseñas.

Primitiva de bajo nivel; no expuesta por API. Únicamente se incorporará a un
flujo operacional cuando exista verificación independiente y custodia real.
"""
from django.db import transaction
from django.db.models import F

from .models import UserMfaState


@transaction.atomic
def revoke_mfa_sessions(*, user_id):
    """Incrementa versión; middleware rechazará TODAS las sesiones MFA previas.

    Nunca desactiva MFA. Las sesiones recién verificadas reciben la nueva
    versión; no se eliminan secretos ni se habilita un bypass de login.
    """
    state = UserMfaState.objects.select_for_update().get(user_id=user_id)
    if not state.enabled:
        return False, "MFA_NOT_ENABLED"
    UserMfaState.objects.filter(pk=state.pk).update(session_epoch=F("session_epoch") + 1)
    return True, "MFA_SESSIONS_REVOKED"
