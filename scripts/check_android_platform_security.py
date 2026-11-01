#!/usr/bin/env python3
"""Static fail-closed Android release surface check (no device operations)."""
from pathlib import Path
import re
import sys
from xml.etree import ElementTree

ROOT = Path(__file__).resolve().parents[1]
GRADLE = ROOT / "clients/flutter/android/app/build.gradle.kts"
MANIFEST = ROOT / "clients/flutter/android/app/src/main/AndroidManifest.xml"
NAMESPACE = "{http://schemas.android.com/apk/res/android}"

def main() -> int:
    if not GRADLE.is_file() or not MANIFEST.is_file():
        print("ANDROID_PLATFORM_GUARD=FAIL_MISSING_SCAFFOLD")
        return 1
    gradle = GRADLE.read_text(encoding="utf-8")
    if (
        'applicationId = "es.vencira"' not in gradle
        or "isCoreLibraryDesugaringEnabled = true" not in gradle
        or 'coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")'
        not in gradle
        or re.search(r"signingConfig\s*=\s*signingConfigs\.", gradle)
    ):
        print("ANDROID_PLATFORM_GUARD=FAIL_GRADLE_RELEASE_OR_DESUGARING")
        return 1
    try:
        root = ElementTree.parse(MANIFEST).getroot()
    except (OSError, ElementTree.ParseError):
        print("ANDROID_PLATFORM_GUARD=FAIL_MANIFEST_XML")
        return 1
    app = root.find("application")
    if app is None or app.get(NAMESPACE + "allowBackup") != "false" or (
        app.get(NAMESPACE + "usesCleartextTraffic") != "false"
    ):
        print("ANDROID_PLATFORM_GUARD=FAIL_BACKUP_OR_CLEAR_TEXT")
        return 1
    for permission in root.findall("uses-permission"):
        if permission.get(NAMESPACE + "name") in {
            "android.permission.USE_EXACT_ALARM",
            "android.permission.SCHEDULE_EXACT_ALARM",
            "android.permission.MANAGE_EXTERNAL_STORAGE",
        }:
            print("ANDROID_PLATFORM_GUARD=FAIL_BROAD_PERMISSION")
            return 1
    print("ANDROID_PLATFORM_GUARD=PASS")
    print("ANDROID_RELEASE_SIGNING_AUTHORIZED=NO")
    print("ANDROID_LOCAL_NOTIFICATIONS_ACTIVATED=NO")
    return 0

if __name__ == "__main__":
    sys.exit(main())
