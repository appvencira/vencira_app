# VENCIRA — B06B/C: barrera cooperativa experimental

## Implementación

Se ha incorporado un bloqueo advisory de PostgreSQL 17:

- Captura: bloqueo exclusivo.
- Escritor cooperativo: bloqueo compartido.
- Tiempo máximo de espera.
- Liberación en bloque finally.
- Rechazo fuera del entorno de ensayo.

## Validaciones

Se prueban conexiones independientes, bloqueo de escritores,
bloqueo de capturas, timeout, liberación tras errores y
conciliación de un inventario leído en PostgreSQL 17.

## Límites

Este contrato NO impide escrituras reales porque los procesos
actuales todavía no adquieren estos bloqueos.

Tampoco protege por sí solo los archivos ni el diario.
Todas las rutas de escritura tendrán que adquirir el bloqueo
compartido, con orden de adquisición documentado.

La captura deberá usar el exclusivo, coordinado con
pg_dump y la copia de objetos y diario. Será necesario
probar interrupciones, caída de procesos y recuperación.

Los advisory locks no proporcionan por sí solos una
instantánea atómica entre PostgreSQL y el sistema de archivos.
La consistencia depende de que todos los escritores cooperen.

No habilitar la barrera en producción ni cambiar O5
sin revisión y autorización expresa.

B06BC_PG17_EXPERIMENTAL=YES
B06BC_OPERATIONAL_RELEASE=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
