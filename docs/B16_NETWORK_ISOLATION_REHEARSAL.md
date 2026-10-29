# B16 — Ensayo de aislamiento y transporte de evidencias

## Evidencia validada

B16A-C:
- Imágenes independientes de firmante y verificador.
- Verificación mediante clave pública Ed25519.
- Rechazo de firmas y evidencias manipuladas.

B16D:
- Comunicación HTTP en red Docker interna y temporal.
- Autenticación HMAC-SHA256.
- Firma Ed25519 independiente.
- Antirrepetición con PostgreSQL 17 temporal.
- Rechazo de mensajes repetidos, caducados y manipulados.
- Contenedores de ensayo no privilegiados.

## Limitaciones

- No hay TLS ni autenticación operacional de servicios.
- Las claves del ensayo son sintéticas.
- No está validada la custodia externa.
- No hay integración del receptor de red con B15F.
- No se ha validado revocación operacional del firmante.
- No hay autorización de descarga ni subida de documentos.
- No se modifica ninguna base de datos persistente.

B16_OPERATIONAL_RELEASE=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
