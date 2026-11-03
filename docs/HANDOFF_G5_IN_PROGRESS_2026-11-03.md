# VENCIRA — Handoff G5 en curso, 03/11/2026

**Rama:** `feature/m3-android-local-notifications` · **PR:** #17 (DRAFT). No usar `main` como origen de G5.

## Estado consolidado

> **Validación local confirmada por operador, 03/11/2026, lote `m3-http-contract-20261103T095043Z`:** `M3_HTTP_STATIC=0`, `M3_HTTP_BUILD=0`, `M3_HTTP_PG17_LAB=0`, `M3_HTTP_G4_PG17=0`, `M3_HTTP_FLUTTER=0`, `M3_HTTP_RESULT=0`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`. El runner `--candidate` incluye G5; el sumario proporcionado no muestra por separado `G5_CANDIDATE_PG17_RESULT` ni el SHA exacto del checkout, así que no inventar el marcador aislado ni un recibo CI. Logs retenidos solo localmente en `/home/vencira/vencira-m3-results/m3-http-contract-20261103T095043Z`. Esta evidencia valida el **lote al que apuntaba el checkout del operador**, no commits posteriores. No autoriza release.


G4 anterior: 20/20 PG17 PASS sin deriva de esquema `0001` (evidencia local 03/11); G6 integral PASS **anterior a G4**. Esos resultados **no validan** estos nuevos commits G5. Para contexto base: [handoff G4→G5](HANDOFF_G4_G5_2026-11-03.md).

G5 publicado en GitHub, **con lote integral local satisfactorio comunicado para la revisión ejecutada; CI GitHub Actions sigue sin recibo confirmado**:

1. [Bloque 1](G5_MOBILE_SECURITY_MACROBLOCK_2026-11-03.md): atribución de IP y confianza de proxy de un salto estricto, aislada y sin llamada HTTP.
2. [Bloque 2](G5_MOBILE_THROTTLE_2026-11-03.md): cuotas candidatas compartidas en PG17 por cuenta e IP, HMAC del sujeto, migración 0002 solo test, pruebas de concurrencia, CI y runner efímero.
3. Gate estático N1 actualizado, runner `n1_identity_pg17_ephemeral.sh --candidate` incluye tests G4+G5 y emite `G4_CANDIDATE_PG17_RESULT` y `G5_CANDIDATE_PG17_RESULT`.

**No existe enlace operativo** entre esos mecanismos de G5 y las vistas de login. No hay auditoría completa, rotación de claves ni un emisor confiable. No deducir seguridad de producción.

## Invariantes bloqueados

```
NO_DEPLOY_NO_LIVE_MIGRATION=1
MFA_RELEASE_AUTHORIZED=NO
MB1_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
GLOBAL_FREEZE=NOT_VERIFIED
```

- No despliegue, no migración de la base persistente, no merge de PR #17.
- `VENCIRA_NATIVE_SERVICE_CANDIDATE` sigue restringido a `VENCIRA_ENV=test`. `VENCIRA_NATIVE_BEARER_ENABLED=False` en settings; URLConfs operativos sin rutas móviles.
- Nunca subir llaves, dumps, credenciales, datos personales ni logs privados al repositorio público.

## Validación local ya comunicada y siguiente comprobación

En `/home/vencira/vencira-m3-localcheck`, comprobar el estado Git antes de fast-forward. Con checkout actualizado y entorno de Docker aislado:

```bash
git status --short
git fetch origin feature/m3-android-local-notifications
git merge --ff-only FETCH_HEAD
python3 scripts/n1_static_security_gate.py
bash scripts/m3_native_http_contract_batch.sh
```

El batch debe construir una nueva imagen, utilizar PG17 `tmpfs` y no conectar a la DB persistente. **No ejecutar si el script ha sido modificado localmente para apuntar al servidor real.** Recoger solamente indicadores de salida `M3_HTTP_STATIC`, `M3_HTTP_BUILD`, `M3_HTTP_PG17_LAB`, `M3_HTTP_G4_PG17`, `M3_HTTP_FLUTTER`, `M3_HTTP_RESULT`, `G5_CANDIDATE_PG17_RESULT` y código de salida del proceso. El segundo indicador se emite en el runner subordinado y podría no estar propagado al sumario principal.

## Siguientes decisiones de ingeniería

- Proteger frente a bloqueo malicioso por cuenta y denegación de servicio; validar procedencia real Caddy/Nginx e IPv6 y tratamiento de múltiples proxies.
- Establecer limpieza de buckets y retención RGPD.
- Eventos de auditoría mínimos y acceso a soporte, sin contraseñas ni tokens.
- Diseño real de claves HMAC por propósito, versionado, custodia externa y recuperación.
- Emisión password+MFA desde un verificador de confianza y tests de carrera/replay; ninguna vista pública antes de pasar gates.

**No marcar PASS, release o custodia real sin evidencia.** Esta nota es documental y no constituye prueba ejecutada.

## G5 macrobloque 3 añadido después del PASS local

[Auditoría mínima candidata](G5_MOBILE_AUTH_AUDIT_2026-11-03.md): modelo `MobileAuthAuditEvent`, migración test-only `0003`, HMAC de actor, UUID de idempotencia, eventos restringidos, retención explícita y 8 tests de contrato. CI y runner PG17 están actualizados. **Estas modificaciones son posteriores al lote `20261103T095043Z`: el PASS anterior NO las cubre.** Se añadieron dos pruebas de deduplicación concurrente PG17 (pendientes de ejecución); siguen sin verificarse integridad ante administradores de la DB, vinculación a login real y custodia de claves. Las migraciones 0002/0003 permanecen **exclusivamente en el grafo del candidato test-only**.

## Segundo PASS local integral — 03/11/2026, 12:13 UTC

El operador comunica `M3_HTTP_STATIC=0`, `M3_HTTP_BUILD=0`, `M3_HTTP_PG17_LAB=0`, `M3_HTTP_G4_PG17=0`, `M3_HTTP_FLUTTER=0`, `M3_HTTP_RESULT=0` y `NO_DEPLOY_NO_LIVE_MIGRATION=1`. Logs privados retenidos en `/home/vencira/vencira-m3-results/m3-http-contract-20261103T121338Z`. **Este segundo lote es posterior a la incorporación del bloque G5 de auditoría y su carrera PG17, y sustituye el estado PENDING de esa suite para el checkout ejecutado.** No se ha aportado `git rev-parse HEAD` del checkout ni el marcador específico `G5_CANDIDATE_PG17_RESULT`; por tanto no inferir SHA exacto ni CI verde. Los commits nuevos que siguen a esta anotación requerirán verificación posterior. Sin autorización de deploy, merge, autenticación operativa ni migraciones persistentes.

## G5 macrobloque 4 después del segundo PASS local

[Política de claves versionadas](G5_MOBILE_KEY_ROTATION_2026-11-03.md) publicada: `g5_keyring_policy.py` + nueve pruebas, CI/runner y gate estático. Permite separar propósitos, verificar claves previas con fecha fin y rechazar formatos legados. **No está conectada a Django, DB ni autenticación**. Los campos digest existentes tienen 64 caracteres y el formato `k1:<id>:<digest>` requiere un nuevo contrato de esquema; faltan custodia real y rotación integrada. **Tests G5 bloque 4 PENDING**: el segundo PASS del operador es anterior. Todos los bloqueos de release permanecen.

## Tercer PASS integral y macrobloque 5

El operador comunica el tercer lote `m3-http-contract-20261103T125155Z` con los cinco controles `M3_HTTP_STATIC/BUILD/PG17_LAB/G4_PG17/FLUTTER=0`, `M3_HTTP_RESULT=0` y `NO_DEPLOY_NO_LIVE_MIGRATION=1`. El resultado valida la revisión ejecutada antes del bloque 5; **SHA del checkout no comunicado, CI actual no confirmada**.

[Macrobloque 5 — capacidad del digest versionado](G5_MOBILE_DIGEST_CAPACITY_2026-11-03.md): cinco campos candidato ampliados a `max_length=96`, migración `0004` test-only, tres pruebas de capacidad/coexistencia de digests (sin transformar registros), CI y runner actualizados. **PENDIENTE NUEVO PASS**. El nuevo esquema no integra el keyring, no cambia digests existentes y no debe confundirse con rotación de claves operativa. No desplegar ni migrar BD persistente. Los gates MFA/MB1/C-FICHA quedan NO y `GLOBAL_FREEZE=NOT_VERIFIED`.

## Cuarto lote — recuperación tras fallo transitorio de Docker build

- Primer intento tras macrobloque 5: `m3-http-contract-20261103T131115Z` produjo `M3_HTTP_STATIC=0`, `M3_HTTP_BUILD=1`, `M3_HTTP_PG17_LAB=99`, `M3_HTTP_G4_PG17=99`, `M3_HTTP_FLUTTER=0`, `M3_HTTP_RESULT=1`. Los valores 99 son fases omitidas por dependencia del build, no tests PG17 fallidos. **Causa del fallo de Docker sin confirmar**, no se ha leído el log original.
- Repetición `m3-http-contract-20261103T131438Z`: `M3_HTTP_STATIC=0`, `M3_HTTP_BUILD=0`, `M3_HTTP_PG17_LAB=0`, `M3_HTTP_G4_PG17=0`, `M3_HTTP_FLUTTER=0`, `M3_HTTP_RESULT=0`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`; Flutter informa `77 tests passed`. Logs privados: `/home/vencira/vencira-m3-results/m3-http-contract-20261103T131438Z`.
- Resultado: **PASS comunicado para el checkout local ejecutado después del bloque 5**. No afirmar CI PASS ni ejecución de cada test PG17 por separado: no se remitió SHA de `git rev-parse HEAD` ni el marcador individual `G5_CANDIDATE_PG17_RESULT`. El bloque 5 deja de figurar como pendiente en la síntesis temporal, pero cualquier commit posterior necesita revalidación.
- Sin deploy, merge, ejecución en BD persistente ni apertura de endpoints. `MFA_RELEASE_AUTHORIZED=NO`, `MB1_RELEASE_AUTHORIZED=NO`, `C_FICHA_RELEASE_AUTHORIZED=NO`, `GLOBAL_FREEZE=NOT_VERIFIED`.

## Transición prioritaria G7-A — login nativo antes de pruebas visuales

Por decisión del operador (03/11/2026) se prioriza [G7 entrada nativa inyectable](G7_NATIVE_LOGIN_INTEGRATION_2026-11-03.md). Se han conectado `NativeLoginScreen` y `NativeSessionCoordinator` mediante `NativeLabLoginShell` con posibilidad de inyección exclusiva en builds no-release, sin construir un issuer ni rutas operativas, y con pantalla de sesión sintética **sin acceso a recursos**. En ausencia de inyección, Android continúa usando la pantalla web externa. Tests nuevos verifican password+MFA simulados, apertura solo tras fence, revocación, limpieza segura y reintento; CI y runner M3 actualizados. **G7_A_LAB_UI_TESTS=PENDING; el último PASS comunicado `20261103T131438Z` es anterior a estos commits.** Pendiente crítico: emisor password/MFA real, backend temporal aislado, adapter HTTPS y prueba en dispositivo. No habilitar el acceso nativo productivo ni desplegar/migrar.

## G7-A Flutter rojo y corrección candidata

El operador ejecutó `m3-http-contract-20261103T133437Z`, con `STATIC=0`, `BUILD=0`, `PG17_LAB=0`, `G4_PG17=0`, **`FLUTTER=1`**, **`M3_HTTP_RESULT=1`** y `NO_DEPLOY_NO_LIVE_MIGRATION=1`. Cinco errores en la suite nueva `native_lab_login_shell_test.dart`: al menos `pumpAndSettle timed out` e invariante `debugDefaultTargetPlatformOverride` sin restablecer antes del cierre del test. Ver [incidencia y validación focalizada](G7_NATIVE_LOGIN_INTEGRATION_2026-11-03.md).

Se han publicado correcciones de **tests únicamente**, usando espera acotada por estado observable y `finally` para restaurar el override. **El nuevo estado es PENDING**: aún no hay ejecución verde de `flutter test test/native_lab_login_shell_test.dart`. No repetir PG17; pedir solo validación Flutter focalizada. Ningún backend real fue activado.

## G7-A segundo test focalizado sigue FAIL; diagnóstico reforzado

`flutter analyze` sin incidencias; la prueba `native_lab_login_shell_test.dart` muestra cuatro fallos `g7-native-logout` ausente después de login sintético y pasa el test de `VenciraApp` inyectable. **Todavía no hay causa confirmada de ausencia del callback**. Añadido test unitario que ejerce directamente el coordinador con token sintético y salida de estado no secreto si no aparece la UI esperada; código actualizado **PENDING**. Prohibido marcar G7 verde por pasar análisis o backend. Véase `docs/G7_NATIVE_LOGIN_INTEGRATION_2026-11-03.md`. No requiere repetir PG17.
