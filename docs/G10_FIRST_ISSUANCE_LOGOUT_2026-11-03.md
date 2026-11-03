# G10 — Primera emisión y cierre remoto con checkpoint duradero

Fecha: 03/11/2026. **CANDIDATO PUBLICADO / PENDING EJECUCIÓN FLUTTER LOCAL O CI.**

## Evidencia anterior

- G7-D2/E/F/G/H: `G7_MACRO_RESULT=0` en laboratorio Django+Flutter HTTPS aislado.
- G8-PHONE: `G8_PHONE_PHYSICAL_STORAGE_RESULT=0` en teléfono Android de pruebas, con tokens sintéticos y proceso reiniciado.
- G9: `N1_STATIC_GATE_RESULT=OK`, `G9_STARTUP_ANALYZE=OK`, `G9_STARTUP_AND_RECOVERY_UNIT=OK`, `G9_STARTUP_GATE_RESULT=0`; bloque de arranque fail-closed y selección de recuperación validado por operador.
- No hay MFA operativo autorizado, publicación del emisor de tokens, congelación global de escritores MB1 verificada ni habilitación de la aplicación para credenciales de producción. `NO_DEPLOY_NO_LIVE_MIGRATION=1` siempre.

## Riesgo que cubre

No basta con persistir el refresh después de obtenerlo. Si el proceso se cierra tras emitir credenciales en el servidor y antes de guardarlas, el cliente no sabe si existe una sesión remota activa. G10 protege la **primera emisión**: antes de enviar la primera contraseña/MFA, persiste un marcador de reautenticación obligatoria. Si el intercambio falla o se desconoce la respuesta, dicho marcador sobrevive y G9 exige recuperación de cuenta, en vez de repetir una emisión a ciegas.

De forma análoga, antes de cerrar la sesión, el cliente bloquea el fence de inmediato y deja constancia persistente antes de contactar con la revocación remota. La limpieza nunca se presenta como realizada si una revocación, borrado de credencial o borrado de marcador no pudo verificarse.

## Componentes

### G10-A — Diario de emisión inicial

`clients/flutter/lib/api/native_refresh_recovery_journal.dart`, nuevos métodos:

- `confirmFirstIssuance`: exige marcador `full-reauth-required-v1` ya duradero y **vault previamente vacío**. Ejecuta el reemplazo y verificación de refresh, comprueba que el fence siga cerrado, borra marcador y verifica lectura vacía; solo después el coordinador activa el fence. No equivale al `confirmFullReauthentication` de G6, que presupone revocación global de sesiones.
- `confirmLogoutCompleted`: exige marcador pendiente y vault vacío **tras** revocación remota confirmada. Borra y relee el marcador. Cualquier fallo deja la sesión cerrada.

### G10-B — Coordinador con opt-in de diario

`clients/flutter/lib/api/native_session_coordinator.dart` admite el parámetro opcional `firstIssuanceJournal` (el G7 antiguo sigue compilando sin él).

- Antes de `port.password` y `port.mfa`, si se activó G10, obliga a encontrar el marcador, vault vacío y el mismo fence. Ninguna solicitud sale si falta.
- La activación usa `confirmFirstIssuance` en vez de `vault.replace` directo: exige confirmación de persistencia de refresh y borrado del checkpoint.
- En caso de error durante commit se reintenta **armar el marcador**; no se elimina ciegamente el refresh, que sirve como evidencia de huérfano si falla el diario protegido. Se intenta revocar el refresh emitido y, si no puede, se mantiene bloqueado el coordinador.
- `logout()` revoca el fence de forma sincrónica, espera operaciones pendientes, persiste el marcador, revoca el refresh remoto, verifica `vault.clear` y solo entonces confirma el borrado del checkpoint. Repetir logout después de una limpieza local fallida evita repetir una revocación **ya confirmada** del mismo refresh dentro del mismo proceso.

### G10-C — Entrada de primera emisión de uso único

`clients/flutter/lib/api/native_first_issuance_entry.dart` exige selección G9 `cleanLogin` y que fence/vault/journal sean las mismas instancias revisadas. Arma y relee el checkpoint **antes de llamar al coordinador** para la primera contraseña. El intento es único: fallo de contraseña, respuesta perdida, cancelación o marcador incierto impiden un segundo login normal; corresponde reautenticación completa. `verifyTotp` solamente después del inicio preparado. El logout admite reintento de revocación/limpieza, pero no reabre login. El adaptador no hace HTTP directamente y no está instanciado desde `main.dart`.

**Limitación importante:** no se garantiza aún una única custodia de vault entre procesos, ni se ha integrado con la UI/Android real, ni se ha ensayado este protocolo completo sobre el emisor candidato con HTTPS real. Los métodos son candidatos de arquitectura, no APIs de producción. El marcador G10 no representa por sí solo una autorización de MFA o de revocación global en Django; es un bloqueo local.

## Test y gate

15 pruebas de G10 en `clients/flutter/test/native_first_issuance_entry_test.dart` cubren: denegación antes de G9; persistencia antes de password; primera emisión+logout; estado huérfano; MFA con marcador pendiente; fallo silencioso de escritura; contraseña fallida; respuesta incierta; fallos de refresh o borrado de marcador; rechazo de doble envío; cancelación mientras se escribe el marcador; fallo de revocación remota; reintentos de limpieza local sin revocación duplicada; imposibilidad de contactar directamente al backend desde coordinador G10 sin marcador.

`scripts/g10_issuance_logout_gate.sh`: un único control N1, `flutter analyze` de archivos G10 y 6 suites Flutter (G10 más G9-A/B y G6/coordinador), reutilizando caché pública de Pub. CI `.github/workflows/g10-issuance-logout-gate.yml`, guard `g10_first_issuance_logout_checkpoint` en `scripts/n1_static_security_gate.py`.

Una sola prueba en Ubuntu, sin repetir G7 HTTPS ni G8 Android:

```bash
cd ~/vencira-m3-localcheck
git fetch origin feature/m3-android-local-notifications
git merge --ff-only FETCH_HEAD
bash scripts/g10_issuance_logout_gate.sh
echo "G10_LOCAL_RESULT=$?"
```

El PASS exige `G10_ISSUANCE_ANALYZE=OK`, `G10_ISSUANCE_LOGOUT_UNIT=OK`, `G10_G9_G6_REGRESSION=OK`, `G10_ISSUANCE_LOGOUT_BATCH=OK`, `G10_ISSUANCE_LOGOUT_GATE_RESULT=0` y `G10_LOCAL_RESULT=0`. **Pendiente de recepción y verificación; no publicar PASS sin log.**

**Gates operativos:** `MB1_RELEASE_AUTHORIZED=NO`, `MFA_RELEASE_AUTHORIZED=NO`, `C_FICHA_RELEASE_AUTHORIZED=NO`, `GLOBAL_FREEZE=NOT_VERIFIED`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`, PR #17 DRAFT.

## G10 primera ejecución local: fallo aislado de aserción síncrona, corregido (03/11/2026)

El operador ejecutó `scripts/g10_issuance_logout_gate.sh`. **N1 estático íntegro OK**, incluidas las comprobaciones G9/G10; `flutter analyze` de los 4 archivos informó **`No issues found!`**. En la ejecución unitaria agrupada, **63 tests pasaron y 1 falló**: `native_first_issuance_entry_test.dart: failed password leaves durable marker for reboot recovery`, con `Bad state: Native startup fence mismatch` en `native_mobile_startup_gate.dart:47` y test línea 226. Resultado final `G10_FLUTTER_BATCH=FAIL`, `G10_ISSUANCE_LOGOUT_GATE_RESULT=1`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

**Diagnóstico:** el caso negativo construía deliberadamente `NativeMobileStartupGate` con un `fence` distinto del del `NativeRefreshRecoveryJournal`. `inspect()` comprueba identidad de fence y lanza **StateError síncronamente antes de devolver un Future**. La prueba usaba `await expectLater(cold.inspect(), throwsStateError)`, que evalúa `cold.inspect()` *fuera* del matcher: por ello el `StateError` intencional escapó y señaló un falso fallo de la prueba. Se sustituyó exclusivamente por `expect(() => cold.inspect(), throwsStateError)`, que entrega una función para que el matcher capture la excepción síncrona. **No se tocó la lógica de seguridad de producción ni se flexibilizó el bloqueo por mismatch**. La segunda parte del mismo test, con `rebootFence` compartido, conserva la comprobación positiva de `fullReauthentication` después de un inicio fallido.

**Estado:** fuente corregida y publicada; G10 **PENDING RECHECK**, NO PASS hasta la nueva salida de `bash scripts/g10_issuance_logout_gate.sh`. Repetir solo la batería agrupada G10; no repetir G7 HTTPS, G8 móvil físico ni G9 aislado. Sigue PR DRAFT, `NO_DEPLOY_NO_LIVE_MIGRATION=1` y release MFA/MB1/C-FICHA no autorizado.

## G10 — Reejecución integral PASS confirmada por operador (03/11/2026)

Tras la corrección de la aserción síncrona del test negativo, el operador ejecutó de nuevo el runner G10 en Ubuntu, con los siguientes marcadores:

```text
N1_STATIC_g9_recovery_entry_never_downgrades_to_regular_login=OK
N1_STATIC_g10_first_issuance_logout_checkpoint=OK
N1_STATIC_lab_issuer_requires_epoch=OK
N1_STATIC_GATE_RESULT=OK
G10_ISSUANCE_ANALYZE=OK
G10_ISSUANCE_LOGOUT_UNIT=OK
G10_G9_G6_REGRESSION=OK
G10_ISSUANCE_LOGOUT_BATCH=OK
G10_ISSUANCE_LOGOUT_GATE_RESULT=0
NO_DEPLOY_NO_LIVE_MIGRATION=1
```

**Resultado: G10 = PASS, suite unitaria Flutter agrupada y guardia estática.** La salida no incluye la línea opcional `G10_LOCAL_RESULT=0` de un `echo` posterior, pero el propio runner informa `G10_ISSUANCE_LOGOUT_GATE_RESULT=0`. Se cierra el incidente anterior de 63/64, causado por un matcher inadecuado para una excepción síncrona; no fue un fallo del protocolo de seguridad. El bloqueo por `Native startup fence mismatch` permanece sin modificaciones.

**Alcance:** primera emisión con marcador duradero, acceso cerrado hasta confirmar vault y limpieza de marcador, revocación/cierre fail-closed y regresiones G9/G6 en condiciones de prueba con puertos simulados. **Todavía NO existe evidencia de G10 contra Django por HTTPS ni de este protocolo completo en Android físico.** El siguiente paso razonable es el ensayo HTTPS aislado G11 (o la auditoría correspondiente), sin desplegar ni montar emisores reales. No reejecutar G7/G8/G9 salvo que cambien sus contratos. PR #17 DRAFT, `MB1_RELEASE_AUTHORIZED=NO`, `MFA_RELEASE_AUTHORIZED=NO`, `C_FICHA_RELEASE_AUTHORIZED=NO`, `GLOBAL_FREEZE=NOT_VERIFIED`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.
