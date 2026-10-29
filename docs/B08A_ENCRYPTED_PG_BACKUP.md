# VENCIRA — B08A: cifrado de respaldo PostgreSQL

## Implementado

Contrato experimental para cifrar y verificar
bytes de un pg_dump utilizando Fernet.

El paquete incluye:
- Versión de esquema.
- Identificador de clave.
- Identificador de captura.
- SHA-256 del dump.
- Dump cifrado y autenticado.

La apertura verifica además una huella externa
que no debe obtenerse del propio paquete.

## Restricciones

La clave nunca se incorpora al paquete.

Este módulo no proporciona custodia externa de
claves, captura atómica ni persistencia de backups.

El límite de 32 MiB es un límite de ensayo, no una
solución de streaming para bases operativas grandes.

El hash externo necesita proceder de un inventario
auténtico y protegido contra sustitución.

No se emplean datos reales, O5 ni PostgreSQL DEV.

## Siguiente fase

B08B: aplicar el cifrado al pg_dump/pg_restore
en dos PG17 desechables y probar claves separadas.

B08A_OPERATIONAL_RELEASE=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
