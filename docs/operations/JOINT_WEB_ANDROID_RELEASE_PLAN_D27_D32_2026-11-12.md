# VENCIRA — Lanzamiento conjunto web + Android (opción B), D27–D32

**Decisión del operador (12/11/2026):** opción B. El objetivo final es **un solo lanzamiento coordinado** de web pública y Android nativo. No desplegar solo la web; no publicar APK ni habilitar la autenticación nativa antes de cumplir todos los gates.

**Rama única:** `main`, sin ramas adicionales. **Estado:** PLAN DE EJECUCIÓN Y PREFLIGHT READ-ONLY PUBLICADOS; no es autorización ni ejecución de release.

## Lo que está probado y lo que no

- D26: el operador confirmó `D26_RESULT=0`, `D26_FLUTTER_TEST_PROCESS=PASS`, `D26_FLUTTER_TEST_OUTPUT=PASS`, `D26_CURSOR_REAL_TLS_FLUTTER=PASS`; PG17 + Flutter TLS real en laboratorios internos. **No equivalen a endpoints operativos desplegados**.
- D16: APK **debug** de `lib/main.dart` construido, NO firmado/distribuido como release; la prueba física del APK definitivo está pendiente.
- D17-B: `NativeAndroidStartupBoundary` incorporado al arranque real. El login nativo sigue sin enrutarse desde `main.dart`; la salida normal conserva el acceso web externo.
- D20: `native_operational_issuer_gate.py` **niega incondicionalmente** emisión operacional, incluso con flags de readiness forzados. Es una barrera deliberada, no un emisor que deba habilitarse con una variable.
- D25/D26: servidor y URLconf de laboratorio `test_d22_urls` seleccionados solo por flags de laboratorio y red Docker interna. Prohibido registrar esas vistas en `config.urls` de producción.
- Backups O5/ensayos de recuperación previos están documentados; la publicación requiere un **ensayo de recuperación y rollback actualizado al artefacto concreto de release**.

## Macrogrupo 1 — D27–D28: emisor operativo + Flutter/Android integrado

**D27 — Autenticación de servidor realmente operativa, separada de LAB**
1. Inventariar límites entre `candidate_two_step_issuer`, `native_server_custody_issuer`, pruebas `test_*` y Django productivo. Definir URLconf/protocolo **nuevo** bajo revisión de seguridad, sin reutilizar controles de laboratorio como habilitadores de release.
2. Implementar custodia real de secretos externos al repositorio e imágenes; emisión de acceso y refresh, expiración, rotación, recuperación MFA, revocación global, auditoría antiabuso e idempotencia con transacciones/locks PG17.
3. Probar denegación por omisión de clave, MFA inactivo/ambiguo, replay, cookies/CSRF mal usados, cambios de workspace, recovery y rollback. Mantener `MFA_RELEASE_AUTHORIZED=NO` durante esta construcción.
4. Gate D27 de pruebas de seguridad autónomo con evidencias auditables. **No** eliminar `assert_operational_issuer_unavailable` sin una implementación alternativa revisada y autorización explícita.

**D28 — Android nativo real**
1. Conectar `main.dart` → login MFA nativo, vault Keystore, journal duradero, lectura de renovaciones y cursor firmado. Mantener inicio fail-closed y aislamiento por entorno.
2. Demostrar logout, token expirado/revocado, recuperación tras reinicio, pérdida de red, falla del almacén y cambio de cuenta.
3. Probar Flutter `analyze`, unit/widget, integración HTTPS de red interna y APK debug de la entrada `main.dart`; no distribuir todavía.

**Cierre macrogrupo 1:** emisor no-lab implementado pero no activado públicamente, Android navega las funcionalidades con credenciales sintéticas de staging, seguridad regresiva PASS.

## Macrogrupo 2 — D29–D30: aceptación física + preproducción de web/infra

**D29 — Dispositivo Android físico y pruebas de fallos**
- APK candidato de `main.dart` en teléfono real sobre **staging privado**: HTTPS/CAs, hostname/SNI, Keystore, política de permisos, reinicio, logout, cuenta revocada, pérdida/restablecimiento de conexión, MFA, caducidad y recovery.
- Evidencia de recorrido funcional web y Android equivalentes, incluyendo renovaciones y roles.
- Revisar accesibilidad y pantalla compacta sin overflows.

**D30 — Preparación conjunta de infraestructura**
- Verificar DNS apex `vencira.es` vs `dev.vencira.es`, origen y proxy Caddy, cookies, CSRF, Allowed Hosts, headers y TLS definitivo.
- Baseline real de Postgres, snapshots restic/O5 y prueba de restauración aislada, plan de migraciones y reversión sin perder datos.
- Inventario real de variables/secretos fuera de GitHub, seguridad de imágenes, observabilidad, healthchecks, límites/alertas, términos/privacidad y restauración.
- Gate de ensayo en staging y plan de rollback *probado*. No migrar ni restaurar datos LIVE durante la preparación.

**Cierre macrogrupo 2:** checks web/API y Android físicos PASS contra el mismo candidato de release, más DR/rollback sobre copia aislada.

## Macrogrupo 3 — D31–D32: artefactos y publicación conjunta

**D31 — Release candidates reproducibles**
- Web Flutter production build y backend Django versión fijada a hash `main`.
- Android APK/AAB **release** con firma en Keystore externo, verificación de firma/identidad de aplicación, versión, integridad y prueba de instalación/reinstalación. No publicar el keystore ni credenciales.
- Evidencias de reproducibilidad, SBOM/dependencias y trazabilidad por SHA de commit/imagen/artefacto.

**D32 — Aprobación y ejecución controlada**
- Paquete de evidencias reunido, plan operativo y rollback con condiciones objetivas.
- Requiere **autorización explícita separada del usuario**, revisión de seguridad del emisor operativo, ventana de despliegue y estrategia de publicación web y Android coordinada.
- Solo **después** de la autorización, migración live/deploy mediante scripts específicos con comprobación de entorno, backup inmediatamente anterior y reversiones ensayadas.
- Pruebas posteriores de aceptación y revocación; si fallan, detener rollout y seguir rollback.

## Orden de ejecución acelerado sin repetir trabajo

Trabajar en `main` con **un solo gate de laboratorio por macrogrupo**, reutilizando I8-K/D26 para PG17 y TLS, I8-P/G13 para pruebas de Keystore, D16/D17B para Flutter, y O5 para DR. No ejecutar D16–D26 íntegros en cada pequeño commit: solo la regresión concreta y un gate final por macrogrupo; evitar falsos PASS exigiendo salida `All tests passed!` y código de salida cero.

La integración Android y el issuer son **trabajos pendientes de implementación**, no gates que se puedan dar por superados con documentación.

## Gate read-only de inventario de bloqueos — YA PUBLICADO

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
bash -n scripts/main_joint_web_android_release_readiness_readonly.sh
bash scripts/main_joint_web_android_release_readiness_readonly.sh
echo "JOINT_B_PREFLIGHT_EXIT=$?"
git status --short
```

Salida que se espera **solo tras verificarla en VPS**: `JOINT_B_MAIN_CLEAN=PASS`, `JOINT_B_PRODUCTION_AUTH_HARD_FENCE=PASS`, `JOINT_B_REAL_NATIVE_LOGIN_IN_MAIN=NO`, `JOINT_B_OPERATIONAL_ISSUER_READY=NO`, `JOINT_B_PRODUCTION_MOBILE_ROUTES=NO`, `JOINT_B_JOINT_RELEASE_AUTHORIZED=NO`, `JOINT_B_READ_ONLY_PREFLIGHT=PASS`, `JOINT_B_RESULT=0`.

**`JOINT_B_RESULT=0` significa que el inventario de bloqueos se ha ejecutado correctamente y el release permanece bloqueado. Nunca equivale a RELEASE PASS.** Se debe conservar una separación inequívoca entre resultados de diagnóstico y autorización operativa.

Guardas vigentes: `MFA_RELEASE_AUTHORIZED=NO`; `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## Primer preflight VPS — PASS de inventario, no de release (12/11/2026)

El operador ejecutó `scripts/main_joint_web_android_release_readiness_readonly.sh` contra `main` sincronizada y limpia, y comunicó los marcadores:

```text
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
JOINT_B_DEPLOY_EXECUTED=NO
JOINT_B_LIVE_MIGRATIONS_EXECUTED=NO
JOINT_B_LIVE_RESTORE_EXECUTED=NO
JOINT_B_ANDROID_SIGNED=NO
JOINT_B_OPERATIONAL_ISSUER_ENABLED=NO
JOINT_B_MAIN_CLEAN=PASS
JOINT_B_SOURCE_INVENTORY=PASS
JOINT_B_PRODUCTION_AUTH_HARD_FENCE=PASS
JOINT_B_REAL_NATIVE_LOGIN_IN_MAIN=NO
JOINT_B_OPERATIONAL_ISSUER_READY=NO
JOINT_B_PRODUCTION_MOBILE_ROUTES=NO
JOINT_B_RELEASE_BLOCKERS_VERIFIED=PASS
JOINT_B_JOINT_RELEASE_AUTHORIZED=NO
JOINT_B_READ_ONLY_PREFLIGHT=PASS
JOINT_B_RESULT=0
JOINT_B_PREFLIGHT_EXIT=0
```

`git status --short` no reportó cambios. **Preflight read-only PASS, publicación web+Android NO autorizada.** D27–D32 continúan pendientes de implementación/validación. No repetir este inventario salvo cambio de las barreras examinadas.

**Siguiente ejecución sustantiva:** D27–D28, emisor operacional nuevo e integración Android con autenticación no-lab, sin reutilizar `test_d22_urls` ni desbloquear las barreras de release. El alcance de D27 deberá verificarse en un laboratorio con claves sintéticas y sin rutas públicas; D28 debe conservar fail-closed.
