"""Pruebas de reglas de recuperación sin conexión ni datos persistentes."""
from dataclasses import replace
from datetime import datetime, timedelta, timezone

from django.test import SimpleTestCase

from .mfa_admin_recovery_policy import RecoveryApproval, RecoveryCase, assess_recovery


class RecoveryPolicyTests(SimpleTestCase):
    def setUp(self):
        self.now = datetime(2026, 10, 27, 12, 0, tzinfo=timezone.utc)
        self.case = RecoveryCase(
            case_id="synthetic-case",
            subject_id=11,
            requester_id=11,
            created_at=self.now - timedelta(hours=24),
            quarantine_until=self.now,
            channel_verified=True,
            approvals=(
                RecoveryApproval(21, "synthetic-case", self.now + timedelta(minutes=5)),
                RecoveryApproval(22, "synthetic-case", self.now + timedelta(minutes=5)),
            ),
        )

    def test_valid_approvals_only_meet_preconditions(self):
        self.assertEqual(assess_recovery(self.case, now=self.now),
                         (True, "POLICY_PRECONDITIONS_MET_ONLY"))

    def test_duplicate_and_self_approval_denied(self):
        for reviewer in (21, 11):
            case = replace(self.case, approvals=(
                self.case.approvals[0],
                RecoveryApproval(reviewer, "synthetic-case",
                                 self.now + timedelta(minutes=5)),
            ))
            self.assertFalse(assess_recovery(case, now=self.now)[0])

    def test_expired_replayed_or_cross_case_approval_denied(self):
        for approval in (
            RecoveryApproval(22, "synthetic-case", self.now),
            RecoveryApproval(22, "different-case", self.now + timedelta(minutes=5)),
        ):
            case = replace(self.case, approvals=(self.case.approvals[0], approval))
            self.assertFalse(assess_recovery(case, now=self.now)[0])

    def test_quarantine_and_independent_channel_required(self):
        for changes in (
            {"quarantine_until": self.now + timedelta(minutes=1)},
            {"channel_verified": False},
            {"status": "completed"},
        ):
            self.assertFalse(assess_recovery(replace(self.case, **changes), now=self.now)[0])

    def test_no_single_approver(self):
        self.assertEqual(assess_recovery(replace(self.case, approvals=self.case.approvals[:1]), now=self.now)[0], False)
