# VENCIRA — M3-02: regresión integral de acciones de avisos (01/11/2026)

## Bloque funcional
**Cliente HTTP Flutter:** `HttpVenciraApi.updateOperationalReminder` verifica el UUID exacto solicitado, estados internos admitidos, fecha civil ISO canónica y `delivery_status=not_implemented` antes de considerar una acción aceptada. Conserva el límite informativo de repetición de control al construir el resultado; no lo eleva a autorización legal ni a prueba de envío.

**Pruebas HTTP Django:** ampliado `backend/reminders/test_operational_api.py` con secuencia `tomorrow → bandeja`, auditoría del usuario, idempotencia, bloqueo de anotación cerrada y prohibición del límite civil tanto en `tomorrow` como en `another_day`. Incluidas en las dos bases de prueba de GitHub Actions.

**Pruebas HTTP Flutter:** nuevo `clients/flutter/test/operational_action_http_test.dart` usa `http.MockClient` para petición con CSRF y contrato de acción, rechazo de identidad distinta, estado inválido, indicador de entrega falso, fechas inválidas, conflicto CAS 409 y pérdida de autorización 403. No realiza conexiones a DEV.

## Evidencia de GitHub Actions
- PR de revisión: https://github.com/appvencira/vencira_app/pull/14 (**draft**; no merge).
- Código validado: commit `a20785b46b2e05c7b1bf05f5a67f191434e96fa1`.
- Workflow M3 run **41306535920**:
  - Django/SQLite, job `124847960586`: **48 tests, OK**.
  - Django/PostgreSQL17 efímero, job `124847960793`: **48 tests, OK**.
  - Flutter, job `124847960802`: `flutter analyze` **No issues found**; **16 tests passed**; `flutter build web --release --pwa-strategy=none` **Built build/web**.
  - Conclusión de los tres jobs: **success**.
- Workflow MB1 run **41306536025**: **success**, limitado a auditoría estática/contratos.

### Incidencia detectada y resuelta
El primer `flutter analyze` del nuevo test HTTP falló por usar `Request.uri`; la API real expone `Request.url`. Corregido en commit `a20785b` y reejecutada toda la CI con resultados PASS.

## Límite del avance
Esto certifica contratos de operaciones HTTP con Django/PG17 en CI y un cliente HTTP Flutter simulado; no demuestra notificaciones entregadas, ejecución Android físico, accesibilidad completa, reconciliación con el servidor en producción, custodia externa ni congelación global de escritores. Tampoco constituye aprobación legal de reglas de cada póliza.

**M3-02 [ ]**. Estado formal **2/15 (13,3 %)**. Dev y datos persistentes sin cambios; sin despliegue, sin MFA release ni C-FICHA release.
