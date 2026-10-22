# VENCIRA — Límite de preaviso contractual en agenda diaria

**22 de octubre de 2026.** Corrección funcional solicitada después de la primera prueba visual real en `dev.vencira.es`.

## Comportamiento esperado

- `Renewal.notice_deadline_on` es una **fecha contractual**, no un recordatorio ni un envío.
- Si un vencimiento **no cerrado** tiene preaviso el día consultado, aparece en la agenda de ese día con `{"kind":"notice_deadline"}`, aunque no exista ninguna `ReminderPolicy` ni `ReminderCandidate`.
- Si el día corresponde también al vencimiento, la referencia aparece **una sola vez** con dos eventos: `expiry` y `notice_deadline`. `count` continúa contando referencias, no eventos.
- Un `ReminderCandidate` activo se mantiene como evento separado `{"kind":"reminder","candidate_id":"...","basis":"expiry"|"notice_deadline"}`. Nunca se declara entregado.
- Se conservan la exclusión de registros `closed`, la pertenencia al `workspace` y las restricciones `assigned_to` de cada miembro; permisos aplicados antes de la paginación.
- Sin preaviso (`notice_deadline_on=null`) no hay evento de este tipo.
- El día usa fecha civil ISO sin inferir zona del navegador/servidor.

## Contrato

`GET /api/v1/workspaces/{uuid}/agenda/?day=2026-10-27`

Respuesta relevante, con datos ficticios:

```json
{
  "day": "2026-10-27",
  "count": 1,
  "next": null,
  "previous": null,
  "results": [
    {
      "renewal": {
        "id": "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
        "customer_reference": "PRUEBA-HOGAR-001",
        "expires_on": "2026-10-29",
        "notice_deadline_on": "2026-10-27",
        "status": "pending",
        "assigned_to": null
      },
      "events": [{"kind": "notice_deadline"}]
    }
  ]
}
```

Es un fragmento ilustrativo de los campos de lectura; el serializer también puede devolver otros metadatos.

El 29 de octubre el mismo registro aparece con `expiry`, sin reproducir un evento `notice_deadline` de fecha distinta. La ficha Flutter muestra **ambas fechas** en cualquiera de las vistas. Si fechas coinciden, se muestran dos etiquetas en una sola ficha.

## UI e idiomas

Flutter muestra el chip `Límite contractual de preaviso` / `Límit contractual de preavís`, distinto del chip `Aviso previsto · Preaviso`. Las dos fechas se ven bajo la referencia. El texto de ayuda separa fechas contractuales de avisos previstos.

## Pruebas de regresión

- Django: preaviso sin regla de recordatorio, coincidencia de ambas fechas, exclusión por estado y aislamiento entre usuarios/organizaciones (SQLite/PostgreSQL).
- Flutter: parser admite nuevo evento; vista móvil 320px en ES y CA, renderiza etiqueta, fecha límite y vencimiento, sin confundirlo con aviso enviado.
- E2E: fixture con fecha de preaviso, login real por sesión/CSRF, consulta HTTP de ambos días, validación de evento, logout.
- No hay migraciones, cambios de cookies, autenticación, tareas programadas ni nuevos envíos.

## Despliegue controlado de desarrollo

1. Confirmar las pruebas de GitHub Actions del **commit exacto**.
2. Mantener proyectos `vencira_preview` y `vencira_localcheck` separados; Caddy debe seguir encaminando `/api/*` y `/accounts/*` a `127.0.0.1:28731`, resto a `127.0.0.1:28732`, con Basic Auth activa.
3. En `/home/vencira/vencira-localcheck`: `git pull --ff-only` mediante la deploy key SSH ya configurada; **no reemplazar .env**.
4. `sudo docker compose -p vencira_localcheck -f compose.yaml -f compose.preview.yaml up --build -d`; comprobar `ps`, API y `VENCIRA_WEB_BIND_PORT=28732 python3 scripts/smoke_same_origin.py`. Sin `down -v`.
5. En navegador móvil privado con HTTPS, entrar a 27/10/2026 y 29/10/2026 para `PRUEBA-HOGAR-001`; verificar preaviso en 27 y vencimiento en 29. No introducir datos reales.
6. No modificar Caddy si continúa funcionando el enrutamiento anterior; solo revisión visual manual y pruebas adicionales.

**Límites:** no genera ni entrega avisos reales; falta la vista mensual, flujo de respuesta a recordatorios, política de retención y preparación para datos reales.
