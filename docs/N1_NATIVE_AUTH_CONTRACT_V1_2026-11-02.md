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

## N1-B — Predicado de identidad posverificación (02/11/2026)
- Módulo aislado: `backend/reminders/native_mobile_identity_gate.py`. NO añadido a DRF ni a ninguna URL; no comprueba firmas, no emite tokens y NO autoriza nuevas sesiones.
- Requiere un usuario activo y autenticado cuya clave primaria sea válida, y tres afirmaciones de un **token ya validado criptográficamente**: MFA verificada (bool estricto), epoch MFA y versión de credenciales separada por dominio mediante `salted_hmac('vencira.mobile.credential-version.v1', user.get_session_auth_hash())`. **Nunca se entrega el hash de sesión Django como un claim**. La versión móvil se compara con `constant_time_compare` para invalidar credenciales móviles previas tras cambiar contraseña.
- Cada solicitud reevalúa el estado MFA de BD y el expediente de recuperación. Rechaza epoch antiguo, MFA obligatoria no verificada, recuperación pendiente, historial de recuperación con MFA desactivada o fila MFA ausente, y fallos de lectura del estado. Requiere denegar sin distinguir al usuario cuál condición falló.
- Pruebas sintéticas sin acceso a BD en `reminders.test_native_mobile_identity_gate`: cuenta sin MFA, MFA activa con epoch correcto/incorrecto, modificación de contraseña, recuperación pendiente/histórica, fila MFA ausente, usuario inactivo, tipos de claim inválidos y fallo de consulta. Integradas en los jobs SQLite y PG17 efímero del workflow M3.
- **Pruebas aún pendientes de ejecución local**, no inferir PASS. Como las pruebas simulan ORM, esto valida la función, no prueba concurrencia ni esquema PG17; añadir posteriormente ensayos reales de BD temporal y condiciones de carrera.
- Riesgo explícito: esta función NO verifica que los argumentos provengan de un token auténtico. Nunca exponerla a una petición que pase claims suministrados por el cliente sin verificar. La adopción futura debe formar parte de una clase de autenticación DRF revisada, después de verificar firma, issuer, audience, expiración, jti y revocación; el middleware de sesión web no ve la identidad Bearer.
- La estrategia de autorización inicial (OIDC/PKCE o inicio de sesión propio con MFA y controles equivalentes) continúa sin decisión definitiva; NO seleccionar proveedores ni crear endpoints funcionales por suposición. Mantener origen HTTPS y autenticación compartida Android/iOS.
- Gates: `N1_MOBILE_BEARER_ENABLED=NO`, `N1_TEST_RESULT=PENDING`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

- Revisión de seguridad posterior: el token móvil futuro no debe incluir `user.get_session_auth_hash()` en bruto. La función `mobile_credential_version(user)` devuelve un HMAC específico del dominio móvil; también queda pendiente separar claves de firma de tokens y políticas de rotación del proveedor autorizado. La firma, auditoría y revocación de tokens NO están implementadas.
