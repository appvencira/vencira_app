> **ACTUALIZACIÓN DE CONTINUIDAD — AUDITORÍA DE RAMAS 08/11/2026:** consultar primero [auditoría y plan de cierre](MAIN_BRANCH_AUDIT_2026-11-08.md) y [registro de integración](MAIN_CONSOLIDATION_2026-11-08.md). Tras el corte original de este handoff se integraron directamente en main I8-L (6/6 Flutter + analyze PASS reportado), desafío lc1 (6/6 unittest PASS), modelos/migración 0005 y núcleo I8-B/C/I/J/K de laboratorio. También se reparó la carga test-only de claves HMAC G5 (`b095531e`). El código backend nuevo y los gates PG17/HTTPS I8-K e I8-M **no tienen PASS sobre main**. Las estadísticas del handoff inferior son históricas y pueden haber cambiado. No hacer merge masivo ni activar servicios. `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

# VENCIRA — CONTINUIDAD MAESTRA PARA NUEVO CHAT

**Fecha de corte: 8 de noviembre de 2026.** Documento publicado en la rama principal `main`. Este archivo es el punto de entrada para reanudar el trabajo. NO equivale a declarar que los cambios de ramas históricas estén fusionados o desplegados.

## 1. Instrucción principal del proyecto

**El objetivo prioritario del usuario es poner `main` por delante y dejar de crear más ramas.** Continuar VENCIRA **directamente sobre `main`**, con cambios pequeños, documentados y verificables. No proponer nuevas ramas de integración como rutina, ni acumular más funciones en `feature/m3-android-local-notifications`. Las ramas existentes son **fuentes históricas de código** a reconciliar, no el nuevo destino.

**No realizar fusiones masivas, force-push, sustituciones completas de árbol ni merges que oculten pérdida de archivos.** La integración debe respetar lo que ya está en `main`; ejecutar en esa base las pruebas antes de declarar un bloque integrado. En caso de conflictos/dependencias, trabajar con una unidad autocontenida y registrar los límites; no inventar un estado PASS.

## 2. Repositorio y estado REAL comprobado en GitHub

- Organización: `appvencira`; repositorio: `appvencira/vencira_app`.
- Rama por defecto: `main`.
- Política principal publicada directamente en `main`: `docs/MAIN_INTEGRATION_POLICY_2026-11-08.md`, commit **`af723da0`**.
- La rama `main` **sí contiene** parte del código base Django/Flutter (por ejemplo `backend/config/settings.py` y `clients/flutter/pubspec.yaml`); sin embargo, el `README.md` de `main` sigue siendo una descripción breve de fase de arranque, por lo que está **desactualizado respecto al trabajo validado en laboratorio**.
- Comparación GitHub realizada el **08/11/2026**, DESPUÉS del cambio documental anterior: `main` vs `feature/m3-android-local-notifications` = **DIVERGED**, `ahead_by=3946`, `behind_by=20`. Los recuentos son una instantánea y cambiarán.
- La PR [#17](https://github.com/appvencira/vencira_app/pull/17) sigue **abierta, borrador, NO mergeable**, `head=feature/m3-android-local-notifications`, `base=feature/mb1-m104-transition-contract-batch`; no apunta a `main`.
- La PR [#18](https://github.com/appvencira/vencira_app/pull/18) apunta a `main`, desde `integration/main-progressive-20261106`, pero en la última consulta tampoco era mergeable.
- Otras PR antiguas y ramas de trabajo pueden existir. **No equivalen a integración en `main`.**
- Documento maestro extenso de la rama histórica: `docs/PROJECT_STATUS.md` en `feature/m3-android-local-notifications` (más de 100 KB). **No se encontró** ese mismo documento en `main` en la última consulta. No describirlo como un archivo ya integrado.
- Último cierre histórico I8-L registrado en esa rama: commit **`f90bf159`**. Los gates I8 cerrados están en ese código histórico, no verificados aún sobre la versión actual de `main`.

## 3. Arquitectura y reglas que deben conservarse

VENCIRA gestiona **vencimientos y anotaciones de seguros**, no es un CRM genérico. Backend Django 5 con PostgreSQL 17; frontend Flutter web/Android; entorno de validación VPS Ubuntu 24.04, Docker/Compose, Caddy HTTPS y dominio DEV `dev.vencira.es`. Verificar rutas/servicios en el repositorio antes de operar, porque `main` y ramas históricas divergen.

Seguridad:
- `MFA_RELEASE_AUTHORIZED=NO`
- `NO_DEPLOY_NO_LIVE_MIGRATION=1`
- NO hacer deploy, NO ejecutar migraciones sobre BD DEV persistente/producción, NO habilitar MFA ni emisor de tokens operativo.
- Los tests de los módulos `native_mobile_service` y recuperación usan PostgreSQL17 **desechable**, identidades y secretos sintéticos, claves temporales y URLconf de laboratorio aislada; **no** desplegarlos por el hecho de integrarlos en GitHub.
- No enlazar accidentalmente vistas test-only en `backend/config/urls.py`, ni un login nativo candidato en `clients/flutter/lib/main.dart`.
- Mantener antifugas: nunca copiar claves privadas, tokens, contraseñas o datos reales a GitHub/logs.
- DEV Docker y datos persistentes deben permanecer intactos. Los gates positivos no son autorización de release.

## 4. Últimos gates reportados por el usuario y validados en su alcance

Los siguientes resultados fueron **aportados directamente por el operador desde VPS**. Distinguir resultado de laboratorio de integración en `main`:

| Bloque | Evidencia / resultado | Alcance |
| --- | --- | --- |
| I8-H | `NATIVE_I8H_ANDROID_REAL_HTTPS_RESULT=0` y marcadores Android MFA/CA/Keystore/Logout PASS | Autenticación MFA sintética HTTPS en **Android físico** con PG17 efímero. El fallo de túnel anterior resultó ser la restricción de batería de Termius. **NO** es recuperación Android física. |
| I8-I | `NATIVE_I8I_PG17_NEGATIVE_POLICY_GATE=PASS`, `NATIVE_I8I_TERMIUS_RESULT=0` | Rechazo seguro de cuentas sin MFA y ausencia de endpoints de recuperación, Flutter mocks. |
| I8-J | `NATIVE_I8J_ATOMIC_RECOVERY_CORE=PASS`, `NATIVE_I8J_PG17_ATOMIC_RECOVERY_GATE=PASS`, `NATIVE_I8J_TERMIUS_RESULT=0`; **29 tests Flutter OK** | Contraseña + TOTP, revocación atómica de anteriores, nueva sesión, rollback/race, solo núcleo candidato PG17. |
| I8-K | `Ran 27 tests ... OK`, `NATIVE_I8K_RECOVERY_JSON_PG17=PASS`, `NATIVE_I8K_REAL_HTTPS_GATE=PASS`, `NATIVE_I8K_TERMIUS_RESULT=0` | Recuperación vía HTTP/HTTPS **desde sonda Python** con CA/hostname comprobados y PG17 efímero, URLconf test-only. |
| I8-L | `00:02 +62: All tests passed!`, `NATIVE_I8L_HTTP_ADAPTER_JOURNAL_GATE=PASS`, `NATIVE_I8L_FLUTTER_GATE=PASS`, `NATIVE_I8L_TERMIUS_RESULT=0` | Flutter: adaptador HTTP + recovery gateway + startup/journal/vault/fence, **MockClient** y secretos sintéticos; no HTTPS Flutter real ni Android físico. |

Todos los gates finales anteriores que incluyeron comprobación de DEV indicaron `*_DEV_CONTAINERS_UNCHANGED=OK` o `*_LIVE_CONTAINERS_UNCHANGED=OK`, `*_DEPLOY_EXECUTED=NO` y `*_LIVE_MIGRATIONS_EXECUTED=NO`.

Hallazgo de seguridad I8-L: antes el cliente podía aceptar tokens directamente tras una respuesta de contraseña de recuperación. Se corrigió en `clients/flutter/lib/api/native_http_auth_port.dart` (**`ff3a5019`**) y `native_recovery_login_gateway.dart` (**`d87480a8`**); se exige **MFA nuevo para recuperar**, también ante adaptador hostil. Los tests correspondientes quedaron validados en el gate I8-L. No revertirlo.

## 5. Código / scripts históricos de referencia (NO asumir ya integrados en main)

En `feature/m3-android-local-notifications`:
- `backend/native_mobile_service/candidate_two_step_issuer.py`
- `backend/native_mobile_service/candidate_recovery_issuer.py`
- `backend/native_mobile_service/test_i8i_non_mfa_recovery_policy_pg17.py`
- `backend/native_mobile_service/test_i8j_recovery_pg17.py`
- `backend/native_mobile_service/test_i8k_recovery_views.py`, `test_i8k_recovery_urls.py`, `test_i8k_recovery_http_pg17.py`
- `clients/flutter/lib/api/native_http_auth_port.dart`
- `clients/flutter/lib/api/native_recovery_login_gateway.dart`
- `clients/flutter/lib/api/native_mobile_recovery_entry.dart`, `native_mobile_startup_gate.dart`, `native_refresh_recovery_journal.dart`, `native_refresh_credential_vault.dart`
- `clients/flutter/test/native_i8l_http_recovery_integration_test.dart`
- `scripts/native_i8j_atomic_recovery_pg17_isolated.sh`
- `scripts/native_i8k_real_https_pg17_isolated.sh`
- `scripts/native_i8l_flutter_recovery_adapter_gate.sh`
- `docs/I8J_ATOMIC_RECOVERY_PG17.md`
- `docs/I8K_RECOVERY_HTTP_HTTPS_PG17.md`
- `docs/I8L_FLUTTER_RECOVERY_ADAPTER_GATE.md`
- `docs/PROJECT_STATUS.md` (histórico completo).

## 6. Pendientes reales y orden de actuación del NUEVO CHAT

**Prioridad 1 — poner `main` por delante, sin más ramas.**
1. Recuperar este documento desde `main`, leer la política `docs/MAIN_INTEGRATION_POLICY_2026-11-08.md`, consultar el estado actual del repositorio y comparar `main` con las ramas históricas.
2. Auditar qué archivos, features, pruebas y migraciones existen de verdad en `main`; no interpretar divergencia de commits como ausencia absoluta de código (algunas funcionalidades pueden haber entrado vía PR independientes).
3. Elegir primer lote funcional autocontenido que no active producción, integrarlo **directamente en `main`** sin crear ramas y respetando hotfixes propios de `main`. Hacer revisión de dependencias y pasar gates en esa revisión.
4. Actualizar `README.md` y documentación de estado **en `main`** de forma que no digan falsamente que la app no ha avanzado. Diferenciar desarrollo validado, integración GitHub y despliegue real.
5. Repetir por lotes revisables. No marcar `main` consolidada hasta confirmar módulos, pruebas y configuraciones; no usar un merge forzado ni overwrite masivo.

**Prioridad 2 — I8-M:** Flutter por HTTPS realmente verificado frente al backend recovery I8-K en PG17 efímero, CA confiable solo de laboratorio, sin fallback TLS. Comprobar éxito completo y errores ambiguos/recuperación. **No existe PASS I8-M** hasta nueva evidencia.

**Prioridad 3 — Android físico:** recuperación completa con storage/Keystore real, túnel Termius `127.0.0.1:18743` y sin restricciones de batería de Termius; la ruta de certificados temporales debe mantener validación CA+hostname. No confundir con PASS de I8-H que fue **login inicial**, no recuperación.

**Prioridad 4 — APK funcional, pruebas visuales, auditoría y gate de publicación.** Autenticación sin MFA requiere una **política de seguridad explícita**: I8-I solo validó rechazo seguro; NO es una función implementada.

## 7. Forma de trabajo esperada

- Idioma español, respuestas técnicas, críticas y verificables. **No inventar PASS, porcentajes, comandos, rutas ni estado de GitHub.**
- El usuario prefiere fases grandes y continuidad sin pedir permiso en cada paso; cuando sea indispensable un gate local, suministrar un bloque de comandos listo para Termius y los marcadores esperados basados en scripts reales.
- Documentar avances y resultados **en GitHub, rama `main`**.
- Distinguir claramente “código preparado/publicado”, “gate ejecutado y PASS”, “integrado en main” y “desplegado”. No son sinónimos.
- Una herramienta que pueda editar GitHub no implica autorización para desplegar VPS. No inventar acceso SSH a VPS.
- Si un merge/direct update sobre `main` resulta inseguro o conflictivo, detener ese lote, explicar el bloqueo y continuar con documentación, pruebas o un lote seguro sin crear nuevas ramas.

## 8. Prompt breve para empezar nuevo chat

> Continuamos VENCIRA. Lee primero `docs/CONTINUITY_HANDOFF_2026-11-08.md` y `docs/MAIN_INTEGRATION_POLICY_2026-11-08.md` desde la rama **main** del repositorio `appvencira/vencira_app`. La instrucción más reciente es **poner main al día sin crear más ramas**. Los gates I8-H a I8-L tienen PASS en sus alcances históricos, pero main ha divergido y NO contiene necesariamente todo. Verifica estado real y prioriza integración directa en main por bloques autocontenidos, sin perder los cambios propios de main; documenta cada paso. NO deploy ni migración viva, `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`. Después continuar I8-M Flutter HTTPS recovery, Android físico, APK funcional y revisión visual. No afirmes validaciones no ejecutadas.
