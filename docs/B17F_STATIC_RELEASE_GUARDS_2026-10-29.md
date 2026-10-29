# VENCIRA — B17F: auditoría estática negativa de entradas de publicación

**Fecha:** 29/10/2026. **Rama:** `feature/c-ficha-independent-attachments`.

## Objetivo y fundamento

B17E identificó rutas históricas de despliegue y autorizaciones pendientes. B17F añade una **auditoría estática read-only**, no un release gate de producción: `scripts/b17f_static_release_guard_audit.py`. Comprueba dinámicamente el inventario `scripts/deploy_*.sh`, el modo de protección esperado (web/schema/api), existencia exactamente una vez de la invocación del guard, pistas de mutación anteriores al guard, y marcadores de bloqueo en los scripts MFA unificado e histórico. A diferencia de `check_mfa_all_legacy_guard_static.py`, no fija el número 16 como inventario cerrado: si aparece una ruta nueva, debe usar al menos el guard conservador `api`.

## Hallazgo de inspección de GitHub

- Hay 16 scripts `deploy_*.sh` en el directorio al momento de la revisión; existen `check_mfa_all_legacy_guard_static.py` y `check_mfa_unified_release_negative.sh`. **No se repiten ni se declaran fallidas sus pruebas anteriores**.
- `mfa_release_entrypoint.sh` bloquea deliberadamente schema-off, mfa-enable y rollback con `OPERATIONAL_AUTHORIZATION_REQUIRED`; además exige rama `integration/local-e2e-prep`, distinta de la rama actual de trabajo. **No ejecutar ni intentar eludir la discrepancia**.
- `mfa_legacy_deploy_guard_readonly.sh` deniega inmediatamente modos api/schema. Modo web efectúa consultas reales de Docker/BD para comprobar esquema 0018: **B17F no llama a este guard**.
- `validate_c_ficha_candidate_integrated.sh` sí crea recursos temporales Docker/PG17, por lo que tampoco es parte del alcance de la auditoría estática.
- La presencia de un marcador de guard en texto no es prueba de orden de ejecución ante toda forma de evaluación dinámica: la auditoría es **defensa complementaria** y requiere revisión humana de hallazgos.

## Ejecución propuesta, solo tras sincronizar checkout

```bash
cd /home/vencira/vencira-localcheck
git status --short
git fetch origin feature/c-ficha-independent-attachments
git pull --ff-only origin feature/c-ficha-independent-attachments
python3 -B scripts/b17f_static_release_guard_audit.py
echo "B17F_AUDIT_EXIT_CODE=$?"
```

No borrar ni versionar `clients/flutter/pubspec.lock`. El script Python no llama a Docker, subprocess, red, PostgreSQL, migraciones, copias ni despliegues. Un código de salida 0 indica solo que **la inspección estática** ha encontrado los marcadores esperados. No demuestra el comportamiento en producción ni autoriza usar rutas legacy. Si falla, inspeccionar los mensajes `B17F_FINDING` y corregir tras confirmar el código real; no relajar controles para que pase.

## Estado de evidencia

```text
B17F_CODE_CREATED=YES
B17F_REAL_REPO_EXECUTION=PENDING
B17F_NEGATIVE_RUNTIME_TESTS=PENDING
B17F_STATIC_AUDIT_VERIFIED_ON_VPS=NO
B17F_RELEASE_AUTHORIZED=NO
B17_OPERATIONAL_RELEASE=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```

## Siguiente tramo B17F

Añadir pruebas negativas autocontenidas usando únicamente fixtures de scripts falsos para verificar detección de guard ausente, duplicado, modo incorrecto y mutación previa; luego ejecutar la auditoría sobre el repositorio real, sin arrancar servicios. Separadamente, ensayar puertas de rollback/recuperación con PG17 y secretos sintéticos únicamente si los recursos se pueden demostrar aislados. Toda evidencia nueva debe asociarse al commit inspeccionado y exit code real.


## 29/10 — Validación estática inicial confirmada por operador; batería negativa preparada

El operador confirmó `git pull --ff-only` hasta `0a38e44`, preservando `?? clients/flutter/pubspec.lock`, y ejecutó `python3 -B scripts/b17f_static_release_guard_audit.py`. Salida: `B17F_LEGACY_INVENTORY=16`, `B17F_STATIC_AUDIT=PASS`, `B17F_AUDIT_EXIT_CODE=0`. Este resultado acredita **solamente la ejecución estática en ese checkout**, no la detección de todos los bypass ni autorización operativa.

Se añadió `scripts/test_b17f_static_release_guard_audit.py` (commit `9fa356ae`), 9 pruebas con scripts sintéticos en `TemporaryDirectory`: baseline, ausencia/duplicado/modo erróneo de guard, mutación/dinámica antes de guard, nueva ruta sin protección, invariante de bloqueo eliminado y ruta esperada ausente. El test no lanza los scripts falsos ni consulta Docker, red, BD, claves o servicios reales. **Pruebas pendientes de ejecución en Ubuntu**.

Comando tras `git pull --ff-only`:

```bash
cd ~/vencira-localcheck
python3 -B -m unittest -v scripts/test_b17f_static_release_guard_audit.py
echo "B17F_NEGATIVE_TEST_EXIT_CODE=$?"
python3 -B scripts/b17f_static_release_guard_audit.py
echo "B17F_STATIC_AUDIT_EXIT_CODE=$?"
```

No considerar B17F cerrado antes de recibir ambos exit code 0 y comprobar que se ejecutaron los 9 tests. No se autoriza desplegar, migrar ni habilitar adjuntos/MFA.


## 29/10/2026 — Cierre de batería estática informado por el operador

El operador ejecutó la suite sintética y el auditor sobre su checkout actualizado e informó: `Ran 9 tests in 0.026s`, `OK`, `B17F_NEGATIVE_TEST_EXIT_CODE=0`, `B17F_LEGACY_INVENTORY=16`, `B17F_STATIC_AUDIT=PASS`, `B17F_STATIC_AUDIT_EXIT_CODE=0`. El resultado acredita las **9 comprobaciones negativas de fixtures y el inventario estático de 16 rutas**. No se ejecutaron por estas herramientas contenedores ni migraciones. No acredita una auditoría de seguridad independiente, gates runtime, custodia ni rollback real.

**Tramo B17F estático: VALIDADO según salida del operador.** Siguiente tramo: evaluación aislada de rutas de rollback, consistencia y recuperación con datos sintéticos, evitando repetir suites ya aprobadas. `B17F_RELEASE_AUTHORIZED=NO`, `C_FICHA_RELEASE_AUTHORIZED=NO`, `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


## B17F2 — revisión de rollback y aislamiento (29/10/2026; pendiente gate)

Se revisaron los scripts reales `scripts/validate_mfa_active_rollback_pg17.sh`, `scripts/rehearse_c_ficha_split_readonly.sh` y el código de transición `backend/renewal_attachments/transition_preflight.py`, `transition_reconciliation.py`. El ensayo MFA exige rama `integration/local-e2e-prep`, por lo que **NO debe ejecutarse desde la rama actual** ni relajarse esa comprobación. El ensayo de adjuntos sí exige la rama actual, pero invoca Docker y PostgreSQL desechables; no se repite en este tramo.

Se añadió `scripts/test_b17f2_rollback_isolation_contracts.py` (commit `358fd2e`) con 5 pruebas Python de lectura de archivos: contratos existentes de scripts, simulación de eliminación de red interna, limpieza ausente y referencia a BD live. **Es una comprobación estática de indicadores**, no prueba dinámica de aislamiento ni respaldo/restauración integral, y no ejecuta scripts ni contenedores. Controles de reconciliación siguen siendo consultivos: no toleran registros históricos sin conciliación y no garantizan consistencia bajo escrituras concurrentes. En particular O5 BD no acredita restauración de objetos/diario/claves.

Ejecución conjunta final (una sola visita al VPS):

```bash
cd ~/vencira-localcheck
git pull --ff-only origin feature/c-ficha-independent-attachments
python3 -B -m unittest -v scripts/test_b17f2_rollback_isolation_contracts.py
echo "B17F2_STATIC_EXIT_CODE=$?"
```

**Pendiente:** resultado real de cinco tests B17F2. No se ha ensayado ni autorizado rollback de producción, migración persistente, claves reales ni adjuntos. `B17F_RELEASE_AUTHORIZED=NO`; `MFA_RELEASE_AUTHORIZED=NO`; `C_FICHA_RELEASE_AUTHORIZED=NO`; `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


## B17F2 — Resultado confirmado por operador (29/10/2026)

Salida aportada: `Ran 5 tests in 0.002s`, `OK`, `B17F2_STATIC_EXIT_CODE=0`. **B17F2_STATIC_TESTS=PASS** (cinco comprobaciones estáticas). No son ensayos de ejecución de rollback, recuperación de archivos ni validación operacional. Se cierra el tramo estático B17F; el siguiente hito material es diseñar y probar recuperación coherente de BD + objetos cifrados + diario con datos sintéticos, y gestionar por separado la custodia externa real. Mantener autorización bloqueada: `B17F_RELEASE_AUTHORIZED=NO`, `C_FICHA_RELEASE_AUTHORIZED=NO`, `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.
