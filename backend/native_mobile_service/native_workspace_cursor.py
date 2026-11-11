"""D26 test-only signed keyset cursor, immutable creation order, live scope.

Cursor does not grant authorization: every request rechecks current membership,
assignment and token. A fixed upper creation timestamp excludes later inserts.
Changes of assignment between pages may still change visible membership.
"""
from datetime import datetime
import uuid

from django.core import signing
from django.db import connection
from django.db.models import Q
from django.utils import timezone
from reminders.models import Renewal, WorkspaceMember

PAGE_SIZE = 50
CURSOR_SALT = "vencira.native.d26.workspace.read.v1"
MAX_CURSOR_AGE = 900


class NativeCursorDenied(Exception):
    """Reject malformed, expired, foreign and tampered cursor uniformly."""


def _decode(cursor, *, user, workspace_id):
    if cursor is None:
        return timezone.now(), None
    if (type(cursor) is not str or not 10 <= len(cursor) <= 1024
            or any(char not in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_:.": for char in cursor)):
        raise NativeCursorDenied()
    try:
        payload = signing.loads(cursor, salt=CURSOR_SALT, max_age=MAX_CURSOR_AGE)
        if (type(payload) is not dict or set(payload) != {"v", "user", "ws", "cut", "last_t", "last_id"}
                or type(payload["v"]) is not int or payload["v"] != 1
                or type(payload["user"]) is not int or payload["user"] != user.pk
                or type(payload["ws"]) is not str or payload["ws"] != str(workspace_id)):
            raise NativeCursorDenied()
        cutoff = datetime.fromisoformat(payload["cut"])
        last = datetime.fromisoformat(payload["last_t"])
        row_id = uuid.UUID(payload["last_id"])
        if (timezone.is_naive(cutoff) or timezone.is_naive(last)
                or last > cutoff or str(row_id) != payload["last_id"]):
            raise NativeCursorDenied()
        return cutoff, (last, row_id)
    except (signing.BadSignature, ValueError, TypeError, KeyError, OverflowError) as exc:
        raise NativeCursorDenied() from exc


def read_native_cursor_page(*, user, workspace_id, cursor=None):
    if (not connection.in_atomic_block or not getattr(user, "is_authenticated", False)
            or not getattr(user, "is_active", False)
            or type(workspace_id) is not uuid.UUID):
        raise NativeCursorDenied()
    cutoff, last = _decode(cursor, user=user, workspace_id=workspace_id)
    membership = WorkspaceMember.objects.select_for_update().filter(
        workspace_id=workspace_id, user_id=user.pk,
    ).first()
    if membership is None:
        raise NativeCursorDenied()
    scoped = Renewal.objects.filter(workspace_id=workspace_id, created_at__lte=cutoff)
    if membership.role == WorkspaceMember.Role.MEMBER:
        scoped = scoped.filter(assigned_to_id=user.pk)
    elif membership.role != WorkspaceMember.Role.OWNER:
        raise NativeCursorDenied()
    if last is not None:
        stamp, pk = last
        scoped = scoped.filter(Q(created_at__gt=stamp) |
                               Q(created_at=stamp, id__gt=pk))
    rows = list(scoped.select_for_update().order_by("created_at", "id").values(
        "id", "created_at", "expires_on", "status",
    )[:PAGE_SIZE + 1])
    visible = rows[:PAGE_SIZE]
    following = None
    if len(rows) > PAGE_SIZE:
        final = visible[-1]
        following = signing.dumps({
            "v": 1, "user": user.pk, "ws": str(workspace_id),
            "cut": cutoff.isoformat(),
            "last_t": final["created_at"].isoformat(),
            "last_id": str(final["id"]),
        }, salt=CURSOR_SALT, compress=True)
    return {
        "workspace_id": str(workspace_id),
        "results": [
            {"id": str(row["id"]), "expires_on": row["expires_on"].isoformat(),
             "status": row["status"]}
            for row in visible
        ],
        "next_cursor": following,
    }
