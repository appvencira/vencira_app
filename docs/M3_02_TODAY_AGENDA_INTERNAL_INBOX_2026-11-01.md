# VENCIRA — M3-02: «Hoy» enlazado con avisos internos pendientes (01/11/2026)

## Objetivo y alcance
El whitepaper §5 exige agenda de Hoy como vista de trabajo; el §7 exige ver avisos pendientes. La agenda ya consultaba eventos previstos, pero no ofrecía acceso a la **bandeja operativa real de hoy y atrasados**. Este bloque incorpora en la agenda diaria un acceso compacto, sin jobs ni envíos externos.

## Funcionalidad publicada
- `clients/flutter/lib/ui/day_agenda_screen.dart`: solo cuando el día seleccionado es **hoy** se consulta `VenciraApi.fetchOperationalInbox(workspace.id, today, scope:'due')`, API de lectura autenticada y acotada por permisos. Se presenta **atrasados + hoy**, con denominación explícita «Toda la cuenta» porque los filtros de modalidad/aseguradora de la agenda no filtran este contador global.
- Un acceso abre `VenciraOperationalInboxScreen` existente, desde el que se pueden resolver o reprogramar avisos internos. Al volver se relee día y contador. El contador no se obtiene de candidatos ni de notificaciones enviadas.
- Estados independientes de carga, error, reintento, falta de autorización y cambio de día. No se conservan cifras viejas al refrescar. `_todayInboxGeneration` impide que una respuesta tardía de hoy reaparezca tras elegir otro día. En fechas distintas de hoy no se consulta ni representa el resumen.
- Cadenas ES/CA incorporadas en ARB, sin literales de producto incrustados en Dart.

## Pruebas previstas y CI
`clients/flutter/test/agenda_today_inbox_test.dart`: tres pruebas de widget para contador autorizado, error+reintento y respuesta tardía tras navegar a otro día. `.github/workflows/m3-product-contracts.yml` incorpora estos tests. Para evitar ejecuciones dobles se eliminó `push` sobre rama feature (sigue `pull_request`), y se configura concurrencia sin cancelación automática.

**Resultado final de CI confirmado por logs de GitHub Actions:** después de dos cancelaciones y un test de widget demasiado amplio (`find.text('1')` también coincidía con la fecha), se acotó la aserción al `Text` con clave `agenda-due-count`. La última ejecución de revisión quedó íntegramente verde:

| Evidencia | Run / job | Resultado |
|---|---|---|
| Django SQLite temporal | `41307549429` / `124851050180` | **62/62 PASS** |
| Django PostgreSQL17 temporal | `41307549429` / `124851050445` | **62/62 PASS** |
| Flutter `analyze` | `41307549429` / `124851050383` | **No issues found** |
| Flutter widgets y contratos (agenda diaria incluida) | `41307549429` / `124851050383` | **49/49 PASS** |
| Flutter Web release `--pwa-strategy=none` | `41307549429` / `124851050383` | **Built build/web** |

Commit de código validado: `0b6b9aa4b7b4f562f646ec5f729cc1623f9c00ce`. PR #14 sigue **draft**. Auditoría MB1 `41307549434` success, contrato estático; no freeze operativo.

Estos tests comprueban flujo de widgets y temporales de CI, **no** validación con navegador en DEV, Android físico, permisos push, envío en segundo plano ni entrega de notificaciones. Ningún requisito de release se considera satisfecho automáticamente.

## Restricciones
- Ninguna notificación externa ni prueba de entrega, ninguna nueva migración, ningún trabajo en background o despliegue DEV.
- `M3-02` abierto hasta completar V1 y aceptación en dispositivo; `M3-03` y `M3-04` abiertos.
- Progreso formal **2/15 = 13,3 %**.
- `MB1_GLOBAL_FREEZE=NOT_VERIFIED`, `MB1_RELEASE_AUTHORIZED=NO`, `MFA_RELEASE_AUTHORIZED=NO`, `C_FICHA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

PR aislada en borrador: https://github.com/appvencira/vencira_app/pull/14
