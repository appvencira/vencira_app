> **07/11/2026 — API ADJUNTOS: AUTORIZACIÓN AUTENTICADA PASS:** operador confirma `ATT_API_PG17_TEST_SESSIONS=OK`, `ATT_API_AUTHORIZED_METADATA=PASS`, `ATT_API_CROSS_SCOPE_DENIED=PASS`, `ATT_API_WRITES_AND_DOWNLOADS_FENCED=PASS`, `ATT_API_FIXTURE_COUNTS_UNCHANGED=PASS`, `ATT_API_FIXTURE_CLEANUP=OK`, `ATT_API_PG17_ROLLBACK=OK`, `ATT_API_LIVE_CONTAINERS_UNCHANGED=OK`, `ATT_API_AUTH_SCOPE_RESULT=PASS`, `ATT_API_AUTH_LOCAL_RESULT=0`. Imagen candidata exacta `vencira-attachment-api-candidate:f8efc90a2647`; base histórica `4eb0130d`. Es prueba **en PG17 desechable y Client.force_login**, no autenticación HTTP real ni deploy. Sin cambios API/DB DEV. Comparación actual GitHub `main...feature/m3-android-local-notifications`: `diverged`, 3726 ahead, 17 behind, 300 archivos truncados; PR #17 draft. NO fusionar masivamente; separar integración de release. `MFA_RELEASE_AUTHORIZED=NO`; `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

---

> **07/11/2026 — API ADJUNTOS CANDIDATA PG17/HTTP ANÓNIMO PASS:** operador confirmó `ATT_API_PG17_READY=YES`, `ATT_API_PG17_DJANGO_CHECK=OK`, `ATT_API_PG17_MIGRATION_PLAN=OK`, `ATT_API_PG17_MIGRATE=OK`, `ATT_API_PG17_MFA_APPLIED=0`, `ATT_API_PG17_INDEPENDENT_TABLE=OK`, `ATT_API_HTTP_ANONYMOUS_DENIED=OK`, `ATT_API_HTTP_ANONYMOUS_DETAIL_DENIED=OK`, `ATT_API_PG17_ROLLBACK=OK`, `ATT_API_LIVE_CONTAINERS_UNCHANGED=OK`, `ATT_API_PG17_EXACT_CANDIDATE_RESULT=PASS` y `ATT_API_PG17_LOCAL_RESULT=0`. Imagen exacta `vencira-attachment-api-candidate:f8efc90a2647`; no hubo despliegue ni migraciones DEV. Gate de sesiones simuladas y aislamiento entre organizaciones publicado como `scripts/backend_attachment_api_auth_scope_pg17.sh` (commit `8a44e39b`), pendiente ejecución. No fusionar/desplegar todavía.

---

> **07/11/2026 — API ADJUNTOS CANDIDATA BUILD PASS, PG17/HTTP PENDIENTES:** operador confirmó base histórica `4eb0130d`, fuente `f8efc90a`, imagen `vencira-attachment-api-candidate:f8efc90a2647`, `ATT_API_CANDIDATE_HISTORICAL_MIGRATIONS=0018_ONLY`, `ATT_API_CANDIDATE_IMAGE_BUILD=OK`, `ATT_API_CANDIDATE_DJANGO_CHECK=OK`, `ATT_API_CANDIDATE_LIVE_CONTAINERS_UNCHANGED=OK`, `ATT_API_CANDIDATE_BUILD=PASS`, `ATT_API_BUILD_RESULT=0`; API/DB DEV sin cambios. Publicado gate siguiente `scripts/backend_attachment_api_candidate_pg17_http.sh` para ejecutar **esa imagen exacta**, migraciones PG17 efímeras y denegación HTTP anónima (pendiente validación local). **No habilitar release ni MFA.**

---

> **07/11/2026 — PG17 ADJUNTOS PASS Y CANDIDATA API RECORTADA:** ensayo con Postgres 17 temporal validado: migración independiente desde `reminders.0018`, 0 migraciones MFA, creación y rollback correcto, live API/DB/web intactos. Publicado `scripts/backend_attachment_api_candidate_build.sh` que construye **sin deploy** una API a partir del checkout backend vivo 0018 y solo el módulo de metadatos de adjuntos. No empaquetar la rama Android completa. **Validación de build candidato pendiente.** Ver [BACKEND_DEV_RELEASE_SPLIT_2026-11-07.md](BACKEND_DEV_RELEASE_SPLIT_2026-11-07.md). `MFA_RELEASE_AUTHORIZED=NO`; `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

---

> **07/11/2026 — ADJUNTOS: PARIDAD DE MIGRACIONES PASS:** el operador confirmó `ATTACHMENT_DRYRUN_MODEL_MIGRATION_PARITY=YES` y `No changes detected in app 'renewal_attachments'` con imagen candidata (no API antigua), sin modificaciones DEV. Publicado `scripts/backend_attachment_split_pg17_isolated.sh` para ensayo **PG17 temporal** de migración independiente desde `reminders.0018`, verificación ausencia de MFA y rollback en BD desechable; ejecución local pendiente. **No desplegar en DEV** hasta separar el candidato operativo de flags `VENCIRA_ENV=test`. Detalle en [BACKEND_DEV_RELEASE_SPLIT_2026-11-07.md](BACKEND_DEV_RELEASE_SPLIT_2026-11-07.md).

---

> **07/11/2026 — ADJUNTOS: AISLAMIENTO YA EXISTE EN TEST:** el operador confirmó `BACKEND_DEPENDENCY_RESULT=0`, `0027` exige las 8 migraciones MFA 0019–0026; no GO. La fuente ya dispone de `backend/renewal_attachments` con `0001_initial` independiente de MFA (base `reminders.0018`), pero restringido explícitamente a `VENCIRA_ENV=test`, con modelo histórico paralelo aún en `reminders`. **No crear otra app; adaptar/ensayar la separación existente, sin autorizar deploy.** Comprobador read-only publicado `scripts/backend_attachment_split_release_readonly.py`. Referencia [BACKEND_DEV_RELEASE_SPLIT_2026-11-07.md](BACKEND_DEV_RELEASE_SPLIT_2026-11-07.md).

---

> **07/11/2026 — BACKEND DEV NO-GO HASTA SEPARAR MIGRACIONES:** inventario ejecutado: 27 migraciones en fuente, 18 aplicadas en DEV, **9 pendientes**: `0019`–`0026` MFA y `0027_renewal_attachment_metadata`. Se verificó en fuente que `0027` **depende de 0026**, de modo que no puede desplegarse selectivamente sin arrastrar toda la cadena MFA. No usar `--fake` ni `migrate 0027`. La API de adjuntos actual solo expone metadatos y bloquea subida/descarga/borrado. Publicados análisis y gate AST read-only `scripts/backend_dev_release_dependency_gate.py` (ejecución local pendiente); ver [BACKEND_DEV_RELEASE_SPLIT_2026-11-07.md](BACKEND_DEV_RELEASE_SPLIT_2026-11-07.md). **`NO_DEPLOY_NO_LIVE_MIGRATION=1`**, frontend WEB V2 desplegado intacto. Próximo desarrollo: candidato separado de adjuntos con grafo de migraciones propio, validación PG17 efímera/O5 y autorización de migración independiente.

---

> **CORTE BACKEND DEV — INICIADO 07/11/2026:** despliegue web V2 ya aceptado manualmente, próximo objetivo actualizar funciones backend independientes de MFA. Se ha publicado `scripts/backend_dev_schema_inventory_readonly.py` para comparar migraciones `reminders` fuente vs aplicadas sin modificarlas; **ejecución local pendiente**. En backend fuente hay 7 rutas ausentes del API actual (MFA 4, adjuntos 2, preview avisos 1); no desplegar backend Android completo. También se corrigió un error latente en rama rollback del script web-only (`b899d1f6`), sin alterar servidor. Detalle en [WEB_DEV_VISUAL_DEPLOY_READINESS_2026-11-06.md](WEB_DEV_VISUAL_DEPLOY_READINESS_2026-11-06.md). `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

---

> **WEB DEV — revisión navegador completada, 06/11/2026:** tras despliegue `WEB_RELEASE_MODE_RESULT=PASS:deploy` para la imagen `vencira-web-candidate:308c69da24aa`, el operador respondió «Done» a la revisión manual de DEV. **`WEB_DEV_BROWSER_REVIEW=OPERATOR_DONE`**, sin informe separado por pantalla ni UAT exhaustiva demostrada; API/DB no modificadas. Estado y límites en [WEB_DEV_VISUAL_DEPLOY_READINESS_2026-11-06.md](WEB_DEV_VISUAL_DEPLOY_READINESS_2026-11-06.md). Próximo corte: nuevas funciones web/API compatibles con backend actualizado y gate propio; no habilitar MFA G14-E2 ni ejecutar migraciones no aprobadas.

---

> **WEB DEV DESPLEGADA — 06/11/2026:** el operador ejecutó despliegue **exclusivamente web_preview**, con `WEB_RELEASE_POSTCHECK=PASS`, `WEB_RELEASE_API_DB_IMAGES_UNCHANGED=YES`, `WEB_RELEASE_MODE_RESULT=PASS:deploy`, `WEB_DEV_DEPLOY_RESULT=0` y `NO_LIVE_DB_MIGRATION=1`. Imagen publicada `vencira-web-candidate:308c69da24aa` (fuente `308c69da24aa7c75502d132e28645d9b1150c1ef`); imagen previa `sha256:9de96e4a9a3ae18b13dbcfbb6c2a25857d7511df3840c4851c6400223136eaf1`, prevista para rollback. **`WEB_DEV_WEB_ONLY_DEPLOY=PASS_OPERATOR_VERIFIED`; `WEB_DEV_BROWSER_UAT=PENDING`**. API/DB conservadas; no hay autorización MFA/adjuntos. PR #17 sigue sin merge. Detalle [WEB_DEV_VISUAL_DEPLOY_READINESS_2026-11-06.md](WEB_DEV_VISUAL_DEPLOY_READINESS_2026-11-06.md). No repetir despliegue; siguiente paso revisión visual y funcional con sesión DEMO.

---

> **WEB DEV — COMPATIBILIDAD PENDIENTE (06/11/2026):** candidata aislada compilada PASS en SHA `ce136348...`, pero comparación con API real: 39 rutas candidatas, 32 desplegadas, **7 faltantes** (MFA 4, adjuntos 2, preview avisos 1). La imagen antigua `vencira-web-candidate:ce1363481947` NO debe desplegarse: la ficha solicitaba adjuntos ausentes. Se publicó gate por defecto `VENCIRA_WEB_ATTACHMENTS_ENABLED=false` y verificación de rutas de UI/MFA en `scripts/web_dev_legacy_api_guard.py`; falta pasar guard, recompilar candidata y verificar las 32 rutas compartidas antes de despliegue web-only/rollback. Infraestructura y O5 PASS; sin deploy ni migración. Detalle: [WEB_DEV_VISUAL_DEPLOY_READINESS_2026-11-06.md](WEB_DEV_VISUAL_DEPLOY_READINESS_2026-11-06.md).

---

> **PUBLICACIÓN VISUAL DEV — 06/11/2026 (prioridad acordada):** el usuario quiere ver pronto las mejoras en `https://dev.vencira.es`, pero sin vulnerar seguridad. Comparación GitHub `main...feature/m3-android-local-notifications` = `diverged`, 3653 commits por delante, 17 por detrás, inventario truncado a 300 archivos: **prohibido desplegar directamente esta rama o fusionar PR #17 para mostrar UI**. Los antiguos scripts `deploy_o7_o8_no_migrations.sh` y `deploy_o8c_0015_guarded.sh` dependen de commits/esquemas históricos; **no ejecutarlos**. Plan de candidata **web-only** y gates en **[WEB_DEV_VISUAL_DEPLOY_READINESS_2026-11-06.md](WEB_DEV_VISUAL_DEPLOY_READINESS_2026-11-06.md)**. Falta baseline real del VPS, selección mínima de cambios UI, test/build web, prueba de rollback y autorización operativa. No se ha desplegado ni probado producción. G15 permanece cerrado; MFA E2 pendiente.

---

> **TRASPASO VIGENTE — 06/11/2026, G15 CERRADO EN LABORATORIO.** Leer primero **[HANDOFF_ANDROID_G15_CLOSED_2026-11-06.md](HANDOFF_ANDROID_G15_CLOSED_2026-11-06.md)**: consolida B2-A (firma estática), B2-B (10/10 Flutter + N1), B2-C (13/13 transporte + 2/2 auditoría), B2-D (manifiesto G13), B2-E/G15 (4/4 tests, N1, compilación debug, manifiesto sin INTERNET, permisos, aviso real en Android y cancelación y entrega tras reinicio confirmadas por el operador). **G15_LAB=COMPLETE_WITH_SCOPE_LIMITS**; no repetir validaciones. **BETA FUNCIONAL=NO GO**: G14-E2 aún no implementado, E3 pendiente, integración Android operativa, firma release real y aprobaciones B3 pendientes. Los párrafos antiguos que indiquen G15 pendiente o `release` firmado con debug son históricos y NO representan el estado actual. `MFA_RELEASE_AUTHORIZED=NO`; `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

---



> **B2-B publicado, validación pendiente (06/11/2026):** cuatro regresiones Flutter de arranque de avisos y cambio de ámbito, control N1 `android_beta_b2b_startup_recovery_regressions`. Ejecutar **una única vez** el test widget dirigido y N1 sobre nuevo HEAD; no repetir PG17, G13 ni build Android. No se ha habilitado autenticación nativa ni datos reales.

---



> **B2-A — Firma Android sin debug (06/11/2026):** publicado cambio en `clients/flutter/android/app/build.gradle.kts` para impedir firma `release` con claves debug y exigir cuatro parámetros de entorno externos. Cuatro pruebas estáticas y N1/CI integrados, pero **sin ejecución local todavía**. No existe APK beta firmada ni autorización. Ver [ANDROID_BETA_CRITICAL_PATH_2026-11-06.md](ANDROID_BETA_CRITICAL_PATH_2026-11-06.md).

---

> **RUTA CRÍTICA BETA ANDROID — 06/11/2026:** plan de tres macrofases B1 (emisor MFA confiable E2/E3 con auditoría transaccional), B2 (integración Android real, permisos, notificaciones, APK firmada y UAT) y B3 (custodia, MB1/C-FICHA, privacidad, recuperación, operaciones y aprobación). Ver [ANDROID_BETA_CRITICAL_PATH_2026-11-06.md](ANDROID_BETA_CRITICAL_PATH_2026-11-06.md). G13 18/18 PASS en laboratorio y E1D3 139 PG17 PASS no autorizan beta operativa. `clients/flutter/android/app/build.gradle.kts` utiliza configuración de firma debug incluso en release: pendiente corregir antes de distribuir beta formal. No desbloquear E2 con pruebas sintéticas, no merge/despliegue/migración persistente.

---

> **ESTADO PRIORITARIO — 06/11/2026 (sustituye cabeceras históricas).** Rama `feature/m3-android-local-notifications`, PR #17 en borrador, trabajo de G14 en laboratorio. Última validación dinámica aportada: **G14-E1D3=PASS_LOCAL**, HEAD `07fa7818b`, N1=0, build=0, PG17=0, **139 pruebas** en 36.805 s; verificación contraseña/TOTP, bloqueo, concurrencia, rollback, denegación uniforme de errores de custodia y vínculos de secretos solo en laboratorio. Última validación estática: **G14-F0=PASS_LOCAL**, HEAD `5291785bd`, **9/9 tests**, barrido AST=0, N1=0, una llamada directa revisada, cero no revisadas; no detecta toda reflexión o llamadas indirectas. **G14-E2 no implementado**: NO hay emisor MFA confiable que una credenciales, consumo TOTP, emisión y auditoría en una transacción; G14-E3 pendiente. Intentos de integrar emisión y auditoría bloqueados por controles de la conexión; NO eludir el bloqueo. `G14_TRUSTED_ISSUER_IMPLEMENTED=NO`, `MFA_RELEASE_AUTHORIZED=NO`, `MB1_RELEASE_AUTHORIZED=NO`, `C_FICHA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`. No extrapolar pruebas locales a CI, beta o servidor DEV. **Fuente de verdad:** [checklist G14](G14_PROGRESS_CHECKLIST_2026-11-05.md), [contrato de aceptación E2](G14_E2_ATOMIC_ISSUANCE_ACCEPTANCE_2026-11-06.md), [handoff en curso](HANDOFF_G5_IN_PROGRESS_2026-11-03.md). Los estados antiguos más abajo son históricos.

---

# Estado del proyecto VENCIRA — actualizado 21/10/2026

## Estado confirmado el 25/10/2026 — O8c DEPLOY DEV CORRECTO; aceptación manual pendiente

**EVIDENCIA REAL aportada por el usuario** al ejecutar `scripts/deploy_o8c_0015_guarded.sh` sobre fuente `9c404380e5801d8f9fd2d4dfe260d51df78264d6`: `RECIBO_RESTAURACION_O8C_VALIDO=OK`, `O5_CIFRADO_ACTIVO=OK`, `IMAGENES_O8B_CONSERVADAS=OK`, `BUILD_API_WEB=OK`, `PLAN_MIGRACION_0015=OK`, `BACKUP_O5_PRE0015_FRESCO=OK`, `APLICAR_0015_EXPLICITAMENTE=OK`, `MIGRACION_0015_VERIFICADA=OK`, `TABLA_BORRADORES_VACIA_Y_RESTRINGIDA=OK`, `CHECK_MIGRACIONES_POST0015=OK`, `API_O8C_DESPLEGADA=OK`, `FLUTTER_WEB_O8C_DESPLEGADA=OK`, `POSTGRES_0015_SIN_REINICIO=OK`, `ENDPOINTS_PRIVADOS_PROTEGIDOS=OK` (HTTP 403 sin sesión para O7/O8b/O8c/O3), `HEALTH_api=healthy`, `HEALTH_db=healthy`, `HEALTH_web_preview=healthy`, proxy local 200 y `DEV_VENCIRA_HTTPS_HTTP=200`, `O8C_GUARDADO_SOLO_BORRADOR=OK`, `O8C_DESPLIEGUE_0015_LOCALCHECK=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`. PostgreSQL LIVE está ahora en `reminders.0015_renewal_reminder_drafts`, **no 0014**. NO volver a ejecutar la migración ni el script de despliegue.

**Recibo local privado** `/tmp/vencira-o8c-deploy.gst32W6O.receipt`, **log** `/tmp/vencira-o8c-deploy.6ggUPoJg.log`. Imágenes anteriores recuperables: `vencira-o8c-before-api:20261025T061256Z_2623430` y `vencira-o8c-before-web:20261025T061256Z_2623430`. Se realizó copia cifrada O5 nueva antes de migrar y no se cambiaron timers, Caddy u OAuth.

**Pendiente únicamente UAT funcional O8c (NO afirmarlo aceptado):** abrir `https://dev.vencira.es/` con anotación ficticia abierta, expandir «Simular avisos de vencimiento», localizar «Guardar borrador de avisos», escribir `20,15` y guardar. Debe figurar borrador guardado; salir/volver y comprobar persistencia solo de esa anotación; otra anotación debe mantener defaults 60/45/35. Verificar que no existe notificación enviada, programada ni regla habilitada. Simulación O8b sigue temporal/no persistente; O8c solo guarda días como **draft**. Si falla UAT, corregir sin volver a aplicar 0015.

**Fuente rápida para nuevo chat:** `docs/NEXT_CHAT_HANDOFF_SHORT.md`. Siguiente bloque tras UAT: O9, revisión de preguntas de control, plazos/repeticiones y decisiones whitepaper §18, sin activar notificaciones prematuramente.


> **Estado 24/10/2026 (más reciente):** el titular confirma que el cliente Google OAuth `VENCIRA Internal Backups` está **In production** en Google Cloud y el sitio informativo `https://oauth.vencira.es/` dispone de HTTPS comprobado (las tres páginas HTTP 200). Esto **no es** un lanzamiento comercial de VENCIRA. `https://dev.vencira.es/` es accesible sin HTTP Basic Auth pero mantiene login Django y API anónima 403; **solo DEMO**. O5 cuenta con copia PostgreSQL cifrada/restaurada; **pendiente reautorizar el remoto Rclone con un token emitido tras publicación**, verificar snapshot existente y definir backups automáticos/retención/alertas. El desarrollo de producto continúa con **O6 «Archivo y cerrados»**: fuentes Flutter y tests en GitHub, aún **sin validación ni despliegue**. Ver `docs/OPERATION_O6_ARCHIVE.md` y `docs/CONTINUITY_RUNBOOK.md`. Los párrafos históricos inferiores describen estados anteriores y no sustituyen este hito.


**Último hito:** VPS IONOS España (Ubuntu 24.04, 4 vCore, 8 GB RAM, 240 GB NVMe, IP 93.93.112.172) con Django + PostgreSQL 17 + Flutter Web **desplegados y healthy** en puertos solo loopback. Usuario confirma acceso inicial desde Windows por túnel SSH; smoke sin sesión correcto, GitHub CI #61 verde sobre commit `0c89a76`. No hay despliegue público ni datos reales. Próxima etapa: DNS de `dev.vencira.es`, proxy HTTPS privado y protección perimetral. Ver `docs/VPS_IONOS.md`. La indicación antigua de no contratar VPS queda superada.

Bootstrap de código y primeras integraciones, todavía en **PR borrador**, con **preview privada desplegada en VPS**, sin producción ni datos reales.

- Nombre VENCIRA y repositorio privado exclusivo `appvencira/vencira_app` confirmados.
- Dominio `vencira.es`: pedido OVHcloud del 20/10/2026 por 7,25 € con IVA; justificante en estado «Validando...», pendiente de activación final.
- Correo previsto `soporte@vencira.es`, aún no configurado.
- Backend: modelos mínimos, pruebas y health/readiness; API v1 de vencimientos limitada por pertenencia a organización, con sesiones web y CSRF.
- Tests backend SQLite y PostgreSQL 17: superados en la ejecución anterior.
- Flutter: interfaz de consulta de organizaciones y vencimientos mediante API; lista paginada, estados de sesión, cambio de organización y pruebas de contrato/widget. **Proxy de mismo origen añadido para pruebas locales con Nginx; la prueba HTTP autenticada E2E está en CI y las pruebas visuales reales de navegador continúan pendientes**.
- Envío de avisos, alta/edición web, MFA, límites adicionales por IP y seguridad de login Admin, RGPD, copias externas y producción: pendientes.
- No comprar VPS hasta necesitar pruebas externas o despliegue real.

Documentación: `docs/API_MVP.md`, `docs/WEB_LOCAL.md` y `clients/flutter/README.md`. CI anterior de compilación web e integración same-origin: superada. CI del refuerzo de login y candidatos internos: superada (27 tests en SQLite y PostgreSQL, además de Flutter y web).

- Login provisional: límite por cuenta HMAC persistido en BD, 5 fallos/15 minutos -> bloqueo 15 minutos. Sin MFA ni protección frente a abuso distribuido.

- Base de avisos: reglas inactivas por defecto, candidatos futuros deduplicados y conciliación manual por organización. **Nunca envía mensajes**.

- Auditoría API v1: eventos de creación y cambios de vencimientos registrados en la misma transacción, sin conservar valores de referencias de clientes. Cobertura limitada a API v1, sin salida pública. Ver `docs/AUDIT.md`.
- Reglas comerciales: opciones y dudas documentadas en `docs/REMINDER_RULES_DRAFT.md`; sin aprobación de parámetros comerciales ni entregas reales.
- CI del registro de auditoría: superada con 34 tests SQLite + 34 PostgreSQL, y Flutter/Web.

- Se añaden fecha opcional de límite contractual de preaviso, base de regla seleccionable y visualización Flutter separada. No se infieren plazos legales ni cambian reglas de destinatarios. CI de código y pruebas de esta revisión: 43 tests en SQLite y 43 en PostgreSQL, Flutter y Nginx-Django, todo correcto en GitHub Actions #35. Consultar siempre el estado del último commit antes de fusionar.

## Preparación de primera prueba en servidor — 21/10/2026

- Frontend Flutter Web con **alta/edición de vencimientos**, validación de fechas y cierre de sesión.
- Django ofrece un endpoint CSRF de mismo origen y mantiene la autorización por organización y auditoría de escrituras.
- `compose.preview.yaml` compila Flutter dentro de Docker y levanta una preview independiente `vencira_preview`, solo puertos 127.0.0.1:18731/18732.
- Comando `seed_preview` disponible exclusivamente en preview de desarrollo, crea una organización y seis vencimientos **ficticios**, además de credenciales de usuario sin privilegios.
- Guía y scripts en `docs/SERVER_PREVIEW.md`, `scripts/preview-up.sh`, `scripts/preview-seed.sh` y `scripts/preview-down.sh`.
- CI integra construcción del Docker de preview y smoke de login, alta, edición y logout sobre los servicios reales. Ver último workflow de la PR antes de utilizar.
- **No desplegado en el servidor del usuario** por falta de acceso SSH desde las herramientas disponibles. No se ha contratado VPS ni cambiado DNS.

## Primera prueba real en Ubuntu — 21/10/2026 (información del usuario)

- El usuario confirma clonado y arranque de la preview en su servidor Ubuntu, último commit y acceso desde navegador. No existe acceso SSH remoto desde el conector de GitHub, por tanto no se atribuyen verificaciones de navegador no ejecutadas.
- Se diagnosticó un error CSRF de login con `Origin: null` y se corrigió la política `Referrer-Policy` de Nginx para permitir formularios HTML del mismo origen sin desactivar CSRF. GitHub Actions #49 validó los servicios y la cabecera.
- **Próxima aceptación manual:** confirmar login, visualizar seis registros sintéticos, crear, editar, filtrar, cerrar sesión.
- Se incorpora API y UI de búsqueda por referencia y filtro por estado, con aislamiento multi-organización y pruebas. Los filtros no modifican datos ni notifican.
- La PR de trabajo sigue en borrador, sin fusionar con `main` ni despliegue público. Los datos de prueba no deben contener clientes reales.

### Procedimiento de aceptación — filtros web

1. Actualizar rama de preview con `git pull --ff-only origin chore/bootstrap-vencira` y reconstruir el contenedor web y API (ver `scripts/preview-up.sh`).
2. Acceder como `vencira_demo` por `http://127.0.0.1:18732/`, solo con datos ficticios.
3. Buscar una referencia parcial, cambiar estado, comprobar que limpiar filtros devuelve la lista completa y que paginación preserva filtros.
4. Crear una referencia DEMO, editarla y cerrar sesión. Confirmar que no hay fuga entre organizaciones ni envíos de avisos.

Nota: la primera prueba manual del navegador sigue siendo necesaria; CI no sustituye al uso real.

## 24/10/2026 — O7/O8a desplegadas en DEV; pruebas técnicas y seguridad superadas

**Fuente: salida real del titular en Ubuntu.** Checkout/despliegue `b61e357f06b7396d1018cb072ef39b6bc0974777`. `FUENTES_IGUALES_GATE_VALIDADO=OK`, `COMPOSE_IDENTIDAD_Y_MIGRATE_CHECK_ONLY=OK`, `COMPOSE_CONFIG=OK`, `O5_BACKUP_READ_ONLY=OK`, `BACKUP_O5_RECIENTE_Y_CIFRADO=OK`, esquema previo `0014` verificado, imágenes antiguas de API y Web etiquetadas, `BUILD_API_WEB=OK`, `MIGRATIONS_CHECK_ONLY_NEW_IMAGE=OK`, `ESQUEMA_SIN_MIGRACIONES_PENDIENTES=OK`, `DEPLOY_API=OK`, `DEPLOY_WEB=OK`, `POSTGRES_0014_SIN_CAMBIOS=OK`, cuatro rutas básicas HTTP 200, endpoint O7 anon HTTP 403 y O3 anon HTTP 403, `HEALTH_api/db/web_preview=healthy`, `DEV_VENCIRA_HTTPS_HTTP=200`, `DESPLIEGUE_O7_O8_LOCALCHECK=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`, sin migraciones, reinicio PostgreSQL, cambios a Caddy, Restic o timers. Versión web `b61e357f06b7396d1018cb072ef39b6bc0974777`.

**Imágenes de recuperación conservadas:** `vencira-o7-pre-api:20261024T214020Z_2326206` y `vencira-o7-pre-web:20261024T214020Z_2326206`. Recibo privado de despliegue: `/tmp/vencira-o7-o8-20261024T214020Z_2326206.bc7EwG0D.receipt`; log privado `/tmp/vencira-o7-o8-deploy.NyAOMxIF.log`. No destruir imágenes ni recibo hasta aceptación manual.

**Estado:** O7 **DESPLEGADA Y VALIDADA TÉCNICAMENTE**; pendiente aceptación visual del administrador en navegador PC ancho >=800: botón «Resumen de resultados», navegación mes/trimestre/año y números correctos sobre registros ficticios. No mostrar resumen en móvil o cuentas member; backend owner-only ya tiene regresiones unitarias y anónimo devuelve 403. O8a cálculo legal y 60/45/35 **DESPLEGADO COMO LÓGICA PURA**, sin notificaciones activas, sin trabajos externos ni ajustes de esquemas. No declarar O7 funcionalmente aceptada sin prueba manual.

Próximo desarrollo acelerado O8b y O9 puede codificarse y probarse en GitHub sobre la misma rama tras este gate sin desplegar automáticamente. Mantener inalterados backups O5 y base `0014`; nuevas migraciones solo con protocolo O4 específico. Nunca ejecutar de nuevo `deploy_o7_o8_no_migrations.sh` si ya salió OK.

## 25/10/2026 — O8b COMPLETADO: preflight integral y despliegue DEV confirmados

**Salida de la ejecución real del titular** del orquestador `scripts/validate_and_deploy_o8b.sh`: `O8B_DEPLOY_COMPLETO=OK`, `O8B_VALIDADO_Y_DESPLEGADO=OK`, `RESULTADO_ORQUESTACION=0`, `RESULTADO_EJECUCION=0`, `CONSOLA_ABIERTA`. Estos marcadores **solo se emiten si** previamente se ha completado el preflight integral SQLite + PostgreSQL17 efímero + Flutter (análisis, tests dirigidos, suite completa, compilación web) y el despliegue condicionado de API + Flutter Web del proyecto `vencira_localcheck`. La copia O5 reciente, migraciones `0014` sin cambios, imágenes anteriores recuperables y chequeos de autenticación/HTTP son gates del script de despliegue. **No se dispone en este mensaje del recibo ni de los identificadores exactos de las imágenes previas creadas en esta última ejecución**, ni del `COMMIT` que mostró la consola; no inventarlos. La rama tenía HEAD `7e83f8d2cf617a7c8db09ca25cd49ffe878f2b7e` antes del `git fetch`/merge y no hay cambios de código posteriores a ese HEAD previos a los docs siguientes.

**Estado fiable**: O8b **VALIDADO Y DESPLEGADO EN DEV**, solo simulación no persistente (API GET autorizada y tarjeta ES/CA en detalle de anotación, plegada después de los controles de contacto y seguimiento); **todavía no hay aceptación manual de UX en navegador**. O7 resultados navegables mes/trimestre/año aceptados visualmente por el usuario. O5 diaria en uso; no reconfigurar. O8b NO crea ni envía mensajes ni guarda regla.

**Próxima validación manual breve**: abrir `https://dev.vencira.es` en una anotación DEMO abierta; desplegar sección «Simular avisos de vencimiento»; comprobar 60,45,35 y después `20,15`; debe advertir si no hay pregunta previa al mes civil, jamás marcar enviado ni guardar configuración; navegar fuera y volver para verificar default sin guardar. Si algo difiere, registrar captura sin datos reales ni secretos y reparar.

**Siguiente lote O8c:** permitir guardar reglas por anotación, con motivos como dato aún sin decidir; no reutilizar directamente políticas globales workspace `ReminderPolicy` (`enabled=False`) porque su alcance es organización y podría alterar otras pólizas. Crear diseño de tabla independiente y migración 0015 ADITIVA bajo protocolo O4 de copia-restauración PG efímero, roles y auditoría; no activar canales externos. Decisiones §18 pendientes: motivos por defecto, manejo alta tardía y sin aviso legal, Vida, avisos no atendidos, selección de entrega; plantear defaults seguros antes de habilitar. Seguir plan `docs/WHITEPAPER_EXECUTION_ROADMAP_2026-10-24.md`.
