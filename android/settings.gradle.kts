pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    // ── Java toolchain yükləyicisi ───────────────────────────────────
    //
    // `flutter_callkit_incoming` (və bəzi digər Flutter plugin-ləri)
    // `jvmToolchain(17)` elan edir. Bu maşında yeganə JDK Android
    // Studio-nun JBR-idir və o, Java 25-dir, yəni Gradle 17 tapa
    // bilmir: "Cannot find a Java installation … matching
    // {languageVersion=17}. Toolchain download repositories have not
    // been configured."
    //
    // Bu plugin həmin konfiqurasiyanı verir — Gradle lazım olan JDK-nı
    // özü yükləyib `~/.gradle/jdks`-də saxlayır. Bir dəfəlik ~180 MB.
    //
    // Alternativ — plugin-in elan etdiyi toolchain-i əvəzləmək —
    // sınandı və düzgün deyil: `javaCompiler` Gradle-da final
    // property-dir, üstəlik plugin-in öz tələbini yan keçmək onun
    // gələcək versiyalarında səssiz uyğunsuzluq yaradar. Bu, Gradle-ın
    // öz sənədləşdirilmiş həllidir və xəta mesajının özünün tövsiyə
    // etdiyi yoldur.
    //
    // Sistemə JDK 17 quraşdırılarsa bu sətir silinə bilər.
    id("org.gradle.toolchains.foojay-resolver-convention") version "1.0.0"
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.0.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
    id("com.google.gms.google-services") version "4.4.2" apply false
    // Uploads the R8 mapping file to Crashlytics on every release
    // build. Not optional now that minification is on: without it,
    // every crash report arrives as `a.b.c(Unknown Source)` and the
    // Crashlytics integration stops being worth having. Was never
    // needed before because nothing was obfuscated.
    id("com.google.firebase.crashlytics") version "3.0.2" apply false
}

include(":app")
