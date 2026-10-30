# MB1 — Experimento de barrera SQL (31/10/2026)

**Estado: implementado, no ejecutado.** Rama feature/c-ficha-independent-attachments.

El script scripts/rehearse_mb1_pg17_connection_fence_disposable.sh crea exclusivamente un contenedor PostgreSQL 17 nuevo sin red externa, rol de ensayo y base de ensayo. Aplica ALTER ROLE ... NOLOGIN al rol ordinario y comprueba que no puede abrir una conexión TCP nueva. Confirma deliberadamente que el administrador conserva acceso. Destruye el contenedor al salir; no toca volúmenes, proyectos VENCIRA ni O5.

**Limitación crítica:** NOLOGIN no corta sesiones abiertas, NO detiene administradores ni otros roles y no protege ficheros. Por tanto, **no es una barrera global apta para producción**. Este experimento prueba solo una propiedad acotada: denegación de conexión a un rol ordinario después de cambiarlo. Se requiere diseñar una puerta de mantenimiento para todos los escritores, gestionar sesiones en curso, evitar bypass y probar captura coherente de PostgreSQL y almacenamiento persistente.

Ejecutar en VPS, sin reiniciar servicios:

```bash
cd ~/vencira-localcheck
git pull --ff-only origin feature/c-ficha-independent-attachments
bash -n scripts/rehearse_mb1_pg17_connection_fence_disposable.sh
sudo bash scripts/rehearse_mb1_pg17_connection_fence_disposable.sh
echo "MB1_PG17_FENCE_EXIT_CODE=$?"
```

Esperado: MB1_PG17_NEW_WRITER_DENIAL=OK; MB1_PG17_ADMIN_BYPASS_CONFIRMED=OK; MB1_PG17_FENCE_RESULT=0. Los marcadores EXISTING_WRITER_DRAIN=NOT_VERIFIED, GLOBAL_FREEZE=NOT_VERIFIED y RELEASE_AUTHORIZED=NO deben persistir.

**M1-03 pendiente** (vías SQL y tareas fuera del control); **M1-04 pendiente** (barrera integral y captura restaurable). No tachar por publicar el código ni por aprobar este ensayo parcial.


## Resultado confirmado por operador — PASS parcial

`MB1_PG17_NEW_WRITER_DENIAL=OK`, `MB1_PG17_EXISTING_WRITER_DRAIN=NOT_VERIFIED`, `MB1_PG17_ADMIN_BYPASS_CONFIRMED=OK`, `MB1_PG17_FENCE_RESULT=0`, `MB1_PG17_FENCE_EXIT_CODE=0`. Asimismo `MB1_NONCOOPERATIVE_SQL_SUPERUSER=NOT_BLOCKED`, `MB1_FILESYSTEM_WRITERS=NOT_BLOCKED`, `MB1_GLOBAL_FREEZE=NOT_VERIFIED`, `MB1_RELEASE_AUTHORIZED=NO`. Prueba **únicamente** de denegación de conexión nueva a un rol ordinario, no un freeze. M1-04 sigue abierto.
