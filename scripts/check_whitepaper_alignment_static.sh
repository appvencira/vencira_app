#!/usr/bin/env bash
# Whitepaper §§5,6,9,13: static fail-closed checks, NO database changes.
set -Eeuo pipefail
cd /home/vencira/vencira-localcheck
bash -n scripts/validate_o7_o8_preflight.sh
bash -n scripts/deploy_whitepaper_alignment_no_migrations.sh
python3 scripts/check_flutter_l10n.py
python3 - <<'PY'
import json
from pathlib import Path
root=Path(".")
deploy=(root/"scripts/deploy_whitepaper_alignment_no_migrations.sh").read_text()
checks=[
  "VALIDATED=ed85fdbb17f89bbb8623a5f8a8282c2f975a6642",
  "BACKUP_O5_RECIENTE_Y_CIFRADO=OK",
  "POSTGRES_0015_INTACTO_PRE=OK",
  "IMAGENES_ANTERIORES_RECUPERABLES=OK",
  "step BUILD_API_WEB",
  "step MIGRATIONS_CHECK_ONLY_NEW_IMAGE",
  "COMPILACION_SIN_CAMBIOS_EN_SERVICIOS_ACTIVOS=OK",
  "PHASE=DEPLOY_API",
  "PHASE=DEPLOY_WEB",
  "POSTGRES_0015_SIN_CAMBIOS=OK",
]
positions=[deploy.find(token) for token in checks]
assert all(pos >= 0 for pos in positions), "missing deployment guard"
assert positions == sorted(positions), "deploy operations out of order"
assert "WP_ALIGNMENT_DESPLIEGUE_SIN_MIGRACION=OK" in deploy, "missing success marker"
for unsafe in ("migrate --noinput", "migrate --fake", "migrate reminders 0015",
               "down -v", "restic prune", "restic forget",
               "docker compose down", "pg_restore", "docker rm -f"):
    assert unsafe not in deploy, "unsafe operation found"
source={p: (root/p).read_text() for p in (
    "backend/reminders/serializers.py", "backend/reminders/outcomes.py",
    "backend/reminders/person_suggestions.py",
    "clients/flutter/lib/ui/renewal_editor.dart",
    "clients/flutter/lib/ui/dashboard_screen.dart",
    "clients/flutter/lib/main.dart",
)}
assert 'if self.instance is None:' in source["backend/reminders/serializers.py"]
assert 'attrs["customer_reference"] = "V-" + uuid.uuid4().hex' in source["backend/reminders/serializers.py"]
assert '_reset_reminder_template(renewal, request.user)' in source["backend/reminders/outcomes.py"]
assert '"suggested_entry": "clients" if item.entry == "clients" else None' in source["backend/reminders/person_suggestions.py"]
assert "item.suggestedEntry == 'clients'" in source["clients/flutter/lib/ui/renewal_editor.dart"]
assert "widget.openTodayOnLoad" in source["clients/flutter/lib/ui/dashboard_screen.dart"]
assert "openTodayOnLoad: widget.api == null" in source["clients/flutter/lib/main.dart"]
es=json.loads((root/"clients/flutter/lib/l10n/app_es.arb").read_text())
ca=json.loads((root/"clients/flutter/lib/l10n/app_ca.arb").read_text())
for key in ("controlTitle","draftSaveOnly","personFullNameRequired",
            "editorPolicySection","detailText01","previewText01",
            "agendaFiltersShort"):
    assert isinstance(es.get(key),str) and isinstance(ca.get(key),str)
print("WP_ALIGNMENT_STATIC=OK")
PY
