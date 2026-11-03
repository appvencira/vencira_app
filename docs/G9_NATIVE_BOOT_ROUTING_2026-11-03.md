# G9 — Arranque nativo fail-closed y selección de recuperación

Fecha: 03/11/2026 — **CANDIDATO PUBLICADO, PENDIENTE DE GATE FLUTTER LOCAL/CI**.

## Referencias y estado anterior

- G7-D2/E/F/G/H PASS end-to-end HTTPS en Django temporal según salida de operador `G7_MACRO_RESULT=0`.
- G8-PHONE PASS en Android físico según los siete marcadores entregados por el operador, terminado en `G8_PHONE_PHYSICAL_STORAGE_RESULT=0`. Solo valida ese dispositivo y credenciales sintéticas.
- **G9 NO activa el servicio móvil de producción.** No modifica `main.dart`, `config.urls` ni las migraciones Django/PostgreSQL. Se mantiene `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## Riesgo de integración resuelto parcialmente

Los componentes G7 permiten leer/escribir refresh y ejecutar recuperación, pero **no forman por sí solos un protocolo de arranque completo**. Tras una terminación brusca, el almacén puede contener un refresh anterior sin marcador. Si una futura aplicación ofreciera login normal o refresh automático sin inspeccionar ese estado, podría ignorar credenciales remotas pendientes de revocación. Es obligatorio iniciar con el `NativeSessionFence` cerrado.

### G9-A: `NativeMobileStartupGate`

Fichero `clients/flutter/lib/api/native_mobile_startup_gate.dart`.

- `inspect()` revoca el fence **sincrónicamente** antes de ninguna lectura asíncrona.
- Marcador persistente existente: `fullReauthentication`, nunca refresh/replay.
- Refresh protegido antiguo sin marcador: crea y relee un **marcador durable** antes de autorizar la recuperación completa. La credencial queda intacta hasta que el backend confirme una recuperación autenticada; no se vuelve a enviar como refresh.
- Almacén vacío y sin marcador: estado `cleanLogin`, pero **no activa ninguna sesión**.
- Lectura errónea, marcador corrupto, escritura ignorada o fallo de persistencia: permanece `locked`; la excepción no se convierte silenciosamente en ruta de login.
- Evita inspecciones concurrentes independientes y no permite degradar una decisión previa de recuperación a login normal repitiendo `inspect()`. Comprueba que diario y decisión utilizan el mismo fence. No accede a HTTP ni imprime secretos.

### G9-B: `NativeMobileRecoveryEntry`

Fichero `clients/flutter/lib/api/native_mobile_recovery_entry.dart`.

- Solo después de inspección G9-A con resultado `fullReauthentication`, comprueba de nuevo el marcador con `NativeRecoveryLoginGateway.requiresRecovery()`.
- Hasta que el estado esté listo, los métodos `verifyPassword`, `verifyTotp` y `abandonChallenge` **rechazan la llamada antes de llegar al transporte**.
- Un arranque `cleanLogin` **nunca** habilita el adaptador de recuperación ni un login normal por atajo.
- Rechaza desajustes entre instancias de fence, vault y journal, revocando cualquier ticket local.
- La recuperación continúa usando el proceso ya auditado G7 de contraseña + MFA, reemplazo protegido, consumo de marcador y revocación de dispositivos previa en el servidor.

**Límite deliberado de G9-B:** no ofrece ruta ordinaria de primera emisión ni logout operativo. Para hacerlo de forma correcta hay que implementar la escritura del checkpoint **antes** del primer intercambio de credenciales con servidor, su consumo **después** de verificar el almacenamiento y **antes** de abrir el fence, y cierre/revocación resistente a fallos. Un login normal sin ese protocolo reabriría el riesgo de respuesta de emisión perdida. No conectar aún `NativeSessionCoordinator` directamente al arranque Android.

## Pruebas agrupadas

Un único ejecutor, sin repetir G7 HTTPS ni G8 Android:

```bash
cd ~/vencira-m3-localcheck
git fetch origin feature/m3-android-local-notifications
git merge --ff-only FETCH_HEAD
bash scripts/g9_native_startup_gate.sh
echo "G9_LOCAL_RESULT=$?"
```

`scripts/g9_native_startup_gate.sh` usa `ghcr.io/cirruslabs/flutter:stable` y cache Pub de dependencias públicas, más `scripts/n1_static_security_gate.py`. Analiza los dos nuevos archivos Dart y ejecuta **cuatro suites en un único proceso Flutter**: nueva puerta de arranque, nuevo adaptador de recuperación y las suites previas de diario y coordinador. Al pasar debe emitir:

```text
G9_STARTUP_ANALYZE=OK
G9_STARTUP_AND_RECOVERY_UNIT=OK
G9_STARTUP_GATE_BATCH=OK
G9_STARTUP_GATE_RESULT=0
NO_DEPLOY_NO_LIVE_MIGRATION=1
G9_LOCAL_RESULT=0
```

La CI `.github/workflows/g9-native-startup-gate.yml` ejecuta el mismo lote en PR y cambios relevantes. Los guardas estáticos `g9_native_startup_recovers_orphan_fail_closed` y `g9_recovery_entry_never_downgrades_to_regular_login` prohíben perder los requisitos o enlazar el prototipo a `main.dart`.

**Estado: G9-A/B PENDING hasta recibo local o CI del lote.** No confundir un test unitario sintético con una prueba completa de login móvil operativo ni elevar estado de release.
