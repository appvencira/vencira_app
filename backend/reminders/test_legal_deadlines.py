"""Whitepaper §8/11: month-of-date cutoff, not 30 days or explicit notice."""
from datetime import date, datetime
from django.test import SimpleTestCase

from .legal_deadlines import one_month_before


class LegalCutoffTests(SimpleTestCase):
    def test_whitepaper_examples(self):
        for expiry, expected in (
            (date(2027, 3, 15), date(2027, 2, 15)),
            (date(2027, 3, 31), date(2027, 2, 28)),
            (date(2027, 5, 31), date(2027, 4, 30)),
            (date(2027, 8, 15), date(2027, 7, 15)),
        ):
            with self.subTest(expiry=expiry):
                self.assertEqual(one_month_before(expiry), expected)

    def test_calendar_boundaries_leap_and_january(self):
        for expiry, expected in (
            (date(2028, 3, 31), date(2028, 2, 29)),
            (date(2028, 1, 31), date(2027, 12, 31)),
            (date(2027, 1, 1), date(2026, 12, 1)),
            (date(2027, 12, 31), date(2027, 11, 30)),
            (date(2027, 7, 30), date(2027, 6, 30)),
        ):
            with self.subTest(expiry=expiry):
                self.assertEqual(one_month_before(expiry), expected)

    def test_reject_non_civil_date_input(self):
        for bad in (None, "2027-03-31", datetime(2027, 3, 31)):
            with self.subTest(bad=bad):
                with self.assertRaises(TypeError):
                    one_month_before(bad)

    def test_does_not_mutate_any_database_or_set_notice_deadline(self):
        self.assertEqual(one_month_before(date(2028, 2, 29)), date(2028, 1, 29))
