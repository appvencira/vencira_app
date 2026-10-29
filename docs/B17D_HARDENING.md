# B17D — Endurecimiento integral

## Resultado de validación

Pruebas completadas correctamente sobre PostgreSQL 17
temporal y contenedores Docker independientes.

### Seguridad de claves
- Firmante sin credenciales PostgreSQL: OK.
- Clave revocada: rechazada.
- Clave caducada: rechazada.
- Clave aún no válida: rechazada.
- Clave desconocida: rechazada.

### Seguridad HTTP
- Ruta desconocida: rechazada.
- Content-Type incorrecto: rechazado.
- JSON inválido: rechazado.
- Cuerpo excesivo: rechazado.
- Sobre inválido: rechazado.
- HMAC incorrecto: rechazado.
- Evidencia manipulada: rechazada.
- Firma falsificada: rechazada.
- Repetición y evidencia duplicada: rechazadas.

### Persistencia
- Rollback atómico de evidencia y nonce: OK.
- Recepción válida: OK.
- Un único registro de evidencia y nonce: OK.
- Conservación de cuarentena: OK.
- Django exit code: 0.

## Limitaciones

Validación exclusivamente sintética.
No autoriza el uso de adjuntos reales.
No acredita custodia externa real, TLS ni
autorización operacional de MFA.

B17D_TEST_GATE=OK
B17_OPERATIONAL_RELEASE=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
