"""O9b-1 validation tests, without persistence or delivery."""
from datetime import date
from django.test import SimpleTestCase
from .control_responses import QUESTION, YES_OPTIONS, validate_control_response


class ControlResponseTests(SimpleTestCase):
    def test_yes_options_exact(self):
        self.assertEqual(QUESTION, "¿Se ha notificado a la aseguradora su no renovación?")
        self.assertEqual(list(YES_OPTIONS.values()), [
            "Avisada por el cliente", "La aseguradora no renueva", "Notificado por mí",
        ])
        for option in YES_OPTIONS:
            result = validate_control_response(
                date(2027, 3, 15), as_of=date(2027, 2, 8),
                answer="yes", yes_option=option,
            )
            self.assertEqual(result.yes_option, option)
            self.assertIsNone(result.repeat_on)
            self.assertFalse(result.notice_delivered)

    def test_no_respects_civil_cutoff(self):
        result = validate_control_response(
            date(2028, 3, 31), as_of=date(2028, 2, 28),
            answer="no", days_later=1,
        )
        self.assertEqual(result.repeat_on, date(2028, 2, 29))
        self.assertTrue(result.question_again)
        self.assertFalse(result.notice_scheduled)
        with self.assertRaises(ValueError):
            validate_control_response(
                date(2028, 3, 31), as_of=date(2028, 2, 28),
                answer="no", days_later=2,
            )

    def test_no_new_repeat_at_cutoff(self):
        with self.assertRaises(ValueError):
            validate_control_response(
                date(2027, 3, 31), as_of=date(2027, 2, 28),
                answer="no", days_later=1,
            )

    def test_invalid_payloads(self):
        for option in (None, "other"):
            with self.assertRaises(ValueError):
                validate_control_response(
                    date(2027, 3, 15), as_of=date(2027, 1, 1),
                    answer="yes", yes_option=option,
                )
        for interval in (None, 0, -1, True, "5"):
            with self.assertRaises(ValueError):
                validate_control_response(
                    date(2027, 3, 15), as_of=date(2027, 1, 1),
                    answer="no", days_later=interval,
                )
        with self.assertRaises(ValueError):
            validate_control_response(
                date(2027, 3, 15), as_of=date(2027, 1, 1),
                answer="no", days_later=1, requires_manual_review=True,
            )
