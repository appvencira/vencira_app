# VENCIRA B09E — recuperación autenticada integral

## Verificación realizada

- PostgreSQL 17 de origen y destino independientes.
- Esquema Django independiente de adjuntos.
- Fixture sintético B07.
- pg_dump real de ensayo.
- Cifrado B08A.
- Paquete de adjuntos con mismo snapshot_id.
- Manifiesto HMAC B09A.
- Verificación integral B09C antes de pg_restore.
- Restauración en segundo PostgreSQL 17.
- Conciliación ORM, bytes originales y diario.
- Rechazo de paquetes mezclados y clave HMAC incorrecta.

## Límites

El catálogo y las claves son externos al paquete en el
ensayo, pero están en el mismo VPS temporal. No equivalen
a custodia externa ni a protección anti-rollback.

No hay captura atómica transaccional entre archivos y BD.
Se usa un origen temporal sin otros escritores durante
el ensayo. No existe automatización de backup operativo.

El dump original se crea temporalmente en claro antes
del cifrado y se elimina después. No usar con datos reales.
No existe garantía de borrado físico.

La verificación del manifiesto precede a pg_restore.
No se modifica O5, DEV ni PostgreSQL persistente.

B09E_INTEGRAL_GATE=EXPERIMENTAL
B09E_OPERATIONAL_RELEASE=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
