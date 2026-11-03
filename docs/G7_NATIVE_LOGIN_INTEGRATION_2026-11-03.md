# VENCIRA G7 — Bloque A: entrada nativa inyectable y cierre de sesión seguro

Fecha: 03/11/2026. Rama `feature/m3-android-local-notifications` (PR #17 DRAFT).

## Objetivo

Se prioriza **login nativo** sobre las pruebas visuales de APK, siguiendo la decisión del operador. G7-A conecta el widget `NativeLoginScreen` con `NativeSessionCoordinator` mediante un shell de integración **exclusivamente inyectable desde pruebas**. NO se crea un emisor Django productivo ni se configura ninguna clave, usuario, contraseña, token o endpoint real en la APK.

## Código

- `clients/flutter/lib/ui/native_lab_login_shell.dart`: recibe un coordinador ya construido por el harness. Un acceso aceptado solo abre un indicador de sesión de laboratorio; no muestra vencimientos, workspaces ni datos privados. Para aceptar callback exige `coordinator.fence.ticket != null`.
- Logout: el coordinador cierra la barrera de peticiones sin esperar red, revoca refresh en el puerto de pruebas, borra la bóveda y solo vuelve a login tras completar la limpieza. Si falla la revocación se mantiene el acceso cerrado y se exige reintentar limpieza. Ni error de plataforma ni errores de servidor muestran secretos.
- `clients/flutter/lib/main.dart`: añade la dependencia inyectada `nativeLoginLab` para pruebas; solo se elige con `!kReleaseMode`, `api == null` y `nativeLoginLab != null`. **La ruta por defecto Android sigue siendo `AndroidWebAccessScreen`**, sin conexión nativa automática. Los builds release ignoran incluso una inyección explícita.
- `clients/flutter/test/native_lab_login_shell_test.dart`: comprueba arranque cerrado sin usuario, contraseña con tokens sintéticos y bóveda protegida simulada, MFA que no desbloquea prematuramente, logout con revocación y borrado, fallo/reintento de revocación, y rama del punto de entrada `VenciraApp` cuando se inyecta el coordinador.
- `scripts/m3_native_http_contract_batch.sh` y `.github/workflows/m3-product-contracts.yml` incorporan la nueva suite Flutter; el guard estático rechaza la presencia de `NativeHttpAuthPort(` o de `NativeSessionCoordinator(` construido dentro de `main.dart`, comprueba la barrera de `kReleaseMode` y que el shell no invoque el dashboard operativo.

## Evidencia y pendientes

El último lote local anterior `m3-http-contract-20261103T131438Z` terminó `M3_HTTP_RESULT=0` (STATIC/BUILD/PG17_LAB/G4_PG17/FLUTTER=0, sin despliegue ni migración persistente). **No valida el nuevo bloque G7-A**; su nueva suite Flutter permanece PENDING hasta ejecutar el runner actualizado, así como GitHub Actions.

Este trabajo **no constituye login nativo conectado a la API Django**: la contraseña/MFA real y la revocación necesitan un servicio autorizado con límites de intentos, auditoría, separación de claves y custodia externa. La app instalada por defecto sigue abriendo el navegador en Android. El backend `native_sessions_lab` y el candidato `native_mobile_service` permanecen en test; ambos carecen de rutas operativas. No usar el harness de tokens sintéticos para permitir navegación de usuarios reales.

## Siguiente bloque G7-B (sin deploy)

Implementar un puente de integración HTTP contra **un backend efímero controlado**, con `NativeHttpAuthPort`, `NativeSessionCoordinator`, Keystore Android real y URL HTTPS explícita del entorno de pruebas; demostrar password+MFA auténticos frente al emisor, revocación con cierre y acceso a recursos con autorización workspace. El puente solo debe estar activo para un proceso de test o una beta expresamente acotada, nunca mediante una opción accesible en release antes de autorizar G1/G2/G3/G4/G5. Después de validar la conectividad nativa real, pasar a APK y pruebas visuales.

## Invariantes

```
NO_DEPLOY_NO_LIVE_MIGRATION=1
MFA_RELEASE_AUTHORIZED=NO
MB1_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
GLOBAL_FREEZE=NOT_VERIFIED
G7_NATIVE_OPERATIONAL_LOGIN=NO
G7_A_LAB_UI_TESTS=PENDING
```

PR #17 continúa DRAFT; no merge ni migración de la BD persistente.

## Incidencia de validación y corrección de tests — 03/11/2026

El operador comunica `m3-http-contract-20261103T133437Z`: `M3_HTTP_STATIC=0`, `BUILD=0`, `PG17_LAB=0`, `G4_PG17=0`, `FLUTTER=1`, `M3_HTTP_RESULT=1`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`. Los cinco fallos están en `native_lab_login_shell_test.dart`; el extracto muestra `pumpAndSettle timed out` durante el login y un override global de plataforma sin limpiar antes del chequeo de invariantes.

Se corrigió **solo el archivo de pruebas**: espera limitada por objetivos observables del widget (MFA, logout, error o vuelta a login) en lugar de `pumpAndSettle` sobre widgets que pueden animarse indefinidamente; `debugDefaultTargetPlatformOverride` se restablece en `finally` antes de terminar el test. En el caso de fallo de revocación, la prueba espera el error de cierre y no el login (que debe permanecer bloqueado). **Esta corrección aún no está validada localmente: no afirmar PASS.**

Primero ejecutar **solo Flutter** usando el contenedor de herramientas Flutter sobre el checkout actualizado, sin correr Docker backend ni PG17:

```bash
cd ~/vencira-m3-localcheck
git status --short
git fetch origin feature/m3-android-local-notifications
git merge --ff-only FETCH_HEAD
sudo docker run --rm -v "$PWD/clients/flutter:/work" -w /work ghcr.io/cirruslabs/flutter:stable sh -c 'flutter pub get && flutter analyze && flutter test test/native_lab_login_shell_test.dart'
echo "G7_FLUTTER_TARGETED_RESULT=$?"
```

Los logs no se incorporan a GitHub (repo público). Si falla, solicitar primeras líneas de excepción/estado observado, no repetir PG17. No desplegar, migrar ni liberar autenticación operativa.

## Segundo resultado focalizado G7-A — fallo de activación aún sin causa confirmada

El operador informa `flutter analyze: No issues found!` pero 4 fallos de widget de `native_lab_login_shell_test.dart` por ausencia de `g7-native-logout` tras esperar la transición; el quinto (prueba del punto de entrada) pasa. Esto evidencia que cambiar `pumpAndSettle` **no solucionó la transición del login**; no declarar el frontend validado. Tampoco deducir que es fallo de Django o del vault a partir de un finder ausente.

Se introduce una comprobación unitaria aislada de *fixture* (`NativeMobileTokenShape`, `NativeSessionCoordinator.verifyPassword`, apertura del fence y persistencia de refresh) y un diagnóstico acotado en la espera del widget que informa **solo** estado del fence, número de llamadas sintéticas, existencia de error genérico UI y presencia de valor en la bóveda; sin contraseñas, refresh, access ni TOTP. Esto permite discriminar **coordinador** frente a **widget/callback**. Requiere validación focalizada posterior a este commit.

No modificar rutas backend, middleware MFA, BD persistente o autorizaciones para superar un test sintético.

Validación recomendada únicamente del test focalizado (sin repetir `flutter pub get` salvo necesitar dependencias):

```bash
cd ~/vencira-m3-localcheck
git status --short
git fetch origin feature/m3-android-local-notifications
git merge --ff-only FETCH_HEAD
sudo docker run --rm -v "$PWD/clients/flutter:/work" -w /work ghcr.io/cirruslabs/flutter:stable sh -c 'flutter test test/native_lab_login_shell_test.dart --reporter expanded'
echo "G7_DIAG_RESULT=$?"
```

## Tercer diagnóstico local: coordinación directa PASS, widget sigue bloqueado (03/11/2026)

El operador notifica `flutter pub get` OK, `flutter analyze` OK y seis pruebas focalizadas: 2 PASS y 4 FAIL. El test `synthetic fixture satisfies native credential shape and coordinator` PASA; el punto de entrada inyectado también. En los cuatro widgets, `passwordCalls=1` (y en MFA, `mfaCalls=1`), pero `fenceActive=false`, `vaultPopulated=false`, `loginError=false`. No hay evidencia de fallo del backend ni de formato de token.

Hipótesis de test a verificar: el fixture instanciaba `NativeRefreshCredentialVault` en `setUp`, fuera de la zona `FakeAsync` de `testWidgets`. El constructor inicializa `Future<void>.value()` para serializar la bóveda. La zona de creación podría impedir que se complete la cadena en widget tests, aunque pase el test normal `test()`. **Se ha movido la construcción del coordinador/bóveda a la función de cada test**, ya dentro de su zona asíncrona; no se ha cambiado el código de login, de la bóveda ni Django. **Corrección candidata sin PASS confirmado**.

Validación: tras actualizar rama, ejecutar `flutter pub get && flutter test test/native_lab_login_shell_test.dart --reporter expanded` con el contenedor Flutter. Si sigue rojo, registrar la primera excepción y el diagnóstico no secreto, sin ejecutar PG17 ni modificar permisos de release.

## G7-A confirmado y G7-B contrato HTTP integrado, pendiente de pruebas

### Recibo local G7-A

El operador confirma `G7_RECHECK_RESULT=0`, `All tests passed!`, **6/6** en `native_lab_login_shell_test.dart`. El test incluye comprobación directa de formato de credenciales y coordinador, login/password, MFA, logout exitoso, revocación fallida con reintento y montaje de `VenciraApp` con inyección explícita. Este resultado sigue siendo **solo laboratorio**; no autoriza beta ni activación en servidor.

### G7-B — nuevo bloque de pruebas integradas Flutter con contrato Django simulado

Nuevo archivo `clients/flutter/test/native_http_login_integration_test.dart` con cuatro tests `testWidgets`. Encadena los componentes de producción potenciales, sin ejecutarlos contra una API real: 
- `NativeLoginScreen` → `NativeLabLoginShell` → `NativeSessionCoordinator` → `NativeHttpAuthPort` con `MockClient` → `NativeRefreshCredentialVault` con almacenamiento sintético.
- Valida el GET `/api/v1/mobile/me/` por `NativeApiTransport`, con `Authorization: Bearer` únicamente **después** de recibir tokens con forma correcta y de escribir/verificar refresh; no permite GET antes de login ni después de logout.
- MFA: comprueba que `mfa_required` no escribe refresh ni abre el `fence`; TOTP aceptado activa la sesión y el puerto exige el contrato de desafío.
- Contraseña denegada: HTTP 401 no desbloquea ni persiste credenciales.
- Revocación fallida: el cierre deja el fence bloqueado, conserva refresh para reintento explícito y no permite volver a login hasta recibir acuse de revocación.

Estas respuestas son **simuladas según** `native_sessions_lab.test_http_contract`, cuyos HTTP Django están probados por separado en PostgreSQL17 desechable. Esto NO es todavía una prueba de red extremo a extremo Flutter→Django. No se crean rutas de autenticación operativa, migraciones persistentes, usuario real, claves reales, APK pública ni endpoint remoto accesible.

Actualizados `scripts/m3_native_http_contract_batch.sh`, `.github/workflows/m3-product-contracts.yml` y `scripts/n1_static_security_gate.py` para incluir y vigilar la nueva suite en el entorno aislado. **G7_B_HTTP_WIDGETS=PENDING** tras estos commits; no afirmar CI verde.

### Próxima validación local específica

```bash
cd ~/vencira-m3-localcheck
git status --short
git fetch origin feature/m3-android-local-notifications
git merge --ff-only FETCH_HEAD
sudo docker run --rm -v "$PWD/clients/flutter:/work" -w /work ghcr.io/cirruslabs/flutter:stable sh -c \
  'flutter pub get && flutter analyze && flutter test test/native_lab_login_shell_test.dart test/native_http_login_integration_test.dart --reporter expanded'
echo "G7_B_HTTP_TEST_RESULT=$?"
```

Si da PASS, el siguiente paso será diseñar una prueba E2E **aislada** en la que Flutter y Django se comuniquen realmente por HTTPS, sin utilizar `dev.vencira.es` productivo, sin alterar la whitelist pública y sin abrir rutas de usuario reales. Para ello habrá que preparar certificados de laboratorio confiables y un emisor temporal controlado, además de asegurar que la aplicación release no lo pueda habilitar.

## G7-B primer intento: 7 PASS / 3 FAIL y corrección de streaming mock

El operador ejecutó `flutter pub get && flutter analyze && flutter test test/native_lab_login_shell_test.dart test/native_http_login_integration_test.dart --reporter expanded`. `flutter analyze` informó `No issues found!` y la prueba terminó `G7_B_HTTP_TEST_RESULT=1`. **G7-A 6/6 PASS**, G7-B 1/4 PASS (denegación HTTP 401). Los otros tres casos no encontraron el destino tras respuestas simuladas correctas: `g7-native-logout` o `Verificación en dos pasos`. No existe evidencia de fallo Django ni error en tokens reales; la nueva suite HTTP continúa roja.

Hipótesis técnica: `MockClient` con `http.Response` convierte el cuerpo en flujo de eventos diferidos; dentro de `testWidgets`/`FakeAsync` la lectura de los cuerpos correctos no progresa en los intervalos de `pump`. La denegación HTTP 401 pasa porque `NativeHttpAuthPort` la rechaza **antes de leer el cuerpo**, lo que apoya aislar este punto, aunque no prueba el diagnóstico por sí solo.

Corrección **solo del fixture de pruebas**: se usa `MockClient.streaming` y `http.StreamedResponse` con `Stream.multi`, `addSync` y `closeSync` para entregar bytes en el mismo turno del listener y ejercitar el parser HTTP. No hay modificación en `NativeHttpAuthPort`, Django, sesión real ni datos operativos. **PENDIENTE validación Flutter** posterior al commit de esta corrección; no declarar PASS sin prueba.

Comprobar de nuevo únicamente la nueva suite y regresión G7-A con `flutter pub get && flutter analyze && flutter test test/native_lab_login_shell_test.dart test/native_http_login_integration_test.dart --reporter expanded` en el contenedor Flutter. Ante un nuevo FAIL, conservar el primer error y añadir instrumentación de estado sin credenciales antes de probar cambios más amplios.

## G7-B — corrección de compilación del test de streaming, 03/11/2026

El operador actualizó `491f0702` y ejecutó `flutter pub get && flutter analyze`; el análisis detuvo la ejecución con **13 errores de tipado** en `native_http_login_integration_test.dart`, `G7_B_HTTP_RECHECK=1`. No se ejecutaron los widgets en este intento y **no se confirmó** ni refutó la hipótesis de streaming. El problema es una llamada `MockClient.streaming` con una función de un parámetro cuando `MockClientStreamHandler` exige `(BaseRequest request, ByteStream bodyStream)`; además, `BaseRequest` no expone `body`. La firma se ha contrastado con la API pública de `package:http`.

Corregido el archivo de tests: cuatro manejadores aceptan dos parámetros, el helper de comprobación recibe `http.BaseRequest` y los tres cuerpos JSON se comprueban con `jsonDecode(await bodyStream.bytesToString())`. No se cambia código operativo ni contratos HTTP Django. **Corrección aún no probada localmente; G7_B_HTTP_WIDGETS=PENDING**. Conservar el marcador de 6/6 G7-A como evidencia del commit previo, no como aprobación de G7-B. No desplegar ni migrar.

Validar primero con `flutter pub get && flutter analyze && flutter test test/native_lab_login_shell_test.dart test/native_http_login_integration_test.dart --reporter expanded` en el contenedor, sin reconstruir backend ni repetir PostgreSQL17.

## G7-B segundo test local: analyzer verde, 7/10 PASS y transporte mock aislado

El operador confirma `flutter analyze: No issues found!` y `G7_B_HTTP_RECHECK=1` con **7 PASS, 3 FAIL**. Los seis casos G7-A vuelven a pasar; en la nueva suite G7-B pasa HTTP 401 pero siguen fallando el login HTTP correcto, la pantalla MFA y la revocación (por falta de sesión inicial). Las excepciones únicamente indican falta de widgets esperados, no afirman todavía por qué no se completó el transporte.

En lugar de modificar autenticación ni aflojar las aserciones, se ha sustituido en la **prueba de integración** `MockClient.streaming` por un pequeño `_LabHttpClient extends http.BaseClient` que recibe un `http.Request`, valida URL, método, cabeceras y JSON de petición, y devuelve `http.StreamedResponse` sin puente asíncrono del cuerpo de petición. Se preserva la lectura/validación de HTTP JSON real en `NativeHttpAuthPort` y `NativeApiTransport`, los límites Bearer, la barrera de sesión y la bóveda sintética; no se usa una URL de Django operativa ni red externa. El test imprime en caso de bloqueo **únicamente metadatos no secretos**: cantidad de peticiones, último estado HTTP, estado del fence/bóveda y presencia de errores en UI.

**Candidata sin validación local**, `G7_B_HTTP_WIDGETS=PENDING`. El objetivo para la siguiente ejecución sigue siendo `flutter analyze` limpio y diez tests correctos. No hacer deploy, migrar DB persistente ni cerrar los gates MFA/MB1/C-FICHA.

La comprobación estática `g7_http_stack_mock_only` se ha adaptado al cliente `_LabHttpClient` (ya no usa `MockClient`) para conservar la validación del aislamiento. Se exige tanto el tipo inyectado `BaseClient` como la ausencia de un cliente HTTP real construido por esta suite o por `main.dart`. Además del test Flutter dirigido, ejecutar `python3 scripts/n1_static_security_gate.py`; ambos resultados permanecen **PENDING** tras estos cambios. Si sigue fallando una transición, copiar únicamente la línea `G7-B state mismatch`, que deliberadamente omite secretos.

## G7-B — Reestructuración tras `httpCalls=1 status=200` sin transición (03/11/2026)

El operador repitió el ensayo con el `_LabHttpClient` determinista. `N1_STATIC_GATE_RESULT=OK`, `flutter analyze: No issues found!`, pero `G7_B_RESULT=1` y tres transiciones no alcanzaron su estado: `httpCalls=1 status=200 fenceActive=false vaultPopulated=false loginError=false logoutError=false`. Esto **demuestra que el cliente de prueba recibió una respuesta 200**, pero no que el parser la completase; no es una justificación para modificar autenticación Django ni emitir una conclusión sobre seguridad de producción.

Se ha corregido el diseño del gate, que mezclaba en el mismo `testWidgets` dos modelos asíncronos distintos. `NativeHttpAuthPort._post` consume `Stream<bytes>` bajo `await for`; el `testWidgets` usa `FakeAsync` para el reloj virtual. La suite G7-B se ha reformulado a **cinco pruebas `test()` con asíncrono real**. Usan `MockClient` in-process y respuestas sintéticas, comprobando el recorrido completo `NativeHttpAuthPort → NativeSessionCoordinator → NativeRefreshCredentialVault → NativeApiTransport`, incluido Bearer de lectura, MFA, 401, fallo de revocación con reintento y 401 del Bearer que cierra el fence.

Los **seis tests de G7-A** siguen comprobando por separado pantalla, callbacks y cierre seguro con su `NativeAuthPort` sintético. La nueva suite **ya no pretende** que cada widget invoque el HTTP real dentro del propio `testWidgets`; **ese E2E de UI-red sigue pendiente** en el laboratorio HTTPS Django. No presentar las 11 pruebas conjuntas como una sola prueba E2E. Se ha modificado el gate `g7_http_stack_mock_only` para exigir `MockClient` sin clientes HTTP reales y para verificar la pantalla en su suite distinta.

**Estado tras estos commits: G7-A LOCAL PASS 6/6; G7-B RESTRUCTURED PENDING**, sin ejecución local ni GitHub Actions verde acreditada. Controlar que los cinco nuevos casos G7-B pasen sin cambiar la lógica de producción. Cualquier prueba real debe usar Django con DB desechable y credenciales de prueba, sin habilitar URLConf ni servicios operativos.

### Comprobación acotada posterior a la reestructuración

```bash
cd ~/vencira-m3-localcheck
git status --short
git fetch origin feature/m3-android-local-notifications
git merge --ff-only FETCH_HEAD
python3 scripts/n1_static_security_gate.py
sudo docker run --rm -v "$PWD/clients/flutter:/work" -w /work ghcr.io/cirruslabs/flutter:stable sh -c \
  'flutter pub get && flutter analyze && flutter test test/native_http_login_integration_test.dart test/native_lab_login_shell_test.dart --reporter expanded'
echo "G7_COMBINED_RESULT=$?"
```

No hace falta repetir PG17, reconstruir imágenes, migrar ni desplegar.

## G7-A + G7-B SPLIT: validación local verde (03/11/2026)

Resultado aportado por el operador: `flutter pub get` OK, `flutter analyze: No issues found!`, `flutter test test/native_lab_login_shell_test.dart test/native_http_login_integration_test.dart --reporter expanded`: **11/11 pruebas PASS** y `G7_SPLIT_RESULT=0`. Son 6 casos G7-A de UI/fixture y 5 G7-B de HTTP simulado con ejecución asíncrona real. Las advertencias sobre 17 paquetes más recientes no son errores de dependencia y no bloquean este gate. Los 11 PASS **no constituyen** un E2E Flutter→Django de red real ni validan la APK Android.

Se conserva la separación de suites porque widget FakeAsync y lectura de streams HTTP de `package:http` requieren entornos asíncronos distintos. G7-A/G7-B están validados **localmente en laboratorio**, con el control estático comprobado `N1_STATIC_GATE_RESULT=OK` por el operador en el intento anterior. `MFA_RELEASE_AUTHORIZED=NO`, `MB1_RELEASE_AUTHORIZED=NO`, `C_FICHA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`. El siguiente paso es ampliar la verificación HTTP de un servidor Django real en entorno test desechable, sin modificar rutas operativas, y después diseñar TLS de laboratorio para Flutter.

## G7-C — Contrato HTTP de socket Django real en loopback (PENDIENTE VALIDACIÓN)

Se añade `backend/native_sessions_lab/test_loopback_http_contract.py`: **3 pruebas de `LiveServerTestCase`** contra un servidor WSGI/HTTP real en `127.0.0.1`, puerto efímero, URLConf sustituido **solo durante la clase de test** por `native_sessions_lab.test_urls`, sin registrar rutas en la aplicación habitual. Las peticiones se envían con `http.client.HTTPConnection` (sin proxies, cookies por defecto ni red pública) y reciben respuestas reales del servidor Django. Prueban:

- Password sintético → `v1.a`/ `v1.r`, `GET /api/v1/mobile/me/` con Bearer, rechazo de refresh como access, revocación y denegación del access anterior.
- Rotación de refresh y access, invalidación del access anterior, y rechazo de replay de refresh que invalida también la sesión nueva.
- Contraseña errónea, cookie web y Origin rechazados, sin sesión Bearer anónima.

**Esta prueba NO conecta Flutter con Django**, ni usa TLS, ni prueba la APK ni habilita rutas móviles reales. Sirve para verificar el salto de las vistas Django/test client a HTTP sobre socket con persistencia en una **base creada y eliminada por Django test runner**. **No es un servidor desplegable**. El script PG17 `n1_identity_pg17_ephemeral.sh --lab` y los jobs CI SQLite/PG17 de `m3-product-contracts.yml` incorporan la nueva suite. El gate estático incorpora `g7_socket_lab_loopback_only` y valida sintaxis Python; conserva todos los controles previos.

**VALIDACIÓN PENDIENTE**: no existe una ejecución local/CI de G7-C en este instante y no debe declararse PASS. G7-A + G7-B **11/11 PASS local** sí se conservan. Antes de cualquier E2E Flutter→Django real queda por diseñar un laboratorio HTTPS con certificados confiables, DNS de red estrictamente aislado, garantía de que ni `dev.vencira.es` operativo ni BD persistente sean alcanzables, y un emisor Django test-only con revocación real.

Para validar sin reconstruir ni ejecutar Flutter innecesariamente, desde checkout actualizado y usando la imagen de backend de pruebas si sigue disponible:

```bash
cd ~/vencira-m3-localcheck
git status --short
git fetch origin feature/m3-android-local-notifications
git merge --ff-only FETCH_HEAD
python3 scripts/n1_static_security_gate.py
sudo docker build -t vencira-m3-backend-test ./backend
bash scripts/n1_identity_pg17_ephemeral.sh --lab
printf 'G7_C_LOOPBACK_PG17_RESULT=%s\\n' "$?"
```

El script usa PostgreSQL17 en `tmpfs` y una red Docker interna **sin puertos publicados**. La clase de socket abre únicamente loopback dentro del contenedor de test y no requiere acceso externo. Mantener `NO_DEPLOY_NO_LIVE_MIGRATION=1` y `RELEASE_AUTHORIZED=NO`.

## G7-D1 — TLS verificado en loopback con Django desechable (pendiente de prueba)

Se incorpora `backend/native_sessions_lab/test_verified_https_loopback.py` con tres `LiveServerTestCase` para comprobar **HTTPS real hasta un proxy local efímero** delante del servidor de test Django. El servidor Django sigue escuchando HTTP **solo en 127.0.0.1** (análogamente al reverse proxy operativo), mientras el proxy TLS escucha también **exclusivamente en 127.0.0.1 sobre un puerto aleatorio**. No se publica Docker `443` ni se cambia Caddy, Nginx o configuración de producción.

Cada caso crea una **CA temporal y una identidad de servidor temporal para `dev.vencira.es`**, con extensión SAN DNS. Los materiales de prueba se generan al ejecutar el test en un directorio temporal, la clave privada usa permisos 0600 y se elimina al acabar; no se incluyen ni distribuyen certificados o claves en el repositorio. El cliente se conecta físicamente a `127.0.0.1`, no consulta DNS público y establece SNI `dev.vencira.es`. La verificación de identidad y cadena de confianza permanece habilitada: `ssl.CERT_REQUIRED`, `check_hostname=True`; las pruebas exigen fallar ante una CA no confiable o un nombre de servidor incorrecto.

Las tres comprobaciones son (a) contraseña contra el emisor Django de laboratorio → Bearer `/me/` → revocación → denegación posterior, (b) CA/hostname incorrectos rechazados en handshake TLS, (c) Cookie web y Origin no permitido rechazados atravesando TLS. La configuración `ROOT_URLCONF=native_sessions_lab.test_urls` está limitada a esta clase de test; las rutas reales continúan ausentes.

Se integra en el runner de PG17 `--lab` y en SQLite/PG17 CI, y se añade un modo rápido **`--lab-https`** que ejecuta solo estas tres pruebas mediante PostgreSQL17 desechable en `tmpfs` y red Docker privada. El gate estático exige aislamiento loopback, TLS con validación de CA y hostname, y ausencia de desactivación de la verificación.

**`G7_D1_TLS_PG17_RESULT=PENDING`**: código publicado pero no ejecutado en local/CI de forma acreditada. Este bloque **no es aún una prueba Flutter→Django**, pues el cliente de las tres pruebas es Python `http.client` con TLS real; no es una APK Android ni debe presentarse como una aprobación de autenticación nativa. `G7-A/B=11/11 PASS local`; `G7-C/N1_PG17_LAB_RESULT=0` sobre 84 tests. Release sigue BLOQUEADO.

### Validación exclusiva G7-D1

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

No forzar `git merge` si existen conflictos con cambios locales. No desplegar, migrar BD persistente, abrir firewall ni utilizar claves de producción. Para G7-D2 quedará pendiente incorporar **el cliente Flutter a un servidor Django HTTPS aislado**, usando una política de certificados explícita y sin debilitar `NativeApiEndpoint`.

## G7-D1 validado — 3/3 pruebas TLS PostgreSQL17

El operador ha confirmado explícitamente:
```text
Ran 3 tests in 2.279s
OK
Destroying test database for alias 'default'...
G7_D1_TLS_PG17_RESULT=0
```
Conservar G7-A/B **11/11 PASS** y G7-C **84 PASS** (incluye pruebas reales de socket Django HTTP), ambos del operador. G7-D1 está **PASS local**; esto acredita TLS y Django con `http.client` Python y PostgreSQL desechable, pero aún no el cliente Flutter sobre una conexión HTTPS real.

## G7-D2 candidato — Dart/Flutter contra emisor Django real con HTTPS

Implementado en esta rama y **pendiente de ejecutar**:

- `backend/native_sessions_lab/g7_d2_https_fixture.py`: arranca Django WSGI de laboratorio con `ROOT_URLCONF=native_sessions_lab.test_urls`, registro de usuario sintético, SQLite exclusivamente en `/tmp/g7d2-disposable.sqlite3` del contenedor, HTTP upstream **127.0.0.1** y relay TLS interno a puerto 8443. La CA temporal se crea como en G7-D1; solo su **certificado público** se comparte con el cliente. El fixture rechaza entornos diferentes de `VENCIRA_ENV=test`, `VENCIRA_NATIVE_SESSION_LAB=1`, SQLite o ausencia de confirmación de red aislada.
- `clients/flutter/tool/g7_d2_https_probe.dart`: utiliza `HttpClient` y `IOClient` auténticos, `NativeHttpAuthPort`, `NativeSessionCoordinator`, `NativeRefreshCredentialVault` sintética y `NativeApiTransport`. El socket se conecta directamente a la **IP privada** de Docker, sin DNS externo, mientras conserva la URI/SNI `https://dev.vencira.es` y valida una CA de test con `SecurityContext(withTrustedRoots: false)`. No se usa `badCertificateCallback`.
- `clients/flutter/test/g7_d2_https_live_test.dart`: binding de Flutter explícitamente habilitado para red real, para evitar la respuesta HTTP 400 ficticia del binding de widget tests. La prueba está **omitida fuera del entorno de laboratorio**. No modifica los seis tests G7-A ni los cinco G7-B.
- `scripts/g7_d2_https_flutter_django.sh`: crea red Docker `--internal` con **cero puertos publicados**, imagen Django de pruebas, proceso Django read-only, DB/certificados en `tmpfs`, paquete Flutter precargado **antes** de crear la red interna, IP privada verificada, Flutter test en contenedor en la misma red, eliminación automática de red y contenedores. No se usan variables reales de producción, Caddy, la base persistente ni `dev.vencira.es` público.
- `.github/workflows/g7-d2-isolated-https.yml`: ejecución aislada en Actions para la rama de desarrollo o manual, sin publicar artefactos secretos. Gate estático `g7_d2_django_flutter_tls_isolation` y validación de sintaxis Python completan los controles.

El programa comprobará login de verdad contra Django, escritura y lectura de refresh sintético, GET `/me/` con Bearer, revocación remota y cierre local, rechazo de password inválida, rechazo de cookie web, CA no confiable y nombre TLS incorrecto. El token no se imprime en el log. **Todavía no demuestra una sesión de APK Android ni una UI Flutter que opere por HTTP real, ni MFA real entre ambos procesos**. El resultado G7-D2 sigue **PENDING**, no contabilizarlo como PASS.

Validación local focalizada después de actualizar la rama:

```bash
cd ~/vencira-m3-localcheck
git status --short
git fetch origin feature/m3-android-local-notifications
git merge --ff-only FETCH_HEAD
bash scripts/g7_d2_https_flutter_django.sh
echo "G7_D2_LOCAL_RESULT=$?"
```

Solo ejecutar si no existen conflictos locales; no usar `git reset --hard`. El script ejecuta el gate estático y `flutter analyze` antes de iniciar el laboratorio. `NO_DEPLOY_NO_LIVE_MIGRATION=1`; todos los permisos de release siguen **NO**. 
