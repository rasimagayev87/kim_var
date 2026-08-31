import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

// android/key.properties + android/keystore/peakpin-release.jks — both
// gitignored (see android/.gitignore's `key.properties`/`**/*.jks`
// entries), never committed. This is the app's real, permanent Play
// Store signing identity: losing this keystore means losing the
// ability to ever publish an update to the same app listing again, so
// it (and the passwords in key.properties) need a real external
// backup, not just this checkout.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "com.peakpin.app"
    // Pinned to explicit literals rather than floating with
    // `flutter.compileSdkVersion`/`minSdkVersion`/`targetSdkVersion` —
    // see docs/BACKWARD_COMPATIBILITY.md for why: these values resolve
    // from whatever Flutter SDK happens to build the app, so an
    // unrelated `flutter upgrade` on a developer's machine could
    // silently raise the real minimum OS version this app requires
    // without that ever being a deliberate, reviewed decision. 24/36/36
    // match what this project's current Flutter SDK already resolved
    // them to at the time of pinning.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.peakpin.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Google Maps API key — read from the same gitignored
        // key.properties this file already loads for release signing
        // (see keystoreProperties above), never committed. Injected
        // into AndroidManifest.xml's `com.google.android.geo.API_KEY`
        // meta-data via `${mapsApiKey}` there. Empty string (rather
        // than failing the build) when the property is absent, so a
        // fresh checkout without key.properties still builds — the map
        // just won't render tiles until it's added, same tradeoff the
        // release-signing fallback above already makes.
        manifestPlaceholders["mapsApiKey"] = keystoreProperties.getProperty("mapsApiKey", "")
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { rootProject.file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // BACKLOG #4 / ACCEPTED_RISKS C1a — R8 was off, so the
            // shipped APK's Java/Kotlin side was fully readable with
            // `apktool`/`jadx`. Turning it on shrinks and obfuscates
            // that side; it does NOT touch Dart, which is already AOT
            // native code in `libapp.so` (Dart obfuscation is
            // `flutter build --obfuscate`, deliberately not used here).
            //
            // `proguard-android-optimize.txt` is Android's own
            // baseline; `proguard-rules.pro` holds this app's keep
            // rules and explains what each one protects. Read that file
            // before touching this line.
            isMinifyEnabled = true
            // Drops unreferenced resources once R8 knows what code
            // survives. Requires minification to be on.
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            // Düzəliş Prompt 10 / INFRA-37 — this USED to fall back to
            // debug signing silently whenever key.properties was
            // missing, with no way to tell a deliberate local-dev build
            // apart from a release pipeline that simply forgot to
            // provide the real keystore. A debug-signed release
            // AAB/APK that actually shipped could never be updated
            // again with a properly-signed build (a genuine, permanent
            // back-compat dead end) — the fallback still exists for
            // local `flutter run --release` testing, but now requires
            // an EXPLICIT opt-in (`-PallowDebugSigning=true`) instead
            // of being the silent default; anything else (a CI/release
            // build with no keystore AND no explicit flag) fails the
            // build loudly instead of quietly producing a debug-signed
            // release artifact.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else if (project.hasProperty("allowDebugSigning")) {
                signingConfigs.getByName("debug")
            } else {
                throw GradleException(
                    "Release keystore tapılmadı (android/key.properties yoxdur). " +
                    "Yerli test üçün debug imzasına keçmək istəyirsinizsə " +
                    "-PallowDebugSigning=true ilə işə salın."
                )
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
