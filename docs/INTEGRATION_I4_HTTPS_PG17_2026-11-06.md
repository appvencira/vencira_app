# I4 — Laboratorio HTTPS de mismo origen con PostgreSQL 17 efímero

Fecha: 2026-11-06

## Qué se ejecuta
GitHub Actions compila Flutter Web real desde `main`, crea PostgreSQL 17 **desechable**, ejecuta las migraciones **únicamente en esa instancia de CI**, siembra dos workspaces y usuarios totalmente sintéticos, levanta Django en `127.0.0.1:18731` y un proxy HTTPS de laboratorio en `127.0.0.1:18732`.

El proxy sirve `flutter_bootstrap.js` y `index.html` del Flutter compilado, e incluye `/api/`, `/accounts/` y `/admin/` bajo el mismo origen. Django recibe `X-Forwarded-Proto=https` desde ese proxy de loopback, con cookies de sesión y CSRF marcadas Secure. El certificado TLS de un día se genera durante el job y la prueba confía únicamente en su CA de laboratorio, verificando el nombre `localhost`; no hay despliegue ni ningún certificado público.

## Pruebas wire-level
El cliente de pruebas Python stdlib atraviesa TLS real, proxy y Django hacia PostgreSQL17; comprueba:
- Disponibilidad de `/api/health/`, `/api/ready/`, Flutter index + bootstrap;
- anonimato denegado, formulario de login, token CSRF y cookie Secure;
- login Django con usuario sintético, cookie de sesión Secure y `/api/v1/me/`;
- alcance de workspace, listado/ficha de vencimiento y agenda de día;
- denegación 404 para workspace ajeno;
- metadatos de adjuntos sin capacidades de subida/descarga/borrado, POST bloqueado;
- logout POST con CSRF y posterior denegación de sesión.

## Límites y precauciones
**No es una prueba visual de navegador**: el JS de Flutter se compila y sirve correctamente, pero los test HTTP no ejecutan Dart en un navegador. Tampoco es un ensayo de HTTPS de acceso público ni Android APK. Las pruebas E2E de UI, recuperación de MFA y custodia de adjuntos siguen pendientes de autorizar por sus propios gates. No se aplica ninguna migración a la BD del VPS.

El seed contiene guardas obligatorias `VENCIRA_ENV=test`, `I4_DISPOSABLE_DATABASE=YES`, `POSTGRES_DB=vencira_i4_ci`, `POSTGRES_HOST=127.0.0.1` y flags de laboratorios desactivados. Las credenciales CI son claramente ficticias y carecen de uso en producción. La conexión Django y el proxy solo escuchan en loopback del runner. El proxy Python existe exclusivamente para esta prueba: nunca debe utilizarse en producción.

## Resultado
Inicialmente `I4_CI_RESULT=PENDING`. La PR permanece en borrador hasta tener un workflow `success` para el HEAD y revisar los fallos.

`NO_DEPLOY_NO_LIVE_MIGRATION=1`
`MFA_RELEASE_AUTHORIZED=NO`
`C_FICHA_RELEASE_AUTHORIZED=NO`
`MB1_RELEASE_AUTHORIZED=NO`
