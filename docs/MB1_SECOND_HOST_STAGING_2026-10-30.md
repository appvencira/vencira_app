# MB1 — Preparación de materiales sintéticos para segundo host

**Estado: implementación publicada, ejecución y transferencia pendientes.**

`scripts/stage_mb1_second_host_fixture.sh` toma **exclusivamente** una ruta local del último ensayo E2E del patrón `/tmp/vencira-mb1-e2e.*`. Comprueba titularidad, permisos privados, existencia de `capture.enc`, `manifest.json`, `manifest.mac`, claves sintéticas y `snapshot` esperado; rechaza la presencia de `source.dump` sin cifrar. Genera dos carpetas privadas: `package/` con tres archivos cifrados/autenticados, y `keys/` con dos claves **sintéticas**. No transfiere nada fuera del VPS ni contacta ningún servidor. No utilizar con O5, datos reales ni otras claves.

## Preparación en VPS actual

```bash
cd ~/vencira-localcheck
git pull --ff-only origin feature/c-ficha-independent-attachments
bash scripts/stage_mb1_second_host_fixture.sh /tmp/vencira-mb1-e2e.A7lyBYRd
echo "MB1_STAGE_EXIT_CODE=$?"
```

**Atención:** este identificador de ensayo procede del último resultado conocido; si el directorio local ya no existe, el proceso debe fallar y **no** utilizar un backup operativo como sustituto. La salida indica las dos rutas locales, **no** el contenido de claves. Las carpetas existen en el VPS hasta que el operador las borre después de haber verificado recepción y restauración. Jamás pegar archivos de `keys/` en el chat ni subirlos a GitHub.

## Transferencia y aceptación pendientes

1. Proveer un **segundo host independiente**, con Docker, espacio de prueba y la imagen backend fijada a la revisión que contiene `detached_extract_to`.
2. Transferir `package/` y `keys/` por rutas distintas, limitadas y autenticadas; no transmitir secretos por chat ni introducirlos en comandos visibles. La etapa de transporte **no está automatizada**.
3. En ese segundo host ejecutar `scripts/rehearse_mb1_second_host_synthetic.sh` con confirmación `MB1_CONFIRM_INDEPENDENT_HOST=YES_SYNTHETIC_ONLY`, apuntando a las dos carpetas privadas y la imagen fijada.
4. Registrar únicamente resultados de la restauración, método de custodia, verificación de identidad de destino y eliminación de los artefactos temporales; nunca sus secretos.
5. Borrar el staging de la máquina de origen una vez finalizada la prueba; no utilizar `rm -rf` fuera de la ruta privada explícita y comprobada.

Esta etapa **no** demuestra custodia real, pérdida de VPS ni congelación global. Tiene como objetivo hacer ejecutable el siguiente paso externo sin volver a correr el E2E. `MB1_EXTERNAL_KEY_CUSTODY=NOT_VERIFIED`, `MB1_GLOBAL_FREEZE=NOT_VERIFIED`, `MB1_RELEASE_AUTHORIZED=NO`.
