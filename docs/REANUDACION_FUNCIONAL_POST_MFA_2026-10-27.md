# VENCIRA — Reanudación funcional tras la macrofase MFA (27-10-2026)

## Estado y disciplina
Rama integration/local-e2e-prep. DEV PostgreSQL persistente confirmado hasta 0018 antes de D15; cambios MFA 0019–0026 SOLO en GitHub/clones. No desplegar/migrar ni habilitar email/push hasta autorizaciones separadas. La macrofase de pruebas técnicas MFA quedó cerrada, aunque su lanzamiento sigue bloqueado.

## Corrección de auditorías históricas
La auditoría whitepaper de 25/10/2026 refleja un corte anterior a diversas implementaciones y **no puede usarse literalmente como backlog actual**.

Comprobaciones directas de código:
- `clients/flutter/lib/main.dart` pasa `openTodayOnLoad: widget.api == null` a Dashboard; por tanto la observación antigua «nunca abre HOY» necesita prueba visual del flujo actual, no corrección ciega.
- `backend/reminders/serializers.py` exige Entrada, nombre y fecha al CREAR; genera referencia técnica si falta. No volver a imponer una referencia obligatoria en UI.
- `backend/reminders/outcomes.py` ya incluye `_reset_reminder_template` a 60/45/35 tras «No aceptó». No duplicar reset.
- `backend/reminders/person_suggestions.py` ya ofrece `suggested_entry=clients` cuando se selecciona explícitamente anotación visible clasificada como cliente. Verificar flujo real y consentimiento en Flutter antes de cambiarlo.
- La macrofase B ya implementó ocurrencias internas con acciones y bandeja; C0 ya inventarió Sí/No, repetición y borradores. **No implementar segundo circuito**.
- El estado de entrega real a proveedor continúa separado del aviso interno; no afirmar que se manden notificaciones.

## Próximo macrobloque funcional propuesto: C-FICHA
Unificar en una sola entrega:
1. Matriz §6 de campos obligatorios / opcionales y validación en API, Flutter, importación futura, categorías Clientes/Candidatos, y compatibilidad de registros legados.
2. Refinar sugerencias de registros visibles y conversión candidato→cliente SOLO al seleccionar fuente; no mutar otras pólizas ni exponer otro workspace/usuario.
3. Completar adjuntos seguros foto/PDF en esquema/API/UI solo con datos ficticios: controles tenant, lectura autorizada, restricciones de tipo/tamaño, prevención de acceso directo, limpieza y auditoría; revisar cuota aún pendiente sin suponer una cifra comercial definitiva.
4. Internacionalización íntegra de cambios ES/CA, diseño Android 320/375 y escritorio; evitar pantalla CRM global.
5. Batería única SQLite + PG17 efímero + Flutter; migración en O5 clon si se incorpora esquema, sin desplegar automáticamente.

## Alternativa posterior C-EXCEL
Importación/exportación y estadísticas multiusuario. No mezclar con adjuntos ni con activación MFA; deberá disponer de seguridad por tenant/asignación y validación previa de filas.

## Evidencia requerida antes de implementación
Inspeccionar los modelos de adjuntos existentes (si los hay), las APIs y las pantallas de ficha para determinar diferencias concretas. Mantener pendiente la decisión de cuota/retención como configuración o feature flag, sin permitir cargas reales hasta aprobación de seguridad/RGPD.

PLAN_DOCUMENTAL_NO_DESPLIEGUE=1
MFA_RELEASE_AUTHORIZED=NO
