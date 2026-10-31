# VENCIRA — MB1 M1-05: respaldo cifrado en dos generaciones y restauración anti-rollback

Fecha: 2026-10-31. Rama: feature/c-ficha-independent-attachments.
Implementación: scripts/rehearse_mb1_antirollback_gated_restore_disposable.py (commit 9da9b99).

## Qué queda integrado en un solo ensayo

Este ensayo combina código ya existente sin tocar ninguna base de VENCIRA:

1. Crea un PG17 efímero, sin red, con una tabla sintética que pasa de la versión 1 a la versión 2.
2. Captura dos pg_dump binarios y crea dos paquetes reales de laboratorio mediante el módulo existente mb1_e2e_authenticated_pack: capture.enc, manifest.json y manifest.mac, vinculados a sus objetos y diarios sintéticos.
3. Tras generar los paquetes, los datos sin cifrar del staging no se trasladan a la restauración. Las claves de cifrado/manifiesto se guardan en directorios temporales separados de los paquetes.
4. Crea una cadena HMAC anti-rollback con dos recibos y sitúa la cabeza actual en una carpeta temporal separada: **simulación local**, no custodia externa.
5. Antes de cualquier pg_restore verifica que la copia antigua, aunque íntegra y autenticada, se rechaza contra la cabeza actual. Verifica también rechazo de recibo cruzado, cabeza ausente y paquete manipulado.
6. Solamente tras verificar el paquete nuevo y su recibo, restaura PG17, extrae objeto y diario y comprueba que los tres reflejan la segunda versión.
7. Destruye los contenedores, la imagen exclusiva de ensayo y los archivos temporales; no detiene ni modifica servicios existentes. La prueba requiere autorización explícita de laboratorio y falla cerrada ante errores.

Se reutilizan los verificadores offline_antirollback_head_mb1 y offline_antirollback_package_mb1, probados anteriormente con 23 tests PASS.

## Ejecución única en VPS (pendiente)

    cd ~/vencira-localcheck
    git pull --ff-only origin feature/c-ficha-independent-attachments
    python3 -m py_compile scripts/rehearse_mb1_antirollback_gated_restore_disposable.py
    sudo env MB1_ANTIROLLBACK_E2E_LAB=YES python3 scripts/rehearse_mb1_antirollback_gated_restore_disposable.py
    echo "MB1_ANTIROLLBACK_E2E_EXIT_CODE=$?"

Marcadores que deben coexistir con salida 0:

- MB1_TWO_ENCRYPTED_PHYSICAL_GENERATIONS=OK
- MB1_SYNTHETIC_TRUSTED_HEAD_ADVANCED=OK
- MB1_STALE_VALID_PACKAGE_REJECTED_BEFORE_RESTORE=OK
- MB1_CROSS_PACKAGE_RECEIPT_REJECTED=OK
- MB1_MISSING_EXTERNAL_HEAD_REJECTED=OK
- MB1_TAMPERED_PACKAGE_REJECTED=OK
- MB1_LATEST_PACKAGE_PREFLIGHT_VERIFIED=OK
- MB1_CURRENT_PG17_RESTORE_AFTER_GATE=OK
- MB1_CURRENT_OBJECT_JOURNAL_RESTORE=OK
- MB1_ANTIROLLBACK_GATED_E2E_LAB=OK
- MB1_ANTIROLLBACK_E2E_RESULT=0
- MB1_ANTIROLLBACK_E2E_EXIT_CODE=0

## Límites que esta prueba NO supera

- La cabeza de confianza está en otra carpeta del **mismo host de ensayo**; un atacante con capacidad sobre el host puede alterar recibos, claves y paquetes. No demuestra custodia externa real, persistencia monotónica resistente a rollback ni recuperación tras pérdida total.
- La prueba genera paquetes con pg_dump sintéticos, no un backup operacional congelado globalmente. M1-04 permanece abierto y los procesos privilegiados y escritores externos no están excluidos.
- El rechazo se aplica como **preflight en el ejecutor de ensayo**, no como imposición universal en los scripts de producción, O5 o restauración operativa.
- El empaquetado de laboratorio es sintético; aún falta un ejercicio con custodia externa auténtica en segundo host y política de rotación/retención. La prueba del segundo host anterior es de recuperación sin este nuevo gate.
- La secuencia en recibo se valida, pero no se ha instalado un registro externo de confianza con escritura monotónica y permisos segregados.

Decisión hasta cerrar M1-04/M1-05/M1-06:

    MB1_EXTERNAL_HEAD_CUSTODY=NOT_VERIFIED
    MB1_GLOBAL_FREEZE=NOT_VERIFIED
    MB1_OPERATIONAL_BACKUP_INTEGRATION=NOT_VERIFIED
    MB1_RELEASE_AUTHORIZED=NO
    NO_DEPLOY_NO_LIVE_MIGRATION=1

**No marcar M1-05 completo solo por PASS de este laboratorio.**
