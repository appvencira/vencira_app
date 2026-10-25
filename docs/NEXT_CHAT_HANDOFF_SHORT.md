# VENCIRA — resumen de continuidad (25/10/2026)

## Estado de DEV confirmado

- Stack `vencira_localcheck` en Ubuntu, `https://dev.vencira.es/`, Flutter Web ES/CA, Django/DRF, PostgreSQL 17. Cuenta `vencira`, checkout `/home/vencira/vencira-localcheck`, GitHub `appvencira/vencira_app` (PRIVADO), rama `integration/local-e2e-prep`. No tocar otros stacks ni Caddy.
- **O8b/O8c**: simulación temporal de avisos y borradores por anotación desplegados. Migración persistente **`reminders.0015_renewal_reminder_drafts`** verificada tras ensayo de copia cifrada O5; no ejecutar de nuevo ninguna migración ya aplicada.
- **O9a**: evaluación de fecha de control **solo lectura** desplegada en commit de código `30a2f20d66836b222c446398d33578f5efd4c222`; terminal `O9A_DESPLIEGUE_SIN_MIGRACION=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`; API/DB/Web saludables, HTTP público 200 y endpoints anónimos 403. Captura Android: borrador `20,15`, referencia `21/10/2026`, `Revisión manual pendiente` coherente, sin errores visibles. O9a no envía avisos ni registra respuestas.
- **O5**: backup cifrado Restic hacia Drive, programado 03:00 Europe/Madrid, health 08:00; ensayos restaurados satisfactoriamente. No exponer claves ni alterar temporizadores. Fuente de backup real previa O8c, recibo `/tmp/vencira-o8c-deploy.gst32W6O.receipt`; O9a recibo `/tmp/vencira-o9a-20261025T070242Z_2658759.Zkb4kHCT.receipt`.

## Whitepaper original ya recuperado

Usuario volvió a adjuntar **`White_paper_agenda_vencimientos.pdf`**, 23 páginas, fecha 18/10/2026, @Bibroker Mediadores, S.L.U. SHA-256 PDF `7158c085a0771f1c09c19223284345899ef516394d4ddd77c3b63cdda5598c66`, 828405 bytes.

En GitHub están: [`docs/source/README.md`](source/README.md), transcripción buscable de **las 23 páginas** [`docs/source/WHITEPAPER_ORIGINAL_2026-10-18_TRANSCRIPCION.md`](source/WHITEPAPER_ORIGINAL_2026-10-18_TRANSCRIPCION.md), [`docs/OPERATION_O9B_RESPONSE_CONTRACT.md`](OPERATION_O9B_RESPONSE_CONTRACT.md), y roadmap reconciliado. **No se ha subido todavía el PDF binario a GitHub** por limitación del conector de escritura: su texto está preservado, pero esquemas e imágenes solo en PDF original aportado.

**Corrección fundamental de O9b según PDF §8 p.11:** pregunta «¿Se ha notificado a la aseguradora su no renovación?»; respuesta **Sí** con tres alternativas exactas: «Avisada por el cliente», «La aseguradora no renueva», «Notificado por mí»; registra opción, usuario, fecha y hora, anotación permanece en agenda. Respuesta **No** con «Avísame dentro de [selector de días]»: genera aviso «Comunicar no renovación de [nombre del cliente]»; §10 p.13 exige repetir la pregunta en la fecha elegida, sin superar fecha límite de un **mes civil** anterior al vencimiento. Si plazo hoy/pasado, indicador rojo; avisar que no conviene apurar el último día. **Estos comportamientos están definidos, no pendientes.**

**Pendientes expresamente §18 p.22**: alta tardía, cero avisos pre-límite, tratamiento especial Vida, motivos por defecto, avisos no atendidos, y decisiones de permisos/empresa/seguridad. No deducir soluciones de propuestas no aprobadas.

## Auditoría de alineación con el whitepaper (25/10/2026)

**NUEVO documento prioritario:** [`AUDITORIA_ALINEACION_WHITEPAPER_2026-10-25.md`](AUDITORIA_ALINEACION_WHITEPAPER_2026-10-25.md). Arquitectura alineada parcialmente; P1: formulario «Referencia» adicional y backend sin tres campos obligatorios; «No aceptó» no restablece 60/45/35 al año siguiente; «Conseguido» no define tipo Cliente para nuevas anotaciones de esa persona; i18n Dart con literales. Apertura Dashboard en lugar de agenda HOY, y otros módulos de v1 pendientes. **No hay cambios de servidor.**

## Próxima tarea

**O9b-1**: implementar validador puro sin DB para exactamente 3 alternativas Sí y respuesta No con selección de fecha civil y tope, tests SQLite/PG17 y frontend ES/CA; después diseñar **nueva migración aditiva `0016`** para respuestas+historial inalterable. Antes de migrar DEV exigir protocolo O4 y restauración cifrada O5 real, nunca auto-migrar. **No enviar notificaciones ni cerrar anotación al responder Sí; no afirmar entregas por fechas calculadas**. O9a es solo lectura y debe conservarse.

## Forma de trabajo

Editar código y documentación directamente mediante conexión GitHub. Para Ubuntu, entregar un solo bloque Bash seguro y pedir logs; no reejecutar migraciones completadas. Mantener `docs/NEXT_CHAT_HANDOFF.md` para detalle histórico y actualizar esta ficha breve antes de cambiar de chat. Solo datos DEMO en DEV.

## 25/10/2026 — AUDITORÍA INTEGRAL DEL WHITEPAPER ORIGINAL (NO SOLO O9)

El usuario solicitó revisar **todo el desarrollo actual** frente a los 23 folios del PDF original. Se completó revisión de árbol completo de rama `integration/local-e2e-prep` (275 entradas), modelos/migraciones `0001`–`0015`, APIs, UI Flutter, seguridad y pruebas, contrastados con §§1–18 del PDF fechado 18/10/2026. **Informe estructurado y evidencia por archivo/folio:** `docs/AUDITORIA_ALINEACION_WHITEPAPER_2026-10-25.md`. No hubo despliegue, migración ni pruebas dinámicas nuevas en esta auditoría. Último DEV confirmado: O9a + O8c operativas, PostgreSQL `0015`, notificaciones NO activadas.

**Dictamen: dirección y arquitectura ALINEADAS PARCIALMENTE; v1 NO completa.** Discrepancias en funcionalidades YA desarrolladas: (A-01) Flutter exige «Referencia» extra ajena a obligatoriedad §6 y API permite nuevos registros con entrada/nombre vacíos por compatibilidad; (A-02) «No aceptó» mueve +1 año pero `outcomes._rebuild_candidates()` solo usa políticas `enabled=True`, no reinicializa los avisos predeterminados 60/45/35 en la anotación; (A-03) «Conseguido» cambia solo esa anotación a Cliente, sin sugerir Cliente por defecto al crear posteriores anotaciones de la misma persona; (A-04) textos ES/CA aún escritos directamente en Dart, en contra de §13. Otras brechas de producto: `main.dart` abre Dashboard, no página HOY directa §5; O8c guarda solo días/borrrador sin motivos/programación; §7–10 notificaciones, respuestas auditadas/repeticiones aún no desarrolladas; team lifecycle, adjuntos, Excel, resultados por miembro, borrado automático/avisos de retención, apps móviles offline y MFA/RGPD incompletos. Catálogo DGSFP no precargado/verificado. §18 propuestas abiertas **NO son decisiones aprobadas**. No confundir tests verdes O8c/O9a con cumplimiento completo.

**Prioridad propuesta:** primero corregir cuatro desviaciones en funciones existentes con tests y sin activar envíos, luego O9b según 4 opciones exactas §8 p.11 y control civil, después agenda HOY/avisos, y finalmente componentes esenciales de lanzamiento. Mantener solo datos DEMO en DEV. **Documento de auditoría es fuente de verdad** para no perder desajustes al cambiar de chat: `docs/AUDITORIA_ALINEACION_WHITEPAPER_2026-10-25.md`.

## 25/10/2026 — Fase única de corrección de divergencias ya implementadas (A01–A05)

**Objetivo del promotor:** resolver conjuntamente las diferencias detectadas en funciones existentes antes de retomar O9b, con un único preflight integral y un único despliegue controlado posterior. No confundir una fase con un comando de despliegue sin puertas de seguridad.

**Cambios de código integrados en GitHub y PENDIENTES de pruebas Ubuntu tras el lote:**
- **A01**: backend obliga **Entrada + nombre/razón social + fecha** en POST nuevo, permite referencia opcional generando identificador técnico sin PII; registros previos siguen editables. En Flutter «Referencia» solo se ve al editar anotación existente, sin exigirla al alta.
- **A02**: al resolver **No aceptó** y pasar un año, reponer borrador a `60,45,35` (si existía personalizado), incrementar revisión CAS y escribir evento auditado. No crea aviso entregado; políticas antiguas de candidates no significan envio.
- **A03**: endpoint de sugerencias propone Clientes `suggested_entry` exclusivamente desde anotación ya convertida a Cliente visible bajo permisos y la UI lo aplica solo tras selección explícita y solo al crear una anotación nueva; no modificar anotaciones existentes.
- **A04**: desplazar textos de O8c/O9a/editor/parte de la ficha a recursos ES/CA ARB; cobertura restante debe auditarse y testearse (sin presumir 100% traducción hasta inventario estático).
- **A05**: después de autenticar un workspace único, entrada por agenda HOY automáticamente; selección para multi-workspace permanece. Pantalla Dashboard sigue sirviendo de contenedor/selector.
- Tests nuevos/actualizados: Django serialización, resultados y sugerencias, Flutter editor/home y controles de idioma. **No se debe certificar que pasan hasta ejecutar suite completa**.

**Script de fase única:** `scripts/validate_whitepaper_alignment_phase.sh`. Comprobación de que las cinco áreas existen y luego el preflight completo existente `scripts/validate_o7_o8_preflight.sh`: SQLite suite, PostgreSQL17 efímero, Flutter analyze/tests/web build, salud antes/después, sin tocar la DB persistente `reminders.0015_renewal_reminder_drafts`.

**Siguiente paso:** actualizar checkout en Ubuntu a HEAD con `git fetch origin integration/local-e2e-prep && git merge --ff-only FETCH_HEAD`, comprobar `bash -n scripts/validate_whitepaper_alignment_phase.sh`, ejecutar `bash scripts/validate_whitepaper_alignment_phase.sh`, recopilar marcadores `ALINEACION_FASE_UNICA_PREFLIGHT=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`. Si falla, corregir GitHub y repetir test; NO desplegar a ciegas.

Con pruebas verdes, preparar **un solo deploy API+Web SIN MIGRACIONES** anclado al SHA probado, esquema persistente `0015`, O5 sana, imágenes previas etiquetadas, `migrate --check --noinput`, salud/HTTP/permisos. No reutilizar scripts fijados a O9a u O8c; NO crear 0016 ni activar notificaciones. Dejar test funcional de A01–A05 en DEV después del despliegue, con datos sintéticos.

## 25/10/2026 — FASE ÚNICA DE ALINEACIÓN DEL WHITEPAPER PREPARADA (SIN DEPLOY)

El usuario aprobó **resolver en una sola fase todas las discrepancias de funcionalidades desarrolladas** encontradas en la auditoría original: A-01 alta (solo 3 obligatorios, referencia opcional/autogenerada), A-02 «No aceptó» restablece 60/45/35 del borrador de la anotación sin envíos, A-03 «Conseguido» propone Clientes en NUEVA anotación al copiar datos desde póliza autorizada que es cliente, A-04 centralización ES/CA en ARB en O8b/O8c/O9a, detalle, desenlaces, alta y agendas; A-05 HOY como primera agenda si un workspace, o tras seleccionar cuando son múltiples. Se añadieron pruebas Django y Flutter; el backend sigue sin nueva migración, PG persistente `0015`, ninguna notificación ni envío activado. **LOS CAMBIOS NO ESTÁN VALIDADOS NI DESPLEGADOS**; no afirmar resultado verde.

Documento completo de alcance/evidencia: `docs/PHASE_WHITEPAPER_ALIGNMENT_2026-10-25.md`. Script orquestador único con fail-closed: `scripts/validate_and_deploy_whitepaper_alignment.sh`, que exige `scripts/check_whitepaper_alignment_static.sh`, `scripts/validate_o7_o8_preflight.sh` TODO VERDE SQLite+Postgres17 temporal+Flutter, y solo entonces `scripts/deploy_whitepaper_alignment_no_migrations.sh`. Nuevo despliegue pin a SHA de fuente probada `c4886728f3a9c53c592911d19096056bc56a0949`, respaldos O5 solo READ-ONLY, imagen API+Web anteriores recuperables, mismo DB ID y conteo de migraciones, solo recreación API+Web, sin modificar schema, CSRF/auth smoke.

**Próximo paso en Ubuntu (un bloque):** subshell `( cd /home/vencira/vencira-localcheck || exit 1; git fetch origin integration/local-e2e-prep || exit 1; git merge --ff-only FETCH_HEAD || exit 1; echo COMMIT=$(git rev-parse HEAD); bash -n scripts/validate_and_deploy_whitepaper_alignment.sh || exit 1; bash scripts/validate_and_deploy_whitepaper_alignment.sh ); echo RESULTADO_EJECUCION=$?; echo CONSOLA_ABIERTA`. Si falla en STATIC o PREFLIGHT, NO despliega. Si falla en DEPLOY tras cambios, **NO repetir a ciegas**; revisar `FASE_FALLIDA` y recibo. Solo resultado `WP_ALIGNMENT_PHASE_COMPLETE=OK`, `RESULTADO_ORQUESTACION=0`, `RESULTADO_EJECUCION=0` permite afirmar despliegue técnico. Después UAT datos ficticios: creación sin referencia, abre HOY, copiar Cliente, No aceptó con 60/45/35 y traducción CA. No seguir O9b hasta cerrar esta fase.


## 25/10/2026 — A01–A05 DESPLEGADAS EN DEV (evidencia recibida)

- Preflight íntegro verde en fuentes `ed85fdbb17f89bbb8623a5f8a8282c2f975a6642`: SQLite, PostgreSQL17 temporal, Flutter analyze/test/build, l10n, salud PRE/POST. `ALINEACION_FASE_UNICA_PREFLIGHT=OK`, `RESULTADO_GLOBAL=0`.
- Deploy API+Flutter Web ejecutado; `VERSION_WEB=3a4d38ef074d45db0df6c888ac69f22993c19400`; `WP_ALIGNMENT_DESPLIEGUE_SIN_MIGRACION=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`.
- API, db y web_preview `healthy`; HTTPS 200; endpoints anónimos O7/O8b/O8c/O9a/outcomes devuelven 403; `POSTGRES_0015_SIN_CAMBIOS=OK` según script; O5/Caddy/Restic timers sin cambios según recibo.
- Imágenes recuperables: `vencira-wp-pre-api:20261025T091112Z_2737080` y `vencira-wp-pre-web:20261025T091112Z_2737080`; recibo `/tmp/vencira-wp-20261025T091112Z_2737080.OgEh8tQ7.receipt`; log `/tmp/vencira-wp-alignment-deploy.dNjgO0UP.log`.
- **No confundir** despliegue saludable con UAT manual: falta comprobar alta, reset 60/45/35, sugerencia Cliente, ES/CA y entrada HOY en DEV con datos sintéticos. O9b todavía no implementada; próximo frente tras UAT: validador puro sin DB, conforme al contrato original.

## 25/10/2026 — O9b-1 implementada en GitHub, NO validada ni desplegada

- Validador puro `backend/reminders/control_responses.py`: pregunta exacta y tres opciones «Sí» del whitepaper; «No» con días positivos, día civil y fecha de repetición nunca posterior al límite de un mes civil. Resultado descriptivo `ControlResponsePlan`, siempre `notice_scheduled=False` / `notice_delivered=False`. Revisión manual bloquea validación. Sin lectura/escritura de modelos, sin API, sin motor de envío.
- Tests `backend/reminders/test_control_responses.py`: opciones, límite en febrero bisiesto, fechas y entradas inválidas.
- HEAD del lote al crear pruebas: `3fd78ba39350005a8e359c333d33eda859915d89`. **PENDIENTE ejecutar suite completa sobre Ubuntu**, no confundir commit con validación. No migración 0016 ni cambios en DEV; O9b-2 persistencia/auditoría es fase posterior.

## 25/10/2026 — O9b-1 gate verde y O9b-2 esquema candidato

- Usuario verificó suite integral O9b-1: `DJANGO_SQLITE_SUITE_COMPLETA=OK`, `DJANGO_POSTGRES17_SUITE_COMPLETA=OK`, `FLUTTER_ANALYZE_TEST_BUILD=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`. Sin despliegue ni migración persistente. Log `/tmp/vencira-o7-o8-preflight.5CxTjnTL.log`.
- O9b-2 **preparación en GitHub, NO aprobada ni aplicada**: modelo `RenewalControlResponse` y migración aditiva `0016_renewal_control_responses.py`. Guarda respuesta, subtipo sí, fecha repetición no, actor, instante, cutoff, revisión y clave idempotente; constraints de forma/revisión. **NO EXISTE TODAVÍA endpoint de escritura, cola ni notificación.**
- Próximo gate: ejecutar `scripts/validate_o7_o8_preflight.sh` en Ubuntu sobre la rama actual para detectar divergencia de esquema con `makemigrations --check --dry-run`, tests SQLite/PG17 y Flutter; revisar SQL de 0016 y compatibilidad con PostgreSQL; ensayo O4/O5 de restauración antes de aplicar al servidor; no desplegar API con `migrate --check` antes de migrar 0016 (se negaría a arrancar).

## 25/10/2026 — O9b-2 API manual preparada SIN desplegar

- Gate del modelo/migración 0016 superado por usuario: SQLite suite, PG17 temporal suite, Flutter tests/analyze/build, salud PRE/POST `OK`; `RESULTADO_GLOBAL=0` y ninguna migración persistente. Log `/tmp/vencira-o7-o8-preflight.AvxP3PZV.log`.
- Nueva API manual `GET/POST .../control-responses/` con tenant y responsable, autenticación, revisión CAS, bloqueo fila, idempotencia UUID, rechazo de anotación archivada/cerrada; aplica validador O9b-1 y guarda `RenewalControlResponse` (origen **manual**, no significa pregunta emitida ni notificación entregada, ni programa tarea). Tests nuevos en `test_control_response_api.py` para alta, repetición, conflictos, acceso y ausencia de entrega. HEAD código con tests `2084efd4fcd6daf598c667050472b40afbb3e22e`.
- **Importante**: la API recién creada NO ESTÁ PROBADA NI DESPLEGADA. Siguiente gate `bash scripts/validate_o7_o8_preflight.sh` sobre HEAD, y cualquier fallo corregirlo antes de tocar DEV. PostgreSQL DEV sigue en `0015`, no desplegar API antes de ensayo O4/O5 y migración controlada `0016`. No se activa cola, push, email ni notificación real. UI O9b-3 pendiente.

## 25/10/2026 — O9b-2 endpoint test gate verde (sin deploy)

- Usuario aportó resultado `LOCALCHECK_HEALTH_PRE/POST=OK`, `DJANGO_CHECK_MIGRACION_SECA=OK`, `DJANGO_SQLITE_SUITE_COMPLETA=OK`, `DJANGO_POSTGRES17_SUITE_COMPLETA=OK`, `FLUTTER_ANALYZE_TEST_BUILD=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0` del checkout actual. Log `/tmp/vencira-o7-o8-preflight.CwVWVoJA.log`.
- DEV sigue en 0015, la migración 0016 *no* ha sido aplicada; no desplegar API nueva mientras falte 0016 porque arranque exige `migrate --check --noinput`.
- Próximo paso seguro: pre-gate read-only de O5 y esquema 0015, revisar `sqlmigrate reminders 0016` sobre imagen aislada sin credenciales LIVE; verificar preparación del ensayo de recuperación O5 en PG efímero antes de aplicar 0016. La prueba integral previa no acredita restauración O5 previa a la nueva migración.

## 25/10/2026 — O9b ensayo aislado 0015→0016 preparado, sin ejecutar

- Usuario confirmó gate read-only `GATE_PREMIGRACION_LECTURA=OK`, `RESULTADO_EJECUCION=0`, rama `integration/local-e2e-prep`, HEAD local `d2e1214f4c32f98c6b833405b65134aa4f017c16`, O5 `AUDITORIA_FINAL_O5=OK`, snapshot reciente (<36h), DB original `healthy`, esquema original `0015_renewal_reminder_drafts`, 0016 presente.
- Script nuevo `scripts/o9b_restore_0016_rehearsal.sh` (commit `ad8dad1ff5cec519694cd6feb30e213cff6a7948`). Opera como root con O5 credentials de solo lectura, crea red Docker **interna** y PG17 temporal, obtiene último snapshot cifrado etiquetado, restaura 0015 vía tubería, ejecuta 0016 solo en clon usando imagen de backend aislada; confirma la tabla y que ID/conteo migraciones/schema de DB viva permanecen intactos; limpia contenedores/red. No despliega API, no migra DEV ni altera timers/OAuth/Caddy.
- **AÚN NO EJECUTADO NI PROBADO EN UBUNTU**. Próximo paso: sincronizar script, `bash -n` y ejecutarlo solo tras comprobar O5 disponible y ausencia de otros procesos backup. Si falla, no aplicar 0016; revisar log sin secretos. Mantener DEV en 0015 hasta ensayo exitoso y nueva copia cifrada pre-migración.

## 25/10/2026 — O9b: fallo real del ensayo de restauración (resuelto conceptualmente, pendiente ejecución)

- El script de ensayo `scripts/o9b_restore_0016_rehearsal.sh` ejecutado tras commit `ded0fbfc942ac1790c850fa33560c9050806f89d` restauró un snapshot válido de Restic, pero `CLONE_SCHEMA_RESTORED=0014_renewal_outcomes`; la base DEV sigue en `0015_renewal_reminder_drafts`. Resultado `ERROR=SNAPSHOT_NO_CONTIENE_0015`, `FASE_FALLIDA=RESTORE`, `RESULTADO_GLOBAL=6`, `RESULTADO_EJECUCION=6`, temporales eliminados, sin migrar base persistente. Log `/tmp/vencira-o9b-clone.1di21XYL.log`.
- **La disponibilidad/antigüedad (<36h) del snapshot O5 no demuestra que el dump contenga la versión actual del esquema**. El respaldo seleccionable puede seguir siendo `0014`. Próxima acción autorizada: ejecutar una **copia cifrada fresca de PostgreSQL DEV vía `scripts/o5_backup_to_drive.sh`** (root, con lock O5, pg_dump directo a Restic, sin dump claro en disco); solo después repetir el ensayo aislado en PG17, ahora con snapshot `0015`; comprobar `CLONE_SCHEMA_RESTORED=0015_renewal_reminder_drafts` y `MIGRACION_0016_SOLO_CLON=OK`, más `LIVE_0015_INTACTO=OK`.
- No ejecutar migración live `0016`, despliegue API, `restic init`, limpieza de snapshots ni restauración contra la DB viva antes de superar el nuevo ensayo. No confundir copia/ensayo exitoso con autorización para producción.

## 25/10/2026 — O9b restauración 0015 verificada, secreto efímero Django corregido

- Usuario ejecutó nueva copia cifrada: `RESTIC_INTEGRIDAD_METADATA=OK`, `GOOGLE_DRIVE_BACKUP_CIFRADO=OK`, `RESULTADO_GLOBAL=0`; ensayo restauró `CLONE_SCHEMA_RESTORED=0015_renewal_reminder_drafts`, `RESTIC_RESTORE_0015=OK`. **La copia correcta YA EXISTE; no repetir backup por este fallo.**
- Ensayo falló en `CLONE_MIGRATION` antes de aplicar 0016 porque variable `DJANGO_SECRET_KEY=o9b-temporary-only-2026` mide menos de los 32 caracteres requeridos por `backend/config/settings.py`. Trace `ImproperlyConfigured: Falta DJANGO_SECRET_KEY aleatoria (>=32 caracteres)`. `BASE_PERSISTENTE_NO_MIGRADA=1`, `CONTENEDORES_TEMPORALES_ELIMINADOS=1`, resultado 1; log privado `/tmp/vencira-o9b-clone.qcbsbTnP.log`.
- Script `scripts/o9b_restore_0016_rehearsal.sh` corregido en commit `c8f6fb57976a6224ef04521445f0b1e2661914a7`: secreto de ensayo suficientemente largo y restringido al clon; NO se cambian settings ni credenciales de DEV. Próxima ejecución: `git fetch`, fast-forward, `bash -n`, ejecutar **solo ensayo O9b**; no backup de nuevo ni migración real.

## 25/10/2026 — O9b ENSAYO DE RECUPERACION Y MIGRACION 0016 SUPERADO

- **Evidencia Ubuntu usuario:** `LIVE_0015_PRE=OK`, `RESTIC_SNAPSHOT_READABLE=OK`, `O9B_IMAGE_BUILT=OK`, `PG17_CLONE_ISOLATED=OK`, `CLONE_SCHEMA_RESTORED=0015_renewal_reminder_drafts`, `RESTIC_RESTORE_0015=OK`, `MIGRACION_0016_SOLO_CLON=OK`, `LIVE_0015_INTACTO=OK`, `O9B_RESTAURACION_Y_MIGRACION_AISLADA=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`, clon y red temporal eliminados. Log `/tmp/vencira-o9b-clone.MeRXR08L.log`.
- **PostgreSQL DEV sigue en 0015**: ninguna migración aplicada al servidor, nueva API O9b todavía no desplegada. O5 con snapshot actualizado de 0015 y ensayo real de restauración exitoso.
- Siguiente fase: despliegue controlado y explícito de 0016 tras nueva copia O5, preservar imagen API previa, comprobar API `migrate --check`, controles de autenticación, ID DB invariable y sin cambios en Caddy/timers. No marcar como desplegado antes de evidencia real.

## 25/10/2026 — O9b deployment gate scripted, pending actual deployment

- Restore drill **successful** from encrypted Restic O5 snapshot at schema 0015, then migration 0016 applied on disposable PostgreSQL17 clone, original untouched. Evidence: `RESTIC_RESTORE_0015=OK`, `MIGRACION_0016_SOLO_CLON=OK`, `LIVE_0015_INTACTO=OK`, `RESULTADO_GLOBAL=0`; log `/tmp/vencira-o9b-clone.MeRXR08L.log`.
- New script `scripts/deploy_o9b_0016_guarded.sh` commit `11c004a7f8d9ca8cc2d41c1863d2c4e17a31f8f2` prepares gated DEV-only deployment: pinned proven backend/client SHA `d2e1214f4c32f98c6b833405b65134aa4f017c16`, O5 freshness, image rollback tag, build and migration plan, new encrypted O5 backup before explicit 0016, no auto migrations, API-only recreation and anonymous access check. Does not redeploy Flutter web nor touch DB container, Caddy, OAuth or timers. **Not yet executed**. If it fails after 0016 applied, do not rerun or roll DB back automatically; inspect schema and receipt.

## 25/10/2026 — O9b 0016 + API DESPLEGADOS EN DEV (evidencia usuario)

- Usuario ejecutó `scripts/deploy_o9b_0016_guarded.sh`, HEAD `d7b3bfed5749c8cfe23deed1c6d65f907236d072`. Resultado `FUENTES_IDENTICAS_PREFLIGHT=OK`, `MIGRATE_CHECK_ONLY=OK`, `POSTGRES_0015_PRE=OK`, `O5_BACKUP_VERIFICADO=OK`, `TAG_PREVIOUS_API=OK`, `BUILD_NEW_API=OK`, `MIGRATION_PLAN=OK`, `BACKUP_O5_PRE0016_FRESCO=OK`, `APPLY_0016=OK`, `POSTGRES_0016_VERIFICADO=OK`, `POST_MIGRATE_CHECK=OK`, `DEPLOY_API=OK`, `HEALTH_api=healthy`, `CONTROL_RESPONSES_ANON_HTTP=403`, `POSTGRES_INTACTO_ID=OK`, `O9B_0016_API_DESPLIEGUE=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`.
- **DEV PostgreSQL ya está en esquema `reminders.0016_renewal_control_responses`. NO REPETIR MIGRACIÓN NI SCRIPT DE DESPLIEGUE.** DB mismo contenedor, no reiniciado; API O9b desplegada, web sin recrear; sin cambios Caddy/OAuth/timers; copia O5 cifrada pre-0016 realizada.
- Imagen anterior preservada: `vencira-o9b-pre-api:20261025T100520Z_2775766`. Recibo privado local `/tmp/vencira-o9b-deploy.LrQlvrgc.receipt`. No registrar credenciales ni contenido de backup en GitHub.
- **Aún pendiente aceptación manual autenticada** de endpoint `GET/POST .../control-responses/` con anotación ficticia y futuro cut-off. El HTTP 403 sin sesión prueba protección, no funcionalidad end-to-end. No hay notificaciones reales activas.
- **Siguiente fase O9b-3**: Flutter API/client UI ES/CA para registrar respuesta manual y mostrar historial con distinción de aviso real; no presentar `control_assessment` preview como evento entregado. Revisar contrato e invalidar UI de anotaciones cerradas, revisar tests Flutter; preflight separado y solo entonces despliegue sin migraciones. Mantener aislamiento multi-tenant y auditoría.

## 25/10/2026 — O9b-3 UI Flutter creada en GitHub; AÚN SIN PREFLIGHT NI DESPLIEGUE

- Archivos: `clients/flutter/lib/api/vencira_api.dart` (contrato typed `fetchControlResponses`/`saveControlResponse`, GET/POST autenticado, JSON estricto, CSRF, control conflictos); `clients/flutter/lib/ui/control_response_card.dart` (pregunta Sí/No manual, 3 motivos Sí, intervalo No libre en días, historial e información explícita no-entrega/no-agenda); integración en `renewal_detail_screen.dart` dentro de sección desplegable; nuevos textos ES/CA `app_es.arb`, `app_ca.arb`.
- Último commit funcional `f04199296b761c6b7c04090b0e7b51eebba8fcd6`. **Todavía NO probado en Ubuntu, NO desplegado**. Se debe ejecutar `scripts/validate_o7_o8_preflight.sh` antes de preparar una operación web sin migraciones. DB DEV está en 0016. Evitar reejecutar `deploy_o9b_0016_guarded.sh` o migrate.
- Límite intencionado: `NO` solo persiste una fecha deseada/repetición en historial; **no genera agenda/tarea ni mensaje real**. UI indica explícitamente este alcance y no representa `O9a assessment` como entrega. Pendientes: UAT web autenticada con datos sintéticos y validación ES/CA responsive.

## 25/10/2026 — O9b-3 preflight Flutter analyze corregido (pendiente nueva prueba)

- Usuario corrió `scripts/validate_o7_o8_preflight.sh`: Django SQLite 172 tests OK; Django PostgreSQL17 172 tests OK; Flutter analyze FAIL por cinco avisos de API obsoleta en `clients/flutter/lib/ui/control_response_card.dart` (2 `RadioListTile.groupValue`, 2 `RadioListTile.onChanged`, 1 `DropdownButtonFormField.value`). Preflight `RESULTADO_GLOBAL=1`, `RESULTADO_EJECUCION=1`; sin despliegue ni migración, O5/Caddy/OAuth intactos; log `/tmp/vencira-o7-o8-preflight.1tFHB4JA.log`. Warning SQLite `unable to open database file` en chequeo migración seca no impidió las suites; revisar si se repite, no confundir con gate Flutter.
- Código corregido en GitHub commit `80478f73d71cbffc63dd70f318245739e570e9c0`: usar `RadioGroup<String>` y `DropdownButtonFormField.initialValue`; no cambia backend ni esquema 0016. **PENDIENTE VALIDAR nuevo checkout** con el preflight completo antes de desplegar web. Mantener DEV en 0016, no ejecutar migraciones.

## 25/10/2026 — O9b-3 Flutter PREFLIGHT superado; despliegue web guardado preparado

- Usuario confirmó `LOCALCHECK_HEALTH_PRE=OK`, `CONFIG_COMPOSE=OK`, `I18N_ES_CA=OK`, `BUILD_BACKEND_AISLADO=OK`, `DJANGO_CHECK_MIGRACION_SECA=OK`, `DJANGO_SQLITE_SUITE_COMPLETA=OK`, `PG17_TEMPORAL=OK`, `DJANGO_POSTGRES17_SUITE_COMPLETA=OK`, `FLUTTER_ANALYZE_TEST_BUILD=OK`, `LOCALCHECK_HEALTH_POST=OK`, `O7_O8_PREFLIGHT_SIN_DESPLIEGUE=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`, sin tocar DB ni servicios. Log `/tmp/vencira-o7-o8-preflight.kvsq5rZc.log`. Código UI validado en commit `3d42c045aa7c01ee394d732708b25ee4154a5877`.
- Nuevo `scripts/deploy_o9b3_web_guarded.sh` en commit `7c7652c3fb826a2529d3c5938a72f3d2bdbfdb0e`: solo web Flutter, conserva imagen web anterior, verifica que clientes Flutter no cambien respecto a commit probado, backend/compose/deploy no cambien respecto al API desplegado, health API/DB/web, esquema 0016, sin migraciones ni reinicios API/DB/Caddy; después de recrear solo web verifica salud y acceso anónimo 401/403 a ruta de control. **PENDIENTE EJECUCIÓN POR USUARIO EN UBUNTU; no marcar web publicada antes.**
- Después del despliegue pendiente: UAT visual con sesión autenticada, anotaciones de ejemplo y respuesta manual. Backend autentica; prueba 403 no demuestra POST real.

## 25/10/2026 — O9b-3 FLUTTER WEB DEV DESPLEGADO, UAT móvil

- Usuario ejecutó `scripts/deploy_o9b3_web_guarded.sh`, HEAD `ae7a46ad7ebb2a71ab006d1e68f86590ab10008d`: `FUENTES_WEB_PREFLIGHT_IDENTICAS=OK`, `POSTGRES_0016_PRE=OK`, `TAG_PREVIOUS_WEB=OK`, `BUILD_WEB=OK`, `WEB_DEPLOY=OK`, `HEALTH_web_preview=healthy`, `CONTROL_RESPONSES_ANON_HTTP=403`, `POSTGRES_0016_INTACTO=OK`, `API_DB_IDENTIDAD_POST_DEPLOY=OK`, `O9B3_WEB_DEV_DESPLIEGUE=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`, sin migraciones ni reinicio API/DB; Caddy/OAuth/timers intactos. Imagen anterior `vencira-o9b3-pre-web:20261025T102723Z_2792918`.
- Capturas reales Android de `https://dev.vencira.es/` muestran pregunta manual, opciones Sí/No y tres opciones Sí, historial con «Sí · Avisada por el cliente» a las 11:35 del 25/10/2026. Evidencia de flujo manual Sí guardado y mostrado (no prueba automáticamente respuestas de No ni notificación real).
- Defecto visual: en No aparece doble etiqueta «Avísame dentro de (días)» encima y dentro del campo. Corregido en GitHub commit `96bde67999eb0cfaca71d1204d73e216d9b7fe4a` eliminando etiqueta externa. **Esta corrección posterior todavía NO ha pasado preflight ni está desplegada; no repetir despliegue hasta validación.**
- Próximas tareas: validar opción No guardando con datos ficticios y revisar límites/corrección de errores; preflight de corrección Flutter, y despliegue web-only posterior con imagen rollback conservada.

## 25/10/2026 — O9b-3 preflight OK, web deploy de retoque visual bloqueado antes de recreación

- Usuario confirmó `scripts/validate_o7_o8_preflight.sh` resultado 0 log `/tmp/vencira-o7-o8-preflight.dhr1EL7b.log` tras corrección visual `96bde679`.
- Intento de `scripts/deploy_o9b3_web_guarded.sh` falló `FASE_FALLIDA=PRECONDITIONS`, `WEB_PUDO_HABERSE_RECREADO=0`, `RESULTADO_GLOBAL=1`, sin migraciones ni reinicio API/DB. Causa muy probable: gate comparaba `clients/flutter` con commit previo `3d42c045` y rechazaba el nuevo cambio visual.
- Script corregido en commit `b9d490fddadee5527cc42d67c131107f44ccc263` para fijar fuentes Flutter a `96bde67999eb0cfaca71d1204d73e216d9b7fe4a` (validado). Reintentar solo despliegue web después de `git fetch/merge`, `bash -n`; no hace falta repetir preflight ni migración. Si vuelve a fallar, no repetir sin diagnóstico. UI DEV previa sigue activa con etiqueta duplicada hasta éxito del nuevo despliegue.

## 25/10/2026 — O9b-3 CORRECCIÓN WEB DEV DESPLEGADA Y PRUEBA NO VALIDADA

- Usuario presentó captura Android y consola de despliegue web corregido: `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`, `SIN_MIGRACIONES=1`, `SIN_REINICIO_API_DB=1`, `SIN_CAMBIOS_CADDY_OAUTH_TIMERS=1`. La UI ahora muestra una sola etiqueta «Avísame dentro de (días)».
- UAT web autenticada con datos ficticios: **NO** registrado el 25/10/2026 a las 11:56 con revisión solicitada para 26/10/2026 en historial. Anteriormente **SÍ · Avisada por el cliente** registrado y visible en historial. Confirmados flujos manuales Sí/No. No constituye notificación entregada ni programación de tarea: no activar notificaciones sin fase específica.
- Estado O9b-3: desplegada y aceptada en DEV por evidencia del usuario. Persistencia PostgreSQL en 0016; no ejecutar migración ni repetir despliegue O9b. Pendiente funcional real: automatización futura separada de preguntas y recordatorios conforme whitepaper; no confundir respuesta manual con ejecución automática.

## 25/10/2026 — PLAN DE MACROBLOQUES WHITEPAPER V1 APROBADO COMO PREPARACIÓN

- Usuario solicita acelerar desarrollo agrupando fases. Se revisó fuente whitepaper transcrita (23 pp.) y se creó `docs/PLAN_ACELERADO_WHITEPAPER_V1_2026-10-25.md` commit `4424da376137aee170ca73ee6f0009f7ee4b32b3`. Cinco macrobloques: **A** motor operativo de avisos/agenda/control y respuestas No generando aviso real sin enviar; **B** notificaciones reales + móvil offline; **C** ficha/archivos/Excel/productividad; **D** cuentas Equipo/seguridad/conservación/compliance; **E** cobro/empaquetado/lanzamiento. Solo gate integrado por macrobloque, sin micro-solicitudes al usuario, manteniendo snapshot O5/clone PG17/migraciones explícitas, NO envío ni borrado sin permiso/gate.
- Corregida discrepancia crucial: whitepaper §8 establece No→crear recordatorio efectivo «Comunicar no renovación de [nombre]» y repetir pregunta; lo actual O9b-3 solo registra intención, no cumple automatismo. El primer macrobloque A cierra esa brecha e implementa 60/45/35, motivos, estados y reprogramación. Whitepaper 14 decisiones promotor + 6 técnicas deben mantenerse visibles, no suponer aprobadas; nombre VENCIRA seleccionado fuera whitepaper. Próximo trabajo: desarrollar A integrado, no desplegar DEV hasta gate.

## 25/10/2026 — Macrobloque A iniciado con motor civil puro y pruebas (NO DESPLEGADO)

- Usuario autorizó seguir. Implementados `backend/reminders/operational_schedule.py` commit `2676096ec2248a0e47fdc3bf1b398c4b368e62d1` y `backend/reminders/test_operational_schedule.py` commit `6599a30df7c803a980d780cdc6f8834a8bcd42cb`: calendario 60/45/35; último aviso estrictamente anterior a corte civil, febrero y bisiesto, aviso tardío, falta de aviso válido, Vida exige revisión, fecha de repetición No acotada, validación datos. **No crea tareas, no migra, no envía ni cambia API/UI desplegada**.
- Pendiente dentro del mismo macrobloque A (no se solicitará despliegue intermedio): modelo de ocurrencias y motivos, migración 0017+ en PR, API de habilitar configuración, CAS/outbox sin envío, integración Sí/No que realmente genera repetición, vista agenda pendiente, Flutter UI/ES/CA, tests de concurrencia, plan O5+ensayo de migración clon PG17 y gate único para A. DEV permanece en PG 0016. Las pruebas nuevas aún no han sido ejecutadas en Ubuntu. No presentar A como completo.

## 25/10/2026 — Macrobloque A, modelos y esquema 0017 preparados, NO MIGRADOS

- Usuario pidió continuar con macrobloque A. Añadidos en `backend/reminders/models.py` los modelos `OperationalReminder` (ocurrencias internas; planned/pending/snoozed/completed/cancelled, source_key+generation, reason, control_question, referencia opcional a respuesta manual) y `OperationalReminderEvent` (auditoría append-only lógica e idempotencia), commit `11684f1fa1609f0b65561fad75af2d4ad3c37ca1`.
- Añadida migración aditiva `backend/reminders/migrations/0017_operational_reminders.py` commit `4a0dcfd6c6c2d210d98775d2159fa42443783e46`. **PENDIENTE probar `makemigrations --check`, ejecutar tests SQLite/PG17, planificar y ensayar clon restic 0016->0017**; no instalar en DEV aún, que sigue en 0016. No hay tareas ni envíos ni activación.
- Se intentó añadir módulo de conciliación pero la operación GitHub fue bloqueada por herramienta; **no asumir archivo creado**. Pendiente completar conciliación transaccional, vínculos de respuestas No, API, Flutter/ES-CA, tests, preflight y un único gate agregado. No presentar macrobloque A como completo.

## 25/10/2026 — Macrobloque A: conciliación interna y vínculo No añadidos en GitHub, NO integrados en endpoints

- `backend/reminders/operational_reconcile.py` commit `a3586b70c456fc6160cfbccaf71110a7848bee58`: servicio explícito de reconciliación transaccional para avisos de vencimiento. Serializa por renovación, crea ocurrencias internas idempotentes, evita reabrir completados, cancela planes obsoletos tras cambio de vencimiento/cierre y mantiene eventos auditables. **No hay ejecución automática ni despacho**.
- `backend/reminders/test_operational_reconcile.py` commit `29139fd9ac2867b25a399f9b2674a7ebed94bf31`, ampliado en `ee7d088b213099b37a14d8f5ea67ffb36797d9c5`: pruebas propuestas de planificación 60/45/35, idempotencia, cambios de vencimiento, cierre, Vida, excepción tardía, respuesta No/Si. Todavía NO ejecutadas en Ubuntu.
- `backend/reminders/control_repeat_schedule.py` commit `553ac2caa8c13b5fdaa94070f6ba54e335d50bbc`: crea ocurrencia de repetición de control vinculada a respuesta No con clave estable, sin notificar ni garantizar entrega. **Deliberadamente no conectada todavía a POST de `control_responses`**; el endpoint manual vigente mantiene su contrato `notice_scheduled=false` hasta completar motor A, agenda y API/Flutter en una misma entrega.
- **No lanzar scripts ni migrar DEV ahora**. DEV sigue en 0016; modelo y migración 0017 todavía sin preflight ni migración en clon. Continuar la integración de A (transiciones de estado con CAS/idempotencia, motivos/cuentas, agenda, endpoints, Flutter/ES-CA, validaciones de concurrencia), un gate completo cuando listo. Reconciliación debe preservarse sin activarla desde GET/cron/startup.

## 25/10/2026 — Macrobloque A: transiciones internas CAS añadidas, SIN integración API

- Creado `backend/reminders/operational_transitions.py` commit `e34444d5c9a41d96a2c1dbd271e5b3cdcc23888a`: transición explícita `complete`, `tomorrow`, `another_day`, `select_for_update` de anotación+recordatorio, idempotency UUID, CAS por estado/fecha, bloqueo de aplazamientos de control posteriores al corte civil. No hay activación ni envío automático. **El servicio no verifica permisos; API posterior debe filtrar por workspace, rol y renovación visible** antes de invocarlo.
- Creado `backend/reminders/test_operational_transitions.py` commit `c2b380295013df103c3273145c3c0b2df933db80`: pruebas previstas de completar dos veces, mañana, conflicto CAS, límite de control, tipos de acción. **Pendiente ejecutar en local y PG17 temporal**.
- Se mantienen DEUDA y bloqueos de integración del macrobloque A: implementar API protegida, motivos configurables, activación segura e integración del `No` en transacción, corrección de semántica de idempotencia en reintento con payload discrepante, agenda y Flutter, ES/CA. Antes de aprobar para DEV se revisarán fallos de reconciliación a fecha futura/repeticiones, migración 0017 en clon y check `makemigrations --check`.

## 25/10/2026 — Macrobloque A: API inicial de lectura operacional (AÚN NO PROBADA NI DESPLEGADA)

- Nuevo `backend/reminders/operational_api.py` commit `67dcfd3d5e6b100b3955cfc05f99772b344416b4`: GET autenticado y tenant/assigned scoped para ocurrencias internas; campo inequívoco `delivery_status=not_implemented` y `Cache-Control: no-store`. POST no admitido.
- Registro ruta `/api/v1/workspaces/<workspace_id>/renewals/<renewal_id>/operational-reminders/` en `backend/reminders/urls.py`, commit `59aa6a305dc13f9b3121ef1503ad88af2604949c`.
- Pruebas API de aislamiento de cuenta, denegación de escrituras, lectura autenticada y consultas inválidas `backend/reminders/test_operational_api.py`, commit `b950d3794f3e6d3604fc12fa54fb8d184ea06cf0`. No ejecutadas aún: seguir sin despliegue hasta gate agregado.
- Pendiente: endpoint mutaciones con permisos + sincronización atómica respuesta No→aviso interno, estados, reconciliación y agenda visual, listas motivos, localizaciones, Flutter. Migración DEV permanece en 0016.

## 25/10/2026 — Macrobloque A: endpoint POST de acciones CAS, pendiente validación local

- `backend/reminders/operational_transitions.py` endurecido para comparar fecha de destino en reintentos e impedir reutilización de clave con un aplazamiento diferente: commit `58acb617ed6e93cd0ee3564837720f05f7ab8e9e`.
- `backend/reminders/operational_api.py`: endpoint POST aislado por workspace y anotación visible para completar/aplazar una ocurrencia interna; JSON exacto (`action`, `expected_state`, `expected_day`, `idempotency_key`, `days_later`), conflictos CAS 409 y sin mensajes reales; commit `46188095e9349454fd301648b10558acf0cebee8`.
- Ruta `.../operational-reminders/<uuid:reminder_id>/action/` en `urls.py`, commit `27d887357dd89e1058e06ab7574c78330ee11f9f`. Tests de permisos cross-tenant, reintento, conflicto y contrato inválido añadidos a `test_operational_api.py`, commit `a4c68935f4dbd7dda50d6e15d41cdff5d020b647`.
- **Todo NO PROBADO aún en Ubuntu/PG17**; DEV sigue 0016 y no debe desplegarse. Pendientes motor A: contrato `No` de respuesta → recordatorio en misma transacción, activación reconciliación controlada, motivos, agenda Flutter, pruebas end-to-end, seguridad y gate migración 0017 con O5 y clon. Revisar semántica de reintentos `tomorrow/another_day` al cruzar día local antes de declarar listo.

## 25/10/2026 — Macrobloque A: agenda diaria/mensual incorpora ocurrencias internas (SIN DESPLIEGUE)

- `backend/reminders/views.py` commit `d879326dc5e671a3237d36733a080ad12829e857`: agenda diaria incluye las anotaciones con avisos operativos internos `planned/pending/snoozed` en la fecha consultada, campo `kind=operational_reminder` y `delivery_status=not_implemented`. Mantiene `_visible_renewals`, filtros, paginación y eventos anteriores.
- `backend/reminders/agenda_month.py` commits `7a1fe130` y corrección `5a389964d6abf471696a51f08f53d875fce3bd27`: incorpora ocurrencias operativas al contador `reminder` sin alterar contrato de Flutter existente; unión exacta por renovación/día entre candidatos previos y operativos para no duplicar contadores.
- Tests `backend/reminders/test_operational_agenda.py` commit `3fa756812e478413cde2e4c5046530ada8e948d8`: agenda diaria y mes, exclusión de completados. **AÚN NO EJECUTADOS**.
- Precaución: esto muestra recordatorios cuando YA existen en DB, pero **respuesta No todavía NO conectada a escritura atómica de ocurrencia** y no hay motor automático de ejecución. Flutter puede mostrar contador de día pero debe disponer de acción/representación del evento `operational_reminder`; revisar parser Dart antes de integración final. Aún faltan motivos configurables, integración del control y reconciliación desde operación autorizada, pruebas integrales, ensayo migración 0017 y gate. DEV sigue en 0016.

## 25/10/2026 — Macrobloque A, puente No y agenda

- `control_response_api.py` commit `edd85d74c46c056770777a00f883d74db53e11ab`: al crear respuesta No, planifica ocurrencia interna con `plan_control_repeat` en misma transacción. El indicador `notice_scheduled` ahora depende de si hay ocurrencia guardada; `notice_delivered` sigue false. No hay envío.
- `views.py` commit `d879326` y `agenda_month.py` commit `5a389964`: calendario incorpora avisos internos, el mensual deduplica por renovación/día. Tests añadidos `test_operational_agenda.py`.
- `vencira_api.dart` commit `04e326db5a65a5e06d5cd85899e6e896911feb9b` acepta bool de `notice_scheduled`; aún debe revisarse toda la representación móvil y cambiar textos ES/CA que actualmente afirman que No nunca programa. Las escrituras de traducción fueron rechazadas por la herramienta. No desplegar hasta corregirlo.
- **PENDIENTE DE COMPROBACIONES**: validar doble transacción, reintentos y semántica de indicadores históricos, Flutter lint/test, contrato fechas, seguridad, migración 0017 en clon. DEV sigue 0016. No activar correo/push.

## 25/10/2026 — Macrobloque A: copy ES/CA y orden de bloqueo en repetición No

- Actualizados textos `controlResponseManualWarning` para ES en commit `b0ff1ecd0ed12ee2e36af4743655872903d3e0a2` y CA en `05be7465946328926dd22ef4ced5a8e51df58d67`: indican que responder No crea una revisión **interna** y que no hay notificación ni comunicación acreditada.
- `control_repeat_schedule.py` commit `bfa001ebbe1f98621d1b640d13c4a15421bafd6a`: bloqueo consistente por renovación antes de leer registro de respuesta. Pendiente prueba de concurrencia.
- `control_response_api.py` sigue vinculado en misma transacción al aviso interno tras No y responde `notice_scheduled=true` cuando la ocurrencia existe; Flutter parser ahora admite bool. **No se ha probado localmente**: comprobar regresiones existentes, migración 0017, i18n, dinámica de UI y reintentos; no desplegar DEV 0016 todavía.

## 25/10/2026 — Macrobloque A: activación explícita de borrador → avisos internos

- Corregida reconciliación en `backend/reminders/operational_reconcile.py` commit `cf26ac40796f0620f4a77c803788b9beeba7db36`: cancela ocurrencias activas sustituidas por una nueva generación, no solo claves eliminadas.
- Nuevo `backend/reminders/reminder_activate.py` commit `d2cc94cf019374664ae915f10ded1107cc9a4840` y ruta `POST /api/v1/workspaces/<ws>/renewals/<renewal>/reminder-activate/` commit `e8ed7f4e9094b7403e0003f53639ef6d1273cd82`: el usuario autorizado activa deliberadamente la programación **interna** del borrador existente, CAS `expected_revision`, transacción y conciliación, rechazo de cuenta ajena/archivadas/fechas excepcionales; no activa canales, cron ni entrega. NO modifica `RenewalReminderDraft.state=draft` pues es configuración editable; respuesta `state=internally_planned`.
- Pruebas `backend/reminders/test_reminder_activate.py` commits `7eb7c1e1b4c383567f4b611f456ff4b6bc713494`, `4c65d008f15799312cebd50b6fabed994fc06705`: borrador exigido, tenant, CAS, formato, idempotencia y 60/45/35 con reloj congelado. **PENDIENTES ejecutar**.
- Riesgos pendientes: motivos aún fijos, no hay botón Flutter de activación ni UI de acciones operativas; faltan pruebas integrales SQLite/PG17 temporal, chequear django makemigrations --check; migración 0017 no aplicada. **No desplegar DEV** (0016).

## 25/10/2026 — Macro A: motivos por aviso, esquema preparado NO integrado

- Campo `RenewalReminderDraft.reasons_by_day` JSON diccionario opcional añadido a modelos en commit `9147845db3862b2faf2c7c68e8fd94046ab23864`.
- Migración aditiva `0018_draft_reasons.py` dependiente de `0017_operational_reminders` creada en commit `bdf847aad9a6790a511aa0c795719cdc69efab7c`. **No ejecutar en DEV**: sigue en `0016` y 0017/0018 requieren gates O5 y ensayo en clon.
- Integración pendiente: validar motivos en API PUT/GET de borrador, pasar mapa a reconciliador de avisos y persistir en ocurrencia, tests con valores por defecto y permisos, Flutter ES/CA y circuito de activación. Intentos de modificar esos archivos bloqueados por herramienta; no declarar funcionalidad completada.

## 25/10/2026 — Macro A: motivos configurables backend conectados (NO PROBADOS)

- `reminder_draft.py` commit `b62f66f54c4da9f3ea0ca66ad98d628d4a29119e`: GET devuelve `reasons_by_day`; PUT opcional acepta mapa `{offset_en_dias: motivo}` validado (máximo 12, 1–160 caracteres y offsets presentes). Contrato anterior PUT sin este campo sigue admitido y conserva motivos válidos para días no eliminados. Versionado CAS cuando cambia motivo, sin activar envíos.
- `operational_reconcile.py` commit `f1331ba450e9cb099d992a1209575d95a0747131`: recibe `reasons_by_day`, crea las ocurrencias con el motivo personalizado, y reemplaza generación si este cambia. `reminder_activate.py` commit `51092a62a65099000c3ab89e83d5285d5481d5e6` transmite motivos del borrador al conciliador.
- Pruebas añadidas a `test_reminder_activate.py` (`827dbefe72d9e62a1c58720193ab0e2cb747671c`) y `test_reminder_draft.py` (`7b25d3a5a8de8b40300acca128e7b2acd0090298`) para flujo de motivo y validación. **NO EJECUTADAS**.
- Sigue pendiente Flutter (edición de motivos, activación, acciones); revisar historial de reconciliación ante transcurso del tiempo, repetición de acciones después de medianoche, y realizar gate SQLite/PG17 migraciones 0017/0018. NO modificar DEV (0016) hasta gates.

## 25/10/2026 — Macrobloque A: Flutter operacional integrado en pantalla, pendiente gate

- `clients/flutter/lib/api/vencira_api.dart` commits `b9eebe1b9af35ec92e1237d5856f521b4b026aa4`, `804147722e4e12b40d409f947588770299d4ddd9`: borrador Flutter admite `reasons_by_day`; métodos/DTO de activación explícita, listado de ocurrencias y cambios de estado con CSRF y control de conflictos.
- `clients/flutter/lib/ui/operational_panel.dart` commit `0ff73c20046e41e787dbce256d5cf712da4cb54d`, mejorado `3840885cb826e7c8f56c4231e4bbf88d70c08036`: panel editable por día, guardar motivos, activar programación interna, visualizar avisos, marcar completado, aplazar mañana o seleccionar fecha civil. El backend impide pasar del corte civil al aplazar controles. **Textos nuevos del panel solo castellano, deben localizarse ES/CA antes de gate.**
- `clients/flutter/lib/ui/renewal_detail_screen.dart` commit `a94671a95e087e1f8facd3f69662f617e26def84`: integra panel en detalle de anotación junto a controles anteriores.
- `backend/reminders/control_repeat_schedule.py` commit `ceb97cfcabbdeac2b529142e404b8dbbfb636628`: un reintento del mismo No posterior a fecha de aviso recupera el original en lugar de rechazar la petición; comprueba identidad. Test `test_operational_reconcile.py` commit `61d72344a83750f2530a228366cd231d01f306bd`.
- **Importante**: código NO probado ni desplegado. Resta comprobar `dart analyze/test/build`, migraciones 0017/0018, Django SQLite/PG17, seguridad de accionamientos, migración sin divergencia, textos CA/ES, alertas retrasadas, reprogramación tras pasar de día y exactitud de UI. No afirmar macrobloque listo para DEV. DEV sigue 0016.

## 25/10/2026 — Macro A: localización y revisión casos límite (sin gate)

- ES/CA `controlResponseDaysHint` ya describe revisión interna (commits `80b6c614`, `1a228b42`).
- Claves `op*` ES/CA incorporadas al ARB y usadas por `operational_panel.dart` en commits `e3e93ea3`, `1ebe0087`, `6262c883`. **Flutter intl generator no ejecutado; análisis compilación pendiente.**
- `operational_reconcile.py` commit `20067256e41c04504dcf5f9c441041a94fdff3d3` conserva ocurrencias existentes vencidas que ya estaban planeadas al reactivar, evitando su eliminación silenciosa; **pendiente revisión y test de fechas transcurridas**: `build_renewal_plan` puede lanzar `late_control` antes de recuperación, revisar este punto antes de gate.
- No hay pruebas locales, migraciones 0017/0018 no aplicadas, DEV sigue 0016. Para cerrar macro A todavía: test end-to-end SQLite/PG17, Flutter analyze/test/build y corrección de problemas detectados; no declarar listo/desplegar.

## 25/10/2026 — Macrobloque A: replay de aplazamiento y pruebas de fecha civil

- `backend/reminders/operational_transitions.py` commit `8a92ef4a2a549a3fe54fc1110832772d72e46be4`: la comprobación de un reintento idempotente usa el **día local original del evento** (`occurred_at`) y no el día actual, con lo que el mismo `idempotency_key` sigue siendo aceptable tras medianoche. Se protege overflow de fecha en aplazamientos. No hay entrega ni canales.
- `backend/reminders/test_operational_transitions.py` commit `c08d3055079ccbfc5f472fddf5b2785ab2d29519`: pruebas previstas para reintentar mañana al día siguiente y rechazar reutilización de clave con otra duración. `test_operational_reconcile.py` commit `3302f22004a24c379217ca2a03e2bd4dd57fe888`: comparación de identidades estable sin presuponer orden al mezclar avisos futuros y vencidos.
- **NO EJECUTADO**: falta `makemigrations --check --dry-run`, pruebas Django, PG17 de prueba, Flutter gen-l10n/analyze/test/build, control de colisiones de fecha y gate O5. Aún no modificar DEV (migración 0016). Cerrar solo cuando se verifiquen los resultados.

## 25/10/2026 — Gate integral macro A preparado (SIN EJECUTAR)

- Nuevo `scripts/validate_macro_a_readonly.sh` commit `5ceae2485d0f8dcef930ae8d46ca39e9d99f29a2`; valida identidad de checkout, rama, limpieza, fuentes de 0017/0018 y pruebas macro A, y reutiliza `scripts/validate_o7_o8_preflight.sh` para Django makemigrations --check --dry-run, test SQLite y PG17 efímero, Flutter analyze/test/build, l10n y salud localcheck. El preflight sí crea recursos Docker efímeros de prueba y compila imágenes; no despliega ni migra DB persistente. Debe ejecutarlo el usuario en Ubuntu tras `git pull --ff-only`, sin pegar secretos. No implica éxito hasta ver `RESULTADO_GLOBAL=0` y `MACRO_A_PREFLIGHT_COMPLETO=OK`.
- Macrobloque A continúa NO VALIDADO. DEV PostgreSQL 0016 intacto. No aplicar migraciones 0017/0018 ni desplegar antes de gates de respaldo O5.

## Gate macro A: primera ejecución 216 tests, 3 failures y 2 errors (25/10/2026)

- Usuario ejecutó `scripts/validate_macro_a_readonly.sh`; Django SQLite llegó a 216 tests y falló antes de PG17/Flutter; `RESULTADO_GLOBAL=1`, sin despliegue ni migración persistente.
- Dos errors: los tests parchean `reminders.control_repeat_schedule.timezone.localdate` pero timezone se importaba dentro de función. Arreglado import global `backend/reminders/control_repeat_schedule.py` commit `7bc0009364573daf411243fee4d9dee7afd1d1cc`.
- Un failure: agenda diaria anotaba `agenda_has_operational` pero omitía agregar evento en `events`. Arreglado `backend/reminders/views.py` commit `a93a1abe132aa3889668c175822564fc906bc34b`.
- Dos failures por test incorrecto: (30,15) días para 15/03/2027 contiene 13/02/2027 (antes corte 15/02); se cambió caso sin preaviso a (25,15), commits `583010be231a05d2691d0abe2b93a0a39ced5362` y `0fa367d5c523923cf6d8e51c8af831dec0ab3506`.
- Próximo paso: repetir gate tras pull --ff-only, revisar cualquier fallo nuevo de PostgreSQL temporal y Flutter. DEV sigue en 0016.

## 25/10/2026 — MACROBLOQUE A: GATE INTEGRAL SUPERADO (confirmado por salida de Ubuntu)

- Commit verificado `b8654ddaaf7f4e57322e564d566af0072ce8e9ee` en rama `integration/local-e2e-prep`.
- Usuario ejecutó `bash scripts/validate_macro_a_readonly.sh`; salida: `MACRO_A_FUENTES=OK`, `CONFIG_COMPOSE=OK`, `I18N_ES_CA=OK`, `BUILD_BACKEND_AISLADO=OK`, `DJANGO_CHECK_MIGRACION_SECA=OK`, `DJANGO_SQLITE_SUITE_COMPLETA=OK`, `PG17_TEMPORAL=OK`, `DJANGO_POSTGRES17_SUITE_COMPLETA=OK`, `FLUTTER_ANALYZE_TEST_BUILD=OK`, `LOCALCHECK_HEALTH_PRE=OK`, `LOCALCHECK_HEALTH_POST=OK`, `RESULTADO_GLOBAL=0`, `MACRO_A_PREFLIGHT_COMPLETO=OK`.
- Log local de la ejecución: `/tmp/vencira-o7-o8-preflight.d3ItY9pt.log`. No hay migración persistente ni despliegue: `NO_SE_DESPLEGO_NI_MIGRO_DB_PERSISTENTE=1` y `MACRO_A_NO_DESPLEGADO=1`.
- **Diferenciar**: gate de tests aislados SUPERADO; despliegue en DEV aún pendiente. DEV sigue en migración 0016; antes de 0017/0018 exigir gate O5 (copia cifrada reciente verificable, ensayo/recuperación, migración, salud y rollback imágenes con trazabilidad).

## 25/10/2026 — Procedimiento despliegue macro A PREPARADO, sin ejecutar

- Ensayo O5 usuario OK en segundo intento: snapshot `4341e05e`, clon PostgreSQL 17 restaurado en `0016`, migrado a `0018`, DEV conservado en `0016`. Preflight integral Django SQLite/PostgreSQL temporal/Flutter OK SHA `b8654dda`.
- Se añadió `scripts/deploy_macro_a_0018_guarded.sh` commits `a8d5157f` y `42ba3132`: sólo ejecutable con `MACRO_A_DEPLOY_CONFIRM=DEPLOY_0017_0018_DEV` y `MACRO_A_O5_VERIFIED_SNAPSHOT=4341e05e`; verifica identidad, fuentes y salud, audita O5, etiqueta imágenes anteriores, construye API/web, inspecciona plan, hace nueva copia cifrada, aplica 0017/0018 explícitamente, recrea API y web, comprueba health y autorización. Recibo y log locales. Sin recuperación automática de BD; si falla tras migrar, NO reejecutar a ciegas.
- Aún NO ejecutado sobre DEV. Antes, `git pull --ff-only`, `bash -n scripts/deploy_macro_a_0018_guarded.sh`; usuario debe ejecutar con sudo y variables explícitas cuando proceda. No afectar Caddy/OAuth/timers/otros stacks.

## 25/10/2026 — MACRO A DESPLEGADO EN DEV (confirmado por consola)

- Usuario ejecutó `scripts/deploy_macro_a_0018_guarded.sh` sobre `vencira_localcheck` y obtuvo `RESULTADO_GLOBAL=0` y `MACRO_A_DEV_DESPLIEGUE=OK`.
- Gates: COMPOSE_CONFIG, MIGRATE_CHECK_ONLY, DEV_0016_PRE, O5_AUDIT, TAG_OLD_API, TAG_OLD_WEB, BUILD_API, BUILD_WEB, MIGRATION_PLAN 0017/0018, FRESH_BACKUP_O5, APPLY_0017_0018, DEV_0018_VERIFICADO, POST_MIGRATE_CHECK, DEPLOY_API/WEB, HEALTH_API/WEB healthy, ANON_DENIED_HTTP=403, DEV_0018_FINAL=OK. PostgreSQL no reiniciado; Caddy/OAuth/timers sin cambios.
- Recibo local `/tmp/vencira-macro-a-deploy.eXQ0fJzh.receipt`, log local `/tmp/vencira-macro-a-deploy.UqWTKaIi.log`. No representan sandbox links.
- PENDIENTE: pruebas E2E funcionales en sesión autenticada sobre recordatorios operativos (60/45/35, control 1 mes, acciones/no/snooze, motivos, agenda ES/CA). No confundir smoke y health con validación manual.

## 25/10/2026 — Macrofase B, primera entrega funcional versionada (NO desplegada)
- Usuario confirmó "Done, todo funciona ok" para macro A incluidas UI premium móvil y motivos; DEV esquema 0018, endpoint operativo A funcional. Estado confirmado por usuario, no extrapolar a producción.
- Plan B `docs/MACROFASE_B_BANDEJA_OPERATIVA.md`; antes de codificar se auditaron `OperationalReminder`, `OperationalReminderEvent`, permisos `_visible_renewals`, agenda día/mes y acciones CAS existentes.
- Implementación B: `backend/reminders/operational_inbox.py` endpoint GET con filtros `day` obligatorio, `scope` due/today/overdue/upcoming, contadores y paginación; URL en `backend/reminders/urls.py`; tests `test_operational_inbox.py`; DTO y cliente Flutter, pantalla `operational_inbox_screen.dart` enlazada desde dashboard, localizaciones ES/CA y parser test.
- Gate `scripts/validate_macro_b_readonly.sh` reutiliza `validate_o7_o8_preflight.sh`, Django SQLite/PG17 efímero/Flutter/i18n/health; **NO EJECUTADO** todavía. Requiere `cd /home/vencira/vencira-localcheck; git pull --ff-only origin integration/local-e2e-prep; bash scripts/validate_macro_b_readonly.sh`. Posibles errores se corrigen en GitHub; NO desplegar hasta gate 0.
- No nuevas migraciones, no envíos; DEV PostgreSQL debe seguir 0018; no usar scripts web-only antiguos para código backend B. Para desplegar después crear guardado de API+web con gates de identidad, O5 e imágenes previas.
- La decisión §18 del whitepaper sobre avisos no atendidos sigue pendiente; lectura conserva atrasados sin marcarlos completos automáticamente. Historial visible por evento y aceptación final móvil aún pendientes.

## 25/10/2026 — Macrofase B: gate OK; despliegue API+Web protegido PREPARADO, NO ejecutado

- El usuario ejecutó `scripts/validate_macro_b_readonly.sh` en Ubuntu; `FLUTTER_ANALYZE_TEST_BUILD=OK`, `LOCALCHECK_HEALTH_POST=OK`, `O7_O8_PREFLIGHT_SIN_DESPLIEGUE=OK`, `RESULTADO_GLOBAL=0`, `MACRO_B_GATE_INTEGRAL=OK`, `MACRO_B_GATE_RESULTADO=0`. Log `/tmp/vencira-o7-o8-preflight.arUdsBEY.log`. Previo fallo de `widget_test.dart` resuelto en commit `f893329c`.
- Implementado `scripts/deploy_macro_b_api_web_guarded.sh` (commit `8004df13`): comprueba fuentes iguales al gate `f893329cb3372cea491e3c06fa1b2c1fda3d3c65`, O5 leído sin alterar, esquema vivo 0018, imágenes antiguas etiquetadas y recibo privado, build de API+Flutter, `migrate --check` (NO MIGRA), despliegue secuencial de api/web, health, validación de ruta inbox anónima denegada, identidad DB y conteo migraciones constantes.
- **NO DESPLEGADO**. Operador: pull, `bash -n scripts/deploy_macro_b_api_web_guarded.sh`; luego `sudo env MACRO_B_DEV_CONFIRM=DEPLOY_API_WEB_NO_MIGRATIONS bash scripts/deploy_macro_b_api_web_guarded.sh`. No repetir a ciegas si falla, revisar FASE_FALLIDA y logs saneados. Scripts anteriores de macro A NO válidos para B.
- Restan E2E autenticado (bandeja hoy/atrasados/próximos, acciones, permisos usuario) e historial visible, decisión explícita del usuario sobre política de atrasados.
