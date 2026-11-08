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
