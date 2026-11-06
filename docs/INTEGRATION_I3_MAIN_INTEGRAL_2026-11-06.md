# I3 — Gate integral de integración desde main

Fecha: 2026-11-06

## Objetivo
Validar el conjunto consolidado de Django, Flutter, C-FICHA y laboratorios nativos sin activar servicios incompletos ni tocar el VPS.

Base de integración: `main` después de PR #25 (`6c1b8a8d0a2072c6f1cf9b72bdc77eaf1798e30c`).

## CI añadido
`.github/workflows/i3-integral-main.yml` ejecuta cuatro trabajos independientes:
1. Django + SQLite de tests: arranque, revisión de modelos/migraciones, calendario, dominio de negocio, permisos, MFA actual, adjuntos denegados y ausencia de apps experimentales en modo normal.
2. Django + PostgreSQL 17 efímero del runner: `manage.py check`, `makemigrations --check --dry-run`, suite de API/tenancy/permisos/MFA/adjuntos. PostgreSQL no es la base del VPS.
3. Flutter estable: `flutter analyze`, pruebas dirigidas de UI/API, cierre de sesión, laboratorio Android inactivo y `flutter build web --release --pwa-strategy=none` sin publicación.
4. Gate informativo de bloqueo de autorización de despliegue.

Todos los valores usados para Django y PG17 son **sintéticos, exclusivos de CI**. No hay conexión al servidor DEV ni instalación de credenciales reales. Las pruebas usan únicamente bases desechables. No se usa `migrate` contra una base persistente. El archivo de migraciones `reminders.0027` existe como código, pero eso NO significa aplicado a producción.

## Qué NO demuestra
- No son pruebas end-to-end reales navegador ↔ HTTPS ↔ Django ↔ DB productiva ni se instala una APK en Android.
- No se habilita login nativo, refresh MFA productivo, adjuntos reales, recuperación ni despliegue.
- No pretende cubrir todas las suites históricas offline/PG17/race/ClamAV; requieren ensayos específicos y sus resultados ya documentados.
- Un compilado Flutter Web sin publicación no es autorización de release. Un gate CI verde no autoriza poner tablas nuevas en la BD del VPS.

## Criterio de aceptación
Todos los jobs de este HEAD deben finalizar `success`. Si hay un fallo, diagnosticar antes de fusionar. La PR de I3 no se fusionará ni declarará PASS solo por su creación.

`NO_DEPLOY_NO_LIVE_MIGRATION=1`
`MFA_RELEASE_AUTHORIZED=NO`
`MB1_RELEASE_AUTHORIZED=NO`
`C_FICHA_RELEASE_AUTHORIZED=NO`
