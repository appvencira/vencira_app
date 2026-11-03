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

## G7-D2 primer intento: compilación Dart FALLA, corrección solo del probe

El operador ejecutó `scripts/g7_d2_https_flutter_django.sh` sobre el candidato anterior. Build Docker y `flutter pub get` completaron, pero `flutter analyze` falló con **tres errores** `undefined_setter` sobre `connectionTimeout`, `idleTimeout`, `connectionFactory` en `tool/g7_d2_https_probe.dart`; `G7_D2_GATE_RESULT=1`. **No llegaron a iniciarse las pruebas reales HTTPS contra Django**: el fallo es exclusivamente de tipado/sintaxis Dart. Causa: la cadena de cascada inmediatamente tras la asignación de `findProxy = (_) => 'DIRECT'` se asoció al retorno de tipo `String` de la función. Se sustituyeron las cascadas por asignaciones explícitas independientes sobre `HttpClient`, conservando `findProxy = DIRECT`, socket forzado a IPv4 privada, CA y verificación TLS, timeouts y callback de conexión sin cambios de comportamiento deseados. **Nueva validación PENDING**; no afirmar G7-D2 PASS.

Comprobación recomendada, sin datos persistentes: `git fetch origin feature/m3-android-local-notifications && git merge --ff-only FETCH_HEAD && bash scripts/g7_d2_https_flutter_django.sh`. Este script ejecuta el control estático y `flutter analyze` antes de iniciar la red privada. El resultado requerido es `G7_D2_GATE_RESULT=0` y `G7_D2_HTTPS_FLUTTER_DJANGO_RESULT=0`. No cambiar backend, configuración de Caddy ni migrar BD operativa.

## G7-D2 — primer intento con compilación PASS, bloqueado en exportar CA temporal

El operador confirma `flutter analyze` **No issues found**, `G7_D2_FIXTURE_READY=OK` y `G7_D2_GATE_RESULT=1`, con error de Docker: `Could not find the file /tmp/g7d2-public-ca.pem in container vencira-g7d2-django-…` al ejecutar `docker cp`. En este intento **no se ejecutó la prueba de Flutter→HTTPS→Django**. El marcador de preparación se comprobó dentro del contenedor, pero `docker cp` no pudo exportar el certificado CA del `tmpfs`; todavía no se ha acreditado si se debe a una limitación del mecanismo de copia o a la visibilidad del archivo.

El runner ahora comprueba desde el propio contenedor mediante `docker exec` que existen tanto el marcador como un certificado público no vacío, y lo transmite con `docker exec ... cat` a un archivo privado temporal del host (redirección local, **nunca mostrar PEM en logs**). Comprueba cabeceras PEM, tamaño y permisos `0600`; no transfiere ninguna clave privada. Se ha actualizado `g7_d2_django_flutter_tls_isolation` en el control estático para exigir este flujo y evitar volver a `docker cp`. No se han alterado Django, CA/TLS, el cliente Flutter, rutas públicas ni base persistente. **G7-D2 continúa PENDING** hasta una nueva prueba.

Próxima validación focalizada: actualizar con `git fetch` + `git merge --ff-only` y repetir exclusivamente `bash scripts/g7_d2_https_flutter_django.sh`. Si falla el chequeo de origen, registrar `G7_D2_PUBLIC_CA_SOURCE=MISSING`; si sigue, los marcadores `G7_D2_PUBLIC_CA_READY`, `G7_D2_HTTPS_FLUTTER_DJANGO_RESULT` y `G7_D2_GATE_RESULT` identificarán la fase. No repetir PG17 ni habilitar producción.

## G7-D2 — fallo real: script shell PEM truncado + permisos de CA + falso PASS (03/11/2026)

El operador informó sobre el intento anterior: `flutter analyze: No issues found`, `G7_D2_FIXTURE_READY=OK`, pero `grep: unrecognized option '--no-pub'`, `PathAccessException: Cannot open file /tmp/g7d2-public-ca.pem (Permission denied, errno=13)`, `scripts/g7_d2_https_flutter_django.sh: line 147: .../public-ca.pem: Permission denied`, y `G7_D2_GATE_RESULT=1`. También aparecía una línea **incorrecta** `G7_D2_FLUTTER_DJANGO_HTTPS=OK` a pesar del fallo. Esto **NO acredita un handshake HTTPS ni G7-D2 PASS**.

Revisión del archivo exacto en GitHub: la condición `grep` de validación PEM había quedado **truncada con comillas abiertas** y engullía comandos posteriores como un patrón multilínea. El shell permitía el archivo (comillas equilibradas más adelante), pero ejecutaba partes duplicadas en un orden erróneo: se encontraron **tres invocaciones** de `flutter test` y tres declaraciones de éxito. El fallo fue introducido en la edición previa del runner, no en Django ni el cliente Dart. La CA compartida se exponía con `chmod 600`, y al usar un usuario distinto en el contenedor Flutter el archivo público de solo lectura no podía abrirse.

Corrección: **sustitución completa** de `scripts/g7_d2_https_flutter_django.sh` por una única secuencia de arranque/validación/probe/limpieza. Desde el contenedor Django se comprueba el archivo CA, se transmite **solo certificado público** por `docker exec cat`, se valida localmente con `python3 ssl.PEM_cert_to_DER_cert` exigiendo un certificado y ninguna clave privada, y se establece `0644` para el archivo público (el directorio temporal del host conserva `0700`; la montura es `:ro`). Se elimina el `grep` mal formado, se conserva `set -euo pipefail` y el runner usa `tee` con `pipefail`; comprueba `G7_D2_HTTPS_FLUTTER_DJANGO_RESULT=0` y `All tests passed!` del resultado real **antes** de imprimir el único `G7_D2_FLUTTER_DJANGO_HTTPS=OK`. El gate estático exige exactamente **una ejecución Flutter** y **un marcador de éxito**, además de la validación PEM y el aislamiento previo. Código de producción, CA temporal, URLConf operativa y DB persistente **sin cambios**.

**G7-D2 continúa PENDING** hasta repetir el script y obtener `G7_D2_GATE_RESULT=0` y `G7_D2_LOCAL_RESULT=0` sobre esta versión. No considerar el `G7_D2_FLUTTER_DJANGO_HTTPS=OK` anterior como evidencia. Verificación focalizada: `git fetch origin feature/m3-android-local-notifications && git merge --ff-only FETCH_HEAD && bash -n scripts/g7_d2_https_flutter_django.sh && bash scripts/g7_d2_https_flutter_django.sh`. No repetir los ensayos G7-A/B/C/D1; los datos operativos permanecen intactos.

## G7-D2: primera ejecución de Dart frente al emisor real; diagnóstico HTTP pendiente

El operador confirma tras la corrección del PEM:
```text
flutter analyze: No issues found!
G7_D2_FIXTURE_READY=OK
G7_D2_PUBLIC_CA_READY=OK
G7_D2_INITIAL_FENCE=OK
NativeHttpAuthFailure (NativeHttpAuthPort._post, línea 71)
G7_D2_GATE_RESULT=1
```

Esto confirma que el contenedor Flutter **puede leer la CA pública**, iniciar la suite live y verificar el fence inicial. La excepción **no permite atribuir el fallo a TLS, HTTP, Django o forma de tokens**: `NativeHttpAuthPort._post` deliberadamente transforma diferentes fallos en `NativeHttpAuthFailure`. G7-D2 sigue rojo, **NO PASS**; el marcador de éxito y de cleanup ya no es falso.

Se añade instrumentación *solo del laboratorio* en `clients/flutter/tool/g7_d2_https_probe.dart`, sin cambiar la lógica `lib/api/native_http_auth_port.dart`: (1) `_preflightTls` usa `Socket.connect` hacia la IPv4 privada de Docker y `SecureSocket.secure(host: dev.vencira.es, context: CA temporal)`, sin DNS ni desactivar verificación, para diferenciar fallo TLS de HTTP; (2) `_SafeHttpTraceClient` mantiene `IOClient` real pero registra **solo** etiqueta de endpoint de una lista fija, código HTTP, si Content-Type es JSON, presencia de Set-Cookie y clase del error de transporte; (3) el `connectionFactory` registra la comprobación de destino y los booleanos de guardia, nunca URL completa, credenciales, tokens, cuerpos ni cabeceras sensibles. El gate estático exige estos componentes.

En el próximo `bash scripts/g7_d2_https_flutter_django.sh`, obtener `G7_D2_TLS_PREFLIGHT`, `G7_D2_FACTORY_...` y `G7_D2_HTTP_PASSWORD_...` para clasificar la causa. Si falla, compartir únicamente las líneas de resultado/primera excepción. **No** relajar `SecurityContext`, no desactivar verificación TLS, no habilitar rutas operativas. G7-A/B/C/D1 siguen PASS anteriores.

## G7-D2 — raíz del _ClientSocketException y corrección de TLS en connectionFactory (03/11/2026)

Resultado local proporcionado: `flutter analyze=OK`, `G7_D2_FIXTURE_READY=OK`, `G7_D2_PUBLIC_CA_READY=OK`, `G7_D2_TLS_PREFLIGHT=OK`, `G7_D2_INITIAL_FENCE=OK`, `G7_D2_FACTORY_PRIVATE_TCP=OK`, `G7_D2_HTTP_PASSWORD_TRANSPORT_FAILURE_TYPE=_ClientSocketException`, `G7_D2_GATE_RESULT=1`. No llegó ningún estado HTTP. Por tanto, el fallo es anterior a la interpretación de tokens; las credenciales no están implicadas.

Se inspeccionó la implementación del SDK Dart de `HttpClient.connectionFactory`. Cuando se proporciona este callback, **sustituye por completo** la creación de `SecureSocket.startConnect` que Dart realizaría automáticamente para HTTPS. Nuestro callback anterior devolvía `Socket.startConnect` (TCP sin TLS), por lo que el cliente HTTP intentaba escribir HTTP no cifrado contra el proxy HTTPS que espera TLS. El `SecureSocket.secure` ejecutado por el preflight sí pasaba, porque era **otro socket distinto**. Causa técnica explicada por el código del SDK (consultar referencia pública Dart `HttpClient.connectionFactory`).

Se corrige **exclusivamente** `clients/flutter/tool/g7_d2_https_probe.dart`: el callback TCP privado crea `ConnectionTask.fromSocket<Socket>` cuyo futuro resuelve a `SecureSocket.secure(raw, host: uri.host, context: trust)`; conserva la CA de prueba, la validación estricta SAN/SNI y el destino privado de Docker. Se gestiona cancelación y destrucción del socket en el camino de error. Nuevo marcador de avance `G7_D2_FACTORY_VERIFIED_TLS=OK`. No se utiliza `badCertificateCallback` ni se altera `NativeHttpAuthPort`. El gate `scripts/n1_static_security_gate.py` ahora **rechaza** volver a entregar el socket sin TLS. Este cambio es exclusivo del cliente de pruebas, no supone que exista una sesión móvil operativa.

**G7-D2 todavía PENDING**: se ha publicado una corrección razonada, pero no ha sido ejecutada localmente. Repetir **solo** `bash scripts/g7_d2_https_flutter_django.sh` tras fast-forward; comprobar `G7_D2_FACTORY_VERIFIED_TLS=OK`, código HTTP de password, `G7_D2_HTTPS_FLUTTER_DJANGO_RESULT=0` y `G7_D2_GATE_RESULT=0`. Si falla Flutter analyze o el test, conservar la salida del primer error para ajustar el laboratorio. G7-A/B/C/D1 mantienen resultados previos; release NO, no desplegar ni migrar la base persistente.

## G7-D2 — HTTPS Flutter → Django validado de extremo a extremo en laboratorio (03/11/2026)

El operador aportó el log completo de `flutter test test/g7_d2_https_live_test.dart`: `flutter analyze: No issues found!`, fixture Django y CA temporal READY, handshake de TLS/SNI verificado, `G7_D2_FACTORY_VERIFIED_TLS=OK`, login `HTTP 200`, almacenamiento sintético del refresh y fence activo, GET Bearer `/me/` `HTTP 200`, cierre síncrono del fence, revocación HTTP 200, denegación del Bearer antiguo HTTP 401, contraseña incorrecta HTTP 401, petición con cookie HTTP 403, rechazo de CA no confiable y rechazo de nombre TLS incorrecto. Resultado inequívoco `G7_D2_HTTPS_FLUTTER_DJANGO_RESULT=0`, `All tests passed!`, `G7_D2_FLUTTER_DJANGO_HTTPS=OK`, `G7_D2_GATE_RESULT=0`. Este resultado **sí acredita tráfico HTTPS real** entre Dart/Flutter y Django de laboratorio en dos contenedores Docker mediante red privada, con CA temporal verificada y base SQLite desechable. No requiere desplegar ni tocar BD persistente.

**Anomalía observada:** para la petición de cookie no autorizada, `G7_D2_HTTP_PASSWORD_HAS_SET_COOKIE=true` pese a código de rechazo HTTP 403. No implica autenticación exitosa, pero la causa exacta y si es una cookie de borrado de sesión **no están demostradas** en este log. El siguiente subgate verificará el nombre y atributos de la cookie **sin imprimir su valor** y rechazará cualquier indicio de concesión de sesión. Los caminos de login 200 y Bearer 200 no emitieron `Set-Cookie`.

**Alcance cerrado:** G7-A/B 11 PASS; G7-C PG17 84 PASS; G7-D1 TLS PG17 3 PASS; **G7-D2 HTTPS Flutter↔Django PASS**. Sigue **pendiente** probar MFA real Dart→Django, rotación/replay de refresh usando cliente Dart real, eventual APK física y aprobación del servicio nativo para producción. Las rutas Django móviles siguen excluidas de `config.urls` y el PR #17 sigue borrador, `MFA_RELEASE_AUTHORIZED=NO`, `MB1_RELEASE_AUTHORIZED=NO`, `C_FICHA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`. El resultado no autoriza migraciones ni despliegue.

## G7-D2 cookie response regression: candidate not yet validated

The successful G7-D2 HTTPS run showed HTTP 403 for a browser-cookie request, but the response included a Set-Cookie header. A test-only regression was added in `clients/flutter/tool/g7_d2_https_probe.dart` to verify that any returned Set-Cookie is exclusively a deletion (`Max-Age=0`) of `vencira_sessionid`, with no cookie values logged. The native auth implementation and Django remain unchanged. The static guard now checks that this assertion is present. **This additional assertion remains PENDING local validation.** It does not invalidate the preceding G7-D2 PASS: login, Bearer and remote revocation over genuine HTTPS were already confirmed. If the assertion fails, inspect only safe attributes, never cookie contents or session IDs. The operational release gates remain closed.

## G7-D2: subgate de cookie eliminado PASS (operador 03/11/2026)

Nueva ejecución confirmada: `G7_D2_REJECT_COOKIE_SESSION_NAME=true`, `G7_D2_REJECT_COOKIE_DELETION=true`, `G7_D2_WEB_COOKIE_RESPONSE_ONLY_DELETES_SESSION=OK`, `G7_D2_HTTPS_FLUTTER_DJANGO_RESULT=0`, `All tests passed!` y `G7_D2_GATE_RESULT=0`. La cabecera `Set-Cookie` del rechazo HTTP 403 borra `vencira_sessionid` mediante `Max-Age=0`, no concede una sesión nueva. El bloque G7-D2, incluido este subgate, está localmente **PASS**.

## G7-E — MFA TOTP y refresh/replay a través de HTTPS real (IMPLEMENTADO, PENDING)

El laboratorio Django `backend/native_sessions_lab/g7_d2_https_fixture.py` añade un **usuario MFA sintético separado** con `UserMfaState.enabled=True`, secreto TOTP RFC 6238 de prueba cifrado mediante `encrypt_totp_secret` y clave Fernet **nueva en cada ejecución**, restringida al proceso de test y nunca expuesta a Dart, host, Docker env de arranque ni logs. No se habilita la inscripción MFA, la autenticación móvil ni las rutas operativas de producción.

El cliente `clients/flutter/tool/g7_d2_https_probe.dart` incorpora en la misma conexión real de `HttpClient`/TLS estricta:

- **G7-E1 MFA**: password correcto exige challenge, `fence.ticket == null`, vault sin refresh y GET bloqueado hasta verificar el TOTP generado en Dart por HMAC-SHA1/RFC6238. Un código TOTP ya consumido no abre otra challenge, la sesión creada permite `GET /me/` y logout cierra inmediatamente el fence, borra vault y revoca en Django el Bearer.
- **G7-E2 refresh**: `NativeHttpAuthPort.rotateRefresh` recibe nuevas credenciales, invalida el Bearer antiguo, protege la nueva sesión hasta que el refresh antiguo se reproduce; el replay debe denegarse y **revocar también la sesión nueva**. Una segunda rotación seguida de `revoke` valida el cierre normal. La rotación se prueba desde el puerto HTTP, **no** desde `NativeSessionCoordinator`: el orquestador de refresh automático con recuperación tras crash **NO está implementado ni autorizado**.
- `crypto: ^3.0.6` como dependencia exclusivamente `dev_dependencies` permite generar el TOTP de test en Flutter, sin añadir criptografía al runtime del producto.

El mismo script `scripts/g7_d2_https_flutter_django.sh` ahora exige obligatoriamente `G7_E_MFA_HTTPS_RESULT=0`, `G7_E_REFRESH_REPLAY_RESULT=0`, `G7_D2_HTTPS_FLUTTER_DJANGO_RESULT=0` y `All tests passed!` antes de declarar éxito. Gate estático `g7_e_https_mfa_rotation_only_in_lab` supervisa separación de test, TOTP, replay, rotación y marcadores.

**G7-E aún PENDING:** no ejecutar despliegue ni migración persistente; no contabilizarlo como PASS antes de recibir el resultado local. Reutilizar script y entorno aislado G7-D2 con `git fetch origin feature/m3-android-local-notifications`, `git merge --ff-only FETCH_HEAD`, `bash scripts/g7_d2_https_flutter_django.sh`. Se omite repetir PG17, G7-A/B/C/D1. La APK Android real, el soporte de refresh en coordinador, la custodia externa MFA y los gates de producción permanecen sin autorización.

## G7-E adicionales: vector RFC6238 y rechazo de redirecciones

Antes de la validación local se añadió un vector conocido RFC6238 para HMAC-SHA1: a los 59 segundos con la semilla sintética de prueba, TOTP de 6 cifras `287082`. Esto verifica que el generador Dart del ensayo coincide con RFC6238, sin mostrar TOTP operativo. Las peticiones Bearer de inspección directa bloquean redirecciones HTTP. El gate estático exige ambos controles. G7-E sigue PENDING hasta ejecución local. No hay cambios en autenticación ni rutas de producción.

## G7-E — MFA y rotación/replay HTTPS: validación local PASS (03/11/2026)

El operador aporta `flutter analyze: No issues found!`, `G7_E_MFA_HTTPS_RESULT=0`, `G7_E_REFRESH_REPLAY_RESULT=0`, `G7_D2_HTTPS_FLUTTER_DJANGO_RESULT=0`, `All tests passed!` y `G7_D2_GATE_RESULT=0`, ejecutados sobre cliente Flutter/Dart real conectado vía TLS con CA temporal a Django solo laboratorio en Docker --internal/SQLite tmpfs.

Recibo de seguridad MFA: vector RFC6238 OK, contraseña de usuario MFA devuelve challenge y no abre fence ni guarda refresh, GET protegido bloqueado hasta TOTP, TOTP válido da sesión y Bearer 200, TOTP ya consumido 401, logout síncrono, revocación remota HTTP 200 y posterior Bearer 401. Recibo refresh: rotación HTTP 200, tokens nuevos diferentes, antiguo access 401 y nuevo 200, reutilización de refresh antiguo HTTP 401 y nuevo access invalidado 401; otra rotación y revocación también correctas. No se imprime ninguna clave MFA ni material de sesión.

**G7-E íntegro PASS local.** No equivale a renovación automática de una sesión de Android; `NativeSessionCoordinator` no implementa una recuperación de rotación ambigua ni un refresco autónomo. La CA temporal, rutas Django y datos siguen fuera de producción.

## G7-F1 — recuperación explícita por refresh de respuesta incierta (implementado, NO validado)

Se añade al probe G7-D2 el caso `_verifyAmbiguousRefreshRecoveryHttps`, que emplea implementaciones existentes `NativeRefreshRecoveryJournal`, `NativeRecoveryLoginGateway` y `NativeHttpAuthPort` contra Django HTTPS real. La prueba arma y verifica primero el marcador persistente, mantiene cerrado el fence, permite que Django **confirme la rotación** pero descarta la respuesta al cliente, simula arranque frío y exige recuperación con nueva contraseña **por endpoint distinto** (no reenvía refresh antiguo). Comprueba que contraseña errónea conserva marcador y no revoca todavía el dispositivo, que la contraseña correcta sustituye refresh en vault, borra marcador, activa fence y revoca en el servidor los tokens previos. Termina revocando la sesión recuperada y limpiando vault. No incluye persistencia protegida Android real ni recuperación MFA de una sesión cuyo refresh falló.

El script `scripts/g7_d2_https_flutter_django.sh` exige ahora adicionalmente `G7_F_AMBIGUOUS_REFRESH_RECOVERY_RESULT=0` antes de `G7_F_HTTPS_RECOVERY=OK`. `scripts/n1_static_security_gate.py` añade `g7_f_disposable_https_uncertain_refresh`; la prueba está separada de código de producción y no habilita el refresh automático. **G7-F1 PENDING**: requiere validación Flutter analyze/runtime local; no afirmar PASS ni recontabilizar G7-E como pendiente. No desplegar ni migrar DB operativa. 

## G7-F1 validado y agrupación de pruebas G7 — 03/11/2026

Resultado local proporcionado por el operador: `G7_F_AMBIGUOUS_REFRESH_RECOVERY_RESULT=0`, `G7_F_HTTPS_RECOVERY=OK`, `G7_E_MFA_HTTPS_RESULT=0`, `G7_E_REFRESH_REPLAY_RESULT=0`, `G7_D2_GATE_RESULT=0` y `All tests passed!`. Se verificó que el marcador persistente se escribe antes del refresh, el servidor confirmó la rotación aunque la respuesta se perdió, el reinicio lógico mantiene cerrado el fence, la contraseña incorrecta no revoca todavía, la recuperación correcta reemplaza refresh, limpia marcador y revoca todas las credenciales anteriores; logout final verifica revocación. **G7-F1 PASS local.** La línea de `G7_D2_HTTPS_FLUTTER_DJANG;O_RESULT=0` del pegado contiene un separador anómalo, pero el script de la rama anterior exige la cadena exacta en el log, ejecutó `All tests passed!` y terminó `G7_D2_GATE_RESULT=0`; no depende de interpretar ese texto pegado para acreditar el éxito.

### Nuevo runner agrupado (candidato, pendiente de un recheck)

Se ha actualizado `scripts/g7_d2_https_flutter_django.sh` para ejecutar los bloques sobre **una sola instancia Django de test** en una red Docker `--internal` con SQLite y CA TLS temporales, reutilizando entre ejecuciones un volumen de caché Pub **solo de dependencias públicas** (`vencira-g7-public-dart-pub-v1`). El volumen de caché es persistente para acelerar reejecuciones, pero la BD, las claves, los certificados y los resultados temporales se destruyen siempre. Se mantienen `VENCIRA_ENV=test`, red privada, ausencia de puertos publicados y `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

- `bash scripts/g7_d2_https_flutter_django.sh --fast`: ejecuta **solo G7-F** usando resolución de dependencias offline primero (con fallback online), sin repetir `flutter analyze`; el compilador/test Flutter sigue ejecutándose. Es para iteraciones, NO valida toda la macrofase.
- `bash scripts/g7_d2_https_flutter_django.sh --group d2|e|f`: ejecuta solo el bloque seleccionado, con las mismas reglas rápidas. `d2` verifica login/TLS/cookies, `e` MFA/refresh/replay, `f` recuperación de refresh ambiguo.
- `bash scripts/g7_d2_https_flutter_django.sh --all` (también sin argumentos): ejecuta **D2 + E + F**, verifica `flutter analyze` y exige los cuatro marcadores de éxito. Se usará una sola vez al cerrar cada macrofase, además de CI.

La salida estándar muestra únicamente marcadores de grupo al pasar; si alguna comprobación falla, imprime la cola del log diagnóstico y termina con código no cero. La selección de grupo se valida estrictamente antes de crear infraestructura, se pasa únicamente a Dart del laboratorio y no cambia TLS, rutas ni la lógica de autenticación. El gate estático `g7_fast_batch_isolation_and_full_suite_gates` impide quitar requisitos de aislamiento y de resultado. El workflow `.github/workflows/g7-d2-isolated-https.yml` ejecuta siempre `--all` cuando hay cambios pertinentes en scripts/cliente/backend, y mantiene PR en borrador.

**Importante:** esta optimización de runner se acaba de publicar, pero todavía no hay recibo local `G7_BATCH_RESULT=0` con la versión nueva. Los resultados históricos D2/E/F permanecen válidos para el código de pruebas previo; el nuevo mecanismo de selección y caché está **PENDING**. Evitar volver a pedir 84 pruebas PG17 por cada cambio de G7. Las validaciones completas de publicación, Android real, custodia MFA y migraciones operativas continúan BLOQUEADAS.

### Corrección de marcadores del runner agrupado

Los modos `--fast` y `--group d2|e|f` informan `G7_BATCH_GATE_RESULT` y `G7_BATCH_RESULT`, además de sus marcadores de grupo; **no** informan `G7_D2_GATE_RESULT=0`, reservado exclusivamente para `--all`. Esto evita confundir un PASS focalizado con una validación integral. El nombre de la prueba Flutter ahora identifica el lote seleccionado. El control estático exige esa separación. Estas mejoras del runner permanecen pendientes de verificación local; G7-F, E y D2 conservan sus PASS anteriores.

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
