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
