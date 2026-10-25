"""Macrobloque A: fechas del whitepaper y límites del motor sin efectos secundarios."""
from datetime import date
from django.test import SimpleTestCase

from reminders.operational_schedule import (
    DEFAULT_DAYS, build_renewal_plan, repeat_control_day,
)


class OperationalScheduleTests(SimpleTestCase):
    def test_march_whitepaper(self):
        p = build_renewal_plan(date(2027, 3, 15), today=date(2027, 1, 1))
        self.assertEqual(DEFAULT_DAYS, (60, 45, 35))
        self.assertEqual(p.cutoff, date(2027, 2, 15))
        self.assertEqual(
            [(x.days_before, x.day, x.control_question) for x in p.occurrences],
            [(60, date(2027, 1, 14), False),
             (45, date(2027, 1, 29), False),
             (35, date(2027, 2, 8), True)],
        )

    def test_short_month_and_leap_year(self):
        self.assertEqual(build_renewal_plan(
            date(2027, 3, 31), today=date(2027, 1, 1)).cutoff,
            date(2027, 2, 28))
        self.assertEqual(build_renewal_plan(
            date(2028, 3, 31), today=date(2028, 1, 1)).cutoff,
            date(2028, 2, 29))

    def test_control_moves_to_last_before_cutoff(self):
        p = build_renewal_plan(date(2027, 3, 15),
            today=date(2027, 1, 1), days_before=(70, 34, 15))
        self.assertEqual([x.days_before for x in p.occurrences if x.control_question], [34])

    def test_missing_control_is_explicit(self):
        p = build_renewal_plan(date(2027, 3, 15),
            today=date(2027, 1, 1), days_before=(30, 15))
        self.assertTrue(p.no_pre_cutoff_control)
        self.assertFalse(any(x.control_question for x in p.occurrences))

    def test_late_creation_does_not_backfill(self):
        p = build_renewal_plan(date(2027, 3, 15), today=date(2027, 2, 10))
        self.assertTrue(p.late_control)
        self.assertFalse(any(x.control_question for x in p.occurrences))
        self.assertEqual(p.occurrences, ())

    def test_life_requires_review(self):
        p = build_renewal_plan(date(2027, 3, 15),
            today=date(2027, 1, 1), life_insurance=True)
        self.assertTrue(p.manual_review_required)
        with self.assertRaises(ValueError):
            repeat_control_day(today=date(2027, 1, 1),
                expiry=date(2027, 3, 15), days_later=1, life_insurance=True)

    def test_repeat_must_fit_civil_cutoff(self):
        self.assertEqual(repeat_control_day(today=date(2027, 2, 12),
            expiry=date(2027, 3, 15), days_later=3), date(2027, 2, 15))
        with self.assertRaises(ValueError):
            repeat_control_day(today=date(2027, 2, 12),
                expiry=date(2027, 3, 15), days_later=4)
        with self.assertRaises(ValueError):
            repeat_control_day(today=date(2027, 2, 15),
                expiry=date(2027, 3, 15), days_later=1)

    def test_invalid_days_fail_closed(self):
        for values in ((), (1, 1), (-1,), (366,), (True,), tuple(range(13))):
            with self.subTest(values=values), self.assertRaises(ValueError):
                build_renewal_plan(date(2027, 3, 15), today=date(2027, 1, 1),
                    days_before=values)
