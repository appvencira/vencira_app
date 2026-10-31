# M1-04 — Frontera de escritores y captura fail-closed (31/10/2026)

## Evidencia confirmada

- La captura cooperativa de **la misma identidad** PG17 + objeto cifrado Fernet + diario bajo una sola ventana fue restaurada con UUID y SHA256 coincidentes; ejecución operador OK, `MB1_PG17_FENCE_EXIT_CODE=0`. Evidencia detallada en `docs/MB1_PG17_CONNECTION_FENCE_LAB_2026-10-31.md`.
- El bloqueo de nuevas sesiones a un rol ordinario, el drenaje previo y el lock POSIX compartido/exclusivo funcionan **solo para participantes**.
- El administrador de PostgreSQL sigue pudiendo escribir. Un proceso con permiso de archivos que no abra el mismo `flock` sigue pudiendo escribir. **No se ha demostrado ni implantado freeze global.**
- Un resultado PASS sintético **no** autoriza migraciones, despliegues, MFA, adjuntos ni backups operativos.

## Adversarial negative control (pendiente de operador)

Script `scripts/rehearse_mb1_noncooperative_bypass_disposable.sh` (commit `958acb1`): solo en contenedor PG17 temporal sin red y directorio `/tmp` privado. Mantiene `IsolatedProcessFence.capture()`, prueba que otro proceso puede modificar archivos sin participar en el lock y que un superusuario SQL puede escribir aunque se haya bloqueado el login del rol ordinario. Estos `...BYPASS=CONFIRMED` son **hallazgos negativos**, nunca indicadores de seguridad. Exige `MB1_NONCOOPERATIVE_LAB=YES` explícito y no utiliza DEV. El resultado no debe cambiar `MB1_GLOBAL_FREEZE=NOT_VERIFIED`.

Comando de ensayo:

```bash
cd ~/vencira-localcheck
git pull --ff-only origin feature/c-ficha-independent-attachments
bash -n scripts/rehearse_mb1_noncooperative_bypass_disposable.sh
sudo env MB1_NONCOOPERATIVE_LAB=YES bash scripts/rehearse_mb1_noncooperative_bypass_disposable.sh
echo "MB1_NONCOOPERATIVE_EXIT_CODE=$?"
```

## Diseño de cierre operativo: requisitos no satisfechos

1. **Definir exactamente el dominio de escritura**: todos los endpoints API, workers/reminders, tareas O5 que alteren datos, procesos administrativos y conexiones SQL de ambos proyectos, almacenes y diarios; probar que no hay accesos laterales con credenciales privilegiadas. El censo de rol PostgreSQL (uno login, uno elevado) **no** sustituye esta demostración.
2. **Modo mantenimiento en la frontera real**, con permiso explícito del operador, que impida nuevas operaciones en todas las rutas de escritura y atienda las existentes hasta su finalización. Puede requerir cambios en topología/permisos, parada controlada de workers y control de credenciales, por separado de DEV y previa evaluación de impacto.
3. **Impedir accesos privilegiados y no cooperativos durante el corte**, mediante aislamiento de writers a nivel de procesos, mount/volúmenes y credenciales/ACL reales. Una restricción `NOLOGIN` aplicada desde el propio administrador y un `flock` son insuficientes. No tocar servicios operativos sin plan de vuelta atrás.
4. **Captura**: PG17 y almacén cifrado/diario con mismo punto lógico; objeto inmutable o writers completamente excluidos; manifiesto autenticado que vincule UUID/digests; sin copiar claves operativas junto a los objetos. Comprobar restauración cruzada.
5. **Fail-closed**: si no es verificable cada canal, hay sesiones pendientes, objetos faltantes, cambios durante el corte, firmas rotas o acceso privilegiado no excluido, abortar, liberar mantenimiento de forma controlada y **no** declarar backup consistente.
6. **Gate de liberación**: reproducir en entorno de infraestructura representativa, adversarial y restaurar desde segundo host. Conservar `M1-03`, `M1-04`, `M1-05` y `M1-06` abiertos hasta cumplir sus propios criterios.

**Decisión actual**: `MB1_GLOBAL_FREEZE=NOT_VERIFIED`; `MB1_RELEASE_AUTHORIZED=NO`; `NO_DEPLOY_NO_LIVE_MIGRATION=1`. Este documento no autoriza una ventana de mantenimiento en DEV.


## Ensayo adversarial ejecutado — PASS en la detección de bypasses

Evidencia comunicada por el operador: `MB1_UNCOOPERATIVE_FS_WRITE_BYPASS=CONFIRMED`, `MB1_ORDINARY_LOGIN_DENIED=OK`, `MB1_NONCOOPERATIVE_SQL_ADMIN_WRITE_BYPASS=CONFIRMED`, `MB1_UNIVERSAL_FREEZE_FAIL_CLOSED=OK`, `MB1_NONCOOPERATIVE_BYPASS_RESULT=0`, `MB1_NONCOOPERATIVE_EXIT_CODE=0`. Persisten `MB1_GLOBAL_FREEZE=NOT_VERIFIED`, `MB1_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

**Interpretación:** la prueba negativa funcionó correctamente y demuestra la insuficiencia del bloqueo actual; no es un PASS de congelación universal. Requisito siguiente: demostrar exclusión de *todos los procesos autorizados del dominio de escritura* y restringir la disponibilidad del almacén y del acceso a PG17 durante una ventana efímera. Conservamos abierto M1-03/M1-04.
