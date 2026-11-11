# D3-B5 — Resultado de ensayo rootless aislado (2026-11-11)

## Alcance y evidencia

Fuente: salida de Termius facilitada por el operador tras ejecutar `scripts/main_d3b5_rootless_podman_reload_isolated.sh` sobre `/home/vencira/vencira-release-archives/pre-upgrade-82d5a9324f6141b67b5b55a7`, con rama main en `ea7d61d5`.

| Marcador | Resultado |
| --- | --- |
| D3B5_MAIN_SYNC | PASS |
| D3B5_ARCHIVE_CHECKSUM | PASS |
| D3B5_STORAGE_CAPACITY | PASS |
| D3B5_XDG_RUNTIME_DIRECTORY | PASS |
| D3B5_ROOTLESS_RUNTIME_ENV | PASS |
| D3B5_ROOTLESS_PRIVATE_STORE | PASS |
| D3B5_HOST_DOCKER_SOCKET_MOUNTED | NO |
| D3B5_ROOTLESS_IMAGE_IMPORT | PASS |
| D3B5_IMPORTED_IMAGE_COUNT_3 | PASS |
| D3B5_ARCHIVED_IMAGES_RELOAD_IN_INDEPENDENT_STORE | PASS |
| D3B5_EPHEMERAL_STORAGE_REMOVED | YES |
| D3B5_RESULT | 0 |
| D3B5_SHELL_RESULT | 0 |

Comprobación independiente posterior: `find ... -name 'd3b5-rootless.*'` no devolvió directorios residuales; `systemctl is-active docker` devolvió `active`.

**Interpretación**: D3-B5 pasa como ensayo de carga de tres imágenes en almacén rootless aislado con limpieza completa. No equivale a prueba de arranque ni recuperación operativa.

## Pendientes y límites

- `D3B5_ARCHIVED_IMAGES_EXECUTED=NO`.
- `D3B5_O5_IMAGE_COMPATIBILITY_VERIFIED=NO`.
- `D3B5_EXACT_ORIGINAL_DOCKER_IMAGE_ID_VERIFIED=NO`.
- `D3B5_OFF_HOST_COPY_VERIFIED=NO`.
- `D3B5_OPERATIONAL_ROLLBACK_VERIFIED=NO`.
- Discrepancia histórica de IDs documentada anteriormente en D3-B3: no resuelta por D3-B5.
- No se ha verificado arranque, servicios, base de datos ni rollback real.

## Contexto del fallo y solución

Ensayos previos fallaron al inicializar el runtime rootless (error 125) y posteriormente al limpiar capas VFS read-only y con UID subordinados (resultado 9). La corrección de `main` `ea7d61d5` usa `podman unshare` durante la limpieza del laboratorio. Validación positiva de la ejecución tras sincronizar el checkout local con ese commit. No se alteró el Docker operativo.

## Política de seguridad

```text
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
D3B5_RELEASE_AUTHORIZED=NO
D3B5_DEPLOY_EXECUTED=NO
D3B5_LIVE_MIGRATIONS_EXECUTED=NO
D3B5_LIVE_RESTORE_EXECUTED=NO
D3B5_OPERATIONAL_ROLLBACK_EXECUTED=NO
D3B5_HOST_DOCKER_IMAGE_LOAD_EXECUTED=NO
D3B5_CONTAINER_RUN_EXECUTED=NO
D3B5_PUBLIC_RELEASE_AUTHORIZED=NO
```

## Próximo gate propuesto

D3-B6 (por definir y revisar): auditoría de metadatos de archivo, manifiestos y referencias de digest/IDs, sin carga a Docker operativo, sin ejecutar contenedores y sin restaurar PostgreSQL. La prueba D3-B5 no elimina por sí sola el riesgo de identidad exacta ni valida recuperación.
