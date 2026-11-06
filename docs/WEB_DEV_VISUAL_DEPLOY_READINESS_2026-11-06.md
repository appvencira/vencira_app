# VENCIRA — Preparación de publicación VISUAL en DEV (06/11/2026)

**Decisión actual: NO-GO para despliegue de la rama completa.** Este documento establece el camino para poder mostrar cambios en `https://dev.vencira.es` sin exponer MFA ni modificar Django/DB. No representa autorización de despliegue.

## Evidencia de partida
- GitHub `appvencira/vencira_app`: comparación `main...feature/m3-android-local-notifications` consultada el 06/11/2026: `status=diverged`, `ahead_by=3653`, `behind_by=17`. La comparación contiene 300 entradas de archivo devueltas por el servicio, por lo que **no se ha demostrado** tener un inventario exhaustivo de toda la diferencia.
- La rama integra muchísima más actividad que UX Flutter. No fusionar PR #17 ni desplegar su backend.
- El deploy histórico `scripts/deploy_o7_o8_no_migrations.sh` exige checkout `/home/vencira/vencira-localcheck`, rama `integration/local-e2e-prep`, hash de fuente validada `c86cd8e...` y estado DB esquema `0014`; no es seguro reutilizarlo sobre estado actual sin actualizar contrato y nueva validación.
- El script histórico `scripts/deploy_o8c_0015_guarded.sh` fue diseñado para migración única `0015`, fuente `80a5ac6...` y un recibo O5 temporal. **No reejecutar** en fase visual.
- La evidencia histórica de `docs/PROJECT_STATUS.md` no basta para conocer el SHA exacto de la imagen web *actualmente* publicada. Aún no se ha verificado inventario live de imágenes/commit/esquema ni salud/O5 desde VPS.

## Alcance permitido de un primer despliegue visual
1. Definir visuales concretos aprobados por el operador: e.g., alineación móvil, paneles, navegación, mejoras ES/CA. Seleccionar fuentes con commits explícitos y comparar contra el checkout **real que alimenta web_preview**.
2. Crear una candidata efímera con los archivos Flutter mínimos. Sin tocar `backend/`, `deploy/`, `compose*.yaml`, `clients/flutter/android/`, permisos, tokens, migraciones, rutas Django, acceso nativo G14 ni lógica no aprobada.
3. Resolver dependencias Flutter de la candidata con build `flutter analyze`, `flutter test` y `flutter build web` en aislamiento. Comparar el `build/web` servido con la API existente, sin modificar esquema.
4. Verificar en VPS, *solo lectura*, proyecto Compose real, identificadores y salud de `web_preview`/`api`/`db`, hash de imágenes, `migrate --check`, backup O5 reciente, SHA de fuentes y posibilidad real de recuperar la imagen web anterior. No exponer secretos ni contraseñas en logs. Si algo no se puede verificar: NO-GO.
5. Preparar un **script específico web-only**, con tag de imagen anterior, control estricto de SHA validado, NO construir ni recrear `api`/`db`, sin ejecutar migraciones y con rollback web explícito. Preparar recibo con comprobaciones HTTP y validación visual tras cambio; revisar y aceptar el despliegue como operación diferenciada.
6. Requerir aceptación explícita de operación tras pasar los gates; mantener `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1` hasta nuevo alcance autorizado. No despliegue automático desde GitHub ni CI.

## Bloqueadores antes de GO
- `WEB_DEV_LIVE_BASELINE=NOT_VERIFIED`: no tenemos aquí comprobación en vivo de contenedores, imagen web actual, PostgreSQL ni O5.
- `WEB_DEV_VISUAL_SOURCE_SET=NOT_SELECTED`: no se ha recortado el diff real a UI y sus dependencias.
- `WEB_DEV_ISOLATED_BUILD_TEST=NOT_RUN`: no existe gate para el nuevo candidato.
- `WEB_DEV_WEB_ONLY_ROLLBACK=NOT_VERIFIED`: no se ha ensayado rollback específico de web.
- `WEB_DEV_DEPLOY_AUTHORIZED=NO`: no interpretar el deseo de verlo pronto como permiso para desactivar los gates o desplegar la rama insegura.

## Próxima acción agrupada
En el siguiente lote, recopilar una auditoría **read-only** del VPS de Compose y la versión web desplegada, determinar los commits visuales que se quieren enseñar, crear candidata web-only y verificarla contra la API/DB existentes. Una sola ejecución de gates al final del lote. **G15 ya está cerrado en laboratorio**; no repetir G13/G15 ni activar las notificaciones operativas. **G14-E2** permanece pendiente y es bloqueante de beta privada nativa, pero no debería forzar la publicación de backend para una revisión visual segura.


## 06/11/2026 — Inicio del corte incremental DEV solicitado

El titular pide que el avance acumulado sea visible en DEV sin dejarlo indefinidamente aparcado. La actualización debe avanzar por cortes funcionales: **primero web/UI compatible**, después API/backend únicamente con validaciones y migraciones específicas (no simultáneamente con Flutter Web), y finalmente autenticación nativa/MFA cuando su emisor transaccional G14-E2 esté implementado y autorizado. No afirmar que todos los cambios pueden salir en un solo deploy.

Se publicó `scripts/web_dev_predeploy_inventory_readonly.sh` en la rama Android para recopilar en una ejecución: estado y digest de contenedores Compose DEV, imagen web recuperable, salud local por HTTP, HEAD/rama de checkouts, suciedad tracked y timers O5. No imprime entornos ni variables de secretos, no consulta datos de usuarios, no construye imágenes, no despliega ni migra. **Ejecución VPS pendiente.**

Después de recibir el inventario: seleccionar set explícito de cambios y SHA, cerrar compatibilidad con API, preparar script nuevo de despliegue **web-only** y rollback con validación en clon. Los viejos scripts O7/O8 de deploy no se pueden reutilizar directamente por anclajes a SHA/esquema históricos. Compromiso de progreso: no otra batería de ensayos de APK aisladas mientras el gate de publicación web esté pendiente. `NO_DEPLOY_NO_LIVE_MIGRATION=1` hasta que se autorice el corte verificado.


## 06/11/2026 — Inventario real VPS y corrección de falsos negativos

Operador ejecutó inventario de solo lectura con `WEB_DEV_SOURCE_HEAD=7bcdbfb3c`, rama del checkout M3 vacía (probablemente HEAD detached; confirmar por separado). Contenedores `vencira_localcheck-web_preview-1`, `-api-1`, `-db-1` todos `running/healthy` y bajo proyecto Compose `vencira_localcheck`. Imagen web actual `sha256:9de96e4a9a3ae18b13dbcfbb6c2a25857d7511df3840c4851c6400223136eaf1`, recuperable localmente. API `sha256:6bb813f527410957b534da61ac8e4120813ba64c2b7f11b98122a231001a8ac5`; BD `sha256:b0f9560a2de083e2cc7382e75f808c7381a32852a7ec49117deedb300e552b24`. Web loopback 18732 devolvió HTTP 200. Health API loopback 18731 devolvió HTTP **405 a HEAD**, **no acredita fallo de salud**: el contenedor API está healthy; verificar con GET. Checkout de despliegue `/home/vencira/vencira-localcheck` en `feature/c-ficha-independent-attachments`, HEAD `64e936b9c`, tracked clean. El primer inventario mostró timers `o5-backup.timer`/`o5-health.timer` `NOT_ACTIVE`, pero **consultó nombres incorrectos**; unidades reales `vencira-o5-backup.timer`/`vencira-o5-health.timer`. Corregido el script en `1bb13693` para consultar unidades reales, usar GET HTTP y comprobar `manage.py migrate --check --noinput` sin escritura. **No concluir que O5 estuviera parado** por aquella salida; pendiente comprobación O5 remota cifrada.

Los resultados prueban disponibilidad y reversibilidad de imagen web, **no** compatibilidad de nuevo frontend, snapshot O5 fresco ni autorización de deploy. Próximo paso: revisión O5 `sudo bash scripts/o5_verify_active_schedule.sh` y ejecución del inventario corregido, sin operación mutante. Después recorte web-only para un primer release controlado. Se mantienen todas las barreras de MFA.


## 06/11/2026 — Gate baseline O5 completo y candidata web compilable aislada

El usuario ejecutó el **inventario corregido** y `scripts/o5_verify_active_schedule.sh`: `WEB_DEV_BASELINE_RESULT=0`, tres contenedores `running/healthy`, local GET web 18732=200 y API `/api/health/` 18731=200, `WEB_DEV_API_SCHEMA_CHECK_ONLY=OK`, timers `vencira-o5-backup.timer` y `vencira-o5-health.timer` ambos `ACTIVE`, `WEB_DEV_O5_RESULT=0`, `TIMERS_ACTIVOS_Y_HABILITADOS=OK`, `MARCADOR_EXITO_MENOS_36H=OK`, `SNAPSHOTS_POSTGRES_EN_RESTIC=OK`, snapshot más reciente `73349` segundos (~20 h 22 min), `ULTIMO_SNAPSHOT_MENOS_36H=SI`, `AUDITORIA_FINAL_O5=OK`, `RESULTADO_GLOBAL=0`. **`WEB_DEV_LIVE_BASELINE=PASS_LOCAL`**, sin necesidad de volver a repetir este inventario sin cambio relevante.

Se publica `scripts/web_dev_candidate_build_isolated.sh` en la rama de trabajo (commits `ab6b16da`, corrección sudo Docker `cf3f413b`) para **compilar una imagen candidata web sin desplegar**. El script comprueba origen limpio, identidad y salud de contenedores, captura los IDs de las 3 imágenes reales, exige que la web anterior sea recuperable, construye una imagen etiquetada `vencira-web-candidate:<sha>` usando `deploy/preview/Dockerfile.web`, comprueba `index.html` y `main.dart.js` sin red, compara que las imágenes de contenedores actuales no cambiaron y emite `WEB_CANDIDATE_BUILD=PASS` solo al finalizar. **No ejecuta Docker Compose up, no reinicia servicios, no migra datos.** Es un gate de compilación, no de compatibilidad web/API ni de autorización de deploy. Validación local de este script **PENDIENTE**.

La fase posterior requiere probar endpoints de navegación del cliente contra la API DEV existente con identidades y datos de prueba, elaborar una lista explícita de funcionalidades operativas que se publicarán, verificar rollback web-only de verdad y aprobar la sustitución. La construcción de la rama completa como candidata **no** autoriza desplegarla. Mantener G14-E2/seguridad sin exponer y no publicar frontend sin comprobación de compatibilidad.


## 06/11/2026 — Candidata Flutter Web compilada; comparativa contra API real pendiente

El operador confirma `WEB_CANDIDATE_RESULT=0`, `WEB_CANDIDATE_SOURCE_SHA=ce13634819475fb572e8323a15b891baa141937f`, `WEB_CANDIDATE_TAG=vencira-web-candidate:ce1363481947`, `WEB_CANDIDATE_OLD_WEB_RECOVERABLE=YES`, `WEB_CANDIDATE_STATIC_ASSETS=OK`, `WEB_CANDIDATE_LIVE_IMAGES_UNCHANGED=OK`, `WEB_CANDIDATE_BUILD=PASS`, `WEB_CANDIDATE_DEPLOY_EXECUTED=NO`, `WEB_CANDIDATE_API_DB_UNCHANGED=YES`. **Compilación aislada PASS_LOCAL para SHA exacto `ce136348...`**. Ni pruebas funcionales con API real ni ensayo de rollback verificados. **Importante:** la imagen de ese SHA no debe confundirse con nuevos commits de scripts/docs: no reconstruir innecesariamente solo por cambios de documentación.

Se añadió `scripts/web_dev_candidate_api_compat_readonly.py` (commit `5385f76a`) para inventariar por introspección los patrones URL de Django **en la API desplegada** (únicamente plantillas, sin datos privados ni requests) y compararlos contra las rutas declaradas en el candidato. Su resultado `WEB_API_CANDIDATE_ROUTES_MISSING_LIVE` permite identificar posibles dependencias no disponibles del backend. **No es prueba completa** de formatos de respuesta, autorización, esquema, interacciones ni compatibilidad; toda falta debe analizarse antes de reemplazar la web. Este instrumento solo lee rutas, no ejecuta `compose up`, `migrate` o acciones persistentes.

Siguiente lote: ejecutar **una vez** la comparación de rutas, evaluar diferencias y preparar candidato de frontend recortado al backend vivo junto a un plan de rollback web-only, sin mezclar seguridad G14/Android. La aprobación de deploy DEV sigue **PENDING**.


## 06/11/2026 — Comparación con API DEV: 7 rutas ausentes; preparación de candidata compatible

El operador ejecutó `scripts/web_dev_candidate_api_compat_readonly.py` con `WEB_API_COMPAT_RESULT=0`, `WEB_API_CANDIDATE_ROUTES=39`, `WEB_API_DEPLOYED_ROUTES=32`, `WEB_API_CANDIDATE_ROUTES_MISSING_LIVE=7`, `WEB_API_ROUTE_COMPARISON=DIFF_FOUND`, `WEB_API_FUNCTIONAL_COMPATIBILITY=NOT_VERIFIED`, `WEB_API_DEPLOY_EXECUTED=NO`. Ausencias exactas: `accounts/mfa/`, tres rutas `/api/v1/me/mfa/setup/start/`, `setup/confirm/`, `recovery/ack/`; `/api/v1/workspaces/<uuid:workspace_id>/device-notice-preview/`; y las dos rutas `/api/v1/workspaces/<uuid:workspace_id>/renewals/<uuid:renewal_id>/attachments/` y `.../attachments/<uuid:attachment_id>/`. No asumir que la API desplegada está rota: corresponde a capacidades implementadas más adelante en otra rama.

Análisis código web: `MfaSetupScreen` aparece en el menú de ajustes solo con `VENCIRA_MFA_UI_ENABLED` (default `false`); sin habilitarlo, el recorrido MFA queda oculto. En la ficha, `VenciraRenewalAttachmentsCard` sí estaba visible y efectuaba `fetchAttachmentManifest` aun sin endpoint; se añadió puerta fail-closed por defecto `VENCIRA_WEB_ATTACHMENTS_ENABLED=false` en `clients/flutter/lib/ui/renewal_detail_screen.dart` (commit `f385c68e`). Esto evita mostrar una función que no puede cumplir su contrato con la API instalada. No habilitar MFA ni adjuntos en compilaciones web de DEV hasta desplegar backend compatible y autorizar la función. `device-notice-preview` sigue pendiente de auditoría de callsites; no atribuir compatibilidad funcional completa al mero ocultamiento de UI.

Se añadió `scripts/web_dev_legacy_api_guard.py` (commit `019f1cfe`) para rastrear invocaciones Dart de estos métodos fuera del adaptador y exigir que los controles de acceso a MFA/adjuntos permanezcan deshabilitados por defecto. El builder aislado exige que ese guard pase antes de compilar (commit `57245d1d`). **Guard estático y nueva compilación NO VERIFICADOS localmente**; la imagen anterior `vencira-web-candidate:ce1363481947` **no incluye la nueva puerta de adjuntos y no debe desplegarse**. La versión reconstruida tendrá un nuevo SHA/tag.

Después del nuevo PASS se necesita evaluar compatibilidad de las **32 rutas compartidas** en forma/respuestas reales (en particular módulos de actividad) y preparar rollback web-only con imagen anterior `sha256:9de96e4a9a3ae18b13dbcfbb6c2a25857d7511df3840c4851c6400223136eaf1`. Este gate es previo a publicación, no autoriza deploy. `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


## 06/11/2026 — Fallo de gate web por coordinador Android, corregido con grafo de imports

Resultado local aportado: `WEB_DEV_STATIC_attachments_disabled_by_default=OK`, `WEB_DEV_STATIC_mfa_disabled_by_default=OK`, demás flags iniciales OK; `WEB_DEV_UNSUPPORTED_CALLSITE_fetchDeviceNoticePreview=notifications/device_notice_session_coordinator.dart`, `WEB_DEV_STATIC_fetchDeviceNoticePreview_callsite_isolated=FAIL`, `WEB_DEV_LEGACY_API_SOURCE_GATE=FAIL`, `WEB_LEGACY_GUARD_RESULT=1`, `WEB_CANDIDATE_V2_RESULT=99`. **La compilación V2 no se ejecutó** (99 es marcador de salto, no error Gradle). El coordinador de avisos contiene la llamada a la previsualización del servidor, pero dispone de rollout `nativeRolloutApproved=false` por defecto y es un módulo separado; no se constató activación en Web.

Corrección del **guard**, no del comportamiento de producción: `scripts/web_dev_legacy_api_guard.py` permite ese único callsite nominal conocido, pero exige simultáneamente que el archivo del coordinador Android **no sea alcanzable en el grafo transitivo de imports de `clients/flutter/lib/main.dart`**. Si se importa directa o indirectamente, el guard falla cerrado. No se autorizan otros callsites ni se habilita el endpoint. Commits `8d47b242` y `a2ba9a15` (regex de import corregida). **Pendiente ejecución local de guard y rebuild V2**. No interpretar el cambio del guard como prueba de compatibilidad funcional de API ni desplegar la primera imagen `ce136348...`.

Se mantienen los siete endpoints ausentes en servidor y la exigencia de evaluar contratos de las rutas compartidas y preparar rollback web-only antes del primer despliegue.


## 06/11/2026 — V2 validada y canario HTTP de integración preparado

El operador confirma `WEB_DEV_WEB_ENTRY_IMPORT_GRAPH=ISOLATED`, todos los controles `WEB_DEV_STATIC_*=OK`, `WEB_DEV_LEGACY_API_SOURCE_GATE=PASS`, `WEB_LEGACY_GUARD_RESULT=0`, `WEB_CANDIDATE_V2_RESULT=0`, `WEB_CANDIDATE_SOURCE_SHA=308c69da24aa7c75502d132e28645d9b1150c1ef`, `WEB_CANDIDATE_TAG=vencira-web-candidate:308c69da24aa`, `WEB_CANDIDATE_STATIC_ASSETS=OK`, `WEB_CANDIDATE_LIVE_IMAGES_UNCHANGED=OK`, `WEB_CANDIDATE_BUILD=PASS`, `WEB_CANDIDATE_DEPLOY_EXECUTED=NO`. V2 incluye gate de ficha de adjuntos y mantiene MFA desactivado; coordinador de preview Android no alcanzable desde import graph de web.

Se añadió `scripts/web_dev_candidate_canary_smoke.sh` (commit `86069758`) para ejecutar la imagen **ya construida**, sin recompilarla, en un contenedor temporal enlazado únicamente al network Compose existente y publicado solo en `127.0.0.1:18744`. Comprueba Flutter HTML y JS 200, endpoint API `GET /api/health/` 200, pantalla login 200, `GET /api/v1/workspaces/` sin autenticar 401/403, identidad de imágenes de web/API/DB intactas; elimina contenedor en trap. **Ningún deploy de web real ni migraciones; ensayo pendiente de salida local.** No acredita contenido de agenda/acciones CRUD con sesión, ni que las 32 rutas compartidas mantengan idénticos contratos. Si falla, no desplegar hasta diagnóstico.

**Siguiente bloqueo GO:** si el canario pasa, preparar sustitución **web-only** con imagen/tag/sha exactos y recuperación explícita a imagen web anterior `sha256:9de96e4a9a3ae18b13dbcfbb6c2a25857d7511df3840c4851c6400223136eaf1`, y ejecutar UAT de interfaz con datos DEMO. No revalidar O5 ni reconstruir imagen por cambios solo en docs.


## 06/11/2026 — Canario HTTP PASS; corte web-only preparado, sin despliegue

El usuario ejecutó canario efímero de la candidata `vencira-web-candidate:308c69da24aa` en puerto 18744, con `WEB_DEV_CANARY_HOME=200`, `WEB_DEV_CANARY_JS=200`, `WEB_DEV_CANARY_API_HEALTH=200`, `WEB_DEV_CANARY_LOGIN=200`, `WEB_DEV_CANARY_PRIVATE_DENIED=403`, `WEB_DEV_CANARY_LIVE_IMAGES_UNCHANGED=OK`, `WEB_DEV_CANARY_HTTP_SMOKE=PASS`, `WEB_CANARY_RESULT=0`. Apareció un `curl: (56) Connection reset by peer` transitorio durante espera de arranque, seguido de resultados finales correctos: **no hay evidencia de fallo permanente HTTP**. El canario se eliminó y no se modificaron servicios activos. No se probó agenda/CRUD con login DEMO (`WEB_DEV_FUNCTIONAL_UAT=NOT_VERIFIED`).

Se publicó `scripts/web_dev_release_web_only.sh` (commits `4fc5e165` y `10d92940`) con modos `preflight` (solo lectura), `deploy` (exige `VENCIRA_WEB_DEV_DEPLOY_APPROVED=YES`) y `rollback` (exige `VENCIRA_WEB_DEV_ROLLBACK_APPROVED=YES`). Utiliza como base el checkout de despliegue histórico `/home/vencira/vencira-localcheck` y Compose `vencira_localcheck`, aplica un override temporal exclusivamente de `web_preview.image`, `up -d --no-deps --no-build --force-recreate web_preview`, comprueba HTTP web/JS/API/login/acceso privado y ausencia de cambios de imágenes API/DB. Conserva la imagen web anterior por etiqueta `vencira-web-rollback:<digest>`, escribe recibo solo con IDs/sha y hace rollback web automático ante fallo HTTP tras sustitución; no introduce migraciones. Candidate SHA fijado `308c69da24aa...` e imagen anterior fijada `sha256:9de96e...` (si cambian, abortar y revisar). **El script NO ha sido ejecutado ni en preflight** y su fiabilidad/rollback todavía NO ha sido ensayada en VPS; no asumir que la mera publicación lo valida.

Próximo paso: ejecutar **solo el modo `preflight`**, incluyendo `bash -n` y `docker compose config --quiet` (sin cambios operativos), y revisar salida. Después aprobar expresamente la operación web-only, activar el modo deploy y comprobar visualmente con sesión DEMO; si falla la UI, activar rollback dedicado. Los despliegues API/DB y G14-E2 quedan fuera de alcance.


## 06/11/2026 — PRIMER DESPLIEGUE WEB-ONLY DEV: PASS OPERADOR, UAT PENDIENTE

**Evidencia ejecutada en VPS y aportada por el operador:** `bash scripts/web_dev_release_web_only.sh preflight` devolvió `WEB_RELEASE_PREFLIGHT=PASS`, `WEB_RELEASE_EXECUTED=NO`, `WEB_RELEASE_PREFLIGHT_RESULT=0`, con `WEB_RELEASE_ONLY_SERVICE=web_preview`. Posteriormente se ejecutó el despliegue explícitamente aprobado `VENCIRA_WEB_DEV_DEPLOY_APPROVED=YES bash scripts/web_dev_release_web_only.sh deploy`, devolviendo:

- `WEB_RELEASE_WEB_FROM=sha256:9de96e4a9a3ae18b13dbcfbb6c2a25857d7511df3840c4851c6400223136eaf1`.
- `WEB_RELEASE_WEB_TO=vencira-web-candidate:308c69da24aa`; fuente fijada `308c69da24aa7c75502d132e28645d9b1150c1ef`.
- `WEB_RELEASE_API_IMAGE=sha256:6bb813f527410957b534da61ac8e4120813ba64c2b7f11b98122a231001a8ac5`; `WEB_RELEASE_DB_IMAGE=sha256:b0f9560a2de083e2cc7382e75f808c7381a32852a7ec49117deedb300e552b24`.
- Docker Compose: `Container vencira_localcheck-web_preview-1 Started`.
- `WEB_RELEASE_POSTCHECK=PASS`, `WEB_RELEASE_API_DB_IMAGES_UNCHANGED=YES`, `WEB_RELEASE_MODE_RESULT=PASS:deploy`, `NO_LIVE_DB_MIGRATION=1`, `WEB_DEV_DEPLOY_RESULT=0`.
- `WEB_RELEASE_UAT=REQUIRES_MANUAL_BROWSER_VALIDATION`.

**Estado: `WEB_DEV_WEB_ONLY_DEPLOY=PASS_OPERATOR_VERIFIED` y `WEB_DEV_BROWSER_UAT=PENDING`.** El despliegue afecta solo la fachada web en `https://dev.vencira.es`; no se actualizó el backend, ni la BD, ni se aplicó una migración. La preparación generaba etiqueta `vencira-web-rollback:9de96e4a9a3a` de la imagen anterior y escribía recibo de recuperación en `/home/vencira/.vencira-web-only-last-release.receipt`; **la presencia final de etiqueta y recibo no se ha inspeccionado independientemente**, por lo que verificar antes de ejecutar rollback si hiciera falta. No se acredita experiencia funcional de login, agenda, CRUD, calendario, filtros o ficha hasta prueba manual. Tampoco se activan rutas MFA/adjuntos/preview ausentes del Django actual. Evitar redeploy automático o fusionar rama Android para lograr paridad.

**Siguiente paso inmediato:** usuario prueba navegador con datos DEMO, preferentemente en móvil y escritorio: inicio, login, agenda día/mes, navegación, vencimientos, ficha, borradores/controles, filtros, ES/CA, logout y ausencia de secciones bloqueadas de MFA/adjuntos. Si falla algo, recoger pantalla/acción y código visible sin secretos ni datos personales para decisión de corrección/rollback. No repetir preflight ni canario ya aprobados sin motivo.


## 06/11/2026 — Confirmación del operador tras revisión de DEV

Tras recibir la lista de comprobación manual de `https://dev.vencira.es` (inicio, agenda/calendario, vencimientos/ficha, edición/borradores, ES/CA, logout y ausencia de MFA/adjuntos habilitados), el operador respondió **«Done»**. Se registra como **revisión manual completada declarada por el operador**, sin informe granular de cada pantalla, dispositivos, navegador, capturas ni log de pruebas adicionales. No afirmar UAT exhaustiva ni ausencia universal de defectos.

**`WEB_DEV_BROWSER_REVIEW=OPERATOR_DONE`**, **`WEB_DEV_WEB_ONLY_DEPLOY=PASS_OPERATOR_VERIFIED`**, **`WEB_DEV_FULL_UAT=NOT_EVIDENCED`**. La imagen web puesta en DEV continúa siendo la candidata `vencira-web-candidate:308c69da24aa` y API/DB anteriores sin cambios según la evidencia del despliegue. Se conserva vía de rollback web anterior; no reejecutar por rutina. Cualquier fallo posterior exige diagnóstico de su ruta afectada.

El próximo trabajo debe priorizar el siguiente corte funcional sincronizado web/API (con su propia compatibilidad y migraciones O4 si las requiere), manteniendo G14-E2 y MFA sin autorización y evitando fusionar la rama Android entera. Separar aceptación de interfaz de validación de backend y seguridad.
