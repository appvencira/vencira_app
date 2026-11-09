# VENCIRA — Plan consolidado de cierre tras I8-Q

**Fecha:** 08/11/2026. **Integración:** `main` exclusivamente. **Estado:** planificación; no autoriza despliegues.

## Evidencias ya superadas en main (sin extrapolar a producción)

| Prueba | Evidencia |
| --- | --- |
| I8-M Flutter ↔ Django HTTPS real, CA/hostname, recuperación MFA y revocación en PG17 temporal | `MAIN_I8M_FLUTTER_TLS_RECOVERY_GATE=PASS`, `MAIN_I8M_FLUTTER_TLS_BOUNDARY_RESULT=0` |
| I8-N Keystore físico, marcador, fence, borrado y persistencia tras reinicio confirmado | Capturas `I8N_ANDROID_KEYSTORE_SEED=PASS`, `I8N_ANDROID_RESTART_RECOVERY_FENCED=PASS`, `I8N_ANDROID_KEYSTORE_CLEANUP=PASS` + reinicio confirmado por operador |
| I8-O Keystore físico con inyección de fallos en escritura, borrado y fence | Captura de 5/5 PASS |
| I8-P Android físico ↔ Django HTTPS por SSH + MFA sintético + Keystore + revocación | Captura de 5/5 PASS, `I8P_PG17_OLD_AND_NEW_SESSION_REVOKED=PASS`, `I8P_LAB_RESULT=0`, DEV intacto |
| I8-Q matriz conjunta de respuesta perdida, MFA ambiguo y almacenamiento/revocación fallidos | `00:01 +30: All tests passed!`, `I8Q_FLUTTER_FAULT_MATRIX_GATE=PASS`, `I8Q_LOCAL_RESULT=0` |

Estos gates prueban **componentes y laboratorios aislados**, no el acceso normal a la aplicación, una distribución móvil autorizada ni que el esquema DEV sea compatible.

## Cuatro bloques grandes restantes

### B1 — I8-R: resiliencia móvil bajo interrupción real y controlada

**Objetivo:** distinguir tres desenlaces sobre un backend temporal, sin tocar el operativo: antes de enviar solicitud, después de un commit MFA antes de entregar respuesta, y fallo de escritura/borrado protegido tras recepción de tokens.

**Trabajo:** introducir fallos controlados y reproducibles en el relay HTTPS de laboratorio, nunca en el servicio DEV; evidenciar con PG17 efímero si hubo emisión y revocación; comprobar que Android no reintenta una MFA de uso único, mantiene marcador/fence ante ambigüedad, y exige recuperación segura. Extender, sin duplicar, I8-P/I8-Q. Probar cancelación y limpieza con el teléfono por SSH. No registrar secretos.

**Cierre:** resultados Android, trazas mínimas del relay/PG17, gate 0, DEV intacto, desmontaje sin residuos; diferencia explícita entre respuesta perdida y emisión efectuada.

### B2 — Integración funcional de la APK y revisión de interfaz

**Objetivo:** dejar de usar pantallas de laboratorio como sustituto de la aplicación funcional. Integrar el login/recuperación nativos **solo cuando la política de emisión y claves operativas se autorice**; no habilitar rutas test-only desde `backend/config/urls.py` ni conectar `main.dart` prematuramente.

**Trabajo:** verificar los flujos reales del dominio (clientes/candidatos, modalidades, vencimientos, ficha, notas, adjuntos cuando estén listos, calendario, recordatorios, logout y alarmas); pruebas de navegación y visualización móvil de la APK, gestión de sesiones y UX accesible. Revisar las capacidades Android y web por separado. Los componentes que aún dependan de desarrollo adicional se inventariarán en una matriz de aceptación.

**Cierre:** smoke funcional completo, Flutter analyze/test/build, pruebas Android físicas con cuentas de ensayo autorizadas, pantallas revisadas y sin regresiones. La APK funcional no es necesariamente una APK de producción.

### B3 — D1: backup, esquema y recuperación operacional

**Hechos:** último inventario D1-A: DEV sano; 42 archivos de migración locales, 36 migraciones registradas en DEV (incluye apps core), **24 nombres de migración del checkout main no aplicados**: nueve `reminders.0019–0027`, cinco `native_mobile_service`, cuatro `native_sessions_lab`, seis `renewal_attachments`. Los 15 de apps lab son test-only y no pertenecen al grafo operativo. `D1_APPLIED_NOT_IN_MAIN_COUNT=0`.

**Trabajo:** ejecutar inventario D1-B1 de metadatos Compose/O5 si no hay resultado; verificar disponibilidad de un snapshot actual y restaurarlo realmente a PG17 temporal. Ensayar `migrate --plan`, migraciones `reminders.0019–0027`, consistencia de datos/índices, rollback y restauración. Comprobar compatibilidad de imagen/Compose del DEV sin cambiar contenedores persistentes.

**Cierre:** restauración reproducible PASS, ensayo de migraciones y rollback PASS, revisión del grafo de apps instaladas, estrategia de despliegue sin pérdida de datos. No migrar laboratorio en DEV.

### B4 — Autorización, despliegue escalonado y validación real

**Trabajo:** fijar contrato operativo de MFA/emisión/rotación, custodia de claves de servicio, permisos, HTTPS de producción, logging y errores; regresión integral backend/web/Flutter; checklist y estrategia de rollback; despliegue controlado **solo en DEV** tras superar B2/B3 y las autorizaciones de seguridad. Validar health/ready, login, datos, tareas y backups. Producción requiere decisión aparte.

**Cierre:** autorización explícita del release, checklist reproducible y postchecks PASS. La existencia de tests de laboratorio no justifica alterar `MFA_RELEASE_AUTHORIZED`.

## Orden para acelerar sin comprometer seguridad

1. **En paralelo:** B1 (resiliencia) y diagnóstico de B2 (inventario funcional), mientras B3 comienza por metadatos Compose, backup y esquema. Ninguno toca DEV.
2. Consolidar B1/B2/B3 en una sola revisión de integración.
3. B4 solo cuando haya evidencias suficientes para la versión concreta y riesgo residual aceptable; no hay fecha comprometida.

Evitar un porcentaje de avance global: no existe una medición ponderada y auditable del trabajo funcional, documental y de lanzamiento. Los PASS de seguridad miden gates concretos, no porcentaje de producto.

## Restricciones obligatorias

```text
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```

**Prohibido por ahora:** deploy, live migration, autorización automática de emisión/recovery real en DEV, reusar certificados efímeros de los labs o presentar simulaciones como fallos reales. Continuar integrando directamente en `main` y registrar cada resultado con SHA del ensayo.

**Fuentes internas:** `docs/MAIN_BRANCH_AUDIT_2026-11-08.md`, `docs/D1_DEV_DEPLOY_PREPARATION_2026-11-08.md`, `docs/I8P_ANDROID_HTTPS_KEYSTORE_SSH_LAB_2026-11-08.md`, `docs/I8Q_NATIVE_RECOVERY_FAULT_MATRIX_2026-11-08.md`.

## Ejecución acelerada — lote de inventario B2+B3 (08/11/2026)

**Hallazgo en código, no deducción:** `clients/flutter/lib/main.dart` dirige la APK Android normal a `AndroidWebAccessScreen` y `clients/flutter/lib/ui/android_web_access_screen.dart` utiliza `LaunchMode.externalApplication` para abrir `https://dev.vencira.es/` en el navegador. La autenticación y recuperación nativas I8-M–I8-Q se han demostrado **solo en laboratorios Android separados**, no están integradas en el arranque operativo. Esta diferencia se convierte en bloqueo de aceptación de B2, no en un FAIL de la seguridad ya ensayada.

**Preflight añadido directamente en main:**
- `scripts/main_closure_source_inventory_readonly.py` (`725a3bbb`) recorre archivos Flutter esenciales sin ejecutar la app; marca pantallas presentes como `SOURCE_PRESENT_NOT_VISUALLY_TESTED` y verifica que la entrada Android normal siga aislada, que `backend/config/urls.py` no publique endpoints móviles candidatos y que el bearer siga desactivado. Identifica por AST las nueve migraciones `reminders.0019–0027` y las dependencias estáticas. **No interpreta presencia de fuente como funcionalidad probada, no usa DB ni Docker**.
- `scripts/main_closure_grouped_readonly_gate.sh` (`2c0bf8e6`) ejecuta en una sola invocación ese inventario y `scripts/d1b_dev_compose_o5_metadata_readonly.py` para obtener metadatos del Compose operativo y estados systemd O5. **No consulta secretos, no verifica backups, no restaura ni ejecuta migraciones.**

**Operación única en Termius:**
```bash
cd ~/vencira-main-check-20261108
git fetch origin main
git merge --ff-only FETCH_HEAD
bash -n scripts/main_closure_grouped_readonly_gate.sh
set -o pipefail
bash scripts/main_closure_grouped_readonly_gate.sh 2>&1 | tee ~/vencira-closure-readonly.log
echo "CLOSE_COMBINED_SHELL_RESULT=${PIPESTATUS[0]}"
```

**Criterio:** `CLOSE_DJANGO_OPERATIONAL_NATIVE_ROUTE_FENCE=PASS`, `CLOSE_ANDROID_NORMAL_ENTRY=EXTERNAL_BROWSER_ONLY`, `CLOSE_REMINDERS_0019_0027_FILES=9`, `D1B_COMPOSE_PROJECT=vencira_localcheck`, `CLOSE_COMBINED_PREFLIGHT=PASS`, `CLOSE_COMBINED_SHELL_RESULT=0`. Si el informe señala un hallazgo de compatibilidad o un temporizador inactivo, **no se modifica DEV para que el gate pase**: investigar la causa y diseñar un ensayo aislado.

**Importante:** este preflight no certifica que los backups O5 sean restaurables ni que `reminders.0019–0027` puedan migrarse. Los gates de restore y rollback siguen pendientes y requieren un ensayo de PG17 aislado. I8-R de pérdida controlada de respuestas HTTPS Android permanece pendiente; no se finge completado por esta publicación. Las 15 migraciones de aplicaciones lab siguen excluidas de DEV.

## Lote D1-E superado + D1-F preparado (09/11/2026)

**Evidencia del operador, SHA `c486d2e0`:** los dos timers reales `vencira-o5-backup.timer` y `vencira-o5-health.timer` están `loaded/active/enabled`, con última activación y próxima ejecución presentes. Las correspondientes unidades `.service` están `loaded`, `Result=success` y `ExecMainStatus=0`. `D1E_ACTIVE_TIMERS=2/2`, `D1E_RESULT=0`, `CLOSE_SHELL_RESULT=0`. El falso negativo de D1B/D1C se debió a la omisión del prefijo `vencira-`.

**Estado limitado:** planificador verificado por metadatos; no hay comprobación nueva de snapshots, retención ni restauración Restic. La última ejecución exitosa de `systemd` no garantiza que el snapshot que se necesita para migrar DEV sea reciente o restaurable.

Para acelerar B3 sin exponer secretos se integraron:
- `scripts/d1f_o5_service_topology_readonly.py` (commit `8b49bfb5`): inspecciona solo los archivos de unidades `vencira-o5-backup.service` y `vencira-o5-health.service`, registra únicamente nombres **filtrados** de scripts auxiliares y presencia/cantidad de directivas `ExecStart`, `EnvironmentFile` y `Environment`. No lee el contenido de envfiles, no imprime argumentos, rutas absolutas, contraseñas, configuración de repositorio Restic o secretos; no ejecuta ni activa el backup.
- `scripts/main_closure_grouped_readonly_gate.sh` (commit `ae31d854`): integra D1-F al diagnóstico combinado ya validado de seguridad/rutas, inventario funcional, esquema y estados O5.

**Validación pendiente:** `CLOSE_D1F_O5_SERVICE_TOPOLOGY=PASS` y `D1F_RESULT=0`. El preflight **no certifica** backup. Si los helpers no se reconocen por ser shell envolvente, ruta dinámica o una unidad drop-in, se debe revisar el procedimiento del VPS sin publicar el contenido sensible, no inventar un comando Restic.

Ejecutar en Termius:
```bash
cd ~/vencira-main-check-20261108
git fetch origin main
git merge --ff-only FETCH_HEAD
python3 -m py_compile scripts/d1f_o5_service_topology_readonly.py
python3 scripts/d1f_o5_service_topology_readonly.py
echo "D1F_SHELL_RESULT=$?"
```

**Próximos cierres agrupados:** (i) localizar y validar snapshot O5/Restic de solo lectura, (ii) restauración en PG17 temporal y `reminders.0019–0027` sobre clon con rollback, (iii) I8-R interrupciones de red HTTPS móvil y (iv) APK funcional/autenticación operativa, sin desplegar hasta autorización específica. Evitar repetir los gates ya acreditados salvo regresión de código relevante.
