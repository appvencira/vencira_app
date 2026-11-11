# VENCIRA D18 — Gate agrupado de autenticación nativa, HTTPS y recuperación

Fecha: 11/11/2026. Rama única `main`. **Publicado; pendiente de ejecución en VPS.**

## Diagnóstico del bloqueo

Tras D17-B PASS (15 tests, Flutter analyze sin incidencias), la aplicación real Android realiza inspección nativa del almacenamiento y mantiene su acceso web. La revisión directa demuestra que:

- `backend/config/urls.py` **no registra** `native_mobile_service/test_i8d_urls.py` ni `test_i8k_recovery_urls.py`; son URLs de laboratorios descartables.
- `backend/config/settings.py`: `VENCIRA_NATIVE_BEARER_ENABLED = False`, y `native_mobile_service` solo entra en `INSTALLED_APPS` cuando `VENCIRA_ENV == "test"` y el candidato explícito se activa.
- `clients/flutter/lib/api/native_http_auth_port.dart`: tiene contrato JSON sin cookies ni redirecciones, pero no está conectado desde el `main.dart` real.
- `NativeFirstIssuanceEntry` requiere `journal.arm()` durable antes del primer envío; `NativeRecoveryLoginGateway` exige MFA nueva, confirmación de checkpoint y revocación previa de sesiones.
- Conectar los endpoints **de test** como si fuesen de producción eludiría los gates de MFA, custodia de claves, revocación y publicación. D18 NO autoriza tal cambio.

## Dos verificaciones existentes, ahora agrupadas

`scripts/main_d18_native_auth_release_fence_static.py` (commit `95dbf983`): inspecciona de forma determinista los invariantes de importaciones, URLs, flags de Django, cliente HTTP, marcador de recuperación y ruta Android. No realiza requests, no imprime secretos. Un PASS significa que las barreras permanecen, **no** que el issuer de producción esté disponible.

`scripts/main_d18_native_auth_grouped_security_gate.sh` (commit `ea490a28`): una ejecución desde `main`, Git limpio, snapshot de identidad de los tres contenedores DEV y sin despliegue:

1. Gate estático anterior.
2. `scripts/native_i8k_recovery_http_pg17_isolated.sh`: Django candidate y PostgreSQL17 desechables; contratos HTTP, MFA, recuperación/revocación y ausencia de rutas operativas. Emite `NATIVE_I8K_PG17_HTTP_RECOVERY_GATE=PASS`.
3. `scripts/main_i8m_flutter_real_https_pg17_isolated.sh`: cliente Flutter real de contrato HTTPS contra servidor Django y PostgreSQL17 desechables con certificado TLS temporal, pruebas de MFA/recuperación, revocación de sesión y fallo de vault. Emite `MAIN_I8M_FLUTTER_TLS_RECOVERY_GATE=PASS` y `MAIN_I8M_FLUTTER_TLS_BOUNDARY_RESULT=0`.
4. Compara que DEV no haya cambiado y devuelve resultado D18.

Estos scripts son los gates existentes: no crean nuevas ramas, no usan credenciales de usuarios, no restauran O5, no modifican Caddy, no publican puertos y no cambian el backend operativo. Pueden construir imágenes temporales de laboratorio y crear/destruir PostgreSQL de prueba. Repetir D12–D17 no es necesario.

## Ejecutar una sola vez en Termius

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
python3 -c 'import ast,pathlib; ast.parse(pathlib.Path("scripts/main_d18_native_auth_release_fence_static.py").read_text())'
bash -n scripts/main_d18_native_auth_grouped_security_gate.sh
echo "D18_SYNTAX=$?"
sudo -v
bash scripts/main_d18_native_auth_grouped_security_gate.sh
echo "D18_SHELL_RESULT=$?"
git status --short
```

PASS solo si están todos los marcadores:
```text
D18_MAIN_CLEAN=PASS
D18_DEV_IDENTITY=PASS
D18_STATIC_FENCE_GATE=PASS
D18_STATIC_FENCE=PASS
NATIVE_I8K_PG17_HTTP_RECOVERY_GATE=PASS
D18_PG17_NATIVE_HTTP_GATE=PASS
MAIN_I8M_FLUTTER_TLS_RECOVERY_GATE=PASS
D18_FLUTTER_REAL_TLS_RECOVERY_GATE=PASS
D18_NATIVE_AUTH_OPERATIONAL_READINESS=BLOCKED
D18_AUTH_PRODUCTION_ENABLED=NO
D18_NATIVE_AUTH_TEST_LABS_GROUPED=PASS
D18_DEV_CONTAINERS_UNCHANGED=OK
D18_RESULT=0
D18_SHELL_RESULT=0
```

**Importante:** el marcador `D18_NATIVE_AUTH_OPERATIONAL_READINESS=BLOCKED` es **esperado** incluso con `D18_RESULT=0`: el gate prueba el comportamiento seguro de laboratorios y verifica que Django no exponga sus rutas en producción.

## Para desbloquear acceso nativo real (no realizado en D18)

Se requiere implementación independiente y auditoría del issuer Django real, custodia de HMAC/Fernet, políticas de abuso/rotación, aislación del token bearer de sesión web y MFA con revocación atómica; endpoints autorizados probados en HTTPS real con Android físico y Keystore, recuperación tras caída y cierre de sesiones, rollback, firma de APK release, host apex y autorización explícita. La lógica operativa no debe importarse desde módulos `test_*` ni declararse lista por superar tests de laboratorio.

`MFA_RELEASE_AUTHORIZED=NO`
`NO_DEPLOY_NO_LIVE_MIGRATION=1`
