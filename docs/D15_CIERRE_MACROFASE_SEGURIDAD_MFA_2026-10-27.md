# VENCIRA — Cierre técnico parcial de macrofase de seguridad MFA

Fecha: 27-10-2026. Rama: integration/local-e2e-prep.

## Evidencia comunicada por el operador
- SQLite y PG17 temporal: gate integrado S1 aprobado.
- Clave Fernet: restauración local declarada; prueba sintética aislada en contenedor sin privilegios OK. Archivo Compose optativo; secreto real no instalado.
- PG17 temporal: migrar 0018→0026, deshacer en esquema **vacío** y reaplicar: OK.
- PG17 temporal con usuario MFA activo: se rechazó candidato sin enforcement; downgrade destructivo deliberadamente no ejecutado.
- Inventario de 16 scripts históricos: 4 web-only, 7 API+web, 5 con migración histórica; preflight estático y test negativo indicados como OK por operador. Los scripts API/esquema antiguos quedan bloqueados; web-only exige esquema 0018.
- Sin despliegue ni migraciones sobre PostgreSQL persistente, último estado comunicado 0018.

## Única entrada prevista para decisiones futuras
`scripts/mfa_release_entrypoint.sh <schema-off|mfa-enable|rollback> <commit>`:
- Ahora es SOLO una barrera fail-closed de inspección de candidato, sin comandos de despliegue, migración, provisión o activación.
- Las tres etapas terminan con código 4, `MFA_RELEASE_AUTHORIZED=NO`.
- `scripts/check_mfa_unified_release_negative.sh` comprueba rechazo en las tres etapas sin Docker ni BD.
- Cualquier desarrollo posterior debe mantener autorización explícita independiente por etapa, comprobación de estado MFA vivo, ensayos de rollback con enforcement, registro de operador, respaldo y recuperación aprobada. No abrir una vía por variable de entorno sin comprobación.

## Bloqueantes operativos no resueltos
1. **Custodia:** aceptación formal del riesgo de un solo administrador; no equivale a doble aprobación humana.
2. **Pérdida total de factores:** no hay identidad externa ni entrega segura operativas. Alternativa de primera versión: códigos de un solo uso; no ofrecer reset administrativo sin revisores reales o proveedor independiente.
3. **Claves reales:** no instaladas ni restauradas en un ensayo del VPS.
4. **Experiencia:** UAT Android/PC, QR, recuperación ES/CA, cambios de factor, incidencias.
5. **Perímetro/operación:** rate limiting IP/proxy, alertas, backup O5/restauración PG17, RGPD y evidencia de endpoints alternativos.
6. **Release/rollback:** la puerta nueva es deliberadamente inoperativa; no representa un pipeline autorizado. Necesaria validación posterior de política contra BD de solo lectura y de compatibilidad de versión.

## Estado de cierre
FASE_PROTECCIONES_AISLADAS=VALIDADA_SEGUN_EVIDENCIA_OPERADOR
RELEASE_UNIFICADO=PREPARADO_SIN_OPERATIVA
MFA_PRODUCTION_ROLLBACK_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
