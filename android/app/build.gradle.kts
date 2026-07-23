plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.meevima.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.meevima.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
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

// Workaround: geocoding_android (still true as of 3.3.1, the latest on
// pub.dev) hardcodes `compileSdk 33` in its own android/build.gradle,
// but its transitive androidx deps (fragment 1.7.1, window 1.2.0, etc.
// — pulled in by other Firebase/androidx plugins in this project) now
// require compileSdk 34+, so `checkDebugAarMetadata` fails on that
// plugin specifically. Bumping only OUR app's compileSdk above doesn't
// fix it, since each Flutter plugin is its own Gradle subproject with
// its own compileSdk setting. This forces every OTHER subproject's
// compileSdk to match ours post-evaluation, without touching
// compileSdk/targetSdk/minSdk in the `android {}` block above.
// `:app` itself is skipped — by the time this fires, something else
// (the Google Services plugin) has already read/locked its compileSdk,
// and re-setting it errors with "too late to set compileSdk". `:app`
// doesn't need this anyway, since its compileSdk is already correct.
rootProject.subprojects {
    if (path == ":app") return@subprojects
    afterEvaluate {
        extensions.findByName("android")?.let { ext ->
            if (ext is com.android.build.gradle.BaseExtension) {
                ext.compileSdkVersion("android-${flutter.compileSdkVersion}")
            }
        }
    }
}
