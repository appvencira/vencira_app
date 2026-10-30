# MB1 — verificación de recepción del paquete sintético fuera del VPS

**30/10/2026. Código publicado; no ejecutado.**

El staging `scripts/stage_mb1_second_host_fixture.sh` incorpora un listado SHA-256 de **solo los tres archivos cifrados/autenticados** (`capture.enc`, `manifest.json`, `manifest.mac`) en `package-checksums.sha256`. No incluye huellas de claves. `scripts/verify_mb1_second_host_package_receipt.sh` compara el conjunto con ese listado después de comprobar que hay exactamente tres registros y nombres permitidos. No usa Docker, no abre claves ni conecta con otro servidor.

**El listado debe llegar al segundo host por una vía cuya autenticidad haya sido comprobada independientemente**. Si se envía el listado por el mismo canal que un paquete manipulable, un atacante puede sustituir ambos: SHA-256 solo detecta alteraciones respecto del inventario recibido, no acredita identidad de origen. Tampoco evita replay/rollback. La autenticidad criptográfica del backup se valida posteriormente con HMAC y claves independientes.

El staging que ya se creó en `/tmp/vencira-mb1-transfer.5orQIVRY/` precede a esta versión: **no tiene por qué contener el listado**. Puede generarse un inventario de esos tres ficheros sin repetir E2E:

```bash
cd /tmp/vencira-mb1-transfer.5orQIVRY
( cd package && sha256sum capture.enc manifest.json manifest.mac ) > package-checksums.sha256
chmod 600 package-checksums.sha256
cd ~/vencira-localcheck
git pull --ff-only origin feature/c-ficha-independent-attachments
bash scripts/verify_mb1_second_host_package_receipt.sh /tmp/vencira-mb1-transfer.5orQIVRY/package /tmp/vencira-mb1-transfer.5orQIVRY/package-checksums.sha256
```

Esto permite comprobar el material existente en el VPS sin generar ni revelar claves. El resultado local **NO** sustituye la verificación en el host independiente. Allí, recibir el paquete y el listado por canales con identidad comprobada y ejecutar el mismo verificador antes de introducir claves y restaurar.

```text
MB1_SECOND_HOST_PACKAGE_RECEIPT=PENDING
MB1_REAL_OFFHOST_TRANSFER=NOT_EXECUTED
MB1_EXTERNAL_CUSTODY=NOT_VERIFIED
MB1_GLOBAL_FREEZE=NOT_VERIFIED
MB1_RELEASE_AUTHORIZED=NO
```


## Resultado comunicado por operador

La verificación **local** del paquete de ensayo ha terminado con `MB1_SECOND_HOST_PACKAGE_RECEIPT=OK` y `MB1_TRANSFER_VERIFY_EXIT_CODE=0`. `MB1_SECOND_HOST_KEYS=NOT_CHECKED`, `MB1_SECOND_HOST_RESTORE=NOT_RUN`, `MB1_EXTERNAL_CUSTODY=NOT_VERIFIED` y `MB1_RELEASE_AUTHORIZED=NO`. No existen evidencias todavía de traslado fuera del VPS ni de restauración en el segundo host. No se vuelven a ejecutar los gates anteriores.
