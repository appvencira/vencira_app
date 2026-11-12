# VENCIRA — D27 fase 2: núcleo independiente contraseña/MFA/sesión (12/11/2026)

**Estado:** implementación publicada en `main`, prueba VPS PENDIENTE. **No hay emisor operacional desplegado.** Esta fase es ingeniería de un núcleo transaccional aislado, no un login web/Android.

## Implementación

- `backend/native_mobile_service/native_operational_issuer_core.py` (`de80edbf`): flujo de dos etapas. `begin_verified_password(username,password,remote_addr)` verifica custodia de claves, consume cuota por cuenta/IP mediante filas `MobileAuthAttemptBucket`, verifica Django password bajo lock `User`, exige MFA activo y ausencia de recuperación administrativa pendiente, y guarda un reto aleatorio con SHA256 del secreto, versión de credenciales, época MFA y generación de revocación. La primera etapa **NUNCA** devuelve token.
- `complete_verified_mfa(challenge,code)`: parseo estricto del nuevo reto `oc1`, bloqueo ordenado usuario→MFA→reto, validación de estado y caducidad, consumo TOTP anti-replay con `reminders.mfa_store.consume_totp`, emisión de tokens `v1.a/v1.r` aleatorios de 256 bits y persistencia únicamente de sus HMAC en `MobileDeviceSession`. Reto consumido y auditoría `auth_verified` dentro de la misma transacción. Si falla auditoría/DB, no se confirma emisión. No se importan `candidate_two_step_issuer`, `candidate_recovery_issuer` ni `session_store` para emitir.
- La auditoría y el presupuesto antiabuso usan claves nuevas `VENCIRA_D27_CORE_AUDIT_KEY` y `VENCIRA_D27_CORE_ABUSE_KEY`, mínimo 32 caracteres, **solo valores sintéticos del laboratorio**; nunca expuestos al cliente. `REMOTE_ADDR` se interpreta como par directo: no se aceptan proxies ni cabeceras `X-Forwarded-For` en esta fase.
- El núcleo exige **expresamente** `VENCIRA_ENV=test`, `VENCIRA_NATIVE_SERVICE_CANDIDATE` y bearer operativo deshabilitado. No está importado por las vistas operativas; `backend/config/urls.py`, `main.dart` y la política `assert_operational_issuer_unavailable` quedan intactas.

## Tests y gate agrupado

- `backend/native_mobile_service/test_d27_operational_core_pg17.py` (`e1b5715b`): 6 pruebas PG17 de contraseña correcta+TOTP+credenciales HMAC+no-replay, contraseña errónea/formato MFA inválido, claves ausentes/entorno producción rechazados, cuotas cuenta/IP y origen inválido.
- `scripts/native_i8k_recovery_http_pg17_isolated.sh` (`6495ad37`): incorpora estas seis pruebas a la suite de PG17 efímero, sin alterar DEV.
- `scripts/main_d27_independent_issuer_pg17_grouped_gate.sh` (`bf3430b2`): un solo gate que exige `main` limpia, AST Python y dependencia aislada, D18 y D27-D28 hard fences, e I8-K PG17 completo. `D27_P2_RESULT=0` significa que el **núcleo aislado de laboratorio** pasó; no significa que el emisor operativo esté listo ni autoriza producción.

### Una sola ejecución Termius

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
sudo -v
bash scripts/main_d27_independent_issuer_pg17_grouped_gate.sh
echo "D27_P2_RECHECK_RESULT=$?"
git status --short
```

Resultados exigidos, **todavía no observados**:

```text
D27_P2_MAIN_CLEAN=PASS
D27_P2_INDEPENDENT_AST_AND_LAB_FENCE=PASS
D27_P2_RELEASE_BARRIERS=PASS
D27_INDEPENDENT_PASSWORD_MFA_SESSION_PG17=PASS
D27_BAD_PASSWORD_AND_MFA_DENIED_PG17=PASS
D27_PRODUCTION_AND_KEY_GUARDS=PASS
D27_INDEPENDENT_ANTIBRUTEFORCE_AND_IP=PASS
NATIVE_I8K_D27_INDEPENDENT_PASSWORD_MFA_CORE_PG17=PASS
NATIVE_I8K_DEV_CONTAINERS_UNCHANGED=OK
NATIVE_I8K_LOCAL_RESULT=0
D27_P2_PG17_ISSUER_AND_SECURITY=PASS
D27_P2_PRODUCTION_ISSUER_ENABLED=NO
D27_P2_ANDROID_MAIN_AUTH_ENABLED=NO
D27_P2_RESULT=0
D27_P2_RECHECK_RESULT=0
```

## Falta para convertirlo en emisor operativo

**Este módulo NO está preparado para su activación en producción.** Falta implementar y revisar: revocación global de cuenta, recuperación tras pérdida de respuesta, auditoría duradera/retención, control IP tras proxy de confianza, claves de custodia externa reales, separación de la app candidata/test del esquema desplegado, migraciones PG17 ensayadas, pruebas de concurrencia y fallos, URLconf operacional, controles de middleware/CSRF/HTTPS, integración Flutter del reto `oc1` y del login de Android, tests sobre dispositivo físico y autorización de release.

**No transformar el gate de laboratorio en producción quitando un `if test`.** Los candados de release existentes permanecen. `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## Ampliación del mismo grupo D27 — acceso, refresh y logout independientes

Tras la primera implementación, `backend/native_mobile_service/native_operational_issuer_core.py` recibió `65567867` con tres funciones adicionales sin llamadas a `session_store`:

1. `validate_verified_access`: parsea bearer estricto, toma locks usuario→dispositivo, valida digest HMAC, vencimientos, revocación, generación de cuenta, versión de contraseña y estado MFA/recovery real en cada lectura.
2. `rotate_verified_refresh`: serializa por usuario y dispositivo, guarda digest gastado único, rota access/refresh de 256 bits y limita vencimientos. Si se vuelve a presentar un **refresh previamente gastado**, revoca el dispositivo y **confirma** la revocación antes de denegar, evitando rollback accidental.
3. `revoke_verified_device`: revoca sesión con refresh válido, limpia digests y rechaza reiteraciones.

`test_d27_operational_core_pg17.py` (`ab75af3f`) añade dos pruebas que verifican rotación, access antiguo rechazado, replay con revocación y logout con rechazo posterior. Son **6 pruebas D27 independientes** incluidas en I8-K, además de la regresión anterior.

Los marcadores esperados adicionales, todavía no observados, son:

```text
D27_REFRESH_ROTATION_REPLAY_REVOKES_PG17=PASS
D27_DEVICE_LOGOUT_SERVER_REVOKED_PG17=PASS
```

Sigue faltando recovery account-wide no-lab, custodia/proxy y tests operativos; ningún permiso de producción se modifica.

## Primer gate D27 fase 2 — FAIL por sintaxis del import, corregido en main (12/11/2026)

El operador ejecutó `scripts/main_d27_independent_issuer_pg17_grouped_gate.sh` en checkout limpio. Se observaron `D27_P2_MAIN_CLEAN=PASS`, `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`, `D27_P2_PRODUCTION_ISSUER_ENABLED=NO` y `D27_P2_ANDROID_MAIN_AUTH_ENABLED=NO`. La comprobación AST detuvo el gate antes de Docker/PG17: `SyntaxError: unexpected character after line continuation character` en línea 27 de `native_operational_issuer_core.py`. La causa era una sentencia `from reminders.native_mobile_token_primitives import (...) ` con secuencias literales `\\n` en lugar de saltos de línea reales, introducida al ampliar el módulo con refresh y revocación.

Corrección publicada directamente en `main` **`67a9ec24`**: reemplaza exactamente esas secuencias por saltos de línea, sin alterar la lógica transaccional. Revisión adicional detectó una regex de prueba raw con `\\\\.` en vez de `\\.`; corregida en **`e8065941`** para verificar correctamente la forma del reto `oc1`. Comprobado contra el código remoto que no quedan secuencias literales `\\n` en el módulo. El gate **no llegó a ejecutar PG17**, así que D27 fase 2 continúa **NO VALIDADA**. Resultado original: `D27_P2_RECHECK_RESULT=1` y `git status --short` vacío.

Repetir el mismo gate agrupado al actualizar `main`. Ninguna migración, ruta pública, contenedor operativo ni autenticación Android ha sido activada.

## Validación final D27 fase 2 — PASS en VPS (12/11/2026)

Resultado aportado por operador desde `main`: `D27_P2_MAIN_CLEAN=PASS`, `D27_P2_INDEPENDENT_AST_AND_LAB_FENCE=PASS`, `D27_P2_SOURCE_GATE=PASS`, `D27_P2_RELEASE_BARRIERS=PASS`. Imagen Django desechable, red interna, PG17 efímero, paridad de migraciones y esquema temporal listos. Se ejecutaron **89 tests en 49.179 segundos: OK**; incluyen **las seis pruebas D27**:

```text
D27_PRODUCTION_AND_KEY_GUARDS=PASS
D27_INDEPENDENT_PASSWORD_MFA_SESSION_PG17=PASS
D27_INDEPENDENT_ANTIBRUTEFORCE_AND_IP=PASS
D27_REFRESH_ROTATION_REPLAY_REVOKES_PG17=PASS
D27_DEVICE_LOGOUT_SERVER_REVOKED_PG17=PASS
D27_BAD_PASSWORD_AND_MFA_DENIED_PG17=PASS
```

Marcadores globales: `NATIVE_I8K_D27_INDEPENDENT_PASSWORD_MFA_CORE_PG17=PASS`, `NATIVE_I8K_D26_SIGNED_WORKSPACE_CURSOR_PG17=PASS`, `NATIVE_I8K_PG17_HTTP_RECOVERY_GATE=PASS`, `NATIVE_I8K_DEV_CONTAINERS_UNCHANGED=OK`, `NATIVE_I8K_LOCAL_RESULT=0`, `D27_P2_PG17_ISSUER_AND_SECURITY=PASS`, `D27_P2_INDEPENDENT_CORE_VALIDATED=YES`, `D27_P2_RESULT=0`. La salida no incluye el `D27_P2_RECHECK_RESULT` independiente ni un `git status --short` final; no inferir esos valores.

**Cierre: D27 FASE 2 PASS SOLO EN LABORATORIO.** `D27_P2_PRODUCTION_ISSUER_ENABLED=NO`, `D27_P2_ANDROID_MAIN_AUTH_ENABLED=NO`, `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`. Siguientes bloqueos sustantivos: recuperación de cuenta en el núcleo independiente, transporte HTTP autorizado con claves reales, aislamiento esquema/entorno final, integración Android y pruebas físicas. No desplegar ni migrar LIVE.
