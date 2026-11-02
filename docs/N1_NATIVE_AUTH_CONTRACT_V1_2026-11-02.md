# N1 — Contrato de autenticación móvil nativa VENCIRA (Android e iOS)
Fecha: 2026-11-02 · Estado: PROPUESTA DE CONTRATO, SIN ENDPOINTS ACTIVOS

## Resultado exigido
Flutter Android e iOS deben conectarse directamente a la API Django mediante HTTPS, iniciar sesión de forma nativa y mantener/revocar su sesión sin utilizar Chrome o Safari. La app web conserva la sesión Django y CSRF. Abrir la web desde el APK solo es una alternativa temporal, NO aceptación de N1–N4.

## Decisiones que deben aprobarse antes de código operativo
- Contrato recomendado para evaluación: autorización externa estándar OIDC Authorization Code + PKCE (S256) con navegador del sistema **solo para la autorización**, retorno verificado al cliente, y consumo nativo posterior de la API. Si el requisito prohíbe incluso un navegador para la autorización, se necesita evaluar una alternativa de identidad específica y sus amenazas antes de implementarla. No usar contraseñas intercambiadas directamente por un endpoint improvisado.
- El proveedor de identidad, el tipo de cliente público, los endpoints de autorización/token/revocación y los identificadores de audiencia **no están seleccionados**. No publicar rutas ficticias ni asumir soporte OIDC de Django.
- El backend debe aceptar solo tokens vinculados a un emisor/audiencia y algoritmos permitidos, con validación de expiración, estado del usuario, MFA y revocación. Definir cómo se representa el requisito MFA en el token y su invalidación ante cambios de factor, bloqueo o recuperación administrativa.
- Los permisos comerciales se evalúan por cada operación y workspace en el servidor, nunca únicamente por el token.
- Acceso de corta duración, renovación rotatoria con detección de reutilización, revocación por dispositivo y global; considerar carreras de renovación concurrente, pérdida de móvil, desconexiones y reinicios.
- No almacenar secretos de cliente público en código como si fueran credenciales. Credenciales de sesión en Android Keystore/iOS Keychain mediante capa específica; nunca en SharedPreferences, logs, crash reporting ni analytics.
- URLs HTTPS explícitas por entorno, validación TLS sin excepciones, redirecciones controladas, no permitir redirección de tokens a orígenes no autorizados.
- Revocación de alarmas nativas y borrado de datos antes de cambiar cuenta/workspace o habilitar nueva sesión. Un fallo de limpieza bloquea el avance (fail-closed).
- Web conserva CSRF/cookies; cliente móvil no copia cookies de navegador. No cambiar DEFAULT_AUTHENTICATION_CLASSES hasta que pruebas sobre PG17 aislado y autorización de seguridad estén completas.

## Contrato propuesto (a validar; no es API ya existente)
1. El cliente obtiene una autorización mediante PKCE con state y nonce, usando redirect URI registrada y comprobación estricta del retorno.
2. El cliente intercambia el código por credenciales con el proveedor autorizado. Tokens nunca aparecen en URLs de acceso a la API VENCIRA.
3. El cliente invoca la API con Authorization: Bearer, en HTTPS, con capa de autenticación independiente del navegador. El backend valida identidad, alcance, MFA, revocación y permisos por recurso.
4. La renovación es de una sola utilización por token rotatorio, con invalidación de familia ante replay. Se documenta un tratamiento explícito de carreras de requests.
5. El cierre de sesión revoca las credenciales activas, cancela alarmas previas, borra secretos locales y datos en pantalla; ante fallos de revocación remota no aparentar éxito.
6. La pérdida de membresía de workspace impide mostrar contenido de otro workspace hasta completar la limpieza de alarmas y datos, tanto en Android como en iOS.

## Matriz mínima de pruebas
- Sin token, token caducado, token de emisor/audiencia ajenos, token manipulado; permiso denegado; revocación y replay del refresh.
- MFA ausente/incompleto, MFA con recuperación pendiente, epoch cambiado y cuenta desactivada.
- Rutas públicas bajo CSRF web preservadas y protegidas de downgrade.
- Logout, doble refresh concurrente, reinstalación, cambio cuenta/workspace y pérdida de membresía.
- Wi-Fi y 4G/5G, fallo DNS/TLS, suspensión/reanudación, datos tardíos y limpieza fallida.
- Tests Flutter Android/iOS y Django sobre SQLite + PostgreSQL 17 efímeros; pruebas físicas separadas en Android e iPhone.

## Gates
N1_CONTRACT=PROPOSED; N1_MOBILE_ENDPOINTS=DISABLED; N1_NATIVE_AUTH=NOT_IMPLEMENTED.
MFA_RELEASE_AUTHORIZED=NO; C_FICHA_RELEASE_AUTHORIZED=NO; MB1_RELEASE_AUTHORIZED=NO; NO_DEPLOY_NO_LIVE_MIGRATION=1.

## Dependencias y decisiones pendientes
Elegir proveedor/arquitectura de identidad, confirmar la experiencia de autorización que se acepta en iOS y Android, revisar el aislamiento de sesiones MFA actuales frente a tokens móviles, y resolver custodia real antes de activar producción.
