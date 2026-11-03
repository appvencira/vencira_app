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

## G7-A: nueva hipótesis de zona asíncrona en widget tests

Cuatro tests fallan sin activar fence ni escribir refresh, aun cuando el puerto sintético recibe password/MFA; test directo del coordinador y entrada `VenciraApp` pasan. Hipótesis fundada en `NativeRefreshCredentialVault._previous = Future<void>.value()` construido en `setUp` fuera de `testWidgets`. Se ha movido la construcción al cuerpo de cada test, sin modificar código operativo. **PENDING recheck Flutter dirigido**, no implicar PASS, ver `G7_NATIVE_LOGIN_INTEGRATION_2026-11-03.md`. Bloqueos de release intactos.

## G7-A PASS local y G7-B HTTP integración candidata

El operador remite resultado `G7_RECHECK_RESULT=0` con seis pruebas `native_lab_login_shell_test.dart` **PASS** tras corregir el fixture asíncrono. Este recibo valida solo G7-A con puertos simulados y **no es login Django operativo**.

Se ha implementado `clients/flutter/test/native_http_login_integration_test.dart` con cuatro pruebas nuevas que integran UI → `NativeHttpAuthPort` HTTP mock (contrato Django) → `NativeSessionCoordinator` → vault sintético → `NativeApiTransport` Bearer → revocación. Incluye MFA, 401 y fallo de revocación con reintento. Agregado a runner M3, CI Flutter y guard estático. **G7_B_HTTP_WIDGETS=PENDING:** ningún resultado local ni GitHub Actions se ha acreditado para estos commits. Consultar [documento G7](G7_NATIVE_LOGIN_INTEGRATION_2026-11-03.md).

Siguiente validación: **Flutter focalizado** con `flutter pub get && flutter analyze && flutter test test/native_lab_login_shell_test.dart test/native_http_login_integration_test.dart --reporter expanded` dentro del contenedor Flutter. Si 0, construir prueba E2E HTTPS real contra un emisor Django temporal y aislado sin rutas operativas ni BD persistente. `MFA_RELEASE_AUTHORIZED=NO`, `MB1_RELEASE_AUTHORIZED=NO`, `C_FICHA_RELEASE_AUTHORIZED=NO`; `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## G7-B primer intento local rojo; streaming mock candidato

Resultado del operador: `G7_B_HTTP_TEST_RESULT=1`, `flutter analyze` limpio, seis pruebas G7-A correctas y de cuatro G7-B solo la denegación HTTP 401 pasa. El flujo de éxito/MFA no alcanza UI esperada. Hipótesis: el cuerpo de `MockClient(Response)` entrega eventos diferidos incompatibles con el avance `FakeAsync` esperado, mientras 401 se rechaza antes de leer el cuerpo. Cambio limitado a `native_http_login_integration_test.dart`: streaming HTTP sincrónico via `MockClient.streaming` con `Stream.multi/addSync/closeSync`, sin bypass de parser. **NUEVA VALIDACIÓN PENDIENTE**, no hay PASS de G7-B. Detalles en [G7](G7_NATIVE_LOGIN_INTEGRATION_2026-11-03.md). Release bloqueado: `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## G7-B: 13 errores de análisis de MockClient.streaming corregidos, recheck pendiente

El intento del operador contra `491f0702` terminó en `G7_B_HTTP_RECHECK=1` **antes de ejecutar tests**: `flutter analyze` encontró 13 errores por firma errónea de `MockClient.streaming` y uso de `Request.body` sobre `BaseRequest`. Código test-only actualizado para firma `(BaseRequest, ByteStream)` y lectura del cuerpo de petición desde `ByteStream.bytesToString()`. **Aún no PASS**; los tres fallos iniciales G7-B no se han revalidado. No modificar Django ni PG17, no deploy. Ver `docs/G7_NATIVE_LOGIN_INTEGRATION_2026-11-03.md`.

## G7-B siguiente iteración candidata: cliente HTTP de test determinista

El segundo resultado local `G7_B_HTTP_RECHECK=1` pasó análisis y 7/10 pruebas; las seis G7-A pasan y tres de las cuatro G7-B siguen bloqueadas en respuestas HTTP 200. Para reducir el área de fallo, la suite `native_http_login_integration_test.dart` usa un `http.BaseClient` simulado con `send` inmediato, validación estricta de request y respuesta JSON por el **puerto operativo potencial**, sin tocar implementación, backend ni seguridad. Añade diagnóstico sin credenciales para el próximo fallo. **Aún no PASS de G7-B**. Ver `docs/G7_NATIVE_LOGIN_INTEGRATION_2026-11-03.md`; `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

El gate `scripts/n1_static_security_gate.py` se actualizó para reconocer el nuevo `BaseClient` de prueba sin dejar un falso fallo por la búsqueda antigua `MockClient(`. Ejecutar gate estático y la suite Flutter dirigida tras actualizar; ambos **PENDING**, no marcar green por commits.

## G7-B: decisión de separar HTTP asíncrono real del test de widgets

El operador confirmó `N1_STATIC_GATE_RESULT=OK`, análisis Flutter limpio y `G7_B_RESULT=1` (HTTP 200 recibido, `fenceActive=false`, `vaultPopulated=false`, sin error visible). La prueba G7-B continuaba mezclando la lectura `Stream` HTTP con el reloj `FakeAsync` de `testWidgets`. Se ha sustituido la suite G7-B por **cinco pruebas de integración `test()`** con `MockClient` y asíncrono real: credenciales + GET Bearer + logout, MFA, denegación de contraseña, revocación/reintento, y 401 Bearer. **G7-A mantiene sus seis pruebas de widget**, validadas previamente. Es una separación deliberada; **no existe todavía prueba E2E UI→HTTP→Django real**.

`scripts/n1_static_security_gate.py` actualizado para garantizar MockClient-only en HTTP y verificar la UI en el archivo separado. **G7-B nueva batería PENDING**; no marcar validado hasta ejecución local o CI efectiva. PR draft, `NO_DEPLOY_NO_LIVE_MIGRATION=1`, sin changes a rutas Django, backend ni DB persistente. Detalles en `docs/G7_NATIVE_LOGIN_INTEGRATION_2026-11-03.md`.

## G7-A/G7-B verificados localmente: 11 PASS

Operador comunica `G7_SPLIT_RESULT=0`, `All tests passed!` con **6 pruebas G7-A** de UI/coordinador y **5 G7-B** de HTTP `MockClient`/MFA/Bearer/vault/revocación. `flutter analyze` sin problemas. El gate estático se informó `N1_STATIC_GATE_RESULT=OK` en el intento inmediatamente anterior. Este paso cierra el **bloque local simulado**, no el E2E Flutter↔Django ni APK Android. Continuar con Django socket de laboratorio en BD desechable; mantener gates de release cerrados y sin despliegue.

## G7-C Django socket loopback — implementación candidata, pruebas pendientes

A partir de G7-A+B local **11/11 PASS**, se añadió `native_sessions_lab.test_loopback_http_contract` (tres `LiveServerTestCase`) para verificar por sockets TCP/HTTP exclusivamente en `127.0.0.1` una autenticación real de Django **solo en entorno de test con BD desechable**: password, Bearer, refresh y replay, revocación, cookies/Origin, rechazo de credenciales. No es E2E Flutter→Django y **no es HTTPS**. Incluido en `n1_identity_pg17_ephemeral.sh --lab`, CI SQLite y PG17, gate estático que impide confundir URLConf de test con operacional. **G7-C RESULTADO PENDING**; ejecutar gate estático, build imagen de test y PG17 --lab sobre checkout actualizado. Sin deploy ni migraciones persistentes; el PR sigue draft.

## G7-C PASS PG17 y G7-D1 HTTPS verificado candidato (03/11/2026)

El operador confirma `Ran 84 tests in 30.472s\nOK\nN1_PG17_LAB_RESULT=0` con PostgreSQL17 desechable; este suite incluye `native_sessions_lab.test_loopback_http_contract`. G7-A+B también se confirmaron antes `G7_SPLIT_RESULT=0`, **11 PASS**. Esto acredita que G7-C trabaja con Django por socket HTTP local; **no es un E2E Flutter HTTPS**.

Añadido `backend/native_sessions_lab/test_verified_https_loopback.py`, tres casos `LiveServerTestCase` tras **proxy TLS temporal en loopback**, CA+certificado efímeros firmados para SAN `dev.vencira.es`, cliente con SNI y confianza exclusiva en CA temporal, y pruebas de rechazo de CA/hostname incorrectos. Se valida password → Bearer → revocación y denegación Cookie/Origin atravesando TLS. Sin DNS remoto, puertos Docker publicados, cambios operativos, migraciones persistentes o claves versionadas.

Se incluye en `n1_identity_pg17_ephemeral.sh --lab` y en CI SQLite/PG17; modo nuevo `--lab-https` permite **validar solo estos tres casos** en Docker PG17 privado `tmpfs` sin repetir los 84 anteriores. Gate estático `g7_https_lab_ephemeral_tls_and_hostname` exige TLS estricto y URLConf de test. **G7_D1_TLS_PG17_RESULT=PENDING**, no hay ejecución registrada. El siguiente bloque G7-D2 (Flutter↔Django por HTTPS real) sigue pendiente y la prueba D1 no debe confundirse con él.

Próximo paso local:
```bash
cd ~/vencira-m3-localcheck
git status --short
git fetch origin feature/m3-android-local-notifications
git merge --ff-only FETCH_HEAD
python3 scripts/n1_static_security_gate.py &&
bash -n scripts/n1_identity_pg17_ephemeral.sh &&
sudo docker build -t vencira-m3-backend-test ./backend &&
bash scripts/n1_identity_pg17_ephemeral.sh --lab-https
echo "G7_D1_GATE_RESULT=$?"
```

Conservar `MFA_RELEASE_AUTHORIZED=NO`, `MB1_RELEASE_AUTHORIZED=NO`, `C_FICHA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`. PR #17 sigue **DRAFT**, no fusionar.

## G7-D1 PASS y G7-D2 Flutter-Django HTTPS candidato (03/11/2026)

El operador comunicó `Ran 3 tests in 2.279s; OK; G7_D1_TLS_PG17_RESULT=0` en PostgreSQL 17 temporal. Se suman G7-A+B `11 PASS` y G7-C `84 PASS` previos. Estos recibos acreditan la capa de servidor, UI sintética y puertos Flutter con mock, **no** una APK ni login móvil operativo.

Añadido **G7-D2 pendiente**: el script `scripts/g7_d2_https_flutter_django.sh` arranca Django test-only y el cliente Flutter en **red Docker --internal sin puertos publicados**, emisor WSGI Django con SQLite en `tmpfs`, proxy HTTPS con CA/certificado efímeros, y cliente `HttpClient` real con CA explícita, hostname/SNI, peer IPv4 privado y sin desactivar la verificación. Verifica contraseña, Bearer `/me/`, persistencia de refresh en store sintético, revocación, cookie, contraseña incorrecta y fallos TLS. La prueba Flutter de red `g7_d2_https_live_test.dart` se omite fuera de un entorno G7-D2 explícito; G7-A/B permanecen separados. CI propio `g7-d2-isolated-https.yml` y static guard incluidos. No es todavía Android en dispositivo ni MFA real entre procesos.

`G7_D2_LOCAL_RESULT=PENDING`; no indicar PASS ni merge/deploy/migrate. Validar con checkout actualizado y `bash scripts/g7_d2_https_flutter_django.sh` (el script compila imagen Django, precarga Flutter, ejecuta el test y limpia contenedores/red incluso al fallar). Mantener `MB1_RELEASE_AUTHORIZED=NO`, `MFA_RELEASE_AUTHORIZED=NO`, `C_FICHA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## G7-D2 fallo de análisis Dart corregido; verificación local pendiente

Operador informó `G7_D2_GATE_RESULT=1`, `flutter analyze` con tres `undefined_setter` en `connectionTimeout/idleTimeout/connectionFactory`. La cascada Dart posterior al `findProxy = (_) => 'DIRECT'` se estaba aplicando al `String` devuelto por la función. Se separaron las asignaciones `HttpClient` sin alterar la política TLS/URI/IPv4 privada. **Aún no hay conexión Django↔Flutter validada**, se detuvo antes de crear el laboratorio. Repetir el script G7-D2 focalizado en rama actualizada, sin PG17 ni deploy. Sigue `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## G7-D2 exportación de CA: corrección de runner pendiente de recheck

Con código previo: `flutter analyze` PASS, fixture Django `G7_D2_FIXTURE_READY=OK`, `G7_D2_GATE_RESULT=1` por `docker cp` incapaz de encontrar `/tmp/g7d2-public-ca.pem` dentro de contenedor temporal; el cliente Dart no llegó a conectarse. Se cambió únicamente `scripts/g7_d2_https_flutter_django.sh` a verificar la CA pública y transmitirla por `docker exec cat`, validar PEM, fijar 0600, manteniendo la clave privada confinada en el contenedor. Gate estático actualizado. **G7-D2 aún NO validado**. Repetir script focalizado. Sin cambios backend ni despliegue/DB persistente, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## G7-D2: runner shell roto sustituido; revalidar antes de contabilizar PASS

El último intento reportó `G7_D2_GATE_RESULT=1`, aun con `flutter analyze` y fixture Django OK. La causa se identificó en GitHub: comillas rotas en el `grep` del PEM, tres ejecuciones Flutter duplicadas y marcadores **falsos** de éxito. Además, la CA **pública** con 0600 era ilegible para el usuario del cliente Flutter en Docker. Se ha sustituido por completo el script G7-D2: entrega solo CA pública validada por Python/SSL a 0644 y montada read-only, directorio temporal 0700, una única ejecución Flutter, `tee` con `pipefail`, comprobación obligatoria del resultado interno y `All tests passed!` antes de declarar éxito. Gate estático ampliado para detectar ejecuciones y echos duplicados. **G7-D2 continúa PENDING.** Repetir solo script focalizado tras `git merge --ff-only`. Mantener `NO_DEPLOY_NO_LIVE_MIGRATION=1`, PR draft, release NO.

## G7-D2 diagnóstico de transporte (pendiente)

La prueba local supera el análisis Flutter, arranque de Django, lectura de CA pública y fence inicial, pero falla al autenticar con `NativeHttpAuthFailure` genérica. Se añadió al probe de laboratorio un handshake TLS separado y un registro limitado a estado HTTP, formato JSON y tipo de error; no registra contenido ni credenciales. **G7-D2 no validado**. Reejecutar únicamente `bash scripts/g7_d2_https_flutter_django.sh` sobre rama actualizada y revisar marcadores `G7_D2_TLS_PREFLIGHT`, `G7_D2_FACTORY` y `G7_D2_HTTP_PASSWORD`. Sin desplegar ni migrar datos persistentes.

## G7-D2: causa precisa del transporte TLS encontrada; recheck pendiente

Logs recientes: handshake independiente `G7_D2_TLS_PREFLIGHT=OK`, pero `HttpClient.connectionFactory` registraba `G7_D2_FACTORY_PRIVATE_TCP=OK` y el primer POST fallaba como `_ClientSocketException` sin estado HTTP. El callback reemplazaba el `SecureSocket.startConnect` automático de Dart y devolvía un **Socket no cifrado**, a pesar de usar una URI HTTPS. La corrección del **probe de laboratorio** devuelve un `ConnectionTask.fromSocket` con `SecureSocket.secure(raw, host: uri.host, context: trust)`, verifica el hostname original con la CA temporal y mantiene el destino Docker privado. Gate estático reforzado para prohibir el viejo callback de TCP sin TLS. **Pendiente de validación G7-D2**: actualizar rama y repetir el script aislado; no repetir PG17, no deploy, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## G7-D2 validado: HTTPS real Flutter/Dart ↔ Django (03/11/2026)

Recibo local: `G7_D2_HTTPS_FLUTTER_DJANGO_RESULT=0`, `All tests passed!`, `G7_D2_GATE_RESULT=0`. Fueron verificadas la CA temporal y el nombre del servidor, login HTTP 200 con refresh protegido sintético, GET Bearer 200, revocación HTTP 200 y rechazo posterior 401, contraseña errónea 401, cookie web 403, CA no confiable y nombre TLS incorrecto rechazados. Confirmación exclusiva de laboratorio Docker interno con SQLite temporal; no equivale a APK Android ni autenticación operativa. Los bloques G7-A/B (11), G7-C (84) y G7-D1 (3) siguen validados. Pendientes MFA HTTPS, rotación/replay y análisis de `Set-Cookie` en respuesta HTTP 403, para determinar si es una cookie de borrado. PR draft, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## G7-D2: comprobación de borrado de cookie PASS (03/11/2026)

El operador confirma `G7_D2_REJECT_COOKIE_SESSION_NAME=true`, `G7_D2_REJECT_COOKIE_DELETION=true`, `G7_D2_WEB_COOKIE_RESPONSE_ONLY_DELETES_SESSION=OK`, junto con `G7_D2_HTTPS_FLUTTER_DJANGO_RESULT=0`, `All tests passed!` y `G7_D2_GATE_RESULT=0`. La cabecera de respuesta en el rechazo HTTP 403 elimina exclusivamente la cookie web previa; no concede autenticación. G7-D2 y su subgate de cookie quedan validados en red Docker privada con SQLite efímera. Siguiente grupo G7-E: MFA TOTP y rotación/replay de refresh contra Django vía cliente Dart/Flutter real. La APK y los gates de despliegue siguen pendientes.

## G7-D2 cookie PASS y G7-E MFA/refresh HTTPS candidato (03/11/2026)

El operador confirmó después de la primera prueba verde el borrado seguro de cookie HTTP403: `G7_D2_REJECT_COOKIE_SESSION_NAME=true`, `G7_D2_REJECT_COOKIE_DELETION=true`, `G7_D2_WEB_COOKIE_RESPONSE_ONLY_DELETES_SESSION=OK`; `G7_D2_GATE_RESULT=0`. **G7-D2 íntegro PASS local**.

En la misma rama está implementado **G7-E pendiente**: usuario de laboratorio Django con `UserMfaState` habilitado, TOTP RFC6238 sintético cifrado y Fernet efímera dentro del contenedor; Dart genera su código de test mediante `crypto` en `dev_dependencies`. La prueba usa realmente `NativeHttpAuthPort` y `NativeSessionCoordinator` sobre HTTPS para demostrar challenge sin fence ni refresh, MFA correcto y denegación de OTP reutilizado, acceso y logout revocado. El segundo bloque valida por HTTPS rotación y replay del refresh, invalidación del Bearer antiguo/nuevo, y revocación del token girado. **Importante:** `NativeSessionCoordinator` sigue sin adaptador de renovación automática o recuperación de refresh ante crash. La rotación se ensaya en `NativeHttpAuthPort`, no constituye funcionalidad operativa.

El runner G7-D2 exige además `G7_E_MFA_HTTPS_RESULT=0` y `G7_E_REFRESH_REPLAY_RESULT=0` antes del éxito final, con control estático `g7_e_https_mfa_rotation_only_in_lab`. Validación local focalizada: fast-forward y `bash scripts/g7_d2_https_flutter_django.sh`; no repetir el conjunto PG17 ni habilitar rutas. G7-E **PENDING**, PR draft y `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## G7-E adicionales: vector RFC6238 y rechazo de redirecciones

Antes de la validación local se añadió un vector conocido RFC6238 para HMAC-SHA1: a los 59 segundos con la semilla sintética de prueba, TOTP de 6 cifras `287082`. Esto verifica que el generador Dart del ensayo coincide con RFC6238, sin mostrar TOTP operativo. Las peticiones Bearer de inspección directa bloquean redirecciones HTTP. El gate estático exige ambos controles. G7-E sigue PENDING hasta ejecución local. No hay cambios en autenticación ni rutas de producción.

## G7-E PASS y G7-F1 recuperación de respuesta ambigua candidata (03/11/2026)

G7-E confirmado localmente con `G7_E_MFA_HTTPS_RESULT=0`, `G7_E_REFRESH_REPLAY_RESULT=0`, `G7_D2_GATE_RESULT=0`, `All tests passed!`. MFA TOTP real Django↔Dart, reuse denegado, Bearer/fence/vault/revocación y refresh rotation/replay sobre HTTPS real, sin red ni DB operativas. Siguen validados G7-A/B, G7-C, G7-D1, G7-D2.

Se añade G7-F1 sin validación local: prueba de red HTTPS con `NativeRecoveryLoginGateway` y `NativeRefreshRecoveryJournal`, marcador duradero ANTES del refresh, rotación aplicada en Django pero respuesta perdida para Dart, arranque frío bloqueado, contraseña incorrecta no revoca sesión vieja, reautenticación explícita account-wide sí revoca token anterior, reemplaza refresh en vault y borra marcador antes de activar fence. Revocación final obligatoria. Runner exige `G7_F_AMBIGUOUS_REFRESH_RECOVERY_RESULT=0` y `G7_F_HTTPS_RECOVERY=OK`; gate estático actualizado. Se conserva `NativeSessionCoordinator` sin refresh automático, rutas test-only y PR draft. **G7-F1 PENDING.** Ejecutar tras fast-forward `bash scripts/g7_d2_https_flutter_django.sh` (solo laboratorio desechable). No producción, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## G7-F PASS y consolidación de pruebas sin reejecuciones redundantes

Operador: `G7_F_AMBIGUOUS_REFRESH_RECOVERY_RESULT=0`, `G7_F_HTTPS_RECOVERY=OK`, `G7_E_MFA_HTTPS_RESULT=0`, `G7_E_REFRESH_REPLAY_RESULT=0`, `All tests passed!`, `G7_D2_GATE_RESULT=0`. **G7-F1 PASS local**; demuestra que una respuesta de refresh perdida fuerza full-reauth y revocación total en el lab Django/Flutter HTTPS.

A petición del operador se incorporó el **runner agrupado**: `scripts/g7_d2_https_flutter_django.sh --fast` solo G7-F, `--group d2|e|f` para pruebas específicas, `--all` (default) para cierre de macrofase. Un único fixture de Django, cache Pub en volumen Docker de paquetes públicos con `flutter pub get --offline` primero en modo rápido y fallback, salida corta de marcadores de PASS, log de diagnóstico solo si falla. Modo rápido no ejecuta `flutter analyze`; el test sí compila Dart. Modo `--all` ejecuta analyzer completo, D2 + E + F y todos los marcadores, CI siempre `--all`. Cache solo de dependencias; BD, CA y secretos siguen efímeros en contenedores/red privada. Static gate G7 batch y workflow actualizados.

**El runner agrupado es candidato no validado localmente**: primer uso recomendado, después de acumular varios cambios, `bash scripts/g7_d2_https_flutter_django.sh --all` una sola vez al cerrar macrofase, no ejecutar en cada pequeño commit. No repetir G7-A/B/C/D1 para depurar iteraciones Dart. No habilitar producción, no migrar BD persistente: `NO_DEPLOY_NO_LIVE_MIGRATION=1`, MFA/MB1/C_FICHA release NO.

### Corrección de marcadores del runner agrupado

Los modos `--fast` y `--group d2|e|f` informan `G7_BATCH_GATE_RESULT` y `G7_BATCH_RESULT`, además de sus marcadores de grupo; **no** informan `G7_D2_GATE_RESULT=0`, reservado exclusivamente para `--all`. Esto evita confundir un PASS focalizado con una validación integral. El nombre de la prueba Flutter ahora identifica el lote seleccionado. El control estático exige esa separación. Estas mejoras del runner permanecen pendientes de verificación local; G7-F, E y D2 conservan sus PASS anteriores.

## G7 runner --fast PASS confirmado por operador (03/11/2026)

Resultado de la versión agrupada: `G7_BATCH_ANALYZE=SKIPPED_FAST_MODE`, `G7_LAB_GROUP_COMPLETE=f`, `All tests passed!`, `G7_F_AMBIGUOUS_REFRESH_RECOVERY_RESULT=0`, `G7_F_HTTPS_RECOVERY=OK`, `G7_BATCH_RESULT=0`, `G7_BATCH_GATE_RESULT=0`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`, `G7_FAST_LOCAL_RESULT=0`. Se demuestra que la selección focalizada G7-F ejecuta únicamente ese bloque y evita repetir el análisis de Flutter. **No equivale a `--all` de la versión nueva.** La suite integral previa D2+E+F pasó con el ejecutor anterior; el runner agrupado `--all` todavía necesita su propia ejecución al cerrar la macrofase, no en cada commit. Se mantiene red aislada, Django y SQLite temporales, sin release.
