# MB1 M1-05 — Anti-rollback con cabeza de confianza independiente (31/10/2026)

## Situación de partida

Ya existían la autenticación HMAC e integridad del manifiesto, la retención planificada no destructiva y la restauración sintética independiente (offline_backup_manifest_b09.py, mb1_e2e_authenticated_pack.py, rehearse_mb1_second_host_synthetic.sh). Esas garantías **no impiden reproducir un respaldo antiguo íntegro y con HMAC válido**.

M1-05 continúa abierto. Se añade una nueva prueba **pura, de datos sintéticos, sin Docker ni servicios**, que exige un recibo/cabeza de confianza conservado **fuera del paquete de backup**.

## Implementación — subprueba pura validada (operador)

- backend/renewal_attachments/offline_antirollback_head_mb1.py (commit ff0367f).
- backend/renewal_attachments/test_antirollback_head_mb1.py (commit a000126).
- Cada recibo canónico firmado por HMAC incluye identidad del backup, SHA-256 del paquete, secuencia y huella del recibo precedente.
- Un nuevo recibo solo encadena como sucesor inmediato de la cabeza anterior; se valida también la continuidad de la cadena.
- La validación sintética de recuperación exige **igualdad exacta** entre el recibo presentado y la cabeza confiable independiente, además de la coincidencia SHA-256 del paquete.
- Una copia anterior con firma HMAC correcta es rechazada si la cabeza externa avanzó; también se rechazan paquetes sustituidos, recibos manipulados, claves equivocadas, JSON ambiguo y ausencia de cabeza.

**Importante:** la cabeza externa no está almacenada por este módulo: debe suministrarla el operador desde custodia independiente, con garantía de integridad y resistencia a rollback. Si un atacante puede revertir simultáneamente la cabeza y todos los respaldos, **este contrato no detecta ese rollback**. Si hay compromiso de la clave HMAC, tampoco ofrece garantías. La rotación, persistencia monotónica, política de recuperación histórica excepcional y vínculo con el manifiesto real siguen pendientes. No mezclar claves de manifiesto, cifrado y recibo.

## Prueba en VPS, sin Docker ni sudo

    cd ~/vencira-localcheck
    git pull --ff-only origin feature/c-ficha-independent-attachments
    PYTHONPATH=backend python3 -m unittest -v renewal_attachments.test_antirollback_head_mb1
    echo "MB1_ANTIROLLBACK_EXIT_CODE=$?"

**Resultado comunicado por operador:** `Ran 11 tests in 0.004s`, `OK`, `MB1_ANTIROLLBACK_EXIT_CODE=0`. Subprueba de cabeza independiente y rechazo de rollback: **PASS**. No marca M1-05 como terminado; aún falta vínculo de la cabeza con los ficheros reales del paquete y custodia externa.

## Gates de liberación no satisfechos

- MB1_GLOBAL_FREEZE=NOT_VERIFIED
- MB1_EXTERNAL_TRUSTED_HEAD_CUSTODY=NOT_VERIFIED
- MB1_INTEGRATED_ANTIROLLBACK_PACKAGE=NOT_VERIFIED
- MB1_RELEASE_AUTHORIZED=NO
- NO_DEPLOY_NO_LIVE_MIGRATION=1

Ningún cambio altera DEV, O5, credenciales reales ni bases persistentes.


## Integración física de los tres archivos del paquete — PENDIENTE DE EJECUCIÓN

Se publican `offline_antirollback_package_mb1.py` (commit `c6dde95`) y `test_antirollback_package_mb1.py` (commit `4d148d3`). El adaptador enlaza explícitamente `capture.enc`, `manifest.json` y `manifest.mac` en un descriptor determinista firmado mediante el recibo anti-rollback. Verifica el HMAC del manifiesto con una **clave distinta** y el SHA-256 del contenedor cifrado; después exige que el recibo coincida con la cabeza de confianza suministrada por separado. Comprueba modos privados, tamaño y enlaces simbólicos. Las nuevas pruebas crean **archivos sintéticos con estructura de paquete**: no vuelven a descifrar Fernet ni restaurar PG17 ni acreditan custodia externa. El adaptador exige `VENCIRA_ENV=test` y `MB1_DISPOSABLE_ONLY=1`. No está integrado en O5 ni autorizado para producción.

La cabeza externa de los tests es un valor de entrada en memoria, no una custodia independiente real. Sigue pendiente conectar ambos a la restauración y custodia verdaderas; no cerrar M1-05.

Prueba en VPS sin Docker ni sudo:

    cd ~/vencira-localcheck
    git pull --ff-only origin feature/c-ficha-independent-attachments
    PYTHONPATH=backend python3 -m unittest -v renewal_attachments.test_antirollback_head_mb1 renewal_attachments.test_antirollback_package_mb1
    echo "MB1_ANTIROLLBACK_PACKAGE_EXIT_CODE=$?"

Esperado: **23 tests** (11 previos + 12 nuevos), OK y salida 0. No registrar PASS físico hasta recibir resultados.


## Validación de paquete físico sintético — PASS (operador)

`Ran 23 tests in 0.031s`, `OK`, `MB1_ANTIROLLBACK_PACKAGE_EXIT_CODE=0` (11 pruebas de cabeza independiente y 12 de vínculo a `capture.enc`, `manifest.json` y `manifest.mac`). Quedan validados en modo unitario/sintético la detección de sustitución de cualquiera de las tres piezas, el rechazo de una copia antigua íntegra contra una cabeza más reciente, errores de autenticación y ausencias de archivos. **No** se ha comprobado custodia externa física de la cabeza ni la integración del verificador con la restauración del paquete real del laboratorio en un segundo host. M1-05 permanece abierto.


## Próximo gate de M1-05 (decisión de alcance, no otra repetición de 23 tests)

**El hito aún requiere una integración end-to-end fail-closed antes de restaurar**, con estas etapas verificables:

1. Generar un paquete sintético a partir de la captura consistente de laboratorio, conservando la custodia separada de las claves y evitando claves dentro del paquete. Vincular el recibo anti-rollback a exactamente los archivos publicados y a su snapshot_id.
2. Crear y promover el nuevo recibo **fuera del dominio recuperable desde el VPS**, bajo autoridad de custodia externa. La promoción debe ser monotónica o inmutable/versionada con protección frente a modificación y borrado; no permitir que el mismo proceso que genera backups sobrescriba el registro confiable. La mera copia en una carpeta distinta del VPS no cuenta.
3. Transferir paquete, clave de manifiesto/cifrado y recibo de confianza por vías separadas a un segundo host. Antes de ejecutar pg_restore, comprobar HMAC y la coincidencia exacta con la cabeza externa. Verificar que una copia antigua **válida** se rechaza tras promover otra más reciente, y que la copia nueva se restaura integralmente.
4. Probar la **pérdida del VPS** y el caso de pérdida o indisponibilidad del registro externo; debe abortar con diagnóstico, no tratar la copia anterior como la actual. Una restauración histórica excepcional necesita autorización y procedimiento diferente, auditable.
5. Acordar retención/rotación de clave, política de recuperación y responsabilidades operativas. No migrar esta lógica a DEV ni habilitar supresión automática de backups antes de su aceptación.

El código pure-Python actual no crea ni protege ese registro externo; no puede sustituir controles de infraestructura/custodia. **Decisión actual:** M1-05 `INTEGRATED_EXTERNAL_ANCHOR=NO`, M1-06 `OPERATIONAL_CUSTODY=NO`, `MB1_RELEASE_AUTHORIZED=NO`.
