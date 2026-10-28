# VENCIRA — B06A: captura consistente

## Implementado

Control experimental que compara:

- Marcador de captura anterior.
- Marcador de captura posterior.
- Inventario atribuido a PostgreSQL.
- Inventario de archivos cifrados.
- Huellas SHA-256 de cada objeto.

El control rechaza cambios de epoch, snapshot,
inventario, objetos ausentes o elementos adicionales.

## Limitación fundamental

Los marcadores son entradas proporcionadas por el
coordinador. Un marcador idéntico antes y después
NO demuestra que no haya habido escrituras.

Para una garantía operativa se necesitará:

1. Barrera de escritura compartida por todos los
   procesos que modifican metadatos, objetos y diario.
2. Captura de PostgreSQL bajo condiciones definidas.
3. Captura de archivos y diario mientras la barrera
   siga activa.
4. Persistencia verificable del identificador de captura.
5. Restauración, conciliación y liberación de barrera.
6. Ensayos de concurrencia, fallos y recuperación.

No conectar a la base persistente ni a O5 sin
revisión y autorización expresa.

B06A_CAPTURE_CONTROL=EXPERIMENTAL
B06A_OPERATIONAL_RELEASE=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
