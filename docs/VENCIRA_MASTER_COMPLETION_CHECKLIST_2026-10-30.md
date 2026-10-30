# VENCIRA — Checklist maestra de cierre (30/10/2026)

Fuente de seguimiento: esta checklist en la rama `feature/c-ficha-independent-attachments`. Marcar `[x]` únicamente con salida PASS del operador y evidencia documentada. **No confundir ensayos sintéticos con liberación operativa.**

## MB1 — Copias y recuperación

- [x] E2E PG17 sintético: pg_dump/restauración y paquete cifrado autenticado; prueba de clave incorrecta/manipulación
- [x] Restauración en Ubuntu x86_64 **independiente** con paquete y claves sintéticas separadas; PG17 + objeto + diario + hashes recuperados `4b13842`
- [x] Persistencia de volúmenes Docker de objetos/diario tras recrear contenedor `860f53c`
- [x] Integración Django / `PrivateQuarantineStore` / `IntakeJournal` / PG17 efímero `0797ea8`
- [x] Contrato de seis interrupciones simulado `c43405e`
- [x] Clasificador puro de inventarios incompletos (10 pruebas) `cb138f4`
- [x] Inventario inicial de los dos proyectos Docker y confirmación de Caddy: DEV servido por `vencira_localcheck`
- [ ] **M1-01** Integrar el clasificador con inventario PG17 + volúmenes de laboratorio e introducir estados incompletos; resultado PASS de operador. Implementación `52464eb`, sin validación todavía
- [ ] **M1-02** Pruebas de interrupción real de procesos, pérdidas parciales y recuperación/reconciliación fail-closed: ninguna eliminación automática
- [ ] **M1-03** Censo completo de escritores y vías externas (API, cron/systemd, scripts, acceso SQL, objetos/diario)
- [ ] **M1-04** Definir e implantar el corte consistente de DB + archivos bajo concurrencia, primero en laboratorio; exclusión efectiva de nuevos escritores y ausencia de escrituras no cooperativas
- [ ] **M1-05** Backup completo con manifiesto, anti-rollback y restauración cruzada, evidencias en segundo host
- [ ] **M1-06** Custodia **operativa** externa de backup y claves, retención, rotación, custodia independiente y recuperación tras pérdida total del VPS
- [ ] **M1-07** Gate integrado final, restauración y revisión de seguridad, con decisión explícita de autorización

## MB2 — Seguridad y adjuntos

- [x] Pruebas sintéticas de MFA/custodia y recuperación administrativa (gates previos)
- [x] Ensayos aislados ClamAV/PG17 para adjuntos
- [ ] **M2-01** Custodia externa MFA real y prueba de recuperación; `MFA_RELEASE_AUTHORIZED=NO`
- [ ] **M2-02** Completar compuertas de adjuntos: scanner, firmas, aislamiento, ciclo de vida, integración ORM y pruebas adversariales
- [ ] **M2-03** Migraciones en clon, prueba de rollback y aceptación; no tocar esquema DEV sin autorización
- [ ] **M2-04** Revisión de seguridad y liberación separada de MFA y adjuntos

## MB3 — Producto V1 y salida comercial

- [ ] **M3-01** Reconciliar funciones actuales con el whitepaper y registrar diferencias verificadas
- [ ] **M3-02** Completar flujos y UX móvil premium, recordatorios y reglas de vencimiento
- [ ] **M3-03** Pruebas E2E, accesibilidad, rendimiento y documentación de uso
- [ ] **M3-04** Preparar despliegue gradual, backup, observabilidad y validación de aceptación

## Límites actuales

```text
MB1_OPERATIONAL_RELEASE=NO
MFA_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```

La lista recoge los **trabajos de cierre conocidos**, no plazos ni porcentajes. Se puede ampliar si aparecen fallos. No tachar por código publicado: solo tras ejecución confirmada.
