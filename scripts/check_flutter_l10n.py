#!/usr/bin/env python3
"""Comprueba que los catálogos ARB de VENCIRA tienen las mismas claves.

No requiere Flutter ni datos de clientes. Ejecución:
  python3 scripts/check_flutter_l10n.py
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "clients" / "flutter" / "lib" / "l10n"
LOCALES = ("es", "ca")
PLACEHOLDER = re.compile(r"(?<!{){([A-Za-z_]\w*)}(?!})")


def load(lang):
    path = ROOT / f"app_{lang}.arb"
    content = json.loads(path.read_text(encoding="utf-8"))
    if content.get("@@locale") != lang:
        raise ValueError(f"{path}: @@locale incorrecto")
    return {
        key: value for key, value in content.items()
        if not key.startswith("@")
    }


def main():
    data = {lang: load(lang) for lang in LOCALES}
    primary = data["es"]
    errors = []
    for lang, catalog in data.items():
        missing = set(primary) - set(catalog)
        extra = set(catalog) - set(primary)
        if missing:
            errors.append(f"{lang}: faltan claves {sorted(missing)}")
        if extra:
            errors.append(f"{lang}: claves adicionales {sorted(extra)}")
        for key in sorted(set(primary) & set(catalog)):
            if not isinstance(catalog[key], str) or not catalog[key].strip():
                errors.append(f"{lang}:{key} vacío o no textual")
            elif set(PLACEHOLDER.findall(catalog[key])) != set(
                PLACEHOLDER.findall(primary[key])
            ):
                errors.append(f"{lang}:{key}: marcadores incompatibles")
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print(f"OK: {len(primary)} textos comparados entre ES/CA")
    return 0


if __name__ == "__main__":
    sys.exit(main())
