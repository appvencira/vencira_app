# VENCIRA — Auditoría MFA consolidada (27 octubre 2026)

**Naturaleza:** revisión técnica/documental del código en la rama `integration/local-e2e-prep` y de los resultados que comunicó el operador. No es una certificación independiente, prueba funcional de producción ni autorización.

## Evidencias técnicas ya validadas

- Gate integral comunicado tras el commit `431d0eac1a505289782602e4f7a531ffd0a290ea`: `S1_SQLITE_SECURITY=OK`, `PG17_EPHEMERAL=OK`, `S1_POSTGRES_REVIEW_AND_RACE=OK`, `S1_STATIC_CANDIDATE_GUARD=OK`, `S1_RELEASE_FAIL_CLOSED=OK`, `S1_DEPLOY_ENTRY_FAIL_CLOSED=OK`, `S1_UNTRACKED_FILES_REJECTED=OK`, `CLEANUP=OK`, `S1_PG17_GATE_RESULT=0`, `RESULTADO_FINAL=0` y `NO_DEPLOY_NO_LIVE_MIGRATION=1`. Log local /tmp/vencira-s1-pg17.rfXAeD5F.log.
- Código de recuperación de un uso, bloqueo por cuenta, revocación de sesiones por epoch tras recuperar el acceso, y ruta de entrada con TOTP. Estos controles cuentan con pruebas automatizadas aisladas, no prueba presencial en producción.
- `mfa_key_config.py` acepta archivo Fernet restringido. Prueba Docker aislada con clave sintética y usuario no privilegiado: `MFA_DOCKER_SECRET_NONROOT=OK`, `MFA_FERNET_SYNTHETIC_ROUNDTRIP=OK`, `MFA_NO_CROSS_USER_DECRYPT=OK`.
- `compose.mfa-secrets.yaml` es **optativo** y su configuración estáticamente validada. No está incluido en la ejecución normal.
- Custodia local: operador comunicó recuperación desde Bitwarden + USB cifrado y prueba de compatibilidad con funciones Fernet VENCIRA. No se han visto ni almacenado secretos en GitHub/chat.
- `mfa_s1_release_readonly.sh` sigue devolviendo código 4 y `MFA_RELEASE_AUTHORIZED=NO`. El gate negativo garantiza que la puerta *específica* ensayada no autoriza publicar; no demuestra que todos los scripts históricos de despliegue estén forzados a usarla.
- No se comunicó aplicación de migraciones MFA 0019–0026 en la BD persistente; último estado de BD confirmado antes de este bloque: 0018.

## Observaciones de auditoría

1. **Recuperación total sin factores:** `mfa_admin_recovery_policy.py` exige dos revisores humanos distintos y `record_review` exige roster de dos revisores elegibles. En una explotación de administrador único no hay cumplimiento real de ese requisito. Las primitivas internas para preparar/confirmar/finalizar factores administrativos no disponen de verificación independiente y entrega segura operativas. No exponer endpoints, desactivar MFA ni simular revisores.
2. **Custodia individual:** dos respaldos no equivalen a dos custodios. La aceptación del riesgo residual de concentración de autoridad y plan por incapacidad del operador está pendiente. La documentación histórica D15Q y el procedimiento D15 contienen requisitos de dos custodios que no deben darse por satisfechos.
3. **Clave real:** sin provisión en VPS, montaje operativo ni restauración operativa de esquema y claves en clon. No incluir la clave ni sus derivados en logs, variables visibles, imágenes o repositorio.
4. **Enrolamiento y UX:** confirmar prueba real de QR, recuperación y custodia en Android/escritorio, ES/CA, errores y cancelaciones. Un gate de unit tests no sustituye UAT.
5. **Sesiones y autenticación:** verificar en clon que todos los puntos de acceso administrativos y API preservan enforcement MFA; el rollback no puede reabrir acceso con contraseña solamente.
6. **Rate limits:** confirmar defensa por IP/proxy y alertas fuera de la lógica de bloqueo por cuenta; comprobar impactos de NAT y proxys.
7. **Operación y privacidad:** validar respaldo O5 reciente, restauración PG17, RGPD y registros mínimos antes de habilitar.
8. **Documentación:** encabezado de `mfa_admin_recovery_service.py` aún dice «NUNCA restablece MFA», aunque contiene primitiva interna de sustitución de factor; corregir antes de auditoría final. Encabezado `mfa_store.py` indica no conectado al login, pero sí se usa en el reto MFA.

## Puertas independientes — condiciones de salida

### G1: Código candidato aislado
**Estado:** pruebas automatizadas comunicadas satisfactorias. Ninguna autorización de despliegue.

### G2: Ensayo de esquema / rollback en clon
Exigir backup O5 verificable, ensayo de migraciones 0019–0026 en clon PG17, compatibilidad de rollback con sesiones protegidas, rutas API cerradas, mecanismo de claves sintéticas y trazabilidad. **PENDIENTE**.

### G3: Custodia, identidad y recuperación operativas
Aceptación firmada de custodia individual; verificación externa real y entrega protegida si se ofrece recuperación administrativa de pérdida total. Como alternativa de primera versión, **no ofrecer reset administrativo total**, usar códigos de recuperación previamente entregados y documentar que pérdida de todos los factores bloquea acceso. Requiere validación de experiencia y política de soporte; no equivale a aprobación automática. **PENDIENTE**.

### G4: Seguridad y UX
Pruebas visuales Android/escritorio, límites por IP, alertas, backup/restauración y revisión RGPD. **PENDIENTE**.

### G5: Publicación de esquema con MFA desactivado
Decisión explícita posterior con plan probado y rollback seguro; no debe ocurrir como efecto colateral de un despliegue web. **NO AUTORIZADA**.

### G6: Activación/enrolamiento de MFA
Autorización distinta después de G2–G5, con política de recuperación aprobada, pruebas UAT y planes de incidencia. **NO AUTORIZADA**.

## Próxima macrofase recomendada

Un único bloque de **preparación de entrega MFA**: corregir documentación desactualizada, cerrar diseño de recuperación autoservicio sin bypass, auditar scripts históricos contra publicación accidental y construir ensayo automatizado en clon de rollback/migraciones. Una sola batería integral aislada al finalizar. No repetir gates por cambios exclusivamente documentales.

**Estado irreversible de esta acta:** `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`. La presente acta no cambia permisos ni estado de ningún servicio.
