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
