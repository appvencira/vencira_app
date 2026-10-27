# MFA — Custodia y recuperación operativa (BLOQUEADO)
Fecha: 2026-10-27. Documento de criterios, no acta de ejecución.

## Custodia Fernet
- Clave ajena a DJANGO_SECRET_KEY y al repositorio, logs y copias sin cifrar.
- Dos custodios independientes con recuperación verificable fuera del VPS y fuera de una única cuenta cloud.
- Registrar responsables autorizados por función, fecha, medios de custodia y prueba de restauración sintética, sin copiar secretos en este documento.
- Reponer claves únicamente mediante procedimiento supervisado y auditado. La prueba sintética no sustituye una prueba real del material operativo en entorno controlado.
- Si falta un custodio, una restauración falló o se desconoce el material activo: no habilitar MFA.

## Pérdida total de factores
- El estado actual contiene casos, cuarentena y doble revisión, pero NO sustitución administrativa funcional y autorizada.
- Verificación independiente de identidad y canal preexistente, con evidencia externa y aviso fuera de banda. El campo channel_verified_at por sí solo no constituye prueba.
- Al entrar en recuperación, bloquear sesiones y cualquier acceso password-only; conservar estado de cuenta protegida incluso mientras el nuevo factor está pendiente.
- Requerir dos revisores actuales y distintos, 24 horas de cuarentena y reevaluación atómica antes de ejecutar.
- Dar de alta TOTP nuevo y códigos con confirmación de custodia antes de revocar los anteriores, sin revelar secretos al personal de revisión.
- Incluir expiración, cancelación, rechazos, rate limiting y ensayos adversariales en PostgreSQL 17.
- Hasta entonces no exponer API ni comando de reset MFA.

## Rotación normal: anomalía por resolver
confirm_factor_rotation sustituye los códigos en la transacción que entrega la lista. Si falla la entrega al titular, pueden perderse los códigos nuevos. Antes de exponer esta primitiva por HTTP se necesita un protocolo de confirmación de custodia o mecanismo de reparación que no debilite MFA.

## Autorización de despliegue
El preflight aislado bloquea, pero los scripts históricos no lo invocan obligatoriamente. Se requiere una ruta operativa única que verifique esquema y estado real, custodios, prueba de reversión, commit exacto y autorización explícita separada para migrar y para activar MFA. Sin esta evidencia: MFA_RELEASE_AUTHORIZED=NO.

## Sustitución administrativa: protocolo de tres etapas
Diseño pendiente de implementar y probar, sin API pública: (1) revalidar atómicamente cuarentena, doble revisión y evidencia de identidad independiente; preparar factor nuevo sin modificar el anterior; (2) acreditar TOTP nuevo y emitir códigos provisionales, conservando los anteriores; (3) exigir prueba de custodia de código provisional, sustituir secretos/códigos, incrementar session_epoch y cerrar expediente en una única transacción. El middleware debe denegar sesiones durante todo el expediente. En cualquier fallo o expiración conservar el factor anterior y el bloqueo administrativo aplicable. No considerar un booleano de cliente como verificación externa. MFA_RELEASE_AUTHORIZED=NO.
