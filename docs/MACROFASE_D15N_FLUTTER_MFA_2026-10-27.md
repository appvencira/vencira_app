# D1.5n — Asistente MFA Flutter (gate PENDIENTE)

Implementado en rama `integration/local-e2e-prep`:
- `clients/flutter/lib/api/vencira_api.dart`: métodos POST same-origin y CSRF para preparar TOTP, confirmar el código y demostrar posesión de un código de recuperación.
- `clients/flutter/lib/ui/mfa_setup_screen.dart`: asistente responsive ES/CA con reautenticación por contraseña, clave TOTP de configuración manual, comprobación TOTP, lista de diez códigos seleccionables en memoria, casilla de custodia, prueba de posesión y pantalla final.
- `clients/flutter/lib/ui/dashboard_screen.dart`: acceso desde Ajustes/Seguridad **oculto por defecto** con `const bool.fromEnvironment('VENCIRA_MFA_UI_ENABLED', defaultValue: false)`. El backend sigue cerrado con `VENCIRA_MFA_ENROLLMENT_ENABLED=0`.

**Limitaciones conscientes:** QR todavía no generado; configuración manual TOTP sí implementada. No guardar secreto ni códigos en logs o almacenamiento local. No habilitar flag Flutter en el despliegue regular ni backend hasta supervisión visual Android/escritorio, pruebas widget específicas, manejo de red interrumpida, custodia/rotación de claves y recuperación administrativa segura. Si falla la entrega de códigos antes del paso ACK, MFA NO queda activo gracias a D1.5m: el usuario puede reiniciar tras contraseña.

Gate necesario: `scripts/validate_o7_o8_preflight.sh` con SQLite/PostgreSQL17 efímero, Flutter analyze/test/build; sin despliegue ni migraciones persistentes 0019–0021.
