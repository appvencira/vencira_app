# VENCIRA — Ruta crítica a beta Android, 06/11/2026

Rama: `feature/m3-android-local-notifications`. Documento de planificación, no autorización de publicación. Estado de referencia: G14-E1D3 PASS local con 139 tests PostgreSQL17 y N1/build/PG17=0; G14-F0 PASS local con 9 tests estáticos, scan/N1=0; G13 Android físico 18/18 PASS únicamente sobre HTTPS de laboratorio, CA temporal, túnel y datos sintéticos.

## Dos destinos y criterios independientes

**BETA LAB (solo titular / QA con datos sintéticos).** No se conecta a API de usuarios reales, no se utilizan claves productivas, no se expone login nativo candidato, no se requiere migración de PostgreSQL persistente. Se admite APK debug firmada exclusivamente para pruebas aisladas. Objetivo: revisión de UX Android, instalaciones, permisos de notificación, almacenamiento seguro, error de red, recuperación, logout, segundo arranque y autonomía del proceso. G13 ya acredita 18/18 pruebas de una APK de laboratorio; no acredita una experiencia completa del producto.

**BETA PRIVADA FUNCIONAL (usuarios autorizados, persistencia real).** Requiere emisor de identidad confiable, custodia/recuperación MFA, autorización workspace, revocaciones y auditoría, TLS desde el móvil a la API real con dominio oficial y certificación, control de fallos, datos personales y release/rollback. Sin esos requisitos, NO-GO.

## Macrofase B1 — cerrar identidad del servidor (bloqueante principal)

- [ ] G14-E2: disponer de composición autorizada `contraseña + TOTP/recuperación + sesión + auditoría` en una única transacción con bloqueos consistentes. La prueba E1 devuelve booleano sin identidad transferible; el emisor de laboratorio recibe afirmaciones del llamante. **No unirlos directamente**.
- [ ] G14-E3: competencia por TOTP/código recovery, cambio de contraseña, cambio de factor, recuperación pendiente, revocación, fallo de escritura, fallo auditoría y respuesta ambigua. Cuotas y denegaciones persistentes controladas fuera del rollback de éxito.
- [ ] Incorporar las políticas G4/G5 sin fallback a sesión web. Claves externas, rotación, proxy de confianza y permisos explícitos. PR con revisión independiente. Los intentos de publicar integración MFA+auditoría fueron bloqueados por controles del conector; no eludir el bloqueo.
- **Gate:** CI + PG17 efímero + N1, fuentes y HEAD reproducibles; ningún endpoint abierto antes de autorización. B1 no puede marcarse PASS por pruebas de E1D3/F0.

## Macrofase B2 — cerrar integración Android y capacidad de recuperación

- [ ] Integrar UI de autenticación y APIs nativas reales con HTTPS normal (sin CA de laboratorio ni túnel SSH), identidad del servidor, almacenamiento en Keystore, logout, expiración, cambios de cuenta y recuperación G6. Sin mezclar sesiones web, cookies y bearer.
- [ ] Verificar workspace, permisos de lectura/escritura, errores uniformes, datos mínimos de cada endpoint y bloqueo contra acceso cruzado.
- [ ] Probar notificaciones Android reales y sus permisos/canales, scheduler, reinicios y denegación/retirada de consentimiento; no asumir que G13 HTTPS validó el comportamiento operativo de notificaciones.
- [ ] APK/AAB firmada con clave de distribución guardada fuera del repositorio, identidad/versiones y actualización firmada. La configuración actual `clients/flutter/android/app/build.gradle.kts` usa **signingConfigs.debug** en `release`: cambiar y verificar antes de distribuir una beta formal; no compartir el keystore.
- [ ] UAT móvil del producto: login, agenda, vencimientos, estados, historial, borradores, cambios de workspace, errores, logout y localización ES/CA; accesibilidad/permisos y comportamiento offline definidos.
- **Gate:** pruebas en Android físico de punta a punta con backend beta, sin datos personales innecesarios, logs sanitizados y métricas/fallo/reintento.

## Macrofase B3 — operación y autorización de beta

- [ ] G1: custodia y recuperación administrativa real supervisada; MFA bajo autorización explícita.
- [ ] G2: cerrar alcance MB1, grafo de escritores, `GLOBAL_FREEZE`, restauración/backups y rollback sin pérdida; no asumir que pruebas sintéticas autorizan migración real.
- [ ] G3: aislar explícitamente adjuntos fuera de alcance o aprobar C-FICHA y sus puertas de acceso, custodia, ClamAV y retención. Excluir adjuntos de una beta no autoriza rutas ocultas si aún están registradas.
- [ ] G8: revisión de todos los endpoints nativos con permisos por workspace, auditoría y pruebas de abuso/PII.
- [ ] G9: entorno beta segregado, TLS, CSRF cuando aplique, observabilidad, backups/restore, gestión de incidentes, rollback de aplicación y DB, protección de datos/condiciones, revisión independiente y autorización expresa.
- [ ] PR #17 revisada: decidir merge/despliegue únicamente tras gates y recibos; no publicar credenciales, tokens ni claves en GitHub.
- **Gate:** GO/NO-GO por responsable con recibo y SHA de la versión, plan de reversión y pruebas posteriores. `MFA_RELEASE_AUTHORIZED=NO`, `MB1_RELEASE_AUTHORIZED=NO`, `C_FICHA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1` hasta autorización.

## Orden de trabajo acelerado

1. **Mientras E2 esté bloqueado:** terminar inventario de alcance beta y revisión Android/UX/firmado en cambios aislados, sin exponer el servidor. El siguiente esfuerzo técnico clave es la autorización de E2, no aumentar sin fin las pruebas de TOTP.
2. **Tras disponer de E2 revisado:** agrupar E2+E3+G4/G5 y ejecutar un único gate PG17/N1/CI.
3. **Después:** agrupar Android real+permisos+notificaciones+UAT y una sola campaña física.
4. **Por último:** consolidar G1/G2/G3/G8/G9 y autorizar beta privada con rollback.

## Estado y porcentaje

- G13 físico 18/18: 100 % de **ese ensayo**, no del producto.
- Gates G0–G9 según último registro revisado: 1/10 formalmente cerrados. **No es porcentaje ponderado del software o días restantes**.
- No se dispone de inventario ponderado de funcionalidades aceptadas; no asignar porcentaje global ni fecha de beta sin cerrar B1, B2 y B3.
- Android beta aislada de laboratorio ya existe como APK G13 debug, pero **no es beta comercial ni beta operativa con usuarios reales**.


## 06/11/2026 — B2-A preparación de firmado: publicado, NO validado

- `clients/flutter/android/app/build.gradle.kts` ya no asigna `signingConfigs.debug` a `release`. Cualquier tarea Gradle que solicite `release` sin las cuatro variables externas de firmado falla cerrada con `VENCIRA_ANDROID_RELEASE_SIGNING_REQUIRED`.
- Las variables se leen exclusivamente del entorno de ejecución: `VENCIRA_ANDROID_KEYSTORE_PATH`, `VENCIRA_ANDROID_KEYSTORE_PASSWORD`, `VENCIRA_ANDROID_KEY_ALIAS` y `VENCIRA_ANDROID_KEY_PASSWORD`. **No añadir valores reales a GitHub, scripts, CI logs ni conversación**. El keystore debe custodiarse fuera del repositorio y contar con copia de recuperación independiente.
- G8/G12/G13 siguen siendo compilaciones `debug` con `applicationIdSuffix` propio y rechazo expreso de modo `release/profile`. No se ha convertido ninguna prueba G13 en una beta operativa.
- Pruebas fuente `scripts/test_android_release_signing_boundary.py` (cuatro casos); N1 `android_beta_release_signing_external_only` y workflow `m3-product-contracts.yml` actualizados. **Pendiente comprobar en VPS**: cuatro unit tests, N1 y resolución Gradle real antes de atribuir firma segura.
- No se ha creado certificado/keystore, no hay APK/AAB de distribución firmada, y faltan políticas de actualización/versionado, canal de pruebas, QA físico y autorización de release.
- No se cambió backend Django, esquema o rutas HTTP. `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


## 06/11/2026 — B2-A PASS local (pruebas estáticas, no Gradle real)

Recibo del operador: `B2_A_HEAD=b4065dd8d`, `B2_A_TESTS=0`, `B2_A_N1=0`, `B2_A_DIFF=0`; `Ran 4 tests in 0.001s`, `OK`, `N1_STATIC_android_beta_release_signing_external_only=OK`, `N1_STATIC_GATE_RESULT=OK`. Se cierra B2-A **solo en alcance de fuentes/tests estáticos**. Se requiere todavía ensayo de configuración Gradle sin parámetros de firmado (rechazo), y build release con keystore custodiado fuera de GitHub (en entorno aislado, únicamente tras autorización de pruebas de firma). No se ha firmado ni distribuido APK beta. B2-B queda pendiente.


## 06/11/2026 — B2-B: regresiones de la barrera de arranque Android

- Ya existen `DeviceNoticeStartupGate`, `NativeMobileStartupGate`, `NativeMobileRecoveryEntry`, `DeviceNoticeConsentPort` y una pantalla de acceso web externo. El cliente Android operativo **no** usa aún inicio de sesión nativo. El arranque de Android cancela avisos anteriores antes de mostrar acceso al navegador.
- Se agregan cuatro tests widget al módulo Flutter existente `test/device_notice_startup_gate_test.dart`: fallo tardío de una limpieza sustituida tras éxito nuevo, éxito tardío que no debe saltarse un fallo nuevo, reintento sin dos limpiezas simultáneas, y transición deshabilitado→habilitado con nueva limpieza.
- Control estático N1 `android_beta_b2b_startup_recovery_regressions` para impedir eliminar los casos del lote. El workflow de Flutter ya ejecuta ese archivo. **Estado: código/test publicados, pendiente de ejecutar Flutter dirigido y N1 en VPS.**
- No se modificó lógica de runtime, permisos del manifiesto, backend, claves, flujos nativos ni notificaciones operativas. Estas pruebas no acreditan permisos del sistema en Android físico, ausencia de red, recuperación HTTP real ni una UX nativa completa. Son gates posteriores de B2.


## 06/11/2026 — B2-B Flutter dirigido PASS, N1 sin recibo

Operador aporta `vencira-b2b-flutter.log`: `flutter pub get` completo; `flutter test test/device_notice_startup_gate_test.dart` ejecutó los **10 tests y terminó `All tests passed!`**. Las cuatro pruebas de carreras/reintento de B2-B están incluidas. Se muestran avisos no bloqueantes de 23 paquetes desactualizados respecto de restricciones actuales; no son fallos. **No se ha recibido resultado N1 ni SHA local**, así que declarar `B2_B_FLUTTER=PASS`, `B2_B_N1=NOT_EVIDENCED`, `B2_B_INTEGRAL=PENDING`. Sin alteraciones operativas, APK nueva ni despliegue.


## 06/11/2026 — B2-B PASS de suites aportadas

Evidencia del operador: log Flutter `vencira-b2b-flutter.log` / `vencira-b2b-flutter(1).log` con `All tests passed!`, 10/10 tests de barrera de arranque incluyendo las 4 regresiones B2-B. Log N1 `vencira-b2b-n1.log` con `N1_STATIC_android_beta_b2b_startup_recovery_regressions=OK`, `N1_STATIC_android_beta_release_signing_external_only=OK` y `N1_STATIC_GATE_RESULT=OK`. **B2_B=PASS_LOCAL_EN_SUITES_APORTADAS**. No consta HEAD exacto del lote ni código de salida N1 en el archivo, pero sí marcador final del propio gate. No se han ejecutado permisos Android físicos, modo sin conexión o recovery nativo operativo; no confundir con beta. No requiere repetir Flutter ni N1 salvo cambios pertinentes.


## 06/11/2026 — B2-C avance parcial: errores de red en transporte candidato

- Publicadas dos pruebas Flutter adicionales en `clients/flutter/test/native_api_transport_test.dart` (commit `d70638a1`): error de red sin renovación especulativa de credenciales y fallo de transporte después de revocación local sin reabrir el fence.
- **Pendiente ejecución local** de esas pruebas. No hay prueba física Android ni permiso del sistema verificado en este lote.
- El intento de publicar dos nuevas pruebas de recuperación offline de avisos en `test/device_notice_transaction_test.dart` fue bloqueado por controles de seguridad del conector: no están publicadas ni ensayadas, y no se intentará eludir el bloqueo.
- El diseño actual de permisos continúa sin activación operacional. B2-C no está terminado. `MFA_RELEASE_AUTHORIZED=NO` y `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


## 06/11/2026 — B2-C transporte Flutter PASS local (alcance parcial)

Resultado textual aportado por operador: `B2_C_FLUTTER=0`, `All tests passed!`, **13/13 pruebas** de `test/native_api_transport_test.dart`. Incluye las dos nuevas: `Offline transport fails without redirect or speculative credential refresh` y `Offline failure after logout cannot reactivate an old session`. Confirmadas las regresiones de rechazo de redirects, validación de tokens, respuesta tras logout, límites de respuesta y timeouts. No se adjuntó `B2_C_HEAD` ni se ejecutaron N1/Gradle/Android físico en este recibo. **B2_C_TRANSPORT=PASS_LOCAL**, **B2_C_INTEGRAL=PENDING**: faltan permisos OS, recuperación de avisos locales y UAT físico. No repetir esta suite salvo modificación relevante. Autenticación nativa operativa no habilitada.


## 06/11/2026 — B2-C permisos Android/reinicio: inventario estático publicado

- Revisión del manifiesto principal y del código del plugin `flutter_local_notifications 22.3.3`: VENCIRA no declara hoy receptores de alarmas programadas tras reinicio, y el adaptador de programación no está conectado a `main.dart`. El consentimiento de avisos y el chequeo `areNotificationsEnabled()` existen, pero el sistema operativo NO se ha probado físicamente. El permiso `POST_NOTIFICATIONS` puede ser aportado por el manifiesto del plugin; no se ha inspeccionado el manifiesto fusionado de la APK. No inferir ausencia o presencia del permiso final solo del manifiesto de la app.
- La documentación oficial del plugin requiere configurar permiso `RECEIVE_BOOT_COMPLETED` y receptores de notificaciones programadas para reprogramación tras reinicio. Android 13+ requiere permiso de notificaciones en tiempo de ejecución: <https://pub.dev/packages/flutter_local_notifications> y <https://developer.android.com/develop/ui/compose/notifications/notification-permission>.
- Se publican `scripts/b2c_android_notification_boundary.py` (inspector fuente de solo lectura) y `scripts/test_b2c_android_notification_boundary.py` (6 tests) con gate N1 `android_beta_b2c_permission_and_reboot_guard`. El control impide dar por inadvertida la exposición de receptores/privilegios de alarmas exactas, la eliminación del chequeo OS o un cambio del rollout a `true`. **Este gate es temporal de no-activación**: cuando se autorice realmente el producto de avisos, debe reemplazarse por revisiones de permisos, manifiesto fusionado, pruebas físicas y runbook de reboot.
- **CODE=PUBLISHED, LOCAL=NOT_RUN**. No se ha solicitado permiso al móvil ni activado el scheduling; no se ha modificado el manifiesto, la configuración de Gradle, las rutas, el backend, ni la base persistente.
- El intento anterior de nuevas pruebas de recuperación de alarmas locales en `test/device_notice_transaction_test.dart` fue bloqueado por el conector y continúa sin publicar; no intentar eludir ese control.


## 06/11/2026 — B2-C auditoría de permisos Android, sin activar funciones

- Inspección de fuentes: `android_local_alarm_port.dart` consulta `areNotificationsEnabled()` antes de programar y exige opt-in + inventario cifrado; `DeviceNoticeSessionCoordinator` conserva `nativeRolloutApproved=false` por defecto, y `main.dart` no monta el programador de avisos.
- `clients/flutter/android/app/src/main/AndroidManifest.xml` declara `INTERNET`, pero no declara explícitamente `POST_NOTIFICATIONS` ni `RECEIVE_BOOT_COMPLETED` ni receivers de reprogramación. El plugin `flutter_local_notifications` puede aportar `POST_NOTIFICATIONS` durante la fusión del manifiesto: **no equiparar manifiesto fuente con manifiesto fusionado ni declarar permiso ausente en APK**.
- Android 13+ requiere consentimiento de notificación del sistema. La librería Flutter expone solicitud explícita; el código revisado no monta ese flujo desde `main.dart`. Reprogramar después de reiniciar necesita configuración Android adicional y ensayo físico, no deducible de tests unitarios.
- Publicado auditor de fuentes `scripts/android_beta_notification_readiness.py` y dos pruebas `scripts/test_android_beta_notification_readiness.py`. Su éxito únicamente verifica el reporte estático, **no** el permiso real ni funcionamiento en teléfono. No contienen secretos, no generan APK ni cambian manifest, rutas, backend o entorno.
- Pendiente de ejecución local: pruebas del auditor + informe. Pendiente posterior: inspeccionar el AndroidManifest fusionado de un APK aislado y realizar campaña Android 13+ conceder / denegar / retirar permiso, reinicio, almacenamiento seguro y cancelación, solo con datos ficticios y rollout desactivado. B2-C sigue abierto.

Referencias técnicas: [Android Developers — permission for notifications](https://developer.android.com/develop/ui/compose/notifications/notification-permission), [flutter_local_notifications — Android manifest setup](https://pub.dev/packages/flutter_local_notifications).


## 06/11/2026 — B2-C auditor de fuentes PASS local, permisos físicos pendientes

Salida del operador: `Ran 2 tests in 0.000s`, `OK`, `B2_C_AUDIT_TESTS=0`, `B2_C_AUDIT_RESULT=0`, `B2_C_ANDROID_READINESS_AUDIT=PASS_READONLY`. Informe: `APP_MANIFEST_POST_NOTIFICATIONS=NO`, `APP_MANIFEST_BOOT_PERMISSION=NO`, `APP_MANIFEST_BOOT_RECEIVERS=NO`, `OS_PERMISSION_PREFLIGHT_IN_ALARM_PORT=YES`, `EXPLICIT_OPT_IN_GATE_IN_COORDINATOR=YES`, `NATIVE_NOTICE_ROLLOUT_WIRED_TO_MAIN=NO`, `RUNTIME_OS_PERMISSION_REQUEST_IN_MAIN=NO`. El propio informe indica `OS_PERMISSION_ON_DEVICE=NOT_VERIFIED`, `MERGED_ANDROID_MANIFEST=NOT_VERIFIED`, `REBOOT_RESCHEDULE_ON_DEVICE=NOT_VERIFIED`. Los saltos de línea de algunos marcadores se pegaron unidos, pero sus nombres y valores son legibles. **B2_C_AUDIT=PASS_LOCAL; B2_C_INTEGRAL=PENDING**. Sin HEAD concreto en la salida. No se modificaron la aplicación operativa, las rutas ni la BD persistente.


## 06/11/2026 — B2-D inventario del APK compilado, pendiente de ejecución VPS

- Código publicado: `scripts/b2d_apk_manifest_audit.py` inspecciona mediante `aapt dump badging/permissions/xmltree` un **APK G13 debug ya compilado**. Rechaza explícitamente cualquier identificador distinto de `es.vencira.vencira.g13lab`; no ejecuta Gradle, no instala APK y no se conecta a un teléfono ni al backend.
- Extrae del **manifiesto fusionado** las declaraciones `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, permisos exact-alarm y receivers de programación/reinicio. Su resultado `DECLARED` solo representa presencia en binario: **no es consentimiento ni prueba de ejecución en Android físico**.
- Cuatro tests sintéticos `scripts/test_b2d_apk_manifest_audit.py` cubren permisos de plugins en manifiesto fusionado, no inferir permisos a partir de receivers, rechazo de paquetes no G13 y exact alarms sin afirmar concesión del sistema. Pendientes de ejecución local junto a inspección real del APK G13.
- El APK G13 incluye una CA TLS efímera de pruebas; el inspector **no** imprime contenido del APK, certificados o claves. Si el APK G13 ya no existe, la auditoría no debe iniciar G13 automáticamente: reconstruirlo requeriría una campaña separada con fixture efímero.
- Gate posterior físico, no disponible todavía: conceder, denegar y retirar permiso Android 13+; reinicio, restauración/cancelación de alarmas, sincronización aislada sin datos reales. El cliente actual no habilita la programación nativa. `B2_D=NOT_VERIFIED` hasta evidencia.


## 06/11/2026 — B2-D inspección de manifiesto APK G13 PASS_READONLY

Recibo textual del operador: `B2_D_PACKAGE=es.vencira.vencira.g13lab`, `B2_D_PERMISSION_POST_NOTIFICATIONS=DECLARED`, `B2_D_PERMISSION_RECEIVE_BOOT_COMPLETED=NOT_DECLARED`, `B2_D_PERMISSION_SCHEDULE_EXACT_ALARM=NOT_DECLARED`, `B2_D_PERMISSION_USE_EXACT_ALARM=NOT_DECLARED`, `B2_D_BOOT_RECEIVER=NOT_DECLARED`, `B2_D_SCHEDULED_RECEIVER=NOT_DECLARED`, `B2_D_MANIFEST_AUDIT=PASS_READONLY`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`. `OS_PERMISSION_GRANTED=NOT_VERIFIED`, `REBOOT_RESCHEDULE_ON_PHONE=NOT_VERIFIED`. El permiso `POST_NOTIFICATIONS` aparece en el **manifiesto fusionado del APK debug G13**, pese a no declararse en el manifiesto fuente de la aplicación. Ausencia de receptores no representa regresión de G13 porque este APK prueba HTTPS, no programación nativa de avisos.

**Evidencia cerrada:** `B2_D_COMPILED_MANIFEST_G13=PASS_READONLY`. **No evidenciado en este recibo:** salida de las cuatro pruebas unitarias del inspector, HEAD del checkout, código final de salida del comando, permiso del sistema concedido ni reinicio y reprogramación real. **B2_D_INTEGRAL=PENDING**: la siguiente campaña necesita una APK *específica* de notificaciones sintéticas, aislada y sin acceso real, con permisos explícitos y receivers auditados; no reutilizar G13 como prueba de entrega de avisos y no activar producción.


## 06/11/2026 — B2-E: laboratorio físico G15 agrupado (publicado, no ejecutado)

Se publica una **APK debug aislada** de notificaciones sintéticas, distinta de G8/G12/G13 y de la app operativa. El paquete Android es `es.vencira.vencira.g15lab`, activado solo con `VENCIRA_G15_LAB_BUILD=1` y `--dart-define=VENCIRA_G15_LAB_BUILD=true`, excluido de compilaciones `release/profile`. `main.dart` no importa el módulo G15.

Cambios agrupados:
- `clients/flutter/lib/g15_lab_main.dart`: interfaz manual para solicitar permiso, revisar permiso actual, programar aviso sintético a +15 minutos, consultar cola y cancelar. Denegación/retirada exige volver a solicitar permiso desde la propia interfaz. Sin usuario, red, token ni contenido de clientes; el sistema operativo puede retrasar la entrega por optimización de batería.
- `clients/flutter/lib/g15_lab/physical_notice_checks.dart`: plugin real Android, guardas de plataforma/debug, opt-in expreso, comprobación del permiso de sistema antes de programar, zona Europe/Madrid, ID fijo, aviso inexacto y operación de cancelación disponible incluso tras revocación.
- `clients/flutter/android/app/src/g15lab/AndroidManifest.xml`: overlay **exclusivo de G15** con `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `ScheduledNotificationReceiver` y `ScheduledNotificationBootReceiver`; sin solicitar privilegios de alarmas exactas. `build.gradle.kts` selecciona el overlay solo durante esta compilación debug aislada.
- `scripts/test_g15_lab_boundary.py`: 4 pruebas fuente/parser; `scripts/g15_apk_manifest_gate.py`: comprueba el manifiesto fusionado y rechaza paquetes ajenos, receptores ausentes o permisos exact-alarm; `scripts/g15_phone_apk_build.sh`: N1 + pruebas + analyzer Flutter + build debug + `aapt` + SHA256.
- `.github/workflows/g15-android-notifications-lab.yml`: CI aislado, sube únicamente APK debug y SHA256 para ensayos en Android físico; no despliega servidor.
- N1: `g15_notification_lab_debug_only`, para exigir el aislamiento.

**Estado inicial: `G15_BUILD=NOT_VERIFIED`; `G15_PHYSICAL=NOT_VERIFIED`.** No afirmar compilación ni entrega del aviso sin logs. El ensayo tras reinicio requiere un teléfono real y verificación del permiso del sistema y del aviso recibido, no solo `pendingNotificationRequests()`. Reiniciar el teléfono puede retrasar la notificación; el ensayo no garantiza puntualidad. Se debe cancelar el aviso sintético al finalizar y no usar datos reales.

Aun con G15 PASS, B2 integral y beta privada siguen bloqueados por contrato de sesión/identidad G14-E2 y restantes gates. `MFA_RELEASE_AUTHORIZED=NO`; `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


**Refuerzo de aislamiento G15:** overlay Android `tools:node="remove"` elimina el permiso heredado `INTERNET`; el gate del APK fusionado exige `G15_INTERNET_PERMISSION=ABSENT`. Esta condición está publicada, **pendiente de compilar y verificar**: no afirmar que el permiso se eliminó realmente hasta `G15_MANIFEST_GATE=PASS`. Si Gradle/Flutter no permite la eliminación, el build debe FALLAR sin distribuir APK. Corrección del parser de permiso INTERNET: commit `b42aa3df`.


## 06/11/2026 — G15 primer ensayo bloqueado por N1 heredado; corrección publicada

El operador ejecutó G15 en `HEAD=b30bc8678`: `G15_BUILD_RESULT=1`, `N1_STATIC_GATE_RESULT=FAIL`; solo dos controles fallaron: `N1_STATIC_g12_physical_android_offline_auth_isolated=FAIL` y `N1_STATIC_g13_android_real_tls_usb_only=FAIL`. Ambos comparaban literalmente la lista antigua de tres flags (`g8/g12/g13`) en Gradle. La variante G15 extendió la exclusión mutua a cuatro flags (`g8/g12/g13/g15`), por lo que **el guard N1 quedó obsoleto** aunque la exclusión mutua siguió activa. Corrección publicada en `180a7932`: los dos controles N1 exigen ahora explícitamente la nueva lista con cuatro laboratorios; no se elimina ninguna prueba, aislamiento, protección de release ni condición de fallo. **Nueva ejecución N1/build/manifest pendiente.** No interpretar el primer fallo como compilación Gradle fallida, porque el runner terminó antes de Flutter. El mensaje intermedio de `sudo` sobre una contraseña errónea es independiente del fallo N1, pues Docker llegó a ejecutar el gate.


## 06/11/2026 — G15 N1 PASS, fixture de tests corregido

Operador ejecutó desde `HEAD=ffff45ada`: `G15_N1_RESULT=0`, `N1_STATIC_g12_physical_android_offline_auth_isolated=OK`, `N1_STATIC_g13_android_real_tls_usb_only=OK`, `N1_STATIC_g15_notification_lab_debug_only=OK`, `N1_STATIC_GATE_RESULT=OK`. El build detuvo en `scripts/test_g15_lab_boundary.py` (4 tests, 1 error), porque el fixture `test_compiled_gate_accepts_only_laboratory_package` solo pasaba nombres abreviados `ScheduledNotificationReceiver` y `ScheduledNotificationBootReceiver`, mientras `g15_apk_manifest_gate.verify` exige **nombres completos** `com.dexterous.flutterlocalnotifications.*`. Se corrigió únicamente el fixture de ensayo (commit `f68a8b29`), manteniendo la exigencia estricta del manifiesto real. **No hay evidencia de Flutter analyze, APK ni aapt**; repetir solo el bloque de G15 tras actualizar rama. `MFA_RELEASE_AUTHORIZED=NO`; `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


## 06/11/2026 — G15 build y manifiesto compilado PASS local

El operador confirma `Ran 4 tests in 0.002s; OK`, `G15_UNIT_TESTS=0`, `G15_BUILD_RESULT=0`, `N1_STATIC_GATE_RESULT=OK`, `Built build/app/outputs/flutter-apk/app-debug.apk`, `G15_APK_PACKAGE=es.vencira.vencira.g15lab`, `G15_POST_NOTIFICATIONS_DECLARED=OK`, `G15_BOOT_RECEIVER_DECLARED=OK`, `G15_SCHEDULE_RECEIVER_DECLARED=OK`, `G15_EXACT_ALARM_PERMISSIONS=ABSENT`, `G15_INTERNET_PERMISSION=ABSENT`, `G15_MANIFEST_GATE=PASS`, `G15_ANDROID_APK_BUILD=OK`, `G15_RELEASE_AUTHORIZED=NO`. El APK está en `clients/flutter/build/g15-phone/VENCIRA-G15-LAB-debug.apk` con .sha256 al lado. **G15_SOURCE_BUILD_AND_MERGED_MANIFEST=PASS_LOCAL**. El mensaje no contiene SHA HEAD de la compilación ni evidencia de que un teléfono haya ejecutado la APK. **G15_ANDROID_PHYSICAL=NOT_VERIFIED**. Pruebas físicas pendientes: permiso concedido/denegado, programación sin Internet, entrega no exacta, cancelación tras revocación de permiso, reinicio de teléfono con aviso en cola y reprogramación Android. Todo con datos sintéticos. Ninguna autorización de beta real ni despliegue.
