plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.inteliwave_app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
        freeCompilerArgs = listOf(
            "-Xjvm-default=all",
            "-Xlint:-deprecation"
        )
    }

    defaultConfig {
        applicationId = "com.example.inteliwave_app"
        minSdk = flutter.minSdkVersion // BLE requires API 21+
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Sign with debug keys for now (replace with your keystore for Play Store)
            signingConfig = signingConfigs.getByName("debug")

            // ── R8 code shrinking & obfuscation ──────────────────────────────
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }

        debug {
            // Keep debug fast — no minification
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    // ── Bundle optimisation (for Play Store AAB) ──────────────────────────────
    bundle {
        language { enableSplit = true }
        density  { enableSplit = true }
        abi      { enableSplit = true }
    }
}

dependencies {
    // Slim NIO variant — avoids shipping the full JDK desugaring library
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs_nio:2.1.4")
}

flutter {
    source = "../.."
}
