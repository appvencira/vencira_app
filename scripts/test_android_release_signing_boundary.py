#!/usr/bin/env python3
"""Source-only checks of Android release signing and separate G8/G12/G13 labs.

No keystores, credentials, Gradle execution, or Android device required.
"""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GRADLE = ROOT / "clients/flutter/android/app/build.gradle.kts"
IGNORE = ROOT / "clients/flutter/android/.gitignore"


class AndroidReleaseSigningBoundaryTests(unittest.TestCase):
    def setUp(self):
        self.gradle = GRADLE.read_text(encoding="utf-8")

    def test_release_must_not_use_debug_signing(self):
        self.assertNotIn('signingConfig = signingConfigs.getByName("debug")', self.gradle)
        self.assertIn('signingConfig = signingConfigs.getByName("venciraRelease")', self.gradle)

    def test_external_signing_requires_all_four_parameters(self):
        for variable in (
            "VENCIRA_ANDROID_KEYSTORE_PATH",
            "VENCIRA_ANDROID_KEYSTORE_PASSWORD",
            "VENCIRA_ANDROID_KEY_ALIAS",
            "VENCIRA_ANDROID_KEY_PASSWORD",
        ):
            with self.subTest(variable=variable):
                self.assertIn(variable, self.gradle)
        self.assertIn("releaseSigningEnvironment.all", self.gradle)
        self.assertIn("releaseBuildRequested && !releaseSigningReady", self.gradle)
        self.assertIn("VENCIRA_ANDROID_RELEASE_SIGNING_REQUIRED", self.gradle)

    def test_debug_labs_remain_isolated_and_release_denied(self):
        for lab in ("g8", "g12", "g13"):
            with self.subTest(lab=lab):
                self.assertIn(f'VENCIRA_{lab.upper()}_LAB_BUILD', self.gradle)
                self.assertIn(f'applicationIdSuffix = ".{lab}lab"', self.gradle)
        self.assertIn("Physical Android labs must never build release/profile", self.gradle)

    def test_local_signing_material_ignored(self):
        ignore = IGNORE.read_text(encoding="utf-8")
        for pattern in ("key.properties", "**/*.keystore", "**/*.jks"):
            self.assertIn(pattern, ignore)


if __name__ == "__main__":
    unittest.main()
