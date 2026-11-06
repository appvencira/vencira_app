# VENCIRA — Traspaso para el siguiente chat, 06/11/2026
**Estado fiable y operativo.** Esta nota es el punto de partida vigente; las anotaciones cronológicas anteriores en otros documentos son historia y pueden contener estados "pendiente" que fueron cerrados después. No se ha autorizado despliegue.

## Repositorio y modo de trabajo
- GitHub: `appvencira/vencira_app`. Rama `feature/m3-android-local-notifications`; PR #17 DRAFT. VPS Ubuntu 24.04, checkout `~/vencira-m3-localcheck`.
- Tras la aceptación G15 se actualizaron documentos: último commit previo a este traspaso `7202efadf1a8568eb147182c5f8c10f89f131a53`. **El SHA del HEAD de pruebas G15 no se aportó junto a su salida**, no atribuirle uno por deducción. Consultar `git rev-parse HEAD` en VPS antes de cualquier gate futuro.
- Preferencias de desarrollo: bloques grandes agrupados, cambios en GitHub y una sola validación local cuando sea necesaria. No repetir pruebas ya superadas sin cambios relevantes. Mantener estrictamente `MFA_RELEASE_AUTHORIZED=NO`, `MB1_RELEASE_AUTHORIZED=NO`, `C_FICHA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`. Sin merge, despliegue ni migraciones persistentes.

## Validación cerrada en esta conversación
1. **B2-A, firmado Android (alcance estático):** `B2_A_HEAD=b4065dd8d`; 4 tests Python, N1 y diff PASS. `release` ya no usa `signingConfigs.debug`; exige keystore y cuatro variables de entorno externas. **No hay una APK/AAB release firmada ni gate real de distribución.**
2. **B2-B arranque Android (alcance dirigido):** `device_notice_startup_gate_test.dart` 10/10 PASS; guard N1 `android_beta_b2b_startup_recovery_regressions=OK`; cancelación de avisos anteriores precede al acceso inicial. No convierte el acceso web existente en login nativo.
3. **B2-C transporte:** `native_api_transport_test.dart` 13/13 PASS, `B2_C_FLUTTER=0`, incluyendo pérdida de red sin refresh especulativo y no resurrección de sesión tras logout. Auditor estático de permisos `scripts/android_beta_notification_readiness.py`: 2/2 tests PASS, `B2_C_AUDIT_RESULT=0`. No es prueba de permisos físicos operativos de la app principal. Intento de publicar regresiones adicionales en `device_notice_transaction_test.dart` bloqueado por controles del conector: no se publicó, no se eludió el bloqueo.
4. **B2-D manifiesto G13:** `B2_D_PACKAGE=es.vencira.vencira.g13lab`, `POST_NOTIFICATIONS=DECLARED`, sin permiso BOOT ni receivers ni permisos de alarmas exactas; `B2_D_MANIFEST_AUDIT=PASS_READONLY`. El permiso llegó al manifiesto fusionado vía plugin; G13 sigue siendo laboratorio HTTPS, no laboratorio de notificaciones.
5. **B2-E/G15, laboratorio Android SIN Internet:** Código aislado: `clients/flutter/lib/g15_lab_main.dart`, `clients/flutter/lib/g15_lab/physical_notice_checks.dart`, manifiesto `clients/flutter/android/app/src/g15lab/AndroidManifest.xml`, variante debug `.g15lab` en Gradle, `scripts/g15_phone_apk_build.sh`, `scripts/g15_apk_manifest_gate.py`, `scripts/test_g15_lab_boundary.py`, workflow `.github/workflows/g15-android-notifications-lab.yml`, control N1. La primera ejecución de build falló porque N1 esperaba tres labs; se corrigió guard sin reducir cobertura. La segunda falló por fixture de test con receiver abreviado; se corrigió sin relajar gate. **Resultado posterior:** `Ran 4 tests ... OK`, `G15_UNIT_TESTS=0`, `N1_STATIC_GATE_RESULT=OK`, `G15_BUILD_RESULT=0`, `G15_APK_PACKAGE=es.vencira.vencira.g15lab`, `G15_POST_NOTIFICATIONS_DECLARED=OK`, `G15_BOOT_RECEIVER_DECLARED=OK`, `G15_SCHEDULE_RECEIVER_DECLARED=OK`, `G15_EXACT_ALARM_PERMISSIONS=ABSENT`, `G15_INTERNET_PERMISSION=ABSENT`, `G15_MANIFEST_GATE=PASS`, `G15_ANDROID_APK_BUILD=OK`. APK en `clients/flutter/build/g15-phone/VENCIRA-G15-LAB-debug.apk` + SHA256.
6. **G15 Android físico:** El usuario aportó 8 capturas del teléfono: se ve permiso concedido y retirado, `G15_SCHEDULE_GATE=OPEN/LOCKED` según permiso, `G15_SYNTHETIC_INEXACT_SCHEDULE=OK`, `G15_PENDING_SYNTHETIC=YES`, y notificación real del sistema Android `VENCIRA · prueba G15` / `Aviso sintético. No contiene datos reales.`. Posteriormente confirmó explícitamente que **cancelar efectivamente funcionó y una notificación se entregó después de reiniciar completamente el teléfono**. **G15_BUILD_STATIC=PASS_LOCAL; G15_PHYSICAL_MANUAL=PASS_OPERATOR_CONFIRMED; G15_LAB=COMPLETE_WITH_SCOPE_LIMITS.** La declaración del usuario sobre cancelación/reinicio es evidencia manual, sin log ADB independiente. No se probaron múltiples modelos/OEM ni SLA de puntualidad. La notificación es `inexactAllowWhileIdle` y no garantiza hora exacta. No repetir este ensayo sin cambio justificado.

## Límites: qué NO está completado
- **Bloqueante principal G14-E2: NO IMPLEMENTADO.** No existe composición segura y autorizada de contraseña + MFA TOTP/recovery + emisión de tokens + auditoría dentro de transacción confiable, con locks/identidad no transferible. G14-E1/E1D3 prueba verificador de MFA, pero solo devuelve booleano; no se debe conectar directamente al emisor de laboratorio que recibe afirmaciones no confiables. Los intentos anteriores de publicar integración MFA fueron bloqueados por controles del conector: no buscar vías para eludirlos. E3 concurrencia/rotación/fallos y revisión independiente siguen pendientes.
- **Beta privada funcional = NO GO.** `main.dart` Android operacional todavía ofrece acceso web externo bajo barrera de limpieza, no login nativo completo. Integración de avisos con sesión real, workspace, API, inventario cifrado y revocación end-to-end no autorizada. G15 **no** valida eso. No hay APK/AAB firmada para distribución ni UAT completa del producto real.
- No asumir que pruebas de laboratorio activan MFA real, exponen rutas candidatas, despliegan DEV, autorizan migraciones o modifican base persistente.
- No ejecutar de nuevo G13 ni G15 por rutina; ambos acreditan solo laboratorios aislados.

## Próximo bloque recomendable
**Priorizar B1/G14-E2 y E3 de forma segura y revisada**, no otro laboratorio de avisos. Antes de integrar credenciales reales, revisar el contrato `docs/G14_E2_ATOMIC_ISSUANCE_ACCEPTANCE_2026-11-06.md`, el checklist `docs/G14_PROGRESS_CHECKLIST_2026-11-05.md`, la barrera `scripts/g14_trusted_issuer_boundary.py` y los tests E1 existentes. Respetar bloqueos de herramientas. Si E2 no puede publicarse mediante el conector, registrar el bloqueo y avanzar solo en tareas independientes de bajo riesgo (UX Android, contratos fuente, pruebas desconectadas); nunca simular una autorización. Una vez E2 autorizado y auditado, agrupar G14-E3/G4/G5 en un gate PG17 temporal+N1+CI, seguido de integración Android real y evaluación B3 operativa.

## Documentación y precauciones
- `docs/PROJECT_STATUS.md`: cabecera principal; contiene datos cronológicos históricos con frases desactualizadas más abajo (p. ej. uso de firma debug en release). Ante conflicto prevalece esta nota y la sección más reciente.
- `docs/ANDROID_BETA_CRITICAL_PATH_2026-11-06.md`: historial detallado B1/B2/B3 y ensayos B2-A…G15; los puntos anteriores son cronología, no estado actual.
- `docs/NEXT_CHAT_HANDOFF_SHORT.md`: traspaso histórico largo; hay cabeceras antiguas contradictorias, leer siempre primero esta nota.
- Mantener custodia Fernet, OAuth/restic O5, no publicar secretos, no variar despliegue/PG17 persistente y no declarar beta GO sin revisión humana.

## Primera acción en el próximo chat
Leer este traspaso y documentos G14-E2. Evaluar con precisión la frontera de seguridad del issuer y proponer un bloque grande **que sea implementable sin pasar por alto restricciones**. Solicitar pruebas locales solo si se introducen cambios y suministrar un único comando reproducible; no pedir de nuevo las evidencias G15.

## Continuación G14-E2/E3 en el siguiente chat (06/11/2026)

Se revisaron de nuevo fuentes de `g14_e1_locked_mfa_verifier.py`, `session_store.py` y `g14_trusted_issuer_boundary.py` y se publicó el análisis agrupado **`docs/G14_E2_E3_GROUPED_SECURITY_REVIEW_2026-11-06.md`**, commit `c3b6373e2cefd62ed8c9a334424be6a7e618c967`. Contiene contrato de transacción, riesgos, matriz de carreras, gates y orden de revisión.

**Sin cambios de runtime ni pruebas E2/E3 nuevas.** E2 continúa `NOT_IMPLEMENTED` y E3 `NOT_EXECUTED`; la documentación no habilita emisión ni beta. Siguiente actividad de código, si los controles del conector lo permiten: diseñar y revisar conjuntamente auditoría transaccional + cuotas de denegaciones, después implementar una interfaz interna que nunca reciba afirmaciones MFA y probar PG17 efímero con carreras reales. No reconectar el `bool` de E1 al emisor de laboratorio ni eludir bloqueos de publicación anteriores. No pedir nuevas pruebas G15.

## 06/11/2026 — E3 refresh races preparadas; validación local dirigida pendiente

Nuevo código de pruebas `e269963d003b3c82ac5eb2a73c518d0a92320635`: dos escenarios PG17 de refresh vs revocación global y refresh vs cambio de contraseña; ambos en `native_mobile_service.test_pg17_races`, sin lógica de runtime nueva. Informe `docs/G14_E2_E3_GROUPED_SECURITY_REVIEW_2026-11-06.md` actualizado en `801ef0cb155db07d805a8187da3ccf5903b762bc`. Runner `scripts/n1_identity_pg17_ephemeral.sh --e3-refresh` añadido en `2947ea9628767b62e0af7aa8a146d649c5903cf3`: ejecuta solo los dos casos en PostgreSQL 17 efímero, sin puertos ni datos reales. **No hay PASS de estas pruebas aún.**

Comprobación local única sugerida, tras `git fetch` + `merge --ff-only` en checkout limpio y confirmar HEAD:
```bash
cd ~/vencira-m3-localcheck
git fetch origin feature/m3-android-local-notifications
git merge --ff-only FETCH_HEAD
git rev-parse --short HEAD
bash -n scripts/n1_identity_pg17_ephemeral.sh &&
bash scripts/n1_identity_pg17_ephemeral.sh --e3-refresh
echo "G14_E3_REFRESH_LOCAL_RESULT=$?"
```
Esperado: `Ran 2 tests`, `OK`, `G14_E3_REFRESH_PG17_RESULT=0`, `G14_E3_REFRESH_LOCAL_RESULT=0`; los resultados deben aportarse antes de cambiar el estado. Este lote **no** cubre emisión MFA E2, E3 TOTP ni lanzamiento beta. No repetir G15/G13 o 139 pruebas E1D3 por rutina.

## 06/11/2026 — G14-E3 refresh R1/R2 validado en VPS

Evidencia del operador: checkout `d67698012`, imagen Docker reconstruida y `G14_E3_IMAGE_SYNC=OK`; runner PostgreSQL 17 interno/tmpfs: `Found 2 test(s)`, `Ran 2 tests in 1.306s`, `OK`, `G14_E3_REFRESH_PG17_RESULT=0`, test DB destruida. Los intentos iniciales fallaron por imagen obsoleta y preflight Django incompleto; no eran fallos de concurrencia. **E3-R1/R2 PASS_LOCAL_PG17**. Informe de aceptación actualizado en commit `4aa4d18c7138fc405edaaab7a64ceb89a1e1714d`. No hay evidencia del echo externo `G14_E3_REFRESH_LOCAL_RESULT`.

No repetir este ensayo salvo cambios relevantes. Faltan emisor MFA confiable E2, concurrencia de emisión TOTP/recovery y auditoría transaccional; beta/release continúan NO GO. Conservar todas las restricciones de seguridad y no modificar base persistente.

## 06/11/2026 — E3-R3/R4: refresh vs estado MFA (publicado, pendiente de PG17)

- Código `b486a0aa26c164c67bfa6259a1d0b7df4555004a`: se añaden dos pruebas en `native_mobile_service.test_g14_d8_admin_rotation_pg17`, ya incluida en el runner y CI. Ambas usan **sesión MFA sintética de laboratorio** y dos conexiones independientes.
- R3: `test_e3_refresh_vs_mfa_epoch_revocation_invalidates_both_tokens`, refresh frente a `revoke_mfa_sessions`, verifica que los tokens existentes y cualquier par devuelto quedan inválidos por `session_epoch`.
- R4: `test_e3_refresh_vs_admin_recovery_does_not_keep_valid_tokens`, refresh frente a `open_recovery_case` con verificador sintético; comprueba expediente pendiente y revocación efectiva de tokens por cambio de época.
- Runner `9fa684932ddf5360ec4b7262e0a6c729435a1d13`: `bash scripts/n1_identity_pg17_ephemeral.sh --e3-mfa-refresh`, **dos pruebas dirigidas**, sin puertos Docker ni datos de producción, sin repetir G13/G15 ni toda la batería E1.
- **ESTADO: R3/R4 CODE_PUBLISHED, PG17_NOT_RUN**. Estas pruebas no prueban el emisor MFA E2, la cadena de custodia real ni una ruta HTTP autorizada. Mantener `G14_E2_ISSUER=NOT_IMPLEMENTED`, `MFA_RELEASE_AUTHORIZED=NO`, `MB1_RELEASE_AUTHORIZED=NO`, `C_FICHA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


## 06/11/2026 — E3-R3/R4 PASS local en PostgreSQL 17

El operador ha comunicado el resultado del runner dirigido `--e3-mfa-refresh`: `N1_PG17_POSTGRES_READY=OK`, `No changes detected in app 'native_mobile_service'`, `Found 2 test(s)`, `Ran 2 tests in 1.266s`, `OK`, `Destroying test database for alias 'default'...` y `G14_E3_MFA_REFRESH_PG17_RESULT=0`.

**E3-R3/R4=PASS_LOCAL_PG17** para las carreras de refresh frente a incremento de epoch MFA y apertura de recuperación administrativa sintética. No se recibió la línea externa `G14_E3_MFA_LOCAL_RESULT`; no se infiere. No consta SHA del checkout de esa ejecución en el mensaje; los métodos corresponden al lote registrado anteriormente y deben correlacionarse con HEAD ante cualquier auditoría formal.

Con R1/R2 ya aprobados, **E3-R1..R4 están cerrados dentro de su alcance de pruebas**. No se ha ejecutado ni aprobado el emisor atómico MFA E2 ni carreras de login TOTP/recovery. `G14_E3_INTEGRAL=PENDING`; `MFA_RELEASE_AUTHORIZED=NO`, `MB1_RELEASE_AUTHORIZED=NO`, `C_FICHA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`. No repetir estas suites por rutina.

## 06/11/2026 — G14-E2-F1, control de transferencia booleana publicado

Se añadió `scripts/g14_e2_bool_issuance_fence.py` (AST, solo lectura) con 7 pruebas en `scripts/test_g14_e2_bool_issuance_fence.py` y N1 `g14_e2_boolean_proof_nontransferable`. Documentado en `docs/G14_E2_E3_GROUPED_SECURITY_REVIEW_2026-11-06.md` (commit `1282757e37f2a58b10e0f75e214f88ea6da038e6`). **No hay resultado de pruebas locales aún.** El guard impide referencias explícitas al verificador E1 desde código no-test, pero no equivale a un análisis completo de todas las rutas dinámicas ni implementa el emisor MFA confiable.

Validación dirigida única sin Docker: sincronizar rama y ejecutar unittest nuevo, scanner y N1, según el informe E2/E3. No ejecutar PostgreSQL ni G13/G15 por este cambio. `G14_E2_ISSUER=NOT_IMPLEMENTED`, `G14_E3_INTEGRAL=PENDING`; continuar sin despliegue, migración persistente ni release.

## 06/11/2026 — G14-E2-F1 PASS local (evidencia aportada)

El operador ejecutó el gate dirigido con resultados: `Ran 7 tests in 0.003s`, `OK`, `G14_E2_E1_BOOL_CROSS_BOUNDARY=0`, `G14_E2_BOOL_FENCE=PASS`, `G14_E2_TRUSTED_ISSUER_IMPLEMENTED=NO`, `N1_STATIC_g14_e2_boolean_proof_nontransferable=OK`, `N1_STATIC_GATE_RESULT=OK`, `G14_E2_F1_LOCAL_RESULT=0`.

**E2-F1=PASS_LOCAL_STATIC**. Solo se verifica la barrera sintáctica contra reutilización explícita del resultado booleano E1 fuera de tests. No se acredita análisis dinámico completo, transacción de token+auditoría, emisor confiable, E3 integral, release ni despliegue. No se aportó SHA del checkout en esta salida, por lo que no se deduce uno. No volver a ejecutar este gate sin cambios relevantes.

Se mantienen `G14_E2_ISSUER=NOT_IMPLEMENTED`, `MFA_RELEASE_AUTHORIZED=NO`, `MB1_RELEASE_AUTHORIZED=NO`, `C_FICHA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.
