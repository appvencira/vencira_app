"""C2 pure-policy regression cases. No persisted records or messages."""
from datetime import date
from django.test import SimpleTestCase

from .c2_control_policy import evaluate_c2_control_policy as evaluate


class C2PolicyTests(SimpleTestCase):
    def test_standard_plan_needs_no_warning(self):
        r = evaluate(date(2027, 3, 15), [60, 45, 35],
                     as_of=date(2027, 1, 1))
        self.assertTrue(r.allow_save)
        self.assertFalse(r.manual_review_required)
        self.assertIsNone(r.warning_code)
        self.assertEqual(r.delivery_status, "not_implemented")

    def test_no_pre_cutoff_still_saves_with_explicit_offer(self):
        r = evaluate(date(2027, 3, 15), [20, 15],
                     as_of=date(2027, 2, 1))
        self.assertEqual(r.warning_code, "no_pre_cutoff_notice")
        self.assertEqual(r.warning_severity, "red")
        self.assertTrue(r.manual_review_required)
        self.assertTrue(r.offer_explicit_control)
        self.assertEqual(r.latest_explicit_control_day, date(2027, 2, 14))

    def test_late_control_keeps_only_future_days(self):
        r = evaluate(date(2027, 3, 15), [60, 45, 35],
                     as_of=date(2027, 2, 10))
        self.assertEqual(r.warning_code, "control_day_elapsed")
        self.assertEqual(r.future_notice_days, ())
        self.assertTrue(r.offer_explicit_control)

    def test_cutoff_today_must_not_offer_future_control(self):
        r = evaluate(date(2027, 3, 15), [20, 15],
                     as_of=date(2027, 2, 15))
        self.assertEqual(r.warning_code, "civil_cutoff_reached")
        self.assertFalse(r.offer_explicit_control)

    def test_cutoff_past_no_retroactive_notice(self):
        r = evaluate(date(2027, 3, 15), [35, 20],
                     as_of=date(2027, 2, 17))
        self.assertEqual(r.warning_severity, "red")
        self.assertIsNone(r.latest_explicit_control_day)

    def test_february_29_and_short_month(self):
        leap = evaluate(date(2028, 3, 31), [20, 15],
                        as_of=date(2028, 2, 1))
        self.assertEqual(leap.cutoff_on, date(2028, 2, 29))
        self.assertEqual(leap.latest_explicit_control_day, date(2028, 2, 28))
        short = evaluate(date(2027, 5, 31), [20],
                         as_of=date(2027, 4, 1))
        self.assertEqual(short.cutoff_on, date(2027, 4, 30))

    def test_life_does_not_claim_general_legal_cutoff(self):
        r = evaluate(date(2027, 3, 15), [60, 45, 35],
                     as_of=date(2027, 1, 1), is_life=True)
        self.assertTrue(r.allow_save)
        self.assertTrue(r.manual_review_required)
        self.assertEqual(r.warning_code, "life_terms_review")
        self.assertIsNone(r.cutoff_on)
        self.assertFalse(r.offer_explicit_control)

    def test_invalid_life_flag_or_duplicate_offsets(self):
        with self.assertRaises(TypeError):
            evaluate(date(2027, 3, 15), [60], as_of=date(2027, 1, 1), is_life=1)
        with self.assertRaises(ValueError):
            evaluate(date(2027, 3, 15), [35, 35], as_of=date(2027, 1, 1))
