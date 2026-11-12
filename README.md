# VENCIRA

Aplicación de gestión de vencimientos, anotaciones y seguimiento de seguros. No es un CRM genérico.

**Repositorio oficial:** `appvencira/vencira_app`. **Rama de integración:** `main`.

## Estado verificado y límites (12 de noviembre de 2026)

**Stack:** Django 5, PostgreSQL 17 y Flutter web/Android. El desarrollo se incorpora directamente a `main`, en cambios acotados. Un commit en `main` no implica instalación en DEV, integración funcional Android ni autorización de publicación.

| Área | Última evidencia documentada | Límite |
| --- | --- | --- |
| Seguridad móvil I8-M–I8-Q | Laboratorios HTTPS/PG17, Keystore, recuperación/revocación y regresión Flutter | No autoriza MFA operativo |
| Copias O5 / migraciones D1-N | Restauración real O5, migraciones y rollback ensayados sobre PG17 **aislado** | No acredita rollback combinado de imágenes históricas + O5 ni restauración LIVE |
| Recuperación de imágenes D3 / D4 | D3-B5: 3 imágenes importadas; D3-B6C: 46 blobs; D3-B7: coincidencias de roles. D4-B: shells aisladas; D4-C: PG17 archivado con SQL; D4-D: roles API/Web/DB identificados | Identidad histórica Docker exacta, recuperación operativa conjunta y copia externa siguen pendientes |
| D4-E API/Web | API HTTP de laboratorio PASS; primer ensayo HTTP Web FAIL, con diagnóstico/iteraciones posteriores registrados en el runbook D4 | Consultar resultado final del subgate en el runbook antes de declararlo cerrado |
| D28 selector Flutter | Enrutador candidato primer acceso/recuperación: 16/16 pruebas PASS en fase 1 | `main.dart` no conecta login nativo operacional |
| D27 núcleo independiente | Fase 3: **92/92 tests PG17 PASS** (incluye 9 pruebas D27): contraseña→MFA, tokens, access/refresh, replay, revocación de dispositivo y recuperación global atómica | Exige `VENCIRA_ENV=test`; sin emisor HTTP operativo, claves reales custodiadas, Android final ni autorización de release |
| Producto Flutter + backend | Existen implementaciones y ensayos históricos de clientes, vencimientos, calendario, notas, adjuntos y notificaciones | No hay un gate único actualizado que acredite todos los recorridos en la APK final |

**Precaución:** los PASS anteriores son evidencias registradas por el operador y en los runbooks; no constituyen una nueva ejecución ni una auditoría integral del estado operativo del VPS. Revisar las secciones más recientes del documento D4, que acumula una cronología de ensayos y no debe interpretarse por su primera entrada.

## Bloqueos vigentes

El programa **D4** agrupa cinco criterios de cierre: **B1** imágenes archivadas y servicios, **B2** reversión con backup O5, **B3** retención cifrada fuera del VPS, **B4** regresión del SHA candidato final y **B5** preflight y autorización de producción. No confundir pruebas de arranque aisladas con recuperación operacional demostrada.

La transición **D27–D28** necesita contrato y transporte HTTPS para los retos `oc1/or1`, custodia real de secretos, control de identidad IP/proxy, aislamiento y migraciones revisadas, integración Flutter/Android, pruebas físicas y autorización diferenciada. No activar el núcleo quitando sus restricciones de laboratorio.

## Restricciones obligatorias

- `MFA_RELEASE_AUTHORIZED=NO`
- `NO_DEPLOY_NO_LIVE_MIGRATION=1`
- Sin despliegue, migración de bases persistentes, recuperación LIVE ni conexión de emisor nativo en URLconf/`main.dart` sin gates y autorización explícitos.
- Los ensayos de backend utilizan PostgreSQL 17 desechable, aislamiento y secretos sintéticos. Preservar contenedores y datos DEV.
- Integrar cambios directamente a `main`, sin ramas nuevas ni merges indiscriminados; verificar el SHA final.
- Antes de un piloto DEV, exigir control de cambios, backup, reversión y aprobación independiente. La producción se autoriza por separado.

## Próximos trabajos priorizados

1. D27–D28: revisar contrato `oc1/or1`, construir transporte HTTPS **solo en laboratorio** y verificar seguridad de emisión, custodia y antiabuso; no enlazar aún el login Android normal.
2. D4 B1–B3: cerrar ejecución y recuperación **conjunta** de imágenes archivadas con O5 en un entorno aislado, y acreditar una copia externa recuperable.
3. D4 B4: ejecutar regresión backend/PG17 y Flutter `analyze/test/build` sobre un mismo SHA final; después, recorridos funcionales y visuales de APK.
4. D4 B5: preparar piloto DEV reversible y, posteriormente, un preflight de producción distinto.

## Documentación de referencia

- [D4 — gates agrupados de despliegue (cronología actualizada)](docs/operations/D4_GROUPED_DEPLOYMENT_GATES_2026-11-11.md)
- [D27 — núcleo independiente MFA/recuperación y 92 pruebas PG17](docs/operations/D27_INDEPENDENT_PASSWORD_MFA_CORE_PG17_2026-11-12.md)
- [D27–D28 — transición operacional y Flutter](docs/operations/D27_D28_GROUPED_OPERATIONAL_TRANSITION_2026-11-12.md)
- [Plan anterior de trabajo agrupado (8/11; referencia histórica)](docs/REMAINING_WORK_GROUPED_2026-11-08.md)
- [Preparación DEV D1 (referencia histórica)](docs/D1_DEV_DEPLOY_PREPARATION_2026-11-08.md)
- [Política de integración en main](docs/MAIN_INTEGRATION_POLICY_2026-11-08.md)
- [Continuidad 8/11 (histórica)](docs/CONTINUITY_HANDOFF_2026-11-08.md)

**Regla de lectura:** implementación, prueba aislada, integración completa, despliegue y autorización son estados distintos.
