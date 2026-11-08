plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Set ONLY by scripts/g8_phone_apk_build.sh. The debug laboratory APK
// receives a distinct Android package ID; normal builds are unchanged.
val g8LabBuild = System.getenv("VENCIRA_G8_LAB_BUILD") == "1"
val g12LabBuild = System.getenv("VENCIRA_G12_LAB_BUILD") == "1"
val g13LabBuild = System.getenv("VENCIRA_G13_LAB_BUILD") == "1"
val g15LabBuild = System.getenv("VENCIRA_G15_LAB_BUILD") == "1"
val i8nLabBuild = System.getenv("VENCIRA_I8N_LAB_BUILD") == "1"
val i8oLabBuild = System.getenv("VENCIRA_I8O_LAB_BUILD") == "1"
val i8pLabBuild = System.getenv("VENCIRA_I8P_LAB_BUILD") == "1"
if (listOf(g8LabBuild, g12LabBuild, g13LabBuild, g15LabBuild, i8nLabBuild, i8oLabBuild, i8pLabBuild).count { it } > 1) {
    throw GradleException("Physical Android labs are mutually exclusive")
}
if ((g8LabBuild || g12LabBuild || g13LabBuild || g15LabBuild || i8nLabBuild || i8oLabBuild || i8pLabBuild) && gradle.startParameter.taskNames.any {
    it.contains("Release", ignoreCase = true) || it.contains("Profile", ignoreCase = true)
}) {
    throw GradleException("Physical Android labs must never build release/profile")
}

// Release distribution uses a separate keystore held outside this repository.
// No release artifact may silently fall back to Android's debug signing key.
val releaseBuildRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
val releaseSigningEnvironment = listOf(
    "VENCIRA_ANDROID_KEYSTORE_PATH",
    "VENCIRA_ANDROID_KEYSTORE_PASSWORD",
    "VENCIRA_ANDROID_KEY_ALIAS",
    "VENCIRA_ANDROID_KEY_PASSWORD",
)
val releaseSigningReady = releaseSigningEnvironment.all {
    !System.getenv(it).isNullOrBlank()
}
if (releaseBuildRequested && !releaseSigningReady) {
    throw GradleException("VENCIRA_ANDROID_RELEASE_SIGNING_REQUIRED")
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

    signingConfigs {
        if (releaseSigningReady) {
            create("venciraRelease") {
                storeFile = file(System.getenv("VENCIRA_ANDROID_KEYSTORE_PATH"))
                storePassword = System.getenv("VENCIRA_ANDROID_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("VENCIRA_ANDROID_KEY_ALIAS")
                keyPassword = System.getenv("VENCIRA_ANDROID_KEY_PASSWORD")
            }
        }
    }

    sourceSets {
        if (g15LabBuild) {
            // Only this G15 debug variant has OS alarm reboot receivers.
            getByName("debug").manifest.srcFile("src/g15lab/AndroidManifest.xml")
        }
    }

    buildTypes {
        debug {
            if (g8LabBuild) {
                applicationIdSuffix = ".g8lab"
                manifestPlaceholders["venciraAppLabel"] = "VENCIRA G8 Pruebas"
            }
            if (g12LabBuild) {
                applicationIdSuffix = ".g12lab"
                manifestPlaceholders["venciraAppLabel"] = "VENCIRA G12 Pruebas"
            }
            if (g13LabBuild) {
                applicationIdSuffix = ".g13lab"
                manifestPlaceholders["venciraAppLabel"] = "VENCIRA G13 TLS"
            }
            if (g15LabBuild) {
                applicationIdSuffix = ".g15lab"
                manifestPlaceholders["venciraAppLabel"] = "VENCIRA G15 Avisos"
            }
            if (i8nLabBuild) {
                applicationIdSuffix = ".i8nlab"
                manifestPlaceholders["venciraAppLabel"] = "VENCIRA I8N Keystore Lab"
            }
            if (i8oLabBuild) {
                applicationIdSuffix = ".i8olab"
                manifestPlaceholders["venciraAppLabel"] = "VENCIRA I8O Fallos"
            }
            if (i8pLabBuild) {
                applicationIdSuffix = ".i8plab"
                manifestPlaceholders["venciraAppLabel"] = "VENCIRA I8P HTTPS"
            }
        }
        release {
            if (releaseSigningReady) {
                signingConfig = signingConfigs.getByName("venciraRelease")
            }
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
