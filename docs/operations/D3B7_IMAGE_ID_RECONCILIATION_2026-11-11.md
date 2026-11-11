# D3-B7 — Reconciliación de identidades: punto de partida (2026-11-11)

## Evidencia existente, no repetir ensayos

- D3-B2 archivó mediante `sudo docker image save "$api_img" "$db_img" "$web_img"` tres IDs de contenedores DEV y guardó esos mismos IDs en `images.manifest`. El empaquetado se hizo en el mismo flujo, con verificación de que las identidades de contenedores no cambiaron.
- D3-B3, tras corregir la aceptación de configuración OCI, acreditó checksums de configuraciones pero detectó **cero coincidencias** entre los tres hashes de configuración archivada y los tres IDs de `images.manifest`. Gate estricto D3-B3 sigue FAIL; nunca forzar PASS.
- D3-B4, ya ejecutado, encontró exactamente una coincidencia por rol de `rootfs.diff_ids`, OS y arquitectura, y cero diferencias en los campos de ejecución comunes muestreados (API 0/6, DB 0/7, WEB 0/8). No prueba identidad byte a byte.
- D3-B5: carga en Podman rootless aislado, tres imágenes, limpieza completa PASS.
- D3-B6: tres entradas de Docker manifest, tres configuraciones, 28 referencias a capas, tres descriptores OCI; RepoTags ausentes.
- D3-B6C: hashes de 46 blobs presentes coinciden con nombre de digest, referencias directas OCI verificadas PASS.

## Interpretación y límites

Las imágenes archivadas son *candidatas plausibles por plataforma, capas y configuración común*, pero la correspondencia exacta del ID histórico continúa sin certificar. No suponer que los hashes de la imagen importada en Podman o los nombres de referencias sean los IDs originales; documentar la distinción entre IDs Docker, digest de configuración OCI, digest de manifiesto OCI y digest del TAR. Investigar si `docker save` convirtió o normalizó la representación antes de interpretar el desajuste como pérdida, sustitución o corrupción. Ninguna hipótesis está confirmada.

## Próxima actuación D3-B7

1. Diagnóstico de versión/motor de Docker (salida sanitizada) y formato real del archivo, con herramientas de solo lectura.
2. Comparación de esquema/huellas de campos con las configuraciones archivadas y evidencias de origen de los tres IDs, sin imprimir variables de entorno, etiquetas, secretos ni IDs completos.
3. Si no se establece equivalencia exacta, conservar `IDENTITY_VERIFIED=NO` y ensayar recuperación funcional **solo en laboratorio totalmente aislado** y con criterios explícitos de compatibilidad O5.
4. Verificar custodia externa cifrada y restaurabilidad independiente antes de autorización operativa.

## Guardas

```text
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
D3B7_EXACT_HISTORICAL_IMAGE_ID_VERIFIED=NO
D3B7_O5_COMPATIBILITY_VERIFIED=NO
D3B7_OPERATIONAL_ROLLBACK_VERIFIED=NO
D3B7_HOST_DOCKER_IMAGE_LOAD_EXECUTED=NO
D3B7_CONTAINER_RUN_EXECUTED=NO
D3B7_LIVE_RESTORE_EXECUTED=NO
```
