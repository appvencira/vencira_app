# B15F — Receptor atómico, ensayo PG17

Ensayo exclusivo con datos sintéticos.

Comprueba la unión transaccional entre:
- autenticación HMAC del sobre;
- registro antirrepetición PostgreSQL;
- registro de confianza Ed25519 B13D;
- persistencia de evidencia B13E.

Pruebas negativas: duplicación, manipulación, firmante
incorrecto, clave revocada, clave caducada y rollback.

Límites:
- tabla de ensayo creada únicamente en la BD temporal;
- receptor implementado como arnés de pruebas, no como
  endpoint de producción;
- clave HMAC y Ed25519 sintéticas;
- sin custodia externa real;
- sin autorización de descarga de documentos;
- sin migraciones persistentes.

B15_OPERATIONAL_RELEASE=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
