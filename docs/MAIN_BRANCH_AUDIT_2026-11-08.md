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


## CV. 10/11/2026 — D1-V primer gate rc7; orden de Caddy y diagnóstico corregidos

Termius informó de `D1V_PG17_TMPFS=PASS`, `D1V_SYNTHETIC_MIGRATIONS=PASS`, `D1V_GUNICORN_STARTED=YES`, `D1V_NO_HOST_PORTS=PASS`, pero `D1V_CADDY_HTTPS_PROBE=FAIL`, `D1V_PROXY_PROBE=FAIL`, `D1V_RESULT=7`. Los contenedores DEV permanecieron inalterados y el laboratorio se limpió. No se observó la causa HTTP concreta porque el probe antiguo no mostraba el estatus fallido.

Revisión del Caddyfile de laboratorio encontró un `respond` general en conflicto con `reverse_proxy @django` por orden canónico de directivas. Se corrigió usando `handle` mutuamente excluyentes (commit `6bbbad2f`); se añadieron diagnósticos sin divulgar respuestas (commit `a2e71b16`) y validación `caddy validate` + readiness TCP antes de una única prueba HTTPS (commit `0b1934a9`). Documento D1-V actualizado `3e467762`. **D1-V PENDIENTE de reintento; no confundir corrección con PASS.**

La prueba sigue usando Caddyfile sintético; la configuración Caddy activa DEV, frontend Flutter detrás del proxy y rollback completo NO se han verificado. Se mantiene `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


## CW. 10/11/2026 — D1-V PASS: Caddy TLS aislado → Gunicorn candidato → PG17

Evidencia directa del operador: `D1V_CADDY_LAB_CONFIG_VALID=PASS`, `D1V_CADDY_SOCKET_READY=PASS`, `D1V_CADDY_TLS_HTTP_CONTRACT=PASS`, `D1V_CSRF_SECURE_COOKIE=PASS`, `D1V_CSRF_POST_DENIED=PASS`, `D1V_UNTRUSTED_CA_DENIED=PASS`, `D1V_CADDY_HTTPS_PROBE=PASS`, `D1V_CADDY_PROXY_CANDIDATE_LAB=PASS`, `D1V_PROXY_AND_BACKEND_GATE=PASS`, `D1V_DEV_CONTAINERS_UNCHANGED=OK`, `D1V_EPHEMERAL_CLEANUP=DONE`, `D1V_RESULT=0`. Junto a ello, build API, PostgreSQL 17 tmpfs y migraciones sintéticas PASS; no hubo cambios en DEV. El resultado independiente `D1V_SHELL_RESULT` no aparece en el extracto. Documento de gate actualizado en `docs/D1V_ISOLATED_CADDY_PROXY_AND_ROLLBACK_GAPS_2026-11-10.md` (commit `a69d20c8`).

**Cierre de D1-V:** Caddy 2.11.7 de laboratorio con Caddyfile sintético puede terminar TLS y reenviar HTTP a Gunicorn/Django candidato, respetando CSRF/cookies y rutas de muestra. **No acredita** la configuración Caddy efectivamente cargada en DEV, el frontend Flutter/Nginx ni rollback integrado. `D1V_CADDY_PRODUCTION_CONFIG_VERIFIED=NO`, `D1V_FLUTTER_ARTIFACT_BEHIND_CADDY_TESTED=NO`, `D1V_ROLLBACK_VERIFIED=NO` siguen siendo NO. Siguiente bloque D1-W: artefacto Flutter Web a través del reverse proxy y recuperación operativa aislada, con autorizaciones persistentes bloqueadas.

```text
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
D1_RELEASE_AUTHORIZED=NO
D1_DEPLOY_EXECUTED=NO
D1_LIVE_MIGRATIONS_EXECUTED=NO
```


## CX. 10/11/2026 — D1-W Flutter Web real con Nginx/Caddy y restore sintético publicado

Tras D1-V PASS (Caddy 2.11.7 → Gunicorn/Django con PG17 temporal), se creó en `main` `scripts/main_d1w_flutter_caddy_probe.py` (commit `cd42c9c1`) y `scripts/main_d1w_flutter_nginx_caddy_isolated.sh` (commits `20d4a2ae`, `97609506`, ajuste de referencia `90ac1b8d`). Ahora la raíz HTTPS de Caddy sirve un **artefacto Flutter Web recién compilado** desde `clients/flutter` a través de un contenedor Nginx en la red `--internal`; las rutas API pasan a Django candidato y PostgreSQL 17 en `tmpfs`. Se verifica JavaScript y bootstrap, contratos HTTP/CSRF, certificados negativos, ausencia de puertos host, limpieza y conservación de contenedores DEV.

Se añadió al mismo gate un ejercicio `pg_dump` → mutación/eliminación → `pg_restore` sobre un **esquema sintético exclusivo**, sin datos de negocio, sin conectar con DEV. Ese resultado **no sustituye la recuperación O5 integral ni el rollback operacional**. Documento: `docs/D1W_FLUTTER_NGINX_CADDY_SYNTHETIC_RECOVERY_2026-11-10.md` (commit `dc74ee15`). **D1-W está PUBLICADO pero NO EJECUTADO**; no afirmar PASS ni elevar automáticamente el porcentaje. Faltan inspección Caddy/SPA activos DEV, prueba visual navegador, preservación y conmutación de imágenes anteriores y rollback íntegro de datos/escrituras. Permisos y MFA operativos siguen bloqueados.

```text
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
D1_RELEASE_AUTHORIZED=NO
D1_DEPLOY_EXECUTED=NO
D1_LIVE_MIGRATIONS_EXECUTED=NO
```


## CY. 10/11/2026 — D1-W integración funcional PASS, gate global FAIL por permisos cleanup

El operador validó `D1W_FLUTTER_WEB_ROOT_AND_ASSETS=PASS`, `D1W_CADDY_TLS_HTTP_CONTRACT=PASS`, `D1W_CSRF_SECURE_COOKIE=PASS`, `D1W_CSRF_POST_DENIED=PASS`, `D1W_UNTRUSTED_CA_DENIED=PASS`, `D1W_CADDY_HTTPS_PROBE=PASS`, `D1W_SYNTHETIC_SCHEMA_BACKUP_RESTORE=PASS`, `D1W_FLUTTER_CADDY_POSTGRES_AND_SYNTHETIC_RESTORE_GATE=PASS`; contenedores DEV sin cambios. Pero export Flutter creó archivos propiedad de root, imposibles de borrar como usuario del host: `D1W_EPHEMERAL_CLEANUP=FAIL` y `D1W_RESULT=9`. Quedó directorio `/tmp/vencira-d1w.dNWV8mh2/web` de esta prueba; **no declarar D1-W global PASS**.

El script de D1-W recibió corrección `0b04161c` para limpieza de árbol de export mediante contenedor desechable root sin red y bind limitado al subdirectorio temporal, sin `sudo rm -rf` genérico. Documento D1-W actualizado en `972ee155` con comandos de retiro exactamente acotados al residuo anterior. Falta ejecutar el retiro y repetir el gate para observar `D1W_EPHEMERAL_CLEANUP=DONE` y `D1W_RESULT=0`. Aun con PASS no se certifica Caddy operativo ni rollback completo de Docker/PostgreSQL ni se autoriza deploy. `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


## CZ. 10/11/2026 — D1-W PASS tras corrección de limpieza

La reejecución del operador confirmó `D1W_FLUTTER_RELEASE_BUILD=PASS`, `D1W_FLUTTER_WEB_ROOT_AND_ASSETS=PASS`, `D1W_CADDY_TLS_HTTP_CONTRACT=PASS`, `D1W_CSRF_SECURE_COOKIE=PASS`, `D1W_CSRF_POST_DENIED=PASS`, `D1W_UNTRUSTED_CA_DENIED=PASS`, `D1W_CADDY_HTTPS_PROBE=PASS`, `D1W_SYNTHETIC_SCHEMA_BACKUP_RESTORE=PASS`, `D1W_FLUTTER_CADDY_POSTGRES_AND_SYNTHETIC_RESTORE_GATE=PASS`, `D1W_DEV_CONTAINERS_UNCHANGED=OK`, `D1W_EPHEMERAL_CLEANUP=DONE` y `D1W_RESULT=0`. No hay valor numérico independiente de `D1W_SHELL_RESULT` en el extracto. El resultado fue registrado en `docs/D1W_FLUTTER_NGINX_CADDY_SYNTHETIC_RECOVERY_2026-11-10.md` (commit `6fac50fb`).

**D1-W PASS** en integración completa de laboratorio Flutter Web real→Nginx→Caddy TLS→Gunicorn/Django→PG17 sintético y restauración de un esquema ficticio. NO implica rollback operativo `D1W_OPERATIONAL_IMAGE_AND_DB_ROLLBACK_VERIFIED=NO`, ni revisión de Caddy efectivo `D1W_CADDY_PRODUCTION_CONFIG_VERIFIED=NO`. La limpieza del nuevo ensayo es DONE; el retiro individual del residuo del intento anterior no fue demostrado en la salida proporcionada. Pendiente también prueba visual navegador y autorización explícita previa a cualquier despliegue. `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


## DA. 10/11/2026 — D1-X consolidado preparado, no ejecutado

En `main` se han incorporado `scripts/main_d1x_loaded_caddy_readonly.py` (commit `db6d74a2`) para leer únicamente la estructura de la configuración efectivamente cargada en Caddy mediante admin API loopback sin imprimir valores, `scripts/main_d1x_full_db_recovery_isolated.sh` (commit `d4f99bc7`) para `pg_dump` y `pg_restore` de la BD **completa pero sintética** sobre PostgreSQL 17 temporal interno sin puertos o volúmenes y `scripts/main_d1x_consolidated_readiness.sh` (commit `7ede35d4`) como control único. Procedimiento en `docs/D1X_LOADED_CADDY_AND_FULL_DB_SYNTHETIC_REHEARSAL_2026-11-10.md`, commit `b0c51ca4`.

**D1-X PENDIENTE de ejecución en VPS.** Si la API de Caddy está deshabilitada, reportará `NOT_VERIFIED` y salida 2; no es un motivo para habilitarla ni para relajar seguridad. Ni la presencia de reverse_proxy asegura ruta correcta a dev.vencira.es, ni recuperar una BD ficticia verifica rollback operativo de volúmenes, imágenes y escrituras DEV. La prueba visual navegador sigue `NO`, documentada como gate separado. Se conserva D1-W PASS anterior y `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`; ningún deploy/migración/restore persistente permitido.


## DB. 11/11/2026 — D1-X PASS: Caddy cargado y recuperación sintética PostgreSQL

El operador confirmó `D1X_CADDY_ADMIN_API_AVAILABLE=YES`, `D1X_CADDY_LOADED_HTTP_SERVER_CONFIG=PASS`, `D1X_CADDY_REVERSE_PROXY_PRESENT=YES`, `D1X_CADDY_STATIC_FILE_HANDLER_PRESENT=YES`, `D1X_CADDY_LOADED_CONFIG_GATE=PASS`. La lectura fue de solo lectura y sin imprimir contenido. También confirmó red interna, PG17 tmpfs, `D1X_DB_FULL_SYNTHETIC_DB_SNAPSHOT=PASS`, `D1X_DB_FULL_SYNTHETIC_DB_RESTORE=PASS`, `D1X_DB_DATA_RECONCILIATION=PASS`, conservación de DEV y limpieza `DONE`. `D1X_METADATA_AND_SYNTHETIC_RESTORE_GATE=PASS` y `D1X_RESULT=0`. Evidencia registrada en `docs/D1X_LOADED_CADDY_AND_FULL_DB_SYNTHETIC_REHEARSAL_2026-11-10.md` commit `8417d59c`. No consta `D1X_SHELL_RESULT` separado.

**D1-X cerrado para sus controles específicos.** No se ha probado route/upstream reales de `dev.vencira.es`, UX en navegador ni rollback operativo de imágenes/volumen/escrituras. En el log `D1X_CADDY_FULL_OPERATIONAL_CONFIG_REVIEWED=NO` queda concatenado con otro marcador, no se interpreta como PASS. `D1X_BROWSER_VISUAL_VERIFIED=NO` y `D1X_OPERATIONAL_ROLLBACK_VERIFIED=NO` expresos. No desplegar ni migrar DEV. `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


## DC. 11/11/2026 — D1-Y: ruta real DEV y disponibilidad de imágenes en modo lectura (pendiente de Termius)

Sobre D1-X PASS se publicaron directamente en `main` los scripts `scripts/main_d1y_caddy_dev_route_readonly.py` (commit `47aa7fb0`, corrección de alcance de subrutas `2a40092d`), `scripts/main_d1y_rollback_artifacts_readonly.py` (commit `e33fd23f`) y la agrupación `scripts/main_d1y_consolidated_readonly.sh` (commit `1fcbd0e7`).

El control Caddy consulta configuración efectivamente cargada por API loopback y exige coincidencia estructural explícita de `dev.vencira.es` con `reverse_proxy` en el alcance de la ruta; no publica JSON, destinos, certificados, secretos ni detalles de configuración. El inventario Docker exige disponibilidad local de imágenes en ejecución y volumen PostgreSQL nombrado. Ambos son **read-only**. Documento operativo `docs/D1Y_LOADED_DEV_ROUTE_AND_ROLLBACK_INVENTORY_2026-11-11.md` (commit `1b518d0a`).

**D1-Y no ejecutado; ningún PASS declarado.** Aun si pasara, no certifica navegador real, rutas/upstreams completos, artefactos anteriores para rollback, gestión de escrituras ni restauración de datos DEV. Conservadas las barreras `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`, `D1_RELEASE_AUTHORIZED=NO`. Próxima validación debe apuntar a riesgos funcionales pendientes en lugar de elevar un porcentaje sin evidencia.


## DD. 11/11/2026 — D1-Y regression sobre match.host antes del inventario efectivo

Se añadieron cinco tests unitarios de alcance de rutas en `scripts/test_main_d1y_caddy_dev_route.py` (commit `42fd74ba`) y se integró su ejecución obligatoria antes de consultar la configuración cargada de Caddy, en `scripts/main_d1y_consolidated_readonly.sh` (commit `f730915a`). Defienden de falsos positivos por `reverse_proxy` de un host ajeno, especialmente anidado bajo una ruta general. Procedimiento actualizado en `docs/D1Y_LOADED_DEV_ROUTE_AND_ROLLBACK_INVENTORY_2026-11-11.md` (commit `8c9331fe`). **Tests todavía sin ejecución; D1-Y pendiente.**


## DE. 11/11/2026 — D1-Y preflight detecta SyntaxError; corregido, pendiente

Primera ejecución Termius D1-Y: `SyntaxError` línea 54 de `scripts/main_d1y_caddy_dev_route_readonly.py` causado por secuencias literales `\\n` en expresión Python, `D1Y_SHELL_RESULT=1`. La compilación AST detuvo el gate **antes de consultar Caddy o Docker**; no se declara ningún resultado de ruta ni inventario. Corregido en `main`, commit `220e712e`. Documento D1-Y ampliado con evidencia y alcance, commit `b75b15e6`. Repetir solo D1-Y; no aumentar progreso ni asumir PASS hasta recibir evidencias. Barreras de release inalteradas.


## DF. 11/11/2026 — D1-Y PASS: host-scoped proxy Caddy DEV y artefactos actuales

El operador aportó `D1Y_SOURCE_AST=PASS`, `D1Y_ROUTE_UNIT_TESTS=PASS`, `D1Y_CADDY_DEV_HOST_MATCH_PRESENT=YES`, `D1Y_CADDY_DEV_HOST_SCOPED_PROXY_PRESENT=YES`, `D1Y_DEV_ROUTE_GATE=PASS`, `D1Y_ROLLBACK_API_RUNNING_IMAGE_PRESENT=PASS`, `D1Y_ROLLBACK_DB_RUNNING_IMAGE_PRESENT=PASS`, `D1Y_ROLLBACK_WEB_PREVIEW_RUNNING_IMAGE_PRESENT=PASS`, `D1Y_ROLLBACK_DB_NAMED_VOLUME_PRESENT=PASS`, `D1Y_ROLLBACK_INVENTORY_GATE=PASS`, `D1Y_READONLY_GATE=PASS`, `D1Y_RESULT=0`. Evidencia registrada en `docs/D1Y_LOADED_DEV_ROUTE_AND_ROLLBACK_INVENTORY_2026-11-11.md` commit `609be75f`.

**D1-Y PASS solo en su alcance de metadatos**, no prueba comunicación con upstream específico ni certificado real del host, imagen previa conservada, rollback operativo, RPO/RTO ni browser visual. El resultado `D1Y_SHELL_RESULT` independiente no consta; una línea `NO` y `D1Y_ROLLBACK_RESULT=0` quedó concatenada, pero `D1Y_OPS_ROLLBACK_VERIFIED=NO` consta explícito. Quedan prohibidos deploy y migraciones operativas: `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


## DG. 11/11/2026 — D1-Z implementado: Chromium real y recuperación web aislada, pendiente validación

Se incorporaron en `main` `scripts/main_d1z_chromium_smoke.js` (commit `fcddccc7`), `scripts/Dockerfile.d1z-playwright` (commit `a04741de`), `scripts/main_d1z_browser_web_recovery_isolated.sh` (commit `4c9765d9`) y `scripts/main_d1z_flutter_caddy_probe.py` (commit `cb0d0db2`). El laboratorio construye Flutter Web real sobre Nginx/Caddy TLS sintético, Gunicorn/Django y PostgreSQL17 aislado; el navegador Chromium automatizado espera un `flutter-view`, comprueba la misma-origin API, detecta errores JS y luego verifica el reinicio de **solo el Nginx desechable**, haciendo otra comprobación Chromium. Se conserva el restore de esquema sintético D1-W. No se toca DEV, la BD persistente, el Caddy operativo ni despliegues.

El procedimiento completo `docs/D1Z_BROWSER_FLUTTER_AND_ISOLATED_WEB_RECOVERY_2026-11-11.md` (commit `b6202fb2`) delimita lo no cubierto: el test no es una inspección manual de pantallas/login/calendario, y el reinicio del Nginx actual no es rollback a imagen antigua ni de datos. **D1-Z está implementado y pendiente de ejecución; no declarar PASS**. Sigue `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


## DH. 11/11/2026 — D1-Z primer Chromium FAIL sin origen discriminado

La primera ejecución de D1-Z validó PG17 sintético, Flutter release, Nginx, Caddy, contratos TLS/HTTP y la imagen Playwright Chromium (todos PASS), pero la prueba de navegador informó `D1Z_CHROMIUM_FAILURE_STAGE=RENDER_OR_BROWSER`, `D1Z_CHROMIUM_RENDER_GATE=FAIL` y `D1Z_RESULT=8`. Contenedores DEV intactos, limpieza del laboratorio DONE. **No declarar D1-Z PASS**. El marcador original no permite afirmar si el error procede del navegador, los recursos Flutter o el render.

Se publicó análisis por etapas y contadores sin exponer URLs ni secretos en `scripts/main_d1z_chromium_smoke.js` (commit `74a32b76`), más `node --check` antes del browser (commit `5df3987b`). Documento D1-Z actualizado en `docs/D1Z_BROWSER_FLUTTER_AND_ISOLATED_WEB_RECOVERY_2026-11-11.md` (commit `350bb071`). D1-Z requiere repetición para diagnóstico o PASS. No se toca DEV; `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


## DI. 11/11/2026 — D1-Z Chromium render sin Flutter view; autohospedaje CanvasKit candidato

El segundo intento D1-Z confirmó `D1Z_CHROMIUM_LAUNCH=PASS`, `D1Z_CHROMIUM_DOCUMENT=PASS`, `D1Z_CHROMIUM_BOOTSTRAP_TAG=YES`, pero `D1Z_CHROMIUM_FLUTTER_VIEW_PRESENT=NO`, `D1Z_CHROMIUM_CANVAS_PRESENT=NO`, `D1Z_CHROMIUM_FAILURE_STAGE=FLUTTER_VIEW_TIMEOUT`, `D1Z_CHROMIUM_JS_ERRORS_COUNT=6`, `D1Z_CHROMIUM_FAILED_INTERNAL_REQUESTS=0`, `D1Z_CHROMIUM_FAILED_EXTERNAL_REQUESTS=3`, `D1Z_CHROMIUM_RENDER_GATE=FAIL` y `D1Z_RESULT=8`. Toda la parte Flutter build/HTTP/TLS y aislamiento DEV pasó, limpieza DONE. No consta causa exacta de las solicitudes externas fallidas.

Se incorporó `clients/flutter/web/flutter_bootstrap.js` (commit `289f3014`) con tokens de generación oficiales y `canvasKitBaseUrl: "/canvaskit/"`, para evitar una dependencia externa del motor web. El runner D1-Z ahora exige CanvasKit JS/WASM embebido y opción generada en el bootstrap antes de la prueba Chromium (commit `028e668b`). Documentación D1-Z actualizada commit `85ce983f`. **D1-Z sigue FAIL** hasta repetir el build y Chromium: la explicación CDN es una hipótesis fundada, no una causa demostrada.

No hay despliegue DEV ni migración o restauración persistente. `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


## DJ. 11/11/2026 — D1-Z CanvasKit local reduce fallos pero render Chromium continúa FAIL

El tercer intento confirmó que el nuevo bootstrap CanvasKit local está incluido: `D1Z_LOCAL_CANVASKIT_BUNDLED=PASS`, `D1Z_BOOTSTRAP_LOCAL_CANVASKIT_CONFIG=PASS`. Error JS de 6 a 2; solicitudes externas fallidas de 3 a 1, internas 0. Pero `D1Z_CHROMIUM_FLUTTER_VIEW_PRESENT=NO`, `D1Z_CHROMIUM_FAILURE_STAGE=FLUTTER_VIEW_TIMEOUT`, `D1Z_CHROMIUM_RENDER_GATE=FAIL`, `D1Z_RESULT=8`. DEV intacto y limpieza DONE. **D1-Z no cerrado**.

Se introdujo clasificación sin exponer URLs ni secretos de tipos de peticiones fallidas, categorías de destinos externos conocidos y categorías de error JS (commit `d98be0fd`), documentado en `docs/D1Z_BROWSER_FLUTTER_AND_ISOLATED_WEB_RECOVERY_2026-11-11.md` (commit `12af42ff`). Próxima ejecución D1-Z aportará evidencias para identificar dependencia remota o excepción concreta. No se modifica Caddy operativo ni se reduce aislamiento. `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


## DK. 11/11/2026 — D1-Z identifica fallo externo Google Fonts, pero render sigue sin causa confirmada

La cuarta ejecución D1-Z confirmó build real Flutter, CanvasKit local, Chromium y documento HTML PASS, pero `flutter-view` y Canvas ausentes, `D1Z_CHROMIUM_JS_ERRORS_COUNT=2`, `D1Z_CHROMIUM_FAILED_INTERNAL_REQUESTS=0`, `D1Z_CHROMIUM_FAILED_EXTERNAL_REQUESTS=1`, `D1Z_CHROMIUM_FAILED_REQUEST_TYPE_FETCH=1`, `D1Z_CHROMIUM_FAILED_HOST_CLASS_GOOGLE_FONTS=1`, `D1Z_CHROMIUM_ERROR_CLASS_OTHER=2`. `D1Z_CHROMIUM_RENDER_GATE=FAIL`, `D1Z_RESULT=8`. Contenedores DEV intactos; cleanup DONE. La dependencia externa es Google Fonts; **no hay evidencia de que cause por sí sola el fallo Flutter**.

Se amplió diagnóstico de tipo de excepción y respuestas de JS estático sin publicar URLs ni contenido (commit `000fe419`), y se incluyó un segundo intento controlado del navegador que reemplaza exclusivamente la hoja de estilo `fonts.googleapis.com` por CSS vacío, solo tras un FAIL del navegador sin modificaciones (commit `5f61089d`). Un eventual `VIEW_PRESENT_WITH_FONT_STUB` permitiría analizar causalidad, **no suma un PASS al gate**. Evidencia y condiciones en `docs/D1Z_BROWSER_FLUTTER_AND_ISOLATED_WEB_RECOVERY_2026-11-11.md` (commit `d79a4bc4`). D1-Z pendiente de nueva ejecución. `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


## DL. 11/11/2026 — D1-Z quinta ejecución: excepción de browser por identificar

Las pruebas HTTP de Flutter/Nginx/Caddy, PG17 aislado y seguridad siguen PASS; Chromium obtiene documento/JS HTTP 200 y falla esperando `flutter-view`. Petición Google Fonts externa fallida = 1, JS errors = 2 (`LOAD_FAILURE=1`, `OTHER=1`, `EXCEPTION_TYPE_ERROR=1`). El control con CSS vacío devolvió `VIEW_ABSENT_OR_DIAGNOSTIC_FAILED` (inconcluso). `D1Z_CHROMIUM_RENDER_GATE=FAIL`, `D1Z_RESULT=8`, DEV intacto y cleanup DONE. **No convertir en PASS ni afirmar que la fuente sea la causa única.**

Se publicó un resumen redactado de excepciones `pageerror`, nunca stack ni URLs ni tokens, commits `585464a2` y `ec709087` en `scripts/main_d1z_chromium_smoke.js`, documentado en `docs/D1Z_BROWSER_FLUTTER_AND_ISOLATED_WEB_RECOVERY_2026-11-11.md` commit `4ceea47d`. Pendiente nueva ejecución de D1-Z para obtener `D1Z_CHROMIUM_SAFE_EXCEPTION_*`. Controles release `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1` inalterados.


## DM. 11/11/2026 — D1-Z regresión de instrumentación Node corregida

La siguiente ejecución del laboratorio completó en PASS PostgreSQL 17 sintético, Flutter Web release, CanvasKit local, Nginx, Caddy TLS y contrato HTTPS, pero el nuevo `node --check` detectó `SyntaxError: Invalid regular expression flags` en `scripts/main_d1z_chromium_smoke.js` (escapes indebidos en regex de redacción de mensajes). Salida `D1Z_CHROMIUM_SMOKE_SYNTAX=FAIL`, `D1Z_RESULT=8`, sin ejecutar Chromium, DEV intacto y cleanup DONE. **No atribuir el fallo a Flutter ni declarar PASS**.

Corregido en `main` commit `d4d08478`; expresiones regulares comprobadas con Node local. Incidencia detallada en `docs/D1Z_BROWSER_FLUTTER_AND_ISOLATED_WEB_RECOVERY_2026-11-11.md` commit `f911c520`. Repetición de D1-Z pendiente, conservando `MFA_RELEASE_AUTHORIZED=NO` y `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


## DN. 11/11/2026 — D1-Z excepción de locale identificada, Chromium es-ES candidato

El séptimo intento D1-Z pasó sintaxis de script, build Flutter, CanvasKit local, Caddy TLS y documentos/scripts HTTP 200, pero Chromium no generó `flutter-view`. El mensaje redactado de excepción es `Invalid argument(s): Incorrect locale information provided`; `D1Z_CHROMIUM_RENDER_GATE=FAIL`, `D1Z_RESULT=8`. Una solicitud externa Google Fonts también falla; no está demostrado que sea causa principal. DEV intacto y limpieza DONE.

Se revisaron `clients/flutter/lib/main.dart` (`es` por defecto, `ca` permitido) y `dashboard_screen.dart` (formato fecha con `languageCode`), sin prueba de código de locale inválido. Se publicó en `scripts/main_d1z_chromium_smoke.js` commit `128d72bb` una configuración explícita del contexto Chromium `es-ES` y preflight Intl/navigator para distinguir un problema de entorno del producto, sin modificar DEV ni código de idiomas. Documento D1-Z actualizado en `docs/D1Z_BROWSER_FLUTTER_AND_ISOLATED_WEB_RECOVERY_2026-11-11.md` commit `78c39991`. **D1-Z no superado; próximo paso es reejecutar y analizar marcadores regionales y renderizado.** Restricciones `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


## DO. 11/11/2026 — D1-Z Chromium render/HTTPS PASS parcial; Google Fonts externos impiden gate estricto

La última ejecución superó `D1Z_CHROMIUM_SPANISH_LOCALE=PASS`, `D1Z_CHROMIUM_INTL_DATE_LOCALE=PASS`, `D1Z_CHROMIUM_FLUTTER_VIEW=PASS` y `D1Z_CHROMIUM_SAME_ORIGIN_API=PASS`. No se trata ya del bloqueo de inicialización anterior. Sin embargo `D1Z_CHROMIUM_JS_ERRORS_COUNT=32`, peticiones externas fallidas 30 (grupo Google Fonts), internas 0, `D1Z_CHROMIUM_RENDER_GATE=FAIL` y `D1Z_RESULT=8`; DEV intacto, cleanup DONE. No declarar D1-Z PASS aún.

Se publicó commit `bcfa7d69` para clasificar estrictamente excepciones `pageerror`, errores de consola de origen Google Fonts y errores de consola restantes, con aceptación **solo para arranque funcional degradado** si las únicas incidencias son externas de fuentes; emite `PASS_WITH_FONT_DEGRADATION`, `FONT_FIDELITY_VERIFIED=NO`, nunca `JS_ERRORS=NONE`. Cualquier fallo JavaScript no atribuible a fuentes conserva FAIL. Documento D1-Z ampliado commit `8fa3996a`. Pendiente repetir operador y, posteriormente, comprobar visualmente tipografía/navegación y rollback completo de versiones/datos. `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


## DP. 11/11/2026 — D1-Z navegador Flutter/API PASS, consola 2 errores sin atribución (gate FAIL)

El operador confirmó `D1Z_CHROMIUM_FLUTTER_VIEW=PASS`, `D1Z_CHROMIUM_SAME_ORIGIN_API=PASS`, `D1Z_CHROMIUM_PAGE_ERRORS=0`, `D1Z_CHROMIUM_FONT_CONSOLE_ERRORS=31`, `D1Z_CHROMIUM_OTHER_CONSOLE_ERRORS=2`, `D1Z_CHROMIUM_FAILED_EXTERNAL_REQUESTS=31` todos Google Fonts, `D1Z_CHROMIUM_FAILED_INTERNAL_REQUESTS=0`. **D1Z continúa FAIL**: `D1Z_CHROMIUM_RENDER_GATE=FAIL`, `D1Z_RESULT=8`; DEV intacto y cleanup DONE. No asumir que los 2 errores ajenos a fuentes sean inocuos.

Para obtener causa sin desactivar controles se añadieron mensajes de consola no-font redactados y categorización de origen (commit `e284467c`), documentado en `docs/D1Z_BROWSER_FLUTTER_AND_ISOLATED_WEB_RECOVERY_2026-11-11.md` (commit `0aee421f`). Pendiente siguiente ejecución para revisar `D1Z_CHROMIUM_OTHER_CONSOLE_SAFE_*` y `D1Z_CHROMIUM_OTHER_CONSOLE_ORIGIN_*`. No se ha ejecutado reinicio Nginx del laboratorio ni rollback operativo. `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


## DQ. 11/11/2026 — D1-Z dos 403 internos no atribuidos; gate sigue FAIL

El décimo intento confirmó arranque Flutter Chromium, same-origin API y cero `pageerror`; los 31 errores de fuente externa se catalogaron Google Fonts. Pero `D1Z_CHROMIUM_OTHER_CONSOLE_ERRORS=2` corresponde a dos respuestas `403` del servidor interno, sin ruta exacta aún comprobada. El contrato sintético indica que `GET /api/v1/me/` anónimo debe devolver 401/403, pero sería incorrecto asumir que estas dos respuestas provienen de ese endpoint. `D1Z_CHROMIUM_RENDER_GATE=FAIL` y `D1Z_RESULT=8`; DEV intacto, limpieza DONE.

Se introdujo clasificación de respuestas HTTP >=400 internas y grupos fijos de rutas HTTP 403 en `scripts/main_d1z_chromium_smoke.js` (commit `ea1a95ed`), sin filtrar los errores ni abrir redes. Documento de gate D1-Z ampliado commit `9e20e24f`. Repetición pendiente para obtener `D1Z_CHROMIUM_INTERNAL_HTTP_STATUS_403` y `D1Z_CHROMIUM_INTERNAL_403_ROUTE_*`. Sin despliegue, MFA ni migraciones persistentes. `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


## DR. 11/11/2026 — D1-Z HTTP 403 anónimos precisados; nuevo gate exacto pendiente

El último intento del operador identificó las únicas dos denegaciones HTTP 403: `GET /api/v1/me/` y `GET /api/v1/workspaces/`, una cada una. Es seguridad esperada sin sesión; Flutter y API de salud Chromium pasan. Google Fonts inaccesible por red interna, 32 solicitudes externas y 32 errores de fuentes. `D1Z_CHROMIUM_PAGE_ERRORS=0`, `D1Z_CHROMIUM_RENDER_GATE=FAIL`, `D1Z_RESULT=8`, DEV intacto, cleanup DONE.

Commit `4c5eeaa5` modifica solo instrumentación D1-Z y requiere correlación explícita entre ubicación de error de consola y respuesta 403 registrada para cada ruta, exactamente dos respuestas 403, ningún otro error HTTP interno >=400, ninguna excepción JS, petición interna fallida o error de consola restante. No se relaja seguridad Django. La documentación D1-Z se actualizó en commit `fc3d3136`. **Nueva ejecución pendiente antes de declarar cualquier PASS.** Los gates posteriores (recrear Nginx aislado y restore PG17 sintético) todavía no ejecutados. `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


## DS. 11/11/2026 — D1-Z falsamente falla correlación 403 por objeto en vez de Map

El operador confirmó `CHROMIUM_FLUTTER_VIEW=PASS`, `SAME_ORIGIN_API=PASS`, `PAGE_ERRORS=0`, `OTHER_CONSOLE_ERRORS=0`, `EXPECTED_AUTH_DENIAL_CONSOLE=2`, `INTERNAL_HTTP_STATUS_403=2`, `INTERNAL_403_ROUTE_AUTH_ME=1`, `INTERNAL_403_ROUTE_WORKSPACES=1`. Aun así, `EXPECTED_ANONYMOUS_403=FAIL` y `D1Z_RESULT=8`; DEV intacto, cleanup DONE. Se identificó error en prueba: `expectedAuthDenialConsoleRoutes` declarado `{}` aunque se invocan `.set/.get/.size`; excepción en `catch` absorbida durante el registro. Corregido inicializándolo `new Map()` commit `3065e338`. Sin cambios en reglas de seguridad ni servicios. Evidencia añadida a `docs/D1Z_BROWSER_FLUTTER_AND_ISOLATED_WEB_RECOVERY_2026-11-11.md` commit `8c9c373e`. **D1-Z sigue pendiente de repetición y fases posteriores; NO PASS.** `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


## DT. 11/11/2026 — D1-Z cerrado PASS con Flutter Chromium y recuperación aislada, fuente degradada

El operador confirmó **`D1Z_RESULT=0`** y `D1Z_FLUTTER_CADDY_CHROMIUM_WEB_RESTART_AND_SYNTHETIC_RESTORE_GATE=PASS`. El test real Chromium ejecutó dos veces, antes y después de recrear solo el contenedor Nginx de laboratorio: `FLUTTER_VIEW=PASS`, `SAME_ORIGIN_API=PASS`, `PAGE_ERRORS=0`, `OTHER_CONSOLE_ERRORS=0`, `EXPECTED_AUTH_DENIAL_CONSOLE=2`, `EXPECTED_ANONYMOUS_403=PASS`, `APP_JS_ERRORS=NONE`, `SMOKE=PASS_WITH_FONT_DEGRADATION`. En red `--internal` los Google Fonts externos no se pudieron obtener, por lo que `FONT_NETWORK_DEGRADED=YES` y `FONT_FIDELITY_VERIFIED=NO`. El laboratorio también confirmó PG17 tmpfs/migraciones sintéticas, Caddy TLS y CA, CSRF, `WEB_RECOVERY_RESTART=PASS`, `CHROMIUM_AFTER_WEB_RESTART=PASS`, `SYNTHETIC_SCHEMA_BACKUP_RESTORE=PASS`, `DEV_CONTAINERS_UNCHANGED=OK` y `EPHEMERAL_CLEANUP=DONE`.

**Cierre dentro de alcance de D1-Z**, sin extrapolar a despliegue. Marcadores de límites: `D1Z_OPERATIONAL_IMAGE_AND_DB_ROLLBACK_VERIFIED=NO`, `D1Z_CADDY_PRODUCTION_CONFIG_VERIFIED=NO`, `D1Z_ROLLBACK_EXECUTED=NO`, `D1Z_ROLLBACK_VERIFIED=NO`, `D1Z_DEPLOY_EXECUTED=NO`, `D1Z_LIVE_MIGRATIONS_EXECUTED=NO`, `D1Z_LIVE_RESTORE_EXECUTED=NO`, `D1Z_RELEASE_AUTHORIZED=NO`, `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`. Pendientes pruebas visuales/fonts e interacción autenticada, respaldo/restauración operativo de versiones antiguas y decisión explícita de release. Detalle en `docs/D1Z_BROWSER_FLUTTER_AND_ISOLATED_WEB_RECOVERY_2026-11-11.md`, cierre commit `7bd0be47`. **No repetir el gate cerrado sin cambios materiales**.


## DU. 11/11/2026 — D2-A preparado sobre main; visual pixel smoke desktop/móvil NO ejecutado

Tras cierre de D1-Z PASS (`D1Z_RESULT=0`), se creó el gate independiente **D2-A** para comprobar la interfaz Flutter Web de forma más exigente en Chromium con viewports 1280×800 y 390×844. No se confunde geometría ni variación de píxeles con revisión de diseño, fidelidad tipográfica o navegación autenticada.

Nuevos scripts `scripts/main_d2a_browser_visual_isolated.sh` (commit `f807011e`), `scripts/main_d2a_flutter_caddy_probe.py` (`03a8e830`), `scripts/Dockerfile.d2a-playwright` (`ab7afda0`) y `scripts/main_d2a_chromium_visual_smoke.js` (`fff74cfe`, reforzado `aaa13691` para comprobar errores tardíos después de rasterizar). Gate final distinguible `D2A_CHROMIUM_DESKTOP_MOBILE_VISUAL_AND_RECOVERY_GATE` (commit `58e4eff2`). Se comprobó sintaxis JavaScript mediante parser V8, **pero no hay ejecución de Chromium ni de Docker del operador**. Documento de alcance y comando `docs/D2A_CHROMIUM_DESKTOP_MOBILE_VISUAL_LAB_2026-11-11.md` commit `9eccfd4f`.

La nueva fase reutiliza las barreras de red Docker interna, PG17 tmpfs, Caddy sintético, imágenes candidatas, navegador real, denegaciones anónimas, API HTTPS, recreación Nginx efímero, restore de schema ficticio y limpieza; añade captura efímera de screenshots **en memoria** decodificados vía `pngjs@7.0.0`, comprobar tamaño, bounding box y variación de colores. Se repite navegador tras recuperación Nginx. Con fuentes Google Fonts todavía inaccesibles la fidelidad visual sigue NO verificada, independientemente de resultado futuro. No hay cambios operativos DEV, autorización MFA ni migraciones. `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

**D2-A PREPARADO/PENDIENTE**: operador debe actualizar main y ejecutar `bash scripts/main_d2a_browser_visual_isolated.sh`. **No declarar PASS antes de `D2A_RESULT=0`**. D1-Z permanece cerrado y no necesita repetición.


## DV. 11/11/2026 — D2-A primer ensayo escritorio PASS, móvil FAIL sin discriminación

El operador ejecutó D2-A sobre main, verificando PostgreSQL 17 tmpfs, Flutter Web release, Caddy/TLS, CSRF, Chromium `es-ES`, `flutter-view`, API same-origin, denegación 403 anónima y ausencia de errores JS de aplicación. **Desktop visual 1280×800 PASS** (`D2A_DESKTOP_VIEW_GEOMETRY=PASS`, `D2A_DESKTOP_PNG_PIXELS=PASS`, `D2A_DESKTOP_COLOR_VARIATION=PASS`). La fase móvil devolvió `D2A_CHROMIUM_FAILURE_STAGE=VISUAL_MOBILE`, `D2A_CHROMIUM_RENDER_GATE=FAIL`, `D2A_RESULT=8`, sin decir qué subcheck falló. Fuentes Google Fonts externas bloqueadas, `PAGE_ERRORS=0`, `OTHER_CONSOLE_ERRORS=0`, `FAILED_INTERNAL_REQUESTS=0`, `DEV_CONTAINERS_UNCHANGED=OK`, `EPHEMERAL_CLEANUP=DONE`.

Commit `9f98856b`: script D2-A publica fallo exacto de geometría/PNG/pantalla plana y métricas numéricas seguras de cada viewport, sin cambiar Flutter ni umbrales. Sintaxis JavaScript revisada mediante V8. Documento `docs/D2A_CHROMIUM_DESKTOP_MOBILE_VISUAL_LAB_2026-11-11.md` actualizado commit `39d3e10d`. **D2-A pendiente de repetición**, todavía no se han ejecutado sus fases posteriores de recuperación Nginx/restore PG17. No hubo deploy ni migraciones; `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


## DW. 11/11/2026 — D2-A segundo ensayo: PNG móvil válido pero solo 3 colores en muestreo grueso

El operador obtuvo `D2A_DESKTOP_VIEW_GEOMETRY=PASS`, `DESKTOP_PNG_PIXELS=PASS`, `DESKTOP_COLOR_VARIATION=PASS` (5 colores), `D2A_MOBILE_VIEW_GEOMETRY=PASS`, `MOBILE_PNG_PIXELS=PASS` (390×844) pero `D2A_MOBILE_SAMPLED_COLOR_COUNT=3` con muestreo 21px, `D2A_CHROMIUM_FAILURE_STAGE=VISUAL_BLANK_OR_FLAT_MOBILE`, `D2A_RESULT=8`. Sin excepciones JS, errores de aplicación ni errores de red interna; Google Fonts sigue bloqueado en red interna. DEV intacto y cleanup DONE.

El muestreo 21px puede omitir elementos móviles estrechos; se añadió conteo paralelo 21px y 5px (commit `29f366da`) y se mantiene el **mismo umbral mínimo de cuatro colores** usando los píxeles de muestra densa, sin modificar Flutter, seguridad o dimensiones. JS parse PASS. Documento D2-A actualizado commit `6300e6d4`. **Pendiente nueva ejecución D2-A**, sin garantizar PASS de antemano ni atribuir defecto visual a la app. `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


## DX. 11/11/2026 — D2-A cierre PASS en Chromium desktop y móvil, recuperación aislada

Ejecución del operador: **`D2A_RESULT=0`**, `D2A_CHROMIUM_DESKTOP_MOBILE_VISUAL_AND_RECOVERY_GATE=PASS`, `D2A_DEV_CONTAINERS_UNCHANGED=OK`, `D2A_EPHEMERAL_CLEANUP=DONE`. Flutter Web release/CanvasKit local, Caddy TLS/CSRF/CA, PG17 tmpfs y API same-origin pasan. Chromium `es-ES`, `PAGE_ERRORS=0`, `OTHER_CONSOLE_ERRORS=0`, `EXPECTED_ANONYMOUS_403=PASS`; escritorio 1280×800 con 15 colores muestreados cada 5px, móvil 390×844 con 14 colores cada 5px; geometría y PNG exactos PASS. El gate se repitió tras recrear Nginx efímero con resultados equivalentes, `WEB_RECOVERY_RESTART=PASS`, `CHROMIUM_AFTER_WEB_RESTART=PASS` y `SYNTHETIC_SCHEMA_BACKUP_RESTORE=PASS`.

**Limitaciones explícitas:** `D2A_VISUAL_FIDELITY_VERIFIED=NO`, `D2A_CHROMIUM_FONT_NETWORK_DEGRADED=YES`, `D2A_CHROMIUM_FONT_FIDELITY_VERIFIED=NO`, `D2A_OPERATIONAL_IMAGE_AND_DB_ROLLBACK_VERIFIED=NO`, `D2A_CADDY_PRODUCTION_CONFIG_VERIFIED=NO`, `D2A_ROLLBACK_EXECUTED=NO`. PASS de píxeles no equivale a revisión visual humana ni a funcionalidad autenticada de UI. Ningún despliegue ni migración/restore persistente autorizado. Cierre técnico detallado en `docs/D2A_CHROMIUM_DESKTOP_MOBILE_VISUAL_LAB_2026-11-11.md`, commit `90a66ed1`. D1-Z y D2-A quedan cerrados dentro de sus alcances, sin repetir sin cambios.

Próxima fase sugerida: pruebas de interacción funcional sintética de navegador y revisión tipográfica real, manteniendo barreras `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


## DY. 11/11/2026 — D2-B preparado en main: login Django real y Flutter con usuario sintético

D1-Z y D2-A permanecen cerrados PASS en laboratorios efímeros. Para avanzar sin tocar DEV se creó **D2-B**: orquestador `scripts/main_d2b_browser_authenticated_isolated.sh` commit `4419fd8c`, contrato proxy `scripts/main_d2b_flutter_caddy_probe.py` `391a2de1`, imagen Chromium `scripts/Dockerfile.d2b-playwright` `13a12b5a`, seed de usuario propietario y workspace en PG17 tmpfs `scripts/main_d2b_seed_synthetic.py` `adeea774` y smoke `scripts/main_d2b_chromium_auth_smoke.js` `69d08a1c`, endurecido `80e90e1e` y `1af8c18f` para exigir que **Flutter** haya consultado workspace ANTES de los fetch manuales de contrato (sin falso PASS). Sintaxis JS verificada con parser V8. Documento `docs/D2B_SYNTHETIC_AUTHENTICATED_CHROMIUM_2026-11-11.md` commit `2a3d4344`.

El navegador Chromium sin credenciales de DEV rellena/formulario de login Django con CSRF, efectúa login de cuenta ficticia, verifica API `/me/` y `/workspaces/` autenticadas, presencia de `flutter-view` y fetch de workspace real desde Flutter, recarga y retención de sesión, además de contexto nuevo sin cookies con denegaciones 401/403. Repite después de recuperación Nginx temporal y backup/restore de schema ficticio, con red Docker interna, PG17 tmpfs, sin puertos publicados, limpieza automática, verificación de contenedores DEV sin cambio. NO es prueba de clicks de edición/calendario ni fidelidad visual/MFA real.

**Estado D2-B: PREPARADO, NO EJECUTADO / no PASS.** Operador debe actualizar `main` y ejecutar `bash scripts/main_d2b_browser_authenticated_isolated.sh`. No despliegues ni migraciones persistentes, `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`, `D2B_RELEASE_AUTHORIZED=NO`.

Complemento D2-B preflight: commit `5f81bbdc` incorpora validación AST tanto del proxy HTTPS como del script de fixtures Python, antes de crear el laboratorio Docker. D2-B continúa NO EJECUTADO.


## DZ. 11/11/2026 — D2-B cerrado PASS: login Django→Flutter con sesión ficticia y recuperación Nginx aislada

El operador confirmó **`D2B_RESULT=0`** y `D2B_CHROMIUM_AUTHENTICATED_NAVIGATION_AND_RECOVERY_GATE=PASS` con usuario `owner` y workspace generados exclusivamente en PG17 tmpfs. Chromium pasó formulario Django con CSRF, login HTTP real, `/api/v1/me/` 200, `/api/v1/workspaces/` 200, fetch autenticado iniciado por Flutter y `flutter-view`, persistencia de sesión después de recarga, aislamiento de un segundo contexto sin cookies con 401/403, y `PAGE_ERRORS=0`. Se repitió el mismo recorrido tras recrear exclusivamente el Nginx efímero: `D2B_WEB_RECOVERY_RESTART=PASS`, `D2B_CHROMIUM_AFTER_WEB_RESTART=PASS`. Se validó también `D2B_SYNTHETIC_SCHEMA_BACKUP_RESTORE=PASS`, contenedores DEV intactos y cleanup DONE.

No implica prueba de CRUD de vencimientos, calendario, MFA real, fidelidad visual ni rollback de imagen/base de datos operativa. Evidencia detallada en `docs/D2B_SYNTHETIC_AUTHENTICATED_CHROMIUM_2026-11-11.md`, cierre commit `42c07b23`. Restricciones: `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`, `D2B_RELEASE_AUTHORIZED=NO`, `D2B_DEPLOY_EXECUTED=NO`, `D2B_LIVE_MIGRATIONS_EXECUTED=NO`, `D2B_LIVE_RESTORE_EXECUTED=NO`.

**D1-Z, D2-A y D2-B cerrados dentro de su alcance**, sin volver a ejecutarlos sin cambios relevantes. Siguiente fase D2-C: ensayar operaciones de negocio sintéticas verificando transacciones/visibilidad en PG17 aislado, no despliegue.


## EA. 11/11/2026 — D2-C preparado; progreso verificable del tramo D1-Z → D2-C: 3/4 (75%)

D1-Z PASS, D2-A PASS y D2-B PASS confirmados por el operador. Se preparó en `main` el cuarto gate **D2-C**, con PostgreSQL 17 tmpfs y cuenta/workspace owner ficticios. Código: `scripts/main_d2c_browser_crud_isolated.sh`, `scripts/main_d2c_flutter_caddy_probe.py`, `scripts/Dockerfile.d2c-playwright`, `scripts/main_d2c_seed_synthetic.py`, `scripts/main_d2c_chromium_crud_smoke.js`. En el browser autenticado, el formulario de Django se envía con clic y el API se prueba con POST renovación sintética (201), GET detalle, GET agenda por fecha ISO y `results[].renewal.id`, PATCH con persistencia, GET eventos de auditoría y denegación anónima. El laboratorio repite el recorrido después de recrear Nginx efímero y verifica backup/restore de esquema ficticio. Sin datos, credenciales, volúmenes ni puertos de DEV. Se verificó sintaxis JavaScript en V8, **pero D2-C aún NO ejecutado**. Documento de alcance y comandos: `docs/D2C_SYNTHETIC_RENEWAL_AGENDA_BROWSER_2026-11-11.md`, commit `f5ead9b9`.

**Progreso: 3 de 4 gates de ESTE tramo específico cerrados = 75%**, sin extrapolar al porcentaje del desarrollo general de VENCIRA. D2-C pendiente de laboratorio real y `D2C_RESULT=0`. No se han validado clics Flutter de CRUD o calendario ni rollback operativo, MFA o fidelidad tipográfica. `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`, `D2C_RELEASE_AUTHORIZED=NO`.


## EB. 11/11/2026 — D2-C PASS, tramo D1-Z→D2-C cerrado 4/4 (100 % de gates definidos)

El operador ejecutó D2-C confirmando **`D2C_RESULT=0`**, `D2C_CHROMIUM_SYNTHETIC_RENEWAL_AGENDA_AND_RECOVERY_GATE=PASS`; `D2C_DEV_CONTAINERS_UNCHANGED=OK`, `D2C_EPHEMERAL_CLEANUP=DONE`. El navegador Chromium inició sesión real mediante Django con cuenta y workspace owner sintéticos de PG17 tmpfs; creó vencimiento vía API (201), leyó detalle, comprobó su presencia en agenda de fecha civil, modificó y releyó datos persistidos, recuperó eventos de auditoría y confirmó rechazo de workspace para sesión anónima; `D2C_BROWSER_PAGE_ERRORS=0`, `D2C_FIXTURE_ONLY=YES`, `D2C_CHROMIUM_SYNTHETIC_CRUD_GATE=PASS`. Se recreó solo Nginx efímero y **repitió** todo el recorrido con PASS (`D2C_WEB_RECOVERY_RESTART=PASS`, `D2C_CHROMIUM_AFTER_WEB_RESTART=PASS`). Backup/restore de esquema sintético `D2C_SYNTHETIC_SCHEMA_BACKUP_RESTORE=PASS`.

**Progreso verificable D1-Z, D2-A, D2-B y D2-C: 4 de 4 gates PASS = 100 % de ESTE tramo, no del producto completo.** No autoriza release. `D2C_REAL_UI_CRUD_CLICKS_VERIFIED=NO`, `D2C_OPERATIONAL_IMAGE_AND_DB_ROLLBACK_VERIFIED=NO`, `D2C_CADDY_PRODUCTION_CONFIG_VERIFIED=NO`, `D2C_ROLLBACK_EXECUTED=NO`, `D2C_ROLLBACK_VERIFIED=NO`. Evidencia detallada en `docs/D2C_SYNTHETIC_RENEWAL_AGENDA_BROWSER_2026-11-11.md`, commit `6d5d8f4c`. Pendientes nuevo bloque de interacciones Flutter GUI, revisión visual/fonts y recuperación operativa. Continúan `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`, sin cambios sobre DEV.


## EC. 11/11/2026 — D2-D agrupado preparado, edición real Flutter mediante tests de widgets; 4/5 (80 %) del tramo extendido

D1-Z→D2-C sigue **4/4 PASS**, 100 % del tramo cerrado. Se incorporó en **main** una fase posterior D2-D: `clients/flutter/test/d2d_real_editor_gestures_test.dart` (commits `f260c3ae` y `ddd52be2`) con gestos Flutter reales en viewports 390×844 y 1280×800: abrir editor, validar campos obligatorios, completar nombre, seleccionar Entrada con `VenciraSelect`, elegir fecha con Material DatePicker, escribir notas y guardar; edición de anotación existente conservando referencia y fecha; cancelación sin devolver cambios. El script agrupado `scripts/main_d2d_flutter_ui_grouped_isolated.sh` (commit `c8a4caa8`) ejecuta en una única copia `tmpfs` de Flutter 3.44 `flutter analyze`, los nuevos widget tests y los tests previos `renewal_editor_test.dart` de es/ca, montando fuente solo lectura y comprobando identidad de DEV. Sin DB operativa, sin migraciones, sin deploy y sin autorización MFA.

Documento técnico `docs/D2D_GROUPED_FLUTTER_EDITOR_INTERACTION_2026-11-11.md` creado commit `cfe79dc0`. **D2-D NO ejecutado, NO PASS**; requiere validación en Termius. Progreso del tramo extendido D1-Z, D2-A, D2-B, D2-C, D2-D: **4/5 gates = 80 %**, no porcentaje del producto total. Flutter widget test NO implica clicks Chromium integrados con backend; D2-C verificó previamente CRUD API por browser, por separado. Sigue pendiente UI end-to-end y revisión de fuentes/renderizado, recuperación operativa. `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


## ED. 11/11/2026 — D2-D PASS; tramo D1-Z→D2-D cerrado 5/5 (100 % verificable del tramo)

Operador confirma `D2D_RESULT=0`, `D2D_SHELL_RESULT=0`, `D2D_FLUTTER_EDITOR_DESKTOP_MOBILE_GROUP_GATE=PASS`. `flutter analyze`: 0 incidencias. Nuevos tests de gestos Flutter `d2d_real_editor_gestures_test.dart`: **4/4 PASS** (alta móvil 390×844, alta escritorio 1280×800, edición conservando identidad/vencimiento y cancelación sin guardar). Regresión anterior `renewal_editor_test.dart`: **4/4 PASS** (castellano/catalán). `D2D_FLUTTER_UI_GROUP=PASS`, `D2D_DEV_IDENTITY=PASS`, `D2D_DEV_CONTAINERS_UNCHANGED=OK`, `D2D_REAL_DEV_DATA_USED=NO`. Sin desplegar ni migrar datos reales; `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

**Progreso: D1-Z, D2-A, D2-B, D2-C y D2-D = 5/5 PASS, 100 % del tramo de validaciones definido. No indica 100 % de desarrollo/release de VENCIRA.** Falta test E2E de clics Chromium sobre Flutter Web y persistencia backend en una misma sesión, fonts/UX real y rollback operativo de imagen+base persistente. `D2D_REAL_CHROMIUM_GUI_CLICK_VERIFIED=NO` permanece. Cierre documentado en `docs/D2D_GROUPED_FLUTTER_EDITOR_INTERACTION_2026-11-11.md`, commit `5f304820`. No repetir estos gates salvo cambios materiales en dependencias.


## EE. 11/11/2026 — D2-E preparado: primer E2E de clics Flutter Web reales → Django → PG17 efímero

Después del tramo D1-Z→D2-D cerrado **5/5 PASS**, se abrió gate **D2-E (NO EJECUTADO)** con laboratorio aislado en `main`. Se publicaron `scripts/main_d2e_browser_gui_isolated.sh` (`d2b7efd6`), `scripts/main_d2e_flutter_caddy_probe.py` (`c1c3ade9`), `scripts/Dockerfile.d2e-playwright` (`6795ad2a`), `scripts/main_d2e_seed_synthetic.py` (`0a84adc2`) y `scripts/main_d2e_chromium_gui_smoke.js` (`7a31c1a4`, correcciones `851f1e9e`, `113394e2`). Documentado en `docs/D2E_REAL_CHROMIUM_FLUTTER_GUI_PG17_2026-11-11.md` (`9ee2d711`).

El test carga Flutter 3.44 Web real bajo Caddy TLS sintético, autentica un usuario ficticio, exige DOM de accesibilidad Flutter, busca un vencimiento ficticio presembrado y **usa clic/teclado de Chromium para editar notas desde GUI**. Verifica por API **solo GET** la persistencia Django/PG17; un segundo pase después de recrear Nginx escribe un valor **distinto**, evitando falso positivo por el primer pase. Repiten guardas de aislamiento y limpieza, sin credenciales, puertos ni DB DEV. Sintaxis JS revisada por V8, pero **no se conoce todavía resultado Chromium**. No utilizar POST/PATCH directo como sustituto de clic GUI si Flutter no expone semántica navegable.

**Progreso:** D1-Z→D2-D 5/5 PASS (100 % del tramo concluido). D2-E 0/1 PASS (pendiente), no se dispone de porcentaje global fundamentado. La primera prueba D2-E valida únicamente editar notas desde dashboard escritorio; quedan otros flujos GUI, fonts/UX, rollback operativo y MFA real. Se mantienen `MFA_RELEASE_AUTHORIZED=NO` y `NO_DEPLOY_NO_LIVE_MIGRATION=1`; no hay autorización de deploy.


## EF. 11/11/2026 — D2-E primer ensayo FAIL, diagnóstico Flutter/semántica desambiguado

Operador ejecutó `scripts/main_d2e_browser_gui_isolated.sh`: aislamiento PG17 tmpfs, build Flutter/CanvasKit, Caddy HTTPS/CSRF/CA, login Django sintético y sintaxis Chromium **PASS**, pero `D2E_GUI_FAILURE_STAGE=FLUTTER`, `D2E_GUI_PAGE_ERROR_COUNT=0`, `D2E_CHROMIUM_RENDER_GATE=FAIL`, `D2E_RESULT=8`. El script limpió recursos y conservó los contenedores DEV (`D2E_DEV_CONTAINERS_UNCHANGED=OK`, `D2E_EPHEMERAL_CLEANUP=DONE`). No se probó clic de edición ni persistencia, por tanto D2-E **NO PASS**.

La etapa FLUTTER original aglutinaba `flutter-view`, `flt-semantics-placeholder` y árbol semántico. Se publicó diagnóstico granular sin modificar funcionalidad ni relajar exigencia de clic Flutter (commit `448d9528`): marcadores `D2E_FLUTTER_VIEW_ATTACHED`, `D2E_FLUTTER_SHADOW_ROOT`, `D2E_FLUTTER_PLACEHOLDER_COUNT`, `D2E_FLUTTER_SEMANTICS_COUNT_BEFORE`, `D2E_FLUTTER_SEMANTICS_HOST_COUNT`, `D2E_FLUTTER_PLACEHOLDER_CLICK`, `D2E_GUI_FAILURE_STAGE`, `D2E_GUI_FAILURE_TYPE`. JS parser V8 PASS. Documento D2-E actualizado commit `91563533`. Pendiente ejecutar de nuevo en VPS antes de atribuir causa. Sin deploy/migraciones/MFA: `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


## EG. 11/11/2026 — D2-E segundo ensayo FAIL (activación de accesibilidad de Flutter); diagnóstico con gesto de puntero real

El operador confirma `D2E_RESULT=8`, `D2E_GUI_FAILURE_STAGE=ACCESSIBILITY_ENABLE`, `D2E_GUI_FAILURE_TYPE=TIMEOUT`, `D2E_GUI_PAGE_ERROR_COUNT=0` tras `D2E_BROWSER_SYNTHETIC_LOGIN=PASS`, `D2E_FLUTTER_VIEW_ATTACHED=PASS`, `D2E_FLUTTER_PLACEHOLDER_COUNT=1`, `D2E_FLUTTER_SEMANTICS_HOST_COUNT=2`, `D2E_FLUTTER_SEMANTICS_COUNT_BEFORE=0`, `D2E_FLUTTER_PLACEHOLDER_FOUND=YES`. El timeout sucede durante Playwright click normal sobre placeholder, no al cargar Flutter; no prueba aún problemas reales de negocio. DEV intacto, limpieza DONE y cero deploy.

Para identificar si Playwright está bloqueando por visibilidad/área de clic, el commit `4155896f` registra características booleanas del control y, **solo si tiene área positiva y entra en viewport**, intenta un clic con `force:true`, que sigue siendo puntero real, sin manipulación del DOM ni llamadas PATCH/POST directas. El test aún exige controlar realmente Flutter GUI, introducir valor distinto en cada fase y verificar el resultado en PostgreSQL mediante GET. Documentación en `docs/D2E_REAL_CHROMIUM_FLUTTER_GUI_PG17_2026-11-11.md` commit `21073c8b`. **D2-E permanece FAIL hasta una validación nueva y `D2E_RESULT=0`**. Los cinco gates anteriores siguen PASS y no se repiten. Protección `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1` vigente.


## EH. 11/11/2026 — D2-E tercer ensayo: causa raíz accesibilidad Flutter fuera de viewport; bootstrap del botón oculto corregido

Evidencia: `D2E_RESULT=8`, `D2E_GUI_FAILURE_STAGE=DASHBOARD_LIST`, `D2E_GUI_FAILURE_TYPE=TIMEOUT`, cero errores JS; `flutter-view` PASS, `flt-semantics-placeholder` existe con geometría positiva pero `D2E_PLACEHOLDER_IN_VIEWPORT=NO`, sin `display:none`, `visibility:hidden` ni `pointer-events:none`; `D2E_FLUTTER_PLACEHOLDER_POINTER_CLICK=NOT_POSSIBLE`, aunque hay nodos `flt-semantics-host`. Flutter documenta que su botón invisible de activación de accesibilidad está intencionadamente colocado en `(-1,-1)` y no es alcanzable por puntero. Fuentes: https://docs.flutter.dev/ui/accessibility/web-accessibility y https://flutter.dev/blog/accessibility-in-flutter-on-the-web .

Commit `939e3f95` del test D2-E usa `HTMLElement.click()` exclusivamente para **activar el botón oculto del framework** cuando está fuera de pantalla; la edición y guardado de notas siguen obligatoriamente mediante eventos reales de ratón/teclado de Chromium, con verificación posterior de persistencia PG17 exclusivamente por GET. No se falsea el clic de negocio, no se ejecuta escritura de API para superar el gate y no cambia el código de VENCIRA. Documento actualizado `docs/D2E_REAL_CHROMIUM_FLUTTER_GUI_PG17_2026-11-11.md` commit `8fc2788a`.

**D2-E aún FAIL / a revalidar**, sin despliegue ni autorización MFA. Contenedores DEV intactos y limpieza DONE; D1-Z→D2-D continúa 5/5 PASS.


## EI. 11/11/2026 — D2-E cuarto ensayo: accesibilidad activada, bloqueo DASHBOARD_LIST; ruta inicial auto-agenda corregida

El operador confirmó `D2E_RESULT=8`, `D2E_ACCESSIBILITY_HIDDEN_BUTTON_ACTIVATED=PASS`, `D2E_FLUTTER_SEMANTICS_CONTAINER_ATTACHED=PASS`, `D2E_GUI_FAILURE_STAGE=DASHBOARD_LIST`, `D2E_GUI_FAILURE_TYPE=TIMEOUT`, cero errores JS, DEV intacto y limpieza DONE. La carga de Flutter y activación de accesibilidad ya pasaron; el test falla al buscar el vencimiento ficticio.

Inspección del código Flutter `dashboard_screen.dart`: tras login con único workspace y `openTodayOnLoad`, la app **abre automáticamente la agenda de hoy**. D2-E siembra una única cuenta y una renovación futura, de modo que buscar directamente el texto en dashboard puede fallar porque la pantalla visible es agenda. Commits `86566e7e` y `2e6736e8`: el smoke detecta agenda por texto o botón único de retroceso, navega usando **clic real de Playwright sobre Flutter Back**, luego busca el vencimiento tanto en DOM convencional como en `flt-semantics[aria-label]`. Si falla, emite recuentos anónimos y booleanos semánticos para diagnóstico sin logs de datos privados. Se mantienen escritura GUI real y verificación PG17 por GET; ningún bypass de formulario ni API PATCH sintético. Documento `docs/D2E_REAL_CHROMIUM_FLUTTER_GUI_PG17_2026-11-11.md` commit `588a5810`.

**Estado D2-E sigue FAIL y no contabiliza PASS**; siguiente acción es ejecutar nueva versión en laboratorio aislado. Precedentes D1-Z→D2-D continúan 5/5 PASS. MFA y despliegue sin autorizar.


## EJ. 11/11/2026 — D2-E quinto ensayo FAIL; diagnóstico estructural de CanvasKit y baseline PG17 GET

Usuario aportó `D2E_RESULT=8`: `D2E_ACCESSIBILITY_HIDDEN_BUTTON_ACTIVATED=PASS`, `D2E_FLUTTER_SEMANTICS_CONTAINER_ATTACHED=PASS`, pero `D2E_INITIAL_AGENDA_TEXT_VISIBLE=NO`, `D2E_INITIAL_BACK_BUTTON_COUNT=0`, `D2E_DASHBOARD_SEMANTICS_COUNT=44`, `D2E_DASHBOARD_LABELED_COUNT=2`, `D2E_DASHBOARD_ROLE_BUTTON_COUNT=20`, `D2E_DASHBOARD_AGENDA_LABEL_PRESENT=NO`, `D2E_GUI_FAILURE_STAGE=DASHBOARD_LIST`, `D2E_GUI_FAILURE_TYPE=ASSERTION_OR_RUNTIME`. No se puede afirmar ya que la agenda inicial sea la causa; tampoco se sabe si la renovación está ausente de la DB. Red aislada, PG17 tmpfs, build, HTTPS, CSRF y login PASS; DEV intacto, cleanup DONE y no deploy.

Commit `29446299`: diagnóstico no invasivo, previo a marcar el gate, distingue API **solo GET** de la fixture, coincidencias DOM semánticas y accesibilidad CDP `Accessibility.getFullAXTree` mediante booleanos y recuentos, sin exponer contenido de usuarios ni reemplazar clics por PATCH. Documento `docs/D2E_REAL_CHROMIUM_FLUTTER_GUI_PG17_2026-11-11.md` actualizado commit `05625176`. **D2-E continúa FAIL, pendiente reejecución local**; gates D1-Z→D2-D 5/5 PASS, sin despliegue ni MFA real.


## EK. 11/11/2026 — D2-E sexta ejecución alcanza el guardado GUI real, pero falla persistencia

El operador obtuvo `D2E_GUI_RETURN_FROM_AGENDA=PASS`, `D2E_GUI_SYNTHETIC_RENEWAL_VISIBLE=PASS`, `D2E_GUI_EDIT_CLICK=PASS`, `D2E_GUI_NOTES_TYPED=PASS`, `D2E_GUI_SAVE_CLICK=PASS`; sin embargo `D2E_GUI_FAILURE_STAGE=NOT_PERSISTED`, `D2E_RESULT=8`. Backend/HTTPS/login/sintéticos PASS, cero errores JS, DEV intacto y cleanup DONE. **D2-E no está aprobado**. El método Flutter `_write` espera PATCH 200 y `_editRenewal` puede ocultar fallos del usuario bajo mensaje de guardado fallido, sin propagación a JavaScript.

Commit `c7526af7`: instrumento pasivo Playwright de respuestas PATCH (solo código HTTP y conteo), cuenta controles Guardar antes/después del clic y mantiene GET final de persistencia; no captura cuerpos, credenciales ni URL con UUID; no simula escrituras. Evidencia y procedimiento en `docs/D2E_REAL_CHROMIUM_FLUTTER_GUI_PG17_2026-11-11.md` commit `8e92773b`. Requiere repetir laboratorio para distinguir ausencia de PATCH de rechazo HTTP y solo entonces corregir causa. No alterar DEV ni cambiar el estatus de MFA; D1-Z→D2-D 5/5 siguen PASS.


## EL. 11/11/2026 — D2-E: fixture confirmada por GET, Back en AX, ruta Flutter no reconocida

Séptimo ensayo del operador `D2E_RESULT=8`; `D2E_READONLY_API_BASELINE=FIXTURE_VISIBLE`, `D2E_AX_NODE_COUNT=120`, `D2E_AX_SYNTHETIC_NAME_MATCH=NO`, `D2E_AX_BACK_NAME_MATCH=YES` y `D2E_SEMANTICS_BACK_TEXT_PRESENT=YES`, frente a `D2E_INITIAL_BACK_BUTTON_COUNT=0`. Falló `DASHBOARD_LIST` sin editar ni llegar al guardado. La anotación está en PostgreSQL aislado; el problema observado es de navegación/semántica GUI, no de ausencia de datos. El árbol AX detecta un nombre de volver pero no garantiza que sea botón clicable. Dev intacto, cleanup DONE, sin despliegue/MFA.

Commit `938bbaaa`: detección asíncrona de ruta inicial (auto-agenda con único workspace) por texto de la anotación o **un** botón volver semántico/rol/texto/aria y clic real Playwright, con marcadores de ruta y recuentos, sin manipulación de navegador ni escrituras API. Documentación D2-E actualizada commit `3fc500e2`. D2-E aún FAIL pendiente VPS; persiste la necesidad de diagnosticar `NOT_PERSISTED` del ensayo que sí llegó a Guardar usando contadores/códigos PATCH instrumentados en commit `c7526af7`. Gates D1-Z→D2-D 5/5 siguen PASS. `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


## EM. 11/11/2026 — D2-E octavo ensayo: PATCH HTTP 200 por clic GUI, GET no verifica notas

Usuario reportó `D2E_INITIAL_ROUTE=AGENDA`, `D2E_GUI_RETURN_FROM_AGENDA=PASS`, `D2E_GUI_SYNTHETIC_RENEWAL_VISIBLE=PASS`, `D2E_GUI_EDIT_CLICK=PASS`, `D2E_GUI_NOTES_TYPED=PASS`, `D2E_GUI_SAVE_CLICK=PASS`, `D2E_GUI_PATCH_COUNT=1`, `D2E_GUI_PATCH_STATUS=200`, `D2E_GUI_EDITOR_STILL_OPEN=NO`; pero `D2E_GUI_FAILURE_STAGE=NOT_PERSISTED`, `D2E_RESULT=8`. Django aceptó al menos una petición PATCH iniciada por GUI, pero el GET de lista no confirmó las notas sintéticas. No asignar PASS, no asumir un fallo de BD ni afirmar que Flutter cambió el campo esperado sin inspeccionar datos de respuesta.

Se revisó `backend/reminders/serializers.py` (`notes` editable y serializado) y `backend/reminders/views.py` (GET lista y PATCH detalle comparten `RenewalSerializer`). Commit `0f53d92a` añade únicamente clasificación booleana de respuesta PATCH (si corresponde a `D2E-EDIT`, si incluye `notes`, si es igual a `D2E GUI first/second`) y GET de detalle de solo lectura para distinguir `DETAIL_MATCHES`/`DETAIL_NOTES_UNCHANGED`/`DETAIL_NOTES_DIFFERENT`. Sin registrar contenidos, ID, contraseñas ni escribir desde JavaScript. Documento actualizado `docs/D2E_REAL_CHROMIUM_FLUTTER_GUI_PG17_2026-11-11.md` commit `28485c25`. Sintaxis JS parse PASS; laboratorio VPS aún pendiente de reejecución. `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`, DEV inalterado.


## EN. 11/11/2026 — D2-E noveno ensayo: PATCH 200 al registro correcto, notas persistidas distintas

Operador confirma `D2E_GUI_PATCH_COUNT=1`, `D2E_GUI_PATCH_STATUS=200`, `D2E_GUI_PATCH_FIXTURE_TARGET=YES`, `D2E_GUI_PATCH_RETURNED_NOTES_MATCH=NO`, `D2E_GUI_PATCH_RETURNED_NOTES_FIELD=YES`, `D2E_READONLY_DETAIL_PERSISTENCE=DETAIL_NOTES_DIFFERENT`, `D2E_RESULT=8`; interfaz Flutter real y regreso de agenda PASS, DEV sin cambios y cleanup DONE. La discrepancia está en el texto de las notas, no en autenticación, HTTP, CSRF o identidad del vencimiento. No es válido declarar E2E PASS ni asumir error de guardado PG17 sin conocer el valor enviado.

Inspección código Flutter `renewal_editor.dart` y `vencira_api.dart`: controlador `_notes` y serialización `notes.trim()` normales; la interacción anterior Playwright `locator.fill()` podría no alcanzar el estado interno CanvasKit. Commit `e8591fd5` cambia el ensayo a clic/seleccionar todo/escritura por **teclado real** y registra solo categorías de notas de solicitud y respuesta PATCH, sin contenido ni identificadores, manteniendo la verificación GET de PostgreSQL. Documento D2-E actualizado `37c7897f`. JS parse PASS; nueva ejecución VPS pendiente. D1-Z→D2-D siguen 5/5 PASS. Sin desplegar, sin migraciones operativas, `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


## EO. 11/11/2026 — D2-E cerrado PASS; Flutter Web Chromium→Django→PG17 con persistencia real dos veces

El operador confirma `D2E_RESULT=0`. Chromium realiza login real, vuelve desde Agenda al dashboard, visualiza anotación sintética, abre editor mediante clic, sustituye notas con eventos reales de ratón/teclado, pulsa Guardar, recibe **un PATCH HTTP 200** al registro de fixture correcto y verifica coincidencia exacta de las notas en request/response y **GET posterior** a PG17 (`D2E_GUI_TO_DJANGO_PG17_PERSISTENCE=PASS`). `D2E_GUI_PAGE_ERRORS=0`, `D2E_REAL_GUI_END_TO_END_GATE=PASS`, `D2E_CHROMIUM_RENDER_GATE=PASS`. Se reinicia Nginx efímero (`D2E_WEB_RECOVERY_RESTART=PASS`) y se repite **el flujo completo con valor distinto**, `D2E_CHROMIUM_AFTER_WEB_RESTART=PASS`. Es demostración E2E real de **editar notas desde escritorio**, no de todo CRUD por clicks ni mobile completo.

Isolación y limpieza: `D2E_INTERNAL_NETWORK=PASS`, `D2E_PG17_TMPFS=PASS`, `D2E_CADDY_TLS_HTTP_CONTRACT=PASS`, `D2E_CSRF_POST_DENIED=PASS`, `D2E_UNTRUSTED_CA_DENIED=PASS`, `D2E_SYNTHETIC_SCHEMA_BACKUP_RESTORE=PASS`, `D2E_DEV_CONTAINERS_UNCHANGED=OK`, `D2E_EPHEMERAL_CLEANUP=DONE`. `D2E_DEPLOY_EXECUTED=NO`, `D2E_LIVE_MIGRATIONS_EXECUTED=NO`.

**Tramo D1-Z→D2-E: 6/6 PASS (100 % de ese tramo, no de VENCIRA global).** Excluidos expresamente: `D2E_OPERATIONAL_IMAGE_AND_DB_ROLLBACK_VERIFIED=NO`, `D2E_CADDY_PRODUCTION_CONFIG_VERIFIED=NO`, `D2E_ROLLBACK_EXECUTED=NO`, `D2E_ROLLBACK_VERIFIED=NO`. Requiere siguiente bloque de garantías operativas, validación UX y gates seguridad/MFA antes de release. Evidencia en `docs/D2E_REAL_CHROMIUM_FLUTTER_GUI_PG17_2026-11-11.md`, cierre commit `52629c8a`. `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


## EP. 11/11/2026 — D3 grouped pre-release readiness prepared on main (NO release)

Following 6/6 PASS D1-Z→D2-E, the operator requested acceleration and grouping without new branches. Implemented directly in `main`:

- `scripts/main_d3a_full_pg17_rollback_isolated.sh` (`63f54a30`, seed fix `e95ed0e2`): Docker internal-only PG17 tmpfs, candidate Django image, migrations, synthetic user/workspace/renewal, **full pg_dump -Fc of the synthetic DB**; controlled notes mutation; `dropdb`/`createdb`/full `pg_restore` **only on temporary DB**; verify original notes, owner identity, membership, Django runtime and migration parity. Guard DEV container IDs/image identities before/after; cleanup. **No O5 real backup nor persistent data touched**. This is NOT operational image rollback.
- `scripts/main_d3c_caddy_readonly_preflight.sh` (`b3459035`): checks host Caddyfile with `caddy validate`, local systemd caddy active and HTTPS TLS certificate/HTTP availability on `dev.vencira.es` with no credentials, config output or process changes. May return UNVERIFIED for containerized topology.
- `scripts/main_d3_grouped_release_preflight.sh` (`f7cd4266`, bundle `cc5daa49`): single operator command, validate clean/synced main and script syntax, execute D3-A one time, then D3-C as read-only non-authorizing check. No repetition of concluded D2-E or Flutter widget tests. Emits explicit release fence: `D3_OPERATIONAL_IMAGE_AND_PERSISTENT_DB_ROLLBACK_VERIFIED=NO`, `D3_PRODUCTION_CADDY_CONFIG_VERIFIED=NO`, `D3_PUBLIC_RELEASE_AUTHORIZED=NO`, `D3_RELEASE_READINESS=GATED`.
- Details, exact Termius command and expected markers: `docs/D3_GROUPED_RELEASE_READINESS_2026-11-11.md` commit `489f072e`.

**Estado D3: scripts committed, NOT EXECUTED on VPS; result unknown.** Do not assign PASS or date of production. Must still validate persistent image+DB/O5 operational rollback, production Caddy topology, security/MFA and explicitly authorize a controlled pilot or production rollout. `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`, no actual deploy or operational migrations.


## EQ. 11/11/2026 — D3 primer ensayo detenido por nombre de rama; guardas por commit conservadas

El operador aportó `D3_MAIN_REQUIRED=FAIL`, `D3_SHELL_RESULT=2`. No se ejecutaron D3-A (PG17 full synthetic restore) ni D3-C (Caddy read-only). Era un requisito innecesario que exigía `git branch --show-current == main` en un checkout de laboratorio, aunque HEAD puede estar desacoplado y ser idéntico a `origin/main`.

Commits correctivos directos en `main`: `03b375bf` en `scripts/main_d3_grouped_release_preflight.sh` y `1a602505` en `scripts/main_d3a_full_pg17_rollback_isolated.sh`. Eliminan la dependencia del **nombre** de rama sin relajar `HEAD==refs/remotes/origin/main`, clean tree, identidad de contenedores DEV o `NO_DEPLOY_NO_LIVE_MIGRATION=1`. Documentación D3 actualizada `8b04e3a1`. Se requiere retest local. D3 sigue 0 gates verificados, D1-Z→D2-E 6/6 PASS.


## ER. 11/11/2026 — D3 grouped execution PASS: full synthetic PG17 restore and read-only DEV Caddy

Operator logs establish `D3_RESULT=0`, `D3A_RESULT=0`, `D3C_RESULT=0`. D3-A passed candidate Django and migrations in PG17 tmpfs internal network, full custom-format `pg_dump` of synthetic DB, controlled mutation and full restore into fresh synthetic DB, integrity of renewal/auth/membership and Django runtime after restore; `D3A_FULL_SYNTHETIC_DB_ROLLBACK_GATE=PASS`. D3-C passed **real host Caddyfile validation**, active service and trusted public HTTPS to `dev.vencira.es`: `D3C_REAL_CADDY_SYNTAX_AND_SERVICE_VERIFIED=PASS`. Operator confirms `D3A_DEV_CONTAINERS_UNCHANGED=OK`, `D3A_EPHEMERAL_CLEANUP=DONE`. No deploy or live DB migration occurred.

**Scoped count 8/8 PASS** = 6 prior D1-Z→D2-E plus D3-A and D3-C. Not a global completion % and **NOT release-ready**: `D3_OPERATIONAL_IMAGE_AND_PERSISTENT_DB_ROLLBACK_VERIFIED=NO`, `D3_PRODUCTION_CADDY_CONFIG_VERIFIED=NO`, `D3_PUBLIC_RELEASE_AUTHORIZED=NO`, `D3_RELEASE_READINESS=GATED`, `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`. Synthetic PG17 full restore is not real O5 backup restore nor image rollback, and DEV Caddy HTTP/TLS is not public production routing audit. D3 evidence and blockers recorded in `docs/D3_GROUPED_RELEASE_READINESS_2026-11-11.md` commit `e5a47766`. Prioritize D3-B real O5+image **isolated** rehearsal, then public domain routing/security/release gates. No branches.
