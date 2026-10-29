# VENCIRA — B06E: rechazo y descarte cooperativos

El rechazo experimental y los reintentos de descarte
participan en el advisory lock compartido PostgreSQL.

Se preservan:
- El cambio transaccional a estado rechazado.
- El outbox persistente de descarte.
- El bloqueo select_for_update para workers concurrentes.
- La eliminación posterior al commit del rechazo.
- La prohibición de descargar documentos.

El rechazo puede llamar al reintento mientras mantiene
el bloqueo compartido de sesión. PostgreSQL permite
adquirir nuevamente un bloqueo compartido en la misma
sesión y exige liberar cada adquisición.

## Pendiente

La cobertura no incluye todavía todos los escritores
de evidencia de escaneo y recuperación, ni cambios
externos sobre el almacén de archivos.

No existe captura operativa coordinada ni backup
de documentos en O5.

B06E_REJECTION_BARRIER=EXPERIMENTAL
B06E_OPERATIONAL_RELEASE=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
