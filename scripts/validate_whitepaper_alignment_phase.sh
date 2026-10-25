#!/usr/bin/env bash
# One-phase whitepaper reconciliation A01–A05; no deployment or database changes.
set -Eeuo pipefail
cd /home/vencira/vencira-localcheck
PHASE=SOURCE
test "$(git branch --show-current)" = integration/local-e2e-prep
test -z "$(git diff --name-only)"
test -z "$(git diff --cached --name-only)"
echo "COMMIT=$(git rev-parse HEAD)"
python3 - <<'PY'
from pathlib import Path
checks = {
 "A01_API_REQUIRED": ("backend/reminders/serializers.py", 'if self.instance is None:'),
 "A01_GENERATED_REFERENCE": ("backend/reminders/serializers.py", '"V-" + uuid.uuid4().hex'),
 "A01_UI_OPTIONAL_REFERENCE": ("clients/flutter/lib/ui/renewal_editor.dart", 'if (widget.existing != null) ...['),
 "A02_DEFAULT_RESET": ("backend/reminders/outcomes.py", '_reset_reminder_template(renewal, request.user)'),
 "A03_CLIENT_SUGGESTION": ("backend/reminders/person_suggestions.py", '"suggested_entry": "clients"'),
 "A03_CLIENT_UI": ("clients/flutter/lib/ui/renewal_editor.dart", "item.suggestedEntry == 'clients'"),
 "A05_TODAY_NAVIGATION": ("clients/flutter/lib/ui/dashboard_screen.dart", "_initialTodayOpened"),
 "A04_ES_LANGUAGE": ("clients/flutter/lib/l10n/app_es.arb", '"personFullNameRequired"'),
 "A04_CA_LANGUAGE": ("clients/flutter/lib/l10n/app_ca.arb", '"personFullNameRequired"'),
}
for label,(path,needle) in checks.items():
    assert needle in Path(path).read_text(), f'{label} FAILED'
    print(label + '=OK')
print('WHITEPAPER_A01_A05_STATIC=OK')
PY
PHASE=FULL_PREFLIGHT
bash scripts/validate_o7_o8_preflight.sh
echo "ALINEACION_FASE_UNICA_PREFLIGHT=OK"
echo "NO_SE_DESPLEGO_NI_MIGRO_POSTGRES=1"
