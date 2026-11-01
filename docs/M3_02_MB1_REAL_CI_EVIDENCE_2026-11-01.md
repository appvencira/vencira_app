# VENCIRA — Evidencia real de CI agrupada M3-02 y MB1 (01/11/2026)

## Referencia reproducible
- PR de validación **en borrador**, no fusionada: https://github.com/appvencira/vencira_app/pull/14
- HEAD del código ejecutado: `b4075e501ea26837028662d5764a990268538fe9`.
- Workflow M3: GitHub Actions run **41304458288**, job Django **124841954914** y job Flutter **124841954711**.
- Workflow MB1: run **41304458277** (conclusión `success`), auditoría de código estática y tests de contratos, no validación operativa de infraestructura.

## Resultado M3-02 verificado por logs oficiales de GitHub Actions
| Trabajo | Evidencia | Resultado |
|---|---|---|
| Django check | `System check identified no issues` | PASS |
| Django contratos O9b, API persistida, bandeja, transiciones y sugerencias | `Ran 35 tests`, `OK` (SQLite temporal) | **35/35 PASS** |
| Flutter analyze | `No issues found! (ran in 8.1s)` | PASS |
| Flutter model parsing y widget de bandeja | `8 tests passed` | **8/8 PASS** |

**Hallazgos de CI corregidos durante esta sesión:**
1. Primera CI Django falló en `test_no_creates_one_internal_repeat_visible_in_inbox`: la fecha civil simulada del POST no coincidía con `timezone.now()` usado para `answered_at`, provocando un falso conflicto 409 en el reintento. Test corregido fijando ambos relojes; nueva CI PASS.
2. Primera ejecución de `flutter analyze` reportó dos `expected_token` en el doble de test `operational_inbox_widget_test.dart`; eliminadas las comas fuera del grupo de parámetros nombrados. Nueva CI PASS.
3. En la misma corrección, los contadores de la bandeja quedan ocultos tras fallo de refresco, no solo las tarjetas; la prueba de widget exige que la tarjeta de resumen no siga visible con datos obsoletos.
4. Un error con resultado incierto tras modificar un aviso fuerza recarga de la bandeja y no permite usar el estado antiguo; una pérdida de autorización elimina la lista visible.

## Estado no acreditado por esta CI
El workflow M3 no cubre toda la batería Django, PostgreSQL17 real, Android físico, ejecución de avisos externos, notificaciones push/email, permisos efectivos de DEV, despliegue ni recuperación. El workflow MB1 solo verifica condiciones estáticas y contratos con evidencia simulada, no garantiza corte universal de escritores ni privilegios limitados en DEV.

**M3-02 sigue [ ]**: cerrar implica completar funciones UX, avisos efectivos y validación de aceptación. **Progreso formal 2/15 (13,3 %)**; no hay autorización de release.

```text
M3_02_DJANGO_35=PASS
M3_02_FLUTTER_ANALYZE=PASS
M3_02_FLUTTER_8=PASS
MB1_STATIC_AUDIT=PASS
MB1_GLOBAL_FREEZE=NOT_VERIFIED
MB1_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```
