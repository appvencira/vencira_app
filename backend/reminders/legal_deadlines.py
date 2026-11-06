"""Whitepaper §8: fecha límite orientativa por un mes civil.

La función NO programa avisos, no determina qué pólizas están legalmente
sujetas a art. 22 y no debe equipararse a Renewal.notice_deadline_on,
que es una fecha contractual opcional independiente.
"""
import calendar
from datetime import date, datetime


def one_month_before(expiry: date) -> date:
    """Un mes civil anterior, con día inexistente ajustado al último del mes.

    31/03/2027 -> 28/02/2027; 31/03/2028 -> 29/02/2028.
    No son «30 días» ni una fecha de notificación automática.
    """
    if not isinstance(expiry, date) or isinstance(expiry, datetime):
        raise TypeError("expiry debe ser fecha civil date")
    year = expiry.year - (expiry.month == 1)
    month = 12 if expiry.month == 1 else expiry.month - 1
    return date(year, month, min(expiry.day, calendar.monthrange(year, month)[1]))
