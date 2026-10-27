# MFA — Custodia y recuperación operativa (BLOQUEADO)
Fecha: 2026-10-27. Documento de criterios, no acta de ejecución.

## Custodia Fernet
- Clave ajena a DJANGO_SECRET_KEY y al repositorio, logs y copias sin cifrar.
- Dos custodios independientes con recuperación verificable fuera del VPS y fuera de una única cuenta cloud.
- Registrar responsables autorizados por función, fecha, medios de custodia y prueba de restauración sintética, sin copiar secretos en este documento.
- Reponer claves únicamente mediante procedimiento supervisado y auditado. La prueba sintética no sustituye una prueba real del material operativo en entorno controlado.
- Si falta un custodio, una restauración falló o se desconoce el material activo: no habilitar MFA.

## Pérdida total de factores
- El estado actual contiene casos, cuarentena, doble revisión y primitivas internas de sustitución administrativa comprobadas con pruebas sintéticas (incluida concurrencia PostgreSQL 17); NO existe todavía un servicio operativo autorizado ni proveedor independiente real de identidad y entrega.
- Verificación independiente de identidad y canal preexistente, con evidencia externa y aviso fuera de banda. El campo channel_verified_at por sí solo no constituye prueba.
- Al entrar en recuperación, bloquear sesiones y cualquier acceso password-only; conservar estado de cuenta protegida incluso mientras el nuevo factor está pendiente.
- Requerir dos revisores actuales y distintos, 24 horas de cuarentena y reevaluación atómica antes de ejecutar.
- Dar de alta TOTP nuevo y códigos con confirmación de custodia antes de revocar los anteriores, sin revelar secretos al personal de revisión.
- Incluir expiración, cancelación, rechazos, rate limiting y ensayos adversariales en PostgreSQL 17.
- Hasta entonces no exponer API ni comando de reset MFA.

## Rotación normal: custodia provisional
La rotación normal prepara TOTP y diez códigos provisionales; finalize_factor_rotation exige acreditar uno de los códigos antes de sustituir los anteriores. La entrega al titular y la reautenticación de transporte siguen pendientes. Ninguna primitiva interna equivale a una API autorizada.

## Autorización de despliegue
El preflight aislado bloquea, pero los scripts históricos no lo invocan obligatoriamente. Se requiere una ruta operativa única que verifique esquema y estado real, custodios, prueba de reversión, commit exacto y autorización explícita separada para migrar y para activar MFA. Sin esta evidencia: MFA_RELEASE_AUTHORIZED=NO.

## Sustitución administrativa: protocolo de tres etapas
Lógica interna de tres etapas implementada y ensayada con evidencias sintéticas, sin API pública ni ejecución operacional autorizada: (1) revalidar atómicamente cuarentena, doble revisión y evidencia de identidad independiente; preparar factor nuevo sin modificar el anterior; (2) acreditar TOTP nuevo y emitir códigos provisionales, conservando los anteriores; (3) exigir prueba de custodia de código provisional, sustituir secretos/códigos, incrementar session_epoch y cerrar expediente en una única transacción. El middleware debe denegar sesiones durante todo el expediente. En cualquier fallo o expiración conservar el factor anterior y el bloqueo administrativo aplicable. No considerar un booleano de cliente como verificación externa. MFA_RELEASE_AUTHORIZED=NO.

## Criterios de aceptación de integración real (pendientes)
- Proveedor de identidad independiente con evidencia verificable, vinculación al sujeto y expediente, antigüedad limitada, no reutilización y operación denegada ante errores. Un callable de pruebas o una marca en base de datos NO aporta esa evidencia.
- Canal fuera de banda preestablecido: aviso al titular, autenticación específica y entrega de TOTP/códigos sin revelar material al revisor ni almacenarlo en logs o correo sin protección. Probar interrupciones y expiración de la entrega.
- Custodia Fernet: dos responsables independientes, medios externos separados, restauración real en aislamiento y acta privada firmada; nunca subir claves a GitHub ni al chat.
- Identificar y proteger todas las rutas de autenticación, incluidas sesiones administrativas, API y autenticación por tokens. La protección de middleware por sesión no prueba por sí misma el cierre de rutas alternativas.
- Puerta de despliegue: bloquear hasta revisión independiente y autorización diferenciada de migración de esquema y activación. No modificar ni saltar el gate fail-closed para dar por completada la integración.
- Estado a 2026-10-27: VALIDACION_INTERNA_SINTETICA=OK; IDENTIDAD_EXTERNA=PENDING; ENTREGA_SEGURA=PENDING; CUSTODIA_REAL=PENDING; MFA_RELEASE_AUTHORIZED=NO.


## Procedimiento propuesto de recuperación manual supervisada — sin habilitación
1. Apertura: registrar expediente y revocar sesiones; suspender operaciones de la cuenta. Nunca asumir que conocer contraseña o controlar correo demuestra identidad.
2. Identidad: personal autorizado verifica al titular usando un canal independiente establecido antes de la incidencia. Archivar referencia opaca a evidencia en un sistema distinto; asociar sujeto, expediente, fecha, método y resultado. No guardar documentación sensible ni secretos en eventos de aplicación.
3. Aviso: enviar comunicación fuera de banda por el contacto anterior a la incidencia, con posibilidad de impugnar y bloquear. Un cambio reciente de contacto invalida el canal hasta nueva comprobación independiente.
4. Revisión: esperar al menos 24 horas; dos revisores activos, distintos e independientes del solicitante, aprueban con caducidad de una hora. Reevaluar todo antes de cada etapa; cualquier rechazo o caducidad impide continuar.
5. Entrega: canal autenticado y cifrado de extremo a extremo directamente con el titular, sin acceso del personal revisor al secreto TOTP ni a los diez códigos. Prohibido correo plano, capturas, chat de soporte y logs. La implementación concreta de este canal sigue pendiente.
6. Confirmación: titular prueba nuevo TOTP y custodia de un código provisional. Solo entonces sustituir en una transacción factores y códigos, revocar sesiones y cerrar expediente; un fallo conserva el factor anterior.
7. Cierre: registrar únicamente identificadores de expediente, resultado, revisores, timestamps y referencia externa; comprobar revocación. No registrar TOTP, códigos, claves ni datos de identidad.
8. Contingencias: ante expiración, pérdida del canal, cambio de identidad, conflicto de revisores o imposibilidad de custodiar claves, bloquear y escalar a revisión humana; nunca habilitar acceso basado solo en contraseña.

### Evidencias que deben existir antes de producción
- Acta privada de titularidad del canal y prueba independiente de identidad, referenciada sin revelar datos personales.
- Demostración de que los revisores no pueden observar ni solicitar códigos, y de que los secretos no aparecen en logs, traces, respaldos de soporte ni mensajes.
- Pruebas de entrega interrumpida, enlace caducado, captura/repetición, cambio de contacto y notificación impugnada.
- Dos custodios reales de claves Fernet y restauración aislada del material custodiado, con acta de aprobación independiente.
- Auditoría de rutas de autenticación y procedimiento de despliegue único autorizado.

Ningún valor booleano de configuración ni test sintético sustituye estas evidencias. Este texto es un diseño operacional, NO una certificación ni autorización de activación.
