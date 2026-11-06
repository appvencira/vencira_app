"""D10C: pruebas puras de seguridad de estados."""
from django.test import SimpleTestCase

from .offline_recovery_states_d10c import (
    RecoveryState, evaluate_recovery, transition_recovery
)


class RecoveryStatesD10CTests(SimpleTestCase):

    def test_verified_still_requires_review(self):
        result = evaluate_recovery("verified")
        self.assertEqual(result.status, "review_required")
        self.assertFalse(result.release_authorized)

    def test_missing_requires_review(self):
        self.assertEqual(
            evaluate_recovery("missing").status,
            "review_required",
        )

    def test_unavailable_requires_retry(self):
        self.assertEqual(
            evaluate_recovery("unavailable").status,
            "retry_required",
        )

    def test_invalid_requires_review(self):
        self.assertEqual(
            evaluate_recovery("invalid").status,
            "review_required",
        )

    def test_same_transition_is_idempotent(self):
        state = evaluate_recovery("verified")
        self.assertEqual(
            transition_recovery(state, state.status), state
        )

    def test_automatic_resolution_denied(self):
        with self.assertRaises(ValueError):
            transition_recovery(
                evaluate_recovery("verified"),
                "resolved_manually",
            )

    def test_manual_resolution_does_not_release(self):
        result = transition_recovery(
            evaluate_recovery("verified"),
            "resolved_manually",
            manual_approval=True,
        )
        self.assertEqual(result.status, "resolved_manually")
        self.assertFalse(result.release_authorized)

    def test_terminal_state_cannot_reopen(self):
        state = transition_recovery(
            evaluate_recovery("missing"),
            "resolved_manually",
            manual_approval=True,
        )
        with self.assertRaises(ValueError):
            transition_recovery(state, "review_required")

    def test_untrusted_release_state_denied(self):
        state = RecoveryState(
            "verified", "review_required",
            "reconcile_metadata", True,
        )
        with self.assertRaises(ValueError):
            transition_recovery(state, "retry_required")

    def test_unknown_classification_denied(self):
        with self.assertRaises(ValueError):
            evaluate_recovery("clean_and_publish")
