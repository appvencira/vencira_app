# Macrofase B — Bandeja operativa y avisos sin atender (propuesta, 25/10/2026)

## Estado de partida
- Macrobloque A: usuario declara funcionalmente validada la UI de avisos internos en DEV; esquema PostgreSQL 0018. Avisos externos NO implementados.
- O11 agenda HOY y franja semanal ya existentes; NO duplicar navegación ni reescribir vistas aceptadas.
- Whitepaper §18 mantiene ABIERTA la decisión sobre aviso no atendido: el comportamiento descrito aquí es propuesta conservadora, NO norma aprobada.

## Alcance propuesto
1. Bandeja de **hoy**: ocurrencias internas por fecha y organización, con identidad de registro, estado y acceso a ficha.
2. **Atrasados**: ocurrencias planned/pending/snoozed con scheduled_for anterior a fecha local y no completadas; mantener visible fecha original y distinguir aplazamientos.
3. Acciones ya implementadas: completar, mañana, otra fecha; reutilizar CAS, idempotencia y límites del control; no enviar notificaciones.
4. Resumen de contadores por día/semana/organización y búsqueda sin mezclar tenants.
5. Historial de eventos con actor/hora, sujeto a autorización y sin exponer datos de terceros.
6. ES/CA, responsive móvil/escritorio y estado vacío/error diferenciado.

## Puertas
- Aclarar o aceptar decisión §18 sobre avisos no atendidos antes de cerrar semántica de producto; predeterminado prudente: NO marcar completado/cancelado automáticamente.
- Ningún GET debe crear eventos; ninguna notificación declarada entregada.
- Tests Django SQLite + PG17 efímero: límites de días civiles/zona horaria, overdue, CAS, isolation, idempotency, paginación/contadores.
- Flutter analyze/test/build, ES/CA, anchuras 320/375/768/1440, visual Android.
- Si migraciones nuevas: gate O5 respaldo restaurable y clon, despliegue explícito.
- No operar sobre datos reales ni anunciar aptitud de producción.

## Continuidad
Siguiente acción técnica: auditar endpoints actuales de agenda y modelos OperationalReminder antes de implementar bandeja; reutilizar los componentes y servicios existentes.
