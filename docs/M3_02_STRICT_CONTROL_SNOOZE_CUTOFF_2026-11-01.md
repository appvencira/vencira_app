# VENCIRA — M3-02: límite civil de aplazamiento de control

## Incoherencia corregida
La validación de respuesta manual «No» ya prohibía programar una nueva pregunta el mismo día del límite civil (`control_responses.py`: `repeat_on >= cutoff`). Sin embargo, `operational_transitions.py` solo rechazaba `new_day > cutoff`, dejando pasar la acción «Otro día» justo al límite.

Ahora ambas rutas rechazan una nueva pregunta de control cuando `new_day >= one_month_before(expires_on)`. No cambia los aplazamientos ordinarios sin pregunta de control. Las pólizas Vida siguen requiriendo revisión humana.

## Evidencia de regresión añadida
En `backend/reminders/test_operational_transitions.py`, sustituida la prueba que admitía el aplazamiento al límite por una que exige rechazo sin evento ni mutación. Añadida prueba positiva al día anterior. CI `.github/workflows/m3-product-contracts.yml` incluye ahora pruebas de transiciones y bandeja operativa, además de las respuestas de control y sugerencias.

**Estado:** cambios y pruebas publicados, todavía sin resultado PASS de Actions observado. DEV intacto, sin migraciones ni envío externo. No cerrar M3-02 ni aumentar el progreso por este cambio (2/15, 13,3%).
