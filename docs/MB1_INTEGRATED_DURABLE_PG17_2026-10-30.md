# MB1 — Integración PG17 + almacén cifrado + diario persistente

**30/10/2026. Implementado en rama, aún sin ejecución del operador.**

`scripts/rehearse_mb1_integrated_durable_pg17.sh` integra en un mismo ensayo la **implementación real** `PrivateQuarantineStore` (Fernet), `IntakeJournal` (intención duradera) y modelo ORM `RenewalAttachment` sobre PostgreSQL 17 desechable. Crea red Docker interna nueva, PostgreSQL efímero, dos volúmenes Docker de laboratorio para objetos y diario, migra únicamente la base temporal hasta `reminders.0018` y `renewal_attachments.0006`, guarda una ficha sintética y su objeto cifrado/intención. A continuación **lanza un segundo contenedor Django** conectado a los mismos recursos temporales y comprueba la recuperación, huella SHA-256 del texto descifrado, identidad de `storage_key` y consistencia con la ficha ORM. El trap elimina sus recursos nombrados; no elimina ni migra ninguna base persistente de DEV.

**Límites:** no es un ciclo transaccional integral autorizado (la prueba crea modelo, diario y objeto consecutivamente); no prueba fallo a mitad de operación, writers simultáneos, freeze global, servidor remoto ni backup operacional. La clave Fernet de ensayo se genera en el volumen efímero del propio laboratorio; **no es custodia externa**. Los montajes son volúmenes de ensayo, no destinos operativos. La restauración independiente sintética MB1 anterior se mantiene válida.

## Comprobación única en VPS IONOS

```bash
cd ~/vencira-localcheck
git pull --ff-only origin feature/c-ficha-independent-attachments
bash -n scripts/rehearse_mb1_integrated_durable_pg17.sh
sudo bash scripts/rehearse_mb1_integrated_durable_pg17.sh
echo "MB1_INTEGRATED_EXIT_CODE=$?"
```

Si falla, facilitar **solo** fase, error sin secretos y código de salida; no continuar con despliegue. Éxito esperado: `MB1_INTEGRATED_REAL_STORE_JOURNAL_PG17=OK`, `MB1_INTEGRATED_RECREATED_APP_CONSISTENT=OK`, `MB1_INTEGRATED_PG17_PRIVATESTORE_JOURNAL_PERSISTENCE=OK`, `MB1_INTEGRATED_RESULT=0`. Mantener `MB1_OPERATIONAL_RELEASE=NO`, `MB1_GLOBAL_FREEZE=NOT_VERIFIED`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

La etapa siguiente, tras PASS, es demostrar comportamiento fail-closed frente a una interrupción o escritura concurrente mediante el writer barrier ya existente y un ensayo con PG17/FS controlados.


## Incidencia de ejecución y corrección

La primera ejecución produjo `PermissionError: [Errno 1] Operation not permitted: '/lab/objects'` en fase `WRITE`, y `MB1_INTEGRATED_RESULT=1`. Causa: raíz de volumen Docker creada con propietario root frente al usuario no privilegiado de Django. Commit `c5100f9`: tras crear **exclusivamente** los dos volúmenes efímeros, obtiene UID/GID de la imagen Django y utiliza un contenedor aislado temporal con usuario root para ajustar propietario y permisos 0700. La prueba Django ahora verifica los permisos sin intentar modificarlos. No se cambian permisos ni volúmenes de DEV. **Corrección aún pendiente de validación**.
