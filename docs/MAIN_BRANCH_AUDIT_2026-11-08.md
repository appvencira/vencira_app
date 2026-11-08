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
