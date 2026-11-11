"""D24 native renewal read, pagination and authorization within PG17 locks.

Caller must hold an atomic transaction and a server-side user row lock;
the HTTP boundary additionally locks the device session before returning data.
Membership and the selected rows are locked to serialize permission changes.
No customer PII is projected. This candidate remains test-only.
"""
import uuid

from django.db import connection, transaction
from reminders.models import Renewal, WorkspaceMember


class NativeWorkspaceDenied(Exception):
    """Do not reveal tenant, membership, assignment or object existence."""


PAGE_SIZE = 50
MAX_OFFSET = 10000


def read_native_workspace_renewals(*, user, workspace_id, offset=0):
    """Read one bounded page from the *current*, locked membership and rows.

    Locking order required by the mobile caller: user, device, membership, rows.
    The outer atomic transaction is held until the HTTP payload is constructed.
    This does not guarantee a client's already-sent response can be recalled.
    """
    if (
        not getattr(user, "is_authenticated", False)
        or not getattr(user, "is_active", False)
        or type(workspace_id) is not uuid.UUID
        or type(offset) is not int
        or not 0 <= offset <= MAX_OFFSET
        or not connection.in_atomic_block
    ):
        raise NativeWorkspaceDenied()
    membership = WorkspaceMember.objects.select_for_update().filter(
        workspace_id=workspace_id, user_id=user.pk,
    ).first()
    if membership is None:
        raise NativeWorkspaceDenied()
    scoped = Renewal.objects.filter(workspace_id=workspace_id)
    if membership.role == WorkspaceMember.Role.MEMBER:
        scoped = scoped.filter(assigned_to_id=user.pk)
    elif membership.role != WorkspaceMember.Role.OWNER:
        raise NativeWorkspaceDenied()
    # Select only minimal columns; lock every returned row before serialization.
    rows = list(
        scoped.order_by("expires_on", "id").select_for_update().values(
            "id", "expires_on", "status",
        )[offset:offset + PAGE_SIZE + 1]
    )
    more = len(rows) > PAGE_SIZE
    return {
        "workspace_id": str(workspace_id),
        "results": [
            {
                "id": str(row["id"]),
                "expires_on": row["expires_on"].isoformat(),
                "status": row["status"],
            }
            for row in rows[:PAGE_SIZE]
        ],
        "next_offset": offset + PAGE_SIZE if more else None,
    }
