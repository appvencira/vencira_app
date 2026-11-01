# VENCIRA — G1 revisión semántica parcial del límite de adjuntos (01/11/2026)

## Fuentes examinadas en GitHub
- `backend/reminders/attachment_api.py`
- `backend/reminders/attachment_gate.py`
- `backend/reminders/attachment_private_store.py`
- `backend/renewal_attachments/transition_reconciliation.py`

## Hallazgos concretos
1. **Endpoints HTTP de adjuntos:** `renewal_attachments` permite GET de metadatos y devuelve 403 para POST. `renewal_attachment_detail` devuelve 403 para GET y DELETE después de comprobar pertenencia/visibilidad. El listado limita resultados a 50 y expone capacidades deshabilitadas. La afirmación se limita a estos handlers y no prueba cobertura universal de URLs/middleware u otras rutas de ejecución.
2. **Descarga:** `may_download_attachment` devuelve siempre `False`, sin depender del campo `state`. No acredita que otro código no pueda acceder al almacén directamente.
3. **Almacén privado:** `put_quarantine` cifra con Fernet y crea un objeto con `O_EXCL`, permisos 0600 y `fsync` de fichero/directorio. `discard_quarantine` elimina físicamente un objeto y llama a `fsync` del directorio. Es una **capacidad real de modificación filesystem en el código**, aunque el módulo indica que no está conectado a producción. La comprobación de pertenencia a BD antes de eliminar se delega al llamador, no se impone en `discard_quarantine`; auditar todos los llamadores.
4. **Reconciliación:** `inspect_reconciliation` obtiene metadatos en una transacción Django y compara inventarios. No escribe en los métodos inspeccionados, pero `READ COMMITTED` no garantiza corte consistente bajo escritores concurrentes y no verifica objetos cifrados. No usar como criterio de freeze.

## Pendientes de validación
- Censo de referencias e imports reales de `PrivateQuarantineStore`, `put_quarantine`, `discard_quarantine` y `read_quarantine_for_scanner_only`, incluidos scripts externos y rutas fuera de `backend`.
- Evidencia de rutas URL/handlers efectivamente desplegados y permisos de filesystem del entorno, sin modificar DEV.
- Comprobación de permisos SQL no elevados y exclusión de escritores administrativos.
- Auditoría de lifecycle: objeto cifrado, diario y PG17 deben permanecer coherentes ante errores/ACK incierto; los ensayos sintéticos anteriores no sustituyen esta cobertura operativa.

## Conclusión
**Revisión semántica parcial de cuatro módulos, no del conjunto de los 146 callsites.** La API HTTP inspeccionada permanece fail-closed para operaciones de adjuntos, pero el método de descarte privado posee capacidad destructiva interna y requiere trazabilidad de llamadores. No se acredita ausencia de bypass SQL/FS, ni inventario G1 completo.

MB1_GLOBAL_FREEZE=NOT_VERIFIED
MB1_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
