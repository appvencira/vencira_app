# I2-B2 — Consolidación de backend Django `reminders` desde rama avanzada

## Preparación (06/11/2026)
- Rama nacida de `main` tras PR #21, HEAD base `db46b6b51f093a0ac509a32a203a74cd6792eaac`.
- El árbol de origen `feature/m3-android-local-notifications` commit `2b770626baa98deccbcde1c79e69679447d9a304` se inspeccionó en GitHub (no truncado).
- Se portan **186 archivos** existentes bajo `backend/reminders/` y `backend/templates/`, preservando los 5 archivos ya incorporados en `main` (apps, init y núcleo I1). El total de `reminders` en origen era 189 archivos, a los que se añaden dos plantillas.
- Incluye modelos, servicios, pruebas y el grafo histórico de migraciones 0001–0027 como **archivos de código**; no se han ejecutado ni aplicado migraciones en ningún entorno persistente.
- No se importa ninguna app desde `backend/native_mobile_service/`, `backend/native_sessions_lab/` o `backend/renewal_attachments/`. La configuración Django original solo registra candidatas si `VENCIRA_ENV=test` y el flag específico está habilitado; en el workflow están desactivadas.
- No se cambian secretos, DNS, Caddy, base de datos persistente ni `dev.vencira.es`. No se activa la emisión de tokens MFA ni autenticación nativa operativa.

## Validación y criterios de fusión
Workflow `.github/workflows/i2b2-django-reminders.yml` (CI, SQLite efímera):
1. Instalar dependencias Python del backend.
2. `python backend/manage.py check`.
3. `python backend/manage.py makemigrations --check --dry-run` con configuración test y SQLite aislada.
4. Tests dirigidos de fechas, planificación y API.
5. Gates I1/I2 y aislamiento source del bootstrap.

**Pendiente:** evidencia de resultado del workflow o ejecución equivalente desde este HEAD. No fusionar esta PR sin verificar que Django arranca y que las pruebas terminan bien. El archivo de workflow no es prueba de que se haya ejecutado.

Si estos tests fallan, corregir regresiones en esta rama, no tocar producción. El backend sigue sin haber sido integrado con Flutter.

## Restricciones
`NO_DEPLOY_NO_LIVE_MIGRATION=1` y `MFA_RELEASE_AUTHORIZED=NO`, `MB1_RELEASE_AUTHORIZED=NO`, `C_FICHA_RELEASE_AUTHORIZED=NO`. No ejecutar ninguna migración contra BD persistente, no desplegar automáticamente al fusionar y no tratar tests sintéticos como autorización de beta.
