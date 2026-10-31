#!/usr/bin/env python3
"""MB1 M1-05: two-generation, fail-closed, actual PG17 restore drill.

All Docker names, data, manifests and keys are synthetic and disposable.
Independent trusted head is SIMULATED in a separate local temporary directory;
this is NOT genuine independent custody and does NOT authorize operational DR.
"""
import hashlib
import json
import os
from pathlib import Path
import secrets
import shutil
import subprocess
import sys
import tempfile


BRANCH = "feature/c-ficha-independent-attachments"
REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / "backend"))
from renewal_attachments.offline_antirollback_head_mb1 import AntiRollbackError
from renewal_attachments.offline_antirollback_package_mb1 import (
    issue_package_receipt, verify_package_antirollback,
)

ITEM = "a" * 32
PREFIX = "mb1_ar_e2e_"
RELEASE_MARKERS = (
    "MB1_EXTERNAL_HEAD_CUSTODY=NOT_VERIFIED",
    "MB1_GLOBAL_FREEZE=NOT_VERIFIED",
    "MB1_OPERATIONAL_BACKUP_INTEGRATION=NOT_VERIFIED",
    "MB1_RELEASE_AUTHORIZED=NO",
    "NO_DEPLOY_NO_LIVE_MIGRATION=1",
)


def run(args, *, input=None, timeout=90):
    return subprocess.run(
        [str(x) for x in args], input=input, stdout=subprocess.PIPE,
        stderr=subprocess.PIPE, check=True, timeout=timeout
    ).stdout


def expect_failure(fn, code):
    try:
        fn()
    except (AntiRollbackError, OSError, ValueError):
        print(code + "=OK", flush=True)
        return
    raise RuntimeError("NEGATIVE_CASE_NOT_REJECTED:" + code)


def stage(root, seq, db, image):
    """Produce one REAL synthetic encrypted MB1 package with fresh keys."""
    source = root / ("source" + str(seq))
    source.mkdir(mode=0o700)
    (source / "objects").mkdir(mode=0o700)
    (source / "journal").mkdir(mode=0o700)
    run(["docker", "exec", db, "psql", "-X", "-v", "ON_ERROR_STOP=1",
         "-U", "mb1", "-d", "mb1", "-c",
         "UPDATE mb1_rollback_probe SET marker = " + str(seq) + ";"])
    dump = run(["docker", "exec", db, "pg_dump", "-Fc", "-U", "mb1", "-d", "mb1"])
    if not dump:
        raise RuntimeError("PG_DUMP_EMPTY")
    (source / "source.dump").write_bytes(dump)
    obj = ("MB1_SYNTHETIC_ENCRYPTED_OBJECT_VERSION_" + str(seq)).encode()
    journal = json.dumps(
        {"version": 1, "storage_key": ITEM, "state": "pending",
         "sha256": hashlib.sha256(obj).hexdigest(), "sequence": seq},
        separators=(",", ":"), sort_keys=True
    ).encode()
    (source / "objects" / ITEM).write_bytes(obj)
    (source / "journal" / (ITEM + ".json")).write_bytes(journal)
    for path in (source / "source.dump", source / "objects" / ITEM,
                 source / "journal" / (ITEM + ".json")):
        path.chmod(0o600)
    run(["docker", "run", "--rm", "--network", "none", "--user", "0:0",
         "--mount", "type=bind,src=" + str(source) + ",dst=/capture",
         "-e", "VENCIRA_ENV=test", "-e", "MB1_DISPOSABLE_ONLY=1", image,
         "python", "-m", "renewal_attachments.mb1_e2e_authenticated_pack",
         "pack", "/capture"], timeout=100)

    pkg = root / ("package" + str(seq))
    pkg.mkdir(mode=0o700)
    custody = root / "keymedia" / str(seq)
    custody.mkdir(mode=0o700)
    for fname in ("capture.enc", "manifest.json", "manifest.mac"):
        shutil.copy2(source / fname, pkg / fname)
        (pkg / fname).chmod(0o600)
    for fname in ("encryption.key", "authentication.key"):
        shutil.copy2(source / "keys" / fname, custody / fname)
        (custody / fname).chmod(0o600)
    # Never pass source plaintext to recovery; remove the staging input.
    shutil.rmtree(source)
    if sorted(x.name for x in pkg.iterdir()) != sorted((
            "capture.enc", "manifest.json", "manifest.mac")):
        raise RuntimeError("NONCANONICAL_PHYSICAL_PACKAGE")
    return pkg, custody


def checked_package(package, keys, receipt, trusted_head, receipt_key):
    result = verify_package_antirollback(
        package, manifest_key=(keys / "authentication.key").read_bytes(),
        receipt_key=receipt_key, candidate_receipt=receipt,
        trusted_external_head=trusted_head,
    )
    if not result["verified"] or result["release_authorized"]:
        raise RuntimeError("ANTIROLLBACK_GATE_INVALID")
    return result


def app_unpack(package, keys, image, action, recovered=None):
    args = [
        "docker", "run", "--rm", "--network", "none", "--user", "0:0",
        "--mount", "type=bind,src=" + str(package) + ",dst=/capture,readonly",
        "--mount", "type=bind,src=" + str(keys) + ",dst=/keymedia,readonly",
        "-e", "VENCIRA_ENV=test", "-e", "MB1_DISPOSABLE_ONLY=1",
        "-e", "MB1_SYNTHETIC_KEY_ROOT=/keymedia",
    ]
    if recovered is not None:
        args += ["--mount",
                 "type=bind,src=" + str(recovered) + ",dst=/recovered"]
    args += [image, "python", "-m",
             "renewal_attachments.mb1_e2e_authenticated_pack",
             action, "/capture"]
    if recovered is not None:
        args += ["/recovered"]
    return run(args, timeout=90)


def main():
    if os.getenv("MB1_ANTIROLLBACK_E2E_LAB") != "YES":
        raise RuntimeError("EXPLICIT_SYNTHETIC_OPT_IN_REQUIRED")
    if run(["git", "-C", str(REPO), "branch", "--show-current"]).decode().strip() != BRANCH:
        raise RuntimeError("UNEXPECTED_GIT_BRANCH")
    os.environ["VENCIRA_ENV"] = "test"
    os.environ["MB1_DISPOSABLE_ONLY"] = "1"
    db = PREFIX + str(os.getpid()) + "_" + secrets.token_hex(3)
    image = "vencira-mb1-ar-e2e:" + str(os.getpid()) + "-" + secrets.token_hex(4)
    db_started = image_built = False
    try:
        with tempfile.TemporaryDirectory(prefix=PREFIX) as tmp:
            root = Path(tmp)
            # The 700 local "keymedia" and "trust" emulate separated
            # media but do NOT provide independent physical custody.
            (root / "keymedia").mkdir(mode=0o700)
            (root / "trust").mkdir(mode=0o700)
            run(["docker", "build", "-q", "-t", image, str(REPO / "backend")],
                timeout=240)
            image_built = True
            run(["docker", "run", "-d", "--name", db, "--network", "none",
                 "-e", "POSTGRES_USER=mb1", "-e", "POSTGRES_DB=mb1",
                 "-e", "POSTGRES_PASSWORD=synthetic-only",
                 "postgres:17-alpine"])
            db_started = True
            import time
            for _ in range(50):
                ready = subprocess.run(
                    ["docker", "exec", db, "pg_isready", "-U", "mb1", "-d", "mb1"],
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
                ).returncode == 0
                if ready:
                    break
                time.sleep(0.2)
            else:
                raise RuntimeError("SYNTHETIC_PG17_NOT_READY")
            run(["docker", "exec", db, "psql", "-X", "-v", "ON_ERROR_STOP=1",
                 "-U", "mb1", "-d", "mb1",
                 "-c", "CREATE TABLE mb1_rollback_probe (marker integer NOT NULL);"
                       "INSERT INTO mb1_rollback_probe VALUES (0);"])
            pkg1, keys1 = stage(root, 1, db, image)
            pkg2, keys2 = stage(root, 2, db, image)
            receipt_key = secrets.token_bytes(32)
            trusted_path = root / "trust" / "trusted-head.receipt"
            # The only trusted copy of the active head is in a distinct
            # host-local directory, NOT in either package, not in real custody.
            head1 = issue_package_receipt(
                pkg1, manifest_key=(keys1 / "authentication.key").read_bytes(),
                receipt_key=receipt_key
            )
            head2 = issue_package_receipt(
                pkg2, manifest_key=(keys2 / "authentication.key").read_bytes(),
                receipt_key=receipt_key, trusted_previous_head=head1
            )
            trusted_path.write_bytes(head2)
            trusted_path.chmod(0o600)
            head = trusted_path.read_bytes()
            print("MB1_TWO_ENCRYPTED_PHYSICAL_GENERATIONS=OK", flush=True)
            print("MB1_SYNTHETIC_TRUSTED_HEAD_ADVANCED=OK", flush=True)

            # Absolutely no pg_restore call occurs until all negatives pass
            # and the current package passes with the separately held head.
            expect_failure(
                lambda: checked_package(pkg1, keys1, head1, head, receipt_key),
                "MB1_STALE_VALID_PACKAGE_REJECTED_BEFORE_RESTORE",
            )
            expect_failure(
                lambda: checked_package(pkg1, keys1, head2, head, receipt_key),
                "MB1_CROSS_PACKAGE_RECEIPT_REJECTED",
            )
            expect_failure(
                lambda: checked_package(pkg2, keys2, head2, None, receipt_key),
                "MB1_MISSING_EXTERNAL_HEAD_REJECTED",
            )
            # Tamper one physical file in a copy, leaving the genuine intact.
            altered = root / "tampered"
            altered.mkdir(mode=0o700)
            for p in pkg2.iterdir():
                shutil.copy2(p, altered / p.name)
            (altered / "capture.enc").write_bytes(b"tampered")
            (altered / "capture.enc").chmod(0o600)
            expect_failure(
                lambda: checked_package(altered, keys2, head2, head, receipt_key),
                "MB1_TAMPERED_PACKAGE_REJECTED",
            )
            result = checked_package(pkg2, keys2, head2, head, receipt_key)
            if result["sequence"] != 2:
                raise RuntimeError("TRUSTED_HEAD_SEQUENCE_MISMATCH")
            print("MB1_LATEST_PACKAGE_PREFLIGHT_VERIFIED=OK", flush=True)

            # Gated restore: neither old nor tampered package reaches pg_restore.
            run(["docker", "exec", db, "createdb", "-U", "mb1", "mb1restored"])
            pg_dump = app_unpack(pkg2, keys2, image, "detached_stream")
            run(["docker", "exec", "-i", db, "pg_restore", "--exit-on-error",
                 "--no-owner", "--no-privileges", "-U", "mb1",
                 "-d", "mb1restored"], input=pg_dump)
            marker = run(
                ["docker", "exec", db, "psql", "-X", "-A", "-t",
                 "-v", "ON_ERROR_STOP=1", "-U", "mb1",
                 "-d", "mb1restored",
                 "-c", "SELECT marker FROM mb1_rollback_probe;"]
            ).decode().strip()
            if marker != "2":
                raise RuntimeError("RESTORE_RETURNED_OLD_VERSION")
            recovered = root / "recovered"
            recovered.mkdir(mode=0o700)
            app_unpack(pkg2, keys2, image, "detached_extract_to", recovered)
            obj = (recovered / ITEM).read_bytes()
            journal = json.loads((recovered / (ITEM + ".json")).read_bytes())
            if (obj != b"MB1_SYNTHETIC_ENCRYPTED_OBJECT_VERSION_2" or
                    journal.get("sequence") != 2 or
                    journal.get("sha256") != hashlib.sha256(obj).hexdigest() or
                    journal.get("storage_key") != ITEM):
                raise RuntimeError("RESTORED_OBJECT_JOURNAL_MISMATCH")
            print("MB1_CURRENT_PG17_RESTORE_AFTER_GATE=OK", flush=True)
            print("MB1_CURRENT_OBJECT_JOURNAL_RESTORE=OK", flush=True)
            print("MB1_ANTIROLLBACK_GATED_E2E_LAB=OK", flush=True)
    finally:
        if db_started:
            subprocess.run(["docker", "rm", "-f", db],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if image_built:
            subprocess.run(["docker", "image", "rm", image],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


if __name__ == "__main__":
    rc = 0
    try:
        main()
    except Exception as exc:
        rc = 1
        # Only type: never print subprocess args, paths, key material or env.
        print("MB1_ANTIROLLBACK_E2E_FAILED=" + type(exc).__name__, flush=True)
    finally:
        for marker in RELEASE_MARKERS:
            print(marker, flush=True)
        print("MB1_ANTIROLLBACK_E2E_RESULT=" + str(rc), flush=True)
    sys.exit(rc)
