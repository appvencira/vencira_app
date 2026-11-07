# VENCIRA — Handoff backend adjuntos, 07/11/2026

## Fuente y prioridad
Repositorio: `appvencira/vencira_app`. Rama: `feature/m3-android-local-notifications`. PR #17 (borrador, no fusionar como mecanismo de release). Leer también `docs/BACKEND_DEV_RELEASE_SPLIT_2026-11-07.md` y `docs/PROJECT_STATUS.md`. Este documento recoge el corte operativo para reanudar en un chat nuevo sin repetir gates superados.

## Evidencia real confirmada por operador
- Primer dry-run falló **antes** del autodetector por `ModuleNotFoundError: No module named 'cryptography'` al reutilizar imagen vieja con fuentes nuevas; el indicador `PARITY=NO` de esa primera ejecución no es evidencia de deriva.
- Ensayo corregido, imagen temporal de requisitos actuales: `ATTACHMENT_DRYRUN_IMAGE_BUILD=OK`, `ATTACHMENT_DRYRUN_MODEL_MIGRATION_PARITY=YES`, `No changes detected in app 'renewal_attachments'`, sin cambios de imagen API ni migraciones DEV.
- Ensayo PG17 desechable confirmado: `ATTACHMENT_PG17_IMAGE_BUILD=OK`, `ATTACHMENT_PG17_READY=YES`, `ATTACHMENT_PG17_INDEPENDENT_MIGRATE=OK`, `ATTACHMENT_PG17_BASELINE_0018=OK`, `ATTACHMENT_PG17_MFA_MIGRATIONS_APPLIED=0`, `ATTACHMENT_PG17_INDEPENDENT_ATTACHMENT_TABLE=OK`, `ATTACHMENT_PG17_ROLLBACK_SCHEMA=OK`, `ATTACHMENT_PG17_LIVE_CONTAINERS_UNCHANGED=OK`, `ATTACHMENT_PG17_REHEARSAL=PASS`, `ATTACHMENT_PG17_OPERATIONAL_RELEASE=NO`, `ATTACHMENT_PG17_LIVE_DB_MIGRATED=NO`.
- Esto demuestra paridad y reversibilidad **en entorno aislado y vacío**, no autorización para aplicar migraciones sobre DEV ni una restauración de datos representativos.

## Código preparado, NO validado en terminal
`scripts/backend_attachment_api_candidate_build.sh` (publicación reportada `e8f7d531`) extrae el backend histórico del checkout `/home/vencira/vencira-localcheck`, comprueba la igualdad de `reminders.0018`, trasplanta solo la app independiente y endpoints de metadatos, añade el router en carpeta temporal, conserva migraciones `reminders` 0001–0018, construye imagen aislada, ejecuta `manage.py check` sin red y comprueba identidades de contenedores. **No migrará ni desplegará** la API. El script contiene una guarda de digest fijo de la imagen API DEV; si la imagen no coincide, parar e investigar (no relajar la guarda).
 
## Próxima única acción en Ubuntu / Termius
Ejecutar en subshell (no afecta a la sesión SSH):

```bash
(
  cd ~/vencira-m3-localcheck || exit 1
  git fetch origin feature/m3-android-local-notifications &&
  git merge --ff-only FETCH_HEAD &&
  bash -n scripts/backend_attachment_api_candidate_build.sh &&
  bash scripts/backend_attachment_api_candidate_build.sh
  rc=$?
  echo "ATT_API_BUILD_RESULT=$rc"
)
echo "CONSOLA_ABIERTA"
```

Marcadores buscados: `ATT_API_CANDIDATE_HISTORICAL_MIGRATIONS=0018_ONLY`, `ATT_API_CANDIDATE_DJANGO_CHECK=OK`, `ATT_API_CANDIDATE_BUILD=PASS`, `ATT_API_CANDIDATE_LIVE_CONTAINERS_UNCHANGED=OK` y `ATT_API_BUILD_RESULT=0`. **No afirmarlos logrados antes de recibir salida**. Si falla, corregir script/fuente en GitHub y volver a ejecutar solo esta prueba.

## Siguiente bloque tras build PASS
Preparar vía GitHub gate con **la imagen candidata exacta** y PostgreSQL 17 desechable para `migrate --plan`, aplicación desde baseline 0018, tablas/resultados y rollback; probar rutas HTTP con identidad autenticada de ámbito correcto, acceso cruzado y anónimo, métodos de escritura denegados y no exposición de archivos; ejecutar regresiones y checks de migraciones. No trasladar flags `VENCIRA_ENV=test` a DEV. Un candidato funcional con solo lectura de metadatos no habilita archivos (subida, descarga, borrado todavía bloqueados).

Antes de cualquier autorización de actualización API DEV: copia O5 fresca y restauración ensayada, compatibilidad con web ya publicada, rollback operativo de imagen y esquema, aprobación explícita y ventana separada de despliegue/migración.

## Estado innegociable
`MFA_RELEASE_AUTHORIZED=NO`; `NO_DEPLOY_NO_LIVE_MIGRATION=1`. No `--fake`, no aplicar `reminders.0027`, no merge de PR #17 para publicar, no tocar PostgreSQL persistente, no activar MFA, no afirmar API desplegada.
