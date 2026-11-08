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
