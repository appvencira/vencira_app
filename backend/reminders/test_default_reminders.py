"""O8: fechas, orden, control y no automatización según whitepaper §7/8."""
from datetime import date

from django.test import SimpleTestCase

from .default_reminders import DEFAULT_DAYS_BEFORE, default_reminders
from .legal_deadlines import one_month_before


class ReminderDefaultsTests(SimpleTestCase):
    def test_march_fifteenth_2027_matches_whitepaper_exactly(self):
        plans = default_reminders(date(2027, 3, 15))
        self.assertEqual(DEFAULT_DAYS_BEFORE, (60, 45, 35))
        self.assertEqual(
            [(p.days_before, p.scheduled_for) for p in plans],
            [(60, date(2027, 1, 14)), (45, date(2027, 1, 29)),
             (35, date(2027, 2, 8))],
        )
        self.assertEqual(
            [p.days_before for p in plans if p.has_legal_control_question],
            [35],
        )
        self.assertEqual(one_month_before(date(2027, 3, 15)), date(2027, 2, 15))

    def test_control_last_reminder_before_cutoff_not_at_or_after(self):
        for expiry in (date(2027, 3, 31), date(2028, 3, 31),
                       date(2027, 5, 31), date(2027, 1, 1)):
            with self.subTest(expiry=expiry):
                plans = default_reminders(expiry)
                self.assertEqual(len(plans), 3)
                cutoff = one_month_before(expiry)
                eligible = [p for p in plans if p.scheduled_for < cutoff]
                chosen = [p for p in plans if p.has_legal_control_question]
                self.assertEqual(len(chosen), 1)
                self.assertEqual(chosen[0].scheduled_for,
                                 max(p.scheduled_for for p in eligible))
                self.assertTrue(all(p.scheduled_for < expiry for p in plans))

    def test_no_database_writes_or_auto_sends(self):
        # Los objetos son dataclasses inmutables: solo fechas calculadas.
        plans = default_reminders(date(2027, 12, 31))
        self.assertTrue(all(p.days_before in DEFAULT_DAYS_BEFORE for p in plans))
        with self.assertRaises(Exception):
            plans[0].days_before = 10

    def test_invalid_input(self):
        with self.assertRaises(TypeError):
            default_reminders("2027-03-15")
