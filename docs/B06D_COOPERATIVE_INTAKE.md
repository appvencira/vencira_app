# VENCIRA — B06D: escritura cooperativa

El flujo experimental `stage_authorized_attachment()`
adquiere un bloqueo compartido antes de ejecutar:

1. Registro de intención.
2. Escritura cifrada en cuarentena.
3. Creación transaccional de metadatos.
4. Limpieza en caso de fallo de metadatos.

La captura experimental utiliza el bloqueo exclusivo
definido en B06B.

## Garantías y limitaciones

El bloqueo abarca el ciclo de entrada experimental,
pero no cubre todavía otros escritores, rechazos,
trabajadores, eliminación ni cambios externos.

No existe todavía un coordinador operativo que mantenga
el bloqueo exclusivo durante pg_dump y copia de archivos.

Los bloqueos son cooperativos y de sesión: requieren que
todos los escritores pertinentes participen.

No autoriza operaciones HTTP, despliegues ni almacenamiento
de documentos reales.

B06D_COOPERATIVE_INTAKE=EXPERIMENTAL
B06D_OPERATIONAL_RELEASE=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
