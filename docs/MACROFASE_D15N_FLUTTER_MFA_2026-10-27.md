# D1.5n — Asistente MFA Flutter (gate PENDIENTE)

Implementado en rama `integration/local-e2e-prep`:
- `clients/flutter/lib/api/vencira_api.dart`: métodos POST same-origin y CSRF para preparar TOTP, confirmar el código y demostrar posesión de un código de recuperación.
- `clients/flutter/lib/ui/mfa_setup_screen.dart`: asistente responsive ES/CA con reautenticación por contraseña, clave TOTP de configuración manual, comprobación TOTP, lista de diez códigos seleccionables en memoria, casilla de custodia, prueba de posesión y pantalla final.
- `clients/flutter/lib/ui/dashboard_screen.dart`: acceso desde Ajustes/Seguridad **oculto por defecto** con `const bool.fromEnvironment('VENCIRA_MFA_UI_ENABLED', defaultValue: false)`. El backend sigue cerrado con `VENCIRA_MFA_ENROLLMENT_ENABLED=0`.

**Limitaciones conscientes:** QR todavía no generado; configuración manual TOTP sí implementada. No guardar secreto ni códigos en logs o almacenamiento local. No habilitar flag Flutter en el despliegue regular ni backend hasta supervisión visual Android/escritorio, pruebas widget específicas, manejo de red interrumpida, custodia/rotación de claves y recuperación administrativa segura. Si falla la entrega de códigos antes del paso ACK, MFA NO queda activo gracias a D1.5m: el usuario puede reiniciar tras contraseña.

Gate necesario: `scripts/validate_o7_o8_preflight.sh` con SQLite/PostgreSQL17 efímero, Flutter analyze/test/build; sin despliegue ni migraciones persistentes 0019–0021.


## Gate D1.5n APROBADO (27/10/2026)

Tras corregir aviso de Flutter `unused_field _uri` (commit `b40d1d92ab8cdb0f94bdebd90846911d56de2a86`), operador confirma: `LOCALCHECK_HEALTH_PRE=OK`, `CONFIG_COMPOSE=OK`, `I18N_ES_CA=OK`, `BUILD_BACKEND_AISLADO=OK`, `DJANGO_CHECK_MIGRACION_SECA=OK`, `DJANGO_SQLITE_SUITE_COMPLETA=OK`, `PG17_TEMPORAL=OK`, `DJANGO_POSTGRES17_SUITE_COMPLETA=OK`, `FLUTTER_ANALYZE_TEST_BUILD=OK`, `LOCALCHECK_HEALTH_POST=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_D1_5N=0`. Log `/tmp/vencira-o7-o8-preflight.WATFuP3J.log`. No desplegado ni migrada DB persistente. MFA backend y UI siguen apagados por defecto. Pendiente QR, pruebas visuales reales y bloqueos operativos (custodia de clave, controles de abuso, recuperación y rollout seguro).
