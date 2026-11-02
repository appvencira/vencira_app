# VENCIRA — M3: decisiones y gates para una beta nativa

Fecha de corte: 2026-11-02. Documento de planificación y auditoría, **NO autorización de despliegue**.

## Evidencia confirmada

El operador ejecutó `bash scripts/m3_native_http_contract_batch.sh` en su copia local y notificó:

```
M3_HTTP_STATIC=0
M3_HTTP_BUILD=0
M3_HTTP_PG17_LAB=0
M3_HTTP_FLUTTER=0
M3_HTTP_RESULT=0
NO_DEPLOY_NO_LIVE_MIGRATION=1
LOGS=/home/vencira/vencira-m3-results/m3-http-contract-20261102T215907Z
```

Esto acredita **el ensayo de contratos, no un release**. Las rutas HTTP experimentales se instalan mediante `native_sessions_lab.test_urls` solo en `VENCIRA_ENV=test`; `backend/config/urls.py` y `backend/reminders/urls.py` no las incluyen. En la aplicación, `NativeLoginScreen` y `NativeSessionCoordinator` tampoco están conectados a `main.dart`.

## Estado de decisión: NO-GO

| Gate | Situación al corte | Criterio objetivo de cierre |
| --- | --- | --- |
| G0 Aislamiento del laboratorio | **PASS** con lote conjunto | Mantener pruebas negativas de rutas operativas, DRF SessionAuthentication intacta |
| G1 MFA y recuperación real | **BLOCKED** — `MFA_RELEASE_AUTHORIZED=NO` | Custodia externa real y procedimiento probado, autorización expresa de la fase MFA |
| G2 Integridad y corte multi-escritor MB1 | **BLOCKED** — `GLOBAL_FREEZE=NOT_VERIFIED`, `MB1_RELEASE_AUTHORIZED=NO` | Evidencia completa de exclusión de escritores, captura y restauración física independiente, corte consistente |
| G3 Adjuntos C-FICHA | **BLOCKED** — `C_FICHA_RELEASE_AUTHORIZED=NO` | Confirmar gates reales de ClamAV, migraciones y custodia, sin habilitar endpoints por inferencia |
| G4 Servicio nativo persistente | **NOT IMPLEMENTED** | Esquema operacional revisado separado de `native_sessions_lab`, plan reversible de migración, DRF authentication/permissions revisadas, pruebas con PostgreSQL real en clon |
| G5 MFA/token móvil y antiabuso | **LAB PASS / OPERATIONAL NOT IMPLEMENTED** | Garantizar rate-limits distribuidos por cuenta y IP de proxy confiable, rotación de secretos, MFA/recovery en cada solicitud, revocación multiinstancia |
| G6 Refresh con respuesta ambigua | **BLOCKED** | Protocolo para renovación cuyo resultado se pierde tras commit del servidor o durante escritura en Keystore/Keychain; pruebas de caída de proceso y carrera entre dispositivos |
| G7 Cliente Android/iOS instalable | **UI/COORDINATOR LAB PASS / INTEGRATION NOT DONE** | Conectar pantalla y gateway revisados, restauración de sesión desde vault, cierre/account switching, UX de errores, dispositivos físicos Android+iOS |
| G8 Aislamiento de datos | **LAB PASS / PRODUCTION REVIEW PENDING** | Autenticador Bearer usado por vistas reales y control de rol/asignación en *todos* los recursos, escrituras y adjuntos; pruebas horizontales y verticales negativas |
| G9 Preproducción y liberación | **NOT AUTHORIZED** | Backup y restore independiente, observabilidad, rollback verificado, control de migraciones, aprobación humana e informe reproducible |

**No deducir la autorización de un gate de la existencia de un commit, de un test aislado o de que una API devuelva 200.**

## Ruta crítica sin ampliar indefinidamente N1

### Macro A — Contrato de producción y sesión

1. Definir la identidad y el esquema **operacionales**, con aislamiento por organización, políticas de caducidad y revocación; no migrar la BD persistente. Eliminar toda dependencia con `native_sessions_lab` de la aplicación real.
2. Diseñar recuperación de refresh ambigua: el protocolo actual marca el refresh previo como gastado y revoca la sesión en replay. Si el servidor rota y la respuesta se pierde, reintentar de forma ingenua puede revocar el propio móvil. **Esta condición impide el lanzamiento nativo**.
3. Determinar si la solución utilizará (a) intercambio idempotente con nonce de cliente y ventana acotada, secretos reemitibles cifrados o derivados; (b) revocación y reautenticación obligatoria ante ambigüedad; o (c) otra política revisada. Sin evidencia no usar reintentos automáticos. Con (b), la experiencia es menos fluida pero falla cerrada y simplifica custodia.
4. Definir tratamiento de un login concedido en servidor pero cuya respuesta se pierde, y de tokens aún válidos cuando se cierra la app. El `_unrevokedIssuedRefresh` actualmente es **volátil**: bloquear la UI no revoca una sesión del servidor tras matar el proceso.
5. Añadir auditoría por identificador opaco de dispositivo (no registrar tokens, contraseña, TOTP, header Authorization, challenge o secreto).

### Macro B — Integración acotada y pruebas de abuso

1. Implementar adaptador Django y autorizador de recursos en un servicio separado, con feature flag deshabilitada y revisión explícita de permisos. **No poner una ruta /api/v1/mobile activa sobre el entorno actual**.
2. Ensayar contra **base temporal/clone** contraseña, TOTP, restablecimiento administrativo, bloqueo por IP y usuario, renovación, replay, denegación por cambio de contraseña, membresía y asignación, doble logout y pérdida de red.
3. Unificar el estado de sesión del Flutter nativo con el vault y la barrera de generaciones; no persistir access tokens en SharedPreferences ni permitir que el login de navegador autorice el cliente nativo.
4. Validez de respuestas diferidas y restauración de proceso en Android e iOS físicos, incluyendo móviles sin red, cierre forzoso, cambios de hora, cambio de espacio de trabajo, eliminación de usuario y clave protegida inaccesible.

### Macro C — Beta y release

1. Completar G1–G3 y ensayos de restauración; si falta custodia real, el resultado es **NO-GO**.
2. Revisar documento maestro y whitepaper contra funciones efectivas; separar **funciones desarrolladas**, **activadas**, **probadas en dispositivo** y **liberadas**.
3. Ejecutar preflight en clon, pruebas de seguridad y resiliencia, backup, snapshot y rollback; comprobar imágenes y migraciones precisas.
4. Solo con evidencias y autorización explícita, definir ventana de despliegue escalonada. La publicación de un repositorio GitHub **no** implica liberar la API.

## Restricciones verificables de diseño

- Django operativo conserva `REST_FRAMEWORK.DEFAULT_AUTHENTICATION_CLASSES = SessionAuthentication` hasta el cambio autorizado; no eximir CSRF a los endpoints web.
- `native_sessions_lab` solo se instala cuando `VENCIRA_ENV=test` y `VENCIRA_NATIVE_SESSION_LAB=1`; ni `config.urls` ni `reminders.urls` importan URLConf de ensayo.
- Se mantiene `NO_DEPLOY_NO_LIVE_MIGRATION=1` hasta autorización separada. No imprimir secretos ni rutas de custodia reales en logs de CI.
- M3 HTTP y workspace experimental: **PASS**. Servicio nativo para usuarios reales: **NO-GO**.

## Próximo entregable concreto

Cerrar **G6 — Refresh con respuesta ambigua** con una decisión de protocolo y criterios de aceptación comprobables *antes de* trasladar código al servicio operativo. En paralelo solo avanzar G1/G2/G3 sobre evidencias reales, no por estimaciones. El siguiente ensayo no necesita repetir todo Flutter ni el laboratorio ya verde salvo que cambie su código.
