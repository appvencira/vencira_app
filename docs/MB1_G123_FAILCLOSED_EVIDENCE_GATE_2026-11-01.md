# VENCIRA — G1-G3: contrato de evidencia fail-closed (01/11/2026)

## Objetivo
Concentrar G1 inventario de escritores, G2 rol SQL segregado y G3 exclusión de escritores en una única evaluación. El contrato no bloquea procesos ni altera permisos. Evita que un PASS de laboratorio se convierta en freeze operativo.

## Código
- scripts/mb1_g123_evidence_gate.py: 14 requisitos de cobertura con booleanos estrictos y referencia obligatoria para cualquier resultado positivo. Ningún resultado activa despliegue o modifica DEV.
- scripts/test_mb1_g123_evidence_gate.py: ocho ensayos sintéticos, incluyendo entradas incompletas, malformadas y autodeclaradas.
- scripts/validate_mb1_g123_evidence_gate.sh: un solo runner Python sin Docker, SQL ni lecturas de secretos.

## Brechas confirmadas
DEV y preview usan SQL elevado; bypass de administrador SQL y de filesystem no cooperativo confirmados en laboratorio. No hay censo universal de escritores, freeze global, custodia externa ni integración O5 de objetos+diario. Aunque los 14 campos se marcaran positivos, la salida no acredita independencia de la revisión: el evaluador impide convertir autoafirmaciones en autorización operativa.

## Estado
PASS unitario confirmado por operador (01/11/2026): `Ran 8 tests in 0.001s`, `OK`, `MB1_G123_UNIT_CONTRACT=OK`, `MB1_G123_DEFAULT_FAILCLOSED=OK`, `MB1_G123_UNVERIFIED_COUNT=14`. Continúan `MB1_G123_OPERATIONAL_EVIDENCE=NOT_VERIFIED`, `MB1_GLOBAL_FREEZE=NOT_VERIFIED`, `MB1_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`. No se ha verificado ninguno de los 14 requisitos operacionales. No repetir los ensayos de PG17/Fernet, M1-02, M1-04, M1-05 y O5 ya acreditados. La matriz general está en docs/MB1_OPERATIONAL_BLOCKER_MATRIX_2026-11-01.md.

MB1_GLOBAL_FREEZE=NOT_VERIFIED. MB1_RELEASE_AUTHORIZED=NO. MFA_RELEASE_AUTHORIZED=NO. C_FICHA_RELEASE_AUTHORIZED=NO. NO_DEPLOY_NO_LIVE_MIGRATION=1. Total 1/15 (6,7%).
