# PeakPin — R8 keep qaydaları (BACKLOG #4 / ACCEPTED_RISKS C1a)
#
# ─────────────────────────────────────────────────────────────────────
# ƏVVƏLCƏ BİR DƏQİQLƏŞDİRMƏ, ÇÜNKİ O, NƏYİ TEST ETMƏK LAZIM OLDUĞUNU
# DƏYİŞİR:
#
# R8 Dart koduna TOXUNMUR. Flutter Dart-ı AOT ilə `libapp.so` içinə
# native maşın koduna kompilyasiya edir; R8 isə yalnız Java/Kotlin
# bytecode → DEX zəncirində işləyir. Deməli `@JsonSerializable`,
# `freezed`, `fromJson`/`toJson` və `.g.dart` generatorları R8-dən
# ZƏRƏR GÖRMÜR — onların hamısı build zamanı Dart mənbəyinə çevrilir
# və R8-in gördüyü fayllarda ümumiyyətlə mövcud deyil.
#
# Dart tərəfini obfuskasiya edən ayrı bir şey var:
# `flutter build --obfuscate --split-debug-info=...`. O, BU FAYLA aid
# deyil və QOŞULMAYIB.
#
# Yəni cihazda axtarılmalı olan şey model serializasiyası deyil —
# aşağıdakı plugin-lərin NATIVE (Java/Kotlin) tərəfidir.
# ─────────────────────────────────────────────────────────────────────

# ── Crashlytics oxunaqlılığı ──────────────────────────────────────────
# Obfuskasiya edilmiş stack trace-i geri açmaq üçün mapping faylı
# lazımdır (Crashlytics Gradle plugin-i onu avtomatik yükləyir) VƏ
# sətir nömrələri saxlanmalıdır. Bu iki sətir olmasa hər crash hesabatı
# `a.b.c(Unknown Source)` şəklində gələr.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Refleksiya işlədən hər kitabxana üçün lazımdır — imza və annotasiya
# metadatası silinsə, generic tiplər və annotasiya oxunuşu sınır.
-keepattributes Signature,InnerClasses,EnclosingMethod
-keepattributes *Annotation*,RuntimeVisibleAnnotations,AnnotationDefault

# JNI ilə çağırılan hər şey — adı dəyişsə native tərəf tapa bilmir.
-keepclasseswithmembernames class * {
    native <methods>;
}

# ── Flutter embedding ─────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Flutter engine-i Play Core-a (deferred components) istinad edir, amma
# bu tətbiq həmin kitabxananı daxil etmir. Xəbərdarlıq susdurulur;
# sinif çağırılmır.
-dontwarn com.google.android.play.core.**

# ── Firebase / Google Play Services ───────────────────────────────────
# Firebase kitabxanaları öz `consumer-rules.pro` fayllarını AAR
# içində göndərir və AGP onları avtomatik tətbiq edir, ona görə burada
# minimum saxlanılır. Firestore-un POJO serializasiyası refleksiya
# işlədir — bu tətbiq platform kanalı üzərindən Map göndərdiyi üçün
# ondan istifadə etmir, amma qayda müdafiə xarakterlidir.
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ── flutter_webrtc — ƏN YÜKSƏK RİSK ───────────────────────────────────
# Tamamilə JNI üzərində qurulub: native tərəf Java siniflərini və
# metodlarını ADLA tapır. Obfuskasiya edilsə zənglər işləmir və bu,
# build zamanı yox, yalnız zəng başlayanda üzə çıxır.
-keep class org.webrtc.** { *; }
-keep class com.cloudwebrtc.webrtc.** { *; }
-dontwarn org.webrtc.**

# ── Branch SDK — refleksiya ilə konfiqurasiya oxuyur ──────────────────
-keep class io.branch.** { *; }
-dontwarn io.branch.**

# ── Play Billing (in_app_purchase) ────────────────────────────────────
-keep class com.android.billingclient.** { *; }
-keep class com.android.vending.billing.** { *; }
-dontwarn com.android.billingclient.**

# ── Media: video_player / audioplayers / record ───────────────────────
# ExoPlayer/Media3 refleksiya ilə renderer və extractor yükləyir.
-keep class androidx.media3.** { *; }
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn androidx.media3.**
-dontwarn com.google.android.exoplayer2.**

# ── Google Maps ───────────────────────────────────────────────────────
-keep class com.google.android.libraries.maps.** { *; }
-dontwarn com.google.android.libraries.maps.**

# ── image_cropper (uCrop) ─────────────────────────────────────────────
-keep class com.yalantis.ucrop.** { *; }
-dontwarn com.yalantis.ucrop.**

# ── flutter_secure_storage ────────────────────────────────────────────
# AndroidX Security / Tink — kripto provayderlərini adla tapır.
-keep class androidx.security.crypto.** { *; }
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**

# ── Sign in with Apple / Google Sign-In ───────────────────────────────
-keep class com.aboutyou.dart_packages.sign_in_with_apple.** { *; }

# ── Kotlin coroutines / metadata ──────────────────────────────────────
-keep class kotlin.Metadata { *; }
-dontwarn kotlinx.coroutines.**

# ── AndroidX ümumi ────────────────────────────────────────────────────
-dontwarn androidx.**

# ── Enum-lar ──────────────────────────────────────────────────────────
# `valueOf`/`values` refleksiya ilə çağırılır (plugin-lərdə geniş
# yayılmışdır — məsələn icazə statusları).
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# ── Parcelable / Serializable ─────────────────────────────────────────
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}
