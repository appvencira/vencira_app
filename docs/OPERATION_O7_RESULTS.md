# VENCIRA — O7: Resumen de resultados (whitepaper §11, p. 14–15)

**24/10/2026 — Estado:** implementación en código GitHub, **no validada por ejecución en VPS, NO desplegada y NO aceptada manualmente**. Sin migración ni envíos.

## Contrato de producto
La fuente exige resultados de escritorio (no móvil/tablet): periodo **mes / trimestre / año**, «Conseguidas», «No aceptadas», «Descartadas» por **fecha del desenlace** y «Pendientes» por **fecha de vencimiento** de anotaciones aún abiertas. En Equipo contempla total y por usuario; sin embargo §18 declara PENDIENTE si los empleados pueden consultar el resumen. Por seguridad, esta primera entrega solo permite consulta del owner, agregada por cuenta. El desglose por agente requiere decidir si atribuir desenlaces al actor de cierre o al responsable de anotación en ese momento (pueden diferir); no se ha inventado una política.

## Implementación
- `GET /api/v1/workspaces/{uuid}/results/?period=month&year=2027&month=3` (ó `period=quarter&year=2027&quarter=1`; ó `period=year&year=2027`).
- Estado owner requerido para cada petición; sin membresía, 404; empleado, 403; sesión anónima, 401/403; otros métodos 405.
- Periodos civiles (Europe/Madrid) `[from,to_exclusive)` validados estrictamente (sin parámetros duplicados, desconocidos o años fuera de 2000–2100). GET y `Cache-Control: no-store`.
- Cuenta **eventos históricos** `RenewalOutcome.kind=won/declined/discarded` del periodo, sin usar el estado actual ni inferir «Conseguida» por status. Si se recupera y se vuelve a ganar en otro periodo, cada cierre real se cuenta en su momento.
- «Pendientes» = anotaciones visibles cuyo `expires_on` cae en periodo, `status != closed` y sin archivo O3. «Contactado» sigue siendo abierto. No son entregas de avisos.
- No se devuelven UUIDs/nombres/referencias/usuarios/PII. No hay escrituras.
- `clients/flutter/lib/ui/results_screen.dart`: vista de 4 contadores y navegación periodo ES/CA, accesible solo en **web de escritorio ancho >=800 px** desde el panel y rol owner. No se expone en móvil nativo ni web estrecha.
- La API de red usa mismo origen y tipo `VenciraResultsSummary`; las pruebas Flutter existentes usan la implementación opcional del método como stub sin afectar pruebas anteriores.

## Verificación y puertas
- `backend/reminders/test_results.py`: cómputo civil en marzo con cambio DST, eventos reabiertos, cuenta ajena, sesión, role, POST y parámetros inválidos.
- `clients/flutter/test/results_test.dart`: ES/CA, agregados, navegación mes/trimestre/año, sesión caducada y ausencia de acceso móvil.
- `scripts/validate_o7_o8_preflight.sh`: Django completo SQLite + PostgreSQL 17 efímero, Flutter analyze/tests/build, sin tocar `vencira_localcheck`, PostgreSQL persistente ni Caddy/Restic.
- **Sin prueba verde aún**; no desplegar API/Web ni alterar Docker persistente hasta obtener resultado exacto y plan independiente. Después probar en PC con datos DEMO y verificar negación a usuario no-owner.
- Falta completar desglose por usuario conforme a decisión formal del §18, y valorar exportación Excel como fase O13 posterior.

## 24/10/2026 — PRE-FLIGHT O7/O8a integral confirmado; despliegue API + Web preparado, NO ejecutado

El usuario aportó resultado real de `scripts/validate_o7_o8_preflight.sh`, sobre checkout integrado con O7 y O8a, con: `LOCALCHECK_HEALTH_PRE=OK`, `CONFIG_COMPOSE=OK`, `I18N_ES_CA=OK`, `BUILD_BACKEND_AISLADO=OK`, `DJANGO_CHECK_MIGRACION_SECA=OK`, `DJANGO_SQLITE_SUITE_COMPLETA=OK`, `PG17_TEMPORAL=OK`, `DJANGO_POSTGRES17_SUITE_COMPLETA=OK`, `FLUTTER_ANALYZE_TEST_BUILD=OK`, `LOCALCHECK_HEALTH_POST=OK`, `O7_O8_PREFLIGHT_SIN_DESPLIEGUE=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`. Log local `/tmp/vencira-o7-o8-preflight.988RWtXC.log`. La salida compartida omite COMMIT pero el último HEAD de fuente preparado para ese gate fue `c86cd8e058262da8998505c80e37ab3cdfa0ca90`; no afirmar verificable vínculo a ese SHA sin nueva comprobación local.

**O7/O8a código funcionalmente testado en aislamiento, aún NO instalado en DEV**. El preflight confirma que no se modificó PostgreSQL persistente ni O5/Caddy/Restic.

Se versionó `scripts/deploy_o7_o8_no_migrations.sh`, despliegue de una sola ejecución para **solo API y Web del proyecto `vencira_localcheck`**, con gate de diff desde commit fuente validado c86cd8e (backend, clients, compose, deploy), identidad healthy y guard de API `migrate --check --noinput`, verificación de respaldo cifrado O5 post-OAuth y snapshot menor de 36 h, comprobación del esquema 0014 y número total de migraciones, etiqueta inmutable y restaurable de imágenes previas API/Web ANTES de construir; si faltan imágenes antiguas aborta sin cambios. Build de API y Web, `migrate --check` sobre nueva imagen, recreación individual `--no-deps --no-build` solo API y solo Web, verificación DB mismo contenedor y migraciones iguales, HTTP 200 y O7/O3 rutas anónimas 401/403, salud API/DB/Web, recibo privado. **No se hace rollback de DB automáticamente**, si falla con servicios ya recreados inspeccionar recibo y tags antes de recuperar; no repetir script a ciegas. Caddy/O5 y `vencira_preview` intactos.

**Siguiente gate:** sincronizar rama `integration/local-e2e-prep`, ejecutar `bash -n scripts/deploy_o7_o8_no_migrations.sh`, luego `bash scripts/deploy_o7_o8_no_migrations.sh` en la consola de Ubuntu. El script abortará antes de desplegar si fallan imágenes recuperables/backup/source check. Si todas las pruebas pasan, aceptación O7 en navegador de ordenador ancho >=800 como owner (Resultados, cambiar periodos, cuenta correcta); confirmar inaccesible empleado y móvil. O8a no tiene UI, son funciones puras. No afirmar despliegue real hasta recibir marcadores `DESPLIEGUE_O7_O8_LOCALCHECK=OK`, `POSTGRES_0014_SIN_CAMBIOS=OK`, `RESULTADO_GLOBAL=0` y `RESULTADO_EJECUCION=0`.

**Restricción de velocidad:** No incorporar más cambios a `backend/`, `clients/` o `deploy/` hasta que se complete este gate o se repita preflight. Mantener O5 diario activo. Después priorizar O8b/O9 y O11, según plan maestro.

## 24/10/2026 — O7/O8a desplegadas en DEV; pruebas técnicas y seguridad superadas

**Fuente: salida real del titular en Ubuntu.** Checkout/despliegue `b61e357f06b7396d1018cb072ef39b6bc0974777`. `FUENTES_IGUALES_GATE_VALIDADO=OK`, `COMPOSE_IDENTIDAD_Y_MIGRATE_CHECK_ONLY=OK`, `COMPOSE_CONFIG=OK`, `O5_BACKUP_READ_ONLY=OK`, `BACKUP_O5_RECIENTE_Y_CIFRADO=OK`, esquema previo `0014` verificado, imágenes antiguas de API y Web etiquetadas, `BUILD_API_WEB=OK`, `MIGRATIONS_CHECK_ONLY_NEW_IMAGE=OK`, `ESQUEMA_SIN_MIGRACIONES_PENDIENTES=OK`, `DEPLOY_API=OK`, `DEPLOY_WEB=OK`, `POSTGRES_0014_SIN_CAMBIOS=OK`, cuatro rutas básicas HTTP 200, endpoint O7 anon HTTP 403 y O3 anon HTTP 403, `HEALTH_api/db/web_preview=healthy`, `DEV_VENCIRA_HTTPS_HTTP=200`, `DESPLIEGUE_O7_O8_LOCALCHECK=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`, sin migraciones, reinicio PostgreSQL, cambios a Caddy, Restic o timers. Versión web `b61e357f06b7396d1018cb072ef39b6bc0974777`.

**Imágenes de recuperación conservadas:** `vencira-o7-pre-api:20261024T214020Z_2326206` y `vencira-o7-pre-web:20261024T214020Z_2326206`. Recibo privado de despliegue: `/tmp/vencira-o7-o8-20261024T214020Z_2326206.bc7EwG0D.receipt`; log privado `/tmp/vencira-o7-o8-deploy.NyAOMxIF.log`. No destruir imágenes ni recibo hasta aceptación manual.

**Estado:** O7 **DESPLEGADA Y VALIDADA TÉCNICAMENTE**; pendiente aceptación visual del administrador en navegador PC ancho >=800: botón «Resumen de resultados», navegación mes/trimestre/año y números correctos sobre registros ficticios. No mostrar resumen en móvil o cuentas member; backend owner-only ya tiene regresiones unitarias y anónimo devuelve 403. O8a cálculo legal y 60/45/35 **DESPLEGADO COMO LÓGICA PURA**, sin notificaciones activas, sin trabajos externos ni ajustes de esquemas. No declarar O7 funcionalmente aceptada sin prueba manual.

Próximo desarrollo acelerado O8b y O9 puede codificarse y probarse en GitHub sobre la misma rama tras este gate sin desplegar automáticamente. Mantener inalterados backups O5 y base `0014`; nuevas migraciones solo con protocolo O4 específico. Nunca ejecutar de nuevo `deploy_o7_o8_no_migrations.sh` si ya salió OK.
