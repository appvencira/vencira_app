# VENCIRA — M3-02: calendario seguro de aplazamientos de control (01/11/2026)

## Cambios funcionales implementados

**Backend Django:** `GET /api/v1/workspaces/{workspace}/operational-inbox/?day=YYYY-MM-DD` incluye `latest_control_repeat_on` por aviso. Se calcula para ocurrencias `control_question=true` y modalidad distinta de `vida` como **un día antes** de `one_month_before(expires_on)` (mes civil). El valor es `null` para avisos ordinarios y pólizas Vida. Consulta solo ocurrencias autorizadas mediante `_visible_renewals`, con `select_related("renewal")`, sin nuevas escrituras ni migraciones. El campo no constituye autorización legal ni evidencia de envío.

**Flutter:** `VenciraOperationalReminder.fromJson` analiza estrictamente la fecha civil opcional y rechaza una fecha malformada o suministrada para un aviso ordinario. En `VenciraOperationalInboxScreen`, las acciones **Mañana** y **Otro día** se deshabilitan para preguntas de control cuando no existe margen o el servidor no proporciona fecha verificada (incluida Vida). `showDatePicker` se limita al mínimo de 365 días y la fecha indicada por el servidor, con mínimo dos días; el cálculo de fecha civil evita desplazamientos DST. Se añade texto de ayuda localizado ES/CA. Las acciones de tarea ordinaria conservan sus intervalos habituales. La API valida de nuevo cualquier POST, por lo que el calendario nunca sustituye al gate del backend.

## Evidencia real de GitHub Actions

- PR **#14** (borrador, no fusionada): https://github.com/appvencira/vencira_app/pull/14
- Commit de código probado: `987f633173125373afe6e737c9e99507b5a92983`
- Run M3: `41305213669`
  - Django, job `124844103654`: **36/36 PASS** (SQLite efímero).
  - Flutter, job `124844103867`: `flutter analyze` **sin errores**, **12/12 tests PASS**.
- Run MB1 estático: `41305213697`: **success**, no acredita corte universal de escritores.

Se agregan pruebas de contrato civil (28/02 y Vida), usuario autorizado/tenant, parser de fechas canónicas, calendario acotado y acciones deshabilitadas.


## Validación ampliada con PostgreSQL17 y compilación Web (misma fecha)

La CI M3 se ha extendido con un contenedor **PostgreSQL 17 Alpine efímero**, independiente de DEV, y un paso `flutter build web --release --pwa-strategy=none`. Los filtros de `pull_request` se han sincronizado con los de `push` para que cambios en la API y widgets no se queden sin ejecutar en futuras revisiones.

- Commit probado: `8eb90746c7273698a46ef846b14edfaf1efd7f14`.
- GitHub Actions run `41305433400`:
  - Job SQLite `124844753066`: **36/36 PASS**, Django check OK.
  - Job PostgreSQL 17 `124844753246`: **36/36 PASS**, Django check OK.
  - Job Flutter `124844753225`: `flutter analyze` **sin problemas**, **12/12 PASS**, `flutter build web --release --pwa-strategy=none` **Built build/web**.
- Todos los jobs finalizaron con `conclusion=success`.

**Límites de esta evidencia:** PostgreSQL de CI utiliza un rol temporal de test, no demuestra separación de roles efectiva en DEV, permisos de producción, congelación universal de escritores ni restauración física; Flutter Web compilado no equivale a publicación ni a aceptación Android/iOS. M3-02 permanece abierto.

## Pendientes y bloqueos

El calendario mejora la experiencia de uso y evita elecciones inviables; **no habilita canales de envío ni acredita cumplimiento legal de pólizas particulares**. Pendiente: CI/PostgreSQL17 representativa, Android físico, pruebas de accesibilidad/UX de múltiples tamaños, permisos operativos, entrega push/email, decisiones excepcionales del whitepaper y aceptación completa M3-02.

**M3-02 sigue pendiente.** Progreso formal **2/15 = 13,3 %**. No despliegues, no migraciones persistentes, sin liberación MFA ni C-FICHA.

```text
M3_02_API_CONTROL_BOUND=PASS_CI_SQLITE
M3_02_FLUTTER_ANALYZE=PASS
M3_02_FLUTTER_WIDGET=PASS_12_OF_12
MB1_STATIC_SECURITY_GATES=PASS
MB1_GLOBAL_FREEZE=NOT_VERIFIED
MB1_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```
