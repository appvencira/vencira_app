# N1 — Diseño ejecutable de autenticación nativa propia Android/iOS

Fecha: 2026-11-02  
Estado: DISEÑO DE IMPLEMENTACIÓN / PRUEBAS DE PRIMITIVAS; NO ACTIVADO

## Objetivo innegociable
La aplicación Flutter debe mostrar login nativo y operar de forma nativa contra la API Django vía HTTPS. **No redirigir a Chrome ni Safari** para gestionar pólizas ni iniciar sesión. La sesión web Django con cookie+CSRF no se sustituye ni se rebaja. El APK que abre la web es una medida provisional, no la solución.

## Ruta de implementación propuesta (aún no autorizada para producción)

Se adopta como línea de desarrollo una **identidad de primera parte** (cuentas Django existentes + segundo factor TOTP si está activo) para evitar proveedor OIDC externo/navegador. Requiere auditoría y gate de liberación antes de exponer endpoints. No confundir este diseño con autenticación ya implementada.

1. En una futura ruta móvil propia, validar forma/tamaño del JSON, HTTPS, credenciales y límites por IP/cuenta antes del intento de login. Usar las funciones de limitación de login ya existentes con protección añadida contra abuso por IP/proxy. No registrar contraseña, OTP, token ni contenido sensible.
2. `django.contrib.auth.authenticate()` comprueba la contraseña. Si MFA está habilitado, **no emitir credenciales todavía**: emitir únicamente un reto de duración breve de un solo uso, ligado a un identificador opaco almacenado en servidor. Tras consumir TOTP con `consume_totp()` y confirmar que no existe recuperación administrativa bloqueante, pasar al siguiente paso. El código de recuperación requiere política y revocación equivalentes a la versión web. Fallos deben ser genéricos.
3. Generar valores de acceso (`a`) y renovación (`r`) independientes de 256 bits con `native_mobile_token_primitives.py`. Las credenciales tienen formato `v1.<tipo>.<uuid-aleatorio>.<secreto-aleatorio>`. **El UUID no autentica**; la prueba exige comparar el digest HMAC-SHA256 almacenado de la credencial completa.
4. Una futura tabla de sesiones móviles por dispositivo (no creada aún) debe almacenar **solo digest del token**, expiración, usuario, versión de credenciales, epoch MFA, revocación, identificador de familia y generación de renovación. Nunca almacenar valores de token en claro. Sesiones y retos requieren migraciones independientes revisadas exclusivamente en bases de datos de prueba antes de migración operativa.
5. API protegida: autenticación DRF exclusiva por token móvil validado, carga del usuario real, `require_mobile_identity_gate()` después de identificar/verificar el token, y autorización por recurso/workspace en servidor. Mantener `SessionAuthentication` para web. No aceptar tokens móviles simplemente por identificador de sesión, cabeceras arbitrarias o claims enviados por el cliente.
6. Caducidad inicial recomendada para evaluación: acceso 5 minutos, refresh 30 días con rotación **de un solo uso**. Refresh con `transaction.atomic()` + `select_for_update()`, comprobación de expiración y hash. Repetir refresh ya utilizado exige revocar toda su familia/dispositivo; no generar tokens al detectar replay. Concurrencia entre workers, caídas tras commit y pérdida de respuesta requieren protocolo de recuperación explícito.
7. Cierre de sesión revoca la familia servidor. Cliente invalida su `NativeSessionFence` sincrónicamente, cancela alarmas Android, borra Keychain/Keystore y limpia datos de pantalla. Un fallo de revocación/limpieza no puede aparentar éxito. Se deben comprobar cambios de cuenta y membresía workspace también en iOS.
8. Flag de servidor **desactivado por defecto**, con tests que demuestren que las rutas móviles no existen/deniegan mientras no se active. No habilitar en producción hasta MFA/custodia y otras gates.
9. Usar redireccionamientos prohibidos para las peticiones que llevan `Authorization`; el cliente ya lo controla. Almacenamiento de refresh protegido en el módulo Flutter N3, sin cookies web ni SharedPreferences.

## Límites y amenazas pendientes de resolver
- No hay sesiones, retos ni endpoints implementados en esta revisión.
- No hay tokens reales; las primitivas usan `SECRET_KEY` de Django con separación de dominio en HMAC. Antes de activar, definir gestión de claves, rotación y comportamiento de respaldos.
- Verificar seguridad de proxy para IP real y rate limiting distribuido; no fiarse de `X-Forwarded-For` arbitrario.
- Evitar conflictos CSRF/cookie: una ruta de login móvil no debe autenticar mediante cookies del navegador; comprobar `Origin`, `Sec-Fetch-Site` o una política equivalente bajo el modelo de amenazas concreto, y restringir respuestas cacheables.
- Definir esquema de tokens y volumen de consultas a DB, control de revocación global y políticas de contraseña/MFA.
- Exigir tests SQLite/PG17 temporal, tests de carrera transaccional en PG17 real, Flutter, Android/iOS físicos, network 4G/5G, dispositivo perdido y reinstalación.
- No desplegar ni migrar PostgreSQL persistente. `MFA_RELEASE_AUTHORIZED=NO`, `MB1_RELEASE_AUTHORIZED=NO`, `C_FICHA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## Estado 02/11
- `N1_IDENTITY_SQLITE_ORM=PASS_25`.
- `N1_IDENTITY_PG17_ORM=PASS_25`.
- `N1_OPAQUE_TOKEN_PRIMITIVES=IMPLEMENTED_TEST_PENDING`.
- `N1_NATIVE_LOGIN=NOT_IMPLEMENTED`.
- `N1_NATIVE_SESSIONS=NOT_IMPLEMENTED`.
- `N1_MOBILE_ENDPOINTS=DISABLED`.
