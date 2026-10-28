"""O8b: calendario configurable, días civiles y fecha de control."""
from datetime import date

from django.test import SimpleTestCase

from .reminder_planning import preview_reminder_plan, validate_control_repeat_day


class ReminderPlanningTests(SimpleTestCase):
    def test_whitepaper_defaults_and_control(self):
        plan = preview_reminder_plan(date(2027, 3, 15), as_of=date(2027, 1, 1))
        self.assertEqual(plan.cutoff_on, date(2027, 2, 15))
        self.assertEqual(
            [(r.days_before, r.scheduled_for) for r in plan.reminders],
            [(60, date(2027, 1, 14)), (45, date(2027, 1, 29)),
             (35, date(2027, 2, 8))],
        )
        self.assertEqual([r.days_before for r in plan.reminders
                          if r.control_question], [35])

    def test_last_eligible_notice_and_missing_control(self):
        plan = preview_reminder_plan(date(2027, 3, 15), (15, 60, 40, 45),
                                     as_of=date(2027, 1, 1))
        self.assertEqual([r.days_before for r in plan.reminders], [60, 45, 40, 15])
        self.assertEqual([r.days_before for r in plan.reminders
                          if r.control_question], [40])
        # 30 días desde el 15/03/2027 = 13/02/2027, anterior
        # al límite civil del 15/02: sí permite la pregunta de control.
        valid_30 = preview_reminder_plan(date(2027, 3, 15), (15, 30),
                                         as_of=date(2027, 1, 1))
        self.assertFalse(valid_30.no_pre_cutoff_notice)
        self.assertEqual([r.days_before for r in valid_30.reminders
                          if r.control_question], [30])
        # A 20 y 15 días, ambos avisos son posteriores al 15/02.
        missing = preview_reminder_plan(date(2027, 3, 15), (15, 20),
                                        as_of=date(2027, 1, 1))
        self.assertTrue(missing.no_pre_cutoff_notice)
        self.assertFalse(any(r.control_question for r in missing.reminders))

    def test_late_creation_and_cutoff_passed_are_flags_only(self):
        plan = preview_reminder_plan(date(2027, 3, 15), as_of=date(2027, 2, 9))
        self.assertTrue(plan.late_control_needs_decision)
        self.assertFalse(plan.cutoff_already_elapsed)
        self.assertTrue(all(r.already_elapsed for r in plan.reminders))
        self.assertTrue(preview_reminder_plan(
            date(2027, 3, 15), as_of=date(2027, 2, 15),
        ).cutoff_already_elapsed)

    def test_invalid_rule_arguments_fail_closed(self):
        for values in ([], list(range(13)), [35, 35], [366], [-1],
                       ["35"], [True], None):
            with self.subTest(values=values):
                with self.assertRaises((TypeError, ValueError)):
                    preview_reminder_plan(date(2027, 3, 15), values,
                                          as_of=date(2027, 1, 1))

    def test_control_repeat_last_day_and_no_post_cutoff(self):
        expiry = date(2027, 3, 31)
        self.assertEqual(validate_control_repeat_day(
            expiry, as_of=date(2027, 2, 25), days_later=3), date(2027, 2, 28))
        for today, days in ((date(2027, 2, 25), 4),
                            (date(2027, 2, 28), 1),
                            (date(2027, 3, 1), 1),
                            (date(2027, 2, 25), True),
                            (date(2027, 2, 25), 0)):
            with self.subTest(today=today, days=days):
                with self.assertRaises(ValueError):
                    validate_control_repeat_day(expiry, as_of=today,
                                                days_later=days)
