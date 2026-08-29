# Geriyə Uyğunluq Siyasəti

Bu sənəd PeakPin-in v1.0.0 buraxılışından sonra tətbiq üçün rəsmi qaydadır: **köhnə (mağazadakı, yenilənməmiş) versiyalar heç vaxt sınmamalıdır**. İstifadəçi yeniləməsə də tətbiq tam işləməyə davam etməlidir; yeniləmə könüllü qalır, yalnız təhlükəsizlik boşluğu, maliyyə riski və ya tamamilə söndürülmüş backend API halında məcburi ola bilər (`force_update_enabled`, defolt söndürülüb).

Bu sənəd `lib/features/app_config/` (Remote Config infrastrukturu), `lib/core/utils/safe_parse.dart`, və bu sessiyada aparılan geriyə uyğunluq auditinin nəticəsidir. Kod dəyişikliklərinin siyahısı üçün handoff hesabatına bax.

---

## 1. Mərhələlərin müəyyən edilməsi

**FAZA 1 — "Sərbəst dövr"**
Meyar: launch-dan sonrakı ilk **60 gün** VƏ köhnə (cari olmayan) versiyada aktiv istifadəçi sayı **2000-dən azdır**.

Bu dövrdə:
- Sxem səhvi görülərsə birbaşa düzəldilə bilər (sahə adı dəyişmək, sahə silmək daxil)
- Lazım olsa `min_supported_version_android`/`min_supported_version_ios` qaldırılıb hamı yenilənməyə yönləndirilə bilər — bu dövrdə bunun qiyməti aşağıdır
- Dual-write proseduru məcburi deyil, amma tövsiyə olunur
- Şərt: dəyişiklikdən **əvvəl** `users/{uid}.appVersion` telemetriyasında təsirlənən versiyaların istifadəçi sayına baxılsın və qərar (kim, nə vaxt, niyə) bu sənədə və ya commit mesajına yazılsın

**FAZA 2 — "Ciddi rejim"**
Yuxarıdakı meyarlardan biri pozulan kimi (60 gün keçib **və ya** köhnə versiyada 2000-dən çox aktiv istifadəçi var) avtomatik olaraq bu rejimə keçilir. Bundan sonra aşağıdakı bölmələr (§2–§6) **məcburidir** və istisnasızdır.

**Bu keçid tarixi ilk buraxılış tarixindən manual hesablanmalıdır** — kod bunu avtomatik izləmir (bilərəkdən: bu, "60 gün keçdimi" sualının avtomatlaşdırılası bir kill-switch olmasını istəmədiyimiz üçündür, insan qərarı qalır).

---

## 2. Firestore sxemi

**Faza 2-də qadağan:**
- Mövcud sahəni silmək
- Mövcud sahənin adını dəyişmək
- Mövcud sahənin tipini dəyişmək
- Mövcud sahəni məcburi (required) etmək
- Mövcud enum dəyərinin mənasını dəyişmək

**Hər zaman icazəli:**
- Yeni optional sahə əlavə etmək
- Yeni enum dəyəri əlavə etmək (client `safeEnum`/`firstWhere(orElse:)` ilə dözümlüdürsə — bax §5)
- Yeni kolleksiya əlavə etmək

**Ad dəyişikliyi lazımdırsa — dual-write proseduru:**
1. Yeni sahə əlavə olunur; client **hər ikisinə yazır**, **yenidən oxuyur**, yoxdursa köhnəyə fallback edir
2. Cloud Function ilə mövcud sənədlər backfill edilir
3. Ən azı **2 release** buraxılır
4. **Köhnə sahə yalnız `users/{uid}.appVersion` telemetriyası onu oxuyan versiyaların aktiv istifadəsinin sıfıra düşdüyünü göstərəndə silinir.** Təqvim müddəti deyil, telemetriya qərar verir. Praktik minimum: 2 release; real qərar admin paneldəki (planlaşdırılan, hələ qurulmayıb) versiya bölgüsündən çıxır

---

## 3. Security Rules — ən çox sındıran nöqtə

- Yeni rule köhnə client-in göndərdiyi payload-u da qəbul etməlidir
- **Yeni sahəni məcburi tələb etmə**: `request.resource.data.newField != null` şərti köhnə versiyada olan bütün yazma əməliyyatlarını qırır. Əvəzinə: sahə varsa yoxla, yoxdursa icazə ver (`'field' in request.resource.data` ilə mövcudluq yoxlanılsın, Firestore Rules mövcud olmayan sahəyə birbaşa müraciətdə xəta atır — bu sessiyada `reviews` kolleksiyasının owner-reply qaydasında məhz bu səbəbdən real bug tapılıb düzəldilib: `resource.data.ownerReply == null` yerinə `!('ownerReply' in resource.data)`)
- `hasOnly([...])` siyahılarına yeni sahələr **əlavə** olunsun, köhnələr silinməsin
- Emulator üzərində rules unit test dəsti qurulsun. **Hər mağaza versiyasının payload forması üçün ayrıca test case saxlanılsın və heç vaxt silinməsin** — daimi regression suite
- Rules dəyişikliyi production-a çıxmazdan əvvəl emulator-da cari mağaza versiyasının payload-u ilə test edilsin

**⚠️ MƏCBURİ ÖN ŞƏRT — Faza 2-yə keçmədən əvvəl:** Bu layihədə hazırda **heç bir Firestore Rules emulator test dəsti yoxdur** (yalnız `flutter test` ilə Dart-tərəfli unit testlər var). Faza 2-yə keçdikdən sonra göndəriləcək **BİRİNCİ** `firestore.rules` dəyişikliyindən əvvəl bu test dəsti qurulmalıdır (`firebase emulators:exec` + `@firebase/rules-unit-testing`). Bu, təqvim müddəti kimi təxirə salına bilməyən, işə başlamazdan əvvəl həll olunmalı bir bloklayıcı şərtdir — "sonra edərik" burada məqbul deyil, çünki elə bu bölmənin özü izah edir ki, rules dəyişiklikləri köhrənə client-ləri ən çox sındıran nöqtədir.

---

## 4. Cloud Functions

- Input sxemi **genişlənə bilər, daralmaz**: yeni optional parametr olar; mövcud parametri məcburi etmək və ya silmək olmaz
- **Response-dan sahə silinməz, adı dəyişilməz** — yalnız yeni sahə əlavə oluna bilər
- Breaking dəyişiklik qaçılmazdırsa: **yeni funksiya adı** (`createBoostPaymentV2`), köhnəsi işləməyə davam edir və yalnız istifadəsi sıfıra düşəndə silinir
- Köhnə formatda input gələndə funksiya xəta qaytarmasın, məntiqli default-larla işləsin
- Ödəniş webhook-ları **idempotent** olsun (eyni bildiriş iki dəfə gələndə ikinci dəfə heç nə dəyişməsin) — köhnə client-lərin təkrar sorğuları üçün vacibdir
- Client hər callable çağırışında `appVersion`/`platform` göndərir (bax `lib/features/auth/data/repositories/firebase_auth_repository.dart`-dakı telemetriya nümunəsi) — funksiya bunu loglaya bilər, amma heç vaxt bunlara əsasən rədd etməsin

---

## 5. Graceful degradation (client tərəfi)

- Yeni funksiyanın məlumatı köhnə client tərəfindən oxunmasın və göstərilməsin
- Siyahılarda naməlum tip elementlər (yeni kateqoriya, yeni post tipi) **filtrlənsin**, siyahı boş qalmasın — bax `lib/core/utils/safe_parse.dart`-ın `safeEnum`/`safeList` funksiyaları, artıq `Venue`/`Offer`/`Review`/`PinBox`/`PinBoxOrder`/`VenueEvent` repository-lərinin bütün `.docs.map(...)` və tək-sənəd oxuma nöqtələrində tətbiq olunub (`_safeVenue`/`_safeOffer`/`_safeReview`/`_safePinBox`/`_safePinBoxOrder`/`_safeEvent` adlı private helper-lər) — bir korlanmış sənəd bütün siyahını/axını boşaltmır, yalnız özü atılır və loglanır
- Yeni funksiyanın olmaması istifadəçiyə xəta kimi göstərilməsin — həmin element sadəcə mövcud olmasın
- Naməlum deep link/route → ana ekrana yönləndirmə (`lib/core/navigation/deep_link_handler.dart`)
- Naməlum bildiriş `type`/`targetType` → sükutla nəzərə alınır (artıq belə idi, bu sessiyada təsdiqləndi, dəyişiklik lazım olmadı)

---

## 6. Release prosesi

- **Staged rollout məcburidir**: Play-də 1% → 10% → 50% → 100%; App Store-da phased release aktiv
- Hər release-dən əvvəl **"köhnə build + yeni backend" smoke testi**: mağazadakı cari versiyanın buildi ilə yeni backend-ə qarşı əsas axınlar yoxlanılsın — giriş, xəritə/radius, məkan açma, kampaniya baxışı, çat, bildiriş, ödəniş ekranı
- **Rules və Cloud Functions dəyişiklikləri tətbiq release-indən ƏVVƏL və geriyə uyğun şəkildə** çıxsın
- Launch-dan sonrakı ilk aylarda **2-3 həftədən bir kiçik release** — köhnə versiyalar toplanmağa macal tapmasın
- Rollout zamanı Crashlytics crash-free rate izlənilsin; düşmə olarsa rollout dayandırılsın

---

## 7. Remote Config — necə işləyir

`lib/features/app_config/` — bax bu modulun öz kod şərhlərinə tam detal üçün. Qısaca:

- **Splash ekranı** heç vaxt şəbəkə sorğusuna görə bloklanmır — keşdən (əvvəlki fetch-dən qalan, və ya heç fetch olmayıbsa bundle edilmiş default-lardan) dərhal oxuyur. Yalnız tətbiqin **ilk dəfə açılışında** (heç bir keş yoxdursa) 3 saniyəyədək gözlənilir, sonra default-lara keçilir.
- `AppLifecycleState.resumed`-da arxa fonda yenidən fetch edilir (bax `AppConfigLifecycleObserver`).
- Fetch uğursuz olarsa (`RemoteConfigDataSource.init`/`refresh`) heç vaxt xəta atmır — loglanır, tətbiq default/keş dəyərlərlə davam edir.

### Feature flag giriş nöqtələri

| Flag | Giriş nöqtəsi |
|---|---|
| `venueSubmission` | `discover_tab.dart` — məkan əlavə et düyməsi |
| `offers` | `discover_tab.dart` — təklif əlavə et düyməsi |
| `calls` | `chat_conversation_screen.dart` — səs/video zəng düymələri |
| `stories` | `profile_tab.dart` — hekayə "+" nişanı |
| `vipPurchase` | `premium_upsell_sheet.dart`, `settings_screen.dart` — VIP ekranına giriş |
| `boostPayment` | `offer_details_screen.dart` — "önə çək" menyusu |
| `waitlist` | `waitlist_status_section.dart` — sıraya yazıl düyməsi |
| `mediaUpload` | `profile_tab.dart` — post paylaş "+" düyməsi |
| `indiTab` | Ayrıca "İndi" tab-ı yoxdur — Canlı tab-ın "İndi boş yer var" bölməsinə tətbiq olunur |
| `newsAgency` | Hələ ayrıca funksiya yoxdur (yalnız `VenueCategory.independentArtist`) — flag mövcuddur, gələcək üçün |

### `read_only_mode_enabled`

`lib/features/app_config/presentation/utils/read_only_guard.dart`-dakı `ensureWritableOrWarn(AppConfig)` funksiyası. Tətbiq olunub: `PostController` (bütün yazma metodları), `ReviewController.submit`/`submitOwnerReply`, `MapLocationSettingsController._run`, `ChatController.sendText`. **Tam siyahı deyil** — hər yeni mutasiya edən controller metoduna eyni bir sətir (`if (!ensureWritableOrWarn(...)) return false;`) əlavə etmək kifayətdir.

### Uzaqdan sabitlər

`AppConfig.urlPrivacyPolicy`/`urlTermsOfService`/`urlCommunityGuidelines`/`supportEmail`/`privacyEmail`/`radiusOptionsKm`/`nearbyRefreshSeconds` — köhnə hardcoded dəyərlərin yerini tutur, default olaraq eyni qiymətlərlə bundle olunub. `nearbyRefreshSeconds` (defolt 45) Düzəliş Prompt 4-də əlavə olundu — `findNearbyUsers` callable-inin nə qədər tez-tez sorğulandığını idarə edir. `lib/features/legal/legal_texts.dart`-dakı statik hüquqi mətnlər (istifadə olunmayan, "ölü kod") bilərəkdən toxunulmayıb — bunlar hər hansı ekranda göstərilmir, əvəzinə xarici `peakpin.app/privacy-policy.html` istifadə olunur.

---

## 8. Minimum OS versiyası

- **Android**: `minSdk = 24`, `targetSdk = 36`, `compileSdk = 36` — `android/app/build.gradle.kts`-də indi hərfi olaraq sabitlənib (əvvəllər quraşdırılmış Flutter SDK-nın öz `flutter.minSdkVersion` və s. dəyərlərindən asılı idi, bu, `flutter upgrade` zamanı sükutla dəyişə bilərdi).
- **iOS**: `platform :ios, '14.0'` — `ios/Podfile`-da onsuz da sabit idi.

Bu dəyərləri qaldırmaq (məsələn minSdk 24 → 26) köhnə cihazları tamamilə kəsir — Faza 1-də ucuz, Faza 2-də bahalı qərardır (bax §1).

---

## 9. Görülməmiş/qismən qalan işlər (dürüst siyahı)

- **Firestore Rules emulator test dəsti** — yoxdur, §3-də izah edildiyi kimi Faza 2-dən əvvəl MƏCBURİDİR.
- **Admin paneldə versiya bölgüsü görünüşü** — ayrıca (Next.js) kodbaza, bu sessiyada araşdırılmayıb, ayrıca planlaşdırılacaq.
- **`schemaVersion` sahəsi** — planlaşdırılmışdı, amma icra edilmədi: bu sahəni `Review`-un client-side yazma yoluna əlavə etmək eyni zamanda `firestore.rules`-un `reviews` `hasOnly([...])` siyahısını da yeniləməyi tələb edirdi (əks halda rəy göndərmə bütünlüklə qıraraq), və bu, canlı mühitdə tam test olunmadan risqli sayıldı. Venue/Offer/PinBox/VenueEvent üçün isə yazma serverdə (`functions/src/index.ts`-in `submitVenue`/`submitOffer`/`createPinBox`/`createEvent` funksiyaları) baş verir. Hər ikisi konkret, aydın əlavə edilə bilən follow-up-dır.
- **Firebase Analytics event-ləri** (qeydiyyat, məkan açma, kampaniya baxışı, ödəniş) — SDK əlavə olunub (`firebase_analytics` pubspec-də), amma konkret event çağırışları hələ mövcud action nöqtələrinə əlavə edilməyib.
- **Play Data Safety / App Store privacy label / Privacy Policy mətni** — Crashlytics və Analytics SDK-ları bu sessiyada əlavə olundu. Bundan əvvəlki bir sessiyada Play Console-un Data Safety formu "heç bir crash/analitika SDK-sı yoxdur" bəyan edilərək göndərilmişdi — bu bəyanat artıq düzgün deyil. **Bu, publish-dən əvvəl həll edilməli məcburi addımdır**: Play Console → Data Safety → "App performance data" (Crash logs, Diagnostics) və "App activity" (Analytics) bölmələri "App functionality" məqsədi ilə işarələnməli; Apple App Store Connect-in privacy "nutrition label"-ına eyni Analytics/Diagnostics kateqoriyaları əlavə edilməli; `peakpin.app/privacy-policy.html` (bu kodbazadan kənar, Vercel-də host olunan marketinq saytı) mətninə Firebase vasitəsilə crash/analitika məlumatı toplandığını bildirən bir sətir əlavə olunmalıdır.
- **IAP məhsul ID-lərinin (`peakpin_vip_monthly/quarterly/yearly`) Play Console/App Store Connect-də faktiki yaradılması** — kodda hazırdır, mağaza tərəfində təsdiqlənməyib (kodbazadan kənar addım).
