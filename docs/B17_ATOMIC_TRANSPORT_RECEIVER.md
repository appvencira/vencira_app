# B17A — Receptor transaccional reutilizable

Contrato de ensayo basado en B15F:
- autenticación HMAC del mensaje;
- verificación Ed25519 v3 contra registro B13D;
- validación de identidad, vigencia y revocación;
- control de metadatos de adjuntos;
- antirrepetición y evidencia en la misma transacción;
- adquisición de barrera B06B antes de transaction.atomic;
- rechazo de duplicados y rollback completo.

La tabla b17_replay solo se crea durante las pruebas
sobre PostgreSQL 17 temporal.

Límites:
- No hay endpoint HTTP conectado al módulo.
- No hay migración operacional para b17_replay.
- No se ha probado todavía el flujo B16 HTTP -> B17 Django.
- El módulo permanece bloqueado fuera del entorno de prueba.
- No existe custodia externa real de claves.
- Sin autorización de lectura, descarga ni subida.

B17_OPERATIONAL_RELEASE=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
