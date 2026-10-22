# API de agenda diaria — base de lectura (MVP)

**Estado:** rama `feat/agenda-day-readonly`, PR apilada sobre `feat/team-assignment-isolation`. No integrada ni desplegada. 22/10/2026.

## Referencia funcional

Whitepaper «Agenda de vencimientos externos», sección 5: la pantalla principal es una agenda tipo papel, se abre en **Hoy**, incluye cabecera con fecha y cantidad de anotaciones, tira semanal, desplazamiento al día anterior/siguiente, «Hoy», «Ver mes» y lista de eventos del día. El día incluye **avisos previstos**, futuros eventos «recuérdamelo» y **vencimientos**; no es una lista global de pólizas.

La parte de «recuérdamelo» y los cierres no están modelados aún. Esta propuesta entrega únicamente una **lectura realista de lo que sí existe**, no presenta eventos pendientes como si estuviesen desarrollados.

## Contrato provisional

`GET /api/workspaces/{uuid}/agenda/?day=2027-03-31&page_size=25&page=1`

- `day` obligatorio y validado como fecha ISO canónica `YYYY-MM-DD`. Lo envía el cliente según su día local. No inferir «hoy» a partir del reloj del servidor: puede estar en otra zona.
- Autenticación requerida y comprobación de pertenencia a workspace.
- `owner`: ve anotaciones activas de toda la cuenta (incluidas sin asignar).
- `member`: solo anotaciones `assigned_to=user`, aplicando el filtro **antes de buscar/paginar**.
- Incluye `Renewal.expires_on == day` (salvo `closed`), y `ReminderCandidate` en estado `planned`, programado para ese día, con política `enabled` y anotación no `closed`.
- **No representa envíos, recepciones ni notificaciones entregadas.** Son candidatos previstos.
- Una anotación aparece una sola vez por página; `events` diferencia `expiry` y cada recordatorio `reminder`, con su `candidate_id` y `basis` (código estable). UI debe traducir estos códigos en ES/CA.
- Orden estable por fecha de vencimiento/UUID y paginación existente del backend. `count` cuenta **anotaciones**, no número total de eventos ni notificaciones. No mostrar «N avisos» usando ese contador.
- Nunca incluir referencias ajenas ni datos de equipos externos; el serializer mantiene campos mínimos, sin documentos.
- Respuesta 400 por fecha ausente/no válida; 404 para workspace ajeno, 401/403 sin autenticación.

Ejemplo sintético de respuesta:

```json
{
  "count": 1,
  "next": null,
  "previous": null,
  "day": "2027-03-31",
  "results": [
    {
      "renewal": {
        "id": "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
        "customer_reference": "DEMO-HOGAR-001",
        "expires_on": "2027-05-01",
        "notice_deadline_on": null,
        "status": "pending",
        "assigned_to": 17,
        "created_at": "2026-10-22T10:00:00Z",
        "updated_at": "2026-10-22T10:00:00Z"
      },
      "events": [
        {
          "kind": "reminder",
          "candidate_id": "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
          "basis": "expiry"
        }
      ]
    }
  ]
}
```

Los IDs y fechas son ficticios. El cliente no debe confiar en el número de usuario, sino en permisos del servidor.

## Implementación

- `reminders/views.py: agenda_day`: consulta paginada con `Exists` para evitar duplicados al unir candidatos de aviso, más `Prefetch` de recordatorios del día para evitar N+1.
- `reminders/urls.py`: ruta `api-agenda-day`.
- `reminders/test_agenda.py`: pruebas de dos empleados del mismo equipo, propietario, otro workspace, fecha, vencimiento, aviso previsto, cierre, cancelación, política deshabilitada y paginación.
- No se cambia esquema ni se programa ningún envío.
- Dependencia funcional de PR #6: `assigned_to` y `_visible_renewals`. Debe integrarse PR #6 antes de esta rama.

## Pendientes para agenda final del whitepaper

1. Eventos `recuérdamelo`, respuesta a notificaciones, pregunta de control y cierre.
2. Vista diaria, tira semanal y calendario mensual en Flutter (ES/CA, temas, accesibilidad, gestos y flechas); se puede construir sobre este contrato con ampliaciones.
3. Datos finales de anotación (nombre/nick, modalidad, aseguradora, color de entrada). No sustituirlos por un CRM.
4. Resumen mensual con puntos coloreados y consulta eficiente de días con actividad (sin descargar todas las páginas).
5. Zona horaria por preferencia de usuario para cálculos, sin desplazar vencimientos basados en fecha civil.
6. Reconciliación de recordatorios al editar o cancelar una anotación, con no duplicación e historial.
7. Criterio definitivo de avisos no atendidos (pendiente del apartado 18).

## Integración segura

CI Django, `makemigrations --check --dry-run` y tests SQLite/PostgreSQL. No despliegue en VPS ni datos reales antes de cerrar permisos de equipo y confirmar la interfaz real.

## Evidencia de validación — 22/10/2026

- [GitHub Actions #8 — Django assignment isolation](https://github.com/appvencira/vencira_app/actions/runs/39721223694), sobre el commit de código `efc348e`: **success**.
- `python manage.py check`, `makemigrations --check --dry-run`, pruebas Django completas en SQLite y PostgreSQL 17: **superadas**.
- Incluye las pruebas de la nueva ruta de agenda, protección entre organizaciones y usuarios, contratos de vencimiento y recordatorio, fecha canónica y paginación.
- Validación de backend no equivale a revisión de UI. Falta la vista Flutter, que se implementará con arreglo al whitepaper una vez integradas las ramas dependientes.
