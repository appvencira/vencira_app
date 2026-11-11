# D17 — evidencia visual Android candidato main; native auth bloqueado por diseño

Fecha: 11/11/2026. Evidencia: dos capturas compartidas por operador; sin logs de backend, sin prueba de autenticación ni medición de HTTPS desde el proceso nativo.

## Observaciones confirmadas

1. El APK Android abre una pantalla titulada VENCIRA / Acceso seguro a VENCIRA. Explica que el inicio de sesión seguro nativo no está disponible y ofrece **Abrir VENCIRA en el navegador**. El botón lleva al navegador del sistema.
2. Chrome muestra `dev.vencira.es` con página **Agenda diaria**, miércoles 11 de noviembre de 2026, selector de días, filtros, acceso a mes, avisos internos y anotaciones vacías. La captura confirma representación visual de esa página en el navegador, no que haya HTTPS pinning o autenticación nativa exitosa.
3. El código real `clients/flutter/lib/main.dart`, compilado en D16 desde `lib/main.dart`, selecciona `AndroidWebAccessScreen` al detectar Android sin inyección de API, mientras que `NativeLabLoginShell` solo se habilita bajo `!kReleaseMode` y coordinador inyectado. `clients/flutter/lib/ui/android_web_access_screen.dart` abre explícitamente `https://dev.vencira.es/` mediante `LaunchMode.externalApplication`. Por tanto, el comportamiento observado es exactamente el actual por diseño, **no un fallo de compilación ni una pantalla de carga bloqueada**.

## Estado del gate

`D17_ANDROID_APP_LAUNCH_VISUAL=PASS` (evidencia visual)
`D17_EXTERNAL_WEB_HANDOFF_VISUAL=PASS` (dos capturas, atribución de navegación coherente)
`D17_NATIVE_AUTHENTICATED_LOGIN=NOT_IMPLEMENTED`
`D17_NATIVE_HTTPS_SESSION_VERIFIED=NO`
`D17_NATIVE_KEYSTORE_REAL_APP_VERIFIED=NO`
`D17_RELEASE_SIGNING_VERIFIED=NO`
`D17_RELEASE_AUTHORIZED=NO`
`MFA_RELEASE_AUTHORIZED=NO`
`NO_DEPLOY_NO_LIVE_MIGRATION=1`

**Conclusión:** no prometer acceso nativo porque existen pruebas de I8-P, I8-Q o G13 con aplicaciones LAB. El binario D16 de producción no contiene todavía el emisor de sesión segura nativa integrado en su pantalla normal. Habilitar o reutilizar el login de laboratorio sin completar el contrato de emisión/almacenamiento/recuperación y la validación en entorno autorizado rompería el fence de seguridad.

## Próxima decisión técnica

Revisar arquitectura de los adaptadores `NativeSessionCoordinator`, almacén seguro y emisor Django: añadir un camino de autenticación real **explícitamente habilitado únicamente tras una prueba de seguridad completa**, o mantener Android como lanzador web hasta disponer de ese contrato. No modificar por estética el mensaje de estado para que aparentara una capacidad inexistente. La URL `dev.vencira.es` solo sirve para desarrollo, no constituye dominio de distribución final.
