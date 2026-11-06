

> **B2-A — Firma Android sin debug (06/11/2026):** publicado cambio en `clients/flutter/android/app/build.gradle.kts` para impedir firma `release` con claves debug y exigir cuatro parámetros de entorno externos. Cuatro pruebas estáticas y N1/CI integrados, pero **sin ejecución local todavía**. No existe APK beta firmada ni autorización. Ver [ANDROID_BETA_CRITICAL_PATH_2026-11-06.md](ANDROID_BETA_CRITICAL_PATH_2026-11-06.md).

---

> **RUTA CRÍTICA BETA ANDROID — 06/11/2026:** plan de tres macrofases B1 (emisor MFA confiable E2/E3 con auditoría transaccional), B2 (integración Android real, permisos, notificaciones, APK firmada y UAT) y B3 (custodia, MB1/C-FICHA, privacidad, recuperación, operaciones y aprobación). Ver [ANDROID_BETA_CRITICAL_PATH_2026-11-06.md](ANDROID_BETA_CRITICAL_PATH_2026-11-06.md). G13 18/18 PASS en laboratorio y E1D3 139 PG17 PASS no autorizan beta operativa. `clients/flutter/android/app/build.gradle.kts` utiliza configuración de firma debug incluso en release: pendiente corregir antes de distribuir beta formal. No desbloquear E2 con pruebas sintéticas, no merge/despliegue/migración persistente.

---

> **CONTINUIDAD PRIORITARIA 06/11/2026 (sustituye lo posterior histórico).** VENCIRA, `feature/m3-android-local-notifications`, PR #17 borrador. G14-E1D3 confirmado localmente: 139 tests PostgreSQL 17 PASS, N1/build/PG17=0 sobre HEAD `07fa7818b`. G14-F0 AST confirmado: 9 tests PASS, scan=0, N1=0, una llamada revisada y cero no revisadas, HEAD `5291785bd`. Documentación posterior en rama contiene commits de seguimiento; no asumir que el último HEAD documental fue sometido a PostgreSQL. **Bloqueador principal:** G14-E2, emisor MFA confiable + auditoría atómica **NO implementado**; E3 pendientes pruebas de carreras del emisor. Intentos de integrar esa composición bloqueados por la conexión, no eludir. No repetir E1/E1B/E1C/E1D/F0 sin cambio relevante. Mantener `MFA_RELEASE_AUTHORIZED=NO`, `MB1_RELEASE_AUTHORIZED=NO`, `C_FICHA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`. Consultar [G14_PROGRESS_CHECKLIST_2026-11-05.md](G14_PROGRESS_CHECKLIST_2026-11-05.md), [G14_E2_ATOMIC_ISSUANCE_ACCEPTANCE_2026-11-06.md](G14_E2_ATOMIC_ISSUANCE_ACCEPTANCE_2026-11-06.md) y [HANDOFF_G5_IN_PROGRESS_2026-11-03.md](HANDOFF_G5_IN_PROGRESS_2026-11-03.md) para decisiones de siguiente fase.

---

> **CONTINUIDAD PRIORITARIA 03/11/2026 — SUSTITUYE LOS ENCABEZADOS HISTÓRICOS SIGUIENTES.** Consultar primero [HANDOFF_G4_G5_2026-11-03.md](HANDOFF_G4_G5_2026-11-03.md): rama `feature/m3-android-local-notifications`, PR #17 borrador; G6 laboratorio integrado `M3_HTTP_RESULT=0` (02/11, anterior a G4), G4 candidato PostgreSQL17 `G4_CANDIDATE_PG17_RESULT=0` (03/11, 20/20 tests y migraciones sin deriva), G4 operativo NO, SQLite/CI G4 no verificados y runner integral post-G4 pendiente. Siguiente macrofase **G5** antiabuso, auditoría, claves HMAC y fuente confiable de emisión. **No desplegar ni migrar DB persistente; MFA/MB1/C-FICHA NO, GLOBAL_FREEZE no verificado**. Las instrucciones sobre O8/O9, ramas o commits antiguos que figuran debajo son historia y no prevalecen.

---

> **ESTADO VIGENTE — 28/10/2026 — LEER ANTES QUE LOS APUNTES HISTÓRICOS INFERIORES.** VENCIRA, rama `feature/c-ficha-independent-attachments`, Macrofase C-FICHA consolidada en ensayos y pruebas; código verificado en `95bb698`, actualización documental posterior. PostgreSQL17 efímero: 34 tests OK, gate 0. Test independiente de raíz ausente vs archivo ausente: `STORE_ROOT_TEST_RESULT=0`. Ensayos aislados de ClamAV, recuperación de outbox y muerte real de worker OK. Flutter analyze/test/build Web OK, panel adjuntos ES/CA solo metadatos y operaciones bloqueadas. GitHub sincronizado en el commit de código; cualquier nuevo commit documental debe actualizarse en VPS con fetch/fast-forward. **La Macrofase D queda pendiente:** transición real del modelo histórico `reminders.0027` al independiente, contratos/API con permisos por workspace, circuito subida-escaneo-descarga, custodia de claves, RGPD, rollback y autorización expresa. NO interpretar C-FICHA como habilitada para producción. **`MFA_RELEASE_AUTHORIZED=NO`; `C_FICHA_RELEASE_AUTHORIZED=NO`; `NO_DEPLOY_NO_LIVE_MIGRATION=1`.** Documento de referencia actualizado: [C_FICHA_RELEASE_REVIEW_2026-10-28.md](C_FICHA_RELEASE_REVIEW_2026-10-28.md). `clients/flutter/pubspec.lock` local sin seguimiento: no borrarlo ni añadirlo. No repetir los gates superados salvo cambios relacionados.

---

> **NUEVO CHAT — CIERRE DE MACROFASE B (25/10/2026):** leer primero [`HANDOFF_MACROFASE_C_2026-10-25.md`](HANDOFF_MACROFASE_C_2026-10-25.md). El promotor confirma «Done, todo ok» tras las pruebas y publicación de la tarjeta premium de historial. Macrofase B aceptada por comunicación del usuario; los apuntes antiguos inferiores pueden indicar estados anteriores al cierre. La próxima macrofase C empieza con auditoría del código real O9b (Sí/No manual y repetición interna ya existen) frente al whitepaper §§7–10/18; decisiones §18 no aprobadas siguen abiertas. No repetir despliegues ni tocar O5/Caddy/OAuth ni PostgreSQL sin gates.

> **ESTADO ACTUAL / LECTURA PRIMERO — 25/10/2026.** La información histórica inferior es acumulativa y puede decir «pendiente» de funcionalidades ya completadas. **A y B aceptadas; B incluye historial premium móvil y paginación.** La macrofase **C0 quedó auditada estáticamente** en [MACROFASE_C_C0_AUDITORIA_2026-10-25.md](MACROFASE_C_C0_AUDITORIA_2026-10-25.md); **C1** debe cerrar las propuestas no aprobadas del §18 (motivos por defecto 60/45/35, atrasados HOY, altas tardías, cero avisos anteriores a corte, Vida y entrega/reintentos). **C2–C3 no iniciadas**. No duplicar O9b (Sí/No manual, tres alternativas, No con programación interna y auditoría) ni declarar notificaciones entregadas. Último esquema DEV documentado: **0018**, confirmar antes de actuar; no hay nuevo gate/despliegue con C0. Fuentes de verdad: [whitepaper original](source/WHITEPAPER_ORIGINAL_2026-10-18_TRANSCRIPCION.md) → [plan maestro](WHITEPAPER_EXECUTION_ROADMAP_2026-10-24.md) → [handoff C](HANDOFF_MACROFASE_C_2026-10-25.md). No solicitar credenciales ni tocar infraestructura.


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


## 25/10/2026 — Macrofase B: despliegue API + web DEV CONFIRMADO

- El operador ejecutó `scripts/deploy_macro_b_api_web_guarded.sh` y aportó la salida final: `DEPLOY_WEB=OK`, `HEALTH_WEB=healthy`, `BANDEJA_PROXY_ANON_DENIED_HTTP=403`, `POSTGRES_0018_INTACTO=OK`, `DEV_0018_FINAL=OK`, `MACRO_B_DEV_DESPLIEGUE=OK`, `RESULTADO_GLOBAL=0`.
- Sin migraciones ni reinicio PostgreSQL, sin cambios Caddy/OAuth/O5. Imágenes antiguas etiquetadas `vencira-macro-b-pre-api:20261025T165744Z_3030839`, `vencira-macro-b-pre-web:20261025T165744Z_3030839`; log `/tmp/vencira-macro-b-deploy.t5mEG38S.log`, recibo `/tmp/vencira-macro-b-deploy.CkNfZBXA.receipt`.
- **Siguiente paso:** validar desde sesión autenticada y móvil: bandeja «Por atender», «Hoy», «Atrasados», «Próximos», contador por clase, entrada a ficha, acciones completar/mañana/elegir fecha, recarga de contadores y ES/CA. No declarar macrofase B aceptada hasta prueba del usuario.
- Sigue pendiente presentación de historial por evento y aprobación de la política §18 para avisos sin atender. No confundir avisos internos con notificaciones entregadas.

## 25/10/2026 — Rediseño premium solicitado tras revisión Android (GitHub, NO desplegado)
- El usuario comprobó bandeja B en Android: endpoint y datos funcionan, pero proliferación de botones en inicio y tarjetas. Solicitó mejora visual consistente y revisada frente a Flutter/Material 3. Screenshots muestran accesos Agenda/Añadir, Archivo/Bandeja, contadores y cuatro acciones repetidas por tarjeta.
- Implementación UI: `clients/flutter/lib/ui/operational_inbox_screen.dart` cambió tres chips de contadores por resumen en tres columnas, cuatro ChoiceChips por un `SegmentedButton` horizontal desplazable, tarjetas `Card.outlined` enteramente pulsables (abre ficha) y un icono de tres puntos que abre `showModalBottomSheet` con estilo de Preferencias. Acciones preexistentes: detalle, completar, mañana, elegir fecha; conserva API, CAS, permisos, ES/CA y no interpreta avisos como enviados.
- Inicio `dashboard_screen.dart`: Archivo y Avisos agrupados en fila de acciones secundarias compactas, conservando las keys de test; etiqueta corta ES/CA `inboxShortcut`.
- Tests nuevos `clients/flutter/test/operational_inbox_premium_test.dart` para 320/375/768 px, ausencia de botonera repetida, sheet y aplazamiento. **No ejecutados aún en Ubuntu.**
- Script de despliegue solo web `scripts/deploy_macro_b_premium_ui_web_guarded.sh`, exige fuente Flutter igual al commit `5294399dfde338f63f58887e119aaa3f9c537f5b`, confirma API B previa protegida y conserva web anterior, sin modificar API/DB ni migrar.
- **PRÓXIMO PASO:** git pull; `bash scripts/validate_macro_b_readonly.sh` (gate aislado Django SQLite/PG17 y Flutter); corregir cualquier fallo. SOLO SI termina `MACRO_B_GATE_RESULTADO=0` ejecutar `sudo env MACRO_B_PREMIUM_UI_CONFIRM=DEPLOY_PREMIUM_WEB_DEV bash scripts/deploy_macro_b_premium_ui_web_guarded.sh`. Aceptación final móvil pendiente; macro B no cerrada.

## 25/10/2026 — Afinado móvil tras capturas: Catálogos en fila + filtros 2×2 (SIN DESPLIEGUE)
- Capturas Android mostraban en Catálogos dos botones apilados y la banda `SegmentedButton` recortando «Por atender» y «Próximos» en horizontal.
- `dashboard_screen.dart`: `open-catalog` y `open-insurers` ahora forman una única `Row` con dos `Expanded`; el helper `_catalogShortcut` usa botón con icono arriba, texto centrado hasta dos líneas, esquinas y borde del tema, y mantiene las keys estables.
- `operational_inbox_screen.dart`: reemplazado selector horizontal por rejilla fija 2×2 `LayoutBuilder` + `Wrap` con cuatro superficies táctiles, iconos, selección en color `primaryContainer` y check. API, contadores, tarjetas y acciones intactos.
- Pruebas nuevas/revisadas: `clients/flutter/test/widget_test.dart` comprueba alineación de botones a 320 y 375 px; `clients/flutter/test/operational_inbox_premium_test.dart` comprueba cuadrícula a 320/375/768 px, selección y backend.
- Nuevo pin exacto del deploy web protegido `scripts/deploy_macro_b_premium_ui_web_guarded.sh`: `VALIDATED=4be62a7c57040bf1e859d970bc0f06f961af0549`. **ES REFERENCIA DE FUENTES PENDIENTE DE GATE**, no declarar validado hasta resultado real.
- Antes de desplegar: `git pull --ff-only origin integration/local-e2e-prep`, `python3 scripts/check_flutter_l10n.py`, `bash scripts/validate_macro_b_readonly.sh`. Solo si gate final `MACRO_B_GATE_RESULTADO=0`, `sudo env MACRO_B_PREMIUM_UI_CONFIRM=DEPLOY_PREMIUM_WEB_DEV bash scripts/deploy_macro_b_premium_ui_web_guarded.sh`.
- El despliegue es web-only, conserva API/PostgreSQL e imagen web antigua; el estado visual final requiere aceptación del usuario tras Android.

## 25/10/2026 — Corrección fallo BUILD_WEB posterior a filtros 2×2 (sin despliegue)
- Operador reportó `FASE_FALLIDA=BUILD_WEB`, `WEB_PUDO_HABERSE_RECREADO=0`, log `/tmp/vencira-macro-b-premium-ui-web.xnFb1Hee.log`, `RESULTADO_GLOBAL=1`. Solo aportó el resumen final del Dockerfile, no líneas `.dart:<línea>:<columna>` del error Dart.
- Revisión detectó referencia sospechosa `Icons.event_upcoming_outlined` que no consta en API Flutter; sustituida por icono documentado `Icons.upcoming` en `clients/flutter/lib/ui/operational_inbox_screen.dart`, commit `cca8bba8afc498778b6c76dbedae04f159a5da05`. Es una causa probable pero sin comprobación del error original.
- Actualizado pin de `scripts/deploy_macro_b_premium_ui_web_guarded.sh` a `VALIDATED=cca8bba8afc498778b6c76dbedae04f159a5da05`. Refuerzo del gate `scripts/validate_macro_b_readonly.sh`: además de suite integral Flutter stable/Django, compila con SDK `ghcr.io/cirruslabs/flutter:3.44.0`, la MISMA del `deploy/preview/Dockerfile.web`; imprime `FLUTTER_WEB_DOCKERFILE_PIN=OK` solo si compila.
- Pendiente: `git pull --ff-only`; consultar origen del error en log local y ejecutar `bash scripts/validate_macro_b_readonly.sh`. **No repetir desplegar hasta `MACRO_B_GATE_RESULTADO=0`**; si falla, enviar primer error Dart, no el final genérico. DB/API/Web actualmente sin recrear por fallo anterior.

## 25/10/2026 — BUILD_WEB diagnosticado, corrección validada, publicación pendiente
- El log real del build previo confirmó `lib/ui/operational_inbox_screen.dart:412:29: Error: Member not found: 'event_upcoming_outlined'`. Sustituido por `Icons.upcoming` en commit `cca8bba8afc498778b6c76dbedae04f159a5da05`.
- Usuario ejecutó `bash scripts/validate_macro_b_readonly.sh` tras `git pull`: `DJANGO_SQLITE_SUITE_COMPLETA=OK`, `DJANGO_POSTGRES17_SUITE_COMPLETA=OK`, `FLUTTER_ANALYZE_TEST_BUILD=OK`, `LOCALCHECK_HEALTH_POST=OK`, `FLUTTER_WEB_DOCKERFILE_PIN=OK` con SDK Flutter 3.44.0, `MACRO_B_GATE_INTEGRAL=OK`, `MACRO_B_GATE_RESULTADO=0`, `NO_SE_DESPLEGO_NI_MIGRO_DB_PERSISTENTE=1`.
- El script `scripts/deploy_macro_b_premium_ui_web_guarded.sh` mantiene `VALIDATED=cca8bba8afc498778b6c76dbedae04f159a5da05`, confirmado contra repositorio. Preparado despliegue **solo web** con `sudo env MACRO_B_PREMIUM_UI_CONFIRM=DEPLOY_PREMIUM_WEB_DEV bash scripts/deploy_macro_b_premium_ui_web_guarded.sh`, previa actualización git. NO se ha realizado ni confirmado este despliegue todavía.

## 25/10/2026 — Despliegue premium móvil B: CONFIRMADO en DEV
- Usuario confirmó salida final del script `scripts/deploy_macro_b_premium_ui_web_guarded.sh`: `WEB_DEPLOY=OK`, `HEALTH_web_preview=healthy`, `BANDEJA_ANON_HTTP=403`, `POSTGRES_0018_INTACTO=OK`, `API_DB_IDENTIDAD_POST_DEPLOY=OK`, `MACRO_B_PREMIUM_UI_WEB_DEV_DESPLIEGUE=OK`, `RESULTADO_GLOBAL=0`.
- Imagen previa conservada: `vencira-macro-b-premium-pre-web:20261025T182617Z_3086588`. `SIN_MIGRACIONES=1`, `SIN_REINICIO_API_DB=1`, `SIN_CAMBIOS_CADDY_OAUTH_TIMERS=1`.
- Publicadas dos mejoras: accesos de catálogos de la organización en la misma fila, filtros Por atender/Atrasados/Hoy/Próximos en cuadrícula 2×2 con selección del tema; tarjetas premium y acciones en panel inferior de B previamente desarrolladas.
- PENDIENTE aceptación visual Android tras el último despliegue y cierre formal del macrobloque B (historial de actuaciones visible y decisión de producto sobre avisos no atendidos).

## 25/10/2026 — Auditoría de fluidez integral, código listo para gate; NO DESPLEGADO
- Usuario observó en Android tema oscuro scroll que sube y vuelve al pulsar Buscar / Limpiar filtros en Inicio, y filtros Por atender/Atrasados/Hoy/Próximos en Bandeja. Se comprobó en fuente que al cargar se vaciaban `_renewals`, `_inbox`, detalles/listas con indicadores de carga, alterando la geometría del scroll.
- Se aplicaron correcciones SOLO Flutter a 12 componentes: `dashboard_screen.dart`, `operational_inbox_screen.dart`, `day_agenda_screen.dart`, `renewal_detail_screen.dart`, `renewal_archive_screen.dart`, `results_screen.dart`, `month_agenda_screen.dart`, `modality_catalog_screen.dart`, `insurer_catalog_screen.dart`, `reminder_draft_card.dart`, `reminder_preview_card.dart`, `control_assessment_card.dart`.
- Retener los datos/campos del mismo workspace/ficha durante consultas; indicadores discretos con espacio fijo, sin retirar toda la lista; permitir pulsar Buscar/Limpiar sin desactivar el TextField. Control de concurrencia con `_sequence`/tokens; limpieza al cambio de organización/pérdida de autorización.
- Se añadieron pruebas widget con `Completer` para simular respuestas de API lentas, comprobar offset y `maxScrollExtent` estable para Buscar y Limpiar, y la coordenada vertical de filtros/tarjetas en Bandeja. Modificados `clients/flutter/test/widget_test.dart`, `clients/flutter/test/operational_inbox_premium_test.dart`.
- Auditoría ampliada `docs/AUDITORIA_FLUIDEZ_FLUTTER_2026-10-25.md` (commit `6f3054a6`), pin de despliegue protegido `scripts/deploy_macro_b_premium_ui_web_guarded.sh` actualizado a `VALIDATED=e0fd537077dde84004af2adac5070bd8e0262003` (commit `c4c0c0d8`). Los cambios posteriores a ese pin son solo scripts/docs, no fuentes Flutter/backend/compose.
- **ESTADO: SIN EJECUTAR PRUEBAS REALES DEL USUARIO Y SIN DESPLIEGUE**. Siguiente paso `git pull --ff-only origin integration/local-e2e-prep`; `bash scripts/validate_macro_b_readonly.sh`. Gate ejecuta suite Django SQLite/PG17 temporal y Flutter stable más build adicional con Flutter 3.44.0 Dockerfile. Requerir `FLUTTER_WEB_DOCKERFILE_PIN=OK`, `MACRO_B_GATE_RESULTADO=0`. Si falla, diagnosticar log y corregir código/pin, no desplegar.
- Solo con gate OK: `bash -n scripts/deploy_macro_b_premium_ui_web_guarded.sh`; `sudo env MACRO_B_PREMIUM_UI_CONFIRM=DEPLOY_PREMIUM_WEB_DEV bash scripts/deploy_macro_b_premium_ui_web_guarded.sh`. Web-only; API, PostgreSQL 0018 y Caddy/OAuth/O5 sin cambio. Exigir `RESULTADO_GLOBAL=0`. Después, nueva validación en Android claro/oscuro y scroll intermedio.

## 25/10/2026 — Macrofase B historial: implementado, NO VALIDADO/DESPLEGADO
- El usuario confirmó que los refrescos/parpadeos estaban correctos tras su última intervención y autorizó continuar.
- Nuevo GET protegido de historial por ocurrencia: `backend/reminders/operational_history.py`; pruebas `test_operational_history.py`. No altera PostgreSQL (sigue 0018), no envía ni acredita notificaciones.
- Flutter ES/CA: modelos `VenciraOperationalEvent/History`, `operational_history_screen.dart` paginada, acceso desde menú de Bandeja y desde `operational_panel.dart` para completados/cancelados; tests `operational_history_test.dart` y `operational_inbox_premium_test.dart`.
- Documento funcional completo: `docs/MACROFASE_B_HISTORIAL_ACTUACIONES_2026-10-25.md`.
- Falta GATE: `git pull --ff-only origin integration/local-e2e-prep`; `bash scripts/validate_macro_b_readonly.sh` (incluye Flutter 3.44.0) y exigir `MACRO_B_GATE_RESULTADO=0`. Despliegue protegido solo tras gate: `sudo env MACRO_B_HISTORY_CONFIRM=DEPLOY_HISTORY_API_WEB_NO_MIGRATIONS bash scripts/deploy_macro_b_history_api_web_guarded.sh` (API+Web, pin `0e6f621d834e882d437acbbf8ca15c89075224c7`). Mantiene O5, DB, Caddy/OAuth/timers, images de rollback. Usuario valida Android después.
- Decisión §18 política de avisos sin atender **no aprobada**; conservar avisos atrasados, ninguna finalización automática.

## 25/10/2026 — Macrofase B history gate falló por truncamiento/duplicación Flutter; corregido en GitHub, NO VALIDADO
- Usuario ejecutó gate en Ubuntu: `FLUTTER_ANALYZE` falló con 607 issues, primeras líneas relevantes en `clients/flutter/lib/api/vencira_api.dart:2045` (`Expected to find ';'`, `missing_required_argument`, etc). `MACRO_B_GATE_RESULTADO=1`, `NO_SE_DESPLEGO_NI_MIGRO_DB_PERSISTENTE=1`, log `/tmp/vencira-o7-o8-preflight.zYiNN0yX.log`.
- Diagnóstico directo de GitHub: `vencira_api.dart` tenía DTO de evento partido en `RegExp(...` a línea ~957, una copia completa de `HttpVenciraApi` y de DTOs tras línea 2040 y cierre de clase faltante. No se trataba de 607 errores independientes sino un fallo de concatenación del archivo.
- Corrección commit `ca69dba2370b8c9de552caea81ea5be1a0720061`: reconstruido DTO `VenciraOperationalEvent` íntegro con UUID canónico, acción/estado/fecha civil/actor validados; `VenciraOperationalHistory` y `VenciraOperationalInbox` en una sola copia; `HttpVenciraApi` única con implementación fetch history y llave de cierre; eliminados 37.754 caracteres duplicados. Invariantes estructurales verificadas al editar: 1 DTO evento, 1 DTO historial, 1 Inbox, 1 clase cliente; 2 firmas history (interface y override). **Aún NO pasó `flutter analyze` real; no declararlo validado.**
- Actualizado `scripts/deploy_macro_b_history_api_web_guarded.sh` pin `VALIDATED=ca69dba2370b8c9de552caea81ea5be1a0720061`, commit `15be5378`. No ejecutar despliegue hasta gate OK.
- Siguiente: `git pull --ff-only origin integration/local-e2e-prep`; validar primero Flutter 3.44.0:
  `sudo docker run --rm -v "$PWD/clients/flutter:/work" -w /work ghcr.io/cirruslabs/flutter:3.44.0 sh -ec 'flutter pub get && flutter gen-l10n && flutter analyze && flutter test test/operational_history_test.dart test/operational_inbox_premium_test.dart'`.
  Después gate integral `bash scripts/validate_macro_b_readonly.sh`; solo con `MACRO_B_GATE_RESULTADO=0`, `FLUTTER_WEB_DOCKERFILE_PIN=OK` se autoriza deploy API+Web history controlado.

## 25/10/2026 — Android: historial visible + paginación centrada, listo para gate (NO DESPLEGADO)
- Usuario envió captura Agenda diaria y Archivo, indicó que no veía el botón de historial y que Anterior/Siguiente solamente estaban centrados en Archivo. Autorizó corregir ambos.
- Implementado acceso visible `Historial de avisos` en el encabezado de cada `renewal_detail_screen.dart` (también para cerradas/archivadas); abre nueva pantalla `operational_history_index_screen.dart` con lista de todas las ocurrencias guardadas, incluso completadas y canceladas, y de ahí cada `operational_history_screen.dart`. Se evita confundir con historial técnico escritorio de cambios. Traducciones ES/CA. No API/DB nuevas.
- Paginador compartido `vencira_pagination_bar.dart`, centrado, responsive 320/375px. Sustituido en Inicio `dashboard_screen.dart`, Agenda diaria `day_agenda_screen.dart`, Archivo `renewal_archive_screen.dart`, Bandeja `operational_inbox_screen.dart` e historial de cambios `renewal_detail_screen.dart`. No alterar lógica de paginación ni flicker.
- Pruebas nuevas `clients/flutter/test/history_entry_pagination_test.dart`: apertura desde anotación cerrada a completados/cancelados, empty state, posiciones geométricas paginador 320/375/768px.
- Documento `docs/AJUSTES_VISIBILIDAD_HISTORIAL_PAGINACION_2026-10-25.md`. Deploy protegido **solo Flutter Web** `scripts/deploy_macro_b_premium_ui_web_guarded.sh` pin `88c03530485a21bd38f13b3a4780ca549323d7b2`, comprueba history API (401/403 anon), O5/PG17 0018 igual, sin recrear API/DB.
- **NO VALIDADO NI DESPLEGADO AÚN**. Ejecutar `git pull --ff-only origin integration/local-e2e-prep`; `bash scripts/validate_macro_b_readonly.sh`; corregir cualquier fallo antes de desplegar. Únicamente con `FLUTTER_WEB_DOCKERFILE_PIN=OK`, `MACRO_B_GATE_RESULTADO=0`: `bash -n scripts/deploy_macro_b_premium_ui_web_guarded.sh` y `sudo env MACRO_B_PREMIUM_UI_CONFIRM=DEPLOY_PREMIUM_WEB_DEV bash scripts/deploy_macro_b_premium_ui_web_guarded.sh`. Si falla en precheck API historial, detenerse, no repetir.

## 25/10/2026 — Gate de UI historial visible/paginación falló por scroll en prueba O2; corregido, sin validar
- Usuario ejecutó `bash scripts/validate_macro_b_readonly.sh`: `FASE_FALLIDA=FULL_ISOLATED_GATE`, `MACRO_B_GATE_RESULTADO=1`, `NO_SE_DESPLEGO_NI_MIGRO_DB_PERSISTENTE=1`, log `/tmp/vencira-o7-o8-preflight.GazhLMQg.log`.
- Diagnóstico aportado: SOLO dos fallos en `clients/flutter/test/manual_follow_up_test.dart:95`, ambos ES/CA; `StateError: Bad state: No element` en `tester.ensureVisible(schedule)`. La nueva fila de CTA Historial de avisos en la cabecera desplaza la tarjeta O2 más abajo del cache del `ListView`; el elemento no está construido todavía, por lo que `ensureVisible` falla, aunque la funcionalidad permanece.
- Corrección test commit `b734e4c4d35605b3aa939b9bae9e720ab62f9760`: usar `tester.scrollUntilVisible` para `schedule-follow-up` y `complete-follow-up`, después continuar con programación/confirmación y validar `api.schedules/resolves` en ES/CA; NO se alteró lógica O2, API, BD ni la UI.
- Pin actualizado en `scripts/deploy_macro_b_premium_ui_web_guarded.sh` a `VALIDATED=b734e4c4d35605b3aa939b9bae9e720ab62f9760`, commit `c2555ff2`.
- **PENDIENTE**: usuario debe ejecutar primero `git pull --ff-only origin integration/local-e2e-prep`; prueba focal con Flutter 3.44.0 `sudo docker run --rm -v "$PWD/clients/flutter:/work" -w /work ghcr.io/cirruslabs/flutter:3.44.0 sh -ec 'flutter pub get && flutter gen-l10n && flutter test test/manual_follow_up_test.dart'`; solo si OK, `bash scripts/validate_macro_b_readonly.sh`. No desplegar hasta `MACRO_B_GATE_RESULTADO=0` y `FLUTTER_WEB_DOCKERFILE_PIN=OK`. Si otra prueba falla, corregir log real primero.

## 25/10/2026 — Historial visible y paginación: gate integral OK, pendiente web deploy
- Tras corregir `manual_follow_up_test.dart` en `b734e4c4` (scrollUntilVisible en ES/CA), el operador reporta `FLUTTER_WEB_DOCKERFILE_PIN=OK`, `MACRO_B_GATE_INTEGRAL=OK`, `MACRO_B_GATE_RESULTADO=0`, `NO_SE_DESPLEGO_NI MIGRO DB PERSISTENTE=1` (última línea normalizada por sentido).
- Verificado script `scripts/deploy_macro_b_premium_ui_web_guarded.sh`: `VALIDATED=b734e4c4d35605b3aa939b9bae9e720ab62f9760`; `MACRO_B_PREMIUM_UI_CONFIRM=DEPLOY_PREMIUM_WEB_DEV`; comprueba presencia API historial (401/403 anónimo), identidad API+DB, esquema PostgreSQL 0018, solo recrea `web_preview`, mantiene imagen web previa. **NO SE HA EJECUTADO ESTE DESPLIEGUE AÚN.**
- Siguiente operador: `git pull --ff-only origin integration/local-e2e-prep`, `bash -n scripts/deploy_macro_b_premium_ui_web_guarded.sh`, `sudo env MACRO_B_PREMIUM_UI_CONFIRM=DEPLOY_PREMIUM_WEB_DEV bash scripts/deploy_macro_b_premium_ui_web_guarded.sh`. Exigir `RESULTADO_GLOBAL=0`. Si falla por precheck API historial, no repetir/desplegar web; revisar despliegue previo API+web de la macrofase B. Después aceptar Android.

## 25/10/2026 — CTA de Historial premium a ancho completo (pendiente gate)
- Usuario mostró Android de ficha de anotación: el botón de Historial de avisos quedaba a la izquierda con gran espacio libre a la derecha, solicitó alinearlo con los paneles y aceptó full-width premium.
- En `clients/flutter/lib/ui/renewal_detail_screen.dart` se sustituyó `Align + OutlinedButton.icon` por `Card.outlined` de ancho completo con `InkWell`, minHeight 76, icono en fondo primaryContainer, título, subtítulo y chevron derecho. Sigue inmediatamente bajo chip estado y antes de Contacto; mantiene key `detail-operational-history` y navegación existente, sin introducir nueva API.
- Traducciones ES/CA `inboxHistoryShortcutDescription` = "Consultar actuaciones registradas" / "Consultar actuacions registrades".
- Regresiones en `clients/flutter/test/history_entry_pagination_test.dart`: con fixture de Contacto, validar al tema oscuro la anchura X izquierda/derecha del CTA igual a Card Contacto, altura >=76 y subtítulo en 320/375/768 px; pruebas previas de enlace/aviso cerrado intactas.
- **Fuentes/UI test SHA** `315570fa30a02a48c7dfc14ffbb9017188fd8f5f`; script web-only `scripts/deploy_macro_b_premium_ui_web_guarded.sh` pin actualizado con este SHA, commit `104a007d`, conserva checks historial API, 0018, O5 indirecto sin alteraciones, sin reinicio API/DB y rollback por tag de imagen web previa.
- **NO VALIDADO/NO DESPLEGADO.** Ejecutar `git pull --ff-only origin integration/local-e2e-prep`; `bash scripts/validate_macro_b_readonly.sh`; SOLO con `FLUTTER_WEB_DOCKERFILE_PIN=OK`, `MACRO_B_GATE_RESULTADO=0` ejecutar `bash -n scripts/deploy_macro_b_premium_ui_web_guarded.sh` y `sudo env MACRO_B_PREMIUM_UI_CONFIRM=DEPLOY_PREMIUM_WEB_DEV bash scripts/deploy_macro_b_premium_ui_web_guarded.sh`. Confirmar Android ancho completo, sin overflow, tema oscuro/claro.


## C1 — Primera decisión aprobada (25/10/2026)

El promotor respondió «Ok, mantenemos actualizados durante los trabajos, seguimos» a la propuesta de motivos. Se registra **aprobación conversacional** de los motivos predeterminados editables: **60 días** «Revisar vencimiento y contactar con el cliente»; **45 días** «Enviar notificación de no renovación»; **35 días** «Comprobar comunicación de no renovación y responder a la pregunta de control». Ello no supone envío real. La pregunta aparece en el último aviso elegible estrictamente anterior al límite del mes civil, que puede no ser el de 35 días. La configuración por cuenta/anotación sigue el §7 y no se alteran borradores existentes sin acción expresa. Esta actualización documental no ejecuta cambios funcionales, gates ni migraciones.

**C1 abierto:** avisos pendientes HOY, alta tardía, ausencia de aviso anterior al corte, Vida, autorización/evidencia de «Notificado por mí», canales y reintentos. Las propuestas §18 no equivalen a decisiones. Antes de C2 cotejar código existente y preparar pruebas; no repetir fases A/B.


## C1 — Regla de avisos no atendidos aprobada (25/10/2026)

El promotor respondió explícitamente «Sí, adelante» a la propuesta: en agenda HOY mostrar arriba los avisos internos vencidos no atendidos como **Pendientes**, por fecha original ascendente (más antiguo primero), sin desaparecer al cambiar de día; conservar acciones **Completada, Mañana, Otro día**; no duplicar al abrir HOY ni inferir una notificación entregada. Prioridad y persistencia son **regla de producto aprobada**, no certificación de que el código ya las satisfaga.

**Inspección estática inicial**: `backend/reminders/operational_api.py` conserva estados internos, CAS y `delivery_status=not_implemented`. `backend/reminders/reminder_planning.py` calcula los días transcurridos y marca altas tardías/no control, pero se abstiene correctamente de decidir §18 automáticamente. Falta verificar implementación concreta de filtrado/orden de HOY con tests; no reimplementar motor A/B. C1 siguientes decisiones abiertas: altas tardías y sin avisos anteriores al mes civil límite, modalidad Vida, evidencia y proveedores. No se ha ejecutado gate ni despliegue con esta aprobación.


## C1 — Altas tardías aprobadas, 25/10/2026

Promotor aprueba: no generar avisos retroactivos ficticios; conservar avisos futuros válidos; si pasó el control, advertir al guardar con acceso a pregunta; si venció el límite civil, advertencia roja y revisión manual; permitir guardar registrando necesidad de revisión. **Sin avisos elegibles antes del límite** es otra decisión §18 aún pendiente. Solo actualización documental, sin gate ni deploy.


## C1 — Sin aviso elegible anterior al límite (aprobado 25/10/2026)

El promotor aprueba **permitir guardar la anotación** aunque no exista ningún aviso configurado estrictamente anterior al límite civil de un mes, pero con **advertencia roja visible y revisión manual obligatoria**. Si todavía existe margen anterior al límite, la interfaz **ofrecerá crear expresamente un aviso de control**, sin crearlo automáticamente y sin superar jamás el tope civil. Si el plazo ya ha transcurrido, no ofrecer agendar retroactivamente ni afirmar que la oposición esté en plazo; advertir y solicitar revisión humana. Registrar la incidencia sin fingir envío/entrega, conservar derechos y permisos de anotación. Esta es decisión funcional C1, **aún no implementada ni validada**: reutilizar cálculo `preview_reminder_plan` y ocurrencias A/B, probar meses cortos, 29/02, límite hoy, cero avisos elegibles, roles y reintentos. Sin migración ni despliegue con esta actualización.


## C1 — Modalidad Vida (aprobada por promotor, 25/10/2026)

Al seleccionar **Vida** mostrar advertencia específica: pueden existir reglas particulares de oposición; no calificar automáticamente el corte general de un mes como plazo legal confirmado para esta modalidad. Mantener avisos configurables y guardado permitido; exigir revisión humana de las condiciones de la póliza, con estado informativo explícito. Permitir el registro manual de respuestas Sí/No conforme al contrato del whitepaper, sin presentarlas como prueba de notificación, autorización o entrega. La implementación C2 deberá revisar el bloqueo conservador actual de `control_response_api.py` y `control_repeat_schedule.py` para ofrecer registro auditado sin automatizar ni certificar un plazo, sujeto a pruebas y revisión jurídica. Decisión documentada; **sin cambios de código ni despliegue** en este registro.


## C1 — «Notificado por mí»: declaración auditada (aprobada 25/10/2026)

El promotor aprueba que, al seleccionar «Sí → Notificado por mí», la interfaz exija **confirmación expresa** del mediador de que dispone de autorización del cliente y de que ha realizado la comunicación. Registrar actor, fecha/hora y alternativa seleccionada, manteniendo la anotación abierta. Es una **declaración del usuario**, no prueba de autorización documental, envío, recepción ni cumplimiento legal. No inventar adjuntos ni certificados; la conservación privada de justificantes queda para la fase de seguridad de archivos, permisos y retención. Debe reutilizarse el modelo/API de respuestas manuales O9b, con pruebas de confirmación, CAS, idempotencia y aislamiento. Esta decisión todavía no está implementada ni probada; no activar entrega ni tocar esquema/DEV con esta actualización.

**C1 restante en la macrofase:** selección, consentimiento, fallos, idempotencia y reintentos de canales reales email/push/local/offline. La entrega requiere diseño y validación independiente; mantener `delivery_status=not_implemented` hasta que exista evidencia fiable.


## C1 — Canales aprobados; cambio expreso de email predeterminado (25/10/2026)

El promotor aprobó móvil (avisos locales incluso sin conexión y app cerrada), navegador con app abierta y permiso, y correo resumen diario; **corrigió expresamente el valor inicial del correo a ACTIVADO por defecto**, modificación posterior y consciente del §7 del whitepaper, que decía desactivado. Adoptar **Resend** como proveedor candidato de VENCIRA, por experiencia con MASBITCOIN (API HTTP con `email_id` y webhooks Svix firmados para delivered/delayed/bounced/complained; originalmente SMTP). Implementación separada con dominio/remitente, credenciales y supresiones propias de VENCIRA; jamás reutilizar claves ni destinatarios de MASBITCOIN. Los permisos legales para comunicaciones, preferencia editable, baja/desactivación sencilla, minimización de datos, contratos de encargo, DNS y validación RGPD/LSSI deben revisarse **antes de activar envíos**. La decisión de default no acredita que sea lícito enviar sin base adecuada: el motor mantendrá entrega deshabilitada hasta gate técnico/jurídico. Reintentos limitados, deduplicación, estados programado/intentado/aceptado/entregado y privacidad lockscreen conforme a propuesta aprobada. Pendiente diseño técnico, implementación, tests y despliegue; sin cambios operativos con esta nota.


## C2 — Correo corporativo y transaccional: arquitectura confirmada (25/10/2026)

El promotor confirma que **vencira.es está contratado en OVHcloud** e incluye una cuenta **Zimbra Starter de 5 GB**. Decisión: usar Zimbra como buzón corporativo para recepción/respuesta y **Resend** exclusivamente para el envío automatizado de resúmenes diarios/notificaciones desde VENCIRA, reutilizando patrones de integración (no credenciales) de MASBITCOIN. Direcciones `contacto@vencira.es` y `avisos@vencira.es` son **ejemplos**, no buzones existentes ni remitentes verificados. Antes de producir envíos: verificar cuenta concreta en OVHcloud, dominio remitente en Resend, SPF/DKIM/DMARC y compatibilidad DNS/MX, subdominio recomendado para aislar reputación transaccional, callbacks/webhooks firmados y supresión de rebotes, límites y consentimiento/base legal. Nunca compartir credenciales, claves ni listas de destinatarios entre proyectos. Correo resumen diario activado inicialmente según decisión del promotor, sujeto a validación de comunicaciones y preferencias. En este hito **solo documentación**: sin accesos a OVH, alteraciones DNS, claves, envíos, migración ni despliegue.


## C2 — Primera entrega de código (25/10/2026)

Implementado en GitHub `backend/reminders/c2_control_policy.py` con pruebas `backend/reminders/test_c2_control_policy.py` (commit de tests `d4d3878b909929021fe1e8a24956da8a58bbb173`). Proyección **pura y sin BD** sobre `preview_reminder_plan`: permitir guardar; evaluar altas tardías, cero aviso pre-corte y corte vencido; ofrecer control explícito solo antes del corte (nunca programarlo por sí misma); Vida exige revisión de términos sin presentar mes civil como límite legal confirmado; conservar únicamente los offsets cuyos avisos no han transcurrido; estados de entrega `not_implemented`. Tests incluyen 29 febrero, meses cortos, límite hoy, tardíos y entradas inválidas. **Pendiente gate real Ubuntu**, integración de endpoints/UI, filtros HOY, evidencias y transportes Resend. No ejecutar migración ni desplegar por este cambio. Usar scripts de pruebas ya existentes, sin repetir B.


## C2 — API solo lectura integrada, pendiente gate Ubuntu (25/10/2026)

Commit `059fac89a1235f5538c9d09ae55302b9a11c81fe`: `control_assessment_api.py` integra la política pura C2 en la ruta GET autenticada ya existente, devolviendo `c2_policy` (guardar, revisión manual, severidad/código, corte informativo no Vida, posible ofrecimiento explícito y último día válido, offsets futuros, `delivery_status=not_implemented`). Se preserva el contrato anterior y se aplica visibilidad del workspace. Commit `1e2541ba4e603b488e9345afb250b18c3756d732`: regresiones del GET normal y borrador sin aviso previo en `test_control_assessment.py`. **No supone programación ni notificación**; integración Flutter, persistencia de revisión y política HOY pendientes. **Sin pruebas ejecutadas todavía**: en Ubuntu correr `bash scripts/validate_o7_o8_preflight.sh` tras sincronizar rama, sin desplegar. No tocar PostgreSQL persistente, backups ni Caddy. Si falla, corregir antes de continuar.


## C2 — Gate integral aceptado y refinamiento visual pendiente de gate (25/10/2026)

El operador aportó marcadores completos del script `validate_o7_o8_preflight.sh`: salud PRE/POST OK, configuración Docker OK, i18n ES/CA OK, build backend aislado OK, comprobación seca de migraciones OK, suite Django SQLite OK, PostgreSQL17 efímero OK, suite Django PG17 OK, Flutter analyze/test/build OK, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`. `NO_SE_DESPLEGO_NI_MIGRO_DB_PERSISTENTE=1` y `SIN_CAMBIOS_OAUTH_RESTIC_CADDY=1`; log privado `/tmp/vencira-o7-o8-preflight.ibm3OwLT.log`. El gate acredita el código **anterior** al siguiente cambio UI, no valida futuros commits.

Refinamiento visual posterior en commit `1756a54f2e9378db6e2ea51ec48da97839bc1fb2` de `control_assessment_card.dart`: avisos de control caducado/ausente más visibles con icono de advertencia del tema; en Vida se oculta la fecha límite general para no presentarla como plazo legal confirmado. **Pendiente nuevo gate completo y aceptación Flutter** antes de desplegar. El contrato `c2_policy` ya está publicado en código de API read-only, pero aún no se consume en el cliente tipado. Sin envío, migración ni deploy nuevos.


## C2 — Segundo gate OK; Flutter tipado posterior (25/10/2026)

El operador aportó recibo integral `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`, `LOCALCHECK_HEALTH_PRE/POST=OK`, `DJANGO_SQLITE_SUITE_COMPLETA=OK`, `DJANGO_POSTGRES17_SUITE_COMPLETA=OK`, `DJANGO_CHECK_MIGRACION_SECA=OK`, `I18N_ES_CA=OK`, `FLUTTER_ANALYZE_TEST_BUILD=OK`, `O7_O8_PREFLIGHT_SIN_DESPLIEGUE=OK`, con `NO_SE_DESPLEGO_NI_MIGRO_DB_PERSISTENTE=1` y `SIN_CAMBIOS_OAUTH_RESTIC_CADDY=1` (log local `/tmp/vencira-o7-o8-preflight.pa7pRnLe.log`). Gate válido para versión anterior al cambio siguiente.

Nuevo commit `cc86f88e6d4adfea320a5c60dadd633bf7635411` añade `VenciraC2Policy` y parser en `clients/flutter/lib/api/vencira_api.dart` para leer el contrato GET `c2_policy`, sin enviar ni persistir; campo opcional para compatibilidad. **Pendiente validación integral después de este commit**. También está pendiente la presentación UX definitiva de los avisos C2 y la confirmación de notificado por mí. No desplegar hasta gate real.


## C2 — Tercer gate OK; tarjeta revisión manual posterior (25/10/2026)

El operador confirma para el gate del modelo Flutter tipado: `LOCALCHECK_HEALTH_PRE/POST=OK`, `CONFIG_COMPOSE=OK`, `I18N_ES_CA=OK`, `BUILD_BACKEND_AISLADO=OK`, `DJANGO_CHECK_MIGRACION_SECA=OK`, `DJANGO_SQLITE_SUITE_COMPLETA=OK`, `PG17_TEMPORAL=OK`, `DJANGO_POSTGRES17_SUITE_COMPLETA=OK`, `FLUTTER_ANALYZE_TEST_BUILD=OK`, `O7_O8_PREFLIGHT_SIN_DESPLIEGUE=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`; log `/tmp/vencira-o7-o8-preflight.r8jDE17f.log`; sin cambios en persistencia, OAuth, Restic o Caddy. Esto valida el commit anterior a la siguiente modificación.

Nuevo commit UI `967f5fa456b233f5608fdde581909cd4c2ec03de`: tarjeta `VenciraControlAssessmentCard` muestra un aviso destacado cuando `c2Policy.manualReviewRequired`, usando textos ES/CA existentes, Material theme y sin acciones simuladas. No se han creado ni enviado avisos. **Requiere gate nuevo antes de deploy**; queda pendiente UI de oferta explícita y proceso de aceptación/revisión, así como aviso de modalidades y canales. No modificar datos reales.


## C2 — Límite estricto de repetición de control (25/10/2026)

Cuarto gate aportado por operador antes del cambio: salud PRE/POST, Compose, i18n ES/CA, backend build, migraciones secas, suites Django SQLite y PostgreSQL17 efímero, Flutter analyze/test/build, todo `OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`, log `/tmp/vencira-o7-o8-preflight.dOMFRUfF.log`; sin despliegue ni cambio en DB persistente, OAuth/Restic/Caddy. Se corrigió la inconsistencia de C2: la fecha de repetición del control debe ser **estrictamente anterior** al corte civil. Cambios: `control_repeat_schedule.py` commit `1a795d01adc8ca3c264a8b04942e862e224170f4`, `operational_schedule.py` commit `4ec0ca7128c8902487da3204ee62d3152380a940`, `control_responses.py` commit `c82894eec5e59bdfbf2c052310dba3a679467ec4`; tests frontera `test_operational_schedule.py` `556552689efda7ad780c1d8125f511a027cfcaba` y `test_control_responses.py` `d02ebe98643b0754b595dc4e9dbd99a81a14fde3`. **Los nuevos commits NO tienen gate ejecutado aún**; revisar suite completa antes de otra integración o deploy. No se ha construido todavía la UI de confirmación ni la acción de crear expresamente un control.


## C2 — Fallo del gate y reparación de test API (26/10/2026)

Gate real informado: `RESULTADO_GLOBAL=1`, `RESULTADO_EJECUCION=1`; suite Django SQLite encontró 235 tests, 1 fallo en `test_no_on_cutoff_is_plan_only_and_conflicts`: el test histórico esperaba HTTP 201 para repetir en 2027-02-28 (día de corte de vencimiento 2027-03-31), mientras la regla C2 aprobada exige día anterior. Se mantuvo el rechazo HTTP 400 y se corrigió exclusivamente la expectativa de regresión en `backend/reminders/test_control_response_api.py`, commit `e99d932a187064613f9d177f7a63cfa9e7047568`: rechazo en día de corte, no persistencia, éxito el 27/02, reintento idempotente y ausencia de entrega. **Gate anterior FALLIDO y nuevo commit pendiente de validar**. No hubo despliegue ni migración persistente; OAuth/Restic/Caddy intactos según recibo. Log local `/tmp/vencira-o7-o8-preflight.1hWeh3yQ.log`.


## C2 — Segundo fallo gate: reloj simulado incoherente (26/10/2026)

Gate informado `RESULTADO_GLOBAL=1`, fallo 1/235 SQLite en `test_no_on_cutoff_rejected_then_prior_day_accepted`: primer POST 201 y repetición igual 409. Diagnóstico: el test parcha fecha civil a 2027-02-25, pero `answered_at` (auto_now_add) queda con el reloj real del host 2026; la comparación idempotente reconstructiva utiliza día de `answered_at`, por eso el reintento artificial falla. Se corrigió el **test** añadiendo mock coherente de `django.utils.timezone.now` a 2027-02-25T12:00 UTC además del mock localdate: commit `505cdfa5bf6897c60a895392cb276202bf039cc0`. Sin cambio de lógica en producción ni migración. **Gate nuevo todavía pendiente**, no desplegar. Registro de fallo `/tmp/vencira-o7-o8-preflight.V6k3p5Z9.log` y ninguna alteración de DB persistente / OAuth / Restic / Caddy.


## C2 — Gate recuperado (26/10/2026)

Operador comunica validación integral de la corrección del reloj simulado (`505cdfa5bf6897c60a895392cb276202bf039cc0`): `LOCALCHECK_HEALTH_PRE/POST=OK`, `CONFIG_COMPOSE=OK`, `I18N_ES_CA=OK`, `BUILD_BACKEND_AISLADO=OK`, `DJANGO_CHECK_MIGRACION_SECA=OK`, `DJANGO_SQLITE_SUITE_COMPLETA=OK`, `PG17_TEMPORAL=OK`, `DJANGO_POSTGRES17_SUITE_COMPLETA=OK`, `FLUTTER_ANALYZE_TEST_BUILD=OK`, `O7_O8_PREFLIGHT_SIN_DESPLIEGUE=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`. Log local `/tmp/vencira-o7-o8-preflight.c6g2NgJO.log`. No despliegue, migración DB persistente ni cambios OAuth/Restic/Caddy. **Este gate valida el código anterior a nuevos cambios C2**. Próxima tarea: acción expresa e idempotente de control con visibilidad de equipo, confirmación, auditoría y sin transporte real.


## C2 — Creación explícita de control interno (26/10/2026; pendiente gate)

Nuevo `backend/reminders/explicit_control_api.py` commit `d2767c9187f51695d175f4e008a033a00ca4c74b` y ruta `POST /api/v1/workspaces/<workspace_id>/renewals/<renewal_id>/explicit-control/` vía `urls.py` commit `4e8f14acd0cd3dcbbf120546c16d08178a7e832c`. Exige auth y alcance del workspace, payload JSON `{confirmed:true, scheduled_for:YYYY-MM-DD, idempotency_key:UUID}`, bloqueo transaccional de anotación, fecha futura o actual anterior al corte civil, política C2 `offer_explicit_control`, excluye Vida y corte vencido. Genera únicamente `OperationalReminder` interno y `OperationalReminderEvent` con actor; reintentos misma clave → misma ocurrencia, fecha distinta → 409, doble creación mismo día → 409. No envía notificaciones ni acredita entrega. Tests en `backend/reminders/test_explicit_control_api.py` commit `82f14d4963f26853ed2c542d5cd2a0793f221257` cubren confirmación, duplicado, idempotencia, fechas frontera, equipo y Vida. Gate anterior `RESULTADO_GLOBAL=0` log `/tmp/vencira-o7-o8-preflight.c6g2NgJO.log` solo valida código previo. **Esta operación nueva no ha superado aún gate Django SQLite/PG17 y Flutter**; no desplegar ni ejecutar migraciones persistentes. Falta conectar Flutter con confirmación UX y mostrar resultado.


## C2 — Gate de aviso explícito OK e integración Flutter pendiente (26/10/2026)

El operador comunicó gate `LOCALCHECK_HEALTH_PRE/POST=OK`, `CONFIG_COMPOSE=OK`, `I18N_ES_CA=OK`, `BUILD_BACKEND_AISLADO=OK`, `DJANGO_CHECK_MIGRACION_SECA=OK`, `DJANGO_SQLITE_SUITE_COMPLETA=OK`, `PG17_TEMPORAL=OK`, `DJANGO_POSTGRES17_SUITE_COMPLETA=OK`, `FLUTTER_ANALYZE_TEST_BUILD=OK`, `O7_O8_PREFLIGHT_SIN_DESPLIEGUE=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`, log `/tmp/vencira-o7-o8-preflight.GorM69zX.log`; no despliegue, migración DB persistente ni alteraciones OAuth/Restic/Caddy. Gate valida API explícita, no los nuevos commits.

Nuevos commits Flutter: API `dabe64737eab9fb62b7bf42b1cfa3f5bd6f7d02e` añade `createExplicitControl` al contrato e implementación same-origin, CSRF, control de estados y respuesta sin delivery; UI `1a34ca4b257953b7bbad69ec642e12b6aef986ff` muestra crear control solo si la política lo ofrece, selector de fechas en intervalo permitido, diálogo confirmación ES/CA, confirmación de aviso interno sin entrega y recarga. **PENDIENTE gate real completo de estos commits, pruebas UI específicas y aceptación móvil**. No habilitar canales ni desplegar todavía.


## C2 — Gate integración Flutter OK y test móvil posterior (26/10/2026)

El operador reportó gate integral `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`, suites Django SQLite/PG17, Flutter analyze/test/build e i18n ES/CA OK, salud pre/post OK; log `/tmp/vencira-o7-o8-preflight.Fn8LRLdg.log`. Sin despliegue ni migración persistente ni cambios OAuth/Restic/Caddy. Gate cubre API+Flutter hasta `1a34ca4b257953b7bbad69ec642e12b6aef986ff`.

Nuevo commit **posterior al gate** `6fbb41e8d822739ff7e9f59bcd1b907df21994ce` añade test widget `control_assessment_test.dart` (320px ES/CA) para verificar que el selector de fecha de control explícito se abre y que cancelarlo no realiza escritura. **Gate nuevo pendiente antes de desplegar**. No confundir pasar test general con validación visual en dispositivo real. Pendientes pruebas de diálogo confirmado y reintentos UI, revisión premium móvil, entrega Resend deshabilitada.


## C2 — Gate Flutter fallido por navegación del test; corrección 26/10/2026

El operador informa `RESULTADO_GLOBAL=1` en `FLUTTER_ANALYZE_TEST_BUILD`: 2 tests ES/CA de cancelación fallaron porque `tester.pageBack()` exige `CupertinoNavigationBarBackButton`, ausente en el selector Material; no se observa escritura o fallo de servidor. Log `/tmp/vencira-o7-o8-preflight.xi9jfhku.log`. El test `clients/flutter/test/control_assessment_test.dart` se corrigió para cerrar la ruta Material mediante `Navigator.of(tester.element(find.byType(DatePickerDialog))).pop()` sin depender del idioma, commit final `d57b8b3d45a607a751d388eba3b58d86ec660d98` (supersede tentativa anterior `658955e44b29d5d3fe694b57f7b63c58e5e5947b`). **Pendiente nuevo gate real**. No despliegue, migración de DB persistente ni alteración OAuth/Restic/Caddy según salida.


## C2 — Gate de cancelación aprobado y test de confirmación positiva (26/10/2026)

El operador confirma `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`, con pre/post salud, Compose, i18n ES/CA, build backend, migraciones secas, suites completas Django SQLite y PostgreSQL17 temporal, Flutter analyze/test/build OK. Log `/tmp/vencira-o7-o8-preflight.lbfaSxgo.log`; `NO_SE_DESPLEGO_NI_MIGRO_DB_PERSISTENTE=1`, `SIN_CAMBIOS_OAUTH_RESTIC_CADDY=1`. Este gate valida el código **antes** del test nuevo.

Commit `509c34d333dcd01e9f91c689f8db08fdbece6847` añade test widget Flutter (320px, ES/CA) de flujo positivo de aviso expreso: selección de fecha, confirmación secundaria, cancelar sin llamada, confirmar con una sola llamada a fake API. **Pendiente gate nuevo**; sin cambios de backend/BD ni envío. Después revisar riesgo de duplicación de intentos reales y visualización móvil antes de permitir despliegue.


## C2 — Timeout en test de confirmación Flutter (26/10/2026)

El gate comunicado falló (`RESULTADO_GLOBAL=1`) en dos tests widget ES/CA de `control_assessment_test.dart` por `pumpAndSettle timed out` en línea 170, tras confirmar la creación; no consta fallo de Django ni evidencia de entrega. Log `/tmp/vencira-o7-o8-preflight.HoAWE8qd.log`. Se reemplazó **solo** la espera global del test de confirmación positiva por `pump()` y avance acotado de 250 ms, manteniendo la aserción de exactamente una llamada fake API; commit `fc9eb5f2fafa6b44634b0b043c1b05589189bc84`. Hipótesis: frame continuado por indicador de progreso. **Gate nuevo pendiente; no afirmar éxito**, ni desplegar o tocar base persistente, Resend, OAuth/Restic/Caddy.


## C2 — Gate de confirmación positiva aprobado (26/10/2026)

El operador confirma gate completo tras commit `fc9eb5f2fafa6b44634b0b043c1b05589189bc84`: `LOCALCHECK_HEALTH_PRE/POST=OK`, `CONFIG_COMPOSE=OK`, `I18N_ES_CA=OK`, `BUILD_BACKEND_AISLADO=OK`, `DJANGO_CHECK_MIGRACION_SECA=OK`, `DJANGO_SQLITE_SUITE_COMPLETA=OK`, `PG17_TEMPORAL=OK`, `DJANGO_POSTGRES17_SUITE_COMPLETA=OK`, `FLUTTER_ANALYZE_TEST_BUILD=OK`, `O7_O8_PREFLIGHT_SIN_DESPLIEGUE=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`. Log local `/tmp/vencira-o7-o8-preflight.CbSYTpyn.log`. No despliegue ni cambio en DB persistente, OAuth/Restic/Caddy. Queda validado el test ES/CA de confirmación de aviso interno, sin entrega real; pendiente aceptación visual móvil y revisión de reintentos ante respuestas ambiguas antes de desplegar.


## C2 — Reintentos ante respuesta ambigua (26/10/2026)

Gate anterior confirmado por operador: SQLite, PG17 efímero, Flutter, ES/CA, checks y salud pre/post `OK`; `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`, log `/tmp/vencira-o7-o8-preflight.CbSYTpyn.log`; sin desplegar ni alterar DB persistente, OAuth/Restic/Caddy. Nuevo commit Flutter `dfd35ee942247b82cc0705ae2c10509e414d8550`: al enviar una creación explícita se conserva fecha + UUID de idempotencia en la tarjeta; ante error de transporte o respuesta incierta se muestra reintentar **la misma** petición (mismo UUID/fecha), se inhabilita nueva creación en esa instancia hasta resolver y no se afirma éxito. Tras respuesta aceptada se borra el token y recarga la evaluación. Se descarta al cambiar de anotación. Nuevo test widget `b10bc255e6df373a915eb23866ad3c483c0f9c02` simula fallo de primera respuesta y comprueba el UUID idéntico al repetir. **Ambos commits requieren gate completo**, además de revisión de permisos/fallo red y UX móvil antes de despliegue. Nota: persistencia del UUID solo en memoria durante la vista; después de recarga del navegador, reconciliar mediante historial/servidor antes de crear de nuevo. Resend sigue deshabilitado.


## C2 — Gate 26/10/2026: Flutter analyzer warnings y corrección

Operador reporta gate `RESULTADO_GLOBAL=1`, `FASE_FALLIDA=FLUTTER_ANALYZE_TEST_BUILD`. Django SQLite: 239 tests OK; Django PG17 temporal: 239 tests OK; Compose, migraciones secas, i18n ES/CA, backend y salud PRE OK. Flutter `analyze` abortó por dos warnings `unused_field` en `control_assessment_card.dart`: `_createError` y `_createConflict` ya no se leen tras refactor de reintentos. Commit corrector `9e3298a25f6c6610479dc928e91cefd39bf95b05` elimina campos/asignaciones obsoletas manteniendo clave UUID y fecha para reintento. **Pendiente nuevo gate**; no desplegar. Log `/tmp/vencira-o7-o8-preflight.GJ2C0SSo.log`, sin migración DB persistente ni cambios OAuth/Restic/Caddy.


## C2 — Gate de reintentos validado (26/10/2026)

Operador confirma `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`, con Compose, i18n ES/CA, build backend, comprobación de migraciones secas, suite Django SQLite, PostgreSQL 17 temporal, Flutter analyze/test/build, salud pre/post OK. Log `/tmp/vencira-o7-o8-preflight.uU9vPtFl.log`; `NO_SE_DESPLEGO_NI_MIGRO_DB_PERSISTENTE=1`, `SIN_CAMBIOS_OAUTH_RESTIC_CADDY=1`. El archivo Flutter de flags obsoletos fue corregido y commit/push desde Ubuntu (`COMMIT_RESULT=0`, `PUSH_RESULT=0`) porque el intento previo de actualización remota no quedó reflejado; consultar `git log` para SHA real si se necesita. **Estado: gate superado, sin despliegue.** Sigue pendiente reconciliación tras recarga total del navegador, inspección UX en dispositivo real y autorización para cualquier despliegue DEV. Resend deshabilitado.


## C2 — Reconciliación tras recarga del navegador (26/10/2026; gate pendiente)

Se confirmó gate anterior de reintentos `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0` log `/tmp/vencira-o7-o8-preflight.uU9vPtFl.log`; sin despliegue ni migraciones persistentes. Nuevos commits: backend lectura `632733f8f989f98a2e5685424da4ff5c338b2a8f` expone `explicit_control_existing` en evaluación de control mediante ocurrencias explícitas activas; backend escritura `b41156289e5c47b488362dd9754a863ebb5e9f57` rechaza cualquier segunda creación explícita activa, incluso en otra fecha; Flutter DTO `417c4fc06e228f93cbf24e6f01b769777b7440fe`, UI `4bc73b0d167890b257c4018e22362a19603a8b91` muestra aviso existente al abrir/refrescar ficha y oculta botón de nueva creación; tests backend `69190bb1c0e90cd8dde3aeef8ecd33b404be66b6`, Flutter `8d8547d2d7d724508e92c579f51f875a04d6ddd1`. No se envía nada externamente. **Gate integral pendiente tras estos cambios.** Limitación: ausencia de persistencia de token UUID después de recarga; la reconciliación evita duplicar un aviso activo, pero los casos cancelado/completado o carreras requieren revisión en fase posterior. Queda pendiente aceptación visual real de móvil y despliegue con autorización.


## C2 — Gate reconciliación navegador OK (26/10/2026)

Operador confirma gate completo: LOCALCHECK_HEALTH_PRE/POST, CONFIG_COMPOSE, I18N_ES_CA, BUILD_BACKEND_AISLADO, DJANGO_CHECK_MIGRACION_SECA, DJANGO_SQLITE_SUITE_COMPLETA, PG17_TEMPORAL, DJANGO_POSTGRES17_SUITE_COMPLETA, FLUTTER_ANALYZE_TEST_BUILD y O7_O8_PREFLIGHT_SIN_DESPLIEGUE = OK; RESULTADO_GLOBAL=0, RESULTADO_EJECUCION=0. Log `/tmp/vencira-o7-o8-preflight.pGCRfpW1.log`. Sin despliegue ni migración DB persistente, sin cambios OAuth/Restic/Caddy. Valida lectura de aviso explícito activo en la evaluación, rechazo backend de duplicado activo y supresión de creación en Flutter después de refrescar. **Pendiente** conciliación exacta de solicitud completada/cancelada tras reinicio, prueba visual móvil real y autorización formal para desplegar en dev.vencira.es. No activar Resend.


## C2 — Historial de control después de recarga, incluido completado/cancelado (26/10/2026; gate pendiente)

A partir del último gate exitoso `/tmp/vencira-o7-o8-preflight.pGCRfpW1.log`, se añadieron: `control_assessment_api.py` GET devuelve `explicit_control_latest` (id, state, scheduled_for, delivery_status=not_implemented) para el último aviso explícito, incluso completado o cancelado, sin acreditar envío (`4370e53b5b0a49e50051c84f304bf28d3978110d`); Flutter tipado `369056ca692f04af690b6642dc32ae442713f7b6` y card `5d587e1397ca003ed692b48220e962c493778947` muestran estado histórico e impiden nueva creación automática si hay aviso anterior; test widget `eeb90e531d080c8e314a247fb190dd121b5eeba8` y Django `d76d84bc93aaaee4adcc1f8eb34db60c6d64246e` comprueban caso completado. No se reutiliza ni divulga UUID de solicitud para recuperación automática: tras recarga hay revisión manual informada de historial, incluso si la ocurrencia no está activa. Diferenciar evento interno de entrega real. **Los commits NO están validados todavía en Ubuntu: ejecutar gate O7/O8 antes de despliegue.** Sigue pendiente inspección visual real y requisitos de autorización. Ningún envío externo, modificación de DB persistente ni despliegue.


## C2 — Gate historial completo aprobado (26/10/2026)

Operador aporta validación aislada completa: `LOCALCHECK_HEALTH_PRE/POST=OK`, `CONFIG_COMPOSE=OK`, `I18N_ES_CA=OK`, `BUILD_BACKEND_AISLADO=OK`, `DJANGO_CHECK_MIGRACION_SECA=OK`, `DJANGO_SQLITE_SUITE_COMPLETA=OK`, `PG17_TEMPORAL=OK`, `DJANGO_POSTGRES17_SUITE_COMPLETA=OK`, `FLUTTER_ANALYZE_TEST_BUILD=OK`, `O7_O8_PREFLIGHT_SIN_DESPLIEGUE=OK`; `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`. Log local `/tmp/vencira-o7-o8-preflight.3whoQRF7.log`. Se valida hasta la reconciliación de avisos explícitos activos/completados/cancelados según suite vigente, sin afirmar acreditación de entrega, recuperación exacta de token tras recarga o aceptación visual física. `NO_SE_DESPLEGO_NI_MIGRO_DB_PERSISTENTE=1`, `SIN_CAMBIOS_OAUTH_RESTIC_CADDY=1`. Próximo punto: UX móvil real / eventual despliegue controlado solo con autorización explícita. Resend no habilitado.


## 26/10/2026 — C2: preparación despliegue DEV, diagnóstico únicamente

El usuario autoriza avanzar a preparación de publicación DEV. Revisión del procedimiento histórico: `scripts/deploy_o9a_no_migrations.sh` y `scripts/deploy_o7_o8_no_migrations.sh` contienen hashes `VALIDATED` y expectativas de esquema de fases anteriores y **no son aptos para ejecutarse directamente con código C2**. Se crea `scripts/c2_deploy_readiness_readonly.sh`, commit `5bb4707cf5118c625d769c40aa8aec9d1370155c`, que comprueba rama y limpieza, Compose, identidad/salud de contenedores, comando check-only de migración, última migración instalada mediante SELECT, disponibilidad de imágenes anteriores, estado O5 y HTTP HTTPS; no recrea, migra ni altera configuración. Requiere ejecutar en Ubuntu y examinar sus resultados **antes de crear/ejecutar script de despliegue** con pin exacto del gate C2 y respaldo/rollback probado. Validación C2 anterior: `RESULTADO_GLOBAL=0`, log `/tmp/vencira-o7-o8-preflight.3whoQRF7.log`. Este nuevo script NO forma parte de aquel gate y aún no tiene ejecución confirmada. Sin despliegue ni migraciones, Resend apagado, pendiente aceptación visual móvil real.


## 26/10/2026 — Auditoría DEV C2 aprobada y rollout 0018 preparado, NO ejecutado

El operador confirmó `C2_READINESS_READONLY=OK`, `RESULTADO_AUDITORIA=0`, `NO_DEPLOY_NO_MIGRATION=1`, SHA fuente `42cd493e5655a2c7cdee312bedc7cb7466bee84b`; Compose, salud api/db/web, migraciones check-only, imágenes locales, HTTPS y O5 backups OK. Esquema persistente **0018_draft_reasons** (los desplegadores antiguos 0015 no sirven). Se creó `scripts/deploy_c2_no_migrations.sh` commit `7db6bc12861b4955e6324daf6c64f77f9fca33ca` basado en rollout O9a con pin al SHA C2 y comprobación esquema 0018, preserva imágenes y recibo, no migra/reinicia db, exige O5, check-only de migraciones, publica solo API+web de localcheck y comprueba health/HTTP. Gate estático separado `scripts/check_c2_deploy_static.sh` commit `34e358c5a3e28f29414cf793a62b4ffa2a16cc00`; existen los dos archivos en remoto verificados. **NO se ha ejecutado gate estático ni despliegue**. Siguiente: sincronizar rama y ejecutar únicamente gate estático; revisar resultado antes de ordenar despliegue real. UI móvil aún sin aceptación real; Resend apagado. No compartir secretos, recibos privados ni logs completos.


## 26/10/2026 — Refinamiento UX móvil en avisos, pendiente gate

El usuario aportó capturas de ficha de anotación y señaló que la zona de avisos es confusa: demasiadas tarjetas encadenadas, simulador, borrador, evaluación, respuesta y programación a la vista, duplicidad de información y jerarquía visual insuficiente. Se reorganizó exclusivamente `clients/flutter/lib/ui/renewal_detail_screen.dart`: punto de entrada renombrado «Avisos y control» ES / «Avisos i control» CA, contenido en tres apartados progresivos: 1. Configurar avisos (borrador + ocurrencias), 2. Control de no renovación (evaluación + respuesta), 3. Simulación de fechas (herramienta secundaria); primer apartado inicialmente expandido, los demás contraídos y aviso general de ausencia de envíos externos. Commits `048252f722e664c7ac625d1d86bb15356a69c283`, `2664174e7d44a2a9eb5ef21d80f4d9b662a132b4`, `ea435a83f2e8a214cc1ba2b56ac1b35be1d68701`. Ninguna API, regla legal, DB ni envío alterados. **Cambios en GitHub; falta gate integral Ubuntu y aceptación visual del nuevo diseño; no se han desplegado.** C2 anterior funcionaba y fue aceptada en DEV por el usuario, pero esta iteración UX posterior queda pendiente.


## 26/10/2026 — Gate UX «Avisos y control» aprobado, SIN deploy

El operador confirma tras agrupar la sección en Configurar avisos / Control de no renovación / Simulación de fechas: `CONFIG_COMPOSE=OK`, `I18N_ES_CA=OK`, `BUILD_BACKEND_AISLADO=OK`, `DJANGO_CHECK_MIGRACION_SECA=OK`, `DJANGO_SQLITE_SUITE_COMPLETA=OK`, `PG17_TEMPORAL=OK`, `DJANGO_POSTGRES17_SUITE_COMPLETA=OK`, `FLUTTER_ANALYZE_TEST_BUILD=OK`, `LOCALCHECK_HEALTH_POST=OK`, `O7_O8_PREFLIGHT_SIN_DESPLIEGUE=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`. Log `/tmp/vencira-o7-o8-preflight.cCw8kPZo.log`. No despliegue, no migraciones persistentes, sin cambios OAuth/Restic/Caddy. Próximo paso: desplegar solo versión UI tras pin a commit de fuentes validadas y revalidar imágenes/backup/esquema 0018, luego inspección móvil. La UX nueva NO está aún publicada.


## 26/10/2026 — Ajuste premium UX solicitado, gate y despliegue pendientes

Tras capturas del móvil el promotor pidió: subapartados 1/2/3 dentro de «Avisos y control» más estrechos que su panel padre, para distinguir la jerarquía; quitar botón ancho «Editar vencimiento» de ficha de anotación; añadir lápiz de edición en tarjetas de Agenda diaria consistente con Inicio. Se modificó solo Flutter: `clients/flutter/lib/ui/renewal_detail_screen.dart` commit `e650333004a7a5304522b58459b13b5332f2c715` con `Padding(horizontal:14, vertical:6)` + `Card.outlined` para cada subapartado, elimina CTA y ofrece modo opcional `openEditorOnLoad` para abrir editor tras cargar detalle. `clients/flutter/lib/ui/day_agenda_screen.dart` commit `fdfd74016b9513cfeffa1c5825685bcde2a9c531` añade lápiz en tarjetas abiertas que navega a ficha y abre diálogo existente, sin duplicar persistencia, recargando Agenda al regresar. **Ningún gate ejecutado aún tras estos cambios. No desplegar** hasta comprobar tests Flutter, Django y esquema con preflight. Último DEV desplegado anterior al ajuste. Solo datos DEMO, sin cambiar backend, DB, OAuth, Caddy, Resend ni O5.


## 26/10/2026 — Corrección UX agenda y avisos (gate pendiente)

El promotor aportó capturas tras publicación de jerarquía C2: el botón grande «Editar vencimiento» persistía, el lápiz de tarjetas de Agenda abría el editor sobre la ruta de Ficha y dejaba la ficha abierta después de Cancelar/Guardar, y los subapartados de Avisos tenían un segundo borde de tarjeta superpuesto. Se corrigió `clients/flutter/lib/ui/renewal_detail_screen.dart` commit `82c5136d9a78736c06b7248f46a4df26720b59e6`: eliminar CTA grande redundante y dejar los tres subapartados indentados con `Divider` y `ExpansionTile` sin `Card.outlined` adicional. Se corrigió `clients/flutter/lib/ui/day_agenda_screen.dart` commit `a90563b803e7221563f370940545887aeab2822a`: el lápiz abre `VenciraRenewalEditor` directamente desde Agenda (consultas de detalle, modalidades y aseguradoras con la API existente), guarda y refresca Agenda, mientras Cancelar cierra solo el diálogo, sin entrar a Ficha. Pulsar cuerpo tarjeta continúa abriendo Ficha. **Gate integral pendiente. Ningún despliegue ni migración DB persistente tras estos commits.** Los tests vigentes aún deben confirmar integración ES/CA y Flutter analyze/test/build.
