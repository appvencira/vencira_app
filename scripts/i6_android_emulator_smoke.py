#!/usr/bin/env python3
"""I6 Android emulator admission: installed ordinary debug APK, no lab login.

Only runs inside an explicitly marked CI emulator; never contacts DEV or
attempts native authentication. Does not modify app data or grant permissions.
"""
import os
import subprocess
import time
from pathlib import Path

PACKAGE = "es.vencira.vencira"
ARTIFACT = Path("/tmp/vencira-i6-emulator")
ARTIFACT.mkdir(parents=True, exist_ok=True)


def run(*args, timeout=30):
    return subprocess.run(args, check=True, capture_output=True, text=True, timeout=timeout)


def gate(ok, label):
    if not ok:
        raise AssertionError("I6_" + label + "=FAIL")
    print("I6_" + label + "=OK", flush=True)


def main():
    gate(os.environ.get("I6_ANDROID_EMULATOR_CI") == "YES", "DISPOSABLE_EMULATOR_ONLY")
    gate(os.environ.get("MFA_RELEASE_AUTHORIZED", "NO") == "NO", "MFA_DENIED")
    gate(os.environ.get("NO_DEPLOY_NO_LIVE_MIGRATION") == "1", "NO_LIVE_MIGRATIONS")
    serial = run("adb", "get-serialno").stdout.strip()
    gate(serial.startswith("emulator-"), "ADB_EMULATOR_SERIAL")
    installed = run("adb", "shell", "pm", "path", PACKAGE).stdout.strip()
    gate(installed.startswith("package:"), "ORDINARY_PACKAGE_INSTALLED")
    package_info = run("adb", "shell", "dumpsys", "package", PACKAGE).stdout
    gate("versionName=" in package_info, "PACKAGE_METADATA")

    run("adb", "shell", "am", "force-stop", PACKAGE)
    run("adb", "shell", "monkey", "-p", PACKAGE, "-c",
        "android.intent.category.LAUNCHER", "1")
    ready = False
    for attempt in range(24):
        time.sleep(2)
        focus = run("adb", "shell", "dumpsys", "window", "windows").stdout
        if PACKAGE not in focus:
            continue
        try:
            run("adb", "shell", "uiautomator", "dump", "/sdcard/i6-window.xml",
                timeout=18)
            xml = run("adb", "shell", "cat", "/sdcard/i6-window.xml").stdout
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
            continue
        if "Acceso seguro a VENCIRA" in xml and "Abrir VENCIRA en el navegador" in xml:
            ready = True
            (ARTIFACT / "accessibility.xml").write_text(xml, encoding="utf-8")
            break
    gate(ready, "WEB_ONLY_ACCESS_SCREEN")
    screen = subprocess.run(["adb", "exec-out", "screencap", "-p"],
                            capture_output=True, check=True, timeout=20).stdout
    gate(screen.startswith(b"\x89PNG\r\n\x1a\n") and len(screen) > 9000,
         "SCREENSHOT_VALID")
    (ARTIFACT / "i6-android-emulator.png").write_bytes(screen)
    gate("es.vencira.vencira.g" not in package_info,
         "NO_G8_G12_G13_G15_LAB_VARIANT")
    print("I6_ANDROID_REAL_EMULATOR=PASS", flush=True)
    print("I6_NATIVE_AUTH_RELEASE=NO", flush=True)


if __name__ == "__main__":
    main()
