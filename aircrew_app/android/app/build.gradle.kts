plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.aircrew.aircrew_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.aircrew.aircrew_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Default app name (used by the combined build); flavors override it.
        manifestPlaceholders["appName"] = "AirCrew"
    }

    // Phase 3 — two installable apps from one codebase (Flutter flavors).
    // Build: flutter build apk -t lib/main_driver.dart   --flavor driver
    //        flutter build apk -t lib/main_customer.dart --flavor customer
    flavorDimensions += "app"
    productFlavors {
        create("driver") {
            dimension = "app"
            applicationIdSuffix = ".driver"
            manifestPlaceholders["appName"] = "AirCrew Driver"
        }
        create("customer") {
            dimension = "app"
            applicationIdSuffix = ".customer"
            manifestPlaceholders["appName"] = "AirCrew Crew"
        }
    }

    buildTypes {
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
