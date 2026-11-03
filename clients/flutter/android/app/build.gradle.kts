plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Set ONLY by scripts/g8_phone_apk_build.sh. The debug laboratory APK
// receives a distinct Android package ID; normal builds are unchanged.
val g8LabBuild = System.getenv("VENCIRA_G8_LAB_BUILD") == "1"
if (g8LabBuild && gradle.startParameter.taskNames.any {
    it.contains("Release", ignoreCase = true) || it.contains("Profile", ignoreCase = true)
}) {
    throw GradleException("G8 lab must never be built as release/profile")
}

android {
    namespace = "es.vencira.vencira"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "es.vencira.vencira"
        manifestPlaceholders["venciraAppLabel"] = "vencira"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        debug {
            if (g8LabBuild) {
                applicationIdSuffix = ".g8lab"
                manifestPlaceholders["venciraAppLabel"] = "VENCIRA G8 Pruebas"
            }
        }
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
