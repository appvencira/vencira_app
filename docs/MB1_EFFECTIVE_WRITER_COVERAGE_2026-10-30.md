# MB1 — Escritores efectivos y estrategia M1-03 / M1-04

30/10/2026. Revisión estática de código y evidencias del VPS. Sin cambios en servicios.

## Matriz de superficies

| Superficie | Evidencia | Consecuencia |
|---|---|---|
| API Django localcheck | compose.yaml ejecuta Gunicorn; reminders/urls.py incluye altas y cambios de renovaciones, usuarios, modalidades y recordatorios | Escritura PG17 operacional; no basta bloquear solo adjuntos |
| API preview | Segundo proyecto Docker, con PostgreSQL independiente; entrypoint histórico de migrate automático | No intervenir ni confundir con localcheck |
| API pública de adjuntos | reminders/attachment_api.py: POST y DELETE 403; listado GET; attachment_gate.py impide descargas | No hay escritura operativa de adjuntos por HTTP |
| Intake de ensayo | renewal_attachments/offline_intake.py bajo VENCIRA_ENV=test; advisory_barrier | Solo escritores cooperativos de laboratorio |
| PG17 advisory lock | offline_write_barrier_b06b.py | No protege contra escritores SQL que ignoran el lock |
| Objetos y diario | PrivateQuarantineStore e IntakeJournal, solo ensayos; ningún volumen de adjuntos en API DEV según inventario | No inventar almacén operacional activo |
| Redes Docker | Ambas DB sin puertos publicados; un network por servicio | La red Docker puede admitir conexiones SQL internas |
| Cron/O5 | Tres timers relevantes, cron del sistema y tres archivos cron.d | Comandos no inspeccionados; no detener backups |

## Brechas M1-03

1. Confirmar todas las rutas de escritura PostgreSQL: endpoints API, scripts de administración, tareas y clientes con acceso desde Docker.
2. Inspeccionar comandos de cron y unidades O5 de forma privada, sin reproducir secretos; revisar permisos PostgreSQL preferentemente en clon.
3. Identificar accesos de otros contenedores o usuarios a las redes y a volúmenes compartidos.
4. Registrar cómo se impedirá que entren nuevas escrituras y cómo se drenarán las existentes, sin afectar el backup O5.

## Arquitectura M1-04

Los advisory locks son cooperativos: NO proporcionan freeze global. Una captura consistente de PG17 + objetos requiere bloquear escritores operativos, esperar transacciones activas, verificar accesos externos y mantener la exclusión durante todo el snapshot. Probar primero con clones y restaurar en un segundo equipo. En DEV actual no hay adjuntos activos ni volúmenes operacionales de objetos en API; no declarar un snapshot integral de ficheros inexistentes.

M1-03=PARTIAL, M1-04=NOT_STARTED, MB1_GLOBAL_FREEZE=NOT_VERIFIED, MB1_OPERATIONAL_RELEASE=NO, NO_DEPLOY_NO_LIVE_MIGRATION=1.

No repetir censos de procesos o redes: revisar rutas efectivas de escritura y planificar una barrera operacional comprobable.


## Siguiente gate M1-03: inspección semántica de tareas (sin exponer comandos)

Commit `ec75257`: `scripts/inspect_mb1_effective_schedulers_readonly.sh` analiza localmente el contenido de `/etc/crontab`, ficheros regulares de `/etc/cron.d` y las unidades systemd `vencira-o5-backup.service` y `vencira-o5-health.service`; muestra **solo** categorías de coincidencias VENCIRA/SQL/OBJECT/EXEC y contadores, nunca comandos, variables, credenciales o el contenido completo. Es una clasificación heurística y puede omitir wrappers de shell o scripts invocados indirectamente. No inspecciona crontabs por usuario; no acredita ausencia de escritores ni autoriza freeze.

```bash
cd ~/vencira-localcheck
git pull --ff-only origin feature/c-ficha-independent-attachments
bash -n scripts/inspect_mb1_effective_schedulers_readonly.sh
sudo env MB1_EFFECTIVE_SCHEDULER_AUDIT=YES bash scripts/inspect_mb1_effective_schedulers_readonly.sh
echo "MB1_EFFECTIVE_SCHEDULER_EXIT_CODE=$?"
```

Esperar `MB1_SCHEDULER_AUDIT_RESULT=INVENTORY_ONLY` y código 0. M1-03 permanece abierto.


## Resultado de auditoría efectiva de planificadores — PASS parcial

El operador informa: `MB1_SCHEDULER_CRON_FILES=4`, `MB1_SCHEDULER_CRON_UNREADABLE=0`, `MB1_SCHEDULER_CRON_FLAGGED=0`; unidad O5 backup clasificada `VENCIRA,SQL,OBJECT`, unidad O5 health clasificada `VENCIRA`; `MB1_SCHEDULER_AUDIT_RESULT=INVENTORY_ONLY`, `MB1_EFFECTIVE_SCHEDULER_EXIT_CODE=0`. El clasificador buscó coincidencias, no ejecutó ni examinó el comportamiento completo de scripts indirectos. No se deduce que cron carezca de escritores. El temporizador O5 backup sí tiene relación con PostgreSQL/almacenamiento, y debe preservarse sin intervención. `MB1_SCHEDULER_SQL_PERMISSIONS=NOT_VERIFIED`, `MB1_SCHEDULER_WRITER_EXCLUSION=NOT_VERIFIED`, `MB1_GLOBAL_FREEZE=NOT_VERIFIED`. M1-03 sigue abierto.
