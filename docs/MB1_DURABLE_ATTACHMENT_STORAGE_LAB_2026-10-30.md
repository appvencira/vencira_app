# MB1 — Persistencia independiente de objetos y diario (laboratorio)

**Fecha:** 30/10/2026. Implementado; **ejecución pendiente**.

Archivos:
- `deploy/mb1/compose.storage-lab.yaml`: Compose **totalmente separado** del Compose DEV, sin API Django, sin PostgreSQL, con red deshabilitada y dos volúmenes Docker específicos: `encrypted_objects` y `intake_journal`.
- `scripts/rehearse_mb1_storage_compose_disposable.sh`: crea un proyecto `mb1_lab_*` efímero, escribe bytes **sintéticos** y diario correlacionado, ajusta permisos privados, fuerza recreación del contenedor y verifica persistencia y hashes. El trap ejecuta `docker compose down --volumes` exclusivamente contra el proyecto efímero recién creado. No ejecuta `docker volume prune` ni toca los volúmenes `vencira_localcheck_postgres_data` o `vencira_preview_postgres_data`.

Los bytes opacos de ensayo **no representan un cifrado real**: este gate solo valida persistencia de montajes ante recreación, modo privado e integridad de bytes. No prueba Django, gestión de claves, capturas PG17/FS, recuperación externa ni bloqueo de escritores. La persistencia de adjuntos de DEV **no cambia** y `renewal_attachments` continúa sin instalar en DEV.

## Ejecución en VPS — prueba autónoma aislada

```bash
cd ~/vencira-localcheck
git pull --ff-only origin feature/c-ficha-independent-attachments
bash scripts/rehearse_mb1_storage_compose_disposable.sh
echo "MB1_STORAGE_LAB_EXIT_CODE=$?"
```

El usuario `vencira` actualmente necesita `sudo` para Docker; si falla antes de crear el proyecto por permisos, **no añadir usuario al grupo docker**. Ejecutar `sudo bash scripts/rehearse_mb1_storage_compose_disposable.sh` desde la misma carpeta únicamente después de confirmar el contenido del script y que no existe un proyecto ajeno llamado `mb1_lab_...`. No ejecutar mientras existan otro laboratorio con nombre coincidente. La descarga de `python:3.12-alpine` podría requerir acceso a Internet.

Éxito esperado: `MB1_STORAGE_LAB_INITIAL_WRITE=OK`, `MB1_STORAGE_LAB_CONTAINER_RECREATE_PERSISTENCE=OK`, `MB1_STORAGE_LAB_OBJECT_JOURNAL_HASH=OK`, `MB1_STORAGE_LAB_RESULT=0`. Mantener `MB1_STORAGE_OPERATIONAL_RELEASE=NO` y `MB1_GLOBAL_FREEZE=NOT_VERIFIED`.

## Próximo trabajo

Una vez validada persistencia a nivel de Compose, integrar `PrivateQuarantineStore` y `IntakeJournal` en una prueba de integración Django **separada y aislada**, junto a PostgreSQL 17 efímero, y comprobar estabilidad durante un corte consistente. No conectar aún almacenamiento al Compose DEV.
