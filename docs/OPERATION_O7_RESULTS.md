# VENCIRA — O7: Resumen de resultados (whitepaper §11, p. 14–15)

**24/10/2026 — Estado:** implementación en código GitHub, **no validada por ejecución en VPS, NO desplegada y NO aceptada manualmente**. Sin migración ni envíos.

## Contrato de producto
La fuente exige resultados de escritorio (no móvil/tablet): periodo **mes / trimestre / año**, «Conseguidas», «No aceptadas», «Descartadas» por **fecha del desenlace** y «Pendientes» por **fecha de vencimiento** de anotaciones aún abiertas. En Equipo contempla total y por usuario; sin embargo §18 declara PENDIENTE si los empleados pueden consultar el resumen. Por seguridad, esta primera entrega solo permite consulta del owner, agregada por cuenta. El desglose por agente requiere decidir si atribuir desenlaces al actor de cierre o al responsable de anotación en ese momento (pueden diferir); no se ha inventado una política.

## Implementación
- `GET /api/v1/workspaces/{uuid}/results/?period=month&year=2027&month=3` (ó `period=quarter&year=2027&quarter=1`; ó `period=year&year=2027`).
- Estado owner requerido para cada petición; sin membresía, 404; empleado, 403; sesión anónima, 401/403; otros métodos 405.
- Periodos civiles (Europe/Madrid) `[from,to_exclusive)` validados estrictamente (sin parámetros duplicados, desconocidos o años fuera de 2000–2100). GET y `Cache-Control: no-store`.
- Cuenta **eventos históricos** `RenewalOutcome.kind=won/declined/discarded` del periodo, sin usar el estado actual ni inferir «Conseguida» por status. Si se recupera y se vuelve a ganar en otro periodo, cada cierre real se cuenta en su momento.
- «Pendientes» = anotaciones visibles cuyo `expires_on` cae en periodo, `status != closed` y sin archivo O3. «Contactado» sigue siendo abierto. No son entregas de avisos.
- No se devuelven UUIDs/nombres/referencias/usuarios/PII. No hay escrituras.
- `clients/flutter/lib/ui/results_screen.dart`: vista de 4 contadores y navegación periodo ES/CA, accesible solo en **web de escritorio ancho >=800 px** desde el panel y rol owner. No se expone en móvil nativo ni web estrecha.
- La API de red usa mismo origen y tipo `VenciraResultsSummary`; las pruebas Flutter existentes usan la implementación opcional del método como stub sin afectar pruebas anteriores.

## Verificación y puertas
- `backend/reminders/test_results.py`: cómputo civil en marzo con cambio DST, eventos reabiertos, cuenta ajena, sesión, role, POST y parámetros inválidos.
- `clients/flutter/test/results_test.dart`: ES/CA, agregados, navegación mes/trimestre/año, sesión caducada y ausencia de acceso móvil.
- `scripts/validate_o7_o8_preflight.sh`: Django completo SQLite + PostgreSQL 17 efímero, Flutter analyze/tests/build, sin tocar `vencira_localcheck`, PostgreSQL persistente ni Caddy/Restic.
- **Sin prueba verde aún**; no desplegar API/Web ni alterar Docker persistente hasta obtener resultado exacto y plan independiente. Después probar en PC con datos DEMO y verificar negación a usuario no-owner.
- Falta completar desglose por usuario conforme a decisión formal del §18, y valorar exportación Excel como fase O13 posterior.
