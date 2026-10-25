# VENCIRA — O8c: contrato de guardado de avisos por anotación (DISEÑO, sin desplegar)

**25/10/2026.** Basado en whitepaper §§7, 8 y decisiones abiertas §18. **Fase de diseño técnico:** sin código de migración, sin persistencia habilitada, sin activar notificaciones. O8b (simulador GET de solo lectura) ya fue validado y desplegado en DEV; O8b no guarda nada.

## Lo que existe y no debe confundirse

- `ReminderPolicy` actual: regla **de ámbito organización**, identificada por `workspace + basis + days_before`, con `enabled=False` por defecto. Es infraestructura legacy para previsiones, no un modelo de reglas por póliza.
- `ReminderCandidate`: solo anotación **prevista** o cancelada; no representa una notificación entregada, ni cuenta con canal, recepción ni respuesta.
- `Renewal.notice_deadline_on`: campo **contractual y opcional**, distinto del límite civil informativo del §8.
- `preview_reminder_plan`: cálculo puro validado, admite 1–12 días naturales únicos 0–365, determina aviso último antes del mes civil y detecta retrasos; no define motivos ni políticas reales.

## Propuesta mínima, segura y aditiva

Una tabla independiente, por ejemplo `RenewalReminderConfiguration`, vinculada 1:1 a `Renewal`. **Borrador hasta aprobación funcional**; no implementar automáticamente sin confirmar campos.

| Campo propuesto | Contrato | Motivo |
| --- | --- | --- |
| `renewal` | FK OneToOne, único | Afecta una sola anotación; no CRM |
| `days_before` | JSON ordenado y validado con `preview_reminder_plan` | Conserva 60,45,35 o anticipaciones personalizadas |
| `state` | `draft` / `enabled` / `paused` | Separar guardado de activación real |
| `revision` | entero monotónico + compare-and-swap | Previene pérdida silenciosa con dos sesiones |
| `created_by` / `updated_by` | FK a usuario autorizable | Auditoría y trazabilidad |
| `created_at` / `updated_at` | timestamps | Operación y depuración |
| `motives` | NO adoptar catálogo fijo hasta decisión §18 | Whitepaper pide motivos, pero no fija cuáles |
| `source` | defaults del sistema / override explícito | Evitar fingir que defecto es elección consciente |

**Estado de despliegue seguro inicial: SOLO `draft`**. Aunque haya validación de valores, *guardar* no debe activar `ReminderPolicy.enabled`, crear `ReminderCandidate`, ni programar webpush/email/local. No se deben aplicar automáticamente 60/45/35 a pólizas preexistentes sin decisión expresa.

### Contrato API propuesto

- `GET /api/v1/workspaces/{workspace}/renewals/{renewal}/reminder-config/`: configuración guardada o defaults **sugeridos y no persistidos**, distinguidos por bandera `is_persisted`.
- `PUT .../reminder-config/`: sobrescritura atómica con `days_before`, `revision` y `state=draft`, validación de tipo estricto y dominio; respuesta 200 con `revision` nueva.
- Si no existe configuración, usar revisión 0 solo para primer guardado, y hacer transacción con bloqueo adecuado o manejo del conflicto `UNIQUE` para carreras.
- Autorización = `_membership` + `_visible_renewals`, rechazo 404 cross-tenant y no asignados; no escritura en anotaciones archivadas/cerradas (409); sin PII en respuestas, `Cache-Control: no-store`.
- Dar 409 en `revision` obsoleta, obligando refrescar antes de guardar, jamás último escritor gana silenciosamente.
- Documentar que `state=draft` **no genera avisos ni tareas**. En O9–O10 futuros se podrá separar `PLANNED`, `QUEUED`, `DISPLAYED`, `ANSWERED`, `DELIVERED` con evidencia real, nunca inferidos de este borrador.

### Dependencias de decisiones (NO aprobadas aún)

1. Catálogo y textos de motivos de avisos de 60,45,35; si es obligatorio elegir motivo en cada aviso, no permitir activación sin motivo.
2. Alta tardía, reglas sin ningún aviso anterior a tope civil y conducta de «No se ha comunicado no renovación».
3. Excepción de Vida y el alcance legal de fecha informativa.
4. Qué pasa con un aviso no atendido; reintentos y criterios de repetición.
5. Quién puede cambiar reglas compartidas en Equipo: responsable de la anotación, owner, o ambos. Implementación provisional debe respetar los permisos actuales de `_visible_renewals` como máximo, no ampliarlos.

### Migración y validación obligatorias

- Si se aprueba el diseño, crear `0015` **solo aditiva**, sin `RunPython` global y sin cambio destructivo del esquema `0014`. Dejar tablas legacy intactas; no backfill de clientes, personas, trabajos, fechas ni causas.
- Ejecutar pruebas de tipado/serialización, conteo de reglas 1–12, duplicados, 0/365, motivos futuros, 28/29 febrero, permisos owner/member/no-member/cross-tenant, anotaciones cerradas, token CSRF, idempotencia PUT y control `revision`/concurrencia.
- Validar sobre SQLite y PG17 temporal, Flutter ES/CA y web responsive. Antes de la migración persistente, ejecutar **O4: backup cifrado real, restauración en PG17 aislado y migración en ensayo con `migrate --plan`**. No aplicar en DB persistente sin ensayo verde y respaldo reciente. No `docker compose down -v`.
- Una vez disponible, incluir pantalla de editar/guardar como **borrador visible**, nunca presentar «avisos activados» ni «notificación enviada». La activación y entrega será una fase separada.

**Siguiente hito recomendado:** obtener aprobación de regla de borrador por anotación y motivos predeterminados antes de crear la migración; en paralelo, comenzar O11 «agenda HOY» independiente de la política de avisos y O14 seguridad RGPD/MFA.

## 25/10/2026 — Implementación draft-only versionada; NO desplegada

El modelo pasó de propuesta documental a **primera implementación de guardado de borradores**, aún pendiente de ejecutar la validación integral. No se han decidido ni activado motivos, canales, estado «enabled» ni entregas.

### Código preparado

- `backend/reminders/models.py` y migración **aditiva** `0015_renewal_reminder_drafts.py`: `RenewalReminderDraft` OneToOne por anotación, lista JSON `days_before`, `state=draft` con restricción de BD para impedir estados enabled, revisión positiva, actor de alta/modificación y timestamps; sin backfill, sin tocar `ReminderPolicy` ni `ReminderCandidate`.
- `backend/reminders/reminder_draft.py`: `GET /api/v1/workspaces/{workspace}/renewals/{renewal}/reminder-config/` devuelve defaults 60/45/35 con `is_persisted=false, revision=0` si no se guardó nada. `PUT` exclusivamente `Content-Type: application/json`, cuerpo exacto `{"state":"draft","revision":0,"days_before":[20,15]}` para primer guardado; respuestas `revision=1`. Para cambios posteriores, usar revisión vigente; edición en conflicto da HTTP 409, sin sobrescritura. Se bloquea con `select_for_update` la anotación autorizada en transacción para serializar escrituras. No aceptar cambios en cerradas/archivadas (409), ni usuarios ajenos (404); no PII en respuesta, `Cache-Control: no-store`; se informa de riesgo legal sin impedir guardar borradores.
- `backend/reminders/test_reminder_draft.py`: pruebas de primer GET sin persistencia, guardado por anotación, normalización de días, idempotencia de valores iguales, conflicto de revisión, aislamiento por workspace y responsable, CSRF en PUT sesión, entradas inválidas, estados prohibidos y ausencia de cambios de políticas/candidatos.
- `clients/flutter/lib/api/vencira_api.dart`: tipos seguros `VenciraReminderDraft`, `fetchReminderDraft`, `saveReminderDraft`, `VenciraConflictException`. Rechaza cualquier respuesta remota que diga `enabled` o `delivered=true`.
- `clients/flutter/lib/ui/reminder_draft_card.dart` y detalle de anotación: editor plegado junto al simulador O8b; ES/CA, consulta sólo al abrir, botón **Guardar solo borrador**, manejo explícito de conflicto mediante recarga, sin control para programar o enviar.
- `clients/flutter/test/reminder_draft_test.dart`: validación del tipo, ES/CA, guardado, días repetidos y conflicto 409; tests de O8b/contacto/seguimiento reejecutables como gate dirigido.

### Próximo paso — NO desplegar

Desde consola de Ubuntu, rama `integration/local-e2e-prep` sincronizada mediante fast-forward, ejecutar **sólo** `bash scripts/validate_o7_o8_preflight.sh`. Este preflight construye nueva API aislada, valida `makemigrations --check`, aplica migraciones en bases de test SQLite y PostgreSQL 17 efímero y ejecuta suite Django+Flutter completa. No aplica `0015` al PostgreSQL `vencira_localcheck`. **No utilizar** `scripts/deploy_o8b_no_migrations.sh` ni `scripts/validate_and_deploy_o8b.sh`: sus pin/checks pertenecen a un gate anterior y el despliegue O8c **sí requiere nueva migración**.

Para un eventual despliegue O8c, crear protocolo **O4 independiente**: backup PostgreSQL reciente e integridad Restic, restauración probada en PG17 temporal, `migrate --plan` en clon, migración `0015` aditiva explícita y health después de actualizar las imágenes API/Web; conservar versiones previas, no permitir API con esquema pendiente, nunca `down -v`. Toda la preparación de esa operación será posterior a resultados verdes del preflight.

**Estado a este corte: CÓDIGO Y TESTS EN GITHUB; SIN VALIDACIÓN REAL, SIN MIGRACIÓN VIVA, SIN DESPLIEGUE NI ACEPTACIÓN DE O8c.**

