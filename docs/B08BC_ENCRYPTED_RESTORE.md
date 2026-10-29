# VENCIRA — B08B/C: restauración cifrada y claves separadas

## Ensayo

1. Dos PostgreSQL 17 temporales.
2. Migraciones Django del esquema independiente en origen.
3. Datos sintéticos B07.
4. `pg_dump -Fc` de la base de ensayo.
5. Cifrado del volcado con B08A.
6. Custodia local temporal de claves separada del paquete.
7. Eliminación del volcado temporal antes de la restauración.
8. Descifrado en memoria y transmisión a `pg_restore`.
9. Comprobación ORM y conciliación de adjuntos/diario.
10. Pruebas negativas de claves, versión, captura e integridad.

## Límites importantes

- La custodia es **separación local temporal**, no custodia
  externa real ni recuperación ante pérdida del servidor.
- El modelo de cifrado B08A carga hasta 32 MiB en memoria.
- El volcado inicial existe brevemente sin cifrar en disco
  temporal. No debe usarse con datos personales reales.
- La eliminación de ese archivo no garantiza borrado físico.
- El ensayo B07 no proporciona una captura atómica real.
- El manifiesto externo sigue siendo sintético.
- No se modifica el backup O5 existente.
- No se habilitan operaciones HTTP ni documentos reales.

## Pendiente

B09: arquitectura de respaldo operativo con captura
consistente y custodia externa de claves. No desplegarla
sin revisión y aprobación.

B08BC_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
