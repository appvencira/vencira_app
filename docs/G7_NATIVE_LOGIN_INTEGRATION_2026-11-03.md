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

El operador confirma \`G7_RECHECK_RESULT=0\`, \`All tests passed!\`, **6/6** en \`native_lab_login_shell_test.dart\`. El test incluye comprobación directa de formato de credenciales y coordinador, login/password, MFA, logout exitoso, revocación fallida con reintento y montaje de \`VenciraApp\` con inyección explícita. Este resultado sigue siendo **solo laboratorio**; no autoriza beta ni activación en servidor.

### G7-B — nuevo bloque de pruebas integradas Flutter con contrato Django simulado

Nuevo archivo \`clients/flutter/test/native_http_login_integration_test.dart\` con cuatro tests \`testWidgets\`. Encadena los componentes de producción potenciales, sin ejecutarlos contra una API real: 
- \`NativeLoginScreen\` → \`NativeLabLoginShell\` → \`NativeSessionCoordinator\` → \`NativeHttpAuthPort\` con \`MockClient\` → \`NativeRefreshCredentialVault\` con almacenamiento sintético.
- Valida el GET \`/api/v1/mobile/me/\` por \`NativeApiTransport\`, con \`Authorization: Bearer\` únicamente **después** de recibir tokens con forma correcta y de escribir/verificar refresh; no permite GET antes de login ni después de logout.
- MFA: comprueba que \`mfa_required\` no escribe refresh ni abre el \`fence\`; TOTP aceptado activa la sesión y el puerto exige el contrato de desafío.
- Contraseña denegada: HTTP 401 no desbloquea ni persiste credenciales.
- Revocación fallida: el cierre deja el fence bloqueado, conserva refresh para reintento explícito y no permite volver a login hasta recibir acuse de revocación.

Estas respuestas son **simuladas según** \`native_sessions_lab.test_http_contract\`, cuyos HTTP Django están probados por separado en PostgreSQL17 desechable. Esto NO es todavía una prueba de red extremo a extremo Flutter→Django. No se crean rutas de autenticación operativa, migraciones persistentes, usuario real, claves reales, APK pública ni endpoint remoto accesible.

Actualizados \`scripts/m3_native_http_contract_batch.sh\`, \`.github/workflows/m3-product-contracts.yml\` y \`scripts/n1_static_security_gate.py\` para incluir y vigilar la nueva suite en el entorno aislado. **G7_B_HTTP_WIDGETS=PENDING** tras estos commits; no afirmar CI verde.

### Próxima validación local específica

\`\`\`bash
cd ~/vencira-m3-localcheck
git status --short
git fetch origin feature/m3-android-local-notifications
git merge --ff-only FETCH_HEAD
sudo docker run --rm -v "$PWD/clients/flutter:/work" -w /work ghcr.io/cirruslabs/flutter:stable sh -c \
  'flutter pub get && flutter analyze && flutter test test/native_lab_login_shell_test.dart test/native_http_login_integration_test.dart --reporter expanded'
echo "G7_B_HTTP_TEST_RESULT=$?"
\`\`\`

Si da PASS, el siguiente paso será diseñar una prueba E2E **aislada** en la que Flutter y Django se comuniquen realmente por HTTPS, sin utilizar \`dev.vencira.es\` productivo, sin alterar la whitelist pública y sin abrir rutas de usuario reales. Para ello habrá que preparar certificados de laboratorio confiables y un emisor temporal controlado, además de asegurar que la aplicación release no lo pueda habilitar.
