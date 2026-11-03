# G11 — Primera emisión y cierre de sesión con HTTPS real aislado

Fecha: 03/11/2026. **CANDIDATO IMPLEMENTADO EN GITHUB; VALIDACIÓN LOCAL/CI PENDIENTE.**

## Base validada

G7-D2/E/F/G/H terminó PASS en HTTPS TLS con Django temporal; G8-PHONE pasó sobre Android físico con almacén cifrado real y credenciales sintéticas; G9 y G10 pasaron sus suites unitarias. G10 se cerró con `G10_ISSUANCE_LOGOUT_GATE_RESULT=0` y `N1_STATIC_GATE_RESULT=OK` informados por el operador. Ninguno de esos resultados prueba por sí solo G10 extremo a extremo sobre la emisión Django a través de HTTPS: **G11 cubre ese hueco**.

## Implementación

- `clients/flutter/tool/g11_https_scenarios.dart`: escenarios G11 nuevos, reutilizando las implementaciones reales de `NativeFirstIssuanceEntry`, `NativeSessionCoordinator`, `NativeRefreshRecoveryJournal`, `NativeMobileRecoveryEntry`, `NativeRecoveryLoginGateway` y `NativeHttpAuthPort`. Se verifica la presencia del marcador sintético en el almacén antes de enviar cualquier password, MFA, recovery o revoke HTTP. El observador de transporte no muestra ni persiste secretos.
- `clients/flutter/tool/g7_d2_https_probe.dart`: admite **solo al solicitarlo explícitamente** `G7_LAB_GROUP=g11`, empleando el mismo TLS seguro y el servidor temporal. El grupo G7 normal `all` **no ejecuta G11**; el grupo G11 **no repite G7-D2/E/F/G/H**.
- `scripts/g7_d2_https_flutter_django.sh --group g11`: acepta el grupo aislado y comprueba cada marcador G11 para evitar falsos PASS. No cambia los controles de aislamiento heredados de G7: red Docker `--internal`, backend `--read-only`, SQLite solo en `--tmpfs`, CA efímera pública, validación de SNI/SAN para `dev.vencira.es`, conexión TCP exclusivamente a IPv4 privada, **sin publicar puertos de host**.
- `scripts/g11_https_first_issue_logout.sh`: ejecutor único G11 con análisis Flutter, controles N1 y el grupo HTTPS G11.
- `.github/workflows/g11-https-first-issuance.yml`: comprobación CI desde PR o manual.
- `scripts/n1_static_security_gate.py`: nuevo guarda `g11_real_https_first_issue_logout_isolated`, con invariantes de escenarios y aislamiento.

## Escenarios HTTPS

1. **Emisión limpia:** `G9.cleanLogin` cierra fence; G10 escribe y lee marcador antes del HTTP real; Django emite access/refresh; solo tras vault y borrado verificado del marcador se activa fence. `/api/v1/mobile/me/` retorna 200 bajo bearer recién emitido.
2. **Logout:** fence cerrado síncronamente antes de revocar; Django confirma revocación; credencial y marcador se borran; el access anterior devuelve 401 del servidor, no solo bloqueo de cliente.
3. **Fallo de escritura de marcador:** la operación de contraseña ni siquiera llega a `NativeHttpAuthPort`; no hay comunicación HTTPS de emisión.
4. **Respuesta de emisión perdida después del commit remoto:** el cliente no recibe la sesión emitida, mantiene marcador, fence cerrado y vault vacío; se reconstruye un proceso lógico y G9 exige recuperación completa. Una nueva contraseña de recuperación revoca la emisión perdida (verificación del bearer previo contra Django: 401) y persiste el refresh nuevo.
5. **Fallo de red antes de revocar:** marcador sigue presente, refresh retenido, sesión cerrada; un reintento completo sí revoca en Django y el bearer anterior queda 401.
6. **Respuesta de revocación perdida después del commit remoto:** Django ya revocó pero el cliente ignora el resultado; marcador y vault se mantienen para recuperación, fence cerrado; el retry sobre el mismo refresh devuelve 401 y **no se interpreta como éxito ni desbloquea una sesión**. Probar recuperación completa es tarea separada, no forzar un bypass.
7. **MFA:** cuenta sintética distinta; código TOTP RFC de test; el marcador existe antes de password y MFA; el access solo funciona tras commit protegido, y un logout posterior lo invalida en Django.

Todos los usuarios, contraseñas de ensayo y códigos son exclusivamente fixtures **públicos sintéticos** dentro de un backend temporal Django; sin cuentas reales ni credenciales productivas. La CA de TLS es generada para cada ensayo y solo se exporta su parte pública. Ninguna migración llega a PostgreSQL persistente.

## Ejecución única en Ubuntu

```bash
cd ~/vencira-m3-localcheck
git fetch origin feature/m3-android-local-notifications
git merge --ff-only FETCH_HEAD
bash scripts/g11_https_first_issue_logout.sh
echo "G11_LOCAL_RESULT=$?"
```

Si falla, compartir el primer error Flutter/Django y `G11_HTTPS_GATE_RESULT`. El runner muestra un máximo de las últimas líneas del log en fallos, sin cuerpos, credenciales ni cabeceras de autorización. No es necesario repetir G7-G10: **G11 usa una nueva instancia aislada del mismo fixture**.

Salida esperada (hasta recibirla es exclusivamente objetivo, **no PASS**):

```text
N1_STATIC_g11_real_https_first_issue_logout_isolated=OK
N1_STATIC_GATE_RESULT=OK
G11_HTTPS_FLUTTER_ANALYZE=OK
G11_FIRST_ISSUANCE_HTTPS_COMMITTED=OK
G11_STORAGE_FAILURE_NO_PASSWORD_HTTP=OK
G11_LOST_ISSUANCE_RESPONSE_FENCED=OK
G11_FULL_RECOVERY_VERIFIED_HTTPS=OK
G11_REMOTE_REVOKE_FAILURE_DURABLE=OK
G11_REVOKE_RETRY_SERVER_DENIES_OLD_ACCESS=OK
G11_POST_COMMIT_REVOKE_RESPONSE_LOSS_FENCED=OK
G11_AMBIGUOUS_REVOKE_RETRY_CANNOT_REOPEN=OK
G11_MFA_SERVER_REVOKED_AFTER_LOGOUT=OK
G11_HTTPS_FIRST_ISSUANCE_LOGOUT_RESULT=0
G11_HTTPS_GATE_RESULT=0
NO_DEPLOY_NO_LIVE_MIGRATION=1
G11_LOCAL_RESULT=0
```

## Límites y release

El PASS G11 probará únicamente el código cliente y emisor **de laboratorio** Django sobre TLS real, no el uso de Android Keystore para esta secuencia, ni MFA/roles/autorización en producción, ni restauraciones de una base de datos real. No activa `main.dart`, no registra `native_sessions_lab.test_urls` en las URLs normales y no aplica migraciones persistentes. **PR #17 DRAFT; `MFA_RELEASE_AUTHORIZED=NO`, `MB1_RELEASE_AUTHORIZED=NO`, `C_FICHA_RELEASE_AUTHORIZED=NO`, `GLOBAL_FREEZE=NOT_VERIFIED`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.**

## G11 — Primera ejecución interrumpida en N1 por ampliación de whitelist (03/11/2026)

El operador ejecutó `bash scripts/g11_https_first_issue_logout.sh` e informó: `N1_STATIC_g7_fast_batch_isolation_and_full_suite_gates=FAIL`, mientras **todas las demás condiciones N1 listadas, incluida `N1_STATIC_g11_real_https_first_issue_logout_isolated=OK`, pasaron**; global `N1_STATIC_GATE_RESULT=FAIL`, `G11_HTTPS_GATE_RESULT=1`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`. **El script se detuvo antes de cualquier `flutter analyze` o prueba HTTPS**.

Causa exacta verificada en código: la comprobación `g7_fast_batch_isolation_and_full_suite_gates` en `scripts/n1_static_security_gate.py` todavía requería la cadena literal `d2|e|f|g|h)` del selector del runner de G7. G11 había extendido correctamente el selector a `d2|e|f|g|h|g11)`, haciendo fallar un guard obsoleto. Se actualizó N1 para exigir el selector nuevo y, además, **se añadieron verificaciones explícitas de que todos los marcadores obligatorios de G7 D2/E/F/G/H permanecen en el runner**, con `g11) required+=` independiente. Se revisaron remotamente presencia de las cinco ramas de Dart, marcadores históricos, aislamiento y nueva condición de grupo: todas las comprobaciones literales revisadas OK. **No se alteraron endpoints, claves, lógica de autenticación ni se relajaron garantías de seguridad**.

**G11 continúa PENDING:** solo se corrigió el bloqueo estático; no hay aún PASS de Dart o Django HTTPS. Reejecutar `bash scripts/g11_https_first_issue_logout.sh` tras fast-forward de la rama para obtener los resultados del lote G11. No repetir G7–G10 ni instalar nada en producción. PR #17 DRAFT, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.
