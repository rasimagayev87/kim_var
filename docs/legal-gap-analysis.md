# Hüquqi sənədlərin boşluq registri

**Tarix:** 2026-09-01 · **Hazırladı:** kod auditi (Claude)
**Status:** hüquqi baxış gözləyir

## Bu sənəd nədir və nə deyil

Bu, **hüquqi mətn deyil.** Kodun faktiki olaraq nə etdiyini sənədlərin
nə dediyi ilə tutuşduran registrdir. Hər bənd üçün: hansı sənəd, hansı
bölmə, hansı kod (fayl:sətir), nəyin çatışmadığı.

Bölmə 6-dakı **layihə mətnləri yalnız faktı təsvir edir** — nə toplanır,
nə qədər saxlanılır, kimə verilir. Hüquqi əsas, öhdəlik dili və hüquqi
iddia formalaşdırması **qəsdən boş buraxılıb** — onu hüquqşünas yazmalıdır.

## Sənədlərin yeri

| Sənəd | Fayl | Versiya |
|---|---|---|
| Məxfilik siyasəti | `peakpin-landing/public/privacy-policy.html` | 1.1 (18.08.2026) |
| İstifadə şərtləri | `peakpin-landing/public/terms-of-service.html` | 1.0 (12.08.2026) |
| Publik oferta | `peakpin-landing/public/business-offer.html` | 1.0 (28.08.2026) |

Tətbiq linkləri Remote Config-dən oxuyur
(`remote_config_data_source.dart:51-58`) — **sənəd dəyişikliyi tətbiq
release-i tələb etmir.**

---

# 1. ⚠️ FAKTİKİ SƏHV — bu boşluq deyil, yanlış məlumatdır

## 1.1. Ödəniş provayderi yanlış göstərilib

**Sənəd:** Məxfilik siyasəti §2.5
**Mövcud mətn:**

> «VIP abunəlik alarkən, kart məlumatlarınız bizim tərəfimizdən deyil,
> **Apple/Google-un rəsmi ödəniş sistemləri** tərəfindən işlənir.»

**Reallıq:** Bu, yalnız VIP abunəliyi üçün doğrudur (IAP). **Məkan
abunəlikləri, kampaniya yerləşdirmə haqları, boost və PinBox ödənişləri
Epoint üzərindən gedir** — Azərbaycanda yerləşən üçüncü tərəf ödəniş
provayderi.

**Kod:** `functions/src/index.ts` — `startEpointCheckoutForPayment`,
`epointWebhook`; `lib/core/payments/epoint_card_checkout_screen.dart`

**Niyə ciddidir:** §4 (paylaşma) üçüncü tərəfləri sadalayır — «Google
Firebase, Google Maps, Apple/Google ödəniş sistemləri». **Epoint bu
siyahıda yoxdur.** Yəni sənəd həm ödənişin necə işləndiyini yanlış
təsvir edir, həm real bir alıcının adını çəkmir. Bu, çatışmayan bənd
deyil — mövcud bəndin səhv olmasıdır.

**Nə edilməli:** §2.5 və §4 hər ikisi düzəldilməlidir. §2.5 iki ödəniş
yolunu ayırmalıdır (IAP vs kart), §4 Epoint-i adı ilə əlavə etməlidir.

## 1.2. Təsisçi promosunun kampaniya hissəsi artıq mövcud deyil

**Sənəd:** Publik oferta §6 «TƏSİSÇİ (STARTAP) PROMOSU»
**Reallıq:** «İlk 1000 məkana 30 gün ərzində 5 pulsuz kampaniya»
güzəşti **ləğv edildi** (2026-09-01). Yerinə abunə tarifinə bağlı
dövrlük kvota gəldi. «1 ay ödə, 1 ay hədiyyə al» hissəsi **qalır**.

**Kod:** `assignFoundingVenueIfEligible` — `freeOffersUsed`/
`freeOfferWindowEnd` artıq nə yazılır, nə oxunur.

---

# 2. MƏXFİLİK SİYASƏTİ — çatışmayan bəndlər

Hamısı **§2 (Topladığımız məlumatlar)** altına.

| # | Mövzu | Kod | Nə yazılmalıdır |
|---|---|---|---|
| 2.1 | **Məlumatın iki yerə bölünməsi** | `private_data_ref.dart`, `privateDataRef` | Həssas sahələr (`birthDate`, `lat`/`lng`, `phoneNumber`, `email`, `gender`, `fcmTokens`, `blockedUsers`, `ghostModeEnabled`, bildiriş seçimləri) ayrıca, başqa istifadəçinin oxuya bilmədiyi sənəddə saxlanılır. Profil sənədində yalnız publik sahələr qalır |
| 2.2 | **Koordinat və görünmə radiusu** | `buildPublicCandidatePayload`, `roundToGrid` | Koordinat toplanır; **başqa istifadəçiyə göndərilməzdən əvvəl şəbəkəyə yuvarlaqlaşdırılır**, dəqiq nöqtə heç vaxt paylaşılmır. İstifadəçi öz görünmə radiusunu seçir |
| 2.3 | **Ghost Mode** | `ghostModeEnabled` | Açıq olduqda istifadəçi yaxınlıq siyahılarında, iştirak sayğaclarında və ad günü eşleşmələrində **ümumiyyətlə iştirak etmir** |
| 2.4 | **Cihaz imzası** | `knownDeviceSignatures` | `sha256(userAgent)` — yeni cihazdan girişi aşkarlamaq və təhlükəsizlik bildirişi göndərmək üçün. Cihaz identifikatoru deyil, hash-dir |
| 2.5 | **Check-in** | `activeCheckins` | Könüllüdür — istifadəçi özü məkana check-in edir. Kimə göründüyü və nə vaxt silindiyi yazılmalıdır |
| 2.6 | **Aqreqat iştirak məlumatı** | `computeAudienceCount`, `VENUE_AUDIENCE_MIN_REPORTABLE_COUNT = 5` (`geo.ts:24`) | Məkan sahibi «ətrafda N istifadəçi» görür. **Kimlik heç vaxt verilmir.** Say **5-dən azdırsa 0 göstərilir** (k-anonimlik həddi) — yəni az adam olanda konkret şəxs müəyyən edilə bilməz |
| 2.7 | **Ad günü hədəflənməsi** | `computeBirthdayMatches`, `publishBirthdayCampaigns` | **Yalnız istifadəçi özü açıq razılıq versə** (`birthdayOffersOptIn`, defolt bağlı). Doğum tarixi **məkanla heç vaxt paylaşılmır** — məkan yalnız «yaxınlığınızda N nəfərin ad günüdür» sayını görür. Söndürüldükdə bildiriş getmir |
| 2.8 | **Bildiriş seçimləri** | `notification-categories.ts` | Səkkiz kateqoriya söndürülə bilir. **İki kateqoriya söndürülə bilmir** və səbəbi yazılmalıdır: `security` (hesabın ələ keçirilməsini üzə çıxaran mesaj) və `account` (pul, kimlik, abunəlik, növbə) |
| 2.9 | **Profil baxışları** | `users/{uid}/profileViews` | Profilə kimin baxdığı qeyd olunur və profil sahibinə göstərilir |
| 2.10 | **Analitika və qəza hesabatı** | `pubspec.yaml:55-56`, `main.dart:36` | Firebase Analytics və Crashlytics istifadə olunur. Nə toplandığı (istifadə hadisələri, qəza izləri, cihaz/OS versiyası) yazılmalıdır — hazırda §2.6 yalnız «cihaz növü, OS, tətbiq versiyası, IP» deyir, analitika xidmətlərinin adı çəkilmir |

---

# 3. MƏXFİLİK SİYASƏTİ §5 — saxlama müddətləri

**Mövcud §5 cəmi iki cümlədir** və heç bir məlumat növü üçün müddət
vermir. Ən böyük boşluq budur. Halbuki §11 (KYC) düzgün yazılıb —
onu model kimi götürmək olar.

| Məlumat | Faktiki müddət | Kod |
|---|---|---|
| Story (sənəd + baxışlar + media) | **24 saat**, sonra tam silinir | `cleanupExpiredStories` (saatlıq), `onStoryDeleted` |
| Story media (ehtiyat qat) | 25 gün — GCS Lifecycle | `docs/CONSOLE_MANUAL_STEPS.md` |
| KYC şəkilləri | **90 gün** ✅ artıq yazılıb | §11 |
| İştirak tarixçəsi (`audienceHistory`) | **7 gün** | `AUDIENCE_HISTORY_RETENTION_MS` (index.ts:2826) |
| Bildiriş niyyətləri (`notificationIntents`) | **3 gün** — Firestore TTL | `INTENT_RETENTION_DAYS` |
| Ad günü eşleşmələri (`birthdayMatches`) | **3 gün** — TTL | `BIRTHDAY_MATCH_RETENTION_DAYS` |
| Ad günü siyahısı (`birthdayFeed`) | **3 gün** — TTL | eyni sabit |
| Ödəniş qeydləri | **saxlanılır** — maliyyə audit izi | aşağıda |

## 3.1. Hesab silindikdə — nə silinir, nə anonimləşdirilir

Mövcud mətn: «hesabınızı və **bütün əlaqəli məlumatlarınızı** silə
bilərsiniz». **Bu, tam dəqiq deyil** və dəqiqləşdirilməlidir.

Faktiki davranış (`functions/src/index.ts:456-463`):

| Məlumat | Nə olur | Niyə |
|---|---|---|
| Profil, media, mesajlar, story-lər | silinir | — |
| PinBox sifarişləri | **anonimləşdirilir** (`buyerDeleted: true`) | Satıcının satış qeydi və hesabatı pozulmamalıdır |
| PinBox elanları | **anonimləşdirilir** (`ownerDeleted: true`) | Alıcıların mövcud sifarişləri qüvvədə qalır |
| Tədbirlər | **anonimləşdirilir + ləğv edilir** | Digər iştirakçıların tarixçəsi |
| Ödəniş qeydləri | **saxlanılır** | Maliyyə audit izi |

Bu, gizlədiləcək şey deyil — normal və izah edilə bilən davranışdır,
sadəcə sənəddə yazılmalıdır.

---

# 4. PUBLİK OFERTA — çatışmayan bəndlər

| # | Bölmə | Nə yazılmalıdır |
|---|---|---|
| 4.1 | §4 Qiymətlər | **Abunə tarifinə daxil olan pulsuz kampaniya kvotası:** 15 AZN → 3, 20 AZN → 5, 25 AZN → 8, 30 AZN → 10 (dövr başına). Kvota bitəndə mövcud yerləşdirmə haqqı tətbiq olunur (2/4/5/7 AZN) |
| 4.2 | §4 | **Tədbir kvotası:** dövr başına 5, bütün tariflərdə eyni. Kvota bitəndə **ödəniş yolu yoxdur** — yeni tədbir növbəti dövrədək yaradıla bilmir |
| 4.3 | §4 | **Dövr:** təqvim ayı deyil, abunənin öz 30 günlük dövrü |
| 4.4 | §5 PinBox | **Limitsizdir**, ayrıca yerləşdirmə haqqı yoxdur — gəlir satışdan komissiya ilə |
| 4.5 | §6 | Təsisçi promosunun **kampaniya hissəsi ləğv edilib** (bax 1.2) |
| 4.6 | §7 Moderasiya | **Kampaniya:** hər biri ön-moderasiyadan keçir. **Tədbir:** məkanın ilk 3 tədbiri baxışdan keçir, sonrakılar dərhal yayımlanır. **Tədbir öz başlama vaxtınadək təsdiqlənməsə avtomatik rədd edilir** və sahibə bildiriş gedir |
| 4.7 | Yeni bənd | **Ödənişin gecikməsi (`subscription_overdue`):** güzəşt müddətindən sonra məkan dayandırılır — elanları kəşfiyyatda görünmür, yeni kampaniya/tədbir/PinBox yaradıla bilmir, **pulsuz kvota donur (sıfırlanmır)**. Ödəniş edildikdə məkan bərpa olunur və yeni dövrün kvotası açılır |
| 4.8 | §9 | Məkan silindikdə PinBox və tədbirlərin anonimləşdirilməsi (bax 3.1) |
| 4.9 | §8 Geri qaytarma | Epoint-in rolu və geri qaytarma axını |

---

# 5. VERSİYA PLANI — ADDIM SIRASI POZULMAMALIDIR

## 5.1. Yenidən razılıq tələb olunurmu?

**Bəli — məxfilik siyasəti üçün, və bu, mübahisəli deyil.**

Bölmə 2-dəki bəndlər dəqiqləşdirmə deyil: mövcud mətnin **ümumiyyətlə
xatırlamadığı** emal kateqoriyalarıdır — cihaz imzası (yeni
identifikator), check-in/iştirak məlumatı, doğum tarixi ilə kommersiya
hədəflənməsi, aqreqat iştirakın biznes funksiyası kimi verilməsi.
Üstəlik **yeni üçüncü tərəf alıcı** (Epoint) sənəddə heç adı çəkilmir.

| Sənəd | Cari | Təklif | Səbəb |
|---|---|---|---|
| Məxfilik | 1.1 | **2.0** | Yeni emal məqsədləri + yeni alıcı |
| Şərtlər | 1.0 | **1.1** | §7 (moderasiya/geri qaytarma) maddi dəyişir |
| Oferta | 1.0 | **2.0** | Qiymət strukturu və kvotalar dəyişir |

## 5.2. ⚠️ TƏLƏ — sıra pozulsa yeni istifadəçilər zərər görür

`lib/features/auth/data/repositories/firebase_auth_repository.dart:338`
qeydiyyat anında **hardcoded** `kCurrentPrivacyVersion`-u yazır
(`legal_versions.dart`). Yenidən-razılıq dialoqu isə `config/legal`-ı
Firestore-dan oxuyur (`consent_dialog.dart:34`).

**Əgər Firestore versiyası klientdən əvvəl artırılsa:** yeni
qeydiyyatdan keçən istifadəçi razılıq qutusunu **yenicə işarələdikdən
dərhal sonra** yenidən-razılıq dialoqunu görəcək. Mövcud istifadəçilər
üçün problem yoxdur — onlar üçün dialoq onsuz da nəzərdə tutulub.

## 5.3. Düzgün ardıcıllıq

Versiya nömrələri **2026-09-01 tarixində təsdiqləndi** və artıq
`legal_versions.dart`-dadır. Mətnlərin özü sonra yazılır — bu, qəsdəndir
və aşağıdakı sıranı pozmur, çünki **Firestore artımı ən sonda gəlir.**

```
1. ✅ legal_versions.dart → 1.1 / 2.0     (EDİLDİ — AAB bunu daşımalıdır)
2. ✅ AAB 1.0.1+14 qurulur
3. ⏳ Hüquqi mətnlər yazılır və baxışdan keçir
4. ⏳ HTML başlıqlarında "Versiya: X.Y · Son yenilənmə" yenilənir
5. ⏳ peakpin-landing deploy edilir       ← mətnlər CANLI olmalıdır
6. ⏳ AAB mağazada yayılır
7. ⏸  5 VƏ 6 — HƏR İKİSİ tamamlanana qədər gözlə
8. ⏳ config/legal → currentPrivacyVersion "2.0", currentTermsVersion "1.1"
9. ⏳ config/businessOffer → currentVersion "2.0"
```

### Niyə 1-ci addım 3-dən əvvəl gələ bilər

`legal_versions.dart` yalnız **qeydiyyat anında** yazılan möhürdür.
Dialoqu tetikləyən şey Firestore-dur. Klient nömrəni Firestore-dan
irəli daşıdıqda heç nə baş vermir — yeni hesab sadəcə Firestore-un
hələ çatmadığı versiya ilə möhürlənir və dialoq işə düşmür.

Əks istiqamət isə sınıqdır və 5.2-də təsvir olunub.

### Niyə 8-ci addım İKİ şərtdən asılıdır

**Şərt A — AAB mağazada yayılmalıdır.** Əks halda köhnə build hələ də
`1.0`/`1.1` möhürləyir, Firestore isə `1.1`/`2.0` gözləyir: hər yeni
qeydiyyatdan keçən istifadəçi razılıq qutusunu işarələdikdən **dərhal
sonra** yenidən-razılıq dialoqunu görür.

**Şərt B — mətnlər canlı olmalıdır.** Dialoq istifadəçini sənədi
oxumağa göndərir. Versiya artırılıb mətn hələ köhnədirsə, istifadəçidən
**oxumadığı bir sənədə razılıq** istənilmiş olur — bu, dialoqun heç
göstərilməməsindən pisdir, çünki formal razılıq yığılır, məzmun isə
yanlışdır.

İkisindən biri hazır deyilsə, 8-ci addım gözləyir.

**Oferta (addım 8) ayrıdır** — məkan sahibləri üçündür və `acceptOffer`
axını ilə idarə olunur, istifadəçi razılıq dialoqu ilə yox.

---

# 6. LAYİHƏ MƏTNLƏRİ

> ⚠️ **LAYİHƏ — HÜQUQİ BAXIŞ TƏLƏB OLUNUR**
>
> Aşağıdakılar mövcud sənədlərin stilində, **yalnız faktı təsvir edir**.
> Hüquqi əsas, öhdəlik dili və hüquqi iddia formalaşdırması qəsdən
> yazılmayıb. Saxlaya, dəyişə və ya tamamilə ata bilərsiniz.

## 6.1. Məxfilik §2.5 (əvəzedici — faktiki səhvin düzəlişi)

> **2.5. Ödəniş məlumatları**
> Tətbiqdaxili VIP abunəlik alarkən kart məlumatlarınız Apple və
> Google-un ödəniş sistemləri tərəfindən işlənir; biz kart nömrənizi
> görmürük və saxlamırıq.
>
> Məkan abunəliyi, kampaniya yerləşdirmə haqqı, boost və PinBox
> ödənişləri kart vasitəsilə **Epoint** ödəniş sistemi üzərindən
> aparılır. Kart məlumatlarınız Epoint-in öz mühitində daxil edilir və
> işlənir — biz kart nömrənizi görmürük və saxlamırıq. Bizdə saxlanan
> ödəniş qeydi ödənişin məbləği, tarixi, növü və statusundan ibarətdir.

## 6.2. Məxfilik §4 (əvəzedici siyahı)

> Xidmət provayderləri: Google Firebase (məlumat saxlama, autentifikasiya,
> bildiriş), Google Maps (xəritə), Firebase Analytics və Crashlytics
> (istifadə statistikası və qəza hesabatları), Apple/Google ödəniş
> sistemləri (tətbiqdaxili abunəlik), **Epoint** (kart ödənişləri).

## 6.3. Məxfilik — yeni §2.7 (lokasiya, genişləndirilmiş)

> **2.7. Lokasiya, görünürlük və iştirak məlumatı**
> Cari coğrafi mövqeyiniz ətrafınızdakı istifadəçiləri, məkanları və
> kampaniyaları göstərmək üçün toplanır. Başqa istifadəçiyə
> göndərilməzdən əvvəl mövqeyiniz şəbəkəyə yuvarlaqlaşdırılır — dəqiq
> koordinatınız heç vaxt paylaşılmır.
>
> Görünmə radiusunuzu Ayarlardan seçirsiniz. **Ghost Mode** açıq
> olduqda yaxınlıq siyahılarında, məkan iştirak sayğaclarında və ad
> günü eşleşmələrində ümumiyyətlə iştirak etmirsiniz.
>
> Məkana könüllü check-in etdiyinizdə bu, məkanın iştirak sayğacına
> daxil olur. Məkan sahibi yalnız **sayı** görür, kimliyi yox. Say
> 5-dən azdırsa sıfır göstərilir.

## 6.4. Məxfilik — yeni §2.8 (ad günü)

> **2.8. Doğum tarixi və ad günü kampaniyaları**
> Doğum tarixiniz yaş yoxlaması üçün toplanır. Ad günü kampaniyaları
> **yalnız** Ayarlar → Məxfilik bölməsində bu funksiyanı özünüz
> açdığınız halda işləyir; defolt olaraq bağlıdır.
>
> Açıq olduqda ad gününüz günü yaxınlığınızdakı uyğun məkanlara «bu
> gün yaxınlığınızda N istifadəçinin ad günüdür» **sayı** bildirilir.
> Doğum tarixiniz, adınız və kimliyiniz məkanla paylaşılmır.
> Funksiyanı söndürsəniz heç bir ad günü bildirişi göndərilmir.

## 6.5. Məxfilik §5 (əvəzedici — saxlama cədvəli)

> **5. Məlumatların saxlanması və silinməsi**
> Məlumatlarınız hesabınız aktiv olduğu müddətdə saxlanılır. Bəzi
> məlumat növləri isə daha qısa müddətdə avtomatik silinir:
>
> | Məlumat | Müddət |
> |---|---|
> | Story (sənəd, baxış qeydləri, media faylı) | 24 saat |
> | Kimlik doğrulama şəkilləri | 90 gün |
> | Məkan iştirak tarixçəsi | 7 gün |
> | Ad günü eşleşmələri və siyahısı | 3 gün |
> | Daxili bildiriş qeydləri | 3 gün |
>
> Ayarlar → Hesab → «Hesabı sil» ilə hesabınızı silə bilərsiniz. Profil
> məlumatlarınız, mediayanız, mesajlarınız və story-ləriniz silinir.
>
> Başqa istifadəçilərin qeydlərinə daxil olan məlumat **silinmir,
> anonimləşdirilir** — PinBox sifarişləri satıcının satış qeydində,
> yaratdığınız elanlar alıcıların sifarişlərində adsız formada qalır.
> Ödəniş qeydləri maliyyə audit izi kimi saxlanılır.

## 6.6. Oferta — yeni bənd (ödənişin gecikməsi)

> **Abunə ödənişi gecikdikdə.** Ödəniş güzəşt müddəti ərzində
> edilməzsə məkanın statusu dayandırılır. Bu müddətdə: məkan və elanları
> istifadəçilərə göstərilmir; yeni kampaniya, tədbir və PinBox
> yaradıla bilmir; dövrün pulsuz kvotası **dondurulur** — sıfırlanmır və
> yenilənmir. Ödəniş edildikdən sonra məkan bərpa olunur və yeni dövrün
> kvotası açılır.

---

# 7. YOXLAMA SİYAHISI

- [ ] §2.5 və §4 — Epoint düzəlişi *(faktiki səhv, birinci prioritet)*
- [ ] §2 — on yeni bənd (bölmə 2)
- [ ] §5 — saxlama cədvəli və silinmə davranışı
- [ ] Oferta §4, §6, §7 + gecikmə bəndi
- [ ] Şərtlər §7 — moderasiya modeli
- [ ] HTML başlıqlarında versiya və tarix
- [x] `legal_versions.dart` → 1.1 / 2.0 *(01.09.2026)*
- [ ] `config/legal` — YALNIZ mətnlər canlı **VƏ** AAB yayıldıqdan sonra (§5.3)
- [ ] `config/businessOffer.currentVersion`
