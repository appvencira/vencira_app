# D1.5j — Preparación de operación MFA (NO DESPLEGAR)

Estado: **en preparación; ningún despliegue ni migración persistente autorizados**.
Rama: `integration/local-e2e-prep`. Validación automatizada exigida: O7/O8 completo SQLite + PostgreSQL17 temporal + Flutter.

## Riesgos bloqueantes constatados

1. El alta TOTP está implementada solo como servicio interno: **no hay endpoint de activación con reautenticación reciente**, ni interfaz de presentación/confirmación/descarga de códigos de recuperación de una sola visualización.
2. Claves: `VENCIRA_MFA_FERNET_KEYS` exige secretos fuera de Git, backups y logs; **no existe custodia/recuperación implantada en VPS**. No se deben colocar claves reales en chat.
3. Si el usuario pierde autenticador y TODOS los códigos de recuperación, **no hay recuperación automática segura**. Se necesita proceso manual de verificación de identidad documentado, de doble control y con auditoría; no restablecer por correo ni contraseña solamente.
4. Interfaz MFA responsive ES/CA preparada, pendiente comprobación visual y accesibilidad real en Android/navegador.
5. Migraciones aditivas 0019/0020/0021 no aplicadas a PostgreSQL persistente; falta plan de despliegue forward-only comprobado en réplica restaurada y plan de reversión de aplicación **sin bajar esquema ni borrar datos**.
6. Probar el inventario de vías de autenticación: login Django, admin, API, sesiones existentes, restablecimiento de contraseña, cambios de usuario, sesiones caducadas, login desde varios dispositivos, rechazo del challenge expirado.
7. Evaluar el bloqueo de intentos compartido: 5 fallos/15 min, protección frente a denegación de servicio por bloqueo provocado, límites por IP/identificador en proxy, observabilidad sin registrar códigos, secretos ni credenciales.

## Secuencia de salida futura (requiere aprobación específica, NO ejecutarla desde este documento)

- Gate O7/O8 en commit inmutable y revisión de migraciones en PostgreSQL17 efímero.
- Inventario y prueba de restauración de backup O5 en destino aislado; conservar secreto de recuperación offline. Nunca mostrarlo.
- Crear/custodiar claves Fernet con gestor externo, separados de Django y de DB; ensayar recuperación y rotación usando datos ficticios.
- Validar enrolamiento y revocación/reinicio MFA de extremo a extremo; asegurar reautenticación reciente con contraseña más segundo factor cuando corresponda, CSRF y limitación; códigos de respaldo visibles exactamente una vez.
- Probar restauración y migraciones 0019–0021 en clon; auditar índices, cargas y tiempos.
- Planificar ventana controlada, imágenes/tags de rollback, preflight read-only y aprobación antes de tocar persistencia.
- Aplicar solo migraciones aditivas aprobadas, desplegar backend compatible y luego activar interfaz con feature flag, inicialmente solo cuentas de prueba, con métricas.
- Confirmar login sin MFA, login con MFA, recuperación, cuentas desactivadas, sesiones previas, otros dispositivos, ES/CA, backup y salud.
- En fallo: revertir imagen/código a versión compatible **manteniendo esquema expandido**; no hacer reverse migration destructiva. Si hay MFA activo, un rollback que omita segundo factor puede rebajar seguridad: **deshabilitar temporalmente logins/aislar servicio o mantener backend MFA protegido** hasta recuperación. Documentar decisión y comunicación.

## Evidencia de D1.5j

Test añadido para demostrar que una sesión abierta antes de habilitar MFA deja de autorizar acceso al activarse. **Gate pendiente**. Se prohíbe despliegue en DEV/producción durante esta fase.
