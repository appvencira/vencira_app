"""D24 bounded pagination and PostgreSQL row-lock safety in disposable PG17."""
from concurrent.futures import ThreadPoolExecutor
from datetime import date, timedelta
from threading import Event
from time import sleep

from django.db import close_old_connections, connection, transaction
from django.test import TransactionTestCase

from reminders.models import Renewal, Workspace, WorkspaceMember
from django.contrib.auth import get_user_model
from .native_workspace_reader import (
    NativeWorkspaceDenied, read_native_workspace_renewals,
)


class D24LockedNativeWorkspacePG17Tests(TransactionTestCase):
    def setUp(self):
        if connection.vendor != "postgresql":
            self.skipTest("D24 requires isolated PostgreSQL17")
        self.user = get_user_model().objects.create_user(
            username="d24-member", password="D24-synthetic-secret",
        )
        self.owner = get_user_model().objects.create_user(
            username="d24-owner", password="D24-synthetic-secret-2",
        )
        self.workspace = Workspace.objects.create(name="D24 Ephemeral")
        self.membership = WorkspaceMember.objects.create(
            workspace=self.workspace, user=self.user,
            role=WorkspaceMember.Role.MEMBER,
        )
        WorkspaceMember.objects.create(
            workspace=self.workspace, user=self.owner,
            role=WorkspaceMember.Role.OWNER,
        )

    def read(self, user, offset=0):
        with transaction.atomic():
            # Same lock ordering as the mobile HTTP request.
            locked = get_user_model().objects.select_for_update().get(pk=user.pk)
            return read_native_workspace_renewals(
                user=locked, workspace_id=self.workspace.pk, offset=offset,
            )

    def test_75_rows_are_paged_without_foreign_assignment(self):
        base = date(2027, 1, 1)
        for index in range(75):
            Renewal.objects.create(
                workspace=self.workspace,
                assigned_to=self.user,
                customer_reference=f"D24 {index}",
                expires_on=base + timedelta(days=index),
            )
        Renewal.objects.create(
            workspace=self.workspace, assigned_to=self.owner,
            customer_reference="D24 forbidden", expires_on=base,
        )
        first = self.read(self.user)
        second = self.read(self.user, 50)
        self.assertEqual(len(first["results"]), 50)
        self.assertEqual(first["next_offset"], 50)
        self.assertEqual(len(second["results"]), 25)
        self.assertIsNone(second["next_offset"])
        self.assertEqual(
            len({row["id"] for row in first["results"] + second["results"]}),
            75,
        )
        self.assertEqual(len(self.read(self.owner)["results"]), 50)
        self.assertTrue(all(
            set(item) == {"id", "expires_on", "status"}
            for item in first["results"] + second["results"]
        ))
        print("D24_WORKSPACE_BOUNDED_PAGINATION_PG17=PASS")

    def test_invalid_offsets_denied(self):
        for offset in (-50, 1, 49, 10050, "50", True):
            with self.subTest(offset=offset), self.assertRaises(NativeWorkspaceDenied):
                self.read(self.user, offset)
        print("D24_WORKSPACE_OFFSET_FENCE_PG17=PASS")

    def test_membership_removal_waits_for_read_transaction(self):
        Renewal.objects.create(
            workspace=self.workspace, assigned_to=self.user,
            customer_reference="D24 race", expires_on=date(2027, 2, 1),
        )
        started = Event()
        done = Event()
        error = []

        def delete_membership():
            close_old_connections()
            try:
                started.set()
                with transaction.atomic():
                    WorkspaceMember.objects.filter(pk=self.membership.pk).delete()
                done.set()
            except Exception as exc:
                error.append(type(exc).__name__)
                done.set()
            finally:
                close_old_connections()

        with ThreadPoolExecutor(max_workers=1) as pool:
            with transaction.atomic():
                locked_user = get_user_model().objects.select_for_update().get(
                    pk=self.user.pk,
                )
                result = read_native_workspace_renewals(
                    user=locked_user, workspace_id=self.workspace.pk,
                )
                self.assertEqual(len(result["results"]), 1)
                future = pool.submit(delete_membership)
                self.assertTrue(started.wait(3))
                self.assertFalse(done.wait(0.2),
                                 "membership deleted before locked read committed")
            self.assertTrue(done.wait(5), "membership deletion did not finish")
            future.result(timeout=5)
        self.assertEqual(error, [])
        with self.assertRaises(NativeWorkspaceDenied):
            self.read(self.user)
        print("D24_MEMBERSHIP_REVOKE_SERIALIZED_PG17=PASS")

    def test_assignment_change_waits_for_locked_read_rows(self):
        renewal = Renewal.objects.create(
            workspace=self.workspace, assigned_to=self.user,
            customer_reference="D24 reassignment", expires_on=date(2027, 2, 2),
        )
        started = Event()
        done = Event()
        error = []

        def reassign():
            close_old_connections()
            try:
                started.set()
                with transaction.atomic():
                    Renewal.objects.filter(pk=renewal.pk).update(
                        assigned_to=self.owner,
                    )
                done.set()
            except Exception as exc:
                error.append(type(exc).__name__)
                done.set()
            finally:
                close_old_connections()

        with ThreadPoolExecutor(max_workers=1) as pool:
            with transaction.atomic():
                locked_user = get_user_model().objects.select_for_update().get(
                    pk=self.user.pk,
                )
                self.assertEqual(len(read_native_workspace_renewals(
                    user=locked_user, workspace_id=self.workspace.pk,
                )["results"]), 1)
                future = pool.submit(reassign)
                self.assertTrue(started.wait(3))
                self.assertFalse(done.wait(0.2),
                                 "assignment changed before locked read committed")
            self.assertTrue(done.wait(5), "assignment update did not finish")
            future.result(timeout=5)
        self.assertEqual(error, [])
        self.assertEqual(self.read(self.user)["results"], [])
        print("D24_ASSIGNMENT_REVOKE_SERIALIZED_PG17=PASS")
