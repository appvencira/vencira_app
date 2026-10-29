# B17B — HTTP local y recepción transaccional

Ensayo con PostgreSQL 17 temporal y datos sintéticos.

El receptor HTTP de prueba escucha exclusivamente en
127.0.0.1 dentro del contenedor de ensayo.

Las peticiones pasan al contrato B17A, que combina:
- HMAC del transporte.
- Registro público de confianza Ed25519.
- Rechazo de claves revocadas o caducadas.
- Comprobación de metadatos del adjunto.
- Bloqueo cooperativo B06B.
- Transacción de evidencia y nonce.
- Reversión íntegra ante fallos.

Pruebas HTTP específicas:
- Primera recepción aceptada y duplicado rechazado.
- HMAC incorrecto sin escritura.
- Evidencia manipulada sin escritura.
- Error transaccional y reintento correcto.

Limitaciones:
- HTTP local, no extremo a extremo entre contenedores.
- No hay TLS ni custodia externa de claves.
- No hay endpoint habilitado en la aplicación.
- No hay migraciones persistentes.
- La tabla antirrepetición es exclusiva de los tests.
- No se habilitan descargas ni subida de adjuntos.

B17_OPERATIONAL_RELEASE=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
