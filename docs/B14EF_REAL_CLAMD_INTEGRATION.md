# B14E + B14F — Ensayo real ClamAV / Ed25519 / PG17

Integración con datos sintéticos:
- clamd real, socket Unix 660.
- Identidad no privilegiada para clamd y cliente.
- Cuarentena Fernet, SHA-256 y validación estructural.
- Solo resultado CLEAN genera evidencia Ed25519 v3.
- Firma verificada antes de persistir en PG17 temporal.
- EICAR, socket ausente y metadatos incorrectos bloqueados.
- Persistencia duplicada rechazada.
- Cuarentena preservada; descargas denegadas.

Limitaciones:
- Clave privada sintética creada dentro del proceso
  de prueba, no custodia externa real.
- Todavía no hay canal operacional autenticado.
- No demuestra separación completa del backend Django.
- Socket y ejecución son únicamente de ensayo.
- No se habilita el servicio de adjuntos.
- MFA y autorizaciones operacionales siguen pendientes.

B14_OPERATIONAL_RELEASE=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
