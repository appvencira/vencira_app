# D3-B6 — Inventario estructural Docker/OCI (2026-11-11)

## Resultado comunicado por operador

Ejecución desde Termius del script `scripts/main_d3b6_archive_metadata_readonly.py` sobre el archivo `images.tar.gz` del paquete `pre-upgrade-82d5a9324f6141b67b5b55a7`.

```text
D3B6_METADATA_PRESENCE=PASS
D3B6_OCI_LAYOUT=PASS
D3B6_DOCKER_MANIFEST_SCHEMA=PASS
D3B6_DOCKER_MANIFEST_ENTRIES=3
D3B6_DOCKER_CONFIG_REFERENCES=3
D3B6_DOCKER_LAYER_REFERENCES=28
D3B6_DOCKER_REPO_TAGS_PRESENT=NO
D3B6_OCI_INDEX_SCHEMA=PASS
D3B6_OCI_INDEX_DESCRIPTORS=3
D3B6_EXACT_HISTORICAL_IMAGE_ID_VERIFIED=NO
D3B6_BLOB_DIGEST_CONTENT_VERIFIED=NO
D3B6_O5_COMPATIBILITY_VERIFIED=NO
D3B6_OPERATIONAL_ROLLBACK_VERIFIED=NO
D3B6_HOST_DOCKER_IMAGE_LOAD_EXECUTED=NO
D3B6_CONTAINER_RUN_EXECUTED=NO
D3B6_LIVE_RESTORE_EXECUTED=NO
D3B6_RESULT=0
D3B6_SHELL_RESULT=0
```

`systemctl is-active docker` -> `active`; `git status --short` -> vacío.

## Interpretación

El formato estructural validado contiene tres entradas Docker, tres referencias de configuración, 28 referencias a capas y tres descriptores OCI. La ausencia de RepoTags impide asumir restauración mediante etiquetas originales. Esto **no** acredita todavía que los bytes de todos los blobs coincidan con sus hashes, ni la igualdad con los IDs de imágenes Docker históricos. D3-B5 sí verificó importación aislada de tres imágenes con limpieza; no ejecutó contenedores.

## Pendientes

1. Validar hash SHA-256 y tamaño de blobs OCI dentro de `images.tar.gz`.
2. Contrastar IDs de configuración con registros históricos autenticados y explicar la discrepancia D3-B3.
3. Verificar mapeo de imagen/servicio y compatibilidad O5 sin tocar Docker activo.
4. Ensayo de recuperación operativa únicamente en entorno aislado y autorizado.

```text
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
D3B6_PUBLIC_RELEASE_AUTHORIZED=NO
D3B6_OPERATIONAL_ROLLBACK_VERIFIED=NO
```
