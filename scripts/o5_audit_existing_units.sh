#!/usr/bin/env bash
# O5: audita archivos y unidades systemd preexistentes. SOLO LECTURA.
# No abre ni imprime secretos, tokens, variables privadas, logs ni contenido de unidades.
set -Eeuo pipefail
umask 077
PHASE=PRECHECK
finish() {
  rc=$?
  trap - EXIT
  echo "RESULTADO_GLOBAL=$rc"
  if [ "$rc" -ne 0 ]; then echo "FASE_FALLIDA=$PHASE"; fi
  echo "NO_SE_MODIFICARON_ARCHIVOS_UNIDADES_NI_TIMERS=1"
  echo "NO_SE_CREARON_NI_BORRARON_COPIAS=1"
  echo "CONSOLA_ABIERTA"
  exit "$rc"
}
trap finish EXIT

test "$(id -u)" -eq 0 || { echo "ERROR=REQUIERE_ROOT"; exit 2; }
BASE=/home/vencira/vencira-localcheck
DST=/usr/local/libexec/vencira
UNITDIR=/etc/systemd/system
cd "$BASE"
test "$(git branch --show-current)" = integration/local-e2e-prep
test -z "$(git diff --name-only)"
test -z "$(git diff --cached --name-only)"
echo "COMMIT=$(git rev-parse HEAD)"

PHASE=INSTALACION_EXISTENTE
if [ -L "$DST" ]; then
  echo "DIRECTORIO_INSTALADO=ENLACE_SIMBOLICO_NO_CONFIABLE"
elif [ -d "$DST" ]; then
  echo "DIRECTORIO_INSTALADO=EXISTE"
  echo "DIRECTORIO_ROOT_700=$(
    [ "$(stat -c '%u:%g:%a' "$DST")" = '0:0:700' ] && echo OK || echo NO
  )"
  echo "ENTRADAS_NIVEL_1=$(find "$DST" -mindepth 1 -maxdepth 1 -printf '.\n' | wc -l | tr -d ' ')"
else
  echo "DIRECTORIO_INSTALADO=NO_ES_DIRECTORIO"
fi

compare() {
  local key="$1" source="$2" dest="$3" mode="$4"
  if [ -L "$dest" ]; then
    echo "$key=SYMLINK_NO_ADMITIDO"
  elif [ ! -e "$dest" ]; then
    echo "$key=AUSENTE"
  elif [ ! -f "$dest" ]; then
    echo "$key=TIPO_INCORRECTO"
  elif [ "$(stat -c '%u:%g:%a' "$dest")" != "0:0:$mode" ]; then
    echo "$key=PERMISOS_O_DUENO_DIFERENTES"
  elif cmp -s -- "$source" "$dest"; then
    echo "$key=IDENTICO_A_GITHUB"
  else
    echo "$key=CONTENIDO_DIFERENTE"
  fi
}

for s in o5_backup_to_drive.sh o5_scheduled_backup.sh o5_backup_health.sh; do
  case "$s" in
    o5_backup_to_drive.sh) key=SCRIPT_BACKUP_ORIGINAL ;;
    o5_scheduled_backup.sh) key=SCRIPT_WRAPPER_DIARIO ;;
    o5_backup_health.sh) key=SCRIPT_SALUD ;;
  esac
  compare "$key" "$BASE/scripts/$s" "$DST/$s" 700
done

PHASE=UNIDADES_EXISTENTES
for u in backup.service backup.timer health.service health.timer; do
  unit="vencira-o5-$u"
  case "$u" in
    backup.service) key=BACKUP_SERVICE ;;
    backup.timer) key=BACKUP_TIMER ;;
    health.service) key=HEALTH_SERVICE ;;
    health.timer) key=HEALTH_TIMER ;;
  esac
  compare "UNIDAD_$key" "$BASE/deploy/o5/$unit" "$UNITDIR/$unit" 644
  loaded="$(systemctl show "$unit" -p FragmentPath --value 2>/dev/null || true)"
  if [ "$loaded" = "$UNITDIR/$unit" ]; then
    echo "CARGADA_$key=RUTA_ESPERADA"
  elif [ -z "$loaded" ]; then
    echo "CARGADA_$key=NO_CARGADA"
  else
    echo "CARGADA_$key=OTRA_RUTA"
  fi
  state="$(systemctl is-active "$unit" 2>/dev/null || true)"
  case "$state" in
    active|inactive|failed|activating|deactivating) ;;
    *) state=OTRO ;;
  esac
  echo "ESTADO_$key=$state"
  if [[ "$u" == *.timer ]]; then
    enabled="$(systemctl is-enabled "$unit" 2>/dev/null || true)"
    case "$enabled" in enabled|disabled|static|masked|indirect|generated) ;; *) enabled=OTRO ;; esac
    echo "HABILITADO_$key=$enabled"
  fi
done

PHASE=ULTIMA_COPIA_LOCAL
STATE=/var/lib/vencira-o5
if [ -L "$STATE" ]; then
  echo "DIRECTORIO_ESTADO=SYMLINK_NO_ADMITIDO"
elif [ -d "$STATE" ] && [ "$(stat -c '%u:%g:%a' "$STATE")" = 0:0:700 ]; then
  echo "DIRECTORIO_ESTADO=ROOT_700"
  if [ -L "$STATE/last-success.epoch" ]; then
    echo "ULTIMO_EXITO=SYMLINK_NO_ADMITIDO"
  elif [ ! -f "$STATE/last-success.epoch" ]; then
    echo "ULTIMO_EXITO=NO_REGISTRADO"
  elif [ "$(stat -c '%u:%g:%a' "$STATE/last-success.epoch")" != 0:0:600 ]; then
    echo "ULTIMO_EXITO=PERMISOS_INCORRECTOS"
  else
    epoch="$(cat "$STATE/last-success.epoch")"
    if [[ "$epoch" =~ ^[0-9]{10}$ ]]; then
      diff="$(($(date -u +%s)-epoch))"
      if [ "$diff" -ge 0 ] && [ "$diff" -le 129600 ]; then
        echo "ULTIMO_EXITO=MENOS_DE_36_HORAS"
      else
        echo "ULTIMO_EXITO=FUERA_DE_36_HORAS"
      fi
    else
      echo "ULTIMO_EXITO=FORMATO_INVALIDO"
    fi
  fi
else
  echo "DIRECTORIO_ESTADO=NO_VALIDO"
fi
if [ -f "$STATE/last-failure.epoch" ] && [ ! -L "$STATE/last-failure.epoch" ]; then
  echo "ULTIMO_FALLO=REGISTRADO"
else
  echo "ULTIMO_FALLO=NO_REGISTRADO"
fi

PHASE=OK
echo "AUDITORIA_UNIDADES_EXISTENTES=FINALIZADA"
