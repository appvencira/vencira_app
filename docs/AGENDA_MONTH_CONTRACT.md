# VENCIRA — Calendario mensual agregado (MVP)

**22/10/2026** · Solicitud de continuación tras las pruebas del vencimiento y preaviso en Android.

## Alcance funcional

- Entrada **«Ver mes»** desde la agenda diaria; encabezado con mes/año, mes anterior/siguiente y acceso a mes actual.
- Cuadrícula de lunes a domingo, con puntos por actividad del día. Al pulsar una fecha se regresa a la agenda diaria del mismo equipo mostrando ese día.
- Marcadores por tipo: **vencimiento**, **límite contractual de preaviso** y **aviso previsto**. Una misma anotación puede aportar en dos fechas/tipos; no se confunde la fecha contractual con un envío.
- Marcador **relleno** = vencimiento en estado `pending`; **contorno** = `contacted`. `contacted` no significa cerrado ni implica notificación entregada. `closed` se excluye de esta primera vista activa, como en la agenda diaria.
- Castellano/catalán, tema claro/oscuro, accesibilidad con descripciones de fecha y cantidades por estado, móviles de 320/375 píxeles.
- **No** hay vista de gestiones cerradas, recordatorios entregados ni calendario de eventos `recuérdamelo` (aún no modelados).

## Contrato HTTP seguro

`GET /api/v1/workspaces/<uuid>/agenda/month/?month=2027-03`

`month` es obligatorio `YYYY-MM` de 2000 a 2100. Nunca se infiere a partir del servidor. Respuesta ilustrativa sin datos reales:

```json
{
  "month": "2027-03",
  "days": [
    {
      "day": "2027-03-27",
      "expiry": {"pending": 0, "contacted": 0},
      "notice_deadline": {"pending": 1, "contacted": 0},
      "reminder": {"pending": 0, "contacted": 0}
    },
    {
      "day": "2027-03-31",
      "expiry": {"pending": 1, "contacted": 1},
      "notice_deadline": {"pending": 0, "contacted": 0},
      "reminder": {"pending": 0, "contacted": 0}
    }
  ]
}
```

Solo devuelve días con alguna actividad; `days: []` para un mes vacío. No incluye referencias, identificadores de pólizas, nombres, ni número de empleados.

Los contadores son **anotaciones distintas en cada tipo, día y estado**, no número de avisos enviados ni suma única entre tipos. Por ejemplo, dos políticas que programan avisos el mismo día sobre la misma póliza cuentan 1 en `reminder`. Si una póliza tiene vencimiento y límite en el mismo día, cuenta una vez en cada tipo (no se suman para decir «2 pólizas»).

## Autorización y eficiencia

- Sesión obligatoria, miembro del `workspace`; para equipos `member` únicamente anotaciones asignadas al usuario, para `owner` toda la organización incluyendo sin asignar.
- El filtro se aplica **antes de agrupar**; no se permite inferir trabajo ajeno mediante contadores.
- No se listan 28–31 páginas de anotaciones ni se transfieren referencias de todo el mes.
- 3 agregaciones SQL acotadas (vencimientos, fechas límite y recordatorios únicos), independientes del número de anotaciones por mes. Se excluyen registros `closed`, candidatos cancelados o con política desactivada.
- Formato canónico, protección contra mes manipulado y respuesta `Cache-Control: no-store`.
- Consulta GET de solo lectura; no cambia tablas, migraciones, notificaciones, jobs ni sesiones.

## Verificación

- Django SQLite y PostgreSQL 17: distintos estados, fechas límite, candidatos duplicados, cierres, política deshabilitada, límites de mes, privacidad por rol/workspace, meses inválidos.
- Flutter: contrato de mismo origen, rechazo de mes discrepante/cantidades negativas, navegación mes/día, indicadores de estado, ES/CA y tamaños móviles.
- Docker HTTP E2E: autenticación, consulta mensual del registro ficticio, ausencia de referencia personal en respuesta, rechazo de mes imposible y denegación posterior a logout.
- Despliegue en VPS **solo tras confirmar CI verde**: `/home/vencira/vencira-localcheck`, proyecto `vencira_localcheck`; actualizar **API y web**, preservar base de datos y el proyecto `vencira_preview`, no cambiar Caddy. Verificar 27/10/2026 y 29/10/2026 en calendario de octubre desde Chrome Android sin borrar cookies.

Pendientes: indicador mensual de respuestas y cierres reales, eventos `recuérdamelo`, resumen multianual, funcionamiento offline y eventual estrategia de color de categorías del whitepaper.
