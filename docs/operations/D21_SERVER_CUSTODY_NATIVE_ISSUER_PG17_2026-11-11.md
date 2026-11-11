# VENCIRA D21 — emisor móvil con custodia MFA en servidor, aislado

Fecha: 11/11/2026. Solo rama `main`. **Código publicado; gate PostgreSQL 17 pendiente.**

## Qué se implementó realmente

`backend/native_mobile_service/native_server_custody_issuer.py` (commit `ea61af18`) ya ejecuta el flujo de emisión candidato en dos fases. A diferencia de un simple contrato de readiness, **compone los servicios de verificación y emisión transaccional**:

- `begin_native_password(username, password, request_meta)`: verifica la contraseña en backend, aplica admission/antiabuso/auditoría y crea un reto opaco sin tokens.
- `complete_native_mfa(challenge, code)`: obtiene las claves de cifrado mediante el loader **del propio backend** `reminders.mfa_key_config.load_mfa_keys()`, nunca por parámetros de HTTP o de la API; consume un TOTP con protección contra replay bajo locks PG17, guarda el consumo y emite access/refresh dentro de la transacción auditada existente.
- `begin_native_recovery(username, password, request_meta)`: reto separado de recuperación sin revocar sesiones aún ni emitir credenciales solo con la contraseña.
- `complete_native_recovery(challenge, code)`: consume nuevo TOTP, revoca sesiones anteriores y emite la nueva bajo la misma transacción PG17; persiste audit y generación de cuenta.

Se **reutilizan**, sin copiar, `candidate_two_step_issuer.py`, `candidate_recovery_issuer.py` y `session_store.py`. La política `_guard()` exige `VENCIRA_ENV=test`, `VENCIRA_NATIVE_SERVICE_CANDIDATE=True`, registro de app candidato y bearer operativo deshabilitado. En producción y desarrollo lanza `NativeServerIssuerUnavailable`; no añade URLs ni cambia el backend operativo.

El servicio retira de su API pública los parámetros de clave MFA y reloj de verificación para evitar que quien solicita emisión pueda elegir el factor o su momento. La clave se carga con el mecanismo de custodia configurado ya en Django, con validación de archivo y permisos o variable secreta de entorno; no se publica su contenido.

## Tests agregados

`backend/native_mobile_service/test_native_server_custody_issuer_pg17.py` (commits `2a7a9a0d`, `01e86c6c`):
- Contraseña real y MFA server-side → access/refresh exclusivamente después de TOTP.
- Clave MFA inválida → rechazo, ningún token.
- Contraseña incorrecta → rechazo, ningún token.
- Recuperación: paso de contraseña no revoca; un **TOTP nuevo** revoca el access antiguo y crea una sesión nueva. Se simula el reloj del **servidor** en test, no se acepta un tiempo suministrado por el cliente.
- Intentos en contexto de producción → todos los métodos permanecen inaccesibles.

El gate existente `scripts/native_i8k_recovery_http_pg17_isolated.sh` (commit `01e12625`) ejecuta la suite nueva sobre el PostgreSQL 17 aislado que ya usa I8-K, sin repetir D18 ni instalaciones Android. Cuando pasa añade `NATIVE_I8K_D21_SERVER_CUSTODY_ISSUER_PG17=PASS`.

## Termius — una sola ejecución D21

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main

bash -n scripts/native_i8k_recovery_http_pg17_isolated.sh
echo "D21_SYNTAX=$?"

sudo -v
bash scripts/native_i8k_recovery_http_pg17_isolated.sh

echo "D21_SHELL_RESULT=$?"
git status --short
```

**Exigir:**
```text
D21_SERVER_CUSTODIED_PASSWORD_MFA=PASS
D21_INVALID_KEY_CUSTODY_DENIED=PASS
D21_PASSWORD_ONLY_ISSUANCE_DENIED=PASS
D21_RECOVERY_PASSWORD_STAGE_NO_REVOKE=PASS
D21_ACCOUNT_WIDE_RECOVERY_REVOKES_OLD=PASS
D21_OPERATIONAL_ISSUER_DISABLED=PASS
NATIVE_I8K_D21_SERVER_CUSTODY_ISSUER_PG17=PASS
NATIVE_I8K_PG17_HTTP_RECOVERY_GATE=PASS
NATIVE_I8K_DEV_CONTAINERS_UNCHANGED=OK
NATIVE_I8K_LOCAL_RESULT=0
D21_SHELL_RESULT=0
```

Si falla un test, D21 NO está superada. El script produce diagnóstico y elimina DB temporal; no es un despliegue. No repetir fases completadas.

## Qué NO demuestra

Es **un servicio emisor de sesiones candidato en entorno de pruebas**, todavía no un emisor operacional autorizado: usa el esquema `native_mobile_service` instalado solo en `test`, y `session_store._gate` mantiene emisión de producción bloqueada. No se conecta el login Android real ni se registran URLs móviles públicas. Siguen pendientes custodia de claves de digest/autenticidad con rotación operacional, auditoría de amenazas de red y sesión, controles definitivos del issuer, permisos por workspace, PG17 de migración operacional, laboratorios Android con endpoints de producción preparados, firma de APK y aprobación explícita de liberación.

`MFA_RELEASE_AUTHORIZED=NO`
`NO_DEPLOY_NO_LIVE_MIGRATION=1`
`D21_OPERATIONAL_ISSUER_ENABLED=NO`
