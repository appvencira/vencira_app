# VENCIRA — M3-02: cierre por macrobloques (01/11/2026)

## Política de trabajo

Evitar ciclos de un commit por incidencia y una respuesta por commit. Cada macrobloque debe entregar código, pruebas, CI, documentación y un veredicto explícito. No se contabilizará un hito completo por pruebas unitarias aisladas.

## Baseline verificada

Commit `b54cc5931e67454ad119666bb9cbc4b8cf789ef7`:
- GitHub Actions M3 product contracts `41332033103`: **success**.
- Android adapter compile `41332033101`: **success**.
- MB1 static security gates `41332033105`: **success**.
- Android scaffold verification `41332033246`: **skipped**, no PASS.
- PR #17 sigue draft; sin release, deploy o migraciones persistentes.

## MACROBLOQUE A — sesión y navegación transversales

Alcance: rutas secundarias (ficha, editor, agenda, bandeja, modalidades, aseguradoras, historial), invalidez de identidad, retirada de membresía y control del ciclo de vida de widgets. Evitar que una ruta ya montada vuelva a mostrar datos después de una revocación.

Criterio de cierre: test widget de revocación propagada desde cada ruta con datos visibles, reintento fallido y respuesta tardía; ausencia de rutas residuales al cerrar sesión; Flutter analyze + tests + Web + Android debug en verde. Hasta entonces, `SESSION_CROSS_ROUTE=OPEN`.

## MACROBLOQUE B — avisos Android reales con consentimiento

Alcance: pantalla opt-in explícito por usuario/workspace; permiso Android solicitado solo mediante gesto del usuario; reconciliación con la base cifrada; cancelación por logout/revocación; reinicio y recuperación; política de alarmas inexactas.

Criterio de cierre: tests de contrato + prueba instrumentada o manual documentada en terminal Android físico con activación, notificación local, denegación/revocación de permisos, modo avión, reinicio, Doze y fecha/huso. La construcción APK no prueba entrega. Mantener `OS_SCHEDULING_ENABLED=NO` hasta aprobar criterios.

## MACROBLOQUE C — liberación controlada

Alcance: integración de las ramas dependientes, revisión whitepaper, custodia externa de claves, gates MB1/MFA/C-FICHA, preflight PG17 aislado y estrategia de rollback. NO ejecutar despliegue o migración persistente hasta autorización explícita fundada en evidencia.

Criterio de cierre: documentación de riesgos, pruebas finales y autorizaciones verificadas. Estado actual: `MB1_RELEASE_AUTHORIZED=NO`, `MFA_RELEASE_AUTHORIZED=NO`, `C_FICHA_RELEASE_AUTHORIZED=NO`.

## Regla de reporting

Reportar una vez por macrobloque: cambios funcionales, commit, ejecución CI, errores pendientes, bloqueo físico y porcentaje formal justificado. Avanzar a continuación sin celebrar cada corrección como un hito.

```text
M3_02_SESSION_CROSS_ROUTE=OPEN
M3_02_DEVICE_DELIVERY_EVIDENCE=NO
M3_02_OS_SCHEDULING_ENABLED=NO
M3_02_RELEASE_AUTHORIZED=NO
GLOBAL_PROGRESS=2/15
NO_DEPLOY_NO_LIVE_MIGRATION=1
```
