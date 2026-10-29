# VENCIRA — B09C/D: restauración vinculada y custodia

## B09C — Integración experimental

La recuperación exige, en este orden:

1. Autenticación HMAC del manifiesto completo.
2. Identidad coincidente del respaldo PostgreSQL y paquete
   de adjuntos.
3. Verificación del volcado descifrado contra SHA-256 externo.
4. Verificación del paquete de archivos, bytes originales,
   diario y metadatos suministrados externamente.
5. Resultado siempre con release_authorized=false.

Los bytes de base de datos se devuelven en memoria.
No hay ejecución de pg_restore ni escritura en disco
en este componente. B08B/C ya ensayó pg_restore por separado;
el conjunto completo todavía requiere un ensayo end-to-end
que aplique B09C al mismo volcado restaurado.

## B09D — Custodia externa: contrato pendiente

Material diferenciado:
- Clave de cifrado del volcado PostgreSQL.
- Clave del paquete de adjuntos.
- Clave de cifrado del contenido de adjuntos.
- Clave HMAC para autenticación del manifiesto.
- Catálogo autenticado con identidades y digests esperados.

Requisitos antes de producción:
- Claves generadas mediante CSPRNG y custodiadas fuera del VPS.
- Acceso independiente y auditado para recuperación.
- Procedimiento de recuperación en caso de pérdida total del VPS.
- Versionado y rotación, sin destruir claves aún necesarias.
- Prueba de recuperación con pérdida simulada de la clave activa.
- Separación de permisos entre operador de respaldo y custodio.
- Autenticidad del catálogo externo y protección anti-rollback.
- Política de retención probada antes de permitir cualquier borrado.

No incluir claves en Git, logs, tickets, chat, backups o
capturas. No reutilizar las claves de Restic/O5 ni MFA.

## Bloqueadores

El HMAC prueba autenticidad respecto de una clave custodiada,
pero NO demuestra frescura, ausencia de rollback ni
consistencia temporal entre sistemas.

El módulo B08A mantiene un límite de 32 MiB y no permite
streaming de volúmenes reales. La custodia externa,
orquestación operativa y restauración completa de B09C
no están implementadas.

No configurar servicios de backup ni tocar O5 hasta
revisión y aprobación específica.

B09C_EXPERIMENTAL_RECONCILIATION=YES
B09D_EXTERNAL_CUSTODY_IMPLEMENTED=NO
B09_OPERATIONAL_RELEASE=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
