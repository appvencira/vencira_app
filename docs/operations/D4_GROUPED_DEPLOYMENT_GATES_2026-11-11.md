# D4 — Cinco bloqueos agrupados para acelerar la entrega (2026-11-11)

## Decisión

Agrupar los cinco riesgos pendientes en un único programa D4 sobre `main`, sin nuevas ramas, sin repetir D1-N, D3-A, D3-C, D3-B5, D3-B6C ni D3-B7. El objetivo es minimizar el trabajo de operador: primero un preflight de solo lectura y después **un único laboratorio aislado con criterios de aceptación por bloque**, seguido de un gate de producción separado.

El script `scripts/main_d4_grouped_release_blockers_readonly.sh` **solo inventaría**, no ejecuta el laboratorio ni autoriza despliegue. Su código de salida **4** es deliberado mientras sigan los bloqueos. No interpretar `RESULT=4` como regresión de gates históricos. No se utilizará el daemon Docker operativo para importar imágenes ni el volumen vivo de PostgreSQL para restauraciones.

## Matriz única de ejecución

| Bloque | Evidencia que ya existe | Falta para cerrar | Condición de aceptación |
| --- | --- | --- | --- |
| B1, recuperación de imágenes | D3-B5 carga rootless de 3 imágenes PASS; D3-B6C 46 blobs verificados | Arranque aislado de imágenes archivadas, pruebas de HTTP y servicios | Runtime y aislamiento verificados sin acceso al Docker operativo |
| B2, rollback imagen + O5 | D1-N restore O5 real aislado; D3-A restore sintético; D3-B4 mapeo rootfs | Combinar imágenes anteriores con backup O5 real aislado, compatibilidad de migraciones y procedimiento de retorno | Recuperación reversible probada con datos controlados y ninguna alteración DEV |
| B3, retención externa | Archivo privado y checksum local PASS | Copia cifrada independiente del VPS y restauración de muestra | Destino externo, integridad, restaurabilidad y custodia comprobados |
| B4, regresión final main | Suites históricas backend/Flutter/HTTPS y pruebas Android | Reejecutar selectivamente el candidato final: Django/PG17, Flutter analyze/test/build, sesión/CSRF/MFA según alcance, adjuntos/calendario | Un gate del SHA final, sin falsos PASS heredados |
| B5, producción | D3-C Caddy DEV/TLS PASS | Configuración real de `vencira.es`, host/CSRF/cookies, secretos, plan de publicación, observabilidad, revisión de restricciones | Preflight producción verificado y aprobación operativa explícita |

**Riesgo transversal:** D3-B3 sigue FAIL en coincidencia exacta entre ID Docker histórico y digest de configuración archivada. D3-B7 demuestra seis coincidencias contenedor↔Docker inspect↔manifiesto externo. No equivale a identidad exacta de la exportación ni puede declararse resuelto de forma automática. Un proceso de autorización deberá valorar el riesgo residual con evidencia técnica y registro explícito.

## Política operativa

1. Mantener `MFA_RELEASE_AUTHORIZED=NO` y `NO_DEPLOY_NO_LIVE_MIGRATION=1` hasta que los gates correspondientes se aprueben expresamente.
2. No instalar/modificar servicios en DEV, cargar imágenes en Docker host ni recuperar PostgreSQL vivo durante D4.
3. No afirmar recuperación operativa antes de B1 y B2; no afirmar DR externo antes de B3.
4. No volver a ejecutar pruebas costosas ya cerradas salvo que el código candidato haya cambiado materialmente.
5. **Primera autorización a considerar**: piloto DEV, no producción, con control de cambios, backup y reversión. Producción se aprueba aparte después de B4/B5.

## Ejecutar el inventario agrupado en Termius

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
bash -n scripts/main_d4_grouped_release_blockers_readonly.sh
bash scripts/main_d4_grouped_release_blockers_readonly.sh
echo "D4_SHELL_RESULT=$?"
```

La salida inicial esperada identifica el archivo existente, las evidencias previas y **cinco bloqueos pendientes**. `D4_RESULT=4` es el bloqueo de autorización previsto, no autorización de release.

## Próxima entrega técnica

Diseñar B1+B2 como **un solo ensayo** de runtime de imágenes archivadas y base O5 aislada, con protecciones de red, ausencia de sockets, volúmenes efímeros, datos no expuestos, recursos limitados y limpieza verificable. Antes de ejecutar, deberá existir gate de preflight de aislamiento y permisos. Los bloques B3-B5 pueden prepararse documentalmente en paralelo en `main` sin alterar sistemas.

```text
D4_DEPLOY_EXECUTED=NO
D4_LIVE_MIGRATIONS_EXECUTED=NO
D4_LIVE_RESTORE_EXECUTED=NO
D4_PUBLIC_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```

## Resultado D4 y siguiente ejecución D4-A

El operador confirmó el inventario D4: `D4_MAIN_SYNC=PASS`, `D4_CLEAN_TREE=PASS`, archivo de imagen PRESENT, evidencias B1/B2/B4 documentadas, Caddy ACTIVE, `D4_BLOCKERS_OPEN=5`, `D4_RELEASE_READINESS=BLOCKED`, `D4_RESULT=4` y `D4_SHELL_RESULT=4`. No se ejecutó ningún despliegue, carga de imágenes, restauración ni contenedor. **Este código 4 es el cierre correcto del inventario, no un gate funcional fallido.**

Para evitar otro inventario genérico, se publicó `scripts/main_d4a_b1b2_joint_lab_preflight_readonly.sh`. Este control comprueba de una vez las condiciones previas para el laboratorio conjunto B1+B2: permisos del archivo, Podman rootless, runtime de usuario, documentación técnica D1-N/B5/B6C y existencia/permisos del contrato O5. No descifra copias, no importa ni ejecuta imágenes y no toca Docker operativo. La verificación de permisos O5 puede quedar `UNVERIFIED` si no se dispone de autorización de sudo no interactiva: no es prueba de inexistencia de copias.

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
bash -n scripts/main_d4a_b1b2_joint_lab_preflight_readonly.sh
sudo -v
bash scripts/main_d4a_b1b2_joint_lab_preflight_readonly.sh
echo "D4A_SHELL_RESULT=$?"
```

Un `D4A_RESULT=0` solamente acredita la **preparación de laboratorio**; B1/B2 continuarán NO verificados hasta ejecutar el ensayo aislado conjunto. No regenerar el archivo original ni repetir D3-B5/B6C/B7.
