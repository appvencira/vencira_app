# D1.5p — QR local y controles operativos (gate PENDIENTE)

Rama `integration/local-e2e-prep`. Se incorpora `qr_flutter:^4.1.0` como renderizador QR totalmente local en Flutter; el contenido es exclusivamente la URI `otpauth://` devuelta por la API, que incluye el secreto TOTP. Nunca transmitir a un generador externo ni imprimir en logs. El QR se presenta junto a la clave de configuración manual en `MfaSetupScreen`, y se elimina del estado del widget al avanzar a los códigos de recuperación. **Atención:** el renderizador local muestra secreto en pantalla y cualquier captura o sesión remota podría exponerlo. Evitar analítica y almacenamiento del secreto.

El acceso al asistente sigue oculto por defecto (`VENCIRA_MFA_UI_ENABLED=false`) y el alta backend continúa deshabilitada (`VENCIRA_MFA_ENROLLMENT_ENABLED=0`). Estas flags no deben activarse en despliegues actuales.

Gate: `scripts/validate_o7_o8_preflight.sh`: Django SQLite y PostgreSQL 17 temporal + Flutter analyze/test/build. La adición de dependencia modifica resolución de paquetes; verificar build íntegro y compatibilidad sin tocar entornos persistentes. **No marcar validado antes del gate.**

Bloqueos restantes: custodia de claves Fernet fuera de servidor/Drive y recuperación probada; recuperación de acceso si se pierden todos los factores; estrategia de rollback sin omitir MFA; validación Android/PC visual y pruebas widget QR/ES/CA; revisar límites por IP/proxy. No aplicar migraciones 0019–0021 a PostgreSQL persistente ni desplegar.
