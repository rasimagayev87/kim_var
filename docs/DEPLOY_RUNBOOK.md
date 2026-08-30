# PeakPin — Deploy və Miqrasiya Ardıcıllığı

Bu sənəd sıra ilə oxunmalı və sıra ilə icra edilməlidir. Addımların
ardıcıllığı təsadüfi deyil — yanlış sıra tətbiqi sındıra bilər.

> **Qeyd:** bu sənəd aşağıdakı 3 nöqtədə düzəldilib (kodla yoxlanıb, orijinal
> mətndən fərqlidir) — dəyişikliklər hər bölmənin özündə **[DÜZƏLİŞ]**
> işarəsi ilə qeyd olunub. Qalan hər şey orijinal mətnin özüdür,
> yoxlanılmayıb (Play Console/App Store addımları, real Storage fayl sayı
> və s. — bunlar yalnız icra zamanı təsdiqlənə bilər).

Tarix: ____________ İcra edən: ____________

---

## 0. ÖN ŞƏRTLƏR — deploy-dan əvvəl

### 0.1. App Check bayraqlarını söndür ⚠️ ƏN VACİB

Callable funksiyalarda `enforceAppCheck: true` deploy anında dərhal
canlıya keçir — Console-da aralıq mərhələ yoxdur. iOS App Check
qeydiyyatdan keçməyib (Apple Developer üzvlüyü gözləyir). Deploy edilsə,
iOS-da bütün bu funksiyalar kəsiləcək.

**[DÜZƏLİŞ] 13 yox, 14 funksiya.** Kodda birbaşa saydım
(`grep -c "enforceAppCheck: true" functions/src/index.ts`) — nəticə 14.
Əskik olan (13-ə daxil olmayan) `verifyInAppPurchase`-dir — Prompt 7-də
VIP IAP doğrulaması üçün əlavə olunub, "Qrup 1 (ödəniş)" konvensiyasına
görə haqlı olaraq bura düşür, amma sayıla bilər ki, orijinal siyahını
yazanda hələ nəzərə alınmayıb. Tam siyahı (sətir nömrələri bu anki
`functions/src/index.ts`-ə görə, deploy-dan əvvəl dəyişə bilər):

1. `retryVenueSubscriptionPayment`
2. `retryVenueCreationPayment`
3. `createBoostCheckout`
4. `createVenuePremiumCheckout`
5. `reservePinBoxOrder`
6. `generatePinBoxQrToken`
7. `redeemPinBoxOrder`
8. `retryOfferPayment`
9. `createEpointWidgetCheckout`
10. `startCardRegistration`
11. `payWithSavedCard`
12. `deleteSavedCard`
13. `setDefaultSavedCard`
14. **`verifyInAppPurchase`** ← bu, orijinal "13"-ə daxil olmaya bilər, yoxlayın

**Addım:** deploy-dan əvvəl bu 14 funksiyanın hamısında `enforceAppCheck`
→ `false`. Kod qalır, bayraq sönülü.

```
☐ 14 funksiyanın HAMISINDA enforceAppCheck: false edildi (yuxarıdakı siyahı ilə tutuşdurun)
☐ Hansı funksiyalar olduğu qeyd edildi (sonra geri açmaq üçün)
```

Geri açma şərti: iOS DeviceCheck qeydiyyatı tamamlanıb və Console-da hər
iki platformanın təsdiqlənmə faizi sabit yüksəkdirsə.

### 0.2. `config/businessOffer` sənədini yarat

Prompt 10-un D1 düzəlişi bu sənədi tələb edir. Yoxdursa, məkan yaratma və
abunə ödənişi sınacaq.

```
☐ npm --prefix admin-panel run set-business-offer-version -- <versiya> <url>
☐ Firestore-da config/businessOffer sənədinin mövcudluğu təsdiqləndi
```

### 0.3. Bütün testlər

```
☐ flutter analyze lib — 0 xəta
☐ flutter test — 63/63
☐ cd functions && npm run build — təmiz
☐ cd admin-panel && npx tsc --noEmit — təmiz
☐ npm --prefix tests/rules test — 124/124
```

Hər hansı biri uğursuzdursa DAYAN. Deploy etmə.

### 0.4. Yedək

```
☐ Firestore export (Console → Firestore → Import/Export) — miqrasiyadan əvvəl
☐ Mövcud firestore.rules-un nüsxəsi saxlanıldı (geri qaytarmaq üçün)
☐ Mövcud storage.rules-un nüsxəsi saxlanıldı
```

### 0.5. Git

```
☐ Bütün dəyişikliklər commit edildi
☐ Commit hash qeyd edildi: ____________  (geri qayıtmaq üçün)
```

---

## 1. FUNKSİYALAR — birinci

Niyə birinci: rules yeni funksiyaların mövcudluğunu tələb edir. Tərsinə
edilsə, tətbiq işləməz.

```
☐ firebase deploy --only functions
☐ Deploy uğurlu bitdi, xəta yoxdur
☐ Firebase Console → Functions — bütün funksiyalar "OK" statusunda
```

Yeni funksiyaların siyahısı (deploy-dan sonra mövcudluğunu təsdiqlə —
hər biri koddaımda `export const <ad>` kimi tapılıb təsdiqlənib):

* `completeOnboarding`
* `findNearbyUsers`, `previewVenueAudience`
* `onActiveCheckinCreated` / `onActiveCheckinDeleted`
* `onUserPrivateDataUpdated`
* `searchUsersByName`
* `onChatDeleted`, `forwardChatMedia`
* `updateOffer`, `updatePinBox`
* `reportOrphanAuthAccounts`
* `googlePlayRtdn` (Pub/Sub mövzusu əvvəlcədən yaradılmalıdır)

**[DÜZƏLİŞ] `initiateRefund` bu siyahıdan ÇIXARILDI.** Kodda yoxladım —
bu, Firebase Function DEYİL, `admin-panel/src/lib/actions/payments.ts`-də
bir Next.js Server Action-dır (Prompt 6-da qəsdən belə dizayn edilib —
admin-authenticated Cloud Function üçün bu kodda presedent yox idi).
`firebase deploy --only functions`-dan sonra Console-da onu axtarmayın —
tapılmayacaq, bu, XƏTA DEYİL. Bunun yerinə **4-cü bölmədə (ADMIN PANEL,
Vercel deploy-u)** yoxlanılmalıdır.

Xəta olarsa: deploy loguna bax, düzəlt, yenidən cəhd et. Rules-a keçmə.

---

## 2. MİQRASİYALAR — funksiyalardan sonra, rules-dan əvvəl

Niyə bu sıra: miqrasiya sənəd strukturunu dəyişir. Rules yeni strukturu
tələb edir. Tərsinə edilsə, miqrasiya özü rules-a ilişər.

### 2.1. Storage yol miqrasiyası (46 fayl)

```
☐ npm --prefix admin-panel run migrate-storage-owner-paths
☐ Nəticə: neçə fayl köçürüldü ____________
☐ Firestore-da URL-lərin yeniləndiyi təsdiqləndi (bir neçə sənəd əl ilə yoxlandı)
☐ Storage Console-da yeni yollarda faylların göründüyü təsdiqləndi
```

*(46 rəqəmi yoxlanılmadı — yalnız icra zamanı real Storage vəziyyətindən
təsdiqlənə bilər, mən production-a toxunmadım.)*

### 2.2. `users` PII miqrasiyası (5 sənəd)

```
☐ npm --prefix admin-panel run migrate-users-private-data
☐ Nəticə: neçə sənəd miqrasiya edildi ____________
☐ Firestore-da users/{uid}/private/data sənədlərinin yarandığı təsdiqləndi
☐ Əsas users/{uid} sənədindən Qrup S sahələrinin silindiyi təsdiqləndi
☐ Ölü sahələrin (friendCount, eventCount və s.) silindiyi təsdiqləndi
```

Miqrasiya uğursuz olarsa: skriptlər idempotentdir, təkrar işlədilə bilər.
Amma əvvəlcə səbəbi anla — yarımçıq miqrasiya rules deploy-undan sonra
tətbiqi sındırar.

---

## 3. RULES — sonuncu

Niyə sonuncu: rules yeni funksiyaları və yeni sənəd strukturunu tələb
edir. Hər ikisi hazır olmalıdır.

```
☐ firebase deploy --only firestore:rules,storage
☐ Deploy uğurlu bitdi
```

Bu andan etibarən:

* Internal Testing trekindəki köhnə build (versionCode 1) sınacaq —
  qeydiyyat, şəkil yükləmə, profil ekranı. Gözlənilən nəticədir.
* Yeni AAB hazır olana qədər testerlərə xəbər ver.

---

## 4. ADMIN PANEL

```
☐ admin-panel dəyişiklikləri deploy edildi (Vercel)
☐ Admin panelə giriş yoxlandı — işləyir
☐ İstifadəçilər səhifəsi açılır (phoneNumber yeni yoldan oxunur)
☐ Ödənişlər səhifəsi açılır (yeni statuslar görünür)
☐ [DÜZƏLİŞ, əlavə] "İadə başlat" (initiateRefund) düyməsi Ödənişlər səhifəsində işləyir
```

⚠️ Prompt 9 edilməyib — `emergencyToken` bypass hələ oradadır, MFA yoxdur.
Admin panelə internetdən çıxışı məhdudlaşdır (Vercel deployment
protection) və ya URL-i paylaşma.

---

## 5. DOĞRULAMA — deploy-dan sonra

### 5.1. Debug build ilə əsas axınlar

```
☐ Qeydiyyat (yeni hesab) — işləyir
☐ Yaş qapısı — 18-dən kiçik tarix seçilə bilmir
☐ Profil ekranı — məlumatlar görünür (private/data-dan oxunur)
☐ Kəşf et / xəritə — yaxınlıqdakılar görünür (findNearbyUsers)
☐ Axtarış — ad və username ilə işləyir
☐ Məkan yaratma — işləyir (config/businessOffer oxunur)
☐ Şəkil yükləmə — yeni yola gedir
☐ Çat — mesaj göndərmə işləyir
☐ Blok — bloklanan istifadəçinin profili "Hesab tapılmadı" göstərir
☐ VIP ekranı açılır, "Alışları bərpa et" düyməsi görünür
☐ [DÜZƏLİŞ, əlavə] Yeni email/parol qeydiyyatı "E-poçtunuzu təsdiqləyin" ekranına yönləndirir
```

### 5.2. Firebase Console

```
☐ Functions → Logs — xəta axını yoxdur
☐ Firestore → Usage — anomal oxunuş artımı yoxdur
☐ Crashlytics (əlavə olunubsa) — yeni crash yoxdur
```

---

## 6. AAB BUILD

**[DÜZƏLİŞ] versionCode/versionName `android/app/build.gradle.kts`-də
DEYİL, `pubspec.yaml`-ın `version:` sahəsində dəyişdirilir** —
`build.gradle.kts:48-49` bunları birbaşa `flutter.versionCode`/
`flutter.versionName`-dən oxuyur, onlar da Flutter-in öz Gradle plugin-i
vasitəsilə `pubspec.yaml`-dan gəlir. **İndiki dəyər: `1.0.0+10`**
(`versionCode=10`, `versionName=1.0.0`) — növbəti buraxılış üçün ən azı
`+11`-ə qaldırılmalıdır.

```
☐ pubspec.yaml — version sətri artırıldı (məs. 1.0.0+10 → 1.0.1+11): ____________
☐ flutter clean && flutter pub get
☐ flutter build appbundle --release
☐ Build uğurlu, AAB yolu: ____________
☐ AAB manifestində AD_ID icazəsinin OLMADIĞI təsdiqləndi
```

Manifest yoxlaması:

```
unzip -p <aab-yolu> base/manifest/AndroidManifest.xml | strings | grep -i AD_ID
```

Nəticə boş olmalıdır.

---

## 7. PLAY CONSOLE

```
☐ AAB Internal Testing trekinə yükləndi
☐ Testerlərdə yeni versiyanın gəldiyi təsdiqləndi
☐ Real cihazda əsas axınlar yenidən yoxlandı
```

Production-a keçməzdən əvvəl:

```
☐ Real ödəniş testi icra edildi (Prompt 6-nın təlimatı, 2 AZN boost)
☐ Data Safety bəyannaməsi yeniləndi (Analytics, Crashlytics, Branch)
☐ Managed publishing AÇIQ qalır
☐ [YENİ] Saxta seed məlumatı silindi (aşağı bax)
```

### 7.1. ⚠️ Saxta seed məlumatının silinməsi — production-dan ƏVVƏL MƏCBURİDİR

2-ci mərhələnin (Storage miqrasiyası) doğrulaması zamanı (2026-08-29/30)
aşkar edildi: `venues`/`offers`/`pinboxes`/`venueEvents` kolleksiyalarında
100+ sənəd **saxta seed məlumatıdır** — real istifadəçi fəaliyyəti deyil.
Təsdiq (3 əlamət birlikdə):

- Hamısının `createdAt`-ı 2026-08-29, saat 17:39:52–17:40:08 aralığında —
  16 saniyə ərzində toplu yaradılıb.
- Hamısı EYNİ tək `ownerId`-ə aiddir, fərqli "restoran" adları ilə (biri
  hətta insan adı daşıyır: "Elnur Musaoğlu").
- Offer/PinBox/Event-lərin şəkilləri ÖZLƏRİNİNKİ deyil — təsadüfi venue
  şəkillərinə istinad edir, kiçik bir hovuzdan təkrar istifadə olunub.

```
☐ Firestore Console-da ownerId=3cyKZtOCJjhfeWFWMNOA8OGCUaG3-ə aid BÜTÜN
  venues/offers/pinboxes sənədləri (+ onlara istinad edən venueEvents)
  tapıldı və siyahıya alındı
☐ Bu sənədlər real istifadəçi məzmunu OLMADIĞI TƏSDİQLƏNDİ (əl ilə,
  başqa uid-lərə aid HEÇ bir real sənədə toxunmadan)
☐ Silindi (Firestore + uyğun Storage faylları)
☐ Silmədən SONRA yenidən yoxlanıldı: Kəşf et/axtarış ekranlarında
  saxta məzmun artıq görünmür
```

Bu addım Storage miqrasiyasının (2-ci mərhələ) NƏTİCƏSİ kimi aşkar
edildi, amma İCRASI production-a keçmədən əvvələ (7-ci mərhələ) aiddir
— indi (miqrasiya zamanı) SİLİNMİR, sadəcə qeyd olunur.

---

## 8. GERİ QAYTARMA PLANI

Bir şey sınarsa:

**Rules problemi:** əvvəlki `firestore.rules` / `storage.rules` nüsxəsini
geri deploy et. Ən sürətli geri qaytarma budur.

**Funksiya problemi:** `firebase deploy --only functions:<funksiya-adı>`
ilə tək funksiyanı əvvəlki koddan deploy et, ya da git-dən əvvəlki
commit-i çıxarıb yenidən deploy et.

**Miqrasiya problemi:** Firestore export-dan bərpa. Bu, ən ağır haldır —
ona görə 0.4-dəki yedək atlanmamalıdır.

**Tam geri qaytarma:** commit hash ____________ -ə qayıt, funksiyaları və
rules-u yenidən deploy et. Miqrasiya geri qaytarılmır — export-dan bərpa
lazımdır.

---

## 9. DEPLOY SONRASI — açıq qalanlar

```
☐ App Check bayraqları hələ sönülüdür (0.1) — iOS hazır olanda açılacaq
☐ Prompt 9 (admin panel MFA, emergencyToken) edilməyib
☐ docs/ACCEPTED_RISKS.md və docs/BACKLOG.md GitHub Issues-a köçürülməli
☐ Apple Developer case 20000150926038 — cavab gözlənilir
☐ Google Play ödəniş profili və IAP məhsulları — vəziyyət: ____________
```
