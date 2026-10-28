# VENCIRA — O8c: guardado de avisos por anotación (probado y ensayado; despliegue DEV pendiente)

## Estado confirmado el 25/10/2026 — O8c DEPLOY DEV CORRECTO; aceptación manual pendiente

**EVIDENCIA REAL aportada por el usuario** al ejecutar `scripts/deploy_o8c_0015_guarded.sh` sobre fuente `9c404380e5801d8f9fd2d4dfe260d51df78264d6`: `RECIBO_RESTAURACION_O8C_VALIDO=OK`, `O5_CIFRADO_ACTIVO=OK`, `IMAGENES_O8B_CONSERVADAS=OK`, `BUILD_API_WEB=OK`, `PLAN_MIGRACION_0015=OK`, `BACKUP_O5_PRE0015_FRESCO=OK`, `APLICAR_0015_EXPLICITAMENTE=OK`, `MIGRACION_0015_VERIFICADA=OK`, `TABLA_BORRADORES_VACIA_Y_RESTRINGIDA=OK`, `CHECK_MIGRACIONES_POST0015=OK`, `API_O8C_DESPLEGADA=OK`, `FLUTTER_WEB_O8C_DESPLEGADA=OK`, `POSTGRES_0015_SIN_REINICIO=OK`, `ENDPOINTS_PRIVADOS_PROTEGIDOS=OK` (HTTP 403 sin sesión para O7/O8b/O8c/O3), `HEALTH_api=healthy`, `HEALTH_db=healthy`, `HEALTH_web_preview=healthy`, proxy local 200 y `DEV_VENCIRA_HTTPS_HTTP=200`, `O8C_GUARDADO_SOLO_BORRADOR=OK`, `O8C_DESPLIEGUE_0015_LOCALCHECK=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`. PostgreSQL LIVE está ahora en `reminders.0015_renewal_reminder_drafts`, **no 0014**. NO volver a ejecutar la migración ni el script de despliegue.

**Recibo local privado** `/tmp/vencira-o8c-deploy.gst32W6O.receipt`, **log** `/tmp/vencira-o8c-deploy.6ggUPoJg.log`. Imágenes anteriores recuperables: `vencira-o8c-before-api:20261025T061256Z_2623430` y `vencira-o8c-before-web:20261025T061256Z_2623430`. Se realizó copia cifrada O5 nueva antes de migrar y no se cambiaron timers, Caddy u OAuth.

**Pendiente únicamente UAT funcional O8c (NO afirmarlo aceptado):** abrir `https://dev.vencira.es/` con anotación ficticia abierta, expandir «Simular avisos de vencimiento», localizar «Guardar borrador de avisos», escribir `20,15` y guardar. Debe figurar borrador guardado; salir/volver y comprobar persistencia solo de esa anotación; otra anotación debe mantener defaults 60/45/35. Verificar que no existe notificación enviada, programada ni regla habilitada. Simulación O8b sigue temporal/no persistente; O8c solo guarda días como **draft**. Si falla UAT, corregir sin volver a aplicar 0015.

**Fuente rápida para nuevo chat:** `docs/NEXT_CHAT_HANDOFF_SHORT.md`. Siguiente bloque tras UAT: O9, revisión de preguntas de control, plazos/repeticiones y decisiones whitepaper §18, sin activar notificaciones prematuramente.


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

## 25/10/2026 — O8c restore drill/migration 0015 on clone PASSED, original 0014 UNCHANGED

User's actual terminal log: commit `4d39705d8379eaf722e677b3be1e4923a0d9b4a8`; gates `FUENTES_PREFLIGHT_O8C=OK`, `POSTGRES_0014_ORIGINAL_PRE=OK`, O5 read-only `O5_STATUS=OK`, immutable snapshot reuse `SNAPSHOT_O5_EXACTO_Y_RECIENTE=OK`, `O5_BACKUP_PRE0015_REUTILIZADO=OK`, isolated Docker network and PostgreSQL17 clone created, `RESTAURACION_DRIVE_PG17_TEMPORAL=OK`, `RESTAURACION_CONTEOS_VERIFICADOS=OK`, backend isolated build, `PLAN_MIGRACION_0015=OK`, `MIGRATE_0015_SOLO_CLON=OK`, `0015_APLICADA_SOLO_EN_CLON=OK`, `DRAFT_ONLY_CONSTRAINTS=OK`, `SIN_BACKFILL_Y_TABLAS_ANTERIORES_INTACTAS=OK`, `POSTGRES_0014_API_WEB_SIN_CAMBIOS=OK`, `RECIBO_ENSAYO_O8C=OK`, `ENSAYO_O8C_0015_AISLADO=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`. Verified **actual encrypted Google Drive O5 recovery** and data-count-preserving application of 0015 to temporary PG17; original live DB and services unchanged. Receipt root/private `/tmp/vencira-o8c-rehearsal.1tRiHwUA.receipt`, log `/tmp/vencira-o8c-rehearsal.JGJnylE4.log`. Snapshot `0b838739` verified. No credentials or data should be pasted.

**Next work**: author a NEW single-use guarded O8c live DEV rollout script pinned to tested source SHA `80a5ac618f476a2d3b256499047dfdd1ada01c12` (docs/scripts may move), requiring restore receipt exact content and unchanged 0014, root-only gates, O5 health/recent backups, old-image tags before build, builds API+Web before explicit one-time migration 0015, `migrate --plan`, SQL schema check, API/Web re-creation only, HTTP/auth/smoke, DB container-ID preserved and receipt. Prefer a fresh encrypted O5 backup immediately before mutation and no automatic rollback. Never use old O8b no-migrations deploy or O3 automigrate scripts. **DO NOT claim 0015 deployed** until a real server success log. No notification delivery / jobs enabled.

## 25/10/2026 — O8c RESTORE + MIGRATION REHEARSAL VERIFIED, rollout live pending

El titular confirmó resultado integral `ENSAYO_O8C_0015_AISLADO=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`: copia cifrada O5 `0b838739` restaurada en PG17 temporal, conteos iguales, `migrate --plan` y migración `0015_renewal_reminder_drafts` ejecutada SOLO en clon, restricciones draft-only y datos anteriores preservados. DB LIVE continua 0014; API+Web sin cambios. Recibo validado `/tmp/vencira-o8c-rehearsal.1tRiHwUA.receipt`, log privado `/tmp/vencira-o8c-rehearsal.JGJnylE4.log`.

Se empezó a preparar `scripts/deploy_o8c_0015_guarded.sh` con fuentes fijas al commit probado `80a5ac618f476a2d3b256499047dfdd1ada01c12`, recibo O5/rehearsal, contenedores sanos, copia cifrada y tags de imágenes antes de builds. **IMPORTANTE: el script NO ESTÁ COMPLETO y fue BLOQUEADO con salida incondicional `O8C_DEPLOY_NO_HABILITADO=SCRIPT_INCOMPLETO` + `exit 78` al inicio**. No ejecutarlo ni quitarle el bloqueo sin implementación completa y revisión. Falta completar migración explícita en vivo, cortes API+Web, todos los postchecks/HTTP, recibo y manejo de estado parcial. Ni `0015` ni nueva API/Web están desplegadas. No usar scripts viejos de O8b; no ejecutar `migrate` directamente.

Próxima tarea técnica: finalizar y verificar cuidadosamente ese script bajo el proceso O4 o sustituirlo por una secuencia de migración segura y explícita con copia nueva O5, garantía de restauración, etiquetas de imágenes, plan, migración 0015 única, API check-only, despliegue por servicios y verificación. No afirmar éxito sin salida real del usuario. O8c sigue TESTEADO + ENSAYADO pero NO DESPLEGADO. O8b sigue ACEPTADO.

## 25/10/2026 — Ensayo O8c validado; procedimiento de migración DEV terminado, NO EJECUTADO

El usuario confirmó restauración desde O5 cifrado (snapshot `0b838739`) en PG17 temporal y migración `0015` en clon con resultado `ENSAYO_O8C_0015_AISLADO=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`. Recibo de ensayo en el servidor: `/tmp/vencira-o8c-rehearsal.1tRiHwUA.receipt`, creado por root, modo 600. Las tablas previas y la API/Web de DEV permanecieron sin cambios, en esquema `0014`.

**Código NUEVO EN GITHUB, NO EJECUTADO**: `scripts/deploy_o8c_0015_guarded.sh` completo y habilitado tras auditoría de su orden: gate `VALIDATED=80a5ac618f476a2d3b256499047dfdd1ada01c12`, recibo reciente root-only con snapshot y prueba restaurada, API O4 `migrate --check` sin automigración, salud y esquema original `0014`, auditoría O5, etiquetas recuperables para imágenes API/Web O8b, compilación de ambas imágenes, plan `0015` de solo lectura, copia O5 cifrada NUEVA previa al DDL, migración **explícita** `manage.py migrate reminders 0015_renewal_reminder_drafts --noinput`, verificación de tabla vacía/restricciones/revisión, `migrate --check` posterior, recreación SOLO API y Web, HTTP 200, endpoints de resultados O7, preview O8b, config O8c y desenlaces O3 anónimos 401/403, salud final, y recibo privado. Fallo posterior a migración se trata como estado parcial: **NO reintentar ni restaurar automáticamente**. PostgreSQL no se reinicia por este procedimiento, O5 timers y Caddy no se modifican. NO envía avisos ni habilita reglas.

**Nuevo gate estático**: `scripts/check_o8c_deploy_static.sh`: ejecuta `bash -n` y comprueba existencia/orden de las operaciones obligatorias y ausencia de acciones destructivas conocidas. Debe pasar ANTES del despliegue. El asistente aún no ha recibido la ejecución local de este gate ni la del despliegue. El próximo comando del usuario será `(cd /home/vencira/vencira-localcheck; git fetch origin integration/local-e2e-prep; git merge --ff-only FETCH_HEAD; bash scripts/check_o8c_deploy_static.sh; sudo bash scripts/deploy_o8c_0015_guarded.sh); echo RESULTADO_EJECUCION=$?; echo CONSOLA_ABIERTA`, preservando `|| exit 1` en cada fase de la subshell. **No declarar O8c desplegada hasta `O8C_DESPLIEGUE_0015_LOCALCHECK=OK` y final cero.**

Tras éxito, UAT DEV: abrir anotación sintética activa > Simular avisos > Guardar solo borrador `20,15`, volver y comprobar que persiste únicamente en esa anotación, otras conservan defaults, no notificaciones; conflict/revisión; no datos reales. Mantener documentación actualizada en todo cambio de chat.
