# VENCIRA — Macrofase C: revisión de publicación y continuidad

Actualización: 2026-10-28. Rama: `feature/c-ficha-independent-attachments`.
Último commit de código validado antes de esta actualización documental: `95bb69808da45ff1675f9ab8c826dd28a74194c5`.
Esta nota distingue validación de ensayos de autorización operativa.

## Evidencias confirmadas (sin despliegue)

- PostgreSQL 17 **efímero**: `C_FICHA_SPLIT_PG17_RESULT=0`, `GATE_EXIT_CODE=0`. 34 tests superados en la ejecución del 28/10/2026. Grafo sin dependencias MFA para `renewal_attachments.0001`, convivencia temporal de esquemas, protección de registros históricos, outbox y rutas ORM comprobadas en ensayo.
- Pruebas específicas de ausencia de objeto frente a ausencia del directorio privado: `STORE_ROOT_TEST_RESULT=0`, ejecutadas explícitamente mediante `manage.py test renewal_attachments.test_store_root_failure -v 2` en la imagen de prueba `vencira-csplit:95bb69808da4` con `--network none` y SQLite efímero. **Estas pruebas no deben atribuirse automáticamente al total de 34 del gate PG17.**
- Recuperación tras salida abrupta real de un worker (`os._exit`) y ensayos de concurrencia/recuperación en entorno PG17 efímero; no son una prueba de corte eléctrico ni de durabilidad física.
- Adaptador ClamAV real con socket restringido y ensayos aislados superados previamente.
- Flutter: `FLUTTER_ANALYZE=OK`, `FLUTTER_TESTS=OK`, `FLUTTER_WEB_BUILD=OK`; test O3 móvil ES/CA y manifiesto ES/CA corregidos. Panel de adjuntos solo metadatos, sin carga, descarga ni eliminación.
- GitHub: `GITHUB_SYNC=OK` tras publicar `95bb698`. Árbol local limpio salvo `clients/flutter/pubspec.lock` sin seguimiento; conservarlo sin añadir.

## Implementación y límites

- Candidata `backend/renewal_attachments`: solo registrada con `VENCIRA_ENV=test` y `VENCIRA_ATTACHMENT_SPLIT_REHEARSAL=1`. NO instalada en las configuraciones normales de desarrollo/producción.
- `backend/reminders/attachment_private_store.py`: almacén cifrado privado; eliminación idempotente si falta el **objeto**, pero error si falta el **directorio raíz**. Corrección en commit `95bb698`.
- `backend/renewal_attachments/offline_rejection_recovery.py`: descarte test-only con outbox y bloqueo de fila; no habilitar como endpoint.
- `clients/flutter/lib/ui/renewal_attachments_card.dart`: panel de documentos bloqueado y de solo lectura. `vencira_api.dart` rechaza capacidades distintas de `false`.

## Bloqueos para Macrofase D / autorización futura

1. Resolver la transición y reconciliación entre el esquema histórico `reminders.0027` y el esquema independiente; prohibido ejecutar `migrate` global sobre DEV o BD persistente.
2. Diseñar, implementar y auditar autorización de todos los endpoints por usuario, rol, workspace, renovación y estado del archivo, incluidos intentos cruzados y accesos directos.
3. Definir gestión y rotación de claves, cifrado y permisos de almacenamiento operativo; validar fallos y comportamiento ante pérdida temporal del volumen.
4. Diseñar circuito completo upload → cuarentena → escaneo auténtico → evidencia → política de acceso/descarga segura → eliminación; ninguna limpieza o resultado CLEAN concede por sí mismo acceso.
5. Ensayar restore/rollback de manera aislada con O5, revisar RGPD y proteger datos reales.
6. Ejecutar gates afectados por los cambios y obtener aprobación de publicación explícita separada.

## Decisión — permanece bloqueada

```text
MFA_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```

La Macrofase C está consolidada como **candidata de ensayo**; no equivale a release, a operación real de archivos ni a aprobación de la Macrofase D. Los documentos históricos anteriores pueden contener hitos marcados pendientes que ya fueron ensayados: prevalece este estado de fecha 28/10/2026 para C-FICHA, contrastado con el código de la rama.


## Macrofase D — auditoría estática de integración (28/10/2026)

Revisión directamente sobre código del repositorio; **no son pruebas de ejecución adicionales**.

### Contratos y límites comprobados

- `backend/config/settings.py`: `renewal_attachments` solo entra en `INSTALLED_APPS` para `VENCIRA_ATTACHMENT_SPLIT_REHEARSAL=1` y `VENCIRA_ENV=test`; el resto permanece en el modelo histórico.
- `backend/reminders/attachment_model_router.py`: `attachment_model()` enruta al modelo histórico salvo ensayo explícito. No cambiar el router hasta aprobar migración y reconciliación.
- `backend/reminders/attachment_gate.py`: el queryset de metadatos se cruza con renovaciones visibles al miembro; `may_download_attachment()` devuelve siempre `False`. No inferir permisos de lectura de un estado CLEAN.
- `backend/reminders/attachment_api.py` y `backend/reminders/urls.py`: listado GET de metadatos; POST al listado devuelve 403; ruta de detalle GET/DELETE devuelve 403 tras comprobar visibilidad. El detalle no devuelve bytes. `Cache-Control: no-store` en respuestas normales; comprobar también errores/autorización en pruebas.
- `backend/renewal_attachments/offline_intake.py`: solo test; valida pertenencia y visibilidad de renovación; no publica endpoint.
- `backend/renewal_attachments/transition_preflight.py`: `inspect_attachment_transition()` solo declara transición vacía segura si ambas tablas están sin registros; con registros, exige conciliación verificable. **No autoriza despliegue aunque ambas tablas estén vacías.**
- `backend/reminders/attachment_quarantine_intake.py`: si falla metadata invoca limpieza, pero hay que ensayar también fallo simultáneo del alta de metadata y de la limpieza del objeto, con reconciliación de huérfanos; no tratar excepciones como garantía de limpieza.
- `clients/flutter/lib/api/vencira_api.dart`: manifiesto con capacidades `upload/download/delete = false`; frontend no autoriza operaciones.

### Trabajo operativo de D agrupado para ejecutar sin repetición

**D1 — pruebas negativas del contrato actual, solo aislamiento.**
Comprobar anónimo, miembro de otro workspace, renovación no visible, adjunto perteneciente a otra renovación, ID inexistente, GET manifest, POST manifest, GET/DELETE detalle, respuesta 403/404 sin filtración de contenidos ni enlaces, `Cache-Control` y capacidades `false`. Usar datos sintéticos y Django test runner. No modificar endpoints para permitir operaciones.

**D2 — reconciliación y rollback, solo aislamiento.**
Determinar existencias de ambas tablas mediante preflight de solo lectura contra clon/restauración cifrada autorizada, nunca live. Bloquear cualquier transición con registros no reconciliados. Preparar mapeo reversible y auditoría de integridad (workspace, renovación, uploader, hash, tamaño, estado y evidencias); no mover objetos reales ni migrar DB persistente. Validar migraciones en PG17 efímero y rollback.

**D3 — diseño previo a abrir subida/descarga.**
Definir límites de tamaño, tipos y magic bytes; streaming con límites, cuarentena cifrada, gestión y rotación de claves, propietario y acceso, scanner autenticado, evidencia firmada y verificación de huella; política de rechazo y outbox; revocación, retención y RGPD. El resultado del escáner nunca es permiso suficiente. Hasta implementar y auditar esto mantener 403 por defecto.

### Punto de continuidad

- Código validado previamente: `95bb698`; documentación posterior `e30e7df`.
- Último estado expresamente reportado de VPS: rama `feature/c-ficha-independent-attachments`, `GITHUB_SYNC=OK`, solo `clients/flutter/pubspec.lock` sin seguimiento.
- Las tareas D1–D3 aquí descritas son **pendientes**, no marcarlas superadas sin evidencias de gates.

```text
MFA_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```


## Macrofase D1 — pruebas HTTP negativas

- Pruebas Django sobre SQLite aislado, sin red.
- Aislamiento entre renovaciones.
- Bloqueo de GET/DELETE incluso con estado CLEAN.
- Prohibición de exponer storage_key, sha256 y rutas privadas.
- Resultado comunicado: OK.
- No se han habilitado operaciones reales.

## Macrofase D2 — siguiente etapa

Objetivo: transición y reconciliación verificable de esquemas.

Condiciones:
- Usar PostgreSQL 17 efímero exclusivamente.
- No copiar ni modificar documentos reales.
- Detectar registros históricos antes de cualquier transición.
- Validar rollback y conservación de metadatos.
- Mantener bloqueada la publicación.

D2_RESULT=PENDING
C_FICHA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1


## Macrofase D2 — pruebas de reconciliación

Validación comunicada el 28/10/2026:

- Cuatro pruebas Django superadas en SQLite aislado.
- Transición vacía sin autorización de publicación.
- Registros históricos conservados.
- Comparación de metadatos coincidentes sin conceder acceso.
- Rollback transaccional de una copia sintética.
- Resultado: D2_ISOLATED_TEST_RESULT=0.

**Alcance:** no demuestra restauración O5, migración real ni
rollback de esquemas PostgreSQL 17.

## Macrofase D3 — siguiente control

Analizar fallos simultáneos en creación de metadatos y limpieza
de cuarentena. Deben detectarse los objetos huérfanos sin
abrir descarga, utilizar documentos reales ni activar endpoints.

D3_RESULT=PENDING
C_FICHA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1


## Macrofase D3-D4 — fallos dobles y auditoría de huérfanos

**D3 — Dos pruebas superadas:**
- Fallo de metadatos con eliminación correcta de cuarentena.
- Fallo simultáneo de metadatos y eliminación: se detecta
  el error y el objeto permanece cifrado.
- D3_DOUBLE_FAILURE_TEST_RESULT=0.

**D4 — Cuatro pruebas superadas:**
- Almacén vacío consistente, sin autorización de publicación.
- Detección de objeto huérfano sin modificarlo.
- Fallo cerrado cuando desaparece el directorio privado.
- Bloqueo de auditoría fuera del entorno de ensayos.
- D4_ORPHAN_AUDIT_RESULT=0.

El auditor D4 es de solo lectura. No garantiza una instantánea
consistente si hay escrituras concurrentes, ni sustituye un
registro duradero de recuperación.

**Siguiente fase D5:**
- Registro duradero de intención previo a almacenar archivos.
- Estados de recuperación e idempotencia.
- Reconciliación tras fallos y reinicios.
- Pruebas de concurrencia, errores y rollback.
- Sin exposición HTTP ni operaciones reales.

D5_RESULT=PENDING
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1


## Macrofase D5 — Diario de intención y recuperación

**Validación aislada comunicada el 28/10/2026.**

- D5A: cinco pruebas superadas. Registro de intención previo
  al almacenamiento, validación de huella y protección
  frente a sobrescrituras.
- D5B: once pruebas superadas, incluidas dos regresiones D3.
  Se comprueba el orden intención → almacenamiento.
- D5C: cinco pruebas superadas. Inspección tras reconstruir
  instancias del diario y del almacén privado.
- Se detectan discrepancias de huella y registros pendientes
  sin objeto verificable.
- No se habilitan endpoints ni operaciones con archivos reales.

Resultados:
D5A_JOURNAL_RESULT=0
D5B_ISOLATED_RESULT=0
D5C_RECOVERY_TEST_RESULT=0

**Límites técnicos pendientes:**

1. Distinguir objeto inexistente de volumen inaccesible
   durante la recuperación.
2. Incorporar estados terminales, transiciones idempotentes
   y reconciliación verificable del diario.
3. Garantizar coordinación ante escrituras concurrentes.
4. Ensayar interrupciones reales del proceso y durabilidad.
5. Verificar comportamiento completo en PostgreSQL 17
   efímero y estrategia de recuperación O5 aislada.
6. Auditar gestión y rotación de claves antes de producción.

Los ensayos utilizan SQLite y archivos sintéticos.
No se ha demostrado recuperación automática completa ni
resistencia a pérdida física de almacenamiento.

D5_ISOLATED_TESTS=OK
D5_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1


## Macrofase D6 — Clasificación y recuperación segura

Resultados comunicados, 28/10/2026:

- D6A: 5 pruebas superadas. Clasificación verified,
  missing, unavailable e invalid.
- D6B: 9 pruebas superadas. Decisiones idempotentes
  sin autorización de descarga ni cierre automático.
- D6C: 2 pruebas superadas. Evaluación simultánea
  de solo lectura sin modificación de los objetos.
- Total: 16 pruebas superadas.

D6A_RESULT=0
D6B_RESULT=0
D6C_RESULT=0

### Limitaciones pendientes

- No existen todavía transiciones terminales persistentes.
- La evaluación concurrente no demuestra exclusión
  transaccional entre workers PostgreSQL.
- La clasificación puede confundir error de lectura
  posterior con objeto inválido.
- La recuperación no debe automatizar eliminaciones.
- Pendientes ensayos de fallos físicos, coordinación
  de reintentos y verificación integral en PG17 efímero.

### Siguiente etapa: D7

Preparar recuperación transaccional en PostgreSQL 17
efímero, con estados persistentes, idempotencia,
bloqueos entre workers y auditoría de transiciones.

D6_ISOLATED_TESTS=OK
D6_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
