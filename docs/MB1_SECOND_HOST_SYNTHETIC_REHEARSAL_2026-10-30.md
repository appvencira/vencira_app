# VENCIRA MB1 — ensayo en segundo host independiente

**Fecha:** 30/10/2026. Implementado, **no ejecutado ni validado**.

Se ha añadido `scripts/rehearse_mb1_second_host_synthetic.sh` para ejecutarse **únicamente en una segunda máquina**, con un paquete MB1 de pruebas y claves sintéticas transferidos por canales separados. En ese host debe existir una imagen del backend de **la misma revisión** que creó el paquete, PostgreSQL 17 por Docker y dos directorios privados (700) que no sean el mismo directorio. No conecta con la máquina de origen: inicia PG17 desechable con red desactivada, verifica que un paquete sin claves no se descifra, monta paquete y claves en puntos separados de solo lectura, descifra el dump en streaming, restaura el registro de prueba y elimina su contenedor temporal.

La ruta del script en GitHub es **código de ensayo**, no un destino seguro para subir claves. No están implementados la generación y transporte independiente de paquetes, la provisión de claves fuera del VPS, la selección de segundo host, ni la acreditación de que no ha tenido conexión con el origen. **No se debe ejecutar todavía sin preparar esas precondiciones**, y el gate final nunca certifica por sí solo custodia externa. El script solo restaura PostgreSQL; no extrae ni compara objetos/diario en ese segundo host, por lo que **no completa la validación integral de recuperación**.

## Uso cuando existan condiciones reales

En el SEGUNDO host de laboratorio, con `PACKAGE_DIRECTORY` y `KEY_DIRECTORY` independientes, y una imagen backend fijada:

```bash
MB1_CONFIRM_INDEPENDENT_HOST=YES_SYNTHETIC_ONLY \
  bash scripts/rehearse_mb1_second_host_synthetic.sh \
  /ruta/paquete-cifrado-de-ensayo \
  /ruta/claves-sinteticas-de-ensayo \
  vencira-backend:tag-de-ensayo
```

No ejecutar este comando en el VPS de desarrollo: hacerlo falsearía el requisito de host independiente. Ninguna clave real debe aparecer en mensajes, logs, Git o documentación. Requiere revisión del gate y evidencia de procedencia de medios y del segundo host. Los ensayos previos en el VPS siguen aprobados, pero la externalización real está **pendiente**.

```text
MB1_SECOND_HOST_RUNNER=IMPLEMENTED_UNVALIDATED
MB1_EXTERNAL_MEDIA_TRANSFER=NOT_IMPLEMENTED
MB1_SECOND_HOST_RESTORE=NOT_RUN
MB1_EXTERNAL_KEY_CUSTODY=NOT_VERIFIED
MB1_GLOBAL_FREEZE=NOT_VERIFIED
MB1_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```


## Ampliación de ensayo: objetos y diario (pendiente de ejecución)

El runner de segundo host ahora también descifra y autentica objeto y diario del paquete, los extrae a un tercer montaje temporal de salida y exige que existan con contenido. El backend incorpora `detached_extract_to` para no escribir en el paquete de origen montado solo lectura. **No se ha ejecutado aún en un segundo host.** Esta comprobación es una prueba de recuperación de bytes sintéticos, no una comprobación completa de coherencia ORM/objeto/diario sobre datos operativos. No aprovisiona almacenamiento externo ni custodia real. `MB1_EXTERNAL_KEY_CUSTODY=NOT_VERIFIED`, `MB1_GLOBAL_FREEZE=NOT_VERIFIED`, `MB1_RELEASE_AUTHORIZED=NO`.


## Integración del mismo método en el E2E ya validado — pendiente de ensayo

La revisión `8601996` incorpora al ejecutor `scripts/rehearse_mb1_pg17_e2e_disposable.sh` la operación `detached_extract_to` del runner de segundo host. Se emplean tres montajes: `/capture` **solo lectura**, `/keymedia` **solo lectura** y `/recovered` escribible por separado; se verifican hashes del objeto y diario extraídos y se imprime `MB1_E2E_THREE_MOUNT_OBJECT_JOURNAL=OK`. Sustituye la extracción antigua, sin reejecutar suites parciales ni modificar los servicios vivos. **Solo valida el método en un VPS con datos sintéticos, no la existencia de un host externo**.

Validación única:

```bash
cd ~/vencira-localcheck
git pull --ff-only origin feature/c-ficha-independent-attachments
bash scripts/rehearse_mb1_pg17_e2e_disposable.sh
echo "MB1_SECOND_HOST_METHOD_EXIT_CODE=$?"
```

No afirmar custodia externa ni freeze global por este resultado.


## Primera restauración en Ubuntu x86_64 independiente — PASS (30/10/2026)

El operador realizó un ensayo en un Ubuntu x86_64 distinto del VPS IONOS. Se transfirió el paquete sintético cifrado por SSH y se verificó el inventario SHA-256 en destino (`MB1_REMOTE_PACKAGE_VERIFY_EXIT_CODE=0`). Las claves sintéticas se empaquetaron cifradas en USB local, se verificó su descifrado con éxito y se extrajeron a un directorio temporal en `/dev/shm` para restauración. Se utilizó la imagen `vencira-mb1-recovery:c2eb33902e82` (amd64). Indicadores informados: `MB1_KEYS_IN_TEMPORARY_MEMORY=OK`, `MB1_SECOND_HOST_NO_KEYS=REJECTED`, `MB1_SECOND_HOST_OBJECT_JOURNAL=OK`, `MB1_SECOND_HOST_PG17_RESTORE=OK`, `MB1_SECOND_HOST_PACKAGE_AND_KEYS_SEPARATE=OK`, `MB1_SECOND_HOST_SYNTHETIC_RESTORE=OK`, `MB1_SECOND_HOST_RESULT=0`, `MB1_INDEPENDENT_RESTORE_COMMAND=OK`, `MB1_SECOND_HOST_EXIT_CODE=0`.

**Alcance exacto:** restauración completa **sintética** en un host independiente confirmada por salida del operador. El resultado de objetos/diario comprueba existencia con contenido, no comparación end-to-end de hashes contra un manifiesto de origen independiente. El paquete y las claves se originaron en el VPS: USB tras transferencia por SSH no acredita custodia externa operativa ni supervivencia ante pérdida total del VPS. El proceso no acredita congelación global de escritores reales. `MB1_EXTERNAL_KEY_CUSTODY=REQUIRES_MANUAL_ATTESTATION`, `MB1_GLOBAL_FREEZE=NOT_VERIFIED`, `MB1_RELEASE_AUTHORIZED=NO`, `MFA_RELEASE_AUTHORIZED=NO`, `C_FICHA_RELEASE_AUTHORIZED=NO`.
