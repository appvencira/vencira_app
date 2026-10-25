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

## 25/10/2026 — Preflight O8c VERDE y ensayo sobre copia cifrada O5 preparado

El usuario ejecutó en Ubuntu `scripts/validate_o7_o8_preflight.sh` sobre commit **`80a5ac618f476a2d3b256499047dfdd1ada01c12`**. Salida real: `LOCALCHECK_HEALTH_PRE=OK`, Compose OK, i18n ES/CA OK, imagen backend OK, `DJANGO_CHECK_MIGRACION_SECA=OK`, `DJANGO_SQLITE_SUITE_COMPLETA=OK`, `PG17_TEMPORAL=OK`, `DJANGO_POSTGRES17_SUITE_COMPLETA=OK`, `FLUTTER_ANALYZE_TEST_BUILD=OK`, `LOCALCHECK_HEALTH_POST=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`. Log local `/tmp/vencira-o7-o8-preflight.E7GBeX2E.log`. Esto prueba que **0015 se instala en bases temporales de test**, NO que esté aplicada en el PostgreSQL persistente. Se conserva esquema operativo 0014.

Se añadió el procedimiento **`scripts/rehearse_o8c_0015_from_o5.sh`**. **SOLO ENSAYO, sin despliegue ni migración real**. Se invoca con `sudo bash` desde la rama y checkout correctos. Gate por SHA anterior para backend/clients/compose/deploy; salud inicial de los contenedores API, DB, Web; esquema original 0014. Comprueba timers y snapshot reciente O5, crea nueva copia PostgreSQL **cifrada en Drive**, obtiene su snapshot Restic bajo `flock` y lo restaura por pipe directo (sin volcado descifrado en disco) en PostgreSQL 17 efímero en red Docker interna. Compara recuentos de entidades; construye nueva imagen Django aislada; consulta `migrate --plan` y ejecuta **exclusivamente en el clon** `migrate reminders 0015_renewal_reminder_drafts --noinput`. Después verifica la tabla de borradores vacía, constraints `draft-only` y revisión positiva, ausencia de backfill, migración +1 y contenido de tablas anteriores intacto. Finalmente comprueba que el **DB original conserva exactamente 0014**, mismos contenedores API/DB/Web y salud; limpia red y clon, genera recibo privado. Las tareas O5 y Caddy no se reconfiguran; se limita a añadir una copia cifrada normal a O5. **No se ejecutó aún el ensayo; no darlo por verde hasta salida real**.

**Siguiente gate exacto para el usuario**: `git fetch origin integration/local-e2e-prep`, `git merge --ff-only FETCH_HEAD`, `bash -n scripts/rehearse_o8c_0015_from_o5.sh`, y `sudo bash scripts/rehearse_o8c_0015_from_o5.sh`, dentro de un subshell para mantener SSH. Esperar: `O5_BACKUP_PRE0015=OK`, `RESTAURACION_DRIVE_PG17_TEMPORAL=OK`, `PLAN_MIGRACION_0015=OK`, `0015_APLICADA_SOLO_EN_CLON=OK`, `POSTGRES_0014_API_WEB_SIN_CAMBIOS=OK`, `ENSAYO_O8C_0015_AISLADO=OK`, `RESULTADO_GLOBAL=0`. Ante fallo, no ejecutar migración real ni repetir a ciegas, inspeccionar `FASE_FALLIDA`.

Tras ensayo verde se necesitará **OTRO script distinto** de despliegue DEV con gates sobre recibo del ensayo, snapshot nuevo y misma fuente, retención de imágenes anteriores, migración `0015` explícita en DB persistente solo con guard y comprobaciones, luego actualizar API y Flutter Web. **No usar** `deploy_o8b_no_migrations.sh`. No activar avisos; el estado sigue `draft`.

