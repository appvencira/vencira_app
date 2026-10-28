"""D6B: pruebas de política, estados e idempotencia."""
from django.test import SimpleTestCase

from .offline_recovery_policy_d6 import (
    RecoveryDecision,
    decide_recovery,
    retry_decision,
)


class RecoveryPolicyD6BTests(SimpleTestCase):

    def test_verified_requires_metadata_reconciliation(self):
        result = decide_recovery("verified")
        self.assertEqual(result.action, "reconcile_metadata")
        self.assertFalse(result.terminal)
        self.assertFalse(result.release_authorized)

    def test_missing_requires_review(self):
        result = decide_recovery("missing")
        self.assertEqual(result.action, "review_missing_object")
        self.assertFalse(result.terminal)

    def test_unavailable_requires_retry(self):
        result = decide_recovery("unavailable")
        self.assertEqual(result.action, "retry_when_store_available")
        self.assertFalse(result.terminal)

    def test_invalid_requires_investigation(self):
        result = decide_recovery("invalid")
        self.assertEqual(result.action, "quarantine_and_investigate")
        self.assertFalse(result.release_authorized)

    def test_identical_retry_is_idempotent(self):
        previous = decide_recovery("unavailable")
        self.assertEqual(
            retry_decision(previous, "unavailable"),
            previous,
        )

    def test_recovery_after_volume_returns(self):
        previous = decide_recovery("unavailable")
        next_decision = retry_decision(previous, "verified")
        self.assertEqual(
            next_decision.action, "reconcile_metadata"
        )
        self.assertFalse(next_decision.terminal)

    def test_unknown_classification_fails_closed(self):
        with self.assertRaises(ValueError):
            decide_recovery("deleted")

    def test_terminal_decision_cannot_be_retried(self):
        forged = RecoveryDecision(
            classification="verified",
            action="complete",
            terminal=True,
        )
        with self.assertRaises(ValueError):
            retry_decision(forged, "verified")

    def test_release_authorization_cannot_be_inherited(self):
        forged = RecoveryDecision(
            classification="verified",
            action="download",
            release_authorized=True,
        )
        with self.assertRaises(ValueError):
            retry_decision(forged, "verified")
