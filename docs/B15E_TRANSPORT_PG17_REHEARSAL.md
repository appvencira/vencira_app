# B15E — Transporte autenticado, Ed25519 y PG17

## Alcance

Ensayo aislado con datos sintéticos.

- HMAC-SHA256 para autenticar el sobre de transporte.
- Ed25519 para verificar la evidencia.
- PostgreSQL 17 temporal para registrar identificadores.
- Rechazo de repeticiones, incluidos intentos concurrentes.
- Rechazo de claves, firmas y mensajes manipulados.
- Rechazo de mensajes caducados o futuros.
- Sin acceso ni liberación de documentos.

## Limitaciones

El código versionado es un ensayo, no un receptor
HTTP operativo.

La clave HMAC y la clave Ed25519 son sintéticas.
No se ha demostrado custodia externa.

La base temporal se destruye al terminar el ensayo.
No existe migración del receptor a producción.

El contrato de transporte todavía no está integrado
con el registro de confianza y la persistencia real
de evidencias de adjuntos.

No se ha validado autenticación de extremo a extremo
entre dos servicios operacionales separados.

## Autorizaciones

B15_OPERATIONAL_RELEASE=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
