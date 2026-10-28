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
