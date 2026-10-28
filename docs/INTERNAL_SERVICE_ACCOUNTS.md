# VENCIRA — Cuentas internas e integraciones administrativas

Fecha de incorporación: 23/10/2026. Documento **interno** del repositorio privado `appvencira/vencira_app`. No publicar datos de cuentas administrativas en páginas públicas, capturas o manuales dirigidos a clientes.

## Cuenta Google dedicada a VENCIRA

| Campo | Valor / decisión |
| --- | --- |
| Propósito | Cuenta Google exclusiva para la administración técnica y los servicios de VENCIRA |
| Dirección confirmada por el titular | **`appvencira@gmail.com`** |
| **Estado de verificación** | **Grafía `.com` confirmada explícitamente por el usuario el 23/10/2026**. Confirmación declarativa; no implica comprobación de acceso, propiedad técnica ni conexión OAuth |
| Carácter | Uso **interno y administrativo**; no presentar como email público ni atención al cliente |
| Usos autorizables | Google Drive para copias externas **cifradas previamente**; alta/gestión y recuperación de accesos en servicios de terceros; credenciales administrativas de integraciones necesarias para la aplicación |
| Usos no asumidos | No es por defecto remitente de recordatorios comerciales, email transaccional, soporte público ni buzón de recepción de datos personales de clientes |
| Estado técnico O5 | **Planificado, no conectado ni configurado**; no se ha concedido acceso a Google Drive ni se han subido copias |

### Separación de identidades

- **Cuenta interna Google**: gestionar Drive, integraciones con proveedores, cuentas de desarrollador y administración de herramientas vinculadas a VENCIRA. Su dirección ya está confirmada por el usuario; cualquier conexión efectiva requiere autorización y autenticación específicas.
- **Identidad pública de VENCIRA**: buzones del dominio `vencira.es` para soporte y comunicaciones cuando se configuren, separados de la cuenta Gmail interna. No sustituir el correo interno por el futuro `soporte@vencira.es` ni publicarlo en la aplicación.
- **GitHub**: repositorio privado y permisos propios; conectar la cuenta interna a GitHub u otros terceros únicamente cuando exista una necesidad concreta, con privilegios mínimos. Evitar compartir contraseñas o reutilizar credenciales de otros proyectos.

### Reglas obligatorias para Drive y futuras integraciones (O5)

1. **Nunca subir `pg_dump` sin cifrar a Drive**. Propuesta técnica: `restic` con repositorio cifrado y `rclone` como transporte; documentar compatibilidad y probar recuperación antes de dar por operativa la copia externa.
2. Activar **verificación en dos pasos / passkey**, establecer opciones seguras de recuperación y guardar códigos de recuperación fuera del servidor y fuera del propio Drive.
3. Las claves de Restic, tokens OAuth, contraseñas y archivos de configuración de rclone no deben registrarse en GitHub, logs, tickets ni este documento. Permisos restrictivos y almacenamiento separado de las copias.
4. Emplear permisos OAuth **mínimos** y limitar la carpeta/repositorio de VENCIRA. Comprobar el propietario, cuota, caducidad de tokens y recuperación si se pierde el servidor o la cuenta.
5. Verificar restauraciones completas, monitorizar fallos y evaluar una **segunda ubicación independiente con protección frente a borrado**, no solo Drive. Retención, RPO/RTO y RGPD antes de datos personales reales.
6. No configurar conexiones ni dar consentimiento a proveedores en nombre del titular hasta completar la autorización correspondiente. Esta anotación **no acredita conexión a Google Drive**.

### Acción pendiente inequívoca

**Dirección confirmada: `appvencira@gmail.com`.** El usuario corrigió explícitamente las grafías anteriores `.col` y `.cm`, confirmando el sufijo `.com`. No solicitar nuevamente la dirección en próximos chats. **Aún falta conectar Google Drive de forma autorizada y validar técnicamente el acceso OAuth** antes de subir copias o administrar servicios.

Próxima fase O5: diseñar y probar desde `vencira_localcheck` el respaldo cifrado y la restauración externa con esa cuenta, sin alterar O1–O4 ni permitir datos reales.
