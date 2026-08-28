# PeakPin — Buraxılış Hazırlığı Checklist

Son yenilənmə: 2026-08-26. İlk versiya 2026-08-26-da yaradılıb, bütün maddələr birbaşa kod/canlı sistem yoxlaması ilə doğrulanıb (sadəcə bəyanat kimi qəbul edilməyib). Bu yenilənmədə: Hissə 3-dəki 8 tapıntının **hamısı həll edildi** (kod yazıldı, `flutter analyze`/`npm run build` təmiz keçdi, commit+push+deploy edildi) — detallar üçün Hissə 3-ə bax.

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
| Cloud Functions runtime (Node.js 20) | 🟡 Diqqət tələb edir | `firebase deploy` zamanı rəsmi xəbərdarlıq: Node.js 20 dəstəyi 2026-04-30-da deprecated elan olunub, 2026-10-30-da tamamilə decommission ediləcək (bundan sonra bu runtime-la deploy mümkün olmayacaq). Buraxılışdan sonra Node 22-yə keçid planlaşdırılmalıdır — hazırda funksional problem yaratmır. |

---

## 3. Bu sessiyanın tam funksionallıq auditindən (2026-08-26) tapılan maddələr — HAMISI HƏLL EDİLDİ ✅

Hamısı istifadəçi tərəfindən prioritetli elan edilmişdi. 2026-08-26 tarixində hamısı üzərində iş görülüb, kod dəyişiklikləri commit+push edilib (server tərəfli hissə üçün Cloud Function də deploy edilib).

| # | Ekran/Komponent | Problem | Həll |
|---|---|---|---|
| 1 | `lib/core/widgets/premium_upsell_sheet.dart` | "Upgrade" düyməsi real VIP alış axınına deyil, `ComingSoonScreen`-ə aparırdı. | ✅ Düymə indi real `VipScreen`-i açır. |
| 2 | `change_email_sheet.dart` + `firebase_account_repository.dart` | E-poçt dəyişəndə yalnız Firestore sənədi yenilənirdi, Firebase Auth hesabının özü yenilənmirdi. | ✅ `verifyBeforeUpdateEmail()` ilə real Auth axını: yeni ünvana təsdiq linki göndərilir, yalnız link klik edildikdən sonra dəyişiklik qüvvəyə minir. Sessiya köhnədirsə (5 dəq-dən çox), paylaşılan `ReauthSheet` widget-i ilə yenidən doğrulama tələb olunur (Apple/Google/e-poçt link). Növbəti tətbiq açılışında Firestore avtomatik sinxronlaşır (`syncEmailFromAuth`). |
| 3 | `update_visibility_radius_usecase.dart` | "Görünmə radiusu" sazlaması heç bir sorğuda oxunmur/tətbiq edilmirdi. | ✅ Client tərəfdə (`nearbyUsersProvider`, `radiusUserCountsProvider`, `venueAudienceCountProvider`) və server tərəfdə (`getDiscoverCandidates` Cloud Function) real tətbiq edilir. Deploy edildi. |
| 4 | `update_two_factor_enabled_usecase.dart` | Bayraq dəyişdirilirdi, amma real ikinci amil heç vaxt tələb olunmurdu. | ✅ İstifadəçi qərarı: real MFA hazır olana qədər UI-dan gizlədildi (Ayarlar → Məxfilik siyahısından sətir silindi). Aldadıcı deyildi, sadəcə hazır deyildi — indi ümumiyyətlə görünmür. |
| 5 | `export_data_screen.dart` | Yalnız `users/{uid}` sənədi göstərilirdi. | ✅ İstifadəçinin öz sahibi olduğu bütün məlumatlar əlavə edildi: paylaşımlar, rəylər, ödəniş tarixçəsi, saxlanmış kartlar (yalnız maskalanmış sahələr), izlədikləri/izləyiciləri, bildirişlər. Mesaj yazışmaları qəsdən xaricdə qalır (başqa istifadəçilərin məlumatını əhatə etdiyi üçün, ayrıca server-side pipeline tələb edir). |
| 6 | `my_offers_screen.dart` | Xam exception mətni göstərilirdi. | ✅ `FriendlyErrorState` (dost mesaj + "Yenidən cəhd et" düyməsi) ilə əvəz edildi. |
| 7 | `notifications_screen.dart` | E-poçt bildirişləri toggle-ı deaktiv "Coming soon" vəziyyətində görünürdü. | ✅ İstifadəçi qərarı: real hazır olana qədər sətir tamamilə gizlədildi (2FA ilə eyni qərar). |
| 8 | `edit_profile_screen.dart` | "Yadda saxla" düyməsi boş məcburi sahələr üçün əvvəlcədən deaktiv edilmirdi. | ✅ Digər formalarla eyni nümunə: bütün məcburi sahələr (ad, soyad, doğum tarixi, username statusu) doğru olana qədər düymə deaktiv qalır. |

**Əlavə qeyd (audit zamanı aşkarlanan, "Canlı" tab adlandırması):** "Canlı" tab canlı video yayım deyil, geo-sorğulara əsaslanan canlı aktivlik lentidir (yaxınlıqdakı yer/tədbir/təklif/PinBox). Marketinq mesajının bununla üst-üstə düşdüyünə əmin olunmalıdır. *(Hələ açıq — bu, kod dəyişikliyi deyil, marketinq/mətn qərarı tələb edir.)*

**Bu batch-dən kənar, əlavə tapılıb düzəldilən UI qüsuru:** Ekranlar arası keçid (push/pop) zamanı ~300ms ərzində köhnə ekranın məzmunu yeni ekranın altından "sızırdı" (şəffaf `Scaffold` fonu + tətbiq-geneli Cupertino slide keçidinin birləşməsi səbəbindən). ~48 ekranda fon şəffaflıqdan `AppColors.background`-a keçirildi, vizual fərq yoxdur, keçid artıq təmizdir. Commit edildi.

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

Hissə 3-ün 8 tapıntısı həll edildi. Buraxılış üçün real bloklayıcı qalan yeganə maddələr:

1. **iOS App Store skrinşotları** (Hissə 2) — `screenshots/ios/` qovluğu yoxdur, təqdimat üçün mütləq lazımdır.
2. **Firebase App Check enforcement** (Hissə 2) — server tərəfdə hələ "UNENFORCED", aktivləşdirmədən əvvəl real cihazda test tələb olunur.
3. **Apple Developer Organization (DUNS)** (Hissə 2) — xarici proses, davam edir.

Bunlardan başqa, item 2/3/5 (e-poçt sinxronizasiyası, görünmə radiusu, məlumat ixracı) kod səviyyəsində doğrulanıb, amma real signed-in sessiya ilə uçdan-uca sınaqdan keçirilməyib — buraxılışdan əvvəl real cihazda bir dəfə yoxlanılması tövsiyə olunur.
