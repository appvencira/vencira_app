"""Regression: client suggestions rank only previously scoped records."""
from unittest.mock import MagicMock
from django.test import SimpleTestCase
from reminders.person_suggestions import _prioritized_visible_matches


class PersonSuggestionRankingTests(SimpleTestCase):
    def test_clients_first_and_limit_applied_after_scope(self):
        scoped=MagicMock()
        scoped.annotate.return_value.order_by.return_value.__getitem__.return_value=["result"]
        result=_prioritized_visible_matches(scoped)
        self.assertEqual(result,["result"])
        scoped.annotate.assert_called_once()
        expression=scoped.annotate.call_args.kwargs["_client_first"]
        self.assertEqual(expression.cases[0].condition.children[0],("entry","clients"))
        scoped.annotate.return_value.order_by.assert_called_once_with(
            "_client_first","full_name","id"
        )
        scoped.annotate.return_value.order_by.return_value.__getitem__.assert_called_once_with(
            slice(None,5,None)
        )
