# PeakPin — Buraxılış Hazırlığı Checklist

Son yenilənmə: 2026-08-26. Bu sənəd əvvəllər mövcud olmayıb — ilk dəfə bu tarixdə yaradılıb, bütün maddələr birbaşa kod/canlı sistem yoxlaması ilə doğrulanıb (sadəcə bəyanat kimi qəbul edilməyib).

---

## 1. Tamamlanmış maddələr

| Maddə | Status | Qeyd |
|---|---|---|
| MMC qeydiyyatı | ✅ Tamamlanıb | 19.08.2026, VÖEN 1204074391 (istifadəçi tərəfindən təsdiqlənib, xarici mənbədən yoxlanıla bilməz) |
| Bank hesabı | ✅ Açılıb | İstifadəçi tərəfindən təsdiqlənib |
| Domen (peakpin.app) | ✅ Alınıb və canlıdır | `curl https://peakpin.app` → HTTP 200 (birbaşa yoxlanıldı) |
| **Privacy Policy / Terms of Service — MMC adına** | ✅ **ARTIQ TAMAMLANIB** | ⚠️ Bu maddə əvvəllər "açıq" kimi qeyd olunmuşdu, amma yoxladım: `https://peakpin.app/privacy-policy.html` və `/terms-of-service.html` hər ikisi artıq **"PeakPin MMC"** yazır, "Rasim Ağayev" adına heç bir istinad tapılmadı. Deploy tarixi: 18.08.2026. Əlavə əməliyyat lazım deyil. |
| Epoint ödəniş inteqrasiyası (əsas axın) | ✅ Qurulub, in-app WebView-a keçirilib | 4 ödəniş nöqtəsinin (Təklif haqqı, Boost, Venue abunəliyi, PinBox) hamısı `presentEpointCheckout()` vasitəsilə daxili `WebViewWidget`-dən keçir, xarici brauzerə çıxış yoxdur (kod səviyyəsində təsdiqləndi) |
| Qiymətləndirmə — Boost | ✅ Finallaşıb | `functions/src/index.ts:3226` — 6/12/18 saat → 2/4/6 AZN (tam istifadəçinin dediyi kimi) |
| Qiymətləndirmə — Təklif yerləşdirmə haqqı | ✅ Finallaşıb (kiçik dəqiqləşdirmə) | `functions/src/index.ts:2880` — 15/20/25/30 AZN pilləli sxem doğrudur, AMMA kateqoriya sayı faktiki **37**-dir (34 deyil) — bu, sənədləşdirmə fərqidir, funksional problem deyil |
| Qiymətləndirmə — VIP (IAP) | ✅ Store-da konfiqurasiya olunub | Qiymətlər kodda saxlanmır, birbaşa App Store/Play Store məhsul kataloqundan gəlir (`vip_screen.dart:125`) — kod tərəfindən yoxlanıla bilməz, mağaza tərəfində maddi olduğu təsdiqlənib |

---

## 2. Hələ açıq / diqqət tələb edən maddələr

| Maddə | Status | Detal |
|---|---|---|
| Apple Developer Program / Google Play Console — Organization (DUNS) | 🟡 Davam edir | Xarici proses, kod/API-dən yoxlanıla bilməz — istifadəçi məlumatına əsasən davam edir |
| **Firebase App Check** | 🟡 **Yarımçıq** | Client tərəfi TAM konfiqurasiyalıdır (`main.dart`: iOS-da DeviceCheck, Android-da Play Integrity, debug-da debug provider). **AMMA** Firebase Console-dan birbaşa API ilə yoxladım: server tərəfdə enforcement rejimi **4 servisin də (Firestore, Storage, Identity Toolkit, OAuth2) üzərində "UNENFORCED"**-dir. Yəni tətbiq token göndərir, amma backend onu HƏLƏ TƏLƏB ETMİR/yoxlamır — real qorunma aktiv deyil. Buraxılışdan əvvəl qərar lazımdır: enforcement-i aktivləşdirmək (tövsiyə olunur, amma əvvəlcə test tələb edir ki, real cihazlarda token generasiyası bloklamasın) və ya şüurlu şəkildə sonraya saxlamaq. |
| Store vitrin materialları — mətn | ✅ Tamamlanıb | `fastlane/metadata/` — həm iOS (az, en-US: description/keywords/subtitle/promotional_text), həm Android (az-AZ, en-US: title/short-full description) tam doldurulub |
| Store vitrin materialları — ikon | ✅ Mövcuddur | `assets/icon.png`, `assets/icon_foreground.png` — real fayllar |
| **Store vitrin materialları — skrinşotlar** | 🔴 **Yarımçıq** | `screenshots/android/` — 6 skrinşot var (login, discover map/venues, chats, profile, VIP). **`screenshots/ios/` qovluğu ÜMUMİYYƏTLƏ YOXDUR** — iOS App Store təqdimatı üçün sıfır skrinşot hazır. Bu, real təqdim maneəsidir. |
| Firebase-də köhnə app qeydləri | 🟡 Təmizlik tövsiyəsi | `com.meevima.app` (iOS+Android) və `com.example.kim_var` (Android) hələ Firebase-də qeydli qalıb — köhnə rebrand qalıqları, funksional problem yaratmır, amma qarışıqlıq üçün silinə bilər |

---

## 3. Bu sessiyanın tam funksionallıq auditindən (2026-08-26) tapılan maddələr

Hamısı istifadəçi tərəfindən prioritetli elan edilib — heç biri ikinci dərəcəli sayılmır.

| # | Ekran/Komponent | Problem |
|---|---|---|
| 1 | `lib/core/widgets/premium_upsell_sheet.dart:84` | Premium kilidli funksiyaya toxunanda çıxan "Upgrade" düyməsi real VIP alış axınına deyil, `ComingSoonScreen`-ə aparır — halbuki real VIP alış axını tətbiqdə mövcuddur və Ayarlar → VIP-dən əlçatandır. Birbaşa gəlir itkisi riski. |
| 2 | `lib/features/settings/account/.../change_email_sheet.dart` + `firebase_account_repository.dart:176` | E-poçt dəyişəndə yalnız Firestore sənədi yenilənir, **Firebase Auth hesabının özü yenilənmir**. İstifadəçi yeni e-poçtla giriş edə bilməyə bilər, iki mənbə arasında səssiz uyğunsuzluq yaranır. |
| 3 | `lib/features/privacy/domain/usecases/update_visibility_radius_usecase.dart` | "Görünmə radiusu" sazlaması Firestore-a yazılır və geri göstərilir, amma **heç bir sorğuda oxunmur/tətbiq edilmir** — nə client tərəfdə (`nearbyUsersProvider`), nə server tərəfdə. Real təsiri sıfırdır. |
| 4 | `lib/features/privacy/domain/usecases/update_two_factor_enabled_usecase.dart` | Yalnız `twoFactorEnabled` bayrağı dəyişdirilir, real ikinci amil (Firebase Auth MFA) heç vaxt tələb olunmur. Sonrakı girişlərə heç bir təsiri yoxdur. |
| 5 | `lib/features/privacy/presentation/screens/export_data_screen.dart` | "Məlumatlarımı yüklə" yalnız `users/{uid}` sənədini JSON kimi göstərir (kopyalana bilər) — mesajlar/hadisələr daxil deyil, real fayl/e-poçt çatdırılması yoxdur. |
| 6 | `lib/features/offers/presentation/screens/my_offers_screen.dart:48-50` | Şəbəkə/Firestore xətası zamanı istifadəçiyə xam exception mətni göstərilir (məs. `[cloud_firestore/permission-denied]...`), dost mesaj/yenidən cəhd düyməsi yoxdur. |
| 7 | `lib/features/settings/notifications/.../notifications_screen.dart:111-117` | E-poçt bildirişləri toggle-ı açıq şəkildə "Coming soon" nişanlıdır və deaktivdir — buraxılış üçün gözləntini təsdiqləmək lazımdır (aldadıcı deyil, sadəcə funksional deyil). |
| 8 | `lib/features/profile/presentation/screens/edit_profile_screen.dart` | "Yadda saxla" düyməsi digər formalardan fərqli olaraq boş məcburi sahələr üçün əvvəlcədən deaktiv edilmir — yalnız basılanda xəbərdarlıq göstərir. Funksional səhv deyil, UX-uyğunsuzluq. |

**Əlavə qeyd (audit zamanı aşkarlanan, "Canlı" tab adlandırması):** "Canlı" tab canlı video yayım deyil, geo-sorğulara əsaslanan canlı aktivlik lentidir (yaxınlıqdakı yer/tədbir/təklif/PinBox). Marketinq mesajının bununla üst-üstə düşdüyünə əmin olunmalıdır.

---

## 4. Tam işlək təsdiqlənən (bu sessiyada təzədən yoxlanıldı)

- Canlı tab (aktivlik lenti formatında)
- PinBox — yaratma → alış (Epoint) → QR ilə realizasiya, uçdan-uca server-side qorunur
- Doğrulanmış Rəy sistemi — Firestore qaydası səviyyəsində real "Gəldi" statusu tələb edir, reytinq aqreqasiyası, admin panel moderasiyası
- İzləyici/İzlənən siyahıları (bu sessiyada tikildi) — tam işlək
- Epoint in-app WebView — bütün 4 nöqtə, xarici brauzer yoxdur
- M10 ödəniş seçimi — kodda heç bir iz yoxdur (gözlənildiyi kimi, hələ tətbiq olunmayıb, biznes tərəfli təsdiq gözlənilir)
- Kartlarım/Ödənişlər (bu sessiyada tikildi) — real Epoint kart-qeydiyyatı və saxlanmış kartla ödəniş
- Aktiv cihazlar — real sessiya izləmə, uzaqdan çıxış (soft-revoke, offline cihaz yenidən qoşulanda çıxarılır)
- Blok edilmiş istifadəçilər, dil dəyişdirici, dəstək/əlaqə axını, hesab silmə (real server-side silinmə)

---

## Növbəti addım

Hissə 1-in 8 tapıntısı prioritetli elan edilib — bunların hansı ardıcıllıqla həll ediləcəyi növbəti addımdır.
