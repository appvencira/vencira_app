# D3-B6C — Verificación SHA-256 de blobs OCI (2026-11-11)

## Evidencia de ejecución local

Operador ejecutó `scripts/main_d3b6c_archive_blob_sha256_readonly.py` sobre el archivo de imágenes de `pre-upgrade-82d5a9324f6141b67b5b55a7`. Salida recibida:

```text
D3B6C_METADATA=PASS
D3B6C_INDEX_BLOB_REFERENCES=PASS
D3B6C_OCI_BLOB_SHA256=PASS
D3B6C_OCI_BLOBS_HASHED=46
D3B6C_OCI_INDEX_DESCRIPTORS=3
D3B6C_EXACT_HISTORICAL_IMAGE_ID_VERIFIED=NO
D3B6C_O5_COMPATIBILITY_VERIFIED=NO
D3B6C_OPERATIONAL_ROLLBACK_VERIFIED=NO
D3B6C_HOST_DOCKER_IMAGE_LOAD_EXECUTED=NO
D3B6C_CONTAINER_RUN_EXECUTED=NO
D3B6C_LIVE_RESTORE_EXECUTED=NO
D3B6C_RESULT=0
D3B6C_SHELL_RESULT=0
```

`systemctl is-active docker` -> `active`; `git status --short` -> vacío.

## Alcance real

El comprobador recorrió las entradas `blobs/sha256/<digest>` presentes en el TAR, contrastó sus bytes con sus nombres SHA-256 y verificó tamaños de blobs referenciados directamente por los descriptores del `index.json`. Se comprobaron 46 blobs y tres descriptores OCI.

No se ha demostrado todavía que todos los objetos encadenados por las configuraciones/manifiestos Docker u OCI sean completos ni que las imágenes sean idénticas a los IDs Docker registrados históricamente. Ausencia de `RepoTags` en D3-B6. La discrepancia de D3-B3 sigue abierta.

D3-B5: importación de tres imágenes en Podman aislado PASS. D3-B6: inventario estructural PASS. D3-B6C: integridad SHA-256 de blobs presentes PASS. Ninguno implica compatibilidad O5, arranque o rollback.

## Política

```text
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
D3B6C_OPERATIONAL_ROLLBACK_VERIFIED=NO
D3B6C_HOST_DOCKER_IMAGE_LOAD_EXECUTED=NO
D3B6C_CONTAINER_RUN_EXECUTED=NO
D3B6C_LIVE_RESTORE_EXECUTED=NO
```

## Siguiente control

Contrastar el mapa de las tres referencias de configuración (identificadores potenciales de imagen) contra evidencia histórica independiente, con salida sanitizada que no revele referencias completas ni invente equivalencias. Mantener ejecución de solo lectura, sin contenedores ni restauraciones.
