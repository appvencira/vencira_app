# VENCIRA — Conectividad y autenticación NATIVAS Android e iOS
Fecha: 2026-11-02
Estado: CONTRATO / DISEÑO PENDIENTE DE IMPLEMENTACIÓN Y VALIDACIÓN
Rama de trabajo inicial: feature/m3-android-local-notifications; PR #17 draft.

## Objetivo de producto (obligatorio)
La aplicación móvil VENCIRA debe trabajar directamente con la API Django mediante HTTPS **desde Android y desde iOS**, incluida conectividad por datos móviles fuera de la red local, sin depender del navegador web como medio de autenticación o de ejecución. Debe permitir usar las funciones autorizadas del usuario con sesión nativa, permisos de workspace y revocación segura. **No dar por terminada la conectividad móvil cuando solo se abre dev.vencira.es en Chrome/Safari.**

Flutter Web mantiene el flujo actual de sesión web y CSRF, sin regresiones. Android/iOS compartirán un contrato de API y autenticación multiplataforma, con adaptadores de almacenamiento y ciclo de vida específicos de cada sistema. No mezclar identidades web y nativas por accidente.

## Diagnóstico reproducido el 02/11/2026
- APK Android instalado en dispositivo y conectado mediante datos móviles muestra «No se han podido cargar los datos».
- dev.vencira.es funciona en Chrome con los mismos datos móviles: el servidor público y HTTPS son accesibles.
- En código, HttpVenciraApi usa `baseUri ?? Uri.base`; el README señala explícitamente que el cliente HTTP usa cookies de sesión **solo en web bajo el mismo origen** y que no hay autenticación nativa terminada.
- El permiso `android.permission.INTERNET` faltaba en la variante Release; se corrigió y verificó mediante `aapt`, publicado en commit d6ebf49.
- Workaround temporal 6251c95/58dedbb y prueba 204162c: Android abre navegador externo en `https://dev.vencira.es/`; NO proporciona conexión nativa ni sesión Android. Validación local de este cambio está ejecutándose, resultado aún no comunicado.
- iOS no ha sido construido ni probado; no inferir compatibilidad iOS a partir de compilaciones Android.

## Contrato de seguridad antes de programar credenciales
1. Diseñar y revisar endpoints de autenticación móvil en Django, compatibles con MFA, recuperación, revocación, límites de intentos y auditoría. Considerar Authorization Code + PKCE con proveedor OIDC o un contrato equivalente revisado; no inventar endpoints ni hacer login por scraping de páginas Django.
2. Cliente HTTP nativo debe usar una URL base HTTPS explícita, independiente de `Uri.base`, con control estricto de host/esquema por entorno; no permitir HTTP o URL arbitraria suministrada por servidor.
3. Tokens de acceso de vida corta, renovación y revocación con rotación/reutilización detectada según diseño aprobado; definir caducidad y gestión de errores sin reintentos de escrituras no idempotentes. **No guardar contraseñas ni secretos en código, SharedPreferences, logs ni repositorio.**
4. Persistencia mínima protegida mediante Android Keystore e iOS Keychain (adaptadores de plataforma; decidir política biométrica y copias de seguridad explícitamente). Borrado seguro en logout, caducidad, cambio de cuenta/workspace y pérdida de permisos; mantener barrera de cancelación de alarmas antes de avanzar.
5. CSRF y cookies web permanecen en su flujo; la autenticación móvil debe tener su propia protección contra suplantación, almacenamiento indebido y fugas por redirección.
6. Uso de TLS válido, límites de redirección y errores de certificado tratados como fallo; nunca saltar validación TLS para pruebas. Separar entorno dev de producción.
7. Pruebas de backend y clientes: 401/403, expiración, desconexión 4G/Wi-Fi, MFA, token revocado, rotación simultánea, cambios de workspace, datos tardíos, proceso en segundo plano, reinstalación, cierre de sesión y fallo de borrado; no reexponer información tras revocación.
8. iOS: configuración ATS, permisos, Keychain, firma/provisioning y pruebas en iPhone real; Android: Keystore, Network Security Config, Activity/manifest y dispositivo real.

## Entregas en macrobloques
- N1 Contrato backend (amenazas y esquema de sesión, endpoints y tests, sin migración persistente).
- N2 Capa API Flutter multiplataforma (separar cliente web vs cliente nativo; inyección de base HTTPS, tests con transporte simulado).
- N3 UI de autenticación Android+iOS y almacenamiento seguro, MFA/revocación con tests de barreras.
- N4 E2E con entorno temporal aislado, pruebas reales Android e iOS en conexión exterior y rehabilitación controlada de UI móvil.
- N5 revisión de seguridad, autorización independiente de distribución y entrega; firma de producción y stores solo tras aprobación y custodia real.

## Evidencia ya disponible vs pendiente
- Flutter 273 tests; Django SQLite 77; PG17 temporal 77; Flutter Web, APK Android Debug, APK Android Release y reconstrucción desde clon GitHub: PASS comunicados localmente para commits previos.
- APK Android Release auditado con `allowBackup=false`, `debuggable` no declarado, permiso INTERNET añadido; firma es Android Debug (no distribuible).
- **No hay pruebas de contrato de sesión móvil nativa, ni build iOS, ni pruebas en dispositivo iOS, ni validación de autenticación nativa Android.**
- El workaround navegador no incrementa hitos de autenticación nativa.
- Gates activos: `MB1_RELEASE_AUTHORIZED=NO`; `MFA_RELEASE_AUTHORIZED=NO`; `C_FICHA_RELEASE_AUTHORIZED=NO`; `NO_DEPLOY_NO_LIVE_MIGRATION=1`. No activar alarmas reales o envíos externos.

## Criterio de aceptación
Dos aplicaciones móviles instalables (Android e iOS) pueden iniciar sesión **nativamente** y operar sobre la API HTTPS desde datos móviles con autenticación segura, MFA y revocación verificados, sin navegador como dependencia funcional. Flutter Web sigue funcionando. La aceptación requiere tests automáticos y pruebas físicas por plataforma, y aprobación explícita de los gates operativos. No declarar completado antes.

## N1/N2 — Ejecuciones locales y transporte aislado (02/11/2026)

- Pruebas locales comunicadas por el operador: `N1_AUTH_BOUNDARY_RESULT=0` para pruebas de barrera Django; `NATIVE_API_CONTRACT_RESULT=0` para `flutter analyze` y cuatro pruebas Flutter (política de origen y acceso provisional). No extrapolarlo a pruebas nuevas que aún no se han ejecutado.
- Contrato detallado: [N1_NATIVE_AUTH_CONTRACT_V1_2026-11-02.md](N1_NATIVE_AUTH_CONTRACT_V1_2026-11-02.md); es una propuesta, no una API operativa.
- El módulo `lib/api/native_api_transport.dart` contiene exclusivamente una base de transporte HTTPS con token inyectado por un futuro controlador seguro. Está **sin conectar a main.dart**, no genera, recibe, renueva ni conserva credenciales, y ningún endpoint Django emite tokens móviles.
- Controles: rechazo de credencial ausente/malformada, rutas API delimitadas, `followRedirects=false` para evitar fuga de Authorization, 401 distinto de 403, tipo JSON exigido y límite 1 MiB por respuesta. Pruebas añadidas en `test/native_api_transport_test.dart` y CI.
- **Estado del nuevo transporte: IMPLEMENTADO SIN VALIDAR LOCALMENTE**. Ejecutar `flutter analyze` y `flutter test test/native_api_transport_test.dart test/native_api_endpoint_test.dart test/android_web_access_screen_test.dart` antes de atribuir PASS.
- Pendiente esencial: seleccionar y aprobar contrato de identidad, MFA móvil, revocación, almacenamiento Keystore/Keychain, API Django y pruebas físicas iOS/Android.
- Permanece `N1_NATIVE_AUTH=NOT_IMPLEMENTED`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## N2 — Invalidation fence for delayed native HTTP responses (02/11/2026)

- Local operator reported `NATIVE_TRANSPORT_RESULT=0` for the preceding HTTPS transport + browser fallback suite. This confirms the **previous** revision, not the new session fence.
- New `NativeSessionFence` is deliberately in-memory and stores **no credential**. Each authenticated session generation receives a distinct ticket; revoking the session invalidates existing tickets synchronously, before any asynchronous cleanup.
- `NativeApiTransport` now requires an active fence. It checks the ticket before obtaining credentials, immediately before accepting the HTTP response, and again before returning decoded JSON. A 401 revokes its generation; 403 remains a permission error and does not silently log out.
- New tests verify: no credential read after revocation, rejection of a response arriving after logout, and rejection of an earlier account's 200 response after a new account generation starts.
- **CURRENT CHANGE NOT YET TESTED LOCALLY**; run `flutter analyze`, `flutter test test/native_api_transport_test.dart test/native_api_endpoint_test.dart test/android_web_access_screen_test.dart` and ideally the full Flutter suite. CI of current head not independently verified.
- This mechanism does not implement authentication, Keychain/Keystore, server revocation, MFA, or network cancellation. Remains disconnected from Android/iOS app entrypoints until those gates are independently verified; avoid treating an in-memory fence as credential storage.

## Regression audit — global Flutter test run (02/11/2026)
- Local operator: `NATIVE_SESSION_FENCE_RESULT=1`; global suite shows **285 passed, 1 failed** (`Today shows authorized due count from operational inbox`, `test/agenda_today_inbox_test.dart`). This run is **NOT PASS**; do not close N2 based on it.
- Independent source review found an ambiguous assertion `find.text('3'), findsOneWidget`. The agenda also renders the week strip with a day number 3. On 2026-11-02 (Monday), the displayed calendar week includes 2026-11-03, so the finder can match both the authorized inbox count (3) and calendar day (3). The full assertion failure lines were not available in the supplied log tail, so treat this as a **supported likely cause**, pending rerun.
- Commit `b8775d4` replaces the unscoped text finder with `tester.widget<Text>(find.byKey(ValueKey('agenda-due-count'))).data == '3'`. This verifies the intended count without depending on today's date.
- Required follow-up: isolated agenda test, then entire Flutter suite. Do not claim N2 session fence validated until full suite returns zero.

## N2 validado y N3 bóveda multiplataforma aislada (02/11/2026)
- El operador confirma `NATIVE_SESSION_FENCE_RECHECK=0` tras el ajuste del test de agenda dependiente del calendario: `flutter analyze`, test aislado de agenda y **batería Flutter completa** PASS en su copia local de la revisión previa. El anterior `NATIVE_SESSION_FENCE_RESULT=1` queda subsanado; no confundir con pruebas de Android/iOS físicos.
- N3 preparatorio: `lib/api/native_refresh_credential_vault.dart` define un puerto de secretos y un adaptador `FlutterSecureStorage`. Usa namespace independiente para credenciales móviles y separa dev/prod, sin reutilizar claves de avisos locales.
- Android: almacenamiento seguro de plugin con `resetOnError=false` y `migrateOnAlgorithmChange=false`. Sigue siendo necesaria una auditoría real en dispositivo sobre protección de respaldo/restauración y tratamiento de errores.
- iOS: Keychain `unlocked_this_device`, sincronización iCloud desactivada; **requiere prueba física de Keychain y de comportamiento ante reinstalación** (el Keychain puede sobrevivir a una desinstalación). El adaptador rechaza invocaciones en web y desktop.
- Guarda **solo una futura credencial refresh opaca**; no persistir contraseña, access token ni identidad. Rechaza formatos incorrectos, comprueba escrituras con lectura, verifica borrado y serializa lectura, rotación y borrado para evitar que una rotación tardía restaure la credencial después de logout.
- Tests unitarios con almacén falso (sin claves verdaderas) verifican ámbitos aislados, errores de almacenamiento, verificación de borrado y carrera de rotación/logout. CI ajustado. **Nueva batería N3 aún no ejecutada localmente.**
- **No está conectada a `main.dart`, al transporte ni al servidor.** Ni Django ni las apps disponen aún de emisión/validación de tokens nativos; no activar ni probar con datos reales. Antes de uso: seleccionar proveedor/contrato de identidad, integrar MFA/revocación, definir inicio seguro después de reinstalación y cerrar auditoría de plataforma.
- Gates MFA, C-FICHA y MB1 permanecen `RELEASE_AUTHORIZED=NO`; no deploy ni migraciones persistentes.

## N3 local PASS; N1 identity gate audit (02/11/2026)
- User-uploaded native-credential-vault.log: Flutter dependencies resolved; `flutter analyze` found no issues (13.7 seconds); complete `flutter test` ended `+293: All tests passed!` in ~54 seconds. This covers the code checked out for that run, not subsequent commits.
- Read-only security audit: Django MFA web middleware checks `request.user` before DRF can authenticate a new Bearer principal; token authentication cannot rely on it alone. A separate mobile-token identity predicate is required after successful token verification.
- Added `backend/reminders/native_mobile_identity_gate.py` as an UNCONNECTED internal predicate: checks active principal, current MFA epoch and administrative recovery blocks. It does not issue/parse/accept bearer tokens, is not registered in DRF, has no endpoint, and is NOT validated by the 293 Flutter tests. **Do not enable or consider it security-approved.** Backend tests and integration remain pending.
- Missing parts: trusted token validation/issuer, authenticated MFA claim issuance, revocation, credential store E2E, password-change invalidation, independent PG17 tests, and device validation on Android/iOS. Keep MFA, MB1, C-FICHA and deploy gates closed.

## N1-B — Contrato posvalidación de identidad, tests y fail-closed (02/11/2026)
- Se publicaron los tests `backend/reminders/test_native_mobile_identity_gate.py` para la función aislada `require_mobile_identity_gate`, cubriendo versión de credenciales obsoleta, MFA activa, versión MFA obsoleta, recuperación pendiente/histórica, fila MFA ausente, tipos inválidos y errores de base de datos. El workflow `m3-product-contracts.yml` los incluye en SQLite y PostgreSQL 17 temporal.
- El vínculo a credenciales usa `mobile_credential_version(user)`, HMAC con salt móvil separado, y comparación constante. **No exporta el hash de sesión de Django** a los tokens. Un cambio de contraseña debe invalidar la versión anterior del claim.
- La protección histórica de recuperación ahora deniega también ausencia de `UserMfaState` cuando existe un expediente previo, sin dar acceso por una fila MFA ausente.
- Además, un test del contrato web comprueba que un encabezado `Authorization: Bearer` arbitrario no autentica `/api/v1/me/` mientras REST Framework continúa usando SessionAuthentication.
- **VALIDACIÓN PENDIENTE**: no se ha ejecutado la nueva batería N1-B localmente, y no hay resultado concluyente CI para el head actual. Los anteriores 293 PASS son de Flutter, no de este cambio Django.
- No hay emisor/verificador de tokens nativos ni endpoint móvil; la función interna no es un mecanismo de login. `N1_AUTH_SERVER=NOT_IMPLEMENTED`; `MOBILE_API_ENABLED=NO`. Conservar todos los gates globales cerrados.
