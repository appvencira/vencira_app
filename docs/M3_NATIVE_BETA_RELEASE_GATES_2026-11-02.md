> **LECTURA PRIORITARIA 03/11/2026:** el estado consolidado para continuar en un nuevo chat está en [HANDOFF G4→G5](HANDOFF_G4_G5_2026-11-03.md). G4 candidato PostgreSQL17 **20/20 PASS**, G6 integral **PASS previo a G4**. El runner integral post-G4 y SQLite/CI no tienen recibo verde; G4 operativo NO. Los apartados previos con «pendiente» son históricos; conservar como cronología. `NO_DEPLOY_NO_LIVE_MIGRATION=1` y gates MFA/MB1/C-FICHA cerrados.

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
| G4 Servicio nativo persistente | **CANDIDATO PG17 PASS / OPERACIONAL NO** | Esquema sin deriva y 20 pruebas PG17 desechables aprobadas; SQLite, emisión autorizada de contraseña/MFA, control antiabuso, claves y despliegue no habilitados |
| G5 MFA/token móvil y antiabuso | **LAB PASS / OPERATIONAL NOT IMPLEMENTED** | Garantizar rate-limits distribuidos por cuenta y IP de proxy confiable, rotación de secretos, MFA/recovery en cada solicitud, revocación multiinstancia |
| G6 Refresh con respuesta ambigua | **LAB PASS / OPERACIONAL NO** | Ensayo PG17 + Flutter integrados finalizados con `M3_HTTP_RESULT=0`; faltan integración real, custodia, fallo físico de proceso, antiabuso y autorización de despliegue |
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

## G6 — Decisión de protocolo (02/11/2026, nueva revisión no validada)

**Opción elegida: reautenticación completa con revocación global, sin reintento del refresh anterior.** Prioriza fallo cerrado y lógica sencilla frente a continuidad de sesión transparente. La renovación actual de laboratorio consume el refresh inmediatamente, y su replay revoca el dispositivo: por eso NO es seguro reenviar el mismo token tras un timeout.

Contrato requerido:

1. Antes de cualquier HTTP capaz de emitir o renovar credenciales, el futuro coordinador debe ejecutar y confirmar en almacenamiento protegido un marcador `full-reauth-required-v1` asociado al entorno. Si no puede escribirse y releerse, bloquear **antes de enviar** la petición.
2. Si se pierde la respuesta, se interrumpe el proceso o se desconoce si el servidor confirmó la rotación, cerrar inmediatamente `NativeSessionFence`; **NO reutilizar ni reintentar** el refresh antiguo.
3. Al reiniciar, leer el marcador protegido antes de restaurar sesión. Si existe o está corrupto, no reconstruir Bearer desde el vault. Exigir nueva contraseña y, si está activo, TOTP. Los fallos de lectura o escritura bloquean el acceso.
4. Tras la autenticación completa, el servidor revoca **TODAS** las sesiones previas y retos pendientes de la cuenta, incrementa `auth_generation`, y emite una sesión nueva dentro de la misma transacción PostgreSQL. Si MFA está habilitado, la contraseña **no revoca nada**: solo la validación exitosa del segundo factor realiza el corte.
5. El cliente guarda y relee un refresh **nuevo** en Keychain/Keystore; comprueba que difiere del previo; solo entonces borra y verifica el borrado del marcador. La barrera de solicitudes sigue cerrada hasta confirmar todo el proceso.
6. Si falla el segundo factor, la escritura, la eliminación del marcador o la red, conservar el estado de recuperación (sin acceso). Si un proceso muere durante la recuperación, repetir reautenticación completa. No aceptar un simple HTTP 200 como demostración de autorización de recurso.

**Impacto UX consciente:** una recuperación G6 cierra las sesiones de **otros dispositivos**, por lo que debe advertirse explícitamente al usuario antes de iniciar esa recuperación. Los inicios de sesión normales NO producen esa revocación global. Es política propuesta para una beta, no una liberación comercial aprobada.

**Implementado solo en test (pendiente de gate):**
- `native_sessions_lab.models.MobileLoginChallengeLab.replace_devices`, migración **0004 exclusivamente temporal**. `begin_native_login_lab(..., replace_devices=True)` y `finish_native_mfa_lab(..., expected_recovery=True)` comprueban el flujo y el orden de revocación.
- Solo la URLConf experimental incluye `POST /api/v1/mobile/auth/recover/password/` y `POST /api/v1/mobile/auth/recover/mfa/`. `config.urls` y `reminders.urls` NO se tocan. Se amplían tests HTTP: respuesta perdida, contraseña incorrecta sin revocación, MFA incompleto sin revocación, completitud del corte, separación entre retos normales y de recuperación, guard de entorno y cookies.
- Cliente `NativeHttpAuthPort.recoverPassword/recoverMfa` con endpoints separados; `NativeRefreshRecoveryJournal` escribe marcador **no secreto** en `NativeSecretStore` independiente por entorno, detecta reinicios y exige un refresh nuevo protegido antes del borrado verificado. Pruebas sintéticas cubren escritura, lectura, reinicio, fallo de red, borrado fallido, credencial repetida y activación prematura.
- Se vuelve a comprobar la contraseña bajo el bloqueo de cuenta por posible carrera con cambio de contraseña; prueba concurrente PostgreSQL 17.
- Los nuevos ensayos se han incorporado al runner M3 y al workflow; **NINGUNA PRUEBA NUEVA SE DECLARA PASS** hasta que el operador devuelva salida de ejecución. El último `M3_HTTP_RESULT=0` confirmado pertenece al commit anterior a G6.

**Aún bloqueante para producción:** el marcador y la recuperación NO están cableados en `main.dart` ni `NativeSessionCoordinator`. La función de confirmación recibe un callback de confianza, pero ese callback todavía NO demuestra por sí mismo que el servidor operativo haya revocado los dispositivos. Falta validación en Android/iOS físico y ante muerte real del proceso, diseño de auditoría global y sesiones operativas persistentes. En consecuencia, `G6_POLICY=SELECTED`, `G6_LAB=NOT_VERIFIED`, `G6_OPERATIONAL=NO`, todos los gates de despliegue `NO`.

## G6 — Implementación de prototipo del gateway móvil (02/11/2026)
- `NativeRecoveryLoginGateway` es la implementación aislada del `NativeLoginGateway` para la recuperación obligatoria, sin acceso a `rotateRefresh`. Se acopla al `NativeRefreshRecoveryJournal` y al vault seguro e impide activar el fence antes de completar la sustitución y verificación de la credencial.
- Casos de prueba nuevos: 9 sintéticos. Se incorporan al workflow de GitHub Actions y al runner M3. Todavía sin evidencia de ejecución de estos nueve.
- **No equiparar este prototipo con la recuperación funcional en Android/iOS**: no está conectado a `main.dart`, no cubre las transiciones de refresh normal ni la revocación operacional, y falta el apagado brusco real y el aviso a usuario sobre cierre de otros dispositivos.
- Evidencia independiente: el operador confirmó el fallo G6 corregido en PostgreSQL17 temporal `Ran 1 test in 0.218s`, `OK`, `N1_PG17_LAB_CASE_RESULT=0`. La validación integral del nuevo conjunto sigue pendiente; no se autorizan migraciones reales.

## G6 — Cierre de laboratorio, apertura de gate operativo (03/11/2026, salida 02/11 23:47 UTC)
- Última validación integrada confirmada por operador: `M3_HTTP_STATIC=0`, `M3_HTTP_BUILD=0`, `M3_HTTP_PG17_LAB=0`, `M3_HTTP_FLUTTER=0`, `M3_HTTP_RESULT=0`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`; logs locales `~/vencira-m3-results/m3-http-contract-20261102T234745Z`.
- G6 se considera **VALIDADO COMO CONTRATO EN LABORATORIO**. Las nueve pruebas nuevas del gateway se incluyeron en el runner validado. El resumen no trae el número exacto de tests ni equivale a ensayo físico.
- La **ruta crítica próxima** deja de ser seguir añadiendo pruebas sintéticas del contrato ya verde. Se limita a cerrar estos bloqueos de producto:
  1. **G1/G2/G3 externos:** custodia de MFA real, congelación/verificación de todos los escritores MB1, separación de adjuntos C-FICHA. Sus gates siguen en NO y requieren evidencia externa; no inferir resolución de un commit.
  2. **G4/G5 backend no-lab:** sistema de tokens propio persistente operativo, aislamiento por cuentas, DRF/HTTP autorizado, autorización completa de recursos, control de abuso y auditoría en clúster; ensayos en clon antes de migración.
  3. **G7 integración cliente real:** `main.dart` continúa sin usar el gateway de recuperación ni el login nativo; impedir el envío HTTP desde móvil sin marcador protegido previo, integrar pantalla y Keychain/Keystore, probar cierre real de app y fallo de red en Android/iOS físicos.
  4. **G9 habilitación:** backup/restauración independiente, rollback, observabilidad y aprobación humana de despliegue.
- Próxima revisión debe producir evidencia reproducible de `G4/G5` en un servicio **aún no desplegado**, sin desbloquear ni migrar la BD persistente. Un laboratorio aprobado no autoriza abrir rutas bajo `/api/v1/mobile/`.
- `G6_LAB=PASS`; `G6_OPERATIONAL=NO`; `MFA_RELEASE_AUTHORIZED=NO`; `MB1_RELEASE_AUTHORIZED=NO`; `C_FICHA_RELEASE_AUTHORIZED=NO`; `GLOBAL_FREEZE=NOT_VERIFIED`; `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## G4 — Servicio móvil persistente candidato (03/11/2026, sin activación)

**Propósito:** pasar del ensayo `native_sessions_lab` a un candidato de arquitectura operativa, **sin promover la lógica de emisión desde pruebas a producción**. No se han modificado `config.urls`, `reminders.urls`, el `main.dart` de Flutter, los autenticadores por defecto, la base de datos real ni las rutas públicas.

### Contenido implementado (PENDIENTE de probar)

- `backend/native_mobile_service/`: app Django independiente, registrada **solo** cuando `VENCIRA_NATIVE_SERVICE_CANDIDATE=1` y `VENCIRA_ENV=test`. Solicitarla en otro entorno provoca `ImproperlyConfigured`. `VENCIRA_NATIVE_BEARER_ENABLED=False` en configuración normal.
- `models.py` y migración `0001_initial.py` exclusiva del candidato: `MobileAccountFence` (epoch por cuenta), `MobileDeviceSession` (UUID, digests HMAC de access/refresh, vencimientos, versión de contraseña/MFA y revocación), `MobileSpentRefresh` (hash único de refresh consumido). **Esta migración no se ejecutará en la BD persistente**.
- `session_store.py`: candidato de emisión sintética limitada explícitamente a `test`, validación access en cada petición con `require_mobile_identity_gate`, rotación refresh transaccional con replay conocido que revoca dispositivo, revocación individual y de cuenta por generación. Los secretos en claro no se escriben en BD. El método `issue_verified_candidate_session` **no establece que el llamador verificó la contraseña/MFA**: es solo un inyector de tests, no una función de login autorizada para una implementación real.
- `authentication.py`: `CandidateMobileBearerAuthentication` para DRF sin aceptación de cookies de navegador, `Origin`, `Referer` o HTTP no seguro, con autorización explícita adicional. Se usa solo en `test_views.py` y `test_urls.py` (URLConf sustituida dentro de un test). `REST_FRAMEWORK.DEFAULT_AUTHENTICATION_CLASSES` permanece solo con `SessionAuthentication`.
- `test_contract.py`: **18** pruebas Django para tokens opacos, workspace owner/member, PII, membresía revocada, host HTTP/Origin/cookies, ausencia de fallback web, feature flag, expiración, password, MFA epoch, rotación/replay y revocación. `test_pg17_races.py`: **2** tests de concurrencia PG17 para doble refresh y corte simultáneo de cuenta/alta; evita inversión de lock entre row y usuario.
- `scripts/n1_identity_pg17_ephemeral.sh --candidate` se ejecuta en PG17 `tmpfs` con red interna, sin volumen ni puerto publicado; comprueba `makemigrations native_mobile_service --check --dry-run` antes de las dos suites. `scripts/m3_native_http_contract_batch.sh` incluye ahora una **fase nueva `M3_HTTP_G4_PG17`**, además de M3/G6 que ya habían pasado, y la exige para `M3_HTTP_RESULT=0`. GitHub Actions incluye SQLite y PG17; `n1_static_security_gate.py` vigila el aislamiento y compila sintácticamente las fuentes con `ast.parse`.
- El guard operativo prueba que el servicio candidato **no está instalado** ni sus URL son resolubles con configuración normal.

### Estado y limitaciones

- Último gate **confirmado por operador antes de esta rama de cambios G4**: `M3_HTTP_STATIC=0`, `M3_HTTP_BUILD=0`, `M3_HTTP_PG17_LAB=0`, `M3_HTTP_FLUTTER=0`, `M3_HTTP_RESULT=0` (logs `m3-http-contract-20261102T234745Z`). **No equivale a validar G4**.
- Estado actual: `G4_CANDIDATE_CODE=COMMITTED`; `G4_CANDIDATE_PG17=NOT_VERIFIED`; `G4_CANDIDATE_SQLITE=NOT_VERIFIED`; `G4_OPERATIONAL_RELEASE=NO`.
- PENDIENTE **crítico** para producción: resolver registro/sujeto confiable de emisión después de password+MFA, rate limit distribuido por IP y cuenta con trusted proxy, gestión de claves digest/rotación y auditoría, autorización total de recursos, migraciones reversibles con backup, restauración independiente y limitación segura de tokens simultáneos. Este lote no desbloquea ninguna de esas decisiones.
- `MFA_RELEASE_AUTHORIZED=NO`; `MB1_RELEASE_AUTHORIZED=NO`; `C_FICHA_RELEASE_AUTHORIZED=NO`; `GLOBAL_FREEZE=NOT_VERIFIED`; `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

**Siguiente comprobación:** revisión de GitHub Actions si produce evidencia disponible; si no, una única ejecución local `bash scripts/m3_native_http_contract_batch.sh` en el checkout actualizado. No abrir backend operativo automáticamente cuando aparezca PASS.

## G4 — Evidencia de cierre del candidato PostgreSQL17 (03/11/2026)

- `bash scripts/n1_identity_pg17_ephemeral.sh --candidate` confirmó `N1_PG17_POSTGRES_READY=OK`, `No changes detected in app 'native_mobile_service'`, `Found 20 test(s)`, `System check identified no issues`, `Ran 20 tests in 2.376s`, `OK` y `G4_CANDIDATE_PG17_RESULT=0`.
- `G4_CANDIDATE_PG17=PASS` en migraciones/contratos/concurrencia; `G4_CANDIDATE_SQLITE=NOT_VERIFIED`; `G4_OPERATIONAL_RELEASE=NO`. Ni el backend de login de producción ni el procedimiento de emisión de credenciales tras MFA existen en este candidato. La aprobación de un ensayo con sesiones inyectadas no prueba la autenticación real.
- El gate `M3_HTTP_RESULT=0` de 02/11/2026 es histórico, anterior al nuevo servicio: no usarlo para declarar la rama G4 completamente aprobada.
- **Ruta crítica ahora:** G5 resistencia a abuso (cuenta/IP de proxy confiable), auditabilidad de accesos/revocaciones sin guardar tokens, custodia HMAC y rotación, identificación inicial con password + MFA autorizada, restauración física y aprobación explícita de los gates externos MB1/MFA/C-FICHA.
- `NO_DEPLOY_NO_LIVE_MIGRATION=1`; `GLOBAL_FREEZE=NOT_VERIFIED`; `MFA_RELEASE_AUTHORIZED=NO`; `MB1_RELEASE_AUTHORIZED=NO`; `C_FICHA_RELEASE_AUTHORIZED=NO`.
