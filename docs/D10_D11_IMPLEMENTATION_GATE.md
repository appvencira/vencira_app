# VENCIRA — D10–D11: integración y seguridad

## D10A — Triple inventario offline

Prueba sintética en SQLite aislado:
`D10A_RESULT=0`.

Se contrastan tres conjuntos independientes:
intenciones del diario, metadatos ORM y objetos privados.
Se detectan discrepancias, objetos físicos sin diario y
raíces inseguras o inaccesibles. No se leen contenidos,
no se borran objetos y no se devuelven identificadores.

## Pendiente antes de cerrar D10–D11

- Instantánea coherente con escrituras concurrentes.
- Estados terminales duraderos e idempotencia entre workers.
- Recuperación de intención incompleta por fallo en fsync.
- Fallos físicos, recuperación y auditoría verificable.
- Pipeline antivirus con evidencia y verificación de integridad.
- API de subida y descarga con permisos exhaustivos.
- Revocación, eliminación, límites y defensa ante abuso.
- Gates integrales en PostgreSQL 17 aislado.

Esta validación no permite ninguna operación real.

D10_D11_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1

## D10B — Resistencia del diario

Seis pruebas sintéticas aisladas:

- Persistencia entre instancias.
- Rechazo de registro incompleto.
- Duplicado sin sobrescritura.
- Rechazo de enlace simbólico.
- Rechazo de registro excesivo.
- Bloqueo fuera del entorno de ensayo.

D10B_RESULT=0

No demuestra supervivencia a pérdida física de energía,
fallos de fsync ni estados terminales persistentes.
No habilita HTTP ni autoriza despliegue.
