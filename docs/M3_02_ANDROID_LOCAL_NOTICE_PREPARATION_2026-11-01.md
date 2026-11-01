# VENCIRA — M3-02: preparación de notificaciones locales Android (01/11/2026)

## Alcance comprobado en el código fuente

En el repositorio actual **no existe** `clients/flutter/android/app/src/main/AndroidManifest.xml` ni un proyecto Android versionado; `pubspec.yaml` no integra un plugin de avisos del sistema ni almacenamiento local cifrado. Por tanto, **no existe todavía un mecanismo que dispare avisos offline en Android**. El endpoint `device-notice-preview` es lectura autorizada, paginada y limitada a 31 días; `native_alarm_scheduling=false`, `offline_storage=false` y `delivery=false` son las capacidades reales publicadas. No falsear estas capacidades.

## Desarrollo agrupado en rama aislada

1. `clients/flutter/lib/notifications/device_notice_reconciliation.dart`: cálculo puro de diferencias entre un inventario de alarmas previamente autorizadas y el preview completo de un usuario/cuenta. Identidad estable por workspace, usuario, ocurrencia y generación; fecha civil local a las 09:00; idempotencia, sustitución y cancelación por cambios. Impide usar un preview paginado/incompleto, una fecha fuera del día actual, otra zona horaria o permisos/rollout/almacenamiento no acreditados. El resultado no lleva nombres ni motivos de póliza: solo referencias técnicas opacas.
2. `clients/flutter/lib/notifications/device_notice_sync.dart`: contrato abstracto para un futuro adaptador OS, con cancelación **antes** de crear nuevas alarmas; si falla una cancelación, no crea alarmas nuevas. Ante resultado de programación ambiguo intenta cancelar la nueva alarma y las generadas en la misma tanda, sin afirmar éxito.
3. `clients/flutter/test/device_notice_reconciliation_test.dart`: casos de sincronización idempotente, reprogramación por día/generación, pérdida de permisos, rechazo de snapshot parcial, revocación por cambio de cuenta y usuario, alarmas atrasadas, datos inválidos y minimización de contenido.
4. `clients/flutter/test/device_notice_sync_test.dart`: pruebas del orden de cancelación y de compensación cuando el adaptador ficticio pierde el ACK.
5. GitHub Actions `m3-product-contracts.yml`: amplía las pruebas Flutter; `m3-android-diagnostic.yml` comprueba la posibilidad de generar un proyecto Android en **un runner efímero** y compilar APK de depuración sin distribuirlo. Esta generación no agrega el scaffold a Git ni implementa alarmas.

### Evidencia confirmada al inicio

Workflow `41308720526` en commit `ca9bfe79` (antes de añadir `device_notice_sync.dart`): Django SQLite **73/73 PASS**, Django PG17 efímero **73/73 PASS**, Flutter analyze **PASS**, Flutter **71/71 PASS**, compilación Flutter Web **PASS**. Auditoría estática MB1 `41308720533` PASS. La nueva batería de sincronización y el diagnóstico Android necesitan registrar sus resultados por separado; **no atribuir el primer PASS a código posterior al commit probado**.

## Validación del bloque de sincronización (GitHub Actions)

- Commit ejecutado: `ff4d9d33f17d1d548942d8f4527300e5d6898a68`.
- Run M3 `41308949614`, resultado de los **tres jobs = success**:
  - SQLite job `124855371863`: **73/73 PASS**.
  - PostgreSQL17 efímero job `124855372027`: **73/73 PASS**.
  - Flutter job `124855372098`: **flutter analyze PASS**, **75/75 tests PASS**, **Flutter Web compilado correctamente**.
- El workflow de diagnóstico Android `41308949634` es independiente y no está incluido en esta afirmación de éxito; el build APK sigue sujeto a verificación de su propio resultado.

### Diagnóstico de compilación Android (runner efímero)

- Workflow `m3-android-diagnostic.yml`, run **41308795853**, job **124854647521**, conclusión **success**.
- Salida: `✓ Built build/app/outputs/flutter-apk/app-debug.apk`, `ANDROID_SCAFFOLD_TEMPORARY_BUILD=PASS`.
- Los marcadores del propio workflow establecen `NATIVE_NOTIFICATIONS_IMPLEMENTED=NO` y `OFFLINE_ENCRYPTED_STORE_IMPLEMENTED=NO`.
- El scaffold Android se generó con `flutter create --platforms=android` solo en el runner; **no se ha versionado** ni distribuido APK. No es aceptación Android física ni una compilación de un adaptador de notificaciones.
- Run posterior **41308949634** contiene el sincronizador nuevo; su diagnóstico independiente sigue pendiente de concluir en esta revisión. El primer PASS no se atribuye a ese commit posterior.

## Pasos necesarios para operar en Android

- Crear y versionar el scaffold Android real, configurar Gradle, SDK, permisos Android 13+, restricciones Android 12+ y política de alarmas exactas/optimizaciones de batería.
- Programar/cancelar alarmas con un adaptador de OS y restaurarlas tras reinicio/cambio de hora; no confundir alarma instalada con notificación vista o entregada.
- Implementar inventario cifrado independiente, revocación en logout y baja de usuario, aislamiento multi-cuenta, sincronización de cambios y protección de pantalla bloqueada. Sin estos controles, el planificador no está conectado al arranque de la app.
- Aprobación funcional §18 sobre avisos no atendidos, entradas tardías, Vida y conflictos offline; pruebas en dispositivos Android físicos con permisos denegados, DST, pérdida de red, reinicio y cambios de cuenta.

Se conserva la protección `MB1_RELEASE_AUTHORIZED=NO`, `MFA_RELEASE_AUTHORIZED=NO`, `C_FICHA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`. La PR #14 sigue **draft**; M3-02 **abierto**; cierre formal **2/15 (13,3 %)**. Sin migraciones persistentes, sin envíos, sin despliegue DEV.
