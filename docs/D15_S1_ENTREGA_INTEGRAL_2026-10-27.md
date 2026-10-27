# D1.5 — S1: Entrega integral (sin subfases)

Fecha: 27/10/2026. Rama: integration/local-e2e-prep.
Referencia: HANDOFF_MACROFASE_D15_ABC_2026-10-27.md, D15_CUSTODIA_MFA_Y_GATE_OPERATIVO_2026-10-27.md y whitepaper §12.

## Decisión de ejecución
Agrupar el trabajo pendiente S1 en un solo paquete de código, documentación y pruebas. Evitar el ciclo commit/SSH/validación por cada pequeño arreglo. Las pruebas históricas O5 y S1A–S1E ya aceptadas no se repiten de forma aislada.

## Trabajo requerido en el paquete
- Autorización administrativa inequívoca de revisores, desde configuración y custodia del servidor separadas de entrada HTTP; comprobación de identidad y permisos.
- Casos de recuperación y aprobaciones transaccionales en PostgreSQL 17 con bloqueo, expiración, cuarentena, replay e idempotencia; auditoría de transiciones y rechazos.
- Recuperación sin bypass de segundo factor: control del proceso, revocación de sesiones y factores antiguos, inscripción de nuevos factores antes de restaurar acceso completo. NO exponer endpoint mientras falte seguridad.
- Puerta de despliegue MFA nueva que compruebe candidato y esquema/estado real antes de migraciones y ante reversiones. Fallo cerrado si el estado es desconocido.
- Custodia Fernet con dos copias cifradas independientes y ensayo de recuperación criptográfica controlado. El procedimiento en código no sustituye ejecución real por custodios.
- Revisión de script O5 para reportar limpieza y estado real sin falsos positivos; conservar ensayos históricos.
- Tests agrupados: Django SQLite, PostgreSQL 17 temporal con concurrencia, seguridad/abuso y Flutter ES/CA relevantes.

## Gate único
Un script de preflight sin despliegue, con SHA fijado, resultados resumidos y sin secretos, comprueba migraciones, suites y seguridad. Solo se pedirá ejecución al operador cuando el paquete esté implementado y revisado. Si falla, resolver errores en GitHub y volver a ejecutar únicamente el gate del paquete actualizado.

## Restricciones
- PostgreSQL persistente documentado en migración 0018; migraciones 0019–0022 preparadas pero NO autorizadas en vivo.
- MFA enrollment y UI apagados, sin publicación ni cambios OAuth/Caddy/Restic.
- No afirmar cierre S1 antes de validar código y completar la custodia real externa.
- Un despliegue exige autorización expresa adicional; la activación de enrolamiento requiere autorización independiente.

## Situación de entrada
S1E validado por operador: RESULTADO_D15_S1E=0 sobre 22f3cc0e66b24b93d514685f9c318f25d47e90c5. S1E documentado en 71d689af78d19659ce63fa166d794bb45d7c1189. Pruebas anteriores registradas en D15_CUSTODIA_MFA_Y_GATE_OPERATIVO_2026-10-27.md.
