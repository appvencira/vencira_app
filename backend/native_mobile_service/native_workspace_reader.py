"""D23 native renewal read scope: membership and assignment are checked per request.

No token is issued or stored here. The caller must first validate its native
access token against the revocation/identity gate, then pass the resolved User.
Unlike a login-time permission snapshot, this query re-evaluates membership,
role and assignment on every request. No PII is returned.
"""
import uuid

from reminders.models import Renewal, WorkspaceMember


class NativeWorkspaceDenied(Exception):
    """No foreign tenant, membership, assignment or object details leak."""


def read_native_workspace_renewals(*, user, workspace_id):
    """Bounded, minimal projection of currently visible renewal rows."""
    if (
        not getattr(user, "is_authenticated", False)
        or not getattr(user, "is_active", False)
        or type(workspace_id) is not uuid.UUID
    ):
        raise NativeWorkspaceDenied()
    membership = WorkspaceMember.objects.filter(
        workspace_id=workspace_id, user_id=user.pk,
    ).values("role").first()
    if membership is None:
        raise NativeWorkspaceDenied()
    scoped = Renewal.objects.filter(workspace_id=workspace_id)
    if membership["role"] == WorkspaceMember.Role.MEMBER:
        scoped = scoped.filter(assigned_to_id=user.pk)
    elif membership["role"] != WorkspaceMember.Role.OWNER:
        raise NativeWorkspaceDenied()
    rows = list(scoped.order_by("expires_on", "id").values(
        "id", "expires_on", "status",
    )[:50])
    return {
        "workspace_id": str(workspace_id),
        "results": [
            {
                "id": str(row["id"]),
                "expires_on": row["expires_on"].isoformat(),
                "status": row["status"],
            }
            for row in rows
        ],
    }
