# VENCIRA — B17E: auditoría de puertas de autorización (29/10/2026)

**Rama auditada:** `feature/c-ficha-independent-attachments`.  
**Naturaleza:** auditoría documental de evidencias existentes en GitHub. No se ejecutaron tests, contenedores ni comandos sobre VPS; no es una auditoría independiente de infraestructura ni autorización operacional.  
**Base:** `docs/HANDOFF_B17E_2026-10-29.md`, `B17C2_NETWORK_E2E.md`, `B17D_HARDENING.md`, `C_FICHA_RELEASE_REVIEW_2026-10-28.md`, `D15_AUDITORIA_CONSOLIDADA_MFA_2026-10-27.md`, `D15_ACTA_CUSTODIA_MFA_PENDIENTE.md`, `B14EF_REAL_CLAMD_INTEGRATION.md`, `D14_RELEASE_READINESS.md`, `OPERATION_O5_DRIVE_BACKUPS.md`, `ATTACHMENTS_SECURITY_GATE.md`, `D15_CUSTODIA_MFA_Y_GATE_OPERATIVO_2026-10-27.md`, `B13D_KEY_ROTATION.md`, `B17_ATOMIC_TRANSPORT_RECEIVER.md`.

## 1. Criterio de clasificación

- **PASS (ensayo):** evidencia documental de prueba sintética aprobada; no equivale a control operativo.
- **BLOCKED:** condición necesaria para la autorización real no acreditada.
- **DESIGN:** procedimiento definido o propuesto; no validado operativamente.
- Las evidencias históricas se califican según su alcance exacto. No elevar a PASS de producción una prueba aislada; no repetir B17C2/B17D sin modificación relevante.

## 2. Matriz de adjuntos / B17

| Requisito | Evidencia | Estado | Dependencia / evidencia faltante |
|---|---|---|---|
| Separación de firmante, HTTP y receptor Django, PG17 temporal | B17C2: NETWORK_E2E=OK, DJANGO_EXIT_CODE=0 | PASS (ensayo) | Topología operacional y autenticación de servicio |
| HMAC, Ed25519, políticas de claves, anti-replay y transacción | B17C2/B17D; rechazo de claves revocadas, futuras, caducadas y desconocidas | PASS (ensayo) | Registro, aprovisionamiento y revocación operacionales |
| Resistencia ante entradas HTTP inválidas y duplicados | B17D_HARDENING.md | PASS (ensayo) | Gateway de producción, límites y controles de abuso |
| ClamAV auténtico aislado y evidencia firmada sintética | B14EF_REAL_CLAMD_INTEGRATION.md | PASS (ensayo) | Operación continua, firmas actualizadas, manejo de fallos |
| Permisos de lectura/carga/descarga y aislamiento tenant | C_FICHA_RELEASE_REVIEW: negativos y denegación de descarga actual | PASS (denegación actual) / BLOCKED (operaciones) | Pruebas adversariales del flujo habilitado y acceso directo |
| Transición esquema histórico 0027 ↔ app independiente | C_FICHA_SPLIT_BRANCH_STATUS; C_FICHA_RELEASE_REVIEW | BLOCKED | Procedimiento reversible con datos/objetos, bloqueo de escrituras y estrategia sin arrastrar MFA |
| Custodia real Ed25519 y HMAC, rotación/revocación y recuperación | B13D; HANDOFF_B17E | BLOCKED | Custodios, almacén de secretos, ensayo independiente, política ante compromiso |
| TLS/mTLS e identidad de ambos servicios | HANDOFF_B17E | BLOCKED | Certificados, identidad, rotación, validación de extremo y fallo cerrado |
| Persistencia durable de nonces y evidencia fuera del test | B17_ATOMIC_TRANSPORT_RECEIVER: tabla temporal b17_replay | BLOCKED | Migración separada autorizable, retención y concurrencia |
| Flujo extremo a extremo de archivo real y aislamiento del almacenamiento | C_FICHA_RELEASE_REVIEW; ATTACHMENTS_SECURITY_GATE | BLOCKED | Upload→cuarentena→escaneo→evidencia→autorización→descarga→borrado, todo adversarial |
| Recuperación de BD + objetos cifrados + diario + claves | D14_RELEASE_READINESS, O5 | BLOCKED | Snapshot consistente, backup cifrado de objetos, restore integral con cotejo digest |
| RGPD/retención/encargados y UAT móvil/escritorio | D14_RELEASE_READINESS | BLOCKED | Revisión jurídico-operativa y aceptación expresa |
| Despliegue/rollback autorizado con imagen inmutable | HANDOFF_B17E | BLOCKED | Gate fail-closed, ensayo de reversión, aceptación independiente |

## 3. Matriz de MFA

| Requisito | Evidencia | Estado | Dependencia / evidencia faltante |
|---|---|---|---|
| Pruebas funcionales S1 y carrera en PG17 efímero | D15_AUDITORIA_CONSOLIDADA_MFA | PASS (ensayo) | No demuestra enforcement en candidato desplegado |
| Prueba Fernet con clave sintética sin privilegios | D15_AUDITORIA_CONSOLIDADA_MFA | PASS (ensayo) | Custodia real y restauración operacional |
| Roundtrip migraciones 0018–0026 / rechazo downgrade de cuenta sintética | D15_AUDITORIA_CONSOLIDADA_MFA | PASS (ensayo) | Procedimiento aprobado con datos reales y rollback no debilitante |
| Puertas legacy y fail-closed ensayadas | D15_AUDITORIA_CONSOLIDADA_MFA | PASS (ensayo) | Cobertura de todos los entrypoints y candidato inmutable |
| Custodia independiente y recuperación Fernet real | D15_ACTA_CUSTODIA_MFA_PENDIENTE | BLOCKED | Acta privada, segregación real, restauración controlada sin divulgar secreto |
| Recuperación total sin factores, doble aprobación y antiabuso | D15_CUSTODIA_MFA_Y_GATE_OPERATIVO | BLOCKED | Dos revisores reales o política de no ofrecer reset total; no simular doble control |
| Enforcement MFA en todas las vías y sesión/rollback | D15_AUDITORIA_CONSOLIDADA_MFA | BLOCKED | UAT y gate runtime en candidato inmutable, fail-closed |
| Protección de proxy/IP, alertas, UX Android/PC, RGPD | D15_AUDITORIA_CONSOLIDADA_MFA | BLOCKED | Ensayos operativos, decisiones y aceptación |
| Migración persistente o activación de enrolamiento | D15_ACTA_CUSTODIA_MFA_PENDIENTE | BLOCKED | Autorización explícita y separada para esquema y activación |

**Advertencia:** dos copias de un secreto bajo un solo operador no equivalen a dos custodios independientes. No usar claves ni credenciales de MASBITCOIN ni publicar material sensible.

## 4. Trabajo delegable a pruebas exclusivamente efímeras

1. Revisión estática de todos los caminos de deploy y migraciones, incluido `migrate` global, con pruebas negativas de bypass (sin ejecutarlos sobre live).
2. Construcción de pruebas con PG17 desechable y claves sintéticas de concurrencia, fallo de volumen, replay, rotación de certificados/identidad de servicio y respuesta HTTP sin exposición de secretos.
3. Diseño/ensayo de backup coherente BD+objetos+diario y restauración sobre datos totalmente sintéticos; probar objetos ausentes, corruptos y claves antiguas.
4. Prueba de las fronteras de permisos, aislamiento de procesos, revocación, timeout y fallo de ClamAV; descarga denegada hasta cumplir todas las condiciones.
5. Revisión de migración y rollback en clones desechables, incluidas cuentas MFA sintéticas; jamás convertir un rollback en password-only.

## 5. Trabajo que exige intervención y custodia real

- Acreditar custodia externa Ed25519/MFA/almacenamiento, segregación y rotación, sin depositar secretos en GitHub ni chat.
- Aprobar política de recuperación total MFA (dos revisores verdaderamente independientes o deshabilitación explícita del reset total).
- Revisar RGPD, relaciones con encargados, retención y recuperación de incidentes.
- Validar certificados/TLS, permisos de almacenamiento, backups restaurables y monitorización operacional.
- Completar UAT Android/escritorio y aprobación de publicación por separado para adjuntos y MFA.

## 6. Secuencia fail-closed de EVENTUAL publicación — solo diseño, NO EJECUTAR

**G0 — Base inmutable.** Congelar commit/artefactos, enumerar cambios y superficie, verificar firma/digest y procedencia. Cualquier divergencia bloquea.

**G1 — Gates offline.** Tests unitarios/adversariales y PG17 efímero, Flutter donde aplique; cleanup comprobado; sin puertos públicos, datos ni claves reales. Fallo o resultado desconocido bloquea.

**G2 — Custodia y controles externos.** Revisores autorizados documentan, fuera del repositorio, custodia, rotación, TLS/mTLS, monitorización, procedimientos de abuso, RGPD y planes de respuesta. Sin evidencia humana válida, bloqueo.

**G3 — Backup y restauración.** Snapshot cifrado consistente de BD/objetos/diario con claves recuperables; restauración en entorno aislado e integridad demostrada, RPO/RTO aceptados. O5 de BD solamente no satisface G3.

**G4 — Compatibilidad de esquemas.** Resolver 0018/0027 y grafo sin arrastrar MFA; prohibir `migrate` global no controlado; ensayo reversible contra clon, reconciliación y congelación de escrituras prevista.

**G5 — Candidato y rollback.** Ensayar despliegue y reversión con imágenes fijadas, auth y permisos fail-closed; asegurar que revertir código no abre acceso ni descifra incorrectamente; ninguna ruta alternativa elude gates.

**G6 — Aprobaciones independientes.** Aprobación formal diferenciada de (a) esquema, (b) servicio de adjuntos con archivos reales y (c) MFA/enrolamiento. No heredar autorizaciones de B17C2/D ni de un aprobado técnico.

**G7 — Ejecución futura.** Solo tras G0–G6 y orden explícita del responsable, seguir procedimiento revisado con monitorización y plan de parada; rollback lógico preferente cuando una reversión de esquema compromete datos. Este documento **no es esa orden**.

En cualquier gate fallido, ausente o indeterminado: **STOP**, mantener acceso denegado, no migrar, no activar funcionalidades; preservar evidencia sin secretos.

## 7. Resultado B17E

```text
B17E_DOCUMENTARY_AUDIT=COMPLETE
B17E_LIVE_TESTS_EXECUTED=NO
B17E_EXTERNAL_CUSTODY_VERIFIED=NO
B17E_RELEASE_AUTHORIZED=NO
B17_OPERATIONAL_RELEASE=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```

**Siguiente trabajo sugerido:** preparar gates estáticos y negativos de despliegue/custodia con fixtures sintéticas, sin tocar servicios, y cerrar evidencia operativa de forma separada. Cualquier resultado nuevo se añade con hash de código, ejecución, salida y limitación explícita.
