# VENCIRA — Auditoría de ramas y plan de cierre de `main`

**Corte:** 2026-11-08. **Destino único:** `appvencira/vencira_app:main`.
**Tipo de auditoría:** GitHub, comparación de refs, PR y comprobación de archivos/objetos concretos. **No equivale a revisión exhaustiva de cada línea de todas las ramas.**
**Regla:** preservar `main`, ninguna rama nueva, ningún merge masivo ni force push.

## A. Resumen ejecutivo y alcance

- Se localizaron **31 ramas** con la búsqueda de GitHub (una página con 31 elementos). Pueden subsistir ramas históricas por razones de trazabilidad.
- Las PR **#19 a #33**, que abarcan I1–I7 y los correctivos de adjuntos/autenticación, aparecen **closed + merged=true**. Esto es evidencia de integración en `main`, no certificación de las pruebas actuales.
- La PR **#17** continúa abierta en borrador; su base es `feature/mb1-m104-transition-contract-batch`, no `main`. No fusionarla completa. La PR #18, hacia `main`, continúa abierta y contiene un documento de planificación.
- Las PR históricas abiertas **#1, #4, #6, #7, #9, #10, #14, #15, #16, #17, #18** requieren clasificación antes de cerrar; no ejecutar merges automáticos.
- Comparaciones a la fecha, siempre en dirección `base=main, head=rama`: `feature/m3-android-local-notifications` **diverged / ahead 3946 / behind 46** al auditar, `feature/mb1-m104-transition-contract-batch` **ahead 2573 / behind 46**, `feature/c-ficha-independent-attachments` **ahead 2332 / behind 46**. Los números son de **genealogía Git** y NO representan funciones o archivos necesariamente ausentes.
- **Límite del método:** el endpoint de comparación devolvió un máximo visible de 300 archivos en ramas grandes. Una comparación histórica `diverged` no sustituye `git diff` de árboles completos ni un inventario exacto de todos los ficheros. Para cerrar la auditoría exhaustiva es obligatorio el gate del apartado F.

## B. Ramas por familia: tratamiento propuesto

| Rama o familia | Hallazgo | Acción |
| --- | --- | --- |
| `main` | Rama destino con cambios propios. Incluye PR I1–I7 y lotes recientes de I8. | Mantener como única rama de integración. |
| `integration/i1-*`, `integration/i2-*`, `integration/i3-*` a `integration/i7b-*` | Sus PR #19–#31 están fusionadas. Archivo representativo de calendario, foundation, HTTPS y MFA idéntico por SHA a `main`. | No repetir merges; revisar diferencias residuales solo si surgen en inventario por contenido. |
| `integration/main-web-attachments-failclosed-20261107` | PR #32 fusionada; `renewal_detail_screen.dart` tiene SHA idéntico. | Conservar corrección de adjuntos; no volver a fusionar. |
| `integration/native-auth-lab-gates-20261107` | PR #33 fusionada; dos scripts de contrato I7 idénticos por SHA. | No repetir merge. |
| `integration/main-progressive-20261106` | PR #18 aún abierta; diferencia documental `docs/MAIN_PROGRESSIVE_INTEGRATION_2026-11-06.md`. | Incorporar solo información todavía válida, no fusionar contenido obsoleto. |
| `feature/m3-android-local-notifications` | Referencia histórica principal I8/G7–G15; PR #17 abierta y divergente. | Extraer archivos faltantes verificando dependencias, límites de seguridad y gates. |
| `feature/mb1-m104-transition-contract-batch` | Seguridad MB1/M104, evidencias y gates; historial largo y divergente. | Auditar scripts/contratos residuales sin sustituir módulos existentes. |
| `feature/c-ficha-independent-attachments` | Ficha, adjuntos y ensayos de cifrado/seguridad; parte ya en I2-D. | Revisar alcance de adjuntos y pruebas de autorización antes de considerar cerrado. |
| `feature/m3-02-agenda-operational-validation`, `feature/m3-device-notice-preview-ci` | Agenda operativa y notificaciones de candidato. | Comparar tests, contratos y documentación restante. |
| `feat/*` (i18n, identidad de póliza, notas, personas, equipo, agenda) | Funciones base presentes en `main` por integración Django/Flutter, no toda la diferencia histórica auditada. | No suponer cierre funcional sin comparar API, migraciones, cobertura y UI. |
| `integration/local-e2e-prep`, ramas iniciales `chore/*` | Historial de bootstrap/laboratorios. | Referencia secundaria, no destino de merges. |

## C. Integración constatada en main

**I1–I7:** I1 calendario/planificación, I2 Django/reminders/Flutter/C-FICHA/laboratorios, I3 gate integral, I4 HTTPS PG17, I5 Chromium/Android, I6 emulador y I7 contratos de emisión/MFA candidato. La afirmación es **código/PR integrado**, no ejecución actual de todas las suites.

**Módulos funcionales comprobados presentes:**
- `backend/reminders/agenda_month.py`, `reminder_planning.py`, `operational_inbox.py`, `operational_transitions.py`, `device_notice_preview.py`, `person_suggestions.py`.
- `backend/reminders/attachment_api.py`, `backend/renewal_attachments/models.py`, `clients/flutter/lib/ui/renewal_detail_screen.dart` (la última coincide por SHA con la PR #32).
- `clients/flutter/lib/l10n/app_es.arb` y `app_ca.arb`, `clients/flutter/lib/api/native_api_transport.dart`, `native_mobile_recovery_entry.dart`, `native_session_coordinator.dart`.
- `clients/flutter/lib/main.dart` y `backend/config/urls.py` son **idénticos por SHA** a la rama histórica #17. No se han conectado endpoints de recuperación nativa a la app operativa.

**I8 integrado directamente en main durante el 08/11/2026:**
- Corrección de aceptación indebidamente permisiva de tokens password-only en `native_http_auth_port.dart` y `native_recovery_login_gateway.dart`; test `native_i8l_http_recovery_integration_test.dart`. Evidencia del operador **Flutter pub get PASS; analyze=0; seis tests I8-L PASS** en copia temporal de `main` revisión `d2015389`.
- Formato canónico `candidate_challenge_wire.py` con test; operador reportó **6/6 tests PASS** en `main` revisión `257502ab`.
- Modelo `MobilePendingChallenge` añadido sin reemplazar modelos anteriores y migración candidata `0005_mobilependingchallenge.py` **versionada, no aplicada**.
- `candidate_challenge_store.py`, `candidate_two_step_issuer.py`, `candidate_recovery_issuer.py`; tests I8-B/C/I/J/K y vistas/URLconf **test-only** incorporadas. `test_i8k_recovery_http_pg17.py` y `candidate_recovery_issuer.py` tienen SHA idénticos a origen histórico.
- `scripts/native_i8k_https_server.py` incorporado (solo laboratorio). No se habilitó en `config.urls`.

**Corrección adicional descubierta en esta auditoría:** `backend/config/settings.py` difería de la fuente I8 únicamente en **489 caracteres**: faltaba leer claves HMAC sintéticas de abuso/auditoría G5 bajo `VENCIRA_ENV=test` y `VENCIRA_NATIVE_SERVICE_CANDIDATE=1`. Integrado **directamente en main**, commit **`b095531e23720d55b48e5ce5c172e84e6b44fce2`**; el nuevo blob coincide exactamente con el histórico `74af4f1e0d800d27c18c0a3960830615ad5cf405`. En desarrollo/producción las claves permanecen `None`. **Pruebas del cambio pendientes**.

**Muestras de identidad SHA entre main y ramas originales:** `scripts/test_i1_calendar_core.py`, `scripts/i2_main_foundation_gate.py`, `scripts/i4_https_proxy.py`, `scripts/native_i7_atomic_mfa_pg17_isolated.sh`, `scripts/native_vs_web_auth_contract_readonly.py`, `clients/flutter/lib/ui/renewal_detail_screen.dart` y `backend/native_mobile_service/g14_e2_atomic_mfa_candidate.py`. Es evidencia muestreada, no auditoría total.

## D. Ausencias verificadas y bloqueos

| Área | Ausencia concreta en main | Prioridad / tratamiento |
| --- | --- | --- |
| I8-B/C/I/J | `scripts/native_i8b_pending_challenge_pg17_isolated.sh`, `native_i8c_two_stage_pg17_isolated.sh`, `native_i8i_negative_policy_pg17_isolated.sh`, `native_i8j_atomic_recovery_pg17_isolated.sh` | Alta: adaptar/revisar ejecutores para `main`, DB PG17 desechable y comprobar código antes de PASS. |
| I8-K HTTP | `scripts/native_i8k_recovery_http_pg17_isolated.sh` | Alta: gate HTTP de recuperación PG17 test-only. |
| I8-K HTTPS | `scripts/native_i8k_https_probe.py` y `scripts/native_i8k_real_https_pg17_isolated.sh` | Alta: **incompleto**; la publicación del probe fue bloqueada por controles de seguridad de la herramienta. No eludir bloqueo ni lanzar runner no revisado. |
| I8-L | `scripts/native_i8l_flutter_recovery_adapter_gate.sh` | Media: el gate específico ya se ejecutó por procedimiento temporal alternativo; registrar runner reproducible seguro en lugar de copiar sin evaluación el histórico. |
| Flutter HTTPS antiguo | `clients/flutter/test/native_i8f_https_live_test.dart` | Media: revisar dependencia de laboratorio; no confundir con I8-M. |
| I8-M | No se localizó `scripts/native_i8m_flutter_https_recovery_gate.sh` ni en `main` ni en la rama histórica examinada. | Alta tras cerrar PG17/I8-K: diseñar nuevo gate Flutter TLS auténtico sin downgrade de CA/hostname. |
| Documentos históricos | `docs/PROJECT_STATUS.md` (~100 KB), `docs/CONTINUITY_RUNBOOK.md` (~269 KB), `docs/I8J_ATOMIC_RECOVERY_PG17.md`, `docs/I8K_RECOVERY_HTTP_HTTPS_PG17.md`, `docs/I8L_FLUTTER_RECOVERY_ADAPTER_GATE.md` | Importar/selectivamente resumir decisiones vigentes; **no copiar como estado actual**, contienen hitos y advertencias de fechas diferentes. |

No se debe afirmar que **todos** los demás scripts, funciones o tests estén integrados; faltan verificaciones completas del conjunto de 335 archivos de la PR #17 y de las 119 entradas de la PR #14. Otras ramas grandes y las funciones antiguas precisan una comparación de árboles.

## E. Backlog de cierre y criterios de aceptación

1. **B0 — Integridad:** inventario exacto `git diff --name-status main...branch` y `git diff --name-status main branch` de las ramas grandes; distinguir genealogía, árbol y archivos; nunca usar `git reset --hard` ni `git clean -fd`. Conservar `main` y artefactos locales; limpiar `__pycache__` solo después de verificar qué se borra.
2. **B1 — Python / configuración:** `python3 -m compileall`, tests `candidate_challenge_wire`, comprobación de `VENCIRA_G5_*_KEY` ausentes por defecto y solo cargadas para `test + candidato`; no exportar secretos al log.
3. **B2 — PostgreSQL17 desechable:** build de imagen de pruebas no operativa, red Docker interna, PG17 temporal sin volúmenes persistentes, migraciones **solo** en contenedor DB desechable, `makemigrations --check --dry-run`, test I8-B/C/I/J y contrato I8-K. Bloquear deploy y rutas productivas. Verificar identidades de contenedores DEV antes/después.
4. **B3 — I8-K HTTPS:** completar revisión del laboratorio, CA sintética temporal, verificación obligatoria de nombre de servidor, negativos de CA no confiable y hostname erróneo; sin puertos host publicados. **No intentar usar un probe bloqueado**; requerirá revisión compatible con controles de seguridad.
5. **B4 — Flutter:** suite completa `flutter test` sobre `main`, `flutter analyze`, gates de adapter/vault/journal. I8-M exige cliente Flutter HTTP real con backend I8-K en PG17 efímero, respuesta ambigua cerrada, refresh revocado y sin TLS permisivo.
6. **B5 — Android físico:** recuperación tras reinicio/almacenamiento Keystore y revocación real del dispositivo; separar de PASS de I8-H (login inicial).
7. **B6 — Producto y seguridad transversal:** revisar agenda, avisos, C-FICHA adjuntos, autorización y cifrado, límites MB1, políticas de usuario sin MFA y UI/visual. Comparar archivos y tests contra ramas restantes; no inferir que cada feature funciona por su presencia.
8. **B7 — Cierre:** matriz única de archivos realmente pendientes, suites PASS en SHA exacto de `main`, registros, README/handoff actualizados y **solo después** decidir archivo/cierre de PR históricas sin borrar ramas ni perder información.

## F. Auditoría de árboles completa requerida en VPS (lectura, sin merges)

Un worktree aislado de `main` ya existe en `~/vencira-main-check-20261108`. Tras limpiar únicamente caches `__pycache__` generadas por Python, conservar su worktree en estado limpio. Ejecutar en él:

```bash
cd ~/vencira-main-check-20261108
git fetch origin '+refs/heads/*:refs/remotes/origin/*'
git status --short
git rev-parse HEAD
for b in feature/m3-android-local-notifications feature/mb1-m104-transition-contract-batch feature/c-ficha-independent-attachments feature/m3-02-agenda-operational-validation feature/m3-device-notice-preview-ci; do
  echo "=== $b: TREE vs TREE ==="
  git diff --stat origin/main "origin/$b" -- backend/ clients/flutter/ scripts/ docs/
  echo "=== $b: NAME STATUS ==="
  git diff --name-status origin/main "origin/$b" -- backend/ clients/flutter/ scripts/ docs/
done
```

**No confundir** `git diff origin/main origin/branch` (árbol final contra árbol final) con `git diff origin/main...origin/branch` (cambios de rama desde ancestro común). Registrar ambos cuando una diferencia sea dudosa. Este gate puede generar mucha salida; **redirigir a archivos externos al worktree**, conservarlos, y producir recuentos por directorio/estado. No mover HEAD ni crear ramas.

## G. Restricciones permanentes

```text
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```

- GitHub `main` es destino de código, no despliegue. Nada de `docker compose up` sobre proyectos DEV, `manage.py migrate` sobre DB persistentes, habilitación de MFA operativo ni rutas de emisión test-only.
- No se han ejecutado tests de VPS ni migraciones en el curso de **esta auditoría documental**. La corrección de `settings.py` queda pendiente de gates sobre el nuevo SHA.
- Ninguna de las ramas se ha eliminado ni fusionado masivamente.

## H. Inventario reproducible de árboles (publicado en main)

`scripts/main_branch_tree_inventory_readonly.py` compara todos los objetos de los árboles de `origin/main` y de las ramas `origin/*`, incluyendo modos, tipos y SHA de cada archivo. **No** invoca `fetch`, modifica refs, crea ramas, ejecuta Docker ni escribe archivos del repositorio. A diferencia del endpoint de GitHub, no limita la comparación a 300 rutas. Se comprobó su comportamiento con un repositorio sintético local (un archivo modificado y otro añadido); sigue **pendiente de ejecución sobre las ramas reales de VENCIRA**.

```bash
cd ~/vencira-main-check-20261108
git fetch origin '+refs/heads/*:refs/remotes/origin/*'
python3 scripts/main_branch_tree_inventory_readonly.py \
  --summary-only > /tmp/vencira-main-branch-summary-20261108.json
python3 scripts/main_branch_tree_inventory_readonly.py \
  > /tmp/vencira-main-branch-full-20261108.json
python3 - <<'PY'
import json
p = '/tmp/vencira-main-branch-summary-20261108.json'
data = json.load(open(p, encoding='utf-8'))
print('MAIN_AUDIT_BASE=' + data['base_commit'])
for b in data['branches']:
    print(b['ref'], b['counts'])
print('MAIN_AUDIT_BRANCHES=' + str(len(data['branches'])))
PY
git status --short
```

Los JSON se crean en `/tmp` fuera del worktree. **Revisar antes de compartirlos** por si revelan nombres de archivos privados, aunque el informe no contiene su contenido. La auditoría completa permitirá priorizar diferencias restantes por árbol, no por conteo de commits.

## I. Evidencia del operador — inventario completo de 30 ramas (08/11/2026)

El operador ejecutó `scripts/main_branch_tree_inventory_readonly.py --summary-only` en el worktree independiente. Reportó `MAIN_AUDIT_BASE=2a23873c697ec41c6b6c4dec02e91c9842043cca`, `MAIN_AUDIT_BRANCHES=30` y `git status --short` sin salida. El inventario de objetos completo se ejecutó satisfactoriamente sobre las ramas remotas.

| Origen comparado con main | `added_in_branch` | `absent_in_branch` | `different` |
| --- | ---: | ---: | ---: |
| `feature/m3-android-local-notifications` | 543 | 38 | 7 |
| `feature/mb1-m104-transition-contract-batch` | 409 | 197 | 23 |
| `feature/c-ficha-independent-attachments` | 356 | 237 | 37 |
| `feature/m3-02-agenda-operational-validation` | 402 | 223 | 27 |
| `feature/m3-device-notice-preview-ci` | 404 | 220 | 24 |
| `integration/local-e2e-prep` | 197 | 371 | 48 |
| `integration/main-web-attachments-failclosed-20261107` | 0 | 25 | 5 |
| `integration/native-auth-lab-gates-20261107` | 0 | 23 | 5 |
| `integration/i7b-mfa-atomic-candidate-20261106` | 0 | 25 | 7 |

**Semántica:** `added_in_branch`: archivo exclusivo de rama; `absent_in_branch`: exclusivo de main; `different`: existe en ambas revisiones pero difiere objeto/modo. Estos números NO representan automáticamente código necesario. Los JSON detallados permanecen en el VPS y no han sido compartidos.

**Próxima auditoría:** obtener exactamente las 7 rutas diferentes de Android y agrupar sus 543 archivos exclusivos por carpeta/extensión. Clasificar su valor y dependencias antes de copiar. Después revisar MB1, C-FICHA y M3 por prioridad. No realizar merges masivos.

## J. Reconciliación del listado I8 aportado por el operador — 08/11/2026

El operador aportó los nombres de **17 scripts `native_i8*` exclusivos de `feature/m3-android-local-notifications`**. El 08/11 se integraron directamente en `main` **7 ejecutores**, en commits individuales:

| Gate de laboratorio | Ruta | Alcance | Commit |
| --- | --- | --- | --- |
| Wire lc1 | `scripts/native_i8_challenge_wire_unit.sh` | Python, sin Docker ni DB. Marcador histórico `DURABLE_CHALLENGE_STORAGE=NOT_IMPLEMENTED` sustituido por `NOT_TESTED_BY_THIS_GATE` para no mentir sobre el estado I8-B. | `eea3c13a` |
| I8-B | `scripts/native_i8b_pending_challenge_pg17_isolated.sh` | PG17 `--tmpfs`, red interna, pruebas de desafío | `bd361630` |
| I8-C | `scripts/native_i8c_two_stage_pg17_isolated.sh` | PG17 aislado, contraseña->MFA | `424d8acf` |
| I8-D | `scripts/native_i8d_http_contract_pg17_isolated.sh` | HTTP candidato test-only; no URL operacional | `33e88eea` |
| I8-I | `scripts/native_i8i_negative_policy_pg17_isolated.sh` | Negativos MFA; eliminado subgate Flutter que escribía en source y creaba volumen persistente | `e1f10df1` |
| I8-J | `scripts/native_i8j_atomic_recovery_pg17_isolated.sh` | Recuperación atómica PG17, **solo backend**; Flutter separado | `7591df20` |
| I8-K HTTP | `scripts/native_i8k_recovery_http_pg17_isolated.sh` | Contrato HTTP PG17, **solo backend**, no HTTPS; Flutter separado | `e1a1fd4b` |

Los scripts PG17 originales verifican el estado de contenedores DEV por identidad, construyen imagen de laboratorio, red Docker `--internal`, contenedor `postgres:17-alpine` con directorio de datos `--tmpfs`, migraciones exclusivamente allí y borrado al terminar. **Esta inspección estática no garantiza que todos los comandos se comporten correctamente al ejecutarlos; se requiere preflight y gate local.** No se han lanzado ni ejecutado migraciones reales durante esta integración GitHub.

**10 scripts I8 pendientes:** `native_i8e_https_probe.py`, `native_i8e_https_server.py`, `native_i8e_real_https_pg17_isolated.sh`, `native_i8f_flutter_https_pg17_isolated.sh`, `native_i8g_android_batch.sh`, `native_i8g_android_vault_static_gate.sh`, `native_i8h_android_https_pg17_lab.sh`, `native_i8k_https_probe.py`, `native_i8k_real_https_pg17_isolated.sh`, `native_i8l_flutter_recovery_adapter_gate.sh`. **I8-K HTTPS sigue bloqueado por la publicación restringida del probe en la sesión anterior**: no sortear el bloqueo. El viejo I8-L puede ser reemplazado por gate aislado que ya dio PASS en el VPS, pero falta comprobar suites relacionadas. Android I8-G/H mantiene los gates históricos, no se consideran aprobados en la revisión nueva de main.

**Nuevo punto de partida:** ejecutar primero `bash -n` para los seis shells PG17 integrados, confirmar `git status` limpio, verificar disponibilidad/identidad de `vencira_localcheck` y `postgres:17-alpine`, y solo después ejecutar **I8-K HTTP (subsumirá I8-I/J) sobre PG17 desechable** en una sesión `tmux` o mediante `nohup` con logging y retorno persistente, sin cerrar Termius. No considerar los marcadores de éxito hasta revisar resultado de los tests, el código de salida y la comprobación de contenedores DEV.

## K. Limpieza progresiva de referencias y directorios (08/11/2026)

**Solicitud del operador:** depurar ramas GitHub innecesarias y directorios locales sin pérdida de información.

**Clasificación confirmada:** PR #19–#33, exactamente **15 PR**, aparecen `closed`, `merged=true`, `base=main`, con `head` correspondiente a 15 ramas `integration/*`. Son candidatas a borrar como **referencias remotas**, porque el código de las PR fue incorporado a `main`, y el inventario completo informó `added_in_branch=0` en las ramas de integración auditadas. La diferencia de archivos respecto al `main` actual no demuestra necesidad de mantener la referencia. La PR sigue accesible como historia al eliminar la rama, aunque se pierde comodidad de navegación por su nombre.

**Operación preparada, no ejecutada:** `scripts/main_merged_branch_cleanup_guarded.sh` (commit `489ddd54`). Por defecto hace `--dry-run`. Comprueba repo exacto, worktree limpio, `HEAD=origin/main`, SHA remoto, ausencia de archivos exclusivos en cada árbol y ausencia de worktree local de esa rama. `--apply` usa un `--force-with-lease` exacto para borrar solo ramas candidatas si siguen en SHA verificado. **Ningún borrado remoto realizado desde esta sesión.** Si fallan permisos/protecciones, no desactivar protecciones ni forzar el repositorio. Las ramas históricas `feature/*`, `feat/*`, `integration/local-e2e-prep` y PR abiertas quedan excluidas expresamente.

**Directorio local:** no hay inventario recibido de `~/vencira-*`, `git worktree list`, contenedores, volumenes, `/opt`, copias de seguridad ni archivos sueltos. **No borrar directorios a ciegas.** Revisar primero con `git worktree list --porcelain`, `find "$HOME" -maxdepth 1 -type d -name 'vencira*' -print` y `du -sh` para cada candidato, comparar con rutas activas y confirmar que no albergan archivos no versionados, configuraciones, secretos ni logs necesarios. Preferir `git worktree remove` solo para worktrees realmente innecesarios y limpios; **nunca** usar `rm -rf ~/vencira*`, `git clean -fdx` ni `docker system prune --volumes`.

**Secuencia:** ejecutar dry-run y revisión de carpetas primero; borrar referencias remotas por lote controlado con `--apply` después de revisar la salida; verificar `git ls-remote origin`, `git status` y dejar evidencia en este documento. Esto no es gate de release ni habilita MFA.

## L. Limpieza GitHub efectuada y directorios inventariados (evidencia del operador, 08/11/2026)

El operador ejecutó `scripts/main_merged_branch_cleanup_guarded.sh --apply` tras `--dry-run` con **15/15 `ELIGIBLE`** y cero rechazadas. Resultado de ejecución comunicado: `BRANCH_CLEANUP_DELETED=15`, `BRANCH_CLEANUP_SKIPPED=0`, `BRANCH_CLEANUP_DONE=YES`, `CLEANUP_APPLY_EXIT=0`. **Limpieza remota de las 15 ramas `integration/*` de PR #19–#33 completada según la salida del operador.** El comando `git fetch --prune` y la inspección posterior de ramas remotas no se han mostrado aún, por lo que la confirmación independiente del estado remoto sigue pendiente. No borrar ninguna rama adicional por el momento.

**Worktrees observados:**
- `/home/vencira/vencira-localcheck`, HEAD `64e936b9`, rama `feature/c-ficha-independent-attachments` (162 MiB): **conservar**, rama C-FICHA aún con auditoría pendiente.
- `/home/vencira/vencira-m3-localcheck`, HEAD `f750bbbf`, detached (3.8 GiB): **conservar por ahora**, es la base de pruebas M3/Android y puede albergar artefactos/builds necesarios.
- `/home/vencira/vencira-main-check-20261108`, HEAD `5a35e96e`, detached (4.4 MiB): **conservar**, worktree de consolidación de `main`.
- `/tmp/vencira-suggestions.RIC9UU/source`, HEAD `e390130e`, marcado `prunable`: **candidato a `git worktree prune` tras dry-run**; la operación elimina registros administrativos de worktrees obsoletos, no directorios activos.

**Directorios adicionales observados:** `vencira-m3-android-build` (2.1 GiB), `vencira-m3-clean` (1.1 GiB), `vencira-m3-results` (1.1 MiB), `vencira-preview` (1.3 MiB), `vencira-export` (8 KiB), `vencira-backups` (124 KiB), `vencira-db-backups` (904 KiB), `vencira-local-backups` (36 KiB) y `~/vencira-android-tree-detail.json` (132 KiB). **Ninguno de esos directorios se ha borrado.**

**Clasificación provisional:** conservar `*-backups`, `*-db-backups`, `*-local-backups`, `*-export` y los tres worktrees funcionales. Revisar si `vencira-m3-android-build` y `vencira-m3-clean` son copias reconstruibles o incluyen scripts/artefactos únicos antes de borrar; podrían liberar hasta ~3.2 GiB según `du -sh`, pero no existe autorización técnica para eliminarlos sin inspección. `vencira-m3-results` puede contener evidencias de pruebas que deben archivarse.

**Próximo gate de limpieza local — exclusivamente lectura:** inspeccionar `git worktree prune -n -v`, `git status --porcelain`/origen en cada directorio si es repo, `du -sh` de sus subcarpetas, antigüedad de archivos, actividad de procesos Docker/Termius y presencia de archivos no versionados o ignorados. Los tamaños por sí solos **no justifican** `rm -rf`. Para el registro `prunable` puede utilizarse `git worktree prune -v` después de confirmar que la ruta temporal no existe ni está montada.

## M. Auditoría adicional de copias Android locales (evidencia del operador)

Comprobaciones del operador (08/11/2026):
- `/home/vencira/vencira-m3-android-build`: **2.1 GiB**, no se reconoce como worktree/repositorio Git. Distribución: `build/` ~2.0 GiB; `.dart_tool/` ~108 MiB; `android/` 4.7 MiB; `lib/` 724 KiB; `test/` 336 KiB; `.idea/` 32 KiB y `web/` 12 KiB. **Candidato a limpiar únicamente artefactos generados** después de confirmar que no hay builds/APK de laboratorio en uso ni archivos no reproducibles. No eliminar el directorio completo de entrada.
- `/home/vencira/vencira-m3-clean`: **1.1 GiB**, repositorio Git independiente en `feature/m3-android-local-notifications` HEAD `73fb358`; `clients/flutter/pubspec.lock` está **sin seguimiento** (`??`). `clients/` ocupa 1.1 GiB. **Conservar** hasta comparar archivos no versionados, fuentes y utilidad como clon de reconstrucción. No ejecutar `git clean -fdx` ni `rm -rf` sobre este repositorio.
- `vencira-m3-localcheck` ~3.8 GiB: worktree registrado, conservar mientras se prueban I8-K/Android; `vencira-main-check-20261108` ~4.4 MiB: worktree de `main`, conservar.
- No consta todavía limpieza de archivos locales, ni resultado de `git worktree prune -n -v`, ni inventario de procesos que dependan de la carpeta `build/`.

**Acción próxima:** revisar `find .../build -maxdepth 3 -type f`, APKs y procesos asociados y confirmar que no se necesitan los artefactos anteriores. Si son regenerables, limpiar solo `build/` y opcionalmente `.dart_tool/` usando `flutter clean` desde `vencira-m3-android-build`, cuando el proyecto Flutter sea válido; documentar el espacio recuperado. Los archivos fuente y los repositorios se conservan.

## N. APK Android preservada y limpieza de build comunicada (08/11/2026)

El operador confirmó SHA-256 idéntico para las dos APK de depuración originales y una tercera copia archivada:

```text
003adcad627c953df281e034a530795bca4ea8160f8c3e5d101818117167deb4
```

Copia conservada: `/home/vencira/vencira-m3-results/apk-conservadas/VENCIRA-Android-LAB-debug.apk`, tamaño ~155 MiB. No hay Flutter CLI en el host (`FLUTTER_NO_INSTALADO_EN_HOST`). Se propuso un borrado acotado de `/home/vencira/vencira-m3-android-build/build` tras verificar SHA-256 de la copia; el operador respondió **"Done"**. **Estado de la limpieza: comunicada como ejecutada, sin salida postoperación ni tamaño de directorio actualizado**; no declarar `ANDROID_BUILD_CLEANUP=PASS` hasta ver marcador o evidencia. La copia APK y los tres worktrees de desarrollo deben preservarse.

Espacio libre antes de la limpieza: `/dev/vda1` 232 GiB total, 56 GiB usados, 176 GiB disponibles (25% uso). Recuperar ~2 GiB no era una operación urgente. Siguiente prioridad: comprobar salud de los contenedores DEV y lanzar únicamente I8-K HTTP en laboratorio PG17 efímero, registrando resultado en el SHA exacto de `main`.

## O. Corrección de bloqueo I8-K en construcción Docker (08/11/2026)

**Evidencia del operador:** tras comprobar los 3 contenedores `vencira_localcheck` en estado `running/healthy`, el laboratorio `scripts/native_i8k_recovery_http_pg17_isolated.sh` terminó con `NATIVE_I8K_LOCAL_RESULT=1`, manteniendo `NATIVE_I8K_DEV_CONTAINERS_UNCHANGED=OK`, `NATIVE_I8K_DEPLOY_EXECUTED=NO`, `NATIVE_I8K_LIVE_MIGRATIONS_EXECUTED=NO`, `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`. Mensaje causal real: `ERROR: failed to build: failed to solve: failed to read dockerfile: open Dockerfile: no such file or directory`.

**Diagnóstico confirmado con GitHub:** el script invoca `docker build -t ... ./backend`; en `main` faltaba `backend/Dockerfile`, aunque sí estaba `backend/requirements.txt` y en `feature/m3-android-local-notifications` existía el Dockerfile. El fallo se produjo **antes** de ejecutar migraciones o tests de Django; no es un fallo de recuperación, HTTPS ni PostgreSQL.

**Corrección publicada directamente en main:**
- `backend/Dockerfile`, copia fiel del Dockerfile histórico de laboratorio/Django: commit `2ce7943cf29aae2c72302fd57a7e669fb8099eff`.
- `backend/.dockerignore`, nuevo, para excluir secretos locales `*.pem`, `*.key`, `.env`, bases de datos, logs y cachés del contexto Docker: commit `b80e09abf0f845adb055debbc846974a713c8165`.

**Estado:** corrección de fuentes y contexto **integrada, todavía no verificada con Docker build**. No confundir con un PASS de I8-K. Repetir el script tras `git fetch` y `git merge --ff-only` de `origin/main`; con `tmux` y `set -o pipefail` guardar el error real si persiste. Comprobar `NATIVE_I8K_LOCAL_RESULT=0`, `MAIN_I8K_HTTP_RESULT=0` y marcadores de aislamiento. No se ha hecho ningún despliegue ni migración persistente desde esta integración GitHub.

## P. Gate I8-K HTTP en PostgreSQL 17 — VALIDADO (evidencia operador 08/11/2026)

Tras restaurar `backend/Dockerfile` y añadir `backend/.dockerignore`, el operador repitió `scripts/native_i8k_recovery_http_pg17_isolated.sh` en el checkout `~/vencira-main-check-20261108`. Salida comunicada:

```text
Ran 42 tests in 26.444s
OK
NATIVE_I8K_FLUTTER_GATE=NOT_RUN_SEPARATE
NATIVE_I8K_NO_PUBLIC_ISSUER=PASS
NATIVE_I8K_NO_MFA_DENIAL_POLICY=PASS
NATIVE_I8K_ATOMIC_RECOVERY_CORE=PASS
NATIVE_I8K_RECOVERY_HTTP_JSON=PASS
NATIVE_I8K_RECOVERY_ENDPOINTS_ABSENT=PASS
NATIVE_I8K_PG17_HTTP_RECOVERY_GATE=PASS
NATIVE_I8K_DEV_CONTAINERS_UNCHANGED=OK
NATIVE_I8K_DEPLOY_EXECUTED=NO
NATIVE_I8K_LIVE_MIGRATIONS_EXECUTED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
NATIVE_I8K_LOCAL_RESULT=0
```

**Interpretación:** backend test-only I8-K HTTP, I8-I e I8-J y regresiones asociadas validados en PG17 desechable; 42/42 tests PASS. Los tres contenedores DEV quedaron sin cambios según el guard del script. El usuario no adjuntó el SHA exacto ejecutado tras el último `git fetch`, aunque el gate se realizó después de los commits de corrección `2ce7943c` y `b80e09ab`. El marcador externo `MAIN_I8K_RECHECK_RESULT` no figura en la salida, pero el propio `NATIVE_I8K_LOCAL_RESULT=0` sí.

**No cubierto:** Flutter en esta ejecución (`NOT_RUN_SEPARATE`), TLS de recuperación I8-K HTTPS, cliente Flutter HTTPS real I8-M, Android físico ni autorización de despliegue. Mantener `MFA_RELEASE_AUTHORIZED=NO` y `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

**Siguiente puerta de calidad:** correr Flutter `analyze` y suite de recuperación/adapter aisladas, sin escribir en worktree ni crear volúmenes permanentes; después diseñar/verificar HTTPS I8-K sin reutilizar el probe cuya publicación quedó bloqueada.

## Q. Regresión Flutter I8-L ampliada: 3 tests heredados desalineados (08/11/2026)

El operador ejecutó una selección ampliada de tests Flutter sobre la copia temporal de `main`. Resultado `MAIN_I8L_FLUTTER_RESULT=1`: tres fallos del conjunto y `Some tests failed`. Los tests fallidos fueron:
1. `native_mobile_recovery_entry_test.dart`: `orphan refresh routes exclusively through full recovery`.
2. `native_recovery_login_gateway_test.dart`: `fresh password recovery persists new refresh before access`.
3. `native_recovery_login_gateway_test.dart`: `storage write ignored after grant rejects session and attempts revoke`.

**Causa técnica confirmada por revisión de tests/implementación:** esos tres tests aún daban por válido `NativePasswordGranted` (tokens entregados tras contraseña) para activar sesión recuperada. La versión I8-L de `NativeRecoveryLoginGateway.verifyPassword()` rechaza **intencionalmente** cualquier `NativePasswordGranted` y acepta exclusivamente `NativePasswordMfaRequired`; los tokens pasan por `_confirm()` solo tras `recoverMfa`. El control seguro es correcto; NO retirar la restricción por complacer las expectativas antiguas de los tests.

**Correcciones directas en main:**
- Commit `8532a639`: `native_mobile_recovery_entry_test.dart` se actualizó para exigir desafío MFA, verificar que no se desbloquea el acceso antes de TOTP y confirmar tokens solo después de `verifyTotp`; se añadió negativo explícito que exige rechazar `NativePasswordGranted`.
- Commit `f3e9dfff`: `native_recovery_login_gateway_test.dart` ahora exige MFA antes de persistir nuevo refresh, y simula fallo de almacenamiento **después** del paso MFA para verificar revocación; añadido negativo explícito de password-only.

**No se ha modificado el código de autenticación** para permitir emisiones tras solo contraseña. **Pendiente de verificación:** correr de nuevo `flutter analyze` y la selección de cinco suites en copia temporal de `main` y obtener `MAIN_I8L_FLUTTER_RESULT=0`; si falla, capturar error detallado. El gate 42/42 de backend I8-K continúa validado en su ejecución anterior; cambios de tests Flutter posteriores no prueban que el nuevo SHA haya sido validado por I8-K.

## R. Revalidación Flutter I8-L — 46/46 PASS (operador, 08/11/2026)

Después de corregir únicamente los tests heredados desalineados con la exigencia de MFA en los commits `8532a639` y `f3e9dfff`, el operador ejecutó sobre copia temporal de `main` en contenedor Flutter el análisis estático y cinco suites:

- `test/native_i8l_http_recovery_integration_test.dart`
- `test/native_recovery_login_gateway_test.dart`
- `test/native_mobile_recovery_entry_test.dart`
- `test/native_mobile_startup_gate_test.dart`
- `test/native_refresh_recovery_journal_test.dart`

Resultados explícitos:

```text
No issues found! (ran in 15.2s)
00:01 +46: All tests passed!
MAIN_I8L_FLUTTER_GATE=PASS
MAIN_I8L_RECHECK_RESULT=0
```

**Conclusión:** regresión seleccionada Flutter I8-L 46/46 PASS, `flutter analyze` PASS. La implementación mantiene el rechazo a recuperación solo con contraseña. Es una ejecución real comunicada por el operador y coherente con el código ahora integrado en `main`. La salida de terminal incluye repeticiones visuales de `tmux`, no se suman como ejecuciones independientes. El hash HEAD exacto del recheck no se imprimió; el operador realizó `git fetch` y `merge --ff-only` antes de ejecutarlo.

**Límites:** el gate es de tests Dart/mock/adapter, **no** prueba una sesión HTTPS real contra Django/PG17, ni Android físico, ni publicación operativa. I8-K HTTP (42/42) y Flutter I8-L (46/46) están validados por separado. Falta prueba de integración completa I8-M y los negativos TLS, además de verificar cualquier runner adicional antes de promoverlo.

**Estado operativo:** `MFA_RELEASE_AUTHORIZED=NO`; `NO_DEPLOY_NO_LIVE_MIGRATION=1`. No se ha desplegado ni se han ejecutado migraciones persistentes.

## S. I8-M: auditoría inicial de integración HTTPS Flutter–Django (08/11/2026)

Tras el PASS del backend I8-K HTTP (42/42) y Flutter I8-L (46/46), se inició revisión del gate extremo a extremo I8-M, **sin afirmar pruebas HTTPS ejecutadas**.

**Hallazgos de código comprobados:**
1. `scripts/native_i8k_https_server.py` **ya está en main** y coincide por SHA con `feature/m3-android-local-notifications`. Usa `native_mobile_service.test_i8k_recovery_urls` solo con `VENCIRA_ENV=test`, servicio candidato, `VENCIRA_I8K_RECOVERY_LAB=1`, `VENCIRA_I8K_NETWORK_ISOLATED=1`, PG17 con `POSTGRES_DB=i8klab`. No habilita `config.urls`.
2. `clients/flutter/lib/api/native_http_auth_port.dart` y `native_i8l_http_recovery_integration_test.dart` coinciden con su fuente histórica. El test I8-L es de adaptador con transporte simulado, no prueba el servidor TLS.
3. El URLconf `backend/native_mobile_service/test_i8k_recovery_urls.py` expone únicamente `/api/v1/mobile/auth/recover/password/`, `/api/v1/mobile/auth/recover/mfa/` y `/api/v1/mobile/me/`. **No expone `/api/v1/mobile/token/revoke/`**, aunque `NativeHttpAuthPort.revoke()` requiere esa ruta para revocación compensatoria en ciertas condiciones. El gateway mantiene fence revocado y marker al fallar, pero el éxito de revocación HTTPS **no está probado ni se puede presumir**. Antes de ampliarlo, revisar controles de autorización/rate-limit, ownership y anti-replay en un laboratorio desechable.
4. `scripts/native_i8k_https_probe.py` y `scripts/native_i8k_real_https_pg17_isolated.sh` están ausentes de main. El primero tuvo un bloqueo de publicación por controles de seguridad, **no intentar copiarlo por otra vía**. La rama histórica conserva código HTTPS I8-E/F y pruebas, pero no es sustituto directo de una prueba completa de recuperación I8-M.
5. El cliente Flutter no está conectado al flujo operativo en `main.dart`. TLS CA/hostname, caducidad del challenge, reinicio y recuperación en Android siguen pendientes.

**Artefacto publicado:** `scripts/main_i8m_recovery_readiness_static.py`, commit `2f965296`. Lee fuentes locales, revisa el aislamiento del servidor test-only y el bloqueo password-only, e informa expresamente `MAIN_I8M_HTTPS_REVOKE_CONTRACT=NOT_IMPLEMENTED_IN_LAB_URLCONF`, `MAIN_I8M_REAL_TLS_CLIENT_SERVER=NOT_TESTED` y `MAIN_I8M_ANDROID_PERSISTENCE=NOT_TESTED`. Un `MAIN_I8M_STATIC_GATE_RESULT=0` **solo certifica invariantes estáticas**, nunca un gate HTTPS real ni aprobación de release. Pendiente ejecutar el script sobre el nuevo SHA de main.

**Orden de trabajo:** (1) comprobar el gate estático; (2) diseñar revisión aislada del contrato revocación y del endpoint HTTPS faltante, con negativos y sin publicar rutas en `config.urls`; (3) preparar fixture TLS con CA temporal y DNS/cert válido **sin desactivar la verificación**; (4) ejecutar Flutter Dart cliente HTTP real contra Django PG17 efímero, verificando rechazos de CA falsa/hostname inválido y recuperación tras MFA; (5) probar persistencia/reinicio real en APK Android. Conservar `NO_DEPLOY_NO_LIVE_MIGRATION=1` y `MFA_RELEASE_AUTHORIZED=NO`.

## T. I8-M: contrato de revocación compensatoria en URLconf **solo test** (08/11/2026)

El operador ejecutó `scripts/main_i8m_recovery_readiness_static.py` sobre `main` y aportó `MAIN_I8M_LAB_ISOLATION_STATIC=PASS`, `MAIN_I8M_PASSWORD_ONLY_FENCE_STATIC=PASS`, `MAIN_I8M_STATIC_GATE_RESULT=0`, `MAIN_I8M_STATIC_RESULT=0`. El informe inicial mostraba `MAIN_I8M_HTTPS_REVOKE_CONTRACT=NOT_IMPLEMENTED_IN_LAB_URLCONF`.

**Correcciones directas en main:**
- `4b28f224`: `backend/native_mobile_service/test_i8k_recovery_views.py`, nueva vista `revoke` restringida al guard I8-K, método POST, JSON exactamente `{"refresh": ...}`, llamada `revoke_candidate_device` para token de refresco correspondiente, denegación uniforme y `{"status":"revoked"}` solo tras éxito. No permite revocación masiva por contraseña.
- `c4a3ef59`: `backend/native_mobile_service/test_i8k_recovery_urls.py`, únicamente ruta de laboratorio `/api/v1/mobile/token/revoke/`. **Ninguna modificación a `backend/config/urls.py`.**
- `61703c0f`: dos tests transaccionales PostgreSQL nuevos en `test_i8k_recovery_http_pg17.py`: (a) MFA de recuperación, emisión, acceso, revocación por refresh, posterior `/me/` rechazado y segunda revocación denegada; (b) token inválido, JSON extra, método equivocado y metadatos HTTP de navegador rechazados. Se comprueba también ausencia de la ruta de revocación en `config.urls`.
- `92894ea3`: `scripts/main_i8m_recovery_readiness_static.py` ahora exige ruta, handler y tests y reporta `MAIN_I8M_HTTPS_REVOKE_CONTRACT=IMPLEMENTED_TEST_ONLY_UNVERIFIED` (la existencia estática **no valida** HTTP ni HTTPS).

**Estado exacto:** código incorporado, pero **todavía sin ejecutar** la nueva regresión PG17 ni el análisis estático actualizado. El PASS anterior de I8-K de **42 tests** corresponde a código previo; el nuevo gate incluirá **44 tests** si las dos pruebas añadidas se descubren y no hay otras modificaciones. No atribuir PASS a este SHA hasta recibir salida y `NATIVE_I8K_LOCAL_RESULT=0`. Tras eso seguirá faltando una prueba TLS extremo a extremo con Flutter real, negativos CA/hostname y reinicio Android. `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## U. Revalidación I8-K tras añadir revocación de laboratorio (operador, 08/11/2026)

Se repitió `scripts/native_i8k_recovery_http_pg17_isolated.sh` después de incorporar la ruta, vista y pruebas de revocación I8-M únicamente en `native_mobile_service.test_i8k_recovery_urls`. Evidencia aportada:

```text
NATIVE_I8K_DISPOSABLE_IMAGE=OK
OK
Destroying test database for alias 'default'...
NATIVE_I8K_FLUTTER_GATE=NOT_RUN_SEPARATE
NATIVE_I8K_NO_PUBLIC_ISSUER=PASS
NATIVE_I8K_NO_MFA_DENIAL_POLICY=PASS
NATIVE_I8K_ATOMIC_RECOVERY_CORE=PASS
NATIVE_I8K_RECOVERY_HTTP_JSON=PASS
NATIVE_I8K_RECOVERY_ENDPOINTS_ABSENT=PASS
NATIVE_I8K_PG17_HTTP_RECOVERY_GATE=PASS
NATIVE_I8K_DEV_CONTAINERS_UNCHANGED=OK
NATIVE_I8K_DEPLOY_EXECUTED=NO
NATIVE_I8K_LIVE_MIGRATIONS_EXECUTED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
NATIVE_I8K_LOCAL_RESULT=0
```

**Interpretación:** la regresión I8-K HTTP/PG17 posterior a la implementación de revocación **PASS**; backend candidato permanece aislado y no altera DEV. El extracto no muestra la línea `Ran N tests`, por lo que **no atribuir 44/44 tests** hasta consultar el log de esta ejecución. Tampoco se muestra `MAIN_I8M_REVOKE_PG17_RESULT` ni SHA HEAD exacto de la ejecución. El marcador interno `NATIVE_I8K_LOCAL_RESULT=0` sí está confirmado.

**Pendiente de I8-M:** ejecución real extremo a extremo Flutter cliente HTTPS vs Django I8-K PG17 efímero, CA/hostname negativos, revocación TLS efectiva, persistencia/reinicio y validación Android. No autorizar publicación.

## V. Conteo confirmado de regresión PG17 I8-M post-revocación (operador, 08/11/2026)

El operador consultó el log `~/vencira-i8m-revoke-pg17.log` y confirmó:

```text
Ran 44 tests in 27.657s
NATIVE_I8K_LOCAL_RESULT=0
```

Junto con los marcadores completos registrados en sección U (`NATIVE_I8K_RECOVERY_HTTP_JSON=PASS`, `NATIVE_I8K_DEV_CONTAINERS_UNCHANGED=OK` y ausencia de despliegue/migraciones), se declara **I8-K/I8-M backend HTTP con revocación 44/44 PASS**, en PostgreSQL 17 desechable. Se reemplaza la incertidumbre de conteo de la sección U con esta evidencia posterior.

La revalidación no prueba por sí sola TLS, los negativos CA/hostname, el cliente Flutter en red real ni persistencia en Android; tales gates continúan pendientes. `MFA_RELEASE_AUTHORIZED=NO` y `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## W. I8-M: test Flutter de revocación compensatoria tras error de almacenamiento (08/11/2026)

El backend I8-M post-revocación había quedado validado en 44/44 pruebas HTTP PG17, mientras que Flutter I8-L alcanzó 46/46 PASS **antes** de este cambio. Se ha incorporado directamente a `main` un test adicional en `clients/flutter/test/native_i8l_http_recovery_integration_test.dart`, commit `1619c488`.

Nuevo test `I8-M failed protected write sends exact refresh to revoke endpoint`: mediante `MockClient` HTTP comprueba que (1) el login de recuperación obtiene un desafío MFA; (2) la respuesta MFA entrega tokens; (3) el almacén protegido falla al guardar el refresh; (4) el cliente envía exactamente el refresh nuevo a `/api/v1/mobile/token/revoke/` con POST HTTPS, sin cookies, autorización ni redirecciones; (5) el servidor simulado responde `{"status":"revoked"}` y pese a ello el gateway propaga el fallo de almacenamiento; (6) el bearer no queda disponible, la fence sigue cerrada, se mantiene el refresh anterior y permanece el marker duradero de recuperación.

El test anterior de fallo de revocación/404 se conserva como regresión negativa; su comentario obsoleto se actualizó para reflejar que el endpoint I8-K **sí** está disponible en el URLconf test-only.

**Pendiente:** ejecutar nueva suite Flutter en copia temporal de Docker. Se esperan **47 pruebas** en las cinco suites si no varía el descubrimiento (46 anteriores + 1 nuevo), más `flutter analyze`. **No atribuir PASS hasta salida del operador**. Este test usa `MockClient`, **NO equivale a una prueba TLS real ni de Android**. Los negativos TLS no deben deducirse de este resultado. Conservar `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## X. I8-M Flutter 47/47 PASS tras test de revocación compensatoria (operador 08/11/2026)

El operador volvió a ejecutar el gate sobre una copia temporal del frontend Flutter de `main`, después del commit `1619c488`. Se seleccionaron las cinco suites I8-L/I8-M y se realizó el análisis estático:

```text
No issues found! (ran in 14.9s)
00:02 +47: All tests passed!
MAIN_I8M_FLUTTER_GATE=PASS
```

**Conclusión:** suite Flutter seleccionada de recuperación MFA y revocación compensatoria **47/47 PASS**, `flutter analyze` PASS. Se cubren el envío HTTP JSON simulado de revocación ante fallo de almacenamiento, el fail-closed, el marker durable y reinicio simulado, pero **no** un enlace TLS real. El texto de terminal muestra repeticiones visuales del mismo resultado en `tmux`; no se cuentan como ejecuciones adicionales. No se incluyó una línea `MAIN_I8M_FLUTTER_RESULT` en el fragmento entregado, pero el marcador interno `MAIN_I8M_FLUTTER_GATE=PASS` sí está presente. El checkout se actualizó previamente desde `origin/main`; no se imprimió SHA exacto en este extracto.

**Resumen de gates disponibles:** backend I8-M PG17 HTTP con revocación 44/44 PASS; Flutter seleccionado I8-M 47/47 PASS; TLS extremo a extremo Flutter–Django PG17 todavía **NOT_TESTED** y Android físico todavía **NOT_TESTED**. Mantener `MFA_RELEASE_AUTHORIZED=NO` y `NO_DEPLOY_NO_LIVE_MIGRATION=1`. Priorizar gate con CA temporal verificable, denegación explícita para CA desconocida/hostname erróneo, sin puertos host públicos, y ausencia de cookies; no convertir tests aislados en autorización de despliegue.

## Y. I8-M TLS bridge: prueba de rechazo de arranque (08/11/2026)

Después del gate Flutter I8-M 47/47 PASS, el paso previo al TLS real es comprobar que el puente `scripts/native_i8k_https_server.py` **no puede arrancar** con variables de laboratorio ausentes o alteradas, sin intentar conexiones reales ni datos operativos.

**Integración directa en main:**
- `fb365af3`: se añade `scripts/main_i8m_tls_bridge_denial_test.py` con un proceso Python aislado en entorno mínimo. Rechaza la omisión de cada una de las seis condiciones `VENCIRA_ENV=test`, `VENCIRA_NATIVE_SERVICE_CANDIDATE=1`, `VENCIRA_I8K_RECOVERY_LAB=1`, `VENCIRA_I8K_NETWORK_ISOLATED=1`, `VENCIRA_DB_ENGINE=postgresql`, `POSTGRES_DB=i8klab`. También comprueba siete combinaciones con valores prohibidos. Los subprocesos no deberían llegar a Django, claves TLS ni escucha TCP.
- `f79b4645`: se ajusta el entrypoint para emitir `MAIN_I8M_TLS_BRIDGE_NEGATIVE_GUARD=PASS` **únicamente** si `unittest` termina sin fallos.

**No ejecutado aún:** el operador debe actualizar `main` y lanzar `python3 scripts/main_i8m_tls_bridge_denial_test.py`; se esperan dos tests unittest que internamente verifican 13 escenarios negativos. No asociar su PASS a TLS verificado. Los marcadores `MAIN_I8M_REAL_TLS_CLIENT_SERVER=NOT_TESTED` y `MAIN_I8M_ANDROID_PERSISTENCE=NOT_TESTED` siguen vigentes. No se ha creado ni ejecutado un probe de autenticación HTTPS real ni se ha publicado ninguna ruta de recuperación. Se mantienen `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## Z. I8-M: rechazo de arranque TLS validado (operador 08/11/2026)

El operador ejecutó `python3 scripts/main_i8m_tls_bridge_denial_test.py` sobre su checkout actualizado de `main`. Evidencia completa relevante:

```text
OK
MAIN_I8M_TLS_BRIDGE_NEGATIVE_GUARD=PASS
MAIN_I8M_REAL_TLS_CLIENT_SERVER=NOT_TESTED
MAIN_I8M_ANDROID_PERSISTENCE=NOT_TESTED
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
MAIN_I8M_TLS_NEGATIVE_RESULT=0
```

**Conclusión:** pruebas negativas de arranque del servidor TLS I8-K **PASS**: el guard inicial deniega configuraciones incompletas o incompatibles con laboratorio (omisión de variables y valores alternativos). El resultado presentado no reproduce `Ran 2 tests`, aunque `OK` y el marcador interno se imprimen solo tras el éxito de unittest. Los resultados Flutter I8-M **47/47 PASS** y backend PG17 **44/44 PASS** permanecen confirmados.

**Pendientes:** transporte HTTPS real y validación CA/hostname cliente Flutter, sesión Django PG17 recuperada de extremo a extremo y reinicio en Android. El gate negativo no prueba ninguna de esas propiedades. No autorizar producción.

## AA. I8-M: contrato X.509 de laboratorio (08/11/2026)

Se inspeccionaron los ejecutores históricos de `feature/m3-android-local-notifications`: `scripts/native_i8k_real_https_pg17_isolated.sh` depende del fichero `scripts/native_i8k_https_probe.py`, ausente en `main` y cuya publicación anterior quedó bloqueada; el runner no es ejecutable de forma autónoma en `main`. `native_i8f_flutter_https_pg17_isolated.sh` prueba autenticación ordinaria I8-E, **no** recuperación I8-M, y depende asimismo de cliente de pruebas Flutter I8-F ausente en `main`. No se han integrado ni ejecutado ni reutilizado esos probes.

Se incorpora directamente a main `scripts/main_i8m_tls_certificate_contract.sh` (commit `1b4b4f70`) como **preflight offline de material X.509**: genera dos certificados sintéticos temporales con OpenSSL, comprueba SAN `DNS:native-i8k.test`, verifica el certificado con su CA permitida y hostname correcto, exige rechazo con hostname incorrecto y con otra CA y mantiene las claves privadas en carpeta `0700` con archivos `0600`. El trap elimina solo los cuatro ficheros temporales del directorio exacto y preserva el código de salida, sin puertos, servidor HTTP, Docker, Flutter ni base de datos. Imprime `MAIN_I8M_TLS_CERT_CONTRACT=PASS` solo después de las comprobaciones.

**Estado:** commit integrado; **no ejecutado en VPS todavía**. Su futuro PASS es solo un contrato criptográfico offline, **no** un handshake real Flutter–Django. Permanecen `MAIN_I8M_REAL_TLS_CLIENT_SERVER=NOT_TESTED`, `MAIN_I8M_ANDROID_PERSISTENCE=NOT_TESTED`, `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`. La validación de TLS real deberá disponer de un ejecutor aprobado y aislado, con CA y hostname verificados sin bypass.

## AB. I8-M: contrato offline X.509 verificado en VPS (operador, 08/11/2026)

El operador ejecutó `bash scripts/main_i8m_tls_certificate_contract.sh` en `~/vencira-main-check-20261108` tras actualizar `main`. Reportó:

```text
MAIN_I8M_EPHEMERAL_PRIVATE_KEY_MODE=PASS
MAIN_I8M_CERTIFICATE_SAN=PASS
MAIN_I8M_CERTIFICATE_TRUSTED_HOST=PASS
MAIN_I8M_CERTIFICATE_WRONG_HOST=DENIED
MAIN_I8M_CERTIFICATE_WRONG_CA=DENIED
MAIN_I8M_TLS_CERT_CONTRACT=PASS
MAIN_I8M_TLS_CERT_CONTRACT_RESULT=0
MAIN_I8M_REAL_TLS_CLIENT_SERVER=NOT_TESTED
MAIN_I8M_ANDROID_PERSISTENCE=NOT_TESTED
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
MAIN_I8M_CERT_RESULT=0
```

**Conclusión estricta:** generación de certificado efímero, SAN, validación de cadena/hostname y denegaciones negativas por OpenSSL offline **PASS**. No se levantó servidor, no se hizo handshake entre procesos ni se verificó el cliente Flutter/Django; no se ha comprobado el almacenamiento Android. Se mantienen backend HTTP PG17 44/44 PASS, Flutter con MockClient 47/47 PASS y rechazo de arranque TLS PASS.

**Siguiente puerta pendiente:** una prueba de integración de transporte HTTPS con verificación real de hostname y CA, red Docker interna y backend PG17 efímero. No reciclar el probe histórico cuya publicación quedó bloqueada; verificar la herramienta de ejecución y sus controles antes de ponerla en marcha.

## AC. I8-M: aislamiento entre cuentas en revocación y rechazo de refresh antiguo (08/11/2026)

Se amplía en `main` `backend/native_mobile_service/test_i8k_recovery_http_pg17.py`, commit `cf0060e6`, con dos regresiones transaccionales:

1. `test_revoke_only_own_device_preserves_other_account`: crea dos usuarios MFA completamente sintéticos en PG17 desechable, emite tokens para ambas cuentas, revoca el refresh del primero y comprueba que su access queda inválido, mientras la otra cuenta conserva una sesión accesible y no revocada. Esto comprueba la separación entre identidades.
2. `test_revoked_old_refresh_cannot_revoke_new_recovery`: inicia sesión previa, completa recuperación MFA que revoca todas las sesiones antiguas y emite otra, intenta revocar con el refresh anterior, exige HTTP 401 y verifica que el access nuevo permanece válido.

**Estado:** código y tests añadidos, no ejecutados todavía. El último PASS comprobado es **44/44** sobre el SHA previo; si solo se incorporan estas dos pruebas, se esperan **46 tests** en el gate `scripts/native_i8k_recovery_http_pg17_isolated.sh`. No reportar 46/46 PASS sin la salida real. El script incluye controles de contenedores sin cambios, sin despliegue y sin migraciones persistentes. Estas pruebas complementan, pero no sustituyen, el HTTPS real Flutter–Django ni Android. `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## AD. Revalidación I8-M aislamiento de revocación PG17 (operador 08/11/2026)

Después del commit `cf0060e6` que añade dos pruebas de separación entre cuentas y rechazo de refresh revocado, el operador repitió el gate `scripts/native_i8k_recovery_http_pg17_isolated.sh` y comunicó:

```text
OK
Destroying test database for alias 'default'...
NATIVE_I8K_FLUTTER_GATE=NOT_RUN_SEPARATE
NATIVE_I8K_NO_PUBLIC_ISSUER=PASS
NATIVE_I8K_NO_MFA_DENIAL_POLICY=PASS
NATIVE_I8K_ATOMIC_RECOVERY_CORE=PASS
NATIVE_I8K_RECOVERY_HTTP_JSON=PASS
NATIVE_I8K_RECOVERY_ENDPOINTS_ABSENT=PASS
NATIVE_I8K_PG17_HTTP_RECOVERY_GATE=PASS
NATIVE_I8K_DEV_CONTAINERS_UNCHANGED=OK
NATIVE_I8K_DEPLOY_EXECUTED=NO
NATIVE_I8K_LIVE_MIGRATIONS_EXECUTED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
NATIVE_I8K_LOCAL_RESULT=0
```

**Conclusión:** gate HTTP PG17 posterior a añadir las dos pruebas **PASS**; no hay despliegue ni migración persistente y los contenedores de DEV permanecen idénticos según el guard. **El extracto no incluye `Ran N tests`**, por lo que no se afirma 46/46 hasta examinar `~/vencira-i8m-isolation-pg17.log`. Tampoco aparece el marcador externo `MAIN_I8M_ISOLATION_RESULT`; la salida interna sí confirma código cero.

Siguen pendientes la ejecución real de HTTPS Flutter-Django, negativos de validación TLS sobre red, y APK Android física.

## AE. Confirmación del conteo PG17 I8-M aislamiento (operador, 08/11/2026)

El operador consultó el registro `~/vencira-i8m-isolation-pg17.log` y confirmó:

```text
Ran 46 tests in 28.537s
NATIVE_I8K_LOCAL_RESULT=0
```

Con los marcadores ya documentados en sección AD (`NATIVE_I8K_RECOVERY_HTTP_JSON=PASS`, `NATIVE_I8K_DEV_CONTAINERS_UNCHANGED=OK`, `NATIVE_I8K_DEPLOY_EXECUTED=NO`, `NATIVE_I8K_LIVE_MIGRATIONS_EXECUTED=NO`), se cierra la incertidumbre: **46/46 pruebas PG17 aisladas PASS** sobre el backend ampliado con revocación entre cuentas y denegación de refresh antiguo. Esto no verifica red TLS real ni Android. Mantener `MFA_RELEASE_AUTHORIZED=NO` y `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## AF. D1 — Preparación de despliegue controlado DEV sin ejecutar cambios (08/11/2026)

El usuario pidió preparar un despliegue de los nuevos cambios en `dev.vencira.es`. **No hay todavía autorización para desplegar la totalidad de `main` ni aplicar migraciones persistentes.** Se abrió el bloque de auditoría D1 y se revisaron las fuentes actuales:

- `backend/config/urls.py` continúa sin vistas candidatas de autenticación/recuperación nativa.
- `backend/config/settings.py` conserva `VENCIRA_NATIVE_BEARER_ENABLED = False` y el registro de `native_mobile_service` limitado al entorno `test`.
- Los paths históricos de documentación operativa O5/runbook y nombres frecuentes de Compose **no aparecen en `main`** en las ubicaciones consultadas; pueden existir en otros worktrees o rutas del VPS. No se afirma que falten en el servidor actual.
- El inventario de migraciones del **checkout main** debe contrastarse con el registro de la **base persistente actualmente conectada**. La coincidencia de nombres por sí sola no demuestra compatibilidad; es obligatorio ensayar con un clon restaurado.

**Artefactos nuevos publicados en main:** `scripts/d1_dev_deploy_inventory_readonly.py`, commits `3d47df92` y ajuste `8dfe773f`; `docs/D1_DEV_DEPLOY_PREPARATION_2026-11-08.md`, commit `41b18415`. El script solo inspecciona Git, código fuente, estado e ID de imagen de los tres contenedores DEV y ejecuta un SELECT de `django_migrations` mediante la API Django en el contenedor API actual. No llama a `migrate`, `docker compose up`, backup, restart o alteraciones de base; no imprime contraseñas, tokens, variables de entorno ni filas personales.

**Estado:** herramientas publicadas pero el preflight D1 no está ejecutado aún en el VPS. No anunciar compatibilidad con DEV ni promoción segura hasta recibir el resultado y validar restore O5 y rollback. Marcadores de protección: `D1_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`, `MFA_RELEASE_AUTHORIZED=NO`.

## AG. Endurecimiento de rutas API del cliente Flutter en main (08/11/2026)

El usuario acordó continuar integrando en `main` y posponer cualquier despliegue hasta que todos los gates pertinentes estén completos. Se inspeccionaron `clients/flutter/lib/api/native_api_endpoint.dart`, su test y el adaptador de recuperación.

**Hallazgo:** `NativeApiEndpoint.resolveApiPath` verificaba el esquema HTTPS del origen y que las rutas empezaran por `/api/v1/`, pero no exigía `parsed.hasQuery == false`. Una ruta interna con `?refresh=...` o un destino de redirección embebido podía admitirse y resolverse a la API autorizada, aunque el cliente actual usa rutas literales sin consultas. El cambio es defensa en profundidad y no se atribuye una explotación real.

**Cambios directos en main:**
- `2508914f` — el resolvedor rechaza rutas API con parámetros de consulta.
- `29c07cbd` — se amplían los casos adversarios en `clients/flutter/test/native_api_endpoint_test.dart`: query de token, query vacía, parámetro de redirección, traversal codificado y barra invertida.

**Estado:** revisión de código publicada; test nuevo **pendiente de ejecución**. Los `47/47` Flutter reportados antes corresponden al SHA anterior, y no verifican el endurecimiento recién añadido. Probar `native_api_endpoint_test.dart` junto con `native_http_auth_port_test.dart` y la regresión I8-L; ejecutar `flutter analyze` en la copia Docker temporal, nunca activar ruta operativa. Los controles `MFA_RELEASE_AUTHORIZED=NO` y `NO_DEPLOY_NO_LIVE_MIGRATION=1` siguen intactos.

**Despliegue D1:** pospuesto por decisión explícita. Inventario D1-A con 24 migraciones de código no registradas en DEV; no tocar la DB. D1-B (backup/restore + ensayo de migración `reminders.0019–0027` en clon) permanece sin ejecutar.

## AH. Incidencia de rutas Flutter: corregida en código, pendiente de nueva ejecución (08/11/2026)

Tras los commits `2508914f` y `29c07cbd`, el operador ejecutó tres suites Flutter. El resultado comunicado fue `00:01 +26 -1: Some tests failed`; la única suite/caso identificado fue `native_api_endpoint_test.dart: does not resolve arbitrary external or non-API paths`. Los 17 tests del adaptador HTTP y 7 de recuperación I8-L aparecen como correctos en el extracto; **el gate global falló y no se declara PASS**.

La primera implementación rechazaba `parsed.hasQuery`, pero las cadenas de rutas son procesadas y potencialmente normalizadas por `Uri.tryParse`. El caso adversario incluye separadores de query vacía y traversal percent-encoded. Se añade una barrera **sobre la ruta de entrada sin parsear**: rechazar cualquier `?` y las codificaciones `%2e`, `%2f`, `%5c` sin distinguir mayúsculas (commit `8c81219d`). Se mantienen además la validación de host, HTTPS y controles posteriores de `Uri`.

**Diagnóstico provisional:** no se recibió el `Expected/Actual` del test fallido, por lo que no está demostrado cuál de los vectores de la lista causó el fallo; el cambio cubre el traversal codificado y query vacía de forma directa. Es imprescindible repetir `native_api_endpoint_test.dart`, `native_http_auth_port_test.dart`, `native_i8l_http_recovery_integration_test.dart` y `flutter analyze` sobre el nuevo SHA. No despliegue ni migración persistente. `MFA_RELEASE_AUTHORIZED=NO`; `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## AI. Recheck de rutas Flutter tras la corrección raw-path (08/11/2026)

El operador volvió a ejecutar las tres suites de Flutter después de incorporar `8c81219d` en `main` y comunicó:

```text
second process remains fenced after ambiguous MFA result
00:01 +27: All tests passed!
```

**Resultado acreditado:** 27/27 tests Flutter PASS para `native_api_endpoint_test.dart`, `native_http_auth_port_test.dart` y `native_i8l_http_recovery_integration_test.dart`. La regresión introducida por las nuevas entradas adversarias queda resuelta según el recheck comunicado. El extracto no contiene `flutter analyze` ni `MAIN_FLUTTER_SECURITY_RECHECK=0`, así que estos dos marcadores no se dan por comprobados en esta ejecución (pueden confirmarse con el log completo).

No se ha verificado HTTPS real Flutter–Django ni persistencia Android. No se realiza despliegue ni migración DEV; permanecen `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## AJ. I8-M primer handshake HTTPS real contra Django + PG17 efímero (08/11/2026)

Nuevo bloque integrado en `main`, **pendiente de ejecución real**:

- `scripts/main_i8m_tls_boundary_probe.py` (`e700855c`, corrección `ae953a80`): cliente Python de laboratorio sin credenciales que exige `VENCIRA_I8M_INTERNAL_TLS_PROBE=1`, `VENCIRA_ENV=test` y `POSTGRES_DB=i8klab`. Utiliza TLS con CA explícita y hostname `native-i8k.test`; verifica que otra CA y un hostname incorrecto son rechazados por un handshake real. Mediante HTTPS realiza únicamente GET sin contraseñas/tokens contra rutas del URLconf de recuperación: password/MFA/revoke GET→405, `me` sin token→401 y login normal ausente→404; bloquea cookies y exige JSON/cache no-store para respuestas nativas. El 404 de Django no está obligado a ser JSON.
- `scripts/main_i8m_tls_boundary_pg17_isolated.sh` (`7ee4302e`): imagen Django desechable construida desde el `main` actual, red Docker `--internal`, PostgreSQL 17 `tmpfs`, secretos/certificado sintéticos en carpeta temporal 0700, esquema migrado **solo en PG17 temporal**, WSGI de test con HTTPS sin publicación de puertos, probe dentro de la red. El servidor se ejecuta read-only, sin capacidades Linux, con seguridad no-new-privileges y el contenedor probe igualmente restringido. Un trap elimina el laboratorio y compara IDs e imágenes de `vencira_localcheck-api-1`, `-db-1`, `-web_preview-1` antes/después. El key PEM sintético usa 0644 únicamente dentro de un directorio temporal privado 0700 para poder montarse en contenedor no-root, se elimina al finalizar; **esto no es un diseño de custodia de claves operativas**.

**Importante:** el preflight **no** prueba autenticación MFA, emisión, revocación real, Flutter `IOClient`, almacenamiento Android o SSL de producción. No equiparar `MAIN_I8M_TLS_BOUNDARY_GATE=PASS` con `MAIN_I8M_REAL_TLS_FLUTTER_CLIENT=PASS`. Resultado esperado solo tras ejecutar el gate en VPS, sin declarar PASS por anticipado. Ningún despliegue DEV ni migraciones persistentes autorizados.

Orden de validación:
```bash
cd ~/vencira-main-check-20261108
git fetch origin main
git merge --ff-only FETCH_HEAD
set -o pipefail
bash scripts/main_i8m_tls_boundary_pg17_isolated.sh 2>&1 | tee ~/vencira-i8m-tls-boundary.log
echo "MAIN_I8M_TLS_BOUNDARY_SHELL_RESULT=${PIPESTATUS[0]}"
```

Exigir `MAIN_I8M_REAL_UNTRUSTED_CA_DENIED=PASS`, `MAIN_I8M_REAL_HOSTNAME_MISMATCH_DENIED=PASS`, `MAIN_I8M_REAL_HTTPS_DJANGO_BOUNDARY=PASS`, `MAIN_I8M_REAL_TLS_PYTHON_CLIENT_SERVER=PASS`, `MAIN_I8M_TLS_BOUNDARY_GATE=PASS`, `MAIN_I8M_TLS_DEV_CONTAINERS_UNCHANGED=OK` y resultado cero. `MAIN_I8M_REAL_TLS_FLUTTER_CLIENT=NOT_TESTED` continúa siendo el bloqueo siguiente.

## AK. I8-M TLS boundary: primer ensayo fallido y corrección de importación (08/11/2026)

El operador ejecutó `scripts/main_i8m_tls_boundary_pg17_isolated.sh` sobre `main`. Evidencia recibida:

```text
MAIN_I8M_TLS_DISPOSABLE_IMAGE=OK
MAIN_I8M_TLS_DOCKER_NETWORK_INTERNAL=PASS
MAIN_I8M_TLS_PG17_EPHEMERAL_READY=PASS
MAIN_I8M_TLS_EPHEMERAL_MIGRATIONS=PASS
MAIN_I8M_TLS_SERVER_READY=FAIL
ModuleNotFoundError: No module named 'config'
MAIN_I8M_TLS_DEV_CONTAINERS_UNCHANGED=OK
MAIN_I8M_TLS_DEPLOY_EXECUTED=NO
MAIN_I8M_TLS_LIVE_MIGRATIONS_EXECUTED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
MAIN_I8M_TLS_BOUNDARY_RESULT=6
```

**Diagnóstico:** el script del servidor Django está montado en `/opt/i8k_server.py` y Python ejecuta ese archivo desde `/opt`, sin incluir `/app` en `sys.path`. El WSGI no puede importar `config.settings`, aunque la imagen Django y las migraciones PG17 efímeras ya han funcionado. No se ha llegado al handshake TLS ni a ejecutar el cliente Python. El fallo no implica un problema de CA o de base de datos.

**Corrección directa en `main`:** commit `d4580149`, añade `-e PYTHONPATH=/app` solo al contenedor efímero del servidor HTTPS; no modifica `backend/config/settings.py`, URLconf, DEV, Docker Compose o datos persistentes. El gate **sigue pendiente de reejecución**. Se espera `MAIN_I8M_TLS_SERVER_READY=PASS`, seguido de los marcadores positivos/negativos del handshake real. No afirmar `MAIN_I8M_TLS_BOUNDARY_GATE=PASS` hasta verlos.

## AL. I8-M handshake TLS real Python–Django–PG17 validado (operador 08/11/2026)

El operador volvió a ejecutar `scripts/main_i8m_tls_boundary_pg17_isolated.sh` tras el ajuste de importación `d4580149`, en el checkout de `main`. Evidencia exacta reportada:

```text
MAIN_I8M_TLS_DISPOSABLE_IMAGE=OK
MAIN_I8M_TLS_DOCKER_NETWORK_INTERNAL=PASS
MAIN_I8M_TLS_PG17_EPHEMERAL_READY=PASS
MAIN_I8M_TLS_EPHEMERAL_MIGRATIONS=PASS
MAIN_I8M_TLS_SERVER_READY=PASS
MAIN_I8M_REAL_UNTRUSTED_CA_DENIED=PASS
MAIN_I8M_REAL_HOSTNAME_MISMATCH_DENIED=PASS
MAIN_I8M_REAL_HTTPS_DJANGO_BOUNDARY=PASS
MAIN_I8M_REAL_TLS_PYTHON_CLIENT_SERVER=PASS
MAIN_I8M_REAL_TLS_FLUTTER_CLIENT=NOT_TESTED
MAIN_I8M_REAL_MFA_FLOW=NOT_TESTED
MAIN_I8M_ANDROID_PERSISTENCE=NOT_TESTED
MAIN_I8M_TLS_BOUNDARY_GATE=PASS
MAIN_I8M_TLS_DEV_CONTAINERS_UNCHANGED=OK
MAIN_I8M_TLS_DEPLOY_EXECUTED=NO
MAIN_I8M_TLS_LIVE_MIGRATIONS_EXECUTED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
MAIN_I8M_TLS_BOUNDARY_RESULT=0
```

**Conclusión válida:** primer gate de transporte TLS **real** entre proceso cliente Python, Django WSGI y red Docker interna con PG17 temporal PASS. Handshake confía solo en CA temporal y hostname esperado; se deniegan una CA externa y hostname incorrecto. Las rutas sin credenciales del URLconf de recuperación responden con el contrato esperado y no hay exposición operativa. La corrección de `PYTHONPATH=/app` queda acreditada.

**Límites:** la prueba GET no usa Flutter/Dart, password ni TOTP, no emite ni revoca sesiones, no prueba almacenamiento Keystore/Android y no publica el backend. No declarar I8-M completo hasta validar cliente Flutter HTTPS auténtico, recuperación MFA real y compensación de revocación bajo fallo de almacenamiento. Se mantienen las restricciones sin despliegue ni migraciones persistentes.

## AM. I8-M Flutter cliente real por HTTPS + MFA y revocación PG17 (08/11/2026)

Tras el gate verificado **Python HTTPS–Django–PG17 PASS**, se integra en `main` un ensayo de extremo a extremo con cliente **Flutter `IOClient` real**, **sin activar `main.dart`** y **sin tocar DEV**.

**Archivos y commits principales:**
- `clients/flutter/test/native_i8m_real_https_pg17_test.dart`, commits `dcdf6332`, `7fa3126a`, `bd2e54a4`, `7b79f1ae`: dos pruebas Flutter con `HttpClient` verificado y `SecurityContext(withTrustedRoots:false)` que carga solo una CA de laboratorio. Binding de test explícito `overrideHttpClient=false` habilitado únicamente con los marcadores `VENCIRA_I8M_FLUTTER_INTERNAL_ONLY=1`, `VENCIRA_ENV=test`, `POSTGRES_DB=i8klab`; la ejecución normal de `flutter test` fuera de lab **salta** este archivo, sin conexiones reales. Primera prueba: rechazo de CA ajena y hostname incorrecto, handshake verificado, autenticación de recuperación contraseña→MFA TOTP sintético→HTTP bearer `me`, sustitución de refresh y marcador. Segunda prueba: escritura protegida sintéticamente fallida (almacén temporal en memoria), fence local cerrado y compensación de revocación HTTP; la revocación se confirma en PG17 después de terminar las pruebas.
- `scripts/native_i8k_https_server.py`, commit `dceff18f`: habilita puerto 443 **solo** si se cumplen los seis guards test-only originales y `VENCIRA_I8M_FLUTTER_INTERNAL_ONLY=1`; en otros casos conserva 8443. El usuario no está conectado a este servidor.
- `scripts/main_i8m_flutter_real_https_pg17_isolated.sh`, commits `498bdcab`, `a5fb1e55`, `f08d2f8a`: imagen Django de `main` desechable, red Docker `--internal`, PG17 `tmpfs`, certificado autofirmado SAN dev.vencira.es **solo en DNS alias del Docker interno**, 443 interno sin publicación en host, dos cuentas MFA sintéticas y una sesión vieja, Flutter 3.44.0 en volúmenes temporales, adquisición de dependencias públicas *antes* de ejecutar el test en red aislada; después de los tests se comprueba en PG17 que la recuperación invalida la sesión anterior y que el fallo de persistencia revoca la nueva. Los contenedores DEV se comparan antes/después y el trap elimina contenedores, imagen y volúmenes efímeros. No usa ni lee datos operativos.
- El test Flutter emplea `crypto` como dependencia de **test** ya presente en pubspec, solo para TOTP RFC 6238 sintético.

**Estado crítico: no ejecutado aún.** El diseño agrega una puerta sustancial, pero no se acreditan análisis Flutter, dos tests TLS ni comprobación transaccional hasta que el operador ejecute el runner. La prueba de almacén es **en memoria**, no `FlutterSecureStorage` ni Keystore Android; el siguiente gate físico permanece pendiente. No se despliega, no se migran datos persistentes, MFA release sigue denegado.

Comando de ensayo desde `~/vencira-main-check-20261108`:

```bash
git fetch origin main
git merge --ff-only FETCH_HEAD
set -o pipefail
bash scripts/main_i8m_flutter_real_https_pg17_isolated.sh 2>&1 | tee ~/vencira-i8m-flutter-real-https.log
echo "MAIN_I8M_FLUTTER_TLS_SHELL_RESULT=${PIPESTATUS[0]}"
```

Exigir `MAIN_I8M_FLUTTER_TLS_ANALYZE=PASS`, `MAIN_I8M_FLUTTER_TLS_SERVER_READY=PASS`, `MAIN_I8M_FLUTTER_TLS_REAL_CLIENT=PASS`, `MAIN_I8M_FLUTTER_TLS_ACCOUNT_RECOVERY_REVOCATION=PASS`, `MAIN_I8M_FLUTTER_TLS_STORAGE_FAILURE_REMOTE_REVOKE=PASS`, `MAIN_I8M_FLUTTER_TLS_RECOVERY_GATE=PASS`, `MAIN_I8M_FLUTTER_TLS_DEV_CONTAINERS_UNCHANGED=OK` y `MAIN_I8M_FLUTTER_TLS_BOUNDARY_RESULT=0`. Sin esos marcadores no declarar I8-M Flutter HTTPS PASS.

## AN. I8-M Flutter TLS: incidencia SDK de Flutter en filesystem RO (operador 08/11/2026)

Primera ejecución del gate `scripts/main_i8m_flutter_real_https_pg17_isolated.sh` en VPS, reportada por el operador:

```text
No issues found! (ran in 10.5s)
MAIN_I8M_FLUTTER_TLS_ANALYZE=PASS
MAIN_I8M_FLUTTER_TLS_FIXTURE_READY=PASS
/sdks/flutter/bin/internal/update_engine_version.sh: line 71: /sdks/flutter/bin/cache/engine.stamp.tmp.18: Read-only file system
/sdks/flutter/bin/internal/update_engine_version.sh: line 78: /sdks/flutter/bin/cache/engine.realm: Read-only file system
MAIN_I8M_FLUTTER_TLS_DEV_CONTAINERS_UNCHANGED=OK
MAIN_I8M_FLUTTER_TLS_DEPLOY_EXECUTED=NO
MAIN_I8M_FLUTTER_TLS_LIVE_MIGRATIONS_EXECUTED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
MAIN_I8M_FLUTTER_TLS_BOUNDARY_RESULT=1
```

**Diagnóstico preciso:** análisis estático Flutter PASS, fixture de usuarios MFA sintéticos creada en PG17 temporal. El contenedor del runner de `flutter test` usaba `--read-only` y el SDK `ghcr.io/cirruslabs/flutter:3.44.0` intenta actualizar el archivo `/sdks/flutter/bin/cache/engine.stamp` y `engine.realm` al iniciar. Se aborta antes de comprobar Flutter TLS, MFA o revocación. **No hay PASS extremo a extremo todavía.**

**Corrección en `main`, commit `74fd920e`:** se retira exclusivamente `--read-only` del contenedor efímero que ejecuta `flutter test`. La capa escribible es descartable y se elimina con `--rm`; el checkout del host no está montado en el runner, las fuentes se preparan en volumen Docker temporal y no hay puertos publicados. Se mantienen `--network` interno, capacidades retiradas, `no-new-privileges` y comparativa de contenedores DEV. El resto de contenedores del ensayo mantiene sus guardias. **Repetición pendiente**.

Próximo paso: repetir `bash scripts/main_i8m_flutter_real_https_pg17_isolated.sh` desde el checkout de `main` actualizado, confirmar `MAIN_I8M_FLUTTER_TLS_REAL_CLIENT=PASS`, ambas comprobaciones SQL de revocación, `MAIN_I8M_FLUTTER_TLS_RECOVERY_GATE=PASS`, y `MAIN_I8M_FLUTTER_TLS_BOUNDARY_RESULT=0`. Si aparece otro error, registrar etapa y corregir causa sin declarar PASS.

## AO. I8-M Flutter HTTPS + recuperación MFA + revocación en PG17: PASS (operador 08/11/2026)

El operador ejecutó el gate corregido `scripts/main_i8m_flutter_real_https_pg17_isolated.sh` y aportó la siguiente salida:

```text
No issues found! (ran in 10.4s)
MAIN_I8M_FLUTTER_TLS_ANALYZE=PASS
MAIN_I8M_FLUTTER_TLS_FIXTURE_READY=PASS
00:00 +0: I8-M verified IOClient TLS and recovery MFA committed
MAIN_I8M_FLUTTER_TLS_CA_AND_HOSTNAME=PASS
MAIN_I8M_FLUTTER_RECOVERY_MFA_TLS=PASS
00:00 +1: I8-M failed storage write triggers remote revoke over real TLS
MAIN_I8M_FLUTTER_FAILURE_LOCAL_FENCE=PASS
00:01 +2: All tests passed!
MAIN_I8M_FLUTTER_TLS_REAL_CLIENT=PASS
MAIN_I8M_FLUTTER_TLS_ACCOUNT_RECOVERY_REVOCATION=PASS
MAIN_I8M_FLUTTER_TLS_STORAGE_FAILURE_REMOTE_REVOKE=PASS
MAIN_I8M_FLUTTER_TLS_RECOVERY_GATE=PASS
MAIN_I8M_FLUTTER_TLS_DEV_CONTAINERS_UNCHANGED=OK
MAIN_I8M_FLUTTER_TLS_DEPLOY_EXECUTED=NO
MAIN_I8M_FLUTTER_TLS_LIVE_MIGRATIONS_EXECUTED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
MAIN_I8M_FLUTTER_TLS_BOUNDARY_RESULT=0
```

**Resultado acreditado:** `flutter analyze` PASS, pruebas Flutter con `IOClient` real **2/2 PASS**, CA/hostname verificados, recuperación password+TOTP sintético mediante HTTPS, rechazo de sesión antigua tras recuperación y revocación compensatoria tras fallo de escritura de refresh; última verificación de sesiones en PostgreSQL 17 **efímero** PASS. El gate completa la conexión Flutter–Django HTTPS de laboratorio, no activa rutas operativas, ni justifica un despliegue.

**Limitaciones pendientes:** la `_Store` empleada en la prueba es un almacén sintético en memoria; **no prueba Android Keystore**, `FlutterSecureStorage` real, persistencia entre procesos en dispositivo o recuperación tras reinicio físico. La seguridad operativa, custodia de claves reales y despliegue siguen sujetos a autorizaciones distintas. No confundir `MAIN_I8M_FLUTTER_TLS_RECOVERY_GATE=PASS` con `MFA_RELEASE_AUTHORIZED=YES`.

**Siguiente bloque recomendado:** integración Android física del almacenamiento nativo con los fences de recuperación y ensayos de kill/restart, sin publicar servicio ni migrar DEV. D1 despliegue permanece expresamente pospuesto por decisión del usuario.

## AP. I8-N Android Keystore real, persistencia entre procesos: gate preparado (08/11/2026)

Después de `MAIN_I8M_FLUTTER_TLS_RECOVERY_GATE=PASS`, el foco pasa a Android físico sin desplegar. Se crean/actualizan **directamente en main**:

- `clients/flutter/integration_test/native_i8n_android_restart_secure_store_test.dart` (commits `1d3c18f5`, `76fff440`): prueba `integration_test` habilitada solo para Android con `VENCIRA_I8N_ANDROID_LAB=true`, dividida en invocaciones separadas `seed`, `verify`, `cleanup`. Usa el plugin real `FlutterSecureStorage` mediante `FlutterNativeSecretStore`, `NativeRefreshCredentialVault`, `NativeRefreshRecoveryJournal` y `NativeMobileStartupGate`. Almacena exclusivamente un token sintético en el namespace `vencira_i8n_restart_lab_v1` y comprueba que el fence sigue cerrado tras reabrir el proceso. Nunca solicita red ni se conecta a DEV.
- `clients/flutter/android/app/build.gradle.kts` (commit `44bf265d`): `VENCIRA_I8N_LAB_BUILD=1` genera exclusivamente un paquete debug separado `es.vencira.vencira.i8nlab`, mutuamente excluyente con G8/G12/G13/G15 y prohibido para release/profile.
- `docs/I8N_ANDROID_KEYSTORE_RESTART_2026-11-08.md` (commit `e79223c9`): procedimiento de análisis Flutter en VPS, ejecución por fases con Android SDK/ADB en un host conectado, interpretación precisa de la persistencia, y limpieza de claves **solo del namespace de laboratorio**.

**No hay aún resultado de `flutter analyze` del archivo I8-N ni ejecución en teléfono**. Tener el test en `main` no equivale a probar Android Keystore real. Para acreditar persistencia entre procesos se debe observar `seed=PASS`, `verify=PASS` y `cleanup=PASS` en ejecuciones independientes sin desinstalar ni borrar datos entre ellas. Si `flutter test` reinstala/limpia datos, se debe adaptar el runner antes de interpretar resultados. El VPS no dispone necesariamente de ADB al teléfono; no inferir acceso USB a partir de Termius.

Mantener `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`, sin cambio en Compose ni migración DEV.

## AQ. I8-N Android: warning estático y corrección (08/11/2026)

Primera ejecución local de `flutter analyze integration_test/native_i8n_android_restart_secure_store_test.dart` aportada por el operador: `1 issue found`, warning `unused_element` por constante `_refreshKey` no utilizada (línea 17). La salida de `flutter pub get` también indica 22 paquetes con versiones más nuevas incompatibles con los límites actuales; es aviso de versiones disponibles, no causa del warning. **No hay `I8N_ANDROID_STATIC_RESULT=0` acreditado en esta ejecución.**

Corrección publicada en `main` commit `219ebe21`: se elimina únicamente la constante sin uso. No hay cambios en el flujo `seed/verify/cleanup`, la configuración debug ni el acceso a Keystore.

**Próximo gate:** repetir `flutter analyze` sobre el SHA actualizado; después instrumentar el dispositivo Android real en tres procesos independientes, comprobando que el runner preserve los datos entre `seed` y `verify`. Ningún PASS físico declarado y ningún deploy autorizado.

## AR. I8-N: revalidación estática Flutter PASS (08/11/2026)

El operador repitió el análisis del test `integration_test/native_i8n_android_restart_secure_store_test.dart` después de la corrección `219ebe21` en `main` y aportó:

```text
Changed 97 dependencies!
22 packages have newer versions incompatible with dependency constraints.
Analyzing native_i8n_android_restart_secure_store_test.dart...
No issues found! (ran in 11.0s)
```

**Evidencia acreditada:** `flutter analyze` finalizó sin advertencias ni errores para el archivo I8-N. El comando original utilizaba `flutter pub get && flutter analyze` en un contenedor de Flutter con copia del proyecto en `/tmp`: la actualización de paquetes observada pertenece a ese entorno temporal, no demuestra cambios en el repositorio, la aplicación desplegada o DEV. El fragmento no incluye la línea explícita `I8N_ANDROID_STATIC_RESULT=0`, pero la salida de `No issues found!` acredita el análisis estático satisfactorio.

**No acreditado aún:** `flutter test` Android físico, instalación y persistencia entre tres procesos `seed/verify/cleanup`, conservación de datos del paquete debug `.i8nlab` entre invocaciones, y persistencia/recuperación después de terminación forzada. El ensayo real requiere un host con Android SDK y dispositivo ADB conectado; Termius sobre VPS sin ADB no equivale a ello. `MFA_RELEASE_AUTHORIZED=NO` y `NO_DEPLOY_NO_LIVE_MIGRATION=1` siguen vigentes.

## AS. I8-N sin ADB: APK manual de Keystore y transferencia mediante túnel SSH existente (08/11/2026)

El operador confirmó que ya utiliza la aplicación en el teléfono por conexión SSH/túnel Termux. Para **evitar requerir ADB** y preservar el paquete operativo existente, se ha incorporado en `main` una entrada Flutter **separada** de `main.dart`: `clients/flutter/lib/main_i8n_keystore_lab.dart` (commit `ca6c311a`), construida únicamente como debug `es.vencira.vencira.i8nlab` con `VENCIRA_I8N_LAB_BUILD=1` y `--dart-define=VENCIRA_I8N_ANDROID_LAB=true`.

La interfaz manual ofrece `seed` (refresh sintético + marker verificados en el namespace Keystore de laboratorio), `verify` (tras reinicio real del teléfono y nuevo proceso, confirma `fullReauthentication` y fence no activo), `cleanup` (verifica eliminación); no contiene red, login ni credenciales operativas. La prueba de Android instrumentada previa permanece como alternativa, pero no es prerrequisito para el ensayo manual.

`scripts/main_i8n_android_keystore_lab_apk_build.sh` (commit `e35ff5f0`) prepara la APK en Docker Flutter 3.44, copia del repo solo lectura, y deposita exclusivamente `~/vencira-i8n-phone/VENCIRA-I8N-Keystore-debug.apk` para descarga desde Termux mediante SCP/SFTP en la conexión SSH disponible. **La conexión SSH es transporte del artefacto**, no el canal HTTP de la prueba Keystore. Un reinicio completo cerrará Termux y no afecta al resultado del test de almacenamiento.

Se documentó el procedimiento en `docs/I8N_ANDROID_KEYSTORE_RESTART_2026-11-08.md` (commit `281f2bd6`). **Estado:** código integrado y analizadores de la prueba instrumentada previa PASS; la **nueva entrada UI APK no tiene análisis ni compilación ejecutada** y el teléfono todavía no ha probado `seed/verify/cleanup`. Exigir `I8N_APK_DEBUG_BUILD=PASS`, código shell 0, resultados 3/3 en pantallas y persistencia tras reinicio sin desinstalación. `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1` intactos.

## AT. I8-N APK Android física: tres pantallas PASS (operador 08/11/2026)

El operador aportó **cuatro capturas de pantalla de un dispositivo Android** ejecutando la APK aislada `VENCIRA · Keystore I8-N` (identidad de paquete prevista `es.vencira.vencira.i8nlab`). Los marcadores visibles, en secuencia temporal de interfaz, son:

```text
I8N_ANDROID_KEYSTORE_SEED=PASS
I8N_ANDROID_RESTART_RECOVERY_FENCED=PASS
I8N_ANDROID_KEYSTORE_CLEANUP=PASS
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```

**Interpretación probatoria:** `seed` demuestra escritura/lectura verificada de refresh sintético y marcador en el namespace de laboratorio; `verify` demuestra lectura válida del estado protegido por una nueva instancia del controlador y `NativeMobileStartupGate.fullReauthentication` con fence sin sesión activa; `cleanup` demuestra borrado verificado, retorno a `cleanLogin` no autenticado y ausencia de sesión. Los estados PASS son emitidos por la APK local y no implican conexión de red ni autenticación real. El hecho de que el marcador `verify` diga `RESTART` **no demuestra visualmente** que Android fue reiniciado, que murió el proceso anterior ni que no se reinstaló la APK: para certificar estrictamente persistencia **tras reinicio físico**, confirmar con el operador la secuencia completa sin borrado de datos. Las capturas sí acreditan éxito funcional de las tres operaciones reales de `FlutterSecureStorage` sobre Android.

**Pendiente:** prueba controlada de fallos de Keystore/lectura y una integración Android HTTPS de recuperación bajo red aislada; ni MFA operativo ni despliegue DEV autorizados. No se solicitó ni usó ADB; SSH/Termux solo transfirió el artefacto.

El resultado I8-M Flutter HTTPS Django PostgreSQL efímero se mantiene PASS de manera independiente; no confundir los dos gates como una única prueba móvil extremo a extremo.

## AU. Confirmación del reinicio físico Android I8-N (operador 08/11/2026)

Tras presentar capturas de `I8N_ANDROID_KEYSTORE_SEED=PASS`, `I8N_ANDROID_RESTART_RECOVERY_FENCED=PASS` e `I8N_ANDROID_KEYSTORE_CLEANUP=PASS`, el operador confirmó explícitamente que **sí hubo reinicio completo del teléfono** entre las fases «Guardar» y «Verificar». Conforme al procedimiento comunicado, la comprobación se realizó con la APK de laboratorio existente, sin necesidad de ADB.

**Gate I8-N de persistencia de almacenamiento Android tras reinicio físico: PASS, basado en las capturas de los tres estados y la confirmación directa del operador.** Se acredita lectura del refresh sintético y marcador persistente tras reinicio y bloqueo de la sesión (`fullReauthentication` sin ticket activo), seguido de borrado verificado. No se ha probado un refresh real ni una sesión móvil operativa; no se certifica revocación HTTPS desde Android ni manejo de fallo de almacenamiento nativo durante una recuperación de red real.

No se autoriza despliegue ni migración persistente: `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## AV. I8-O Android: laboratorio de fallos Keystore integrado en main, sin despliegue (08/11/2026)

**Antecedente acreditado:** I8-N Android Keystore `seed`, `verify` tras reinicio físico confirmado, y `cleanup` PASS; I8-M Flutter `IOClient` HTTPS real + Django/PostgreSQL17 efímero, recuperación MFA y revocación PASS. Los dos gates han sido distintos; todavía no se ha probado la recuperación real conjunta desde Android.

**Nuevo trabajo publicado exclusivamente en `main`:**
- `clients/flutter/lib/i8o_android_keystore_failure_lab.dart` (commit `5cd3495e`): ejecuta tres fallos **inyectados** (marcador no escribible; refresh no escribible con marcador armado; borrado de marcador omitido) contra `FlutterNativeSecretStore` real bajo namespace Android exclusivo `vencira_i8o_failure_lab_v1`. Acreditaría, si pasa en móvil, el cierre del fence, retención de marcadores, reautenticación obligatoria en un controlador reconstruido y cleanup separado. No HTTP, no cuentas reales, ni claves operativas.
- `clients/flutter/lib/main_i8n_keystore_lab.dart` (commit `2e764bd8`): agrega a la UI de laboratorio un botón `I8-O · Comprobar fallos seguros` sin alterar el arranque `clients/flutter/lib/main.dart`.
- `clients/flutter/android/app/build.gradle.kts` (commit `2480f449`): añade variante debug `VENCIRA_I8O_LAB_BUILD=1` con paquete **distinto** `es.vencira.vencira.i8olab`, excluyente de G8/G12/G13/G15/I8N, sin release ni profile. Esta separación es intencional porque una firma debug regenerada en contenedores distintos puede impedir actualizar el paquete I8-N ya instalado.
- `scripts/main_i8o_android_failure_lab_apk_build.sh` (commits `e248482d`, `722b2af7`): compila desde fuente `main` en imagen Flutter 3.44 y crea `~/vencira-i8o-phone/VENCIRA-I8O-FailureLab-debug.apk`, sin escritura en el checkout, deploy ni migración DEV. Incluye análisis estático del nuevo código I8-O.
- `docs/I8O_ANDROID_SECURE_STORE_FAILURE_LAB_2026-11-08.md` (commits `e9552891`, `211ebd77`): procedimiento SSH/Termux, verificación de las cinco marcas y límites de la prueba.

**Estado preciso:** código en `main`, **compilación Android I8-O no ejecutada aún**, sin evidencias de `flutter analyze`, sin ejecución física ni validación de fallos. El gate I8-O requiere `I8O_APK_DEBUG_BUILD=PASS` y las marcas `I8O_ANDROID_MARKER_WRITE_DENIED=PASS`, `I8O_ANDROID_REFRESH_WRITE_DENIED=PASS`, `I8O_ANDROID_MARKER_DELETE_DENIED=PASS`, `I8O_ANDROID_FAILURE_FENCE=PASS`, `I8O_ANDROID_FAILURE_LAB_CLEANUP=PASS`. En caso de fallo no inferir nada de una captura parcial.

**No interpretar los fallos simulados como fallos de Keystore auténticos**; se prueba la capacidad del cliente para cerrarse correctamente al recibir errores del wrapper. Pendientes integración Android HTTPS real y ensayo operativo de custodia/revocación sin tocar DEV. `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## AW. I8-O: prueba física de fallos sintéticos Android PASS (operador 08/11/2026)

El operador aportó captura del teléfono Android ejecutando el laboratorio `VENCIRA · Keystore I8-N` con el botón `I8-O · Comprobar fallos seguros`. La pantalla confirma íntegramente los cinco marcadores:

```text
I8O_ANDROID_MARKER_WRITE_DENIED=PASS
I8O_ANDROID_REFRESH_WRITE_DENIED=PASS
I8O_ANDROID_MARKER_DELETE_DENIED=PASS
I8O_ANDROID_FAILURE_FENCE=PASS
I8O_ANDROID_FAILURE_LAB_CLEANUP=PASS
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```

**Resultado:** gate de inyección de errores I8-O en Android físico **5/5 PASS** según evidencia visual. Se verificó la gestión *fail-closed* de fallos simulados de escritura del marcador/refresh, omisión de borrado del marcador, fence de sesión y limpieza de claves sintéticas en el namespace de prueba. **No son fallos espontáneos/reales del Android Keystore**, sino situaciones provocadas por el wrapper `_FaultStore` delante del plugin real. No se ha producido autenticación, emisión de credenciales ni revocación remota en este ensayo.

**Evidencias anteriores vigentes:** I8-N Android persistencia tras reinicio físico PASS; I8-M cliente Flutter `IOClient` + Django HTTPS + PG17 efímero, recuperación password/TOTP y revocación compensatoria PASS. **Falta aún un único ensayo móvil end-to-end por HTTPS con almacenamiento seguro real**, usando solo backend temporal y tráfico tunelizado/verificado, no DEV. No confundir tres gates separados con integración operativa completa.

**Observación de presentación:** la cabecera sigue mostrando `Keystore I8-N` en la APK que contiene el botón I8-O; conviene corregirla en un build futuro, sin bloquear la certificación de seguridad. No despliegue ni migración persistente; `MFA_RELEASE_AUTHORIZED=NO` y `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## AX. I8-P paquete integrado Android físico HTTPS/MFA/Keystore/PG17 por SSH (08/11/2026)

Antecedentes comprobados: I8-M Flutter HTTPS + Django/PG17 sintéticos PASS; I8-N Android Keystore con reinicio físico PASS; I8-O fallos simulados sobre Keystore físico 5/5 PASS. El usuario solicitó **agrupar y acelerar** el cierre Android sin desplegar.

El nuevo I8-P agrupa en una prueba Android física integrada, con contrato de validación explícito:
- `clients/flutter/lib/main_i8p_android_https_lab.dart` (`8aefcff3`, endurecimiento de 401 `a7339ec2`): app Flutter debug exclusiva y sin entrada operativa, conecta únicamente a loopback Android puerto 18743, túnel SSH hacia relay VPS, TLS con contexto de confianza solo para CA pública temporal e identidad `dev.vencira.es`, verificación de mismatch, recuperación password→TOTP **sintéticos**, refresh realmente confirmado en `FlutterSecureStorage`, revocación HTTP y 401 para access antiguo, cleanup local. Marcadores Android **pendientes de ejecutar**.
- `clients/flutter/android/app/build.gradle.kts` (`e6893778`): `VENCIRA_I8P_LAB_BUILD=1` añade paquete separado `es.vencira.vencira.i8plab` para debug, mutuamente excluyente con G8/G12/G13/G15/I8N/I8O; prohibido release/profile. `clients/flutter/pubspec.yaml` (`7f10e736`) mueve `crypto` a dependencies para la generación TOTP sintética del target Flutter; **sin migración de datos ni cambios de backend operativo**.
- `scripts/main_i8p_ssh_tls_loopback_relay.py` (`5722edeb`, comentario `58014943`): traslado de bytes TLS cifrados en localhost VPS 18743 a servidor Docker privado 443, sin publicar puerto.
- `scripts/main_i8p_android_ssh_https_pg17_lab.sh` (`2fb7b8b7`): contenedores desechables Django + PG17 tmpfs en red `--internal`, test URLconf de recuperación, CA pública temporal compilada en APK, claves privadas nunca en Android, usuario/sesiones sintéticas, verificación SQL final de ambas sesiones revocadas, trap de limpieza y comprobación DEV intacto. Mantiene tmux y relay hasta que operador recopile resultado en teléfono.
- `docs/I8P_ANDROID_HTTPS_KEYSTORE_SSH_LAB_2026-11-08.md` (`b22e3a75`): instrucciones completas paso único de VPS, copia SCP con SSH existente, túnel local 18743 y resultados esperados de cliente y PG17.

**Estado de publicación:** integrados en `main`, **ninguna prueba I8-P ejecutada ni certificada**. Exigir `bash -n`, compilación Flutter, gate TLS/MFA/Keystore sobre dispositivo Android, respuesta 401 tras revocación y `I8P_PG17_OLD_AND_NEW_SESSION_REVOKED=PASS`, `I8P_DEV_CONTAINERS_UNCHANGED=OK` y resultado final 0. Los gates anteriores I8-M/I8-N/I8-O no sustituyen esta evidencia. El cliente I8-P no tiene contraseña configurable, usa solo fixtures sintéticas, y nunca se entrega como release.

**Deploy/DEV:** intocados por diseño. `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1` y `I8P_RELEASE_AUTHORIZED=NO`. I8-P no prueba custodia real ni autorización de despliegue.

## AY. I8-P primer intento: warning Flutter de importación (08/11/2026)

El operador ejecutó `scripts/main_i8p_android_ssh_https_pg17_lab.sh` en VPS y el proceso se detuvo al analizar `clients/flutter/lib/main_i8p_android_https_lab.dart`:

```text
info • The import of 'dart:typed_data' is unnecessary because all of the used elements are also provided by the import of 'package:flutter/foundation.dart'
1 issue found. (ran in 10.1s)
I8P_DEV_CONTAINERS_UNCHANGED=OK
I8P_DEPLOY_EXECUTED=NO
I8P_LIVE_MIGRATIONS_EXECUTED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
I8P_LAB_RESULT=1
```

El aviso `22 packages have newer versions incompatible with dependency constraints` corresponde a dependencias disponibles fuera de los constraints actuales, **no** al error de análisis. El gate `flutter analyze` de Flutter considera esta información como issue y abortó la compilación. **No hay APK I8-P acreditada ni gate Android ejecutado.** El trap desmontó el laboratorio y confirmó DEV intacto.

Corrección directa en `main` commit `de18003c`: se elimina solamente `import 'dart:typed_data';` de la entrada I8-P; `ByteData` continúa disponible por `package:flutter/foundation.dart`. No hay cambios a TLS, autenticación, PostgreSQL, Keystore ni despliegue.

**Pendiente:** reejecutar `scripts/main_i8p_android_ssh_https_pg17_lab.sh` y exigir una salida limpia de análisis, APK compilada, marcador Android de HTTPS/MFA/Keystore/revocación y comprobación SQL de PostgreSQL efímero antes de declarar PASS.

## AZ. I8-P Android físico: interfaz HTTPS/MFA/Keystore/revocación 5/5 PASS (08/11/2026)

El operador aportó captura del teléfono Android con la APK debug aislada `VENCIRA · Android I8-P`. La pantalla muestra:

```text
I8P_ANDROID_TLS_HOSTNAME=PASS
I8P_ANDROID_RECOVERY_MFA_KEYSTORE=PASS
I8P_ANDROID_REMOTE_REVOKE=PASS
I8P_ANDROID_ACCESS_AFTER_REVOKE_401=PASS
I8P_ANDROID_LAB_CLEANUP=PASS
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```

**Resultado acreditado:** gate del **cliente Android físico 5/5 PASS**, incluida la comunicación HTTPS con CA pública y hostname verificados mediante el túnel SSH, recuperación de cuenta sintética por contraseña+TOTP, escritura/lectura de refresh real en almacenamiento protegido Android, revocación remota y rechazo HTTP 401 del access después de revocar, seguido de limpieza del namespace I8-P.

**No certificar todavía el gate global I8-P:** falta la salida de la sesión VPS después de pulsar INTRO que compruebe `I8P_PG17_OLD_AND_NEW_SESSION_REVOKED=PASS`, `I8P_ANDROID_TLS_MFA_KEYSTORE_GATE=PASS`, `I8P_DEV_CONTAINERS_UNCHANGED=OK`, `I8P_LAB_RESULT=0`. La captura del móvil no sustituye el postcheck SQL ni acredita por sí sola el teardown del laboratorio.

No hubo activación de MFA operativa, publicación de endpoint ni autorización de despliegue; continúan `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## BA. I8-P Android físico + SQL de PG17 temporal: gate completo PASS (08/11/2026)

Tras la captura Android que acredita los cinco marcadores TLS/MFA/Keystore/revocación/401/cleanup, el operador cerró la sesión del laboratorio I8-P en el VPS y compartió:

```text
I8P_PG17_OLD_AND_NEW_SESSION_REVOKED=PASS
I8P_ANDROID_TLS_MFA_KEYSTORE_GATE=PASS
I8P_DEV_CONTAINERS_UNCHANGED=OK
I8P_DEPLOY_EXECUTED=NO
I8P_LIVE_MIGRATIONS_EXECUTED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
I8P_LAB_RESULT=0
```

**Resultado acreditado:** I8-P **PASS extremo a extremo en laboratorio**, con Android físico, transporte HTTPS verificado a través de SSH, autenticación de recuperación contraseña+TOTP sintéticas, credencial refresh guardada/leída en Keystore, revocación remota y rechazo 401, más confirmación SQL en PostgreSQL17 efímero de que la sesión antigua y la nueva están revocadas. El proceso confirmó que las identidades de los contenedores DEV no cambiaron y no ejecutó despliegue/migraciones persistentes. El teardown corrió por el trap de salida; `I8P_LAB_RESULT=0` demuestra que el ejecutor finalizó correctamente, no por sí solo una auditoría independiente de inexistencia de recursos Docker residuales.

**No sustituye autorización de publicación ni pruebas operativas:** continúan pendientes la recuperación ante fallos reales de red y/o almacenamiento durante el flujo Android, custodia de claves de servicio, backup/restauración y compatibilidad de migraciones para DEV. Restricciones: `MFA_RELEASE_AUTHORIZED=NO` y `NO_DEPLOY_NO_LIVE_MIGRATION=1`. No incluir `native_mobile_service` en apps operativas ni publicar sus URLconf test-only.

## BB. I8-Q regresión agrupada de ambigüedad y fallos de recuperación (08/11/2026)

Tras cierre I8-P Android físico+PostgreSQL17 temporal **PASS**, se integran directamente en `main` tres regresiones de fallo `clients/flutter/test/native_i8q_recovery_fault_matrix_test.dart` (commit `84c3a5f4`): timeout de contraseña; respuesta MFA posiblemente comprometida pero perdida sin reintento; y fallo de almacenamiento tras emisión con revocación compensatoria también sin confirmación. La prueba exige que el checkpoint durable sobreviva, no se active bearer, y un nuevo controlador exija reautenticación.

Se añade gate agrupado `scripts/main_i8q_android_recovery_fault_matrix_local.sh` (commit `06ba985b`) que ejecuta `flutter analyze` y **cuatro** suites de regresión HTTP/recuperación en Docker de solo lectura respecto al código del VPS, sin endpoints vivos. Incluye comprobaciones DEV y trap final. Procedimiento y limitaciones en `docs/I8Q_NATIVE_RECOVERY_FAULT_MATRIX_2026-11-08.md` (commit `04121ca5`).

**Estado: publicado en main, PENDIENTE ejecución de gate.** La matriz de errores I8-Q usa HTTP/almacenamiento sintéticos; no es prueba física de pérdida de red de Android ni sustituye I8-P. Nunca declarar I8-Q PASS sin `All tests passed!`, `I8Q_FLUTTER_FAULT_MATRIX_GATE=PASS`, `I8Q_DEV_CONTAINERS_UNCHANGED=OK`, y resultado cero.

`MFA_RELEASE_AUTHORIZED=NO`; `NO_DEPLOY_NO_LIVE_MIGRATION=1` siguen intactos; despliegue pospuesto expresamente.

## BC. I8-Q matriz agrupada Flutter de ambigüedad: 30/30 PASS (operador 08/11/2026)

El operador ejecutó `scripts/main_i8q_android_recovery_fault_matrix_local.sh` y aportó la salida final:

```text
00:01 +30: All tests passed!
I8Q_FLUTTER_FAULT_MATRIX_GATE=PASS
I8Q_DEV_CONTAINERS_UNCHANGED=OK
I8Q_DEPLOY_EXECUTED=NO
I8Q_LIVE_MIGRATIONS_EXECUTED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
I8Q_LOCAL_RESULT=0
```

**Resultado acreditado:** cuatro suites de regresión Flutter completadas, **30/30 PASS**, con fallo cero y sin cambios de identidades de los contenedores DEV. Incluyen `native_i8q_recovery_fault_matrix_test.dart` (timeout de contraseña, resultado MFA ambiguo sin reintento, fallo de escritura y revocación sin respuesta), además de las suites de recuperación HTTP, contrato de transporte y endpoint. La salida final no reproduce de manera individual los tres `I8Q_...=PASS`, pero `All tests passed!` y el gate conjunto PASS confirman la ejecución satisfactoria de la matriz incluida por el script.

**Límites:** los fallos I8-Q son inyectados con MockClient y almacén sintético, no cortes reales del túnel Android ni fallos auténticos Keystore. Los gates previos I8-M, I8-N, I8-O e I8-P permanecen acreditados de manera independiente; no confundir sus alcances. El próximo bloque integra interrupciones controladas en el flujo de red real Android↔Django efímero y reconciliación PG17, sin habilitar infraestructura operativa.

**Restricciones:** `MFA_RELEASE_AUTHORIZED=NO` y `NO_DEPLOY_NO_LIVE_MIGRATION=1` sin cambios; ninguna migración persistente ni despliegue.

## BD. Inicio paralelo B2+B3 con un solo gate de solo lectura (08/11/2026)

Se confirmó por inspección de `main` que la **APK normal Android aún abre el sistema web externo** mediante `AndroidWebAccessScreen` y `LaunchMode.externalApplication`. No utiliza directamente los clientes `NativeHttpAuthPort` / `NativeMobileRecoveryEntry` validados en I8-P. Los PASS I8-M–I8-Q son reales **en sus respectivos laboratorios**, pero no equivalen a una APK nativa funcional autorizada. Esto es un bloqueo B2 verificable y se evita describir el trabajo restante como meros retoques visuales.

Commits de trabajo directo sobre `main`:
- `725a3bbb`: `scripts/main_closure_source_inventory_readonly.py` — inventario de entrypoint Android/web, aislamiento de rutas móviles candidatas, pantallas Flutter de dominio presentes y dependencias estáticas de `reminders.0019–0027`. Los archivos presentes se rotulan `SOURCE_PRESENT_NOT_VISUALLY_TESTED`, no PASS funcional. No consulta datos ni ejecuta migraciones.
- `2c0bf8e6`: `scripts/main_closure_grouped_readonly_gate.sh` — una invocación de B2 fuente + `d1b_dev_compose_o5_metadata_readonly.py` para B3 metadatos Docker Compose y servicios O5. Sin backup/restauración real, sin claves, sin SQL ni cambios en DEV.
- `157995b8`: detalle de operación, criterios y límites añadido a `docs/REMAINING_WORK_GROUPED_2026-11-08.md`.

**Estado:** publicados pero **todavía sin ejecutar** en VPS. Se requiere `CLOSE_COMBINED_SHELL_RESULT=0`, `CLOSE_DJANGO_OPERATIONAL_NATIVE_ROUTE_FENCE=PASS` y `D1B_COMPOSE_PROJECT=vencira_localcheck`; cualquier mismatch se debe investigar, no corregir alterando servicios. I8-R Android HTTPS con interrupciones controladas permanece pendiente. Los backup/restore/migration rehearsal D1 continúan no verificados. `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## BE. Resultado del preflight B2+B3 y diagnóstico corregido de O5 (08/11/2026)

El operador ejecutó con `CLOSE_MAIN_SHA=907431e9f96b0e540b6891028f9ddc026c8214b2` la auditoría solo lectura, obteniendo `CLOSE_COMBINED_PREFLIGHT=PASS` y `CLOSE_PREFLIGHT_RESULT=0`. Se detectaron 10/10 archivos Flutter de pantallas, **ninguno visualmente acreditado por este inventario**. La APK Android operativa abre el navegador externo, **no** integra `NativeMobileRecoveryEntry`; rutas Django de auth nativa candidata siguen bloqueadas. Se detectaron nueve migraciones de `reminders.0019–0027`, sin ejecutar `migrate`, backup ni restauración. Se marcaban tres como `REVIEW_DYNAMIC_DEPENDENCIES`, no porque faltase dependencia, sino porque el parser intentaba evaluar la lista completa con `ast.literal_eval` y las tres incluyen `migrations.swappable_dependency(settings.AUTH_USER_MODEL)`.

El diagnóstico D1B informó `D1B_COMPOSE_PROJECT=vencira_localcheck`, archivos `compose.yaml,compose.preview.yaml` y directorio `vencira-localcheck`. Las unidades `o5-backup.timer`, `o5-health.timer`, `o5-backup.service` y `o5-health.service` se devolvieron como `inactive`/`not-found` **en el manager systemd del sistema**, sin consultar el manager de usuario. Por tanto el resultado **no demuestra que falten backups**, sino que la consulta D1B no encontró esas unidades en ese scope. Tampoco demuestra que los backups funcionen: `D1B_BACKUP_RESTORE_VERIFIED=NO`. Se observaron reintentos sudo por contraseña incorrecta antes del éxito; no hubo modificación de servicios. `D1B_RESULT=0` solo certifica que el inventario devolvió metadatos correctamente.

Para eliminar ambigüedad:
- `scripts/d1c_o5_scope_units_readonly.py` (`36099574`): consulta `LoadState` y `ActiveState` tanto en el gestor systemd del sistema como de usuario, sin abrir archivos/secretos. Salidas de ausencia o gestor no disponible no se convierten en PASS de backup. No inicia ni cambia unidades.
- `scripts/main_closure_source_inventory_readonly.py` (`5ce91687`): reconoce las dependencias `swappable_dependency` estándar y mantiene `UNKNOWN_DYNAMIC` para expresiones verdaderamente no reconocidas, sin importar ni ejecutar migraciones.
- `scripts/main_closure_grouped_readonly_gate.sh` (`84b65363`): agrupa inventario B2, metadatos D1B y diagnóstico D1C en un solo comando.

**Estado:** correcciones en `main`, validación VPS de D1C y nuevo parser pendiente. Comando: `bash scripts/main_closure_grouped_readonly_gate.sh` tras `git fetch origin main && git merge --ff-only FETCH_HEAD`. Exigir `CLOSE_D1C_O5_SCOPE_DIAGNOSTIC=PASS` y `CLOSE_COMBINED_PREFLIGHT=PASS`; además evaluar la **clasificación** `D1C_O5_UNIT_REGISTRATION` en vez de interpretarla como salud. Restauración O5 y migración real en clon PG17 **todavía pendientes**. I8-R Android HTTPS corte de transporte también pendiente. `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## BF. D1-C resultado real: migraciones estáticas claras, O5 no localizado (operador 09/11/2026)

El operador ejecutó el gate combinado sobre el SHA `8d4f3c916ab314adfdb620fbc6edc1826992cd75`. Evidencias:

```text
CLOSE_REMINDERS_0019_0027_FILES=9
CLOSE_REMINDERS_UNKNOWN_STATIC_DEPENDENCIES=0
CLOSE_REMINDERS_DJANGO_SWAPPABLE_AUTH_DEPENDENCIES=3
CLOSE_DJANGO_OPERATIONAL_NATIVE_ROUTE_FENCE=PASS
CLOSE_ANDROID_NORMAL_ENTRY=EXTERNAL_BROWSER_ONLY
CLOSE_NATIVE_RECOVERY_WIRED_TO_MAIN=NO
CLOSE_FLUTTER_SCREENS_SOURCE_PRESENT=10/10
D1B_COMPOSE_PROJECT=vencira_localcheck
D1C_SYSTEM_UNITS_LOADED=0
D1C_USER_UNITS_LOADED=0
D1C_O5_UNIT_REGISTRATION=NOT_VERIFIED
D1C_O5_SNAPSHOT_VALID=NOT_VERIFIED
D1C_O5_RESTORE_VALID=NOT_VERIFIED
CLOSE_COMBINED_PREFLIGHT=PASS
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```

**Conclusiones limitadas:** parser corregido confirma la cadena literal anterior en las nueve migraciones y reconoce correctamente las tres dependencias `migrations.swappable_dependency(settings.AUTH_USER_MODEL)`. **No demuestra aplicación ni rollback en DEV.** La APK normal continúa abriendo el navegador, sin acceso nativo integrado. Diez archivos de interfaz presentes no son diez pantallas funcionalmente probadas.

La búsqueda D1-C de **cuatro nombres exactos** O5 en ambos ámbitos systemd devuelve `not-found`; no hay unidades O5 cargadas con esos nombres en el ámbito consultado. **No permite afirmar que no existan backups ni que hayan fallado:** podrían tener otros nombres, estar registrados en otro usuario o estar gestionados de otra manera. No hay backup restaurado ni continuidad O5 acreditada en esta revisión. Hubo errores iniciales de contraseña sudo antes de que el inventario Compose continuara, sin modificación de servicios.

Se publica `scripts/d1d_backup_scheduler_names_readonly.py` (commit `5a708f2b`), diagnóstico siguiente **sin sudo**: lista exclusivamente nombres filtrados de archivos de unidades systemd, sus directorios *.wants y entradas cron habituales, y nombres de unidades de systemd reconocidas (scope de sistema y usuario). No lee contenidos, credenciales, registros ni archivos de backup. Tampoco inicia servicios. Si no encuentra coincidencias, el resultado **no acredita la inexistencia de backups**; queda pendiente identificar el usuario/canal real y verificar Restic mediante un ensayo controlado.

**Ejecución VPS:**
```bash
cd ~/vencira-main-check-20261108
git fetch origin main
git merge --ff-only FETCH_HEAD
python3 scripts/d1d_backup_scheduler_names_readonly.py
echo "D1D_SHELL_RESULT=$?"
```

Prioridad: resolver la evidencia de backups/restore antes de cualquier ensayo que se proponga sobre la base persistente. `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## BG. D1-D descubrió los nombres reales de las tareas O5 — 09/11/2026

El operador ejecutó el script `scripts/d1d_backup_scheduler_names_readonly.py` y compartió:

```text
D1D_MATCH=system:timers.target.wants_vencira-o5-backup.timer
D1D_MATCH=system:timers.target.wants_vencira-o5-health.timer
D1D_MATCH=system:vencira-o5-backup.service
D1D_MATCH=system:vencira-o5-backup.timer
D1D_MATCH=system:vencira-o5-health.service
D1D_MATCH=system:vencira-o5-health.timer
D1D_UNIT_OR_CRON_NAMES_FOUND=6
D1D_SYSTEM_UNIT_NAME=vencira-o5-backup.service
D1D_SYSTEM_UNIT_NAME=vencira-o5-backup.timer
D1D_SYSTEM_UNIT_NAME=vencira-o5-health.service
D1D_SYSTEM_UNIT_NAME=vencira-o5-health.timer
D1D_SYSTEM_UNIT_NAMES_FOUND=4
D1D_USER_UNIT_NAMES_FOUND=0
D1D_BACKUP_EXISTS=NOT_VERIFIED
D1D_BACKUP_RESTORE=NOT_VERIFIED
D1D_BACKUP_SCHEDULE_ACTIVE=NOT_VERIFIED
D1D_RESULT=0
D1D_SHELL_RESULT=0
```

**Corrección de diagnóstico:** D1-B y D1-C preguntaban por `o5-backup.*`/`o5-health.*` y por tanto devolvían `not-found`, pero **las unidades registradas llevan el prefijo `vencira-`**. Es una diferencia de nombre, no prueba de fallo del backup. Existen asimismo enlaces bajo `timers.target.wants`, pero su presencia por sí sola no demuestra activación actual o ejecuciones satisfactorias.

Cambios integrados directamente en `main`:
- `48cec940`: D1-C consulta las cuatro unidades systemd con nombres correctos.
- `3e6f2cd1`: D1-B consulta las unidades correctas y preserva la comprobación de Compose.
- `ec8e4c31`: nuevo `scripts/d1e_o5_actual_units_health_readonly.py` consulta estados de carga, actividad, habilitación, resultados y presencia de última/próxima ejecución con `systemctl show` **sin contenido de unidades, logs ni secretos**. Un servicio `.service` `inactive` entre ejecuciones puede ser normal; no se confunde con fallo.
- `4554bc38`: añade D1-E al comando combinado de solo lectura.

**PENDIENTE de ejecución** de D1-E. Ejecutar el gate agrupado tras actualizar `main`; comprobar `D1E_ACTIVE_TIMERS`, estado `vencira-o5-backup.timer` y resultado del servicio. Cualquier `D1E_RESULT=0` solo indica éxito de consulta: **no certifica snapshot Restic ni restauración**. No ejecutar jobs de backup ni tocar servicios automáticamente. La fase posterior debe examinar de forma acotada la existencia y restauración de un snapshot O5, sin revelar credenciales y sobre clon temporal.

`MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`; ninguna migración ni despliegue.

## BH. D1-E O5: ambos temporizadores activos, últimas unidades con éxito (09/11/2026)

El operador ejecutó `scripts/main_closure_grouped_readonly_gate.sh` en el commit `c486d2e04b4336273dce3536e43300e29c003f1d`. Registró `CLOSE_SHELL_RESULT=0`, `CLOSE_COMBINED_PREFLIGHT=PASS`, `D1E_RESULT=0`, `D1C_SYSTEM_UNITS_LOADED=4`, `D1C_USER_UNITS_LOADED=0`.

Evidencias específicas:
```text
D1B_VENCIRA_O5_BACKUP_TIMER_ACTIVE=active
D1B_VENCIRA_O5_BACKUP_TIMER_ENABLED=enabled
D1B_VENCIRA_O5_HEALTH_TIMER_ACTIVE=active
D1B_VENCIRA_O5_HEALTH_TIMER_ENABLED=enabled
D1E_O5_BACKUP_TIMER_LOAD=loaded
D1E_O5_BACKUP_TIMER_ACTIVE=active
D1E_O5_BACKUP_TIMER_UNIT_FILE_STATE=enabled
D1E_O5_BACKUP_TIMER_LAST_TRIGGER_PRESENT=YES
D1E_O5_BACKUP_TIMER_NEXT_ELAPSE_PRESENT=YES
D1E_O5_HEALTH_TIMER_LOAD=loaded
D1E_O5_HEALTH_TIMER_ACTIVE=active
D1E_O5_HEALTH_TIMER_UNIT_FILE_STATE=enabled
D1E_O5_HEALTH_TIMER_LAST_TRIGGER_PRESENT=YES
D1E_O5_HEALTH_TIMER_NEXT_ELAPSE_PRESENT=YES
D1E_O5_BACKUP_SERVICE_RESULT=success
D1E_O5_BACKUP_SERVICE_EXEC_MAIN_STATUS=0
D1E_O5_HEALTH_SERVICE_RESULT=success
D1E_O5_HEALTH_SERVICE_EXEC_MAIN_STATUS=0
D1E_ACTIVE_TIMERS=2/2
D1E_O5_BACKUP_SUCCESS=NOT_VERIFIED
D1E_O5_RESTIC_SNAPSHOT=NOT_VERIFIED
D1E_O5_RESTORE=NOT_VERIFIED
```

**Interpretación:** el planificador O5 está instalado/activo en systemd del sistema y ambos timers muestran última activación y próxima programación. Los servicios finalizaron con `Result=success` y código 0 en sus ejecuciones registradas; `inactive` entre ejecuciones es normal. **No** está comprobada la fecha/frescura concreta del snapshot ni su existencia/integridad/restauración real. No confundir `Result=success` con recuperación ante desastre probada. Se mantiene D1-B/D1-C como solo lectura.

**Siguiente paso controlado:** localizar el procedimiento operativo O5 real fuera del checkout actual (la documentación histórica `docs/OPERATION_O5_DRIVE_BACKUPS.md` no aparece en la rama `main` de este repositorio), inspeccionar los metadatos de snapshots mediante el mecanismo ya configurado sin mostrar rutas privadas ni contraseñas; restaurar únicamente sobre PostgreSQL 17 temporal siguiendo un plan de aislamiento explícito. No ejecutar `systemctl start`, `restic restore` o migraciones contra DEV sin procedimiento verificado.

**Seguridad:** `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1` siguen vigentes.

## BI. 09/11/2026 — D1-F: topología operativa O5 integrada sin acceder a secretos

Se confirma el resultado del operador en D1-E: `D1E_ACTIVE_TIMERS=2/2`, `vencira-o5-backup.timer` y `vencira-o5-health.timer` activos/habilitados, última activación y próxima elapse presentes; sus servicios informan `Result=success` y `ExecMainStatus=0`. El gate de inventario terminó en `CLOSE_SHELL_RESULT=0`, sin cambios de DEV ni migraciones. Esto **no acredita** integridad/frescura del repositorio Restic ni recuperación de un snapshot.

Se incorporó a `main` `scripts/d1f_o5_service_topology_readonly.py` (commit `8b49bfb5`): inspección *local* y sin elevación de archivos de las unidades systemd instaladas, con salida limitada a nombres de fichero auxiliares sanitizados y cantidades de directivas de ejecución/configuración. **No ejecuta restic/rclone, no imprime argumentos, rutas absolutas ni secretos, y no lee EnvironmentFile.** Se incorporó al gate agrupado (commit `ae31d854`). El plan general se actualizó (commit `9dd13c33`).

**Pendiente de validación VPS:** `python3 scripts/d1f_o5_service_topology_readonly.py`, `D1F_RESULT=0`; si no identifica scripts, no implica ausencia de ellos, podrían ser invocados por wrappers, drop-ins o unidades auxiliares. No se ha implementado ni ejecutado todavía un restore/clon a partir de O5 porque aún falta identificar con certeza el contrato de ejecución y el repositorio seguro. El trabajo I8-R y la integración funcional de la APK permanecen pendientes y no se marcan PASS.

Siguen `MFA_RELEASE_AUTHORIZED=NO` y `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## BJ. 09/11/2026 — D1-F PASS; clasificación segura del objetivo de ejecución D1-G

El operador envió resultado `D1F_RESULT=0` del diagnóstico de solo lectura D1-F. Ambas unidades `vencira-o5-backup.service` y `vencira-o5-health.service` se encuentran cargadas, sus archivos de unidad se pueden leer y hay **una directiva de ejecución en cada servicio**. El inventario no encontró ninguna directiva `EnvironmentFile` ni `Environment` en el cuerpo principal de los archivos consultados; **esto no descarta configuración externa mediante drop-ins, scripts, variables de entorno de proceso o mecanismos alternativos**. El identificador de helper devolvió `NO` para ambos servicios, pero esa búsqueda D1-F solo cubre nombres `.sh` o `.py` con patrones de ruta determinados. Por tanto no se concluye que no existan scripts, solo que no fueron identificados con esa heurística.

**Permanecen explícitamente SIN VERIFICAR:** repositorio y frescura del snapshot Restic; restauración real; grafo `reminders.0019–0027` sobre clon PostgreSQL 17; APK funcional nativa. D1-F no ejecutó backup ni restore y no cambió DEV; `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

Para evitar repetir la búsqueda anterior, se incorporó a `main` el script `scripts/d1g_o5_exec_target_readonly.py` (commit `5dc9f828`), que **clasifica** el primer ejecutable de la directiva `ExecStart` como intérprete, herramienta, wrapper del proyecto u otro, indica si tiene argumentos y si existe un helper local detectado, **sin imprimir comandos, rutas, nombres arbitrarios, argumentos, contenidos auxiliares, credenciales, logs ni repositorios**. En ningún momento lanza las directivas encontradas. Su revisión en VPS aún está pendiente.

```bash
cd ~/vencira-main-check-20261108
git fetch origin main
git merge --ff-only FETCH_HEAD
python3 -m py_compile scripts/d1g_o5_exec_target_readonly.py
python3 scripts/d1g_o5_exec_target_readonly.py
echo "D1G_SHELL_RESULT=$?"
```

**Criterio:** `D1G_RESULT=0` con salida acotada `D1G_BACKUP_EXEC_CLASS`, `D1G_BACKUP_HELPER_TARGET` y equivalentes para HEALTH. D1G no confirma que la copia exista: el siguiente gate será la lectura controlada de metadatos del repositorio respaldado por el procedimiento operativo realmente identificado y, después, ensayo de restauración aislada, no restauración en DEV. D1-G no es una autorización de despliegue.

## BK. D1-G primera ejecución: `PermissionError` en metadatos del wrapper O5 — 09/11/2026

El operador devolvió:
```text
D1G_READ_ONLY=YES
D1G_NO_SECRET_OR_HELPER_CONTENT_READ=YES
D1G_NO_BACKUP_OR_RESTORE=YES
D1G_BACKUP_EXECSTART_COUNT=1
D1G_BACKUP_EXEC_CLASS=PROJECT_WRAPPER
D1G_BACKUP_ARGS_PRESENT=NO
D1G_BACKUP_EXEC_PATH_ABSOLUTE=YES
D1G_BACKUP_HELPER_TARGET=DETECTED
D1G_ERROR_TYPE=PermissionError
D1G_RESULT=1
D1G_SHELL_RESULT=1
```

**Interpretación precisa:** D1-G detectó que el servicio de backup usa un ejecutable/wrapper del proyecto con ruta absoluta y sin argumentos directos. Falló **al consultar metadatos del archivo auxiliar como usuario sin permisos**, antes de examinar HEALTH. El script no ejecutó el comando y no intentó leer su contenido. Esto **no demuestra ningún fallo del temporizador ni de Restic**. El intento de consultar `is_file()` puede generar `PermissionError` cuando el directorio padre es privado.

**Corrección integrada directamente en main:** `22eb9a96` modifica solo la sonda `D1G_*_HELPER_EXISTS`: si el sistema deniega el `stat`, informa `PERMISSION_DENIED` sin escalada de privilegios, sin inferir `NO` ni detener la clasificación del servicio HEALTH. `D1G_RESULT=0` tras esto solo significará que se completó la **clasificación parcial permitida**, nunca que se accedió al wrapper, al backup ni al repositorio. La comprobación corregida todavía está pendiente de repetir.

```bash
cd ~/vencira-main-check-20261108
git fetch origin main
git merge --ff-only FETCH_HEAD
python3 scripts/d1g_o5_exec_target_readonly.py
echo "D1G_SHELL_RESULT=$?"
```

Conservar las restricciones `MFA_RELEASE_AUTHORIZED=NO` y `NO_DEPLOY_NO_LIVE_MIGRATION=1`. No utilizar `sudo` para intentar abrir el contenido de wrappers, certificados o archivos de entorno como parte de este preflight.

## BL. D1-G segundo ensayo de clasificación O5 PASS — 09/11/2026

El operador reejecutó el script corregido (a partir de `22eb9a96`) y aportó:
```text
D1G_BACKUP_EXEC_CLASS=PROJECT_WRAPPER
D1G_BACKUP_ARGS_PRESENT=NO
D1G_BACKUP_EXEC_PATH_ABSOLUTE=YES
D1G_BACKUP_HELPER_TARGET=DETECTED
D1G_BACKUP_HELPER_EXISTS=PERMISSION_DENIED
D1G_BACKUP_HELPER_EXTENSION=SHELL
D1G_HEALTH_EXEC_CLASS=PROJECT_WRAPPER
D1G_HEALTH_ARGS_PRESENT=NO
D1G_HEALTH_EXEC_PATH_ABSOLUTE=YES
D1G_HEALTH_HELPER_TARGET=DETECTED
D1G_HEALTH_HELPER_EXISTS=PERMISSION_DENIED
D1G_HEALTH_HELPER_EXTENSION=SHELL
D1G_SNAPSHOT_VERIFIED=NO
D1G_RESTORE_VERIFIED=NO
D1G_RESULT=0
D1G_SHELL_RESULT=0
```

**D1-G PASS en alcance de clasificación:** los dos servicios usan un wrapper shell del proyecto, con ruta absoluta, sin argumentos directos. El usuario de Termius no puede comprobar metadatos de su archivo porque el acceso al directorio está denegado. Esto es una limitación correcta de permisos, no prueba de error de las copias y no autoriza saltar permisos.

**Decisión de cierre:** no repetir diagnósticos de nombres, unidades o heurísticas de scripts. La evidencia previa D1-E muestra temporizadores `active/enabled`, última activación registrada y `Result=success, ExecMainStatus=0` de los servicios. Sigue faltando acreditar que existe un snapshot reciente íntegro y poder restaurarlo de forma segura. Para completar D1, un procedimiento aprobado por el operador debe consultar Restic con los permisos del servicio sin imprimir credenciales/configuración/PII y restaurar solo en un destino efímero, aislado de DEV. Si no hay interfaz de verificación que no exponga secretos, detener D1 backup gate, no inventar un PASS.

**Pendientes en paralelo:** grafo/migraciones `reminders.0019–0027` en PG17 temporal y rollback, I8-R Android/HTTPS frente a desconexiones y entrada funcional de APK; ninguna actividad cambia `MFA_RELEASE_AUTHORIZED=NO` ni `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## BM. D1-I — ensayo agrupado de migraciones y rollback PostgreSQL17 sintético (09/11/2026)

Para progresar hacia DEV sin esperar al acceso protegido del servicio O5 se ha integrado en `main` el script `scripts/main_d1i_pg17_synthetic_migrations_rollback.sh` (commit `5d3f85f6`). Crea PostgreSQL17 efímero con datos sintéticos en red Docker `--internal`, construye imagen Django candidata temporal y recorre `reminders.0018 → 0027 → 0018 → 0027`, comprobando el registro SQL de las nueve migraciones. Antes de la subida genera un dump de la base sintética en el contenedor temporal y posteriormente lo restaura con `pg_restore` a **otra base temporal**. Dispone de `trap EXIT` y comprobación de identidad de los contenedores DEV. No reutiliza credenciales ni bases persistentes y no publica puertos. Protocolo en `docs/D1I_PG17_SYNTHETIC_MIGRATION_REHEARSAL_2026-11-09.md` (commit `1dc95708`).

**Estado:** código publicado en `main`, **pendiente de validación VPS**. No declarar PASS hasta `D1I_0019_0027_APPLIED=PASS`, `D1I_ROLLBACK_TO_0018=PASS`, `D1I_SYNTHETIC_DUMP_RESTORED=PASS`, `D1I_DEV_CONTAINERS_UNCHANGED=OK` y `D1I_RESULT=0`. Esta restauración es de un esquema `main` **sintético**, **NO** la copia real O5, de modo que incluso un PASS no cierra compatibilidad/DR sobre los datos reales del entorno DEV.

El resultado D1-G previo del operador queda `D1G_RESULT=0`, sin acceso a wrappers protegidos. Sigue pendiente verificar snapshot Restic y restauración de DEV sobre un clon antes de cualquier deployment; I8-R Android y APK nativa real también pendientes.

Se mantienen `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## BN. 09/11/2026 — D1-I migraciones PG17 sintéticas y rollback: PASS

El operador ejecutó `scripts/main_d1i_pg17_synthetic_migrations_rollback.sh`, con evidencia:

```text
D1I_CANDIDATE_IMAGE=PASS
D1I_PG17_INTERNAL_TMPFS_READY=PASS
D1I_MODEL_MIGRATION_PARITY=PASS
D1I_BASELINE_0018=PASS
D1I_SYNTHETIC_BASELINE_DUMP=PASS
D1I_0019_0027_PLAN=PASS
D1I_0019_0027_APPLIED=PASS
D1I_ROLLBACK_TO_0018=PASS
D1I_SYNTHETIC_DUMP_RESTORED=PASS
D1I_0019_0027_REAPPLY=PASS
D1I_SCHEMA_ONLY_GATE=PASS
D1I_DEV_CONTAINERS_UNCHANGED=OK
D1I_O5_BACKUP_RESTORED=NO
D1I_LIVE_MIGRATIONS_EXECUTED=NO
D1I_DEPLOY_EXECUTED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
D1I_RESULT=0
```

**Cierre D1-I PASS en su alcance:** el backend actual genera imagen de laboratorio; paridad modelo/migración, planificación, subida `reminders.0018 → 0027`, rollback `0027 → 0018`, restauración del dump `0018` **sintético** a otra base PG17 efímera y nueva subida a `0027` son satisfactorios. Se preservaron los contenedores DEV; el test no desplegó ni migró la base persistente.

**Riesgo aún sin cerrar:** el dump restaurado no provenía de O5 ni del estado histórico de DEV. Falta confirmar snapshot Restic auténtico y restaurarlo sin sobrescritura en un destino aislado; solo después ensayar la migración sobre esa copia y verificar integridad de datos/rollback antes de considerar despliegue web en DEV. Los flags `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1` siguen vigentes. La APK funcional nativa e I8-R siguen pendientes.

## BO. D1-J: inspección protegida del contrato de copias O5 — preparada (09/11/2026)

Después de **D1-I PASS** (subida y rollback `reminders.0018↔0027`, restauración sintética y DEV intacto) queda como principal puerta del despliegue web la restauración de **un snapshot Restic real**. D1-G demostró que `vencira-o5-backup.service` y `vencira-o5-health.service` utilizan scripts Shell de proyecto bajo permisos protegidos; buscar nuevos nombres no aporta información.

Se ha integrado `scripts/d1j_o5_privileged_contract_readonly.py` (commit `bbf4c62a`) para **leer, sin ejecutar**, solo los dos unit fragments y los wrappers directos de `ExecStart` con privilegios del operador. Emite únicamente clasificaciones booleanas del texto (presencia de Restic/Rclone/pg_dump/restore, etc.) y nunca salida de los scripts, argumentos, rutas ni claves. Rechaza contratos inesperados en vez de ejecutarlos. Procedimiento `docs/D1J_O5_PROTECTED_CONTRACT_2026-11-09.md` (commit `b3086fce`).

**Todavía sin ejecutar en VPS**: resultado y contrato O5 no verificados. El clasificador `D1J_RESULT=0` confirmará únicamente que los wrappers han podido leerse y clasificarse estáticamente; **no** confirma backup reciente ni restorable. Una vez revisado el contrato real, preparar gate Restic y restauración a destino *temporal y aislado*, seguido de migración de esa copia. Prohibido ejecutar automáticamente scripts privilegiados, alterar permisos o escribir en bases persistentes. `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## BP. D1-J lectura O5 PASS con incertidumbre operativa sustancial (09/11/2026)

El operador ejecutó el clasificador privilegiado D1-J y obtuvo `D1J_RESULT=0`. Ambos wrappers están presentes, son legibles y no vacíos, pero **NO** hay coincidencias directas en ninguno para `restic`, `rclone`, `pg_dump`, `pg_restore`, `docker`, `restic snapshots/check/backup/restore/forget/prune`, ni aprovisionamiento de variables de entorno. Esta revisión de texto no prueba que no realicen backups; pueden delegar en otras herramientas, invocar un auxiliar sin esas palabras o constituir stubs. Pero systemd `Result=success` por sí solo **no acredita backup**.

Se publica `scripts/d1k_o5_wrapper_structure_readonly.py` (commit `cf615eeb`) para una **última** clasificación estructural de ambos wrappers protegidos, con una lectura limitada y sin ejecución de comandos ni salida de archivos o argumentos. Identifica señales genéricas de delegación, estructuras Shell y declaraciones de salida exitosa; sus heurísticas no demuestran la efectividad del backup. Se pide **solo**:
```bash
cd ~/vencira-main-check-20261108
git fetch origin main
git merge --ff-only FETCH_HEAD
sudo python3 scripts/d1k_o5_wrapper_structure_readonly.py
echo "D1K_SHELL_RESULT=$?"
```
El informe imprime marcadores fijos `D1K_*`, sin valores ni rutas privadas. `D1K_RESULT=0` es **clasificación satisfactoria**, no snapshot PASS. Si no se identifica claramente el mecanismo, detener la cadena de clasificación y recurrir a la evidencia operativa de un snapshot en repositorio Restic mediante procedimiento revisado, nunca dar por cubierta O5 solo por los metadatos systemd.

Persisten D1-I **PASS sintético**, D1-J **PASS clasificación** y **NO** evidencia de recuperación del PostgreSQL histórico DEV. Por tanto no desplegar ni aplicar migraciones persistentes. `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## BQ. D1-K estructura O5 analizada: sin evidencia de snapshot (09/11/2026)

El operador ejecutó `scripts/d1k_o5_wrapper_structure_readonly.py` y aportó `D1K_RESULT=0`. La revisión de solo lectura comunicó:

```text
D1K_BACKUP_SOURCE_NONEMPTY_LINES=36
D1K_BACKUP_SOURCE_SIZE_CLASS=MEDIUM
D1K_BACKUP_SHEBANG_PRESENT=YES
D1K_BACKUP_SHELL_CONTROL_FLOW=NO
D1K_BACKUP_EXIT_SUCCESS_STATEMENT_PRESENT=NO
D1K_BACKUP_DELEGATION_INDICATOR=NO
D1K_BACKUP_NETWORK_TRANSFER_KEYWORD=NO
D1K_BACKUP_BACKUP_TOOL_KEYWORD=NO
D1K_BACKUP_ACTUAL_BACKUP_ACTIVITY=NOT_VERIFIED
D1K_HEALTH_SOURCE_NONEMPTY_LINES=27
D1K_HEALTH_SOURCE_SIZE_CLASS=MEDIUM
D1K_HEALTH_SHEBANG_PRESENT=YES
D1K_HEALTH_SHELL_CONTROL_FLOW=NO
D1K_HEALTH_EXIT_SUCCESS_STATEMENT_PRESENT=NO
D1K_HEALTH_DELEGATION_INDICATOR=NO
D1K_HEALTH_NETWORK_TRANSFER_KEYWORD=NO
D1K_HEALTH_BACKUP_TOOL_KEYWORD=NO
D1K_HEALTH_ACTUAL_BACKUP_ACTIVITY=NOT_VERIFIED
D1K_SNAPSHOT_VERIFIED=NO
D1K_RESTORE_VERIFIED=NO
D1K_RESULT=0
```

**Interpretación y decisión:** D1-K completó su **clasificación estática**, no la verificación del backup. La ausencia de coincidencias con expresiones regulares no demuestra inactividad de los wrappers: podrían emplear variables, expansiones, comandos indirectos o dependencias externas. No hay prueba de snapshot Restic existente, reciente, íntegro o restaurable. Aunque D1-E estableció que los timers están activos y los servicios reportan último resultado `success`, no debe elevarse ese hecho a una certificación de recuperación.

**Se detiene la cadena D1-B…D1-K de inventarios de nombres/keywords.** El siguiente gate operacional solo podrá cerrar con evidencia tangible de un snapshot O5 identificado en el repositorio configurado y una restauración completa a un directorio nuevo, vacío y **aislado**, sin publicar datos personales ni secretos y sin escribir sobre DEV. No inferir comandos ni ubicaciones de Restic a partir de heurísticas; el procedimiento debe ser revisado a partir de la configuración efectiva bajo permisos autorizados, sin enviar su contenido sensible al chat. Después, sobre un clon PG17 temporal de ese backup, se reensayarán migraciones `0019–0027`, coherencia y rollback. No autorizar deployment sin estos cierres.

**Otros avances:** D1-I PG17 sintético/rollback PASS. Integración funcional y visual de Android sigue pendiente. Sin deploy, sin migraciones persistentes, `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## BR. 09/11/2026 — D1-K cierre y B2 Flutter viewport smoke aislado

**D1-K ejecutado por operador:** `D1K_RESULT=0`, wrappers Shell O5 con 36 y 27 líneas no vacías respectivamente, shebang en ambos, sin coincidencias de delegación, Restic/Rclone/pg_dump, transferencia de red ni salida de éxito inmediata. `D1K_SNAPSHOT_VERIFIED=NO`, `D1K_RESTORE_VERIFIED=NO`. D1-K **solo clasifica texto**: no autoriza concluir que no hay backup; el siguiente paso O5 es obtener **evidencia real de snapshot y restauración aislada** mediante el procedimiento custodiado, no más regex.

**B2 avance paralelo integrado directamente a main:**
- `clients/flutter/test/b2_dashboard_viewport_smoke_test.dart` (commit `429dbb88`): arranque de `VenciraApp(api: fake)` con `VenciraApi` simulado **sin HTTP ni credenciales**, workspaces vacíos, viewport físico de 320 y 390 puntos lógicos, verifica que el dashboard se construye y no registra excepción de widget; no prueba las otras diez pantallas ni una APK real.
- `scripts/main_b2_dashboard_viewport_smoke.sh` (commit `42d3b6e2`): contenedor de Flutter SDK independiente; copia el código desde volumen solo lectura a directorio temporal, ejecuta `flutter pub get`, `flutter analyze` del test y `flutter test`, sin crear ni tocar contenedores DEV. El contenedor Flutter podrá acceder a los repositorios públicos para instalar paquetes; el test simulado no se conecta a DEV.

**Pendiente de ejecutar en VPS** (no proclamar PASS hasta ver resultados):
```bash
cd ~/vencira-main-check-20261108
git fetch origin main
git merge --ff-only FETCH_HEAD
bash scripts/main_b2_dashboard_viewport_smoke.sh
echo "B2_SHELL_RESULT=$?"
```
Requeridos: `B2_DASHBOARD_VIEWPORTS_320_390=PASS`, `B2_UI_SMOKE_RESULT=0`, `B2_SHELL_RESULT=0`. Si hay overflow/fallo, corregir pantalla y verificar de nuevo. Esto solo prueba la UI inicial sin workspace real; otras pantallas y autenticación nativa permanecen sin probar.

**No autorizaciones:** `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`. No ejecutar Restic manualmente sin destino aislado y contrato real verificado.

## BS. B2 dashboard Flutter 320/390 smoke PASS; error-state extension pending (09/11/2026)

El operador ejecutó `scripts/main_b2_dashboard_viewport_smoke.sh` sobre el test con API simulada, aportando:
```text
No issues found! (ran in 14.2s)
00:00 +0: B2 dashboard empty state renders at 320px
00:01 +1: B2 dashboard empty state renders at 390px
00:01 +2: All tests passed!
B2_DASHBOARD_VIEWPORTS_320_390=PASS
B2_DEV_CONTAINERS_TOUCHED=NO
B2_VISUAL_PHONE_REVIEW=NOT_RUN
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
B2_UI_SMOKE_RESULT=0
```

**B2 subgate aprobado:** dos renderizados iniciales del dashboard en 320 y 390 píxeles con `VenciraApi` falsa y `flutter analyze` sin incidencias. No prueba acceso Android real, sesión nativa operativa, carga de workspaces ni resto de pantallas, y tampoco acredita revisión visual física.

Para elevar la utilidad del mismo gate sin nuevos laboratorios, se añadió en `main` la prueba de API no disponible (commit `1a9f3ec8`): dos casos adicionales, 320 y 390 píxeles, en los que `fetchWorkspaces` lanza `VenciraApiException` deliberadamente. Verifica que el dashboard permanece montado sin excepciones de widget. El backend sigue simulado, sin solicitudes HTTP; **todavía pendiente la ejecución VPS de la ampliación**. Reutilizar el mismo comando `bash scripts/main_b2_dashboard_viewport_smoke.sh`. Se esperan cuatro tests PASS; no elevar hasta comprobarlo.

O5 continúa con temporizadores activos y resultados systemd correctos, pero snapshot real y restore no verificados. D1-I migraciones sintéticas PASS. Despliegue DEV bloqueado, `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## BT. B2 Flutter 4/4 PASS y ampliación a workspace/vencimiento sintético (09/11/2026)

El operador reejecutó el gate del dashboard tras añadir el estado de API no disponible. Evidencia:

```text
00:01 +4: All tests passed!
B2_DASHBOARD_VIEWPORTS_320_390=PASS
B2_DEV_CONTAINERS_TOUCHED=NO
B2_VISUAL_PHONE_REVIEW=NOT_RUN
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
B2_UI_SMOKE_RESULT=0
```

**Aceptado B2-UI-EMPTY/OFFLINE=PASS 4/4** para 320/390 px con API simulada; no es una prueba nativa Android ni con API operativa.

Para aumentar cobertura de flujo funcional real de **widget**, se incorporó `_SyntheticWorkspaceApi` a `clients/flutter/test/b2_dashboard_viewport_smoke_test.dart` (commits `13e67d54` y `67095299`): suministra un workspace de pruebas y un vencimiento no personal, comprueba que aparece el título `Caso sintético` en anchuras 320/390 px y que no hay excepción Flutter. El cliente implementa `VenciraApi` simulado sin red; métodos no cubiertos fallan cerrados. **Pendiente ejecución VPS de esta ampliación**: se esperan 6/6 tests. Se reutiliza `scripts/main_b2_dashboard_viewport_smoke.sh`; el marcador final `B2_DASHBOARD_VIEWPORTS_320_390=PASS` es de cobertura de viewport y no equivale a una revisión visual física.

```bash
cd ~/vencira-main-check-20261108
git fetch origin main
git merge --ff-only FETCH_HEAD
bash scripts/main_b2_dashboard_viewport_smoke.sh
echo "B2_SHELL_RESULT=$?"
```

El cambio **no habilita** autenticación nativa ni las rutas de laboratorio en producción, no toca DEV. D1-I sigue PASS sintético; restauración de un snapshot O5 real sigue pendiente y bloquea el despliegue web de DEV. No repetir investigaciones de nombres/keywords O5; próxima intervención O5 debe demostrar snapshot/recovery.

## BU. B2 test de workspace sintético: 4 PASS + 2 FAIL; corrección de visibilidad de ListView (09/11/2026)

El operador ejecutó la ampliación de `clients/flutter/test/b2_dashboard_viewport_smoke_test.dart` sobre `main`: `flutter analyze` sin incidencias; los cuatro tests existentes (vacío y API caída, 320/390 px) siguen pasando, pero los dos nuevos de workspace/vencimiento fallaron por `find.text('Caso sintético')` con `Found 0 widgets`. **El subgate ampliado no pasa; no atribuir PASS a los seis tests.**

Inspección de fuente: el dashboard usa `ListView(children: ..._workspaceContent(...))`, donde la tarjeta de vencimiento aparece **después de** los filtros y controles. En un viewport de 320/390 px puede quedar fuera del área construida por el scroll perezoso. El test comprobaba el texto **sin desplazarse**, por lo que el fallo no prueba por sí solo una avería de la API o de la UI.

**Cambio de test únicamente**, commit `b97bfa25`: antes del `expect`, `tester.scrollUntilVisible(..., 220, maxScrolls:25)` sobre el `Scrollable` descendiente del dashboard. No se modifican modelo de autenticación, dashboard ni backend; no se inventa un PASS.

Ejecutar solo el mismo gate B2:
```bash
cd ~/vencira-main-check-20261108
git fetch origin main
git merge --ff-only FETCH_HEAD
bash scripts/main_b2_dashboard_viewport_smoke.sh
echo "B2_SHELL_RESULT=$?"
```
Esperar `00:.. +6: All tests passed!`, `B2_UI_SMOKE_RESULT=0` y `B2_SHELL_RESULT=0`. Si falla, investigar el resultado real de `fetchFilteredRenewals` o estado de la lista; no repetir cambios en UI sin evidencia. El aviso de dependencias Flutter actualizables no fue la causa del TestFailure.

Permanece `MFA_RELEASE_AUTHORIZED=NO` y `NO_DEPLOY_NO_LIVE_MIGRATION=1`; O5 restore real aún pendiente.

## BV. B2: segunda falla de fixture; causa identificada en contrato Dart (09/11/2026)

El operador informó `flutter analyze` sin incidencias, cuatro pruebas de vacío/API-no-disponible PASS, y dos pruebas de workspace/vencimiento todavía FAIL. El nuevo error es `StateError: Bad state: No element` desde `tester.scrollUntilVisible`: el vencimiento no llega a encontrarse después de desplazarse, por lo que la primera hipótesis de visibilidad **no explicaba el fallo íntegro**.

**Causa localizada en el test:** `_SyntheticWorkspaceApi implements VenciraApi` no hereda las implementaciones de métodos de la clase abstracta. El dashboard llama a `fetchFilteredRenewals()`, cuya implementación por defecto en `VenciraApi` delega en `fetchRenewals()`. Con `implements`, la llamada entra en el `noSuchMethod` del fake y lanza `UnsupportedError`; el dashboard lo absorbe mostrando el estado de error, sin la tarjeta. El flujo del widget, por tanto, **no estaba siendo ejercitado correctamente**.

**Corrección directa en main:** `6209e35a` cambia `_SyntheticWorkspaceApi` a `extends VenciraApi` para heredar la delegación de filtros y añade `renewalRequests` y una aserción `greaterThan(0)` antes de buscar el texto. Mantiene el desplazamiento sobre `ListView` para la tarjeta fuera de viewport. No modifica la UI, backend ni ningún contrato de autenticación.

**Pendiente de repetir solo B2**:
```bash
cd ~/vencira-main-check-20261108
git fetch origin main
git merge --ff-only FETCH_HEAD
bash scripts/main_b2_dashboard_viewport_smoke.sh
echo "B2_SHELL_RESULT=$?"
```
Requiere `6/6 All tests passed!` y `B2_UI_SMOKE_RESULT=0` antes de certificar la ampliación. Continúan `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`, O5 real sin restaurar.

## BW. 09/11/2026 — B2 dashboard sintético 6/6 PASS y navegación a detalle preparada

El operador validó el script B2, con `No issues found!`, seis pruebas Flutter correctas y `B2_UI_SMOKE_RESULT=0`. Cuatro escenarios de dashboard vacío/API simulada no disponible (320/390 px) y dos de workspace con vencimiento sintético en 320/390 px. `B2_DEV_CONTAINERS_TOUCHED=NO`, `B2_VISUAL_PHONE_REVIEW=NOT_RUN`; no se habilitaron accesos nativos ni rutas experimentales.

**Cierre B2 dashboard base:** PASS 6/6; el fallo de `implements VenciraApi` quedó resuelto con `extends VenciraApi`.

**Siguiente prueba integrada directamente en main**, commit `3f3ce252`: se amplía el mismo fichero `clients/flutter/test/b2_dashboard_viewport_smoke_test.dart` para comprobar navegación `dashboard → ficha detalle → dashboard` con la misma API sintética. El fixture implementa `fetchRenewalDetail` sin HTTP y la nueva prueba pulsa el vencimiento simulado, comprueba ficha y referencia, vuelve atrás y verifica que dashboard se mantiene. **Pendiente de ejecutar en VPS**; no atribuir PASS todavía. Reutilizar `bash scripts/main_b2_dashboard_viewport_smoke.sh`; nuevo objetivo 7/7 tests. Un fallo debe inspeccionarse sin alterar la interfaz ni el backend de forma especulativa.

**Pendientes fuera del test:** restauración O5 real aislada, migraciones sobre copia histórica de DEV y integración nativa Android. `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`; prohibido deploy/migración persistente.

## BX. B2 navegación sintética 6/7: fallo al volver por API de test Cupertino (09/11/2026)

El operador volvió a ejecutar el smoke Flutter; `flutter analyze` no encontró errores, los seis escenarios ya establecidos volvieron a pasar y el séptimo completó el acceso al detalle de vencimiento (tanto el finder de la pantalla como el de la referencia superaron sus aserciones). El fallo registrado fue:
```text
00:03 +6 -1: B2 synthetic renewal opens details and returns [E]
Expected: exactly one CupertinoNavigationBarBackButton
Actual: Found 0 widgets
# WidgetTester.pageBack (.../widget_tester.dart:1177)
```

**Diagnóstico:** `tester.pageBack()` exige un botón de retroceso `CupertinoNavigationBarBackButton`, pero el cliente usa navegación Material. El error no es evidencia de avería de datos ni de navegación de entrada. La salida de Flutter sigue siendo **6/7, NO PASS**.

**Corrección en main `c24b2c55`:** reemplazar la llamada de test a `pageBack()` por `tester.state<NavigatorState>(find.byType(Navigator).first).pop()`; después del `pumpAndSettle` exigir desaparición de la ruta detalle, presencia del dashboard y una segunda solicitud a la API sintética de vencimientos como prueba de recarga. No se modifican interfaces de producción, backend ni seguridad. Aún está **pendiente la validación en VPS**.

```bash
cd ~/vencira-main-check-20261108
git fetch origin main
git merge --ff-only FETCH_HEAD
bash scripts/main_b2_dashboard_viewport_smoke.sh
echo "B2_SHELL_RESULT=$?"
```

Cierre requerido: `+7: All tests passed!`, `B2_UI_SMOKE_RESULT=0`, `B2_SHELL_RESULT=0`. O5 real aún no restaurado; cualquier despliegue o migración persistente continúa prohibido.

## BY. B2 Flutter dashboard + ficha: cierre 7/7 PASS (09/11/2026)

El operador reejecutó `scripts/main_b2_dashboard_viewport_smoke.sh` tras corregir el retorno de la navegación Material y aportó:

```text
00:02 +7: All tests passed!
B2_DASHBOARD_VIEWPORTS_320_390=PASS
B2_DEV_CONTAINERS_TOUCHED=NO
B2_VISUAL_PHONE_REVIEW=NOT_RUN
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
B2_UI_SMOKE_RESULT=0
```

**Cierre B2-UI-SMOKE=PASS para alcance testado**: dashboard vacío, error de backend simulado, espacio de trabajo y vencimiento sintéticos en 320/390 px, navegación a ficha de detalle en 390 px, regreso al dashboard y recarga de vencimientos mediante una API de pruebas sin red. El `flutter analyze` de la ejecución anterior había resultado sin incidencias; el extracto más reciente confirma los siete tests. No se tocó DEV.

**Límite de certificación:** la navegación solo se probó con datos sintéticos, no con API real, sesión nativa ni Android físico; `B2_VISUAL_PHONE_REVIEW=NOT_RUN`. Este subgate se considera cerrado; no añadir tests menores sin nuevo defecto observado.

**Prioridad siguiente de lanzamiento:** obtener evidencia de un snapshot O5 real y restaurarlo en destino aislado para comprobar integridad y compatibilidad de migraciones PG17 con datos históricos; luego gate regresión y despliegue DEV controlado si se autoriza. En paralelo sigue pendiente APK nativa real. No inferir eficacia del backup de `systemd Result=success`; D1J/D1K fueron solo clasificaciones estáticas. `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## BZ. D1-L: verificación real de snapshots y metadatos Restic preparada (09/11/2026)

Tras B2 **7/7 PASS** y D1-I **PASS sintético**, la principal puerta de despliegue web DEV sigue siendo la prueba de restauración desde la copia O5 auténtica. Los clasificadores D1-J/D1-K no identificaron llamadas directas Restic/Rclone en wrappers protegidos, lo que **no** demuestra ni funcionamiento ni fallo de backup.

Se ha integrado directamente en `main` el gate `scripts/main_d1l_o5_restic_metadata_gate.py` (commit `204fe233`) y su procedimiento de ejecución custodiado `docs/D1L_O5_REAL_RESTIC_GATE_2026-11-09.md` (commit `4585a04c`). A diferencia de D1-J/K, D1-L **consulta un repositorio Restic real** usando el entorno autenticado preexistente del operador: `restic --no-lock snapshots --json`, cuenta snapshots y calcula frescura; `restic --no-lock check` revisa los metadatos del repositorio. Aborta si el operador no confirma explícitamente el alcance DEV, falta `RESTIC_REPOSITORY` o un proveedor de contraseña basado en fichero/comando. No ejecuta backup, restauración, borrado, cambios de locks, migraciones ni despliegue. No vuelca stdout/stderr de Restic, identificadores, paths o secretos.

**Estado D1-L: publicado, todavía NO ejecutado ni validado en VPS.** Necesita entorno Restic real cuya ubicación/custodia **no está incluida en el checkout `main`**; no inventar variables ni importar scripts privilegiados no auditados. `D1L_RESULT=0` + `D1L_RESTIC_METADATA_CHECK=PASS` prueban solo disponibilidad de snapshots y consistencia de metadatos, **NO** completitud del payload, copia de PostgreSQL real ni restaurabilidad. Exigir `D1L_SNAPSHOT_FRESHNESS_48H=YES` como puerta independiente. La restauración real a destino efímero y ensayo de migraciones sobre copia histórica corresponden al bloque posterior D1-M, no autorizado aún.

`MFA_RELEASE_AUTHORIZED=NO`; `NO_DEPLOY_NO_LIVE_MIGRATION=1`; `D1_RELEASE_AUTHORIZED=NO`.

## CA. 09/11/2026 — O5 delegado REAL IDENTIFICADO; snapshots aún pendientes

El operador inspeccionó localmente el `ExecStart` de `vencira-o5-backup.service`. El script real es un **wrapper de estado**, `/usr/local/libexec/vencira/o5_schedule_backup.sh`, que comprueba ejecución root, propiedad/permisos del directorio `/var/lib/vencira-o5` y un marcador de OAuth, y luego ejecuta explícitamente:

```bash
bash /usr/local/libexec/vencira/o5_backup_to_drive.sh
```

Solo si la ejecución delegada termina sin error (por `set -Eeuo pipefail`) avanza a `PHASE=MARCADOR_EXITO`, escribe de forma atómica `last-success.epoch`, borra `last-failure.epoch` y comunica `O5_BACKUP_DIARIO=OK`. La trampa `EXIT` registra fallo y código si se produce un error. **La ausencia de menciones Restic/Rclone en D1-J/D1-K es esperable en este wrapper**: ambas inspecciones cubrían solo el envoltorio, no el ejecutable delegado.

**Estado verificado:** delegación explícita, estructura de marca de estado, no ejecución de backup manual. **No verificado:** contenido del script delegado, repositorio Restic, credenciales OAuth efectivas, snapshots, integridad de datos ni restauración. No inferir de `systemd Result=success` o `last-success.epoch` que el respaldo contiene un dump PostgreSQL recuperable.

**Siguiente acción:** inspección local protegida y exclusivamente de lectura de `/usr/local/libexec/vencira/o5_backup_to_drive.sh` (no compartir contraseñas, tokens, claves, rutas privadas de datos ni contenido íntegro del script); identificar cómo adquiere la configuración Restic y comprobar snapshots reales con el mecanismo autorizado. No ejecutar el backup a mano, no editar unidades o permisos ni copiar secretos al repositorio público. `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## CB. O5: contrato Restic/Google Drive completo localizado; gate real D1-L listo (09/11/2026)

El operador consultó el script delegado protegido `/usr/local/libexec/vencira/o5_backup_to_drive.sh`. **Ya conocemos la ejecución real**, no solo el wrapper systemd:
- Solo root; `flock` evita duplicidad; carga `/etc/vencira-backup/config.env` bajo permisos root; comprueba proveedor de contraseña Restic y `rclone.conf` con permisos `600`.
- Restic se conecta a Google Drive mediante backend Rclone y directorio O5 PostgreSQL; confirma acceso mediante `restic snapshots --quiet`.
- Verifica contenedor `vencira_localcheck-db-1` saludable con etiqueta de proyecto correcta.
- Ejecuta `restic backup --tag vencira-postgresql --stdin-filename vencira-postgres.dump --stdin-from-command -- docker exec ... pg_dump -Fc`. El dump sin cifrar se envía por stdin y no se almacena como archivo temporal local.
- Ejecuta `restic check` y emite marcadores de éxito solo al terminar; el scheduler root actualiza marcas de control posteriormente.

**Todavía NO se ha validado acceso Restic en esta sesión ni se ha recuperado un dump**. La ausencia de variables RESTIC en shells interactivas es esperable: están cargadas desde `config.env` durante la ejecución protegida.

Se publica en `main` `scripts/main_d1l_o5_authenticated_readonly.sh` (commit `c0e888a4`), que comprueba los permisos y el repositorio O5 exactos, carga el `config.env` protegido y ejecuta **solo lectura** el gate Python D1-L. Este último ahora restringe los snapshots a la etiqueta `vencira-postgresql` y al archivo `vencira-postgres.dump` (commit `2b97e82d`). Instrucciones en `docs/D1L_O5_REAL_RESTIC_GATE_2026-11-09.md` (commit `86d306c0`).

**Pendiente ejecución VPS:** `sudo bash scripts/main_d1l_o5_authenticated_readonly.sh` desde checkout `main` actualizado. Requiere conteo positivo, frescura 48h YES, `restic check` PASS y `D1L_RESULT=0`; esto sigue siendo solo prueba de metadatos, no `--read-data`, ni recuperación integral. D1-M real necesita restaurar a un PostgreSQL17 separado y comprobar migraciones `0019–0027`. Las restricciones `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1` siguen activas.

## CC. D1-L O5 REAL PASS; D1-M PG17 restauración auténtica preparada (09/11/2026)

**Evidencia aportada por operador tras ejecutar D1-L con la configuración protegida original:**

```text
D1L_SECURE_CONFIG=PASS
D1L_O5_CONFIG_MATCH=PASS
D1L_CREDENTIAL_FILE_PERMISSIONS=PASS
D1L_POSTGRESQL_TAGGED_SNAPSHOT_COUNT=25
D1L_NEWEST_POSTGRESQL_SNAPSHOT_AGE_HOURS=19
D1L_SNAPSHOT_FRESHNESS_48H=YES
D1L_RESTIC_METADATA_CHECK=PASS
D1L_BACKUP_SCOPE=OPERATOR_CONFIRMED_NOT_INDEPENDENTLY_VERIFIED
D1L_SNAPSHOT_PAYLOAD_FULL_READ=NOT_RUN
D1L_RESTORE_VERIFIED=NO
D1L_RESULT=0
```

**D1-L PASS (metadatos reales, alcance limitado):** el repositorio PostgreSQL O5 es accesible y contiene **25 snapshots etiquetados**, el más reciente de **19 horas** al ejecutarse, y supera `restic check` de metadatos. Aún no acredita la lectura completa de datos ni su restauración.

**D1-M preparado en `main`:** `scripts/main_d1m_o5_real_restore_pg17_isolated.sh` (commit `07f1480e`) usa la configuración original root protegida, selecciona snapshot etiquetado `vencira-postgresql` reciente y canaliza `restic dump` hacia `pg_restore` en un contenedor `postgres:17-alpine` **sin red, puertos, mounts persistentes ni intervención sobre DEV**, PostgreSQL en `tmpfs` y limpieza al finalizar. Verifica la presencia de `reminders.0018` en el historial Django restaurado y no muestra datos personales ni dump descifrado. Procedimiento `docs/D1M_REAL_O5_PG17_RESTORE_2026-11-09.md` (commit `7e83de29`).

**D1-M PENDIENTE EJECUCIÓN VPS.** No convertir en PASS sin `D1M_RESTORE_REAL_O5_PG17=PASS`, `D1M_HISTORICAL_0018=PASS`, `D1M_DEV_CONTAINERS_UNCHANGED=OK`, `D1M_LAB_CONTAINER_REMOVED=YES` y `D1M_RESULT=0`. D1-M **NO** aplica migraciones sobre los datos restaurados; ese ensayo histórico se asigna a D1-N. Flags `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`, sin deployment ni migraciones DEV.

## CD. D1-M: restauración real de O5 sobre PostgreSQL17 aislado PASS (09/11/2026)

El operador ejecutó `scripts/main_d1m_o5_real_restore_pg17_isolated.sh` en el VPS y aportó:

```text
D1M_CONFIG_MATCH=PASS
D1M_DEV_IDENTITY=PASS
D1M_RECENT_POSTGRESQL_SNAPSHOT=PASS
D1M_PG17_NETWORK_ISOLATED=PASS
D1M_PG17_TMPFS_READY=PASS
D1M_RESTORE_REAL_O5_PG17=PASS
D1M_HISTORICAL_0018=PASS
D1M_BACKUP_PAYLOAD_PG_RESTORE_VERIFIED=YES
D1M_MIGRATIONS_0019_0027_ON_REAL_DATA=NOT_RUN
D1M_DEV_CONTAINERS_UNCHANGED=OK
D1M_LAB_CONTAINER_REMOVED=YES
D1M_LIVE_RESTORE_EXECUTED=NO
D1M_LIVE_MIGRATIONS_EXECUTED=NO
D1M_DEPLOY_EXECUTED=NO
D1M_RESULT=0
```

**D1-M PASS:** el backup Restic O5 real se ha descifrado por streaming y restaurado correctamente con `pg_restore` en un PostgreSQL 17 `tmpfs` sin red; se confirmó el historial `reminders.0018` y la eliminación del laboratorio, sin alterar los tres contenedores persistentes DEV. Es una prueba de recuperación PostgreSQL real, no solo metadatos.

**Siguiente gate:** D1-N migraciones `0019–0027` sobre **una segunda copia aislada de este backup real**; observar conservación de datos clave y viabilidad de rollback de esquema. No elevar a autorización de deployment hasta validación y regresión. `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## CE. D1-N: ensayo de migración real sobre copia O5 restaurada, preparado (09/11/2026)

**Antecedentes comprobados**: D1-L **25 snapshots PostgreSQL**, último **19 h**, `restic check` de metadatos **PASS**. D1-M **PASS** con `D1M_RESTORE_REAL_O5_PG17=PASS`, `D1M_HISTORICAL_0018=PASS`, `D1M_DEV_CONTAINERS_UNCHANGED=OK`, `D1M_LAB_CONTAINER_REMOVED=YES`, `D1M_RESULT=0`. Por primera vez existe evidencia de restauración auténtica de O5 en PG17 temporal, no solo ensayos sintéticos.

**D1-N integrado directamente en `main`**, `scripts/main_d1n_o5_historical_migrations_pg17.sh` (commit `44f35f25`), documentado en `docs/D1N_O5_HISTORICAL_PG17_MIGRATIONS_2026-11-09.md` (commit `f4c1307a`). Realiza una **nueva** recuperación de snapshot O5 real con Restic a PostgreSQL17 `tmpfs` en red Docker `--internal` nueva y sin puertos ni mounts persistentes. Construye imagen Django desechable del checkout `main`, prueba `makemigrations --check`, planifica y aplica `reminders.0019–0027` **únicamente en el clon**, compara conteos de usuarios/espacios/vencimientos antes y después, ensaya vuelta a `0018` y comprueba conservación de esos conteos tras el rollback. Limita memoria y limpia contenedor, red, imagen y credenciales sintéticas de laboratorio. No imprime filas de usuarios.

**D1-N publicado, aún NO ejecutado en VPS.** Criterio de cierre: `D1N_MIGRATIONS_0019_0027=PASS`, `D1N_ROLLBACK_TO_0018=PASS`, `D1N_CORE_COUNTS_UP=PASS`, `D1N_CORE_COUNTS_DOWN=PASS`, `D1N_DEV_CONTAINERS_UNCHANGED=OK`, `D1N_RESULT=0`. Sin esos resultados no atribuir compatibilidad histórica. La igualdad de tres contadores no prueba toda la semántica de datos. Aun con PASS persisten regresión integral web/HTTPS y autorización expresa para despliegue DEV; Android nativo sigue sin integrarse en entrada normal. `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## CF. 09/11/2026 — D1-N PASS sobre datos O5 reales y traspaso a nuevo chat

**Resultado local confirmado por el operador:** `D1N_RESULT=0`, `D1N_RESTORE_REAL_O5_PG17=PASS`, `D1N_HISTORICAL_0018=PASS`, `D1N_MODEL_MIGRATION_PARITY=PASS`, `D1N_MIGRATION_PLAN=PASS`, `D1N_MIGRATIONS_0019_0027=PASS`, `D1N_CORE_COUNTS_UP=PASS`, `D1N_ROLLBACK_TO_0018=PASS`, `D1N_CORE_COUNTS_DOWN=PASS`, `D1N_HISTORICAL_MIGRATION_GATE=PASS`, `D1N_DEV_CONTAINERS_UNCHANGED=OK`, `D1N_LAB_CONTAINER_REMOVED=YES`, `D1N_REAL_DATA_CONTENT_PRINTED=NO`. Restauración de un **segundo backup O5 auténtico** en PG17 `tmpfs` aislado, migraciones sobre esa copia, vuelta a `0018` y preservación de conteos base; no se migró la BD persistente.

**D1-N CERRADO PASS para alcance histórico**. El mensaje del operador no incluye `D1N_SHELL_RESULT` ni `D1N_EPHEMERAL_NETWORK_REMOVED`: no inventar esos valores. La igualdad de conteos de 3 tablas no garantiza invariancia de todas las filas/campos. **No equivale a autorizar un despliegue.**

Documento de traspaso completo: **`docs/HANDOFF_2026-11-09_D1N_PASS_NEXT_D1O.md`**, publicado en `main` (commit `bf892ce7`). El protocolo D1-N también contiene el resultado real (commit `18b25dd4`). Conservar este documento maestro como historial; el nuevo chat debe cargar el handoff y este último apartado antes de continuar.

**Siguiente bloque recomendado: D1-O, regresión integral Django+web+seguridad**, seguido de plan de rollback y autorización expresa para una eventual actualización web DEV. B2 UI 7/7 PASS, D1-I sintético PASS, D1-L snapshot/metadatos PASS y D1-M recuperación PG17 real PASS. Login Android nativo de APK operativa pendiente. Prohibido deploy, migración persistente o activación MFA nativa:

```text
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
D1_RELEASE_AUTHORIZED=NO
D1_DEPLOY_EXECUTED=NO
D1_LIVE_MIGRATIONS_EXECUTED=NO
```


## CG. 09/11/2026 — D1-O publicado directamente en main; validación pendiente

Se incorporó el runner `scripts/main_d1o_candidate_integral_gate.sh` (commit `d9565c14`, correcciones `9a363898`, `c57578f8`) y el módulo `backend/reminders/test_d1o_release_contract.py` (commit `c914f832`). Documento de procedimiento y aceptación: `docs/D1O_CANDIDATE_INTEGRAL_GATE_2026-11-09.md` (commit `6041d23d`).

El ejecutor, **todavía sin evidencia de ejecución**, usa PostgreSQL 17 sintético en `tmpfs` y red interna, imagen Django de `main`, verificaciones de migraciones, Django test client para sesión/CSRF/fail-closed y suite `reminders`; prueba Flutter analyze/test/build web en copia temporal. Exige identidad y conservación de contenedores persistentes DEV; limpia recursos de laboratorio al salir. No repite el ensayo histórico D1-N ni ejecuta migraciones DEV.

**Estado D1-O: RUNNER PUBLICADO / GATE PENDIENTE.** No afirmar PASS sin `D1O_RESULT=0`, `D1O_SHELL_RESULT=0` y marcadores detallados. Tampoco equivale a un ensayo HTTP TLS real de Caddy o validación de adjuntos binarios. Próxima intervención del operador: ejecutar una única vez el procedimiento D1-O en Termius. No introducir ramas ni modificar contenedores DEV.

```text
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
D1_RELEASE_AUTHORIZED=NO
D1_DEPLOY_EXECUTED=NO
D1_LIVE_MIGRATIONS_EXECUTED=NO
```


## CH. 10/11/2026 — D1-O regresión integral PASS (evidencia Termius)

El operador comunicó `D1O_DEV_IDENTITY=PASS`, `D1O_INTERNAL_NETWORK=PASS`, `D1O_PG17_SYNTHETIC_TMPFS=PASS`, `D1O_CANDIDATE_IMAGE_BUILD=PASS`, `D1O_DJANGO_DEPLOY_CHECK=PASS`, `D1O_MODEL_PARITY=PASS`, `D1O_SYNTHETIC_MIGRATIONS=PASS`, `D1O_SECURITY_HTTP_CONTRACT=PASS`, `D1O_DJANGO_REMINDERS_SUITE=PASS`, `D1O_FLUTTER_ANALYZE_TEST_WEB_BUILD=PASS`, `D1O_CANDIDATE_INTEGRAL_GATE=PASS`, `D1O_DEV_CONTAINERS_UNCHANGED=OK`, `D1O_EPHEMERAL_CLEANUP=DONE` y `D1O_RESULT=0`. El marcador `D1O_SHELL_RESULT` no consta en la salida recibida; no atribuirlo.

**D1-O PASS para base PG17 sintética, contratos Django HTTP de test, suite reminders y compilación Flutter web.** Las contraseñas `sudo` tuvieron un intento fallido previo, pero la ejecución completó el gate. El aviso WASM dry-run de Flutter no cambia el resultado.

Se solucionaron los bloqueos preflight: la referencia local `origin/main` no se había actualizado pese a `FETCH_HEAD`, y los archivos `scripts/__pycache__/` no versionados impedían el checkout limpio; commit `f246bae3` introduce `.gitignore`. No se autorizó ni realizó migración ni despliegue DEV.

**Pendientes reales:** `D1O_COMPOSE_CADDY_RUNTIME_INSPECTION=NOT_RUN`, `D1O_ANDROID_PHYSICAL=NOT_RUN`, pruebas HTTPS reales y autorizaciones de adjuntos. Prioridad siguiente: D1-P inspección/contrato HTTPS y plan de rollback Compose; después revisión de riesgos para solicitar autorización explícita de una futura promoción DEV, nunca MFA nativa.

```text
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
D1_RELEASE_AUTHORIZED=NO
D1_DEPLOY_EXECUTED=NO
D1_LIVE_MIGRATIONS_EXECUTED=NO
```


## CI. 10/11/2026 — D1-P HTTPS read-only del DEV existente publicado

El script `scripts/main_d1p_existing_dev_https_readonly.sh` (commit `8dd88d3f`) verifica TLS con CA confiable, rutas health/ready/login/CSRF y ausencia por HTTP 404 de cuatro rutas nativas de muestra **solo del DEV actualmente desplegado**, mediante peticiones GET sin cookies ni credenciales. Procedimiento `docs/D1P_EXISTING_DEV_HTTPS_READONLY_2026-11-10.md` (commit `076b9d09`). **D1-P NO EJECUTADO: no declarar PASS.** No sustituye HTTPS del candidato `main`, inspección Caddy/Compose, test de permisos de adjuntos ni validación Android. Se exige evidencia futura del operador antes de cerrar. Se mantienen `MFA_RELEASE_AUTHORIZED=NO` y `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


## CJ. 10/11/2026 — D1-P PASS y D1-Q promoción/rollback preparado

El operador ejecutó `scripts/main_d1p_existing_dev_https_readonly.sh` y comunicó `D1P_TLS_TRUSTED_CA_AND_HEALTH=PASS`, `D1P_READY_HTTP=PASS`, `D1P_LOGIN_GET=PASS`, `D1P_CSRF_GET=PASS`, `D1P_SAMPLED_NATIVE_ROUTES_404=PASS`, `D1P_EXTERNAL_HTTPS_EXISTING_DEV=PASS`, `D1P_RESULT=0` y `D1P_SHELL_RESULT=0`. Confirmó explícitamente `D1P_CANDIDATE_DEPLOYED=NO`, `D1P_CANDIDATE_HTTPS_TESTED=NO`, `D1P_COMPOSE_CONFIG_CONTENT_INSPECTED=NO`, `D1P_LOGIN_ATTEMPTED=NO`, `D1P_MUTATING_HTTP_REQUESTS=NO`. **D1-P cerrado PASS únicamente para DEV existente.** Documento actualizado en commit `ed00b3d0`.

Preparado D1-Q en `docs/D1Q_COMPOSE_ROLLBACK_READINESS_2026-11-10.md` (commit `767cb29a`): matriz de bloqueos para futura promoción, advertencia sobre rollback de datos y procedimiento de inventario Compose/O5 de solo lectura reutilizando `scripts/d1b_dev_compose_o5_metadata_readonly.py`. D1-Q **no ejecutado**; pedir solo su resultado de Termius. No actualizar ni migrar DEV sin autorización posterior.

```text
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
D1_RELEASE_AUTHORIZED=NO
D1_DEPLOY_EXECUTED=NO
D1_LIVE_MIGRATIONS_EXECUTED=NO
```


## CK. 10/11/2026 — D1-Q metadatos PASS, D1-R inventario de dependencias preparado

El operador aportó `D1B_RESULT=0`: proyecto `vencira_localcheck`, manifiestos `compose.yaml` y `compose.preview.yaml`, directorio `vencira-localcheck`, ambos timers O5 `active/enabled` y servicios `inactive/static`. La salida se registró en `docs/D1Q_COMPOSE_ROLLBACK_READINESS_2026-11-10.md` (commit `ca3aba86`). No interpretar los marcadores `D1B_BACKUP_RESTORE_VERIFIED=NO` y `D1B_MIGRATION_COMPATIBILITY_VERIFIED=NO` como reversión de los PASS de D1-M/N: esos atributos no son verificados por D1B.

Nuevo `scripts/main_d1r_dev_docker_dependency_readonly.py` (commits `fbbe2b70`, `bce1ab0e`) y procedimiento `docs/D1R_DOCKER_DEPENDENCY_INVENTORY_2026-11-10.md` (commit `8c27db2c`). El nuevo paso publica únicamente clasificaciones de metadatos Docker (no valores secretos ni rutas), sin cambios persistentes. **D1-R no ejecutado, pendiente de evidencia Termius.** El rollback real y el HTTPS del candidato `main` permanecen pendientes.

```text
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
D1_RELEASE_AUTHORIZED=NO
D1_DEPLOY_EXECUTED=NO
D1_LIVE_MIGRATIONS_EXECUTED=NO
```


## CL. 10/11/2026 — D1-R PASS; dependencia persistente PostgreSQL identificada

Termius confirmó `D1R_API_PROJECT=PASS`, `D1R_DB_PROJECT=PASS`, `D1R_WEB_PROJECT=PASS`, `D1R_THREE_DISTINCT_LIVE_CONTAINERS=PASS`, `D1R_RESULT=0`. Las tres imágenes tienen digest presente y política de reinicio; API y WEB tienen puertos publicados, DB ninguno. Recuentos Docker: API 0 binds/0 volumes/0 tmpfs; DB 0 binds/**1 volumen**/0 tmpfs; WEB 0 binds/0 volumes/0 tmpfs. Ninguno de los rootfs está configurado como readonly. Evidencia incorporada a `docs/D1R_DOCKER_DEPENDENCY_INVENTORY_2026-11-10.md` en commit `08b21a82`.

El inventario **no leyó** contenido Compose/Caddy, no ejecutó rollback ni modificó DEV. `D1R_ROLLBACK_VERIFIED=NO` sigue vigente. El volumen PostgreSQL es la dependencia persistente principal observada; no manipularlo ni asumir que rollback de imagen equivale a rollback de datos. Siguiente tramo: contrastar manifiestos reales, plan de conmutación/rollback y contrato HTTPS del candidato en laboratorio, sin tocar DEV.

```text
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
D1_RELEASE_AUTHORIZED=NO
D1_DEPLOY_EXECUTED=NO
D1_LIVE_MIGRATIONS_EXECUTED=NO
```


## CM. 10/11/2026 — D1-S autorización cruzada de ficha/adjuntos: tests publicados, no ejecutados

Se incorporó directamente en `main` `backend/reminders/test_d1s_workspace_attachment_access.py` (commit `60d665ae`) con pruebas HTTP de separación entre workspaces, miembro sin asignación y comportamiento fail-closed de adjuntos. Procedimiento y matriz de riesgos en `docs/D1S_SECURITY_PROMOTION_GAP_2026-11-10.md` (commit `5fe9c74f`). **No hay PASS de esta nueva suite aún**. El endpoint de adjuntos vigente expone metadatos autorizados; upload/download/delete siguen bloqueados explícitamente. No cambiar esta política por conveniencia de pruebas.

Inventario D1-R PASS ya documentado; persisten revisión de configuración Compose/Caddy, HTTPS de candidato aislado y rollback integral. Despliegue DEV y migraciones persistentes prohibidos. La regresión nueva puede ejecutarse sobre el PG17 sintético del ejecutor D1-O tras sincronizar `main`; es una repetición motivada por cambio nuevo de tests backend. La certificación web no implica disponibilidad del login Android nativo.

```text
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
D1_RELEASE_AUTHORIZED=NO
```


## CN. 10/11/2026 — D1-S regresión en PG17 PASS; D1-T metadatos Compose/Caddy listo

El operador volvió a ejecutar D1-O desde checkout actualizado tras publicar los tests D1-S y aportó `D1O_SECURITY_HTTP_CONTRACT=PASS`, `D1O_DJANGO_REMINDERS_SUITE=PASS`, `D1O_FLUTTER_ANALYZE_TEST_WEB_BUILD=PASS`, `D1O_DEV_CONTAINERS_UNCHANGED=OK`, `D1O_EPHEMERAL_CLEANUP=DONE` y `D1O_RESULT=0`. No se recibió el valor separado de `D1S_BACKEND_SHELL_RESULT`; no inventarlo. D1-S superado en alcance Django test discovery, no prueba de binarios ni de HTTPS candidato. Registrado en `docs/D1S_SECURITY_PROMOTION_GAP_2026-11-10.md` commit `21182f9c`.

Se integra en `main` el comprobador de solo lectura `scripts/main_d1t_compose_caddy_metadata_readonly.py` (commit `7d5530e2`) y procedimiento `docs/D1T_COMPOSE_CADDY_METADATA_2026-11-10.md` (commit `740e4204`). Comprueba únicamente presencia de los dos manifiestos conocidos y estado activo de `caddy`, sin imprimir configuración ni valores. **D1-T PENDIENTE de ejecución.** No certifica semántica Compose, configuración Caddy cargada, HTTPS del candidato o rollback. Bloqueos operativos intactos.


## CO. 10/11/2026 — D1-T PASS solo metadatos; siguiente gate de promoción sustantivo

El operador confirmó `D1T_COMPOSE_TWO_FILES_PRESENT=PASS`, existencia de `compose.yaml` y `compose.preview.yaml`, `D1T_CADDY_UNIT_ACTIVE=PASS`, `D1T_READ_ONLY=YES`, `D1T_RESULT=0`. No se adjuntó resultado independiente de shell. Persisten `D1T_CADDY_ACTIVE_CONFIG_VERIFIED=NO`, `D1T_COMPOSE_INTERPOLATION_REVIEWED=NO`, `D1T_HTTPS_CANDIDATE_TESTED=NO`, `D1T_ROLLBACK_TESTED=NO`. Resultado incorporado a `docs/D1T_COMPOSE_CADDY_METADATA_2026-11-10.md` (commit `8bb56ef5`).

**D1-T cerrado en alcance de presencia/estado de servicio.** Evitar más gates menores de mera existencia: el siguiente bloque debe revisar semántica efectiva de Compose/Caddy confidencialmente y probar el nuevo candidato con proxy HTTPS en un laboratorio sin DEV, junto con procedimiento de rollback, antes de solicitar autorización de despliegue. Sigue `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`; ni deploy ni migraciones persistentes ejecutados.


## CP. 10/11/2026 — D1-U gate consolidado publicado en main, PENDIENTE de Termius

Sin crear ramas se han integrado cuatro piezas para un solo bloque:
- `scripts/main_d1u_https_candidate_lab.py`, commit `b8606461`: WSGI HTTPS candidato, pruebas CA/SAN y endpoints de muestra en lab.
- `scripts/main_d1u_candidate_https_pg17_isolated.sh`, commit `ca20c8c3` y corrección `30a6d10b`: imagen backend desde main, PostgreSQL17 sintético en `tmpfs`, red interna, no publicación de puertos, limpieza de laboratorio y custodia de certificados sintéticos.
- `scripts/main_d1u_compose_semantics_readonly.py`, commit `49468b93`: revisión de la configuración Compose interpolación/entorno deshabilitada, toda salida sensible capturada solo en memoria.
- `scripts/main_d1u_consolidated_gate.sh`, commit `90ee744b`: un solo comando para las dos subpruebas.
- Documento operativo `docs/D1U_CONSOLIDATED_CANDIDATE_TLS_AND_COMPOSE_2026-11-10.md`, commit `7556ea07`.

**D1-U todavía NO ejecutado en el VPS; sin PASS.** Alcance HTTPS Django sintético con servidor WSGI TLS propio, *no* equivalente a Caddy operativo ni a proxy Nginx/Flutter. Aun con resultado PASS persistirán HTTPS proxy-equivalente, revisión de configuración Caddy cargada, recuperación real de imágenes + datos y aprobación expresa. A diferencia de D1-O, D1-U no repite Flutter/analyze/test/build. A diferencia de D1-P, no toca HTTPS público DEV.

Se mantiene `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`, `D1_RELEASE_AUTHORIZED=NO`.


## CQ. 10/11/2026 — D1-U primer intento: Compose PASS, TLS no ejecutado por typo

Resultado local comunicado: `D1U_COMPOSE_SEMANTICS_GATE=PASS`, `D1U_COMPOSE_RESULT=0`; el laboratorio inició red interna y PostgreSQL17 tmpfs y construyó imagen candidata, pero una línea `chmod` contenía literalmente `\\n#`, descomponiendo el comentario en argumentos y fallando antes de arrancar HTTPS. `D1U_RESULT=1`, `D1U_CANDIDATE_TLS_GATE=FAIL`; limpieza `D1U_EPHEMERAL_CLEANUP=DONE` y contenedores DEV `D1U_DEV_CONTAINERS_UNCHANGED=OK`. **No hay evidencia de TLS candidato PASS.**

Se corrigió el salto de línea y se añadió `DJANGO_SETTINGS_MODULE=config.settings` para la ejecución WSGI standalone (commit `e0a902c6`). Documento D1-U ampliado en `93673e19` con fallo y reintento. No hubo despliegue ni migración DEV. El nuevo gate sigue pendiente de validación; mantener `MFA_RELEASE_AUTHORIZED=NO` y `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


## CR. 10/11/2026 — D1-U segundo intento: PostgreSQL/candidato PASS, HTTPS FAIL (rc=6)

El operador confirmó Compose PASS, PG17 sintético tmpfs PASS, migraciones PASS, imagen candidata PASS y contenedor aislado PASS. El probe HTTPS no confirmó resultado: `D1U_HTTPS_CANDIDATE=FAIL`, `D1U_RESULT=6`, `D1U_CANDIDATE_TLS_GATE=FAIL`. `D1U_DEV_CONTAINERS_UNCHANGED=OK`, `D1U_EPHEMERAL_CLEANUP=DONE`. TLS sigue **PENDIENTE**, sin deploy ni migraciones DEV.

Hipótesis respaldada por Dockerfile: el entrypoint `/opt/d1u.py` no encontraba los módulos del backend bajo `/app`; no afirmar causa confirmada sin logs. Se publicó corrección de búsqueda de módulos Django en el servidor `scripts/main_d1u_https_candidate_lab.py`, commit `c4a80922`, y diagnósticos por etapas (servidor vivo/socket/probe) en `scripts/main_d1u_candidate_https_pg17_isolated.sh`, commit `da10e784`. Documento actualizado commit `34358cec`. Pendiente reejecución única D1-U; conservar `MFA_RELEASE_AUTHORIZED=NO` y `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


## CS. 10/11/2026 — D1-U tercer intento y SyntaxError del laboratorio corregido

El operador aportó `D1U_COMPOSE_SEMANTICS_GATE=PASS`, `D1U_PG17_TMPFS=PASS`, `D1U_SYNTHETIC_MIGRATIONS=PASS`, `D1U_CANDIDATE_CONTAINER_INTERNAL=PASS`, pero `D1U_HTTPS_SERVER_RUNNING=FAIL`, `D1U_RESULT=6` y `D1U_CANDIDATE_TLS_GATE=FAIL`. Confirmó `D1U_EPHEMERAL_CLEANUP=DONE` y `D1U_DEV_CONTAINERS_UNCHANGED=OK`. No despliegue ni migraciones persistentes.

Revisión de fuente encontró secuencias literales `\\n` entre sentencias Python fuera de strings en `scripts/main_d1u_https_candidate_lab.py`, error sintáctico suficiente para terminar el servidor al arrancar. Corregido en `9f0019dd`. Preflight AST Python + `bash -n` al inicio del gate, commit `d9e4eb49`, para impedir repetir esta clase de fallo después de construir imagen. Documento `docs/D1U_CONSOLIDATED_CANDIDATE_TLS_AND_COMPOSE_2026-11-10.md` actualizado en `fe6bbee0`. **TLS candidato todavía PENDIENTE de nueva ejecución, no PASS.** Mantener `MFA_RELEASE_AUTHORIZED=NO` y `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


## CT. 10/11/2026 — D1-U consolidado PASS; próximos riesgos Caddy y rollback

El operador compartió el resultado integral D1-U con preflight sintaxis Python/Bash PASS, revisión básica de políticas Compose PASS, PG17 sintético tmpfs PASS, migraciones sintéticas PASS, servidor HTTPS candidato y contrato HTTP PASS, denegación de CA no confiable y hostname no coincidente PASS, contenedores DEV sin cambios y limpieza efímera DONE. `D1U_CANDIDATE_TLS_GATE=PASS` y `D1U_RESULT=0`. El `D1U_SHELL_RESULT` independiente no consta. Evidencia detallada en `docs/D1U_CONSOLIDATED_CANDIDATE_TLS_AND_COMPOSE_2026-11-10.md` commit `91a790f0`.

Limitaciones expresas: `D1U_CADDY_CANDIDATE_VERIFIED=NO`, `D1U_ROLLBACK_VERIFIED=NO`, `D1U_COMPOSE_CADDY_EFFECTIVE_CONFIG_VERIFIED=NO`. La terminación HTTPS probada fue Python WSGI sintético, **no Caddy ni Nginx**. No hubo despliegue DEV ni migraciones persistentes. Siguiente tarea unificada: integración Caddy candidato en laboratorio y validación del plan de reversión de imágenes/Postgres/artefactos web. Ningún gate precedente autoriza por sí solo un deploy. `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


## CU. 10/11/2026 — D1-V Caddy real en laboratorio aislado, publicación pendiente de ejecución

D1-U cerró PASS la cadena HTTPS directa del candidato (Python WSGI sintético). Para cerrar la brecha de proxy se incorporó `scripts/main_d1v_caddy_candidate_probe.py` (commits `83a75327`, `2505b23b`) y `scripts/main_d1v_caddy_candidate_isolated.sh` (commits `690a0736`, `5a90e735`), que construyen y prueban una red interna Docker sin puertos publicados con PG17 tmpfs, Gunicorn/Django candidato y Caddy 2.11.7 TLS con un Caddyfile de laboratorio. Pruebas HTTPS: health/ready/login/CSRF, cookie `Secure`, POST sin token bloqueado, anonimato, rutas nativas no publicadas y CA no confiable denegada; sin lectura ni modificaciones de DEV. Documento completo: `docs/D1V_ISOLATED_CADDY_PROXY_AND_ROLLBACK_GAPS_2026-11-10.md`, commit `0be2b3b7`.

**D1-V NO EJECUTADO; no declarar PASS.** El Caddyfile es sintético, no la configuración activa de Caddy DEV, y la ruta web raíz sirve un fixture en lugar del Flutter real; el rollback de imágenes, artefactos y datos aún no está certificado ni ejecutado. Este bloque aporta una prueba real del software Caddy como reverse proxy ante Django, no una promoción. Se mantienen `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`, `D1_RELEASE_AUTHORIZED=NO`.
