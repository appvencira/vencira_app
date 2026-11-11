# D24 — lectura móvil paginada y revocación concurrente con PostgreSQL 17

Fecha: 11/11/2026. Rama: **main**. Estado: **código publicado; resultado VPS pendiente**.

## Implementación

D23 validó 74 tests y la pertenencia/asignación comprobada en cada petición. D24 añade garantías transaccionales a la lectura del workspace y un protocolo paginado de 50 registros:

- `backend/native_mobile_service/native_workspace_reader.py`: solo funciona dentro de una transacción explícita. La membresía actual se bloquea con `select_for_update`; se bloquean las filas seleccionadas antes de proyectar `id/expires_on/status`. Páginas `offset` de 50, desde 0 hasta 10000, con `next_offset` o `null`. Los offsets no canónicos y roles distintos de owner/member deniegan. Es un límite deliberado para laboratorio, **no paginación completa sin límite**.
- `backend/native_mobile_service/test_d22_http_views.py`: bajo `transaction.atomic` bloquea usuario → sesión móvil → membresía → filas. Antes del bloqueo obtiene la identidad a partir del token, pero **la valida de nuevo con los bloqueos adquiridos**, evitando entregar datos si se revocó el dispositivo entre ambas validaciones. Rechaza offsets HTTP inválidos. El body JSON se construye mientras se mantienen los bloqueos.
- `clients/flutter/lib/api/native_workspace_read_port.dart`: respuesta paginada `NativeWorkspacePage`, `loadPage(workspaceId, offset: ...)`, conserva `load()` para la primera página; valida offsets, estructura, estados y fechas, y rechaza campos PII. **No se conecta al entrypoint real Android**.
- `backend/native_mobile_service/test_d24_workspace_pagination_pg17.py`: cuatro pruebas con base PG17 temporal: 75 renovaciones asignadas recuperadas en dos páginas, offsets inválidos, bloqueo de eliminación de membresía hasta finalizar la consulta y bloqueo de reasignación de fila durante la lectura. Los tests usan dos conexiones reales y `ThreadPoolExecutor`, no solo mocks.
- `backend/native_mobile_service/test_d23_workspace_pg17.py`: añade un test HTTP de offsets y página vacía.
- `clients/flutter/test/native_workspace_read_port_test.dart`: adapta el contrato y añade segunda página y metadatos de paginación falsificados.
- `scripts/native_i8k_recovery_http_pg17_isolated.sh`: añade D24 al paquete histórico I8-K y marca `NATIVE_I8K_D24_PAGINATION_CONCURRENCY_PG17=PASS` solo tras suite completa.
- `scripts/main_d24_native_workspace_pagination_race_gate.sh`: un gate agrupa checks estáticos, el mismo laboratorio PG17 aislado y `flutter analyze` + `flutter test test/native_workspace_read_port_test.dart` en Flutter 3.44.0 Docker, con comparación de identidades de DEV. No hace deploy, LIVE migrate ni build de APK.

## Ejecutar una sola vez en Termius

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
bash -n scripts/main_d24_native_workspace_pagination_race_gate.sh
echo "D24_SYNTAX=$?"
sudo -v
bash scripts/main_d24_native_workspace_pagination_race_gate.sh
echo "D24_SHELL_RESULT=$?"
git status --short
```

Requerido para D24 PASS:
```text
D24_MAIN_CLEAN=PASS
D24_OPERATIONAL_ROUTE_FENCE=PASS
D24_WORKSPACE_BOUNDED_PAGINATION_PG17=PASS
D24_WORKSPACE_OFFSET_FENCE_PG17=PASS
D24_MEMBERSHIP_REVOKE_SERIALIZED_PG17=PASS
D24_ASSIGNMENT_REVOKE_SERIALIZED_PG17=PASS
D24_WORKSPACE_HTTP_OFFSET_FENCE=PASS
NATIVE_I8K_D24_PAGINATION_CONCURRENCY_PG17=PASS
NATIVE_I8K_DEV_CONTAINERS_UNCHANGED=OK
NATIVE_I8K_LOCAL_RESULT=0
D24_PG17_CONCURRENCY_PAGINATION=PASS
D24_FLUTTER_PAGINATION_GATE=PASS
D24_ACTUAL_TLS_NETWORK_GATE=NOT_RUN
D24_NATIVE_ISSUER_ENABLED=NO
D24_DEV_CONTAINERS_UNCHANGED=OK
D24_RESULT=0
D24_SHELL_RESULT=0
```

## Alcance y límites

**No marcar PASS hasta recibir el resultado del VPS.** Estas pruebas verifican que una modificación de la membresía o asignación **sobre filas bloqueadas** no termina antes de la transacción de lectura; una vez enviada una respuesta no se pueden retirar sus bytes del dispositivo. Hay además dos riesgos fuera de alcance: 1) offsets pueden saltar/repetir filas si cambia el dataset *entre páginas*; para producción hará falta cursor estable con reautorización por página; 2) el límite en 10000 impide recorrer workspaces enormes y es temporal. La lectura es read-only, no permisos de escrituras ni adjuntos.

**TLS de red cliente Flutter ↔ las nuevas vistas D24 NO ha sido ejecutado.** El gate Flutter usa un transport mock, y el test Django utiliza request `secure=True`. El gate anterior D18 sí cubrió TLS real, pero en una API de laboratorio anterior, no D24; se necesita un gate posterior específico para esta versión.

Conservar `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`, no registrar URL D22/D24 en `config.urls`, no habilitar issuer móvil ni instalar APK.

## Primer gate VPS — FAIL, corrección localizada (12/11/2026)

Reporte real: `D24_SYNTAX=0`, `D24_MAIN_CLEAN=PASS`, `D24_DEV_IDENTITY=PASS`, `D24_OPERATIONAL_ROUTE_FENCE=PASS`, red interna PG17, imagen y migraciones temporales OK. **79 tests ejecutados, 1 fallo**. Test `test_native_workspace_http_offset_and_canonical_page` para `?offset=1`: esperaba HTTP 400 y obtuvo HTTP 401. Las otras pruebas de D24 informaron `D24_WORKSPACE_BOUNDED_PAGINATION_PG17=PASS`, `D24_ASSIGNMENT_REVOKE_SERIALIZED_PG17=PASS`, `D24_WORKSPACE_OFFSET_FENCE_PG17=PASS`, `D24_MEMBERSHIP_REVOKE_SERIALIZED_PG17=PASS`. `NATIVE_I8K_DEV_CONTAINERS_UNCHANGED=OK`, `NATIVE_I8K_LOCAL_RESULT=1`, `D24_PG17_CONCURRENCY_PAGINATION=FAIL`, `D24_DEV_CONTAINERS_UNCHANGED=OK`, `D24_RESULT=4`. **Flutter no se ejecutó por fail-fast del gate**.

**Diagnóstico:** la vista HTTP aceptaba como sintácticamente numérico `offset=1`, pero el lector requería múltiplos de 50, lanzaba `NativeWorkspaceDenied`, y la vista lo traducía a 401. No es una vulnerabilidad de acceso demostrado; sí un error de contrato HTTP para parámetros de paginación. **Corrección publicada en main, commit `58d765bb`**: `test_d22_http_views.workspace_renewals` rechaza offsets no múltiplos de 50 como 400 *antes* de validar credenciales o consultar el tenant. El lector sigue denegando los offsets no canónicos como defensa adicional. No se han modificado `config.urls`, settings operativos ni el flujo de emisión.

**Pendiente:** repetir una sola vez el gate D24 agrupado después de `git fetch` y `git merge --ff-only`; se exige **79 tests OK**, `D24_FLUTTER_PAGINATION_GATE=PASS`, `D24_RESULT=0`. Hasta entonces **D24 NO PASS**.

## Segundo gate VPS — fallo Flutter al serializar offset, corrección publicada (12/11/2026)

La ejecución llegó al subgate Flutter tras la fase PostgreSQL17, lo que implica que el subgate backend precedente finalizó con código cero; la parte del log entregada no incluye el resumen de los 79 tests del recheck y no se inventan esos marcadores. `flutter pub get` completó; `flutter analyze` informó **No issues found**. `flutter test` ejecutó 9 pruebas de `native_workspace_read_port_test.dart`, con **8 correctas y 1 fallo**: `page two uses canonical offset and validates next_offset` arrojó `FormatException: Invalid API path` desde `NativeApiEndpoint.resolveApiPath`. El cliente D24 concatenaba `?offset=50` a la ruta; el contrato de seguridad de `NativeApiEndpoint` rechaza por diseño cualquier query dentro de la ruta. El gate detuvo correctamente la fase con `D24_FLUTTER_PAGINATION_GATE=FAIL`, `D24_DEV_CONTAINERS_UNCHANGED=OK`, `D24_RESULT=5`.

**Corrección en main sin relajar la validación de rutas**:
- `d17756a2` actualiza `NativeApiTransport.getJson(path, query: ...)`: primero valida ruta por `NativeApiEndpoint.resolveApiPath`, y solo permite una query tipada `offset` numérica, canónica, múltiplo de 50, máxima 10000 y **solo** para `/api/v1/mobile/workspaces/<id>/renewals/`. No permite query cruda, redirección ni otros endpoints. Construye `Uri.replace(queryParameters: ...)` sin interpolar el delimitador en la ruta.
- `e7c84258` actualiza `NativeWorkspaceReadPort.loadPage` para enviar el `offset` por el parámetro `query`, sin concatenarlo al path.
- `d252d31a` añade regresiones Flutter del transport: URL HTTPS canónica con offset 50, rechazo antes de leer token y antes de red para offsets inválidos, query inesperada y query cruda.
- `c45b31bb` amplía el gate Flutter D24 para ejecutar `native_workspace_read_port_test.dart`, `native_api_transport_test.dart` y `native_api_endpoint_test.dart`, además de `flutter analyze`.

**D24 aún PENDIENTE**, hasta repetir el gate de principio a fin y obtener `D24_FLUTTER_PAGINATION_GATE=PASS`, `D24_PG17_CONCURRENCY_PAGINATION=PASS`, `D24_DEV_CONTAINERS_UNCHANGED=OK` y `D24_RESULT=0`. La revisión y validación Flutter no se han ejecutado en el VPS tras esta corrección.

`MFA_RELEASE_AUTHORIZED=NO`
`NO_DEPLOY_NO_LIVE_MIGRATION=1`

## Tercer gate VPS — análisis Dart bloqueado por corrupción textual, corrección (12/11/2026)

La ejecución entregada reporta `flutter analyze` con **163 issues** y `D24_FLUTTER_PAGINATION_GATE=FAIL`, `D24_DEV_CONTAINERS_UNCHANGED=OK`, `D24_RESULT=5`. Las referencias a tipos `int`, `RegExp` y clases de error que «no existen», y las palabras clave `if`/`try` aparentemente inválidas, eran errores en cascada por una sintaxis rota en `clients/flutter/lib/api/native_api_transport.dart`. La lectura real de GitHub comprobó **273 líneas** con la implementación del transporte duplicada/intercalada tres veces, incluyendo dos expresiones regulares incompletas y clases repetidas; no era un fallo de dependencias `pub get` ni 163 defectos separados.

**Corrección publicada en main, commit `a8b313f3`**: reconstrucción completa y única de `getJson` con query tipada `offset` limitada a renovaciones workspace, sin aceptar query cruda en path; preserva la generación de sesión, rechazo de tokens inválidos y redirecciones, límites de red/JSON y fail-closed. Relectura del blob de GitHub posterior al commit: **132 líneas, una implementación de getJson y una definición de NativeApiTransportFailure**. No se ha ejecutado Flutter local ni VPS después de este commit; D24 **NO PASS**.

Repetir el gate completo desde `main` sincronizado: exigir PostgreSQL17 + `flutter analyze` + tests de workspace, transporte y endpoint, más `D24_RESULT=0`. Seguir con `MFA_RELEASE_AUTHORIZED=NO` y `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## Cuarto gate VPS — Flutter test recibe una ruta literal `\\`; corregido en main (12/11/2026)

La última ejecución llega otra vez al subgate Flutter: `flutter pub get` termina y `flutter analyze` informa **No issues found** (14,4 s). Sin embargo, Flutter no ejecutó ningún test real: intentó cargar `/tmp/vencira-d24-flutter/\\` y notificó `Failed to load ... Does not exist`. Marcadores: `D24_FLUTTER_PAGINATION_GATE=FAIL`, `D24_DEV_CONTAINERS_UNCHANGED=OK`, `D24_RESULT=5`. No concluir sobre el resultado de los tests Flutter.

**Causa confirmada en el script de main:** el comando dentro del argumento `sh -euc '...'` tenía finales de línea con **dos barras invertidas** en lugar de una. Para el shell interno, `\\\\` deja una barra literal como argumento, y Flutter intenta ejecutar esa ruta. `bash -n` no detecta este fallo semántico de escape dentro de una cadena pasada a otro intérprete.

**Corrección commit `43011416`:** sustituye exclusivamente la invocación fragmentada por un comando `flutter test --reporter expanded test/native_workspace_read_port_test.dart test/native_api_transport_test.dart test/native_api_endpoint_test.dart` de una sola línea. No altera Django, DRF, PostgreSQL, acceso móvil ni las rutas de producción.

D24 **no PASS** hasta un gate íntegro con `D24_PG17_CONCURRENCY_PAGINATION=PASS`, `D24_FLUTTER_PAGINATION_GATE=PASS`, `D24_DEV_CONTAINERS_UNCHANGED=OK`, `D24_RESULT=0`. Se mantienen `MFA_RELEASE_AUTHORIZED=NO` y `NO_DEPLOY_NO_LIVE_MIGRATION=1`.
