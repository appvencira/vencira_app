# VENCIRA — MB1 captura de archivos físicos sintéticos bajo fence multiproceso

**30/10/2026 — preparado, sin ejecución del operador.**

Se integró el coordinador `IsolatedProcessFence` del bloque multiproceso (ya validado 6/6) con el verificador B18E (validado 12/12), utilizando **archivos temporales reales** de un ensayo: `db_inventory.json` (representación de inventario de BD, **no un volcado PostgreSQL**), `objects/<id>` con ciphertext sintético y `journal/<id>.json`. El programa `offline_synthetic_file_capture_mb1.py` exige permisos de raíz privada, lee las tres piezas durante `fence.capture()` y comprueba huellas, identidad e inventario. Seis tests `test_synthetic_file_capture_mb1.py` cubren caso correcto, corrupción, ausencias, permisos y prueba negativa de que un escritor no cooperativo puede alterar archivos durante un lock cooperativo.

El diagnóstico es deliberadamente limitado: **no crea `pg_dump`, no conecta a PG17, no captura ni restaura datos reales, no controla otros contenedores o writers que ignoran el lock, no construye un backup durable ni acredita custodia externa.** El objetivo es probar la composición material con archivos de ensayo y hacer visible el límite de seguridad sin atribuirle una garantía falsa.

```bash
cd ~/vencira-localcheck
git pull --ff-only origin feature/c-ficha-independent-attachments
bash scripts/validate_mb1_physical_fixture_capture.sh
echo "MB1_PHYSICAL_EXIT_CODE=$?"
```

Esperado si pasa: seis tests, `MB1_PHYSICAL_FIXTURE_CAPTURE=OK`, `MB1_REAL_PG17_CAPTURE=NOT_RUN`, `MB1_NONCOOPERATIVE_WRITER_EXCLUSION=NOT_VERIFIED`, `MB1_INDEPENDENT_RESTORE=NOT_RUN`, `MB1_PHYSICAL_RESULT=0`. **Pendiente validar**.

## Bloqueador para cerrar MB1

El único siguiente gate de valor suficiente debe ser un ensayo **completo**: clonar PG17 en aislamiento, detener físicamente entradas de escritura y writers (incluidos no cooperativos), capturar datos SQL más objetos/diario, autenticar un snapshot sin alteraciones, restaurar sobre PG17 destino distinto con B09E y simular caída. No confundir los datos artificiales de `db_inventory.json` con el snapshot de PostgreSQL. El diseño y condiciones de aceptación figuran en `MB1_FREEZE_RESTORE_INTEGRATION_DECISION_2026-10-30.md`.

```text
MB1_PHYSICAL_FIXTURE_TESTS=PENDING
MB1_GLOBAL_FREEZE=NOT_IMPLEMENTED
MB1_REAL_PG17_INTEGRATION=NOT_RUN
MB1_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```


## Validación aportada por operador — 30/10/2026

`Ran 6 tests in 0.011s`, `OK`, `MB1_PHYSICAL_FIXTURE_CAPTURE=OK`, `MB1_REAL_PG17_CAPTURE=NOT_RUN`, `MB1_NONCOOPERATIVE_WRITER_EXCLUSION=NOT_VERIFIED`, `MB1_INDEPENDENT_RESTORE=NOT_RUN`, `MB1_RELEASE_AUTHORIZED=NO`, `C_FICHA_RELEASE_AUTHORIZED=NO`, `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`, `MB1_PHYSICAL_RESULT=0`. Acredita únicamente las **seis pruebas de captura física sintética**; no significa snapshot de PG17 ni restore integral. El fragmento compartido no incluye un `MB1_PHYSICAL_EXIT_CODE` adicional. Próximo desarrollo de valor: un ensayo end-to-end real en PG17 efímero con storage sintético, restauración aislada y controles de exclusión efectivos, sin habilitar servicios ni datos persistentes.
