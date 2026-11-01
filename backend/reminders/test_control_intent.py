from datetime import date, datetime
from django.test import SimpleTestCase

from reminders.control_intent import YES_REASONS, validate_control_intent


class ControlIntentContractTests(SimpleTestCase):
    def test_yes_all_three_reasons_no_delivery_or_closure(self):
        for reason in YES_REASONS:
            with self.subTest(reason=reason):
                r = validate_control_intent(
                    expires_on=date(2027, 5, 31), as_of=date(2027, 4, 1),
                    answer="yes", reason=reason)
                self.assertIsNone(r.repeat_on)
                self.assertFalse(r.verified_delivery)
                self.assertFalse(r.closes_renewal)

    def test_no_repeats_before_civil_month_cutoff(self):
        r=validate_control_intent(
            expires_on=date(2027,3,31), as_of=date(2027,2,20),
            answer="no",days_later=8)
        self.assertEqual(r.repeat_on,date(2027,2,28))
        self.assertFalse(r.verified_delivery)

    def test_no_cannot_exceed_cutoff(self):
        with self.assertRaises(ValueError):
            validate_control_intent(
                expires_on=date(2027,3,31),as_of=date(2027,2,20),
                answer="no",days_later=9)

    def test_no_after_cutoff_rejected(self):
        with self.assertRaises(ValueError):
            validate_control_intent(
                expires_on=date(2027,3,31),as_of=date(2027,3,1),
                answer="no",days_later=1)

    def test_yes_requires_exact_reason(self):
        for reason in ("other", None, ""):
            with self.subTest(reason=reason), self.assertRaises(ValueError):
                validate_control_intent(
                    expires_on=date(2027,5,31),as_of=date(2027,4,1),
                    answer="yes",reason=reason)

    def test_yes_rejects_repeat_date(self):
        with self.assertRaises(ValueError):
            validate_control_intent(
                expires_on=date(2027,5,31),as_of=date(2027,4,1),
                answer="yes",reason="notified_by_client",days_later=1)

    def test_no_rejects_reason(self):
        with self.assertRaises(ValueError):
            validate_control_intent(
                expires_on=date(2027,5,31),as_of=date(2027,4,1),
                answer="no",reason="notified_by_client",days_later=1)

    def test_boolean_and_nonpositive_interval_rejected(self):
        for delta in (True,0,-1,None):
            with self.subTest(delta=delta),self.assertRaises(ValueError):
                validate_control_intent(
                    expires_on=date(2027,5,31),as_of=date(2027,4,1),
                    answer="no",days_later=delta)

    def test_invalid_answers_rejected(self):
        for answer in ("si","YES","",True,None):
            with self.subTest(answer=answer),self.assertRaises(ValueError):
                validate_control_intent(
                    expires_on=date(2027,5,31),as_of=date(2027,4,1),
                    answer=answer)

    def test_datetime_not_civil_date(self):
        with self.assertRaises((TypeError,ValueError)):
            validate_control_intent(
                expires_on=date(2027,5,31),
                as_of=datetime(2027,4,1),
                answer="no",days_later=1)
