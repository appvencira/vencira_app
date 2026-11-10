# VENCIRA — D1-S, cierre de seguridad previo a promoción (10/11/2026)

## Estado

**Código publicado en `main`, ejecución local pendiente. No autoriza despliegue.**

Evidencia previa confirmada: D1-N O5 auténtico + PG17 histórico + rollback PASS; D1-O Django/Flutter web sintético PASS; D1-P HTTPS DEV existente PASS; D1-Q inventario Compose/O5 PASS; D1-R inventario de mounts/imágenes PASS. Ninguno de estos gates verifica HTTPS del código candidato publicado tras D1-O en el proxy real ni un rollback operativo completo.

## Riesgos y cobertura

1. **Permisos:** `backend/reminders/test_d1s_workspace_attachment_access.py` añade tests HTTP con dos propietarios de workspaces y un miembro sin asignación. Comprueba que la lectura de renovación y adjuntos ajenos responde 404; que el miembro sin asignación no recibe detalles; y que el propietario autorizado solo obtiene metadatos y recibe 403 al intentar POST de adjuntos. Son fixtures sintéticas; no hay almacenamiento, antivirus ni acceso a datos DEV.
2. **Adjuntos:** la implementación actual `backend/reminders/attachment_api.py` permite GET de metadatos autorizados pero bloquea upload/download/delete. NO se debe presentar la funcionalidad de adjuntos binarios como terminada o habilitarla sin la cadena de custodia y escaneo pendientes.
3. **Proxy:** D1-P revisó `dev.vencira.es` con GET read-only, **no probó el candidato detrás de Caddy**. `scripts/i4_https_proxy.py` es un proxy HTTPS de laboratorio distinto y tampoco demuestra que el Caddy operativo vaya a servir correctamente el candidato.
4. **Rollbacks:** D1-N preservó recuentos de tres tablas en clon tras migración/reversa; no garantiza reversión de escrituras posteriores ni restauración íntegra de artefactos estáticos. D1-R detectó un único volumen persistente PostgreSQL; no editar ni destruir el volumen para ensayar rollback.

## Procedimiento de siguiente validación

Reutilizar el gate integral D1-O para que descubra también la nueva suite `reminders.test_d1s_workspace_attachment_access`, pero **sin asumir PASS** hasta ejecutar. D1-O crea una BD PG17 sintética y verifica que DEV no cambie. Aunque el script repita checks anteriores, al cambiar pruebas backend el resultado será nuevo y atribuible a esta revisión.

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
bash scripts/main_d1o_candidate_integral_gate.sh
echo "D1S_BACKEND_SHELL_RESULT=$?"
```

Si `D1O_DJANGO_REMINDERS_SUITE=PASS` y `D1O_RESULT=0` los nuevos tests habrán entrado en la regresión. Si falla, no asumir que es código de negocio: recoger primer error y corregirlo en `main`. La validación exacta de casos/contadores se hará en un gate posterior si es necesaria.

## Puertas que quedan abiertas

- Lectura y revisión **redactada** de los manifiestos efectivos `compose.yaml`, `compose.preview.yaml` y Caddy; comprobar rutas, imágenes y red sin copiar credenciales ni variables.
- Ensayo de proxy HTTPS con imagen web/api candidatas en un laboratorio separado, sin conexión a DEV.
- Plan operacional de promoción, copia O5 previa a ventana, rollback consistente para imágenes + PostgreSQL + posibles escrituras posteriores; aprobación expresa y post-checks.
- Login nativo Android físico + validación visual y política MFA: ruta de trabajo **independiente**, no requisito para concluir una versión web sin MFA nativa.

```text
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
D1_RELEASE_AUTHORIZED=NO
D1_DEPLOY_EXECUTED=NO
D1_LIVE_MIGRATIONS_EXECUTED=NO
```
