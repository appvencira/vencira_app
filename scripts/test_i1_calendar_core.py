#!/usr/bin/env python3
"""I1 calendar-core tests: stdlib only; no Django, database, deployment or HTTP."""
import sys
import unittest
from datetime import date, datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "backend"))
from reminders.legal_deadlines import one_month_before
from reminders.default_reminders import DEFAULT_DAYS_BEFORE, default_reminders
from reminders.reminder_planning import preview_reminder_plan, validate_control_repeat_day


class CalendarCoreI1Tests(unittest.TestCase):
    def test_calendar_month_leap_year_and_january(self):
        self.assertEqual(one_month_before(date(2027, 3, 31)), date(2027, 2, 28))
        self.assertEqual(one_month_before(date(2028, 3, 31)), date(2028, 2, 29))
        self.assertEqual(one_month_before(date(2028, 1, 31)), date(2027, 12, 31))

    def test_default_three_reminders_are_pure(self):
        reminders = default_reminders(date(2027, 3, 15))
        self.assertEqual(DEFAULT_DAYS_BEFORE, (60, 45, 35))
        self.assertEqual([r.scheduled_for for r in reminders], [
            date(2027, 1, 14), date(2027, 1, 29), date(2027, 2, 8),
        ])
        self.assertEqual([r.days_before for r in reminders if r.has_legal_control_question], [35])

    def test_preview_sort_and_control(self):
        plan = preview_reminder_plan(
            date(2027, 3, 15), (15, 60, 40, 45), as_of=date(2027, 1, 1),
        )
        self.assertEqual(plan.cutoff_on, date(2027, 2, 15))
        self.assertEqual([r.days_before for r in plan.reminders], [60, 45, 40, 15])
        self.assertEqual([r.days_before for r in plan.reminders if r.control_question], [40])

    def test_no_automatic_control_if_only_late_notices(self):
        plan = preview_reminder_plan(date(2027, 3, 15), (15, 20), as_of=date(2027, 1, 1))
        self.assertTrue(plan.no_pre_cutoff_notice)
        self.assertFalse(any(r.control_question for r in plan.reminders))

    def test_expired_control_is_a_flag_not_automatic_action(self):
        plan = preview_reminder_plan(date(2027, 3, 15), as_of=date(2027, 2, 9))
        self.assertTrue(plan.late_control_needs_decision)
        self.assertFalse(plan.cutoff_already_elapsed)
        self.assertTrue(all(r.already_elapsed for r in plan.reminders))

    def test_repeat_never_reaches_month_cutoff(self):
        self.assertEqual(validate_control_repeat_day(
            date(2027, 3, 31), as_of=date(2027, 2, 25), days_later=2,
        ), date(2027, 2, 27))
        with self.assertRaises(ValueError):
            validate_control_repeat_day(
                date(2027, 3, 31), as_of=date(2027, 2, 25), days_later=3,
            )

    def test_reject_duplicate_or_invalid_rules(self):
        for rules in ([], list(range(13)), [35, 35], [-1], [366], ["35"], [True], None):
            with self.subTest(rules=rules), self.assertRaises((TypeError, ValueError)):
                preview_reminder_plan(date(2027, 3, 15), rules, as_of=date(2027, 1, 1))

    def test_reject_datetime_as_civil_date(self):
        with self.assertRaises(TypeError):
            one_month_before(datetime(2027, 3, 15))
        with self.assertRaises(TypeError):
            default_reminders(datetime(2027, 3, 15))
        with self.assertRaises(TypeError):
            preview_reminder_plan(date(2027, 3, 15), as_of=datetime(2027, 1, 1))


if __name__ == "__main__":
    unittest.main()
