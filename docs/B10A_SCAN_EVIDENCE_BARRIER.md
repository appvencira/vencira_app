# VENCIRA — B10A: evidencia de escaneo y barrera

## Integración

La persistencia experimental de evidencia firmada
adquiere la barrera PostgreSQL compartida antes de:

- bloquear la fila de adjunto;
- verificar el fingerprint del documento;
- comprobar el resultado firmado del escáner;
- insertar la evidencia de auditoría.

El bloqueo abarca la transacción completa.

## Ensayos

- Resultado sintético autenticado.
- Firma incorrecta rechazada.
- Evidencia duplicada rechazada.
- Estado rechazado no admite evidencia limpia.
- Bloqueo exclusivo de captura detiene la escritura.
- Registro de evidencia NO cambia el estado del adjunto
  ni concede permisos de descarga.
- Producción rechazada.

## No implementado todavía

- Trabajador operativo ClamAV.
- Gestión de firmas y salud del motor.
- Claves de firma aisladas de los procesos web.
- Transición autorizada de cuarentena a disponible.
- Descarga o eliminación HTTP.
- RGPD y políticas de conservación.

No desplegar este código experimental.
No usar archivos ni claves reales.

B10A_SCAN_EVIDENCE_BARRIER=EXPERIMENTAL
B10A_OPERATIONAL_RELEASE=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
