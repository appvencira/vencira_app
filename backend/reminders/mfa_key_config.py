"""Fail-closed MFA keyring loader. Secrets are never printed."""
import os
from pathlib import Path
from cryptography.fernet import Fernet


def load_mfa_keys(*, environ=None) -> list[str]:
    env = os.environ if environ is None else environ
    raw_env = env.get("VENCIRA_MFA_FERNET_KEYS", "")
    secret_path = env.get("VENCIRA_MFA_FERNET_KEYS_FILE", "")
    if raw_env and secret_path:
        raise ValueError("Fuentes de claves MFA incompatibles")
    if secret_path:
        path = Path(secret_path)
        try:
            if not path.is_absolute() or path.is_symlink() or not path.is_file():
                raise ValueError("Archivo secreto MFA inválido")
            st = path.stat()
            if st.st_mode & 0o077 or st.st_size > 1024 or st.st_size == 0:
                raise ValueError("Permisos o tamaño de secreto MFA inválidos")
            raw = path.read_text(encoding="ascii").strip()
        except (OSError, UnicodeError) as exc:
            raise ValueError("Archivo secreto MFA no disponible") from exc
    else:
        raw = raw_env
    if not isinstance(raw, str) or not raw.strip():
        raise ValueError("Claves MFA no configuradas")
    keys = [part.strip() for part in raw.split(",")]
    if len(keys) > 5 or len(set(keys)) != len(keys) or any(not key for key in keys):
        raise ValueError("Anillo de claves MFA inválido")
    try:
        for key in keys:
            Fernet(key.encode("ascii"))
    except (ValueError, UnicodeError, TypeError) as exc:
        raise ValueError("Clave MFA inválida") from exc
    return keys
