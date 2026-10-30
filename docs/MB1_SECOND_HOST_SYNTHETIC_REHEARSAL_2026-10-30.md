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
