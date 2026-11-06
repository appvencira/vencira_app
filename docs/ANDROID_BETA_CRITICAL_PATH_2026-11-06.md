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
