# VENCIRA — Cierre M3-01: reconciliación whitepaper y código (01/11/2026)

## Criterio de cierre aplicado
Checklist maestra: **«M3-01 Reconciliar funciones actuales con el whitepaper y registrar diferencias verificadas»**. Es un entregable de **auditoría y registro**, no la exigencia de implementar toda V1 ni un gate de despliegue.

## Documentación fuente ya verificada
- `docs/source/WHITEPAPER_ORIGINAL_2026-10-18_TRANSCRIPCION.md`: transcripción íntegra de las 23 páginas del documento original del 18/10; declara que los diagramas no se preservan.
- `docs/AUDITORIA_ALINEACION_WHITEPAPER_2026-10-25.md`: matriz completa que recorre secciones 1–18 y clasifica A/P/D/N/DEC, con caminos de código, diferencias y decisiones del §18 pendientes.
- `docs/WHITEPAPER_ALIGNMENT_2026-10-22.md`: condiciones de alcance y alertas legales.
- PDF original aportado por el promotor y conservado fuera de Git; no se considera que la transcripción reemplace los elementos gráficos.

## Delta revisado contra HEAD de la rama 01/11
| Requisito | Evidencia en fuentes actuales | Juicio actualizado |
|---|---|---|
| §6 tres obligatorios al crear: Entrada, Nombre, Vencimiento | `backend/reminders/serializers.py` comprueba los tres solo si `self.instance is None`; conserva registros históricos incompletos y sintetiza referencia técnica cuando falta | Discrepancia del 25/10 **corregida en API**, sin afirmar migración final o UAT actual |
| §9 «No aceptó», reiniciar plantilla de avisos | `backend/reminders/outcomes.py` llama `_reset_reminder_template` con `DEFAULT_DAYS_BEFORE` después de actualizar vencimiento; `_rebuild_candidates` solo proyecta políticas habilitadas, sin notificar | Reposición de plantilla **corregida en lógica**, activación/entrega de avisos pendiente |
| §6 candidato conseguido, sugerencia de Cliente futuro | `backend/reminders/person_suggestions.py` devuelve `suggested_entry=clients` solo si se elige explícitamente una anotación visible ya de Clientes | Sugerencia **parcialmente implementada**; no identidad global ni inferencia automática de toda persona |
| §5 agenda de HOY al inicio | `clients/flutter/lib/main.dart` mantiene `VenciraDashboardScreen`, pero configura `openTodayOnLoad: widget.api == null` | Diferencia anterior mitigada en ruta normal; falta verificación E2E del comportamiento y restauración de navegación |
| §7 avisos reales | `outcomes.py` documenta que `_rebuild_candidates` crea candidatos planificados, no entregas | **Pendiente** envío, acciones y trazabilidad de avisos |
| §8–10 pregunta de control | Auditoría original registra el contrato literal de respuestas Sí/No en §8 y trabajo O9b parcial | No afirmar ciclo completo operativo; verificar implementación y notificaciones en M3-02 |
| §3/§12 equipos y seguridad | Auditoría 25/10 y checklist MB1/MB2; SQL en DEV aún con usuario elevado, MFA bloqueado | **Pendiente** revisión operativa y liberación |
| §13 ES/CA | `main.dart` contiene delegados y locales es/ca | No acredita ausencia de literales Dart ni cumplimiento exhaustivo i18n |

## Diferencias pendientes explícitas
- Avisos reales, móvil offline, control y notificación, operación de equipos, historial exhaustivo, estadísticas/Excel, adjuntos escaneados, MFA, integridad e inmutabilidad de histórico, retención y RGPD.
- Decisiones excepcionales del §18: Vida, alta tardía, avisos sin atención y anteriores al límite. No fabricar políticas.
- La auditoría es estática y de alcance funcional, no demuestra seguridad de despliegue, aprobación legal, pruebas E2E ni equivalencia comercial completa.

## Resolución M3-01
**CRITERIO DE AUDITORÍA SATISFECHO**: fuente original trazable, matriz integral por apartado, diferencias y decisiones pendientes explícitas, más delta del código actual corroborado por lectura directa. Se permite cerrar **solo M3-01**. M3-02, M3-03, M3-04 y todos los gates de MB1/MB2 siguen abiertos.

Progreso formal resultante: **2/15 = 13,3 %** (MB1 1/7, MB2 0/4, MB3 1/4). Mide hitos cerrados, no porcentaje de desarrollo real.

```text
M3_01_WHITEPAPER_RECONCILIATION=COMPLETE
M3_02_PRODUCT_IMPLEMENTATION=NOT_VERIFIED
M3_03_E2E_ACCEPTANCE=NOT_VERIFIED
M3_04_RELEASE=NOT_AUTHORIZED
MB1_GLOBAL_FREEZE=NOT_VERIFIED
MB1_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```
