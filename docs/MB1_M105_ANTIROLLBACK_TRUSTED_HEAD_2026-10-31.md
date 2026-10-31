# MB1 M1-05 — Anti-rollback con cabeza de confianza independiente (31/10/2026)

## Situación de partida

Ya existían la autenticación HMAC e integridad del manifiesto, la retención planificada no destructiva y la restauración sintética independiente (offline_backup_manifest_b09.py, mb1_e2e_authenticated_pack.py, rehearse_mb1_second_host_synthetic.sh). Esas garantías **no impiden reproducir un respaldo antiguo íntegro y con HMAC válido**.

M1-05 continúa abierto. Se añade una nueva prueba **pura, de datos sintéticos, sin Docker ni servicios**, que exige un recibo/cabeza de confianza conservado **fuera del paquete de backup**.

## Implementación propuesta — no ejecutada todavía

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

Se esperan 11 pruebas OK y MB1_ANTIROLLBACK_EXIT_CODE=0. Solo entonces registrar PASS de la subprueba. No marca M1-05 como terminado.

## Gates de liberación no satisfechos

- MB1_GLOBAL_FREEZE=NOT_VERIFIED
- MB1_EXTERNAL_TRUSTED_HEAD_CUSTODY=NOT_VERIFIED
- MB1_INTEGRATED_ANTIROLLBACK_PACKAGE=NOT_VERIFIED
- MB1_RELEASE_AUTHORIZED=NO
- NO_DEPLOY_NO_LIVE_MIGRATION=1

Ningún cambio altera DEV, O5, credenciales reales ni bases persistentes.
