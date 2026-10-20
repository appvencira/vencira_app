#!/usr/bin/env python3
"""Generar .env privado y único. Nunca sobrescribirlo."""
from pathlib import Path
import os
import secrets

root = Path(__file__).resolve().parent.parent
src = (root / ".env.example").read_text(encoding="utf-8")
dest = root / ".env"
if dest.exists():
    raise SystemExit("El archivo .env ya existe. No se modifica.")
src = src.replace("CHANGE_ME_LONG_RANDOM", secrets.token_urlsafe(48)).replace("CHANGE_ME_DB_PASSWORD", secrets.token_urlsafe(36))
fd = os.open(dest, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
with os.fdopen(fd, "w", encoding="utf-8") as stream:
    stream.write(src)
print("Secretos únicos creados en .env (modo 0600). No subir a GitHub.")
