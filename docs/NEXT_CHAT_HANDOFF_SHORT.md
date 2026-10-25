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
