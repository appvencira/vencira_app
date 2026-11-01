# VENCIRA — M3-02 contrato de control

Implementado `backend/reminders/control_intent.py`: respuestas Sí con tres motivos aprobados y No con repetición restringida al límite de mes civil. Los objetos de decisión no implican entrega, cierre ni escritura. Incorporadas pruebas en `backend/reminders/test_control_intent.py` y workflow `.github/workflows/m3-product-contracts.yml` para ejecutar dichas pruebas y la priorización de sugerencias Clientes.

Estado: código publicado, pruebas automáticas pendientes de confirmar. No hay endpoint, persistencia, auditoría real ni notificaciones; no se cierra M3-02. DEV intacto; no deploy ni migraciones. Total formal 2/15 (13,3%).
