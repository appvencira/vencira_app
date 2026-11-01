# VENCIRA — M3-02: sugerencias Cliente prioritarias (01/11/2026)

## Cambio funcional
En `backend/reminders/person_suggestions.py` las cinco sugerencias se ordenan priorizando las anotaciones **ya visibles** clasificadas como `clients` antes de tomar los cinco resultados. Antes el orden alfabético + ID podía excluir anotaciones Clientes entre varias coincidencias. La operación mantiene `_visible_renewals(membership)` y todos los filtros de `name`/`phone`/`exclude` antes de ordenar; no crea CRM, no modifica anotaciones y no comparte personas entre workspaces.

## Prueba
`backend/reminders/test_person_suggestions_ranking.py` comprueba que el helper conserva el queryset recibido, aplica `Case(When(entry=clients))`, ordena antes del límite de cinco. **Prueba publicada, no hay PASS confirmado en CI ni VPS**. La semántica del endpoint completo requerirá prueba HTTP multitenant adicional; el cambio no demuestra identidad perfecta entre personas homónimas.

## Pendientes de M3-02
Entrega de avisos, controles legal/confirmación, UX móvil y decisiones §18; el hito sigue abierto.

`MB1_GLOBAL_FREEZE=NOT_VERIFIED`; `MB1_RELEASE_AUTHORIZED=NO`; `NO_DEPLOY_NO_LIVE_MIGRATION=1`. Hitos 2/15 (13,3%).
