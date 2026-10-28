# VENCIRA — B05E: conciliación ORM PostgreSQL 17

## Alcance del ensayo

Se utiliza el modelo independiente RenewalAttachment y
sus campos reales de metadatos, con PostgreSQL 17 temporal.

La comprobación cruza:
- identificador storage_key;
- SHA-256 del documento original;
- tamaño del documento original;
- inventario de bytes cifrados;
- diario de intención;
- versiones e identificador de captura.

Todas las entradas son sintéticas.

## Limitaciones importantes

B05E no restaura la BD completa desde pg_dump: ese
procedimiento fue probado separadamente en B05D.

B05E no garantiza todavía una instantánea atómica de
PostgreSQL y del almacenamiento privado. El inventario
de huellas del ciphertext sigue siendo generado en el
ensayo, no capturado desde un servicio operativo.

No se autoriza:
- desplegar migraciones;
- habilitar subidas o descargas;
- almacenar documentos reales;
- modificar O5;
- reutilizar claves de MFA o Restic.

Antes de producción se requiere orquestación de captura
consistente, restauración con esquema real, custodia
externa, actualización de firmas ClamAV y revisión RGPD.

B05E_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
