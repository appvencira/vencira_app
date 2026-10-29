# VENCIRA — B09A/B: manifiesto y retención

## Componente implementado

Un manifiesto autenticado mediante HMAC-SHA256 que vincula:

- Paquete cifrado PostgreSQL.
- Paquete cifrado de adjuntos y diario.
- Identificador de captura.
- Identificadores de versión de claves.
- Huellas SHA-256 de ambos paquetes.

La verificación exige una clave independiente.
El manifiesto no puede demostrar consistencia temporal:
esa garantía requiere un coordinador de captura real.

## Retención

El módulo genera exclusivamente un plan de revisión.
No elimina archivos ni autoriza borrados.

- Conserva como mínimo dos copias verificadas y recuperables.
- Si faltan copias recuperables, no propone eliminaciones.
- Conserva copias corruptas para revisión.
- No interfiere con la retención de O5.

## Límites de B09

Es un contrato experimental, no un servicio de backup:

- No existe custodia externa de claves.
- No existe captura operacional atómica.
- No se configura Drive, Restic, systemd ni cron.
- No hay supervisión programada ni alertas.
- Los tamaños y el cifrado no están diseñados para
  archivos de producción de tamaño arbitrario.
- No se autoriza tratamiento de documentos reales.

## Siguiente integración

B09C: vincular este manifiesto a la restauración
cifrada PostgreSQL 17 de ensayo y comprobar rechazo
de conjuntos mezclados.

B09D: definir custodia externa y operativa de
backup independiente de O5, con aprobación previa.

B09_OPERATIONAL_RELEASE=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
