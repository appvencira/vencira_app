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
