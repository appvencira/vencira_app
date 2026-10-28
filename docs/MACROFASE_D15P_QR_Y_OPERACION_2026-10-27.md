# D1.5p — QR local y controles operativos (gate PENDIENTE)

Rama `integration/local-e2e-prep`. Se incorpora `qr_flutter:^4.1.0` como renderizador QR totalmente local en Flutter; el contenido es exclusivamente la URI `otpauth://` devuelta por la API, que incluye el secreto TOTP. Nunca transmitir a un generador externo ni imprimir en logs. El QR se presenta junto a la clave de configuración manual en `MfaSetupScreen`, y se elimina del estado del widget al avanzar a los códigos de recuperación. **Atención:** el renderizador local muestra secreto en pantalla y cualquier captura o sesión remota podría exponerlo. Evitar analítica y almacenamiento del secreto.

El acceso al asistente sigue oculto por defecto (`VENCIRA_MFA_UI_ENABLED=false`) y el alta backend continúa deshabilitada (`VENCIRA_MFA_ENROLLMENT_ENABLED=0`). Estas flags no deben activarse en despliegues actuales.

Gate: `scripts/validate_o7_o8_preflight.sh`: Django SQLite y PostgreSQL 17 temporal + Flutter analyze/test/build. La adición de dependencia modifica resolución de paquetes; verificar build íntegro y compatibilidad sin tocar entornos persistentes. **No marcar validado antes del gate.**

Bloqueos restantes: custodia de claves Fernet fuera de servidor/Drive y recuperación probada; recuperación de acceso si se pierden todos los factores; estrategia de rollback sin omitir MFA; validación Android/PC visual y pruebas widget QR/ES/CA; revisar límites por IP/proxy. No aplicar migraciones 0019–0021 a PostgreSQL persistente ni desplegar.


## Gate D1.5p — APROBADO (27/10/2026)

Salida del operador: `LOCALCHECK_HEALTH_PRE=OK`, `CONFIG_COMPOSE=OK`, `I18N_ES_CA=OK`, `BUILD_BACKEND_AISLADO=OK`, `DJANGO_CHECK_MIGRACION_SECA=OK`, `DJANGO_SQLITE_SUITE_COMPLETA=OK`, `PG17_TEMPORAL=OK`, `DJANGO_POSTGRES17_SUITE_COMPLETA=OK`, `FLUTTER_ANALYZE_TEST_BUILD=OK`, `LOCALCHECK_HEALTH_POST=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_D1_5P=0`. Log local `/tmp/vencira-o7-o8-preflight.b7g8Damm.log`. Sin despliegue ni migraciones persistentes, sin cambios en OAuth/Restic/Caddy. Validación visual de QR Android y PC, custodia/restitución de claves y recuperación de pérdida total de factores siguen pendientes; alta MFA desactivada.
