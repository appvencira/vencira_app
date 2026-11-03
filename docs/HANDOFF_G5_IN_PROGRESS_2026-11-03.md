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

## G7 — consolidación tras FAST PASS y candidato G/H (03/11/2026)

El operador confirmó el modo focalizado mediante `G7_LAB_GROUP_COMPLETE=f`, `G7_F_AMBIGUOUS_REFRESH_RECOVERY_RESULT=0`, `G7_BATCH_RESULT=0`, `G7_BATCH_GATE_RESULT=0`, `G7_FAST_LOCAL_RESULT=0` y `NO_DEPLOY_NO_LIVE_MIGRATION=1`. El modo rápido seleccionado para F queda **PASS** y no repite D2/E ni analiza Dart. No representa por sí solo un cierre integral. Los casos D2/E/F habían pasado antes en el ensayo no agrupado.

Se han acumulado **dos nuevos bloques** en el mismo laboratorio HTTPS Django/Flutter, todavía sin recibo de ejecución:

**G7-G: recuperación de MFA tras rotación incierta.** Usuario MFA de laboratorio adicional y separado del usuario G7-E, con secreto TOTP RFC de test cifrado por una Fernet efímera que no sale del proceso backend. Primer inicio con TOTP previo aceptable, se arma marcador duradero, se simula refresh rotado en Django pero respuesta perdida, se construye otro gateway/vault/journal sobre el mismo almacén sintético para representar reinicio. El endpoint `recover/password` devuelve desafío: no revoca otras sesiones ni abre fence hasta recibir TOTP. Un OTP previamente consumido no permite recuperar y mantiene el marcador, mientras el Bearer remoto anterior permanece válido. Solo un TOTP válido posterior confirma el nuevo refresh, borra marcador, activa sesión y revoca todas las anteriores, finalizando con revocación/limpieza. Se evita iniciar los dos pasos a pocos segundos del cambio de periodo TOTP para reducir variabilidad del reloj. Marcador `G7_G_MFA_RECOVERY_HTTPS_RESULT=0`. Este caso **no** se ha ejecutado todavía.

**G7-H: fallos silenciosos de almacenamiento protegido.** `_FaultInjectStore` exclusivamente test simula primero una escritura de refresh ignorada y luego un borrado ignorado del marcador persistente. Aunque Django complete la autenticación de recuperación, ambas situaciones deben dejar el fence cerrado, mantener el marcador y requerir nueva autenticación. Con almacén restaurado, la siguiente verificación sustituye credenciales, borra el marcador, activa el fence y permite cerrar/revocar explícitamente. Marcador `G7_H_RECOVERY_STORAGE_FAULTS_RESULT=0`. Este caso **no** se ha ejecutado todavía. No demuestra un fallo de hardware real ni desbloquea Android.

El runner `scripts/g7_d2_https_flutter_django.sh` acepta ahora `--group g`, `--group h` y `--fast` selecciona únicamente el último grupo H para iteraciones. `--all` ejecuta **D2+E+F+G+H** sobre una única red Docker interna y un servidor Django temporal, con análisis Dart y todos los marcadores exigidos; GitHub Actions sigue usando `--all`. Actualizado `scripts/n1_static_security_gate.py` con `g7_g_real_https_mfa_recovery_fail_closed` y `g7_h_https_secure_vault_faults_fail_closed`. El modo focalizado no puede declarar un PASS integral. La cuenta MFA/certificados/SQLite son desechables; la base persistente y los endpoints operativos no se modifican.

**Siguiente validación única cuando proceda** (no ejecutar `--fast` y `--all` en serie): actualizar rama con fast-forward y ejecutar `bash scripts/g7_d2_https_flutter_django.sh --all`. Éxito requiere `G7_G_MFA_RECOVERY_HTTPS_RESULT=0`, `G7_H_RECOVERY_STORAGE_FAULTS_RESULT=0`, marcadores D2/E/F, `All tests passed!`, `G7_BATCH_GATE_RESULT=0` y `G7_D2_GATE_RESULT=0`. **G7-G/H = PENDING**; toda autorización operativa permanece NO, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## G7-G/H primera ejecución `--all` — bloqueo estático corregido (03/11/2026)

El operador ejecutó el runner agrupado `--all` después de añadir G/H. `flutter analyze` comunicó **una advertencia** `unnecessary_non_null_assertion` en `clients/flutter/tool/g7_d2_https_probe.dart:727:57` y el script terminó correctamente en modo fail-closed: `G7_BATCH_GATE_RESULT=1`, `G7_D2_GATE_RESULT=1`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`. **No se ejecutó el laboratorio HTTPS para G7-G/H** en este intento. No es un fallo TLS/Django/MFA, sino del análisis Dart; el hecho de que se detuviera antes de la prueba indica que el gate respeta el análisis limpio.

Se corrigió exclusivamente la expresión en la condición de G7-H `RECOVERY_STORAGE_RETRY_VERIFIED`: después de `access != null &&`, el compilador promueve `access` a no nulo, por lo que se eliminó el `!` sobrante del primer `_bearerHttpStatus(..., access!)`. La siguiente comprobación después de `_require(...)` mantiene su propia aserción explícita. **Corrección publicada; aún no se ha recibido recheck**. Repetir una sola vez `--all` tras actualizar la rama: debe producir marcadores D2/E/F/G/H, `All tests passed!`, `G7_BATCH_GATE_RESULT=0` y `G7_D2_GATE_RESULT=0`. Todos los gates operativos permanecen NO.

## G7 MACRO D2/E/F/G/H: validación integral PASS — 03/11/2026

El operador ejecutó la nueva versión agrupada `bash scripts/g7_d2_https_flutter_django.sh --all` después de corregir el warning Dart. Resultado completo: `flutter analyze: No issues found!`, `G7_D2_FIXTURE_READY=OK`, `G7_D2_PUBLIC_CA_READY=OK`, `G7_LAB_GROUP_COMPLETE=all`, `All tests passed!`, `G7_D2_HTTPS_FLUTTER_DJANGO_RESULT=0`, `G7_E_MFA_HTTPS_RESULT=0`, `G7_E_REFRESH_REPLAY_RESULT=0`, `G7_F_AMBIGUOUS_REFRESH_RECOVERY_RESULT=0`, `G7_G_MFA_RECOVERY_HTTPS_RESULT=0`, `G7_H_RECOVERY_STORAGE_FAULTS_RESULT=0`, `G7_E_HTTPS_MFA_REFRESH=OK`, `G7_F_HTTPS_RECOVERY=OK`, `G7_G_HTTPS_MFA_RECOVERY=OK`, `G7_H_HTTPS_STORAGE_FAULTS=OK`, `G7_D2_FLUTTER_DJANGO_HTTPS=OK`, `G7_BATCH_RESULT=0`, `G7_BATCH_GATE_RESULT=0`, `G7_D2_GATE_RESULT=0`, `G7_MACRO_RESULT=0`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

**Resultado:** G7-D2 + G7-E + G7-F + G7-G + G7-H **PASS END-TO-END en laboratorio aislado**, incluida CA y hostname TLS, login/password y segundo factor, replay TOTP y refresh, recuperación de sesión incierta con MFA, cancelación/bloqueo de credenciales, simulación de fallos silenciosos del almacén protegido y revocación remota. El nuevo agrupador también ha superado `--all`; ya se había confirmado `--fast` en un ensayo independiente. No repetir estos bloques hasta modificar código que afecte sus contratos.

**Límites:** el test usa `_DisposableSecretStore` y `_FaultInjectStore` sintéticos; NO acredita Android Keystore o hardware real ni `flutter_secure_storage` sobre dispositivo, ni demuestra que los endpoints de laboratorio estén instalados en producción. `main.dart` no conecta el prototipo de autenticación, la recuperación automática de refresh no está implementada y faltan gates operativos MB1/MFA/custodia. Mantener PR #17 DRAFT, `NO_DEPLOY_NO_LIVE_MIGRATION=1`, `MFA_RELEASE_AUTHORIZED=NO`, `MB1_RELEASE_AUTHORIZED=NO`, `C_FICHA_RELEASE_AUTHORIZED=NO` y `GLOBAL_FREEZE=NOT_VERIFIED`. La siguiente macrofase debería concentrarse en **evidencia de Android real y validación de almacén protegido**, sin adelantar el despliegue.

## G8 — almacenamiento cifrado Android: candidato aislado, pendiente de ejecución

Se añade `clients/flutter/integration_test/g8_protected_store_device_test.dart` con `integration_test` de Flutter (dependencia **dev-only**) para verificar `FlutterNativeSecretStore` con el plugin `flutter_secure_storage` real en un **emulador Android**. La prueba no crea cuentas, no hace llamadas HTTP y no usa tokens operativos. Inyecta un almacenamiento deliberadamente diferente del previsto para producción mediante `storageNamespace: vencira_g8_emulator_credential_lab_v1` y tokens sintéticos de formato conocido. Revisa: lectura inicial vacía, escritura y comprobación de refresh, creación del marcador duradero de recuperación, recreación de objetos plugin/vault/journal sin activar ningún fence, separación de claves `dev`/`prod` dentro del namespace sintético, recuperación que reemplaza refresh y borra el marcador, rechazo fail-closed de un marcador artificialmente corrupto y limpieza de ambos valores con lectura final vacía. No prueba supervivencia a un reinicio completo del proceso ni demuestra que Android Keystore esté respaldado físicamente por hardware; requiere pruebas separadas.

El ejecutor `scripts/g8_android_store_lab.sh emulator-5554` **deniega por defecto dispositivos físicos, emuladores no verificables, estado ADB distinto de `device` y cualquier emulador donde el paquete `es.vencira.vencira` ya esté instalado**. No borra datos ni desinstala aplicaciones; no altera la instalación operativa. Se debe ejecutar desde un equipo con Flutter/Android SDK/ADB y un **emulador descartable vacío**. El runner analiza el único fichero G8, ejecuta el test Dart/Android en dispositivo y exige `G8_ANDROID_PROTECTED_STORE_RESULT=0`, `All tests passed!` y `G8_EMULATOR_GATE_RESULT=0` antes de dar PASS. La ruta de trabajo es `clients/flutter`. El guard `g8_android_plugin_device_test_isolated` de `scripts/n1_static_security_gate.py` obliga a que existan las restricciones de red, namespace, limpieza y bloqueo de producción. Se mantiene `android:allowBackup=false`.

La CI `.github/workflows/g8-android-store-static.yml` comprueba guard Python, sintaxis bash y `flutter analyze` del test sin iniciar Android ni construir APK. La CI informa expresamente `G8_ANDROID_HARDWARE_RESULT=NOT_RUN`; **un PASS CI no equivale a pruebas sobre Android**.

**Estado: G7 D2/E/F/G/H PASS integral confirmado y documentado; G8 CANDIDATO PENDING.** No se ha ejecutado el test G8 en ningún emulador/dispositivo y el código del prototipo nativo sigue desconectado de `main.dart`. G8 no autoriza un despliegue, integración de login real, migración de Postgres ni cambio de custodia MFA. Siguen `NO_DEPLOY_NO_LIVE_MIGRATION=1`, `MFA_RELEASE_AUTHORIZED=NO`, `MB1_RELEASE_AUTHORIZED=NO`, `C_FICHA_RELEASE_AUTHORIZED=NO` y `GLOBAL_FREEZE=NOT_VERIFIED`.

## G8-PHONE — decisión: móvil físico de pruebas y APK independiente (03/11/2026)

El operador ha elegido expresamente **instalar una APK en su móvil de pruebas**, no usar el emulador preparado previamente. Se ha añadido un flujo separado **debug-only** sin alterar el inicio normal de VENCIRA: `clients/flutter/lib/g8_lab_main.dart`, `clients/flutter/lib/g8_lab/physical_store_checks.dart`, `scripts/g8_phone_apk_build.sh` y `.github/workflows/g8-phone-apk.yml`. El Gradle script añade `.g8lab` solamente al application ID de esta compilación bajo `VENCIRA_G8_LAB_BUILD=1` y el código Flutter exige `--dart-define=VENCIRA_G8_LAB_BUILD=true`; `aapt` debe confirmar **`es.vencira.vencira.g8lab`** antes de publicar una APK. El label de launcher muestra `VENCIRA G8 Pruebas`, identificable y desinstalable sin afectar a `es.vencira.vencira`.

El teléfono ejecutará **dos pasos** con `FlutterNativeSecretStore` y namespace `vencira_g8_phone_only_v1`, usando credenciales sintéticas y sin contactar con Django: 1) almacenar refresh sintético y marcador duradero; 2) forzar detención del proceso desde Ajustes Android, reabrir, comparar PID, comprobar persistencia real, commit de cambio de refresh, rechazo de marcador corrupto y limpieza total. `SharedPreferences` almacena exclusivamente PID del proceso anterior (no credenciales). La interfaz tiene botones explícitos de preparación, verificación y limpieza. El resultado esperado es `G8_PHONE_PHYSICAL_STORAGE_RESULT=0`, mostrado solo tras finalización válida.

La compilación CI ofrecerá un artefacto `VENCIRA-G8-PHONE-DEBUG-ONLY` con APK y SHA256; no se ha confirmado todavía compilación ni subida de artefacto. El test G8 del emulador se conserva como alternativa y no se debe ejecutar en el móvil físico. Procedimiento detallado: `docs/G8_PHYSICAL_PHONE_APK_2026-11-03.md`. Static guard `g8_physical_phone_debug_apk_isolated` inspecciona aislamiento, debug-only y prohibición de rutas operativas. **G8-PHONE = PENDING build+device; G7 D2/E/F/G/H sigue PASS integral.** Se mantiene PR #17 en borrador y `NO_DEPLOY_NO_LIVE_MIGRATION=1`, MB1/MFA/C_FICHA release NO.

## Incidencia compilación G8 en GitHub Actions (03/11/2026)

El operador comunica que la compilación de la APK G8 por GitHub Actions **falló**. La API GitHub conectada ha permitido revisar el workflow `.github/workflows/g8-phone-apk.yml` y el script `scripts/g8_phone_apk_build.sh`, pero no proporciona **las ejecuciones push** ni sus logs por SHA: las consultas de estados y ejecuciones PR devolvieron listas vacías. El acceso público de navegación a la URL de Actions tampoco dio contenido del run. **La causa exacta del fallo no está determinada**: no atribuir a Gradle, Flutter, Android SDK, permisos o `aapt` sin el log de la ejecución.

Para mejorar visibilidad se añadió evento `pull_request` (además de `push` y `workflow_dispatch`) al workflow G8 Phone, con filtros por rutas G8. Permite registrar pruebas PR donde el conector soporte resultados. No se ha demostrado aún un PASS de esa nueva configuración. Se puede reproducir la compilación local con Docker ya utilizado para G7, sin necesidad de Flutter ni Android SDK instalados en el host:

```bash
cd ~/vencira-m3-localcheck
git status --short
git fetch origin feature/m3-android-local-notifications
git merge --ff-only FETCH_HEAD
set -o pipefail
sudo docker run --rm -v "$PWD:/src" -w /src ghcr.io/cirruslabs/flutter:stable bash scripts/g8_phone_apk_build.sh 2>&1 | tee /tmp/vencira-g8-phone-build.log
echo "G8_DOCKER_BUILD_RESULT=${PIPESTATUS[0]}"
```

El propio script rechaza compilar o publicar APK si `flutter analyze`, compilación debug y verificación del `applicationId` por `aapt` no terminan correctamente. Para diagnosticar una ejecución fallida, observar **el primer error real** del log local o compartir el enlace del workflow/run que terminó en rojo y las líneas del paso fallido (eliminar cualquier secreto que pudiera aparecer). **No instalar ninguna APK hasta conseguir `G8_PHONE_APK_ID_VERIFY=OK` y `G8_PHONE_APK_BUILD=OK`.** G7 completo sigue validado; G8 Phone build y prueba física siguen PENDING.

## G8 Phone local Docker build: 14 Dart analyzer issues, corrected source (03/11/2026)

El operador ejecutó la compilación local en la imagen `ghcr.io/cirruslabs/flutter:stable`. `flutter pub get` completó; `flutter analyze` detuvo el build con **14 incidencias** en `clients/flutter/lib/g8_lab_main.dart`: advertencias por `_failure`, `_markers` y `_clear` aparentemente no usados, **un error de retorno** en `_clear` línea 104 (`Future<void>` incompatible con `List<String>`) y una **coma/paréntesis sobrante** después de la tarjeta de resultado (anterior línea 209) que generó los restantes errores de parser (`Expected to find ']'`, `')'`, `';'`, texto inesperado). `G8_DOCKER_BUILD_RESULT=1` es correcto al fallar el análisis; no se produjo APK validada. No tiene relación con espacio de disco del VPS ni con la fase G7.

Corrección publicada: `_clear` se declara `Future<List<String>>` para respetar el contrato de `_run(Future<List<String>> Function())`, y se elimina únicamente el cierre extra de `Card` entre `_resultOk` e `if (_failure != null)`, conservando los cierres correctos. El fuente resultante conserva referencias a `_failure`, `_markers` y `_clear`; comprobación local de delimitadores balanceados sobre el fichero remoto OK, **pero no se dispone aún de reejecución `flutter analyze` ni de compilación APK**. Mantener `G8_PHONE_APK_BUILD=PENDING` y no recomendar instalación hasta confirmar `G8_PHONE_APK_ID_VERIFY=OK`, `G8_PHONE_APK_BUILD=OK`, exit 0. Repetir el runner único `bash scripts/g8_phone_apk_build.sh` o su envoltorio Docker anterior tras `git fetch` + fast-forward. PR sigue DRAFT, sin deploy ni migración.

## G8-PHONE: compilación DEBUG PASS (operador 03/11/2026)

El operador confirma compilación local **PASS** en `ghcr.io/cirruslabs/flutter:stable`:

```text
✓ Built build/app/outputs/flutter-apk/app-debug.apk
G8_PHONE_APK_ID_VERIFY=OK
G8_PHONE_PACKAGE=es.vencira.vencira.g8lab
G8_PHONE_APK_BUILD=OK
G8_PHONE_APK_PATH=clients/flutter/build/g8-phone/VENCIRA-G8-LAB-debug.apk
G8_PHONE_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
G8_DOCKER_BUILD_RESULT=0
```

El operador indica también **GitHub Actions DONE**; no se dispone en este registro del ID concreto de ejecución ni del artefacto verificado por consulta API, así que esta comprobación de Actions se consigna **como confirmación del operador**, no como inspección independiente de logs ni descarga. Con ello G8-PHONE **BUILD PASS** y **ANDROID DEVICE RUNTIME PENDING**. La APK debug conserva application ID `es.vencira.vencira.g8lab`, diferente de `es.vencira.vencira`; el usuario puede transferirla al móvil de pruebas desde el fichero local generado o descargar exclusivamente el artefacto `VENCIRA-G8-PHONE-DEBUG-ONLY` de la ejecución verde de GitHub. Verificar el SHA256 contra el fichero acompañante si se usa el artefacto descargado.

**Procedimiento de teléfono:** instalar APK G8 en dispositivo de pruebas; abrir **VENCIRA G8 Pruebas**, pulsar `Preparar prueba`; ir a Ajustes de Android → Aplicaciones → VENCIRA G8 Pruebas → Forzar detención; reabrir y pulsar `Verificar tras reinicio`. Confirmar `G8_PHONE_PHYSICAL_STORAGE_RESULT=0` y todos los marcadores locales, sin compartir tokens ni archivos de almacenamiento. Tras el ensayo limpiar con botón **Borrar datos de laboratorio** y, si se desea, desinstalar únicamente el paquete G8. La prueba no autoriza despliegue productivo, sesión móvil operativa, atestación de hardware o migración persistente. PR sigue DRAFT; `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## G8-PHONE — Validación física PASS confirmada (03/11/2026)

El operador instaló la APK separada **VENCIRA G8 Pruebas** en su teléfono Android de pruebas y comunicó los resultados exactos:

```text
G8_PHONE_NEW_PROCESS_CONFIRMED=OK
G8_PHONE_ENCRYPTED_REFRESH_SURVIVED=OK
G8_PHONE_MARKER_SURVIVED=OK
G8_PHONE_REAUTH_COMMIT=OK
G8_PHONE_CORRUPT_MARKER_DENIED=OK
G8_PHONE_STORAGE_CLEARED=OK
G8_PHONE_PHYSICAL_STORAGE_RESULT=0
```

**G8-PHONE = PASS EN DISPOSITIVO FÍSICO** para la prueba implementada de `FlutterNativeSecretStore` sobre `flutter_secure_storage` con namespace exclusivo `vencira_g8_phone_only_v1`, identificador APK separado `es.vencira.vencira.g8lab` y **credenciales exclusivamente sintéticas**. La prueba confirma un PID de proceso Android diferente, persistencia del dato cifrado y marcador después del cambio de proceso, sustitución verificada del refresh de prueba, rechazo fail-closed de un marcador manipulado y eliminación final de los valores. Se había recibido previamente `G8_PHONE_APK_ID_VERIFY=OK`, `G8_PHONE_APK_BUILD=OK` y `G8_DOCKER_BUILD_RESULT=0` del ensayo de compilación local; el operador informó también que GitHub Actions quedó completado. Evidencia de ejecución del móvil provista por el operador; no se ha inspeccionado remotamente el dispositivo.

**Alcance y límites:** NO prueba atestación del hardware criptográfico (TEE/StrongBox), protección frente a root, reinstalaciones, backups/restauraciones, malware, ni uso de cuentas o credenciales reales. El resultado no demuestra autenticación operativa conectada a Django ni autoriza endpoints, permisos, migraciones persistentes o producción. El código G8 es una APK de laboratorio desconectada y el prototipo de autenticación nativa sigue sin enlazarse con `main.dart`.

**Estado de gates:** G7-D2/E/F/G/H = PASS laboratorio HTTPS; G8-PHONE = PASS dispositivo físico en pruebas sintéticas. `NO_DEPLOY_NO_LIVE_MIGRATION=1`, `MFA_RELEASE_AUTHORIZED=NO`, `MB1_RELEASE_AUTHORIZED=NO`, `C_FICHA_RELEASE_AUTHORIZED=NO`, `GLOBAL_FREEZE=NOT_VERIFIED`, PR #17 DRAFT. Siguiente trabajo recomendado: revisión de integración de autenticación y rutas bajo aislamiento; no habilitar producción automáticamente.

## G9 — Arranque fail-closed / ruta de recuperación restringida, 03/11/2026

**Candidato en GitHub:** `clients/flutter/lib/api/native_mobile_startup_gate.dart` (G9-A) y `clients/flutter/lib/api/native_mobile_recovery_entry.dart` (G9-B), más 20 pruebas unitarias sintéticas repartidas entre dos ficheros nuevos, runner agrupado `scripts/g9_native_startup_gate.sh`, CI `.github/workflows/g9-native-startup-gate.yml` y nuevos checks estáticos en `scripts/n1_static_security_gate.py`. Documento de diseño y limitaciones: `docs/G9_NATIVE_BOOT_ROUTING_2026-11-03.md`.

**Política:** revocar fence antes de leer almacén; marcador persistente -> recuperación completa, refresh huérfano sin marcador -> armar marcador y verificarlo antes de ruta de recuperación; errores de lectura/escritura/marcador corrupto -> bloqueado; sin secretos ni operaciones HTTP. Adaptador G9-B impide que el widget envíe contraseña/TOTP antes de inspección, re-verifica marcador y comparte estrictamente fence/vault/journal. La ruta ordinaria `cleanLogin` **no autoriza credenciales**: quedan pendientes protocolo pre-network de emisión y logout fail-closed. No inyectar en `main.dart` ni instalar rutas operativas. G9-A/B **PENDING Flutter analyze/test local**. Ejecutar **una única vez** tras fast-forward `bash scripts/g9_native_startup_gate.sh`; no reejecutar G7 HTTPS ni G8 físico. Esperados `G9_STARTUP_ANALYZE=OK`, `G9_STARTUP_AND_RECOVERY_UNIT=OK`, `G9_STARTUP_GATE_RESULT=0`.

G7-D2/E/F/G/H PASS laboratorio, G8-PHONE PASS teléfono físico de pruebas. PR #17 permanece DRAFT, `GLOBAL_FREEZE=NOT_VERIFIED`, `MFA_RELEASE_AUTHORIZED=NO`, `MB1_RELEASE_AUTHORIZED=NO`, `C_FICHA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## G9 — Resultado local PASS confirmado (03/11/2026)

El operador ejecutó `scripts/g9_native_startup_gate.sh` después de actualizar la rama. El control N1 mostró todas las comprobaciones `N1_STATIC_*=OK`, incluidas `N1_STATIC_g9_native_startup_recovers_orphan_fail_closed=OK`, `N1_STATIC_g9_recovery_entry_never_downgrades_to_regular_login=OK` y `N1_STATIC_GATE_RESULT=OK`. El lote Flutter mostró `G9_STARTUP_ANALYZE=OK`, `G9_STARTUP_AND_RECOVERY_UNIT=OK`, `G9_STARTUP_GATE_BATCH=OK`, `G9_STARTUP_GATE_RESULT=0` y `NO_DEPLOY_NO_LIVE_MIGRATION=1`. La primera petición de `sudo` fue rechazada, pero tras reintroducir la contraseña el runner acabó con resultado 0. **G9-A/B = PASS en suite unitaria sintética**; no son HTTP E2E ni login operativo.

El siguiente bloque G10 debe resolver **primer checkpoint de emisión protegido y logout fail-closed** sin permitir un acceso al backend antes de persistir el marcador. Mantener `main.dart` y `config.urls` desconectados. No repetir G7/G8/G9 salvo que cambien los contratos ya verificados.

## G10 — Primera emisión y logout fail-closed (03/11/2026)

**Estado candidato / pendiente de ejecución:** implementados `NativeRefreshRecoveryJournal.confirmFirstIssuance` y `confirmLogoutCompleted`, opt-in `NativeSessionCoordinator.firstIssuanceJournal`, entrada `NativeFirstIssuanceEntry`, 15 pruebas G10, runner único `scripts/g10_issuance_logout_gate.sh` que agrupa 6 suites y análisis Flutter, CI `.github/workflows/g10-issuance-logout-gate.yml`, static gate `g10_first_issuance_logout_checkpoint` y documento completo `docs/G10_FIRST_ISSUANCE_LOGOUT_2026-11-03.md`.

**Invariante:** G9 limpio -> comprobar ausencia de credencial y marcador -> `journal.arm()` duradero **antes de password/MFA HTTP** -> primera emisión remota -> `vault.replace` verificado -> eliminación verificada de marcador -> activar fence. Fallos mantienen el fence cerrado y evidencia de recuperación. `logout`: fence cerrado sincrónicamente, marcador duradero antes de revocación HTTP, `vault.clear`, borrado de marcador verificado; reintentos locales no deben repetir una revocación remota que ya respondió correctamente. Un intento fallido no reintenta password directamente; debe ir a recuperación. No activado en `main.dart` ni en endpoints Django de producción.

**G9-A/B = PASS** (comprobación N1 y Flutter `G9_STARTUP_GATE_RESULT=0` recibida). G7-D2/E/F/G/H PASS HTTPS y G8-PHONE PASS Android físico previos. **G10 = PENDING** (sin recibo Flutter ni verificación del endpoint real). No pedir repetir G7 ni G8. Único comando tras actualizar rama: `bash scripts/g10_issuance_logout_gate.sh`. Esperar `G10_ISSUANCE_LOGOUT_GATE_RESULT=0`, `G10_ISSUANCE_LOGOUT_BATCH=OK`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`. PR #17 DRAFT; MB1/MFA/C_FICHA release NO; `GLOBAL_FREEZE=NOT_VERIFIED`.

## G10 primera ejecución local: fallo aislado de aserción síncrona, corregido (03/11/2026)

El operador ejecutó `scripts/g10_issuance_logout_gate.sh`. **N1 estático íntegro OK**, incluidas las comprobaciones G9/G10; `flutter analyze` de los 4 archivos informó **`No issues found!`**. En la ejecución unitaria agrupada, **63 tests pasaron y 1 falló**: `native_first_issuance_entry_test.dart: failed password leaves durable marker for reboot recovery`, con `Bad state: Native startup fence mismatch` en `native_mobile_startup_gate.dart:47` y test línea 226. Resultado final `G10_FLUTTER_BATCH=FAIL`, `G10_ISSUANCE_LOGOUT_GATE_RESULT=1`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

**Diagnóstico:** el caso negativo construía deliberadamente `NativeMobileStartupGate` con un `fence` distinto del del `NativeRefreshRecoveryJournal`. `inspect()` comprueba identidad de fence y lanza **StateError síncronamente antes de devolver un Future**. La prueba usaba `await expectLater(cold.inspect(), throwsStateError)`, que evalúa `cold.inspect()` *fuera* del matcher: por ello el `StateError` intencional escapó y señaló un falso fallo de la prueba. Se sustituyó exclusivamente por `expect(() => cold.inspect(), throwsStateError)`, que entrega una función para que el matcher capture la excepción síncrona. **No se tocó la lógica de seguridad de producción ni se flexibilizó el bloqueo por mismatch**. La segunda parte del mismo test, con `rebootFence` compartido, conserva la comprobación positiva de `fullReauthentication` después de un inicio fallido.

**Estado:** fuente corregida y publicada; G10 **PENDING RECHECK**, NO PASS hasta la nueva salida de `bash scripts/g10_issuance_logout_gate.sh`. Repetir solo la batería agrupada G10; no repetir G7 HTTPS, G8 móvil físico ni G9 aislado. Sigue PR DRAFT, `NO_DEPLOY_NO_LIVE_MIGRATION=1` y release MFA/MB1/C-FICHA no autorizado.

## G10 — Reejecución integral PASS confirmada por operador (03/11/2026)

Tras la corrección de la aserción síncrona del test negativo, el operador ejecutó de nuevo el runner G10 en Ubuntu, con los siguientes marcadores:

```text
N1_STATIC_g9_recovery_entry_never_downgrades_to_regular_login=OK
N1_STATIC_g10_first_issuance_logout_checkpoint=OK
N1_STATIC_lab_issuer_requires_epoch=OK
N1_STATIC_GATE_RESULT=OK
G10_ISSUANCE_ANALYZE=OK
G10_ISSUANCE_LOGOUT_UNIT=OK
G10_G9_G6_REGRESSION=OK
G10_ISSUANCE_LOGOUT_BATCH=OK
G10_ISSUANCE_LOGOUT_GATE_RESULT=0
NO_DEPLOY_NO_LIVE_MIGRATION=1
```

**Resultado: G10 = PASS, suite unitaria Flutter agrupada y guardia estática.** La salida no incluye la línea opcional `G10_LOCAL_RESULT=0` de un `echo` posterior, pero el propio runner informa `G10_ISSUANCE_LOGOUT_GATE_RESULT=0`. Se cierra el incidente anterior de 63/64, causado por un matcher inadecuado para una excepción síncrona; no fue un fallo del protocolo de seguridad. El bloqueo por `Native startup fence mismatch` permanece sin modificaciones.

**Alcance:** primera emisión con marcador duradero, acceso cerrado hasta confirmar vault y limpieza de marcador, revocación/cierre fail-closed y regresiones G9/G6 en condiciones de prueba con puertos simulados. **Todavía NO existe evidencia de G10 contra Django por HTTPS ni de este protocolo completo en Android físico.** El siguiente paso razonable es el ensayo HTTPS aislado G11 (o la auditoría correspondiente), sin desplegar ni montar emisores reales. No reejecutar G7/G8/G9 salvo que cambien sus contratos. PR #17 DRAFT, `MB1_RELEASE_AUTHORIZED=NO`, `MFA_RELEASE_AUTHORIZED=NO`, `C_FICHA_RELEASE_AUTHORIZED=NO`, `GLOBAL_FREEZE=NOT_VERIFIED`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.
