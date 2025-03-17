plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")  // Ensure this is included
}

android {
    namespace = "com.example.plateforme_services"
    compileSdk = 35
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // Enable core library desugaring
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    defaultConfig {
        applicationId = "com.example.plateforme_services"
        minSdk = 23
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Add these lines for Firebase Messaging to work
        manifestPlaceholders += mapOf(
            "firebase_messaging_auto_init_enabled" to "true",
            "firebase_messaging_auto_init" to "true"
        )
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // Import the Firebase BoM (Bill of Materials) to use Firebase services easily
    implementation(platform("com.google.firebase:firebase-bom:33.10.0"))

    // Firebase Messaging
    implementation("com.google.firebase:firebase-messaging")

    // Use the updated desugaring library (1.2.2 or above)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
