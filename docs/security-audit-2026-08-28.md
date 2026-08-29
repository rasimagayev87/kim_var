# PeakPin — Tam Təhlükəsizlik və Production Hazırlıq Auditi (Tam Versiya)

**Tarix:** 2026-08-28
**Əhatə:** 8 audit bloku, 250+ yoxlama, hər biri tam bənd-bənd, fayl:sətir sübutları ilə sənədləşdirilib.
**Metod:** Yalnız statik kod və konfiqurasiya təhlili (READ-ONLY) — heç bir fayl dəyişdirilmədi, heç bir deploy edilmədi, heç bir production data oxunmadı/yazılmadı, heç bir zəiflik "sübut üçün" istismar edilmədi.

**Bloklar:** A (Autentifikasiya/Hesab, 26 yoxlama) · B (RBAC/Admin Panel, 24 yoxlama) · C (İstifadəçi Datası/Lokasiya/Məkanlar, 32 yoxlama) · D (Ödənişlər/Boost/Abunə/PinBox Payout, 34 yoxlama) · E (Real-time/Chat/PinBox/API, 43 yoxlama) · F (Database/Mobil/İnfra, 47 yoxlama) · G (Remote Config/App Check/Xərc Sui-istifadəsi, 18 yoxlama) · H (Hüquqi/IAP/Kateqoriya/Məxfilik, 26 yoxlama).

---

## 1. Executive Summary

| Kateqoriya | Blok | Yoxlanmış | PASS | WARNING | FAIL | Digər | Bal (0-100) |
|---|---|---|---|---|---|---|---|
| RBAC / Admin Panel | B | 24 | 9 | 7 | 7 | 1 (NOT IMPL) | **52** |
| Autentifikasiya / Hesab | A | 26 | 3 | 6 | 15 | 2 | **25** |
| Ödənişlər / Boost / Abunə / PinBox Payout | D | 34 | 10 | 9 | 14 | 1 | **44** |
| Database (Rules) / Mobil / İnfrastruktur | F | ~45 | 8 | 8 | ~25 | 4 | **28** |
| Real-time / Chat / PinBox / API | E | 43 | 8 | 8 | 26 | 1 | **28** |
| İstifadəçi Datası / Lokasiya / Məkanlar | C | 32 | 3 | 8 | 19 | 2 | **22** |
| Remote Config / App Check / Xərc Sui-istifadəsi | G | 18 | 2 | 4 | 9 | 3 | **22** |
| Hüquqi / IAP / Kateqoriya / Məxfilik | H | 26 | 6 | 7 | 12 | 1 | **38** |

**Ümumi Təhlükəsizlik Balı: 32 / 100**

Bu, təkcə "bəzi boşluqları olan" tətbiq deyil — **arxitektural səviyyədə sistemli bir naxışdır**: Firestore Rules demək olar hər yerdə "blocklist" modeli ilə yazılıb (yalnız bəzi sahələr qadağandır, defolt icazə verir), server-tərəf enforcement neredeyse heç bir yerdə yoxdur, App Check bütün 25 Cloud Function-da açıq şəkildə söndürülüb, rate limiting kod bazasında ümumiyyətlə mövcud deyil, və mobil tətbiqin UI-da göstərdiyi demək olar hər "qadağa" (Ghost Mode, gizlilik radiusu, blok, read-only rejim, kateqoriya məhdudiyyəti) sadəcə kosmetik göstəricidir — server heç birini yoxlamır.

**Ən yaxşı qorunan sahə**: `payments`/`savedCards`/`venuePayouts`/`pinboxOrders` kolleksiyalarının client-yazısına tam bağlı olması, ödəniş məbləğlərinin server-tərəf sabit cədvəllərdən gəlməsi, admin panelin icazə modeli (kim admin ola bilər), və 25 Cloud Function-un hamısında düzgün sahiblik yoxlaması. **Ən zəif sahə**: Firestore/Storage Rules-un böyük əksəriyyəti "kim daxil olubsa, hər şeyi edə bilər" səviyyəsindədir — pul aparılan andan SONRA (refund, entitlement revocation) və sosial/real-time layer-in demək olar hamısı.

---

## 2. Kritik Tapıntılar (CRITICAL) — 13 tapıntı

### K-1. `users/{uid}` kolleksiyası bütün daxil olmuş istifadəçilərə tam oxunaqlıdır — PII + canlı GPS + push token-lər
**Mənbə:** A (AUTH-1), C (#35,36,37,52), E (RT-25)
**Fayl:** `firestore.rules:75-78` — `allow read: if request.auth != null` (heç bir sahə filtri, `list` də daxil)
Sənəddə `email`, `phoneNumber`, `birthDate`, tam dəqiqlikli `lat`/`lng` (25m-də bir yenilənir), `fcmTokens`, `blockedUsers`, `knownDeviceSignatures`, `activeCheckinVenueId`, `activeChatId` var. `usernames` kolleksiyası isə hesabsız (`allow list: if true`, `firestore.rules:279`) bütün username→uid xəritəsini verir. Bir skript `db.collection('users').limit(1000).get()` + səhifələmə ilə **bütün istifadəçi bazasını** endirə bilər.
**Real dünya təsiri:** Kütləvi PII sızması, real-time stalking, push-token korrelyasiyası. Ghost Mode/gizlilik radiusu yalnız client-filtrdir — xam sorğunu keçmir.

### K-2. `chats/{chatId}/messages` — istənilən iştirakçı qarşı tərəfin mesajını sərbəst yenidən yaza bilər
**Mənbə:** F (INFRA-2), E (RT-1)
**Fayl:** `firestore.rules:408` — `allow update: if ... chatId.split('_').hasAny([request.auth.uid])` (heç bir `hasOnly()`, `senderId` yoxlanmır)
İki müstəqil audit blokunun eyni tapıntısı: alıcı göndərənin `text`/`senderId`/`mediaUrl`/`sentAt` sahəsini tam sərbəst dəyişə bilir, redaktə izi qalmır. Şantaj, saxta "razılıq" yazışması, hüquqi sübut kimi istifadə riski.

### K-3. Blok mexanizmi TAM OLARAQ fiktivdir — server heç bir yerdə yoxlamır
**Mənbə:** E (RT-11)
`firestore.rules`-un 1169 sətrində `blockedUsers` sözü **bir dəfə də keçmir**. Yeganə yoxlama Flutter repository-də (`firebase_chat_repository.dart:449-454`). Bloklanan şəxs SDK skripti ilə mesaj yaza, zəng edə (RT-14 — client-də belə yoxlama yoxdur), profil oxuya bilir. `onChatMessageCreated` (functions/src/index.ts:3741-3805) blok yoxlamadığı üçün push da çatır (RT-12). Taciz/təqib əleyhinə əsas mexanizm sıfır real təsirə malikdir.

### K-4. `venues/{venueId}/activeCheckins` — real-time fiziki mövcudluq izləyicisi, hər kəsə açıq
**Mənbə:** C (#53), E (RT-20, RT-21, RT-22)
**Fayl:** `firestore.rules:801-804` — sənəd id-si birbaşa uid, `allow read: if request.auth != null`
Bir skript bütün məkanları taramaqla "kim indi harada" xəritəsi qura bilər. `users/{uid}.activeCheckinVenueId` (K-1 ilə birlikdə) isə TƏK sənəd oxuması ilə konkret şəxsi izləməyə imkan verir. Ghost Mode bu yola heç toxunmur — istifadəçi qorunduğunu zənn edir. Bu, rəqəmsal deyil, **fiziki təhlükəsizlik** riskidir (təqib, oğurluq "ev boşdur" siqnalı, məişət zorakılığı qurbanları).

### K-5. `follows` create — "Hesab gizliliyi" (private account) funksiyası tam sındırılıb
**Mənbə:** F (INFRA-1)
**Fayl:** `firestore.rules:317-321` — client-in göndərdiyi `status` (`accepted`/`pending`) heç yoxlanmadan qəbul edilir
İstənilən istifadəçi özünü private hesabın "təsdiqlənmiş izləyicisi" elan edib onun story/post/like/comment-larını oxuya bilər — sahib heç vaxt sorğu görmür, heç vaxt təsdiqləmir.

### K-6. `venue_photos`/`offer_photos`/`pinbox_photos`/`event_covers` Storage — kütləvi dağıntı imkanı
**Mənbə:** F (INFRA-25), C (#59) — müstəqil təsdiqləndi
**Fayl:** `storage.rules:73-79, 83-89, 93-99, 103-109` — sahiblik yoxlaması yoxdur, əsaslandırma ("təxmin edilməyən auto-id") yanlışdır, çünki bütün id-lər Firestore-dan açıq oxunur
İstənilən istifadəçi bütün məkanların/təkliflərin/PinBox-ların/tədbirlərin şəkillərini bir neçə dəqiqəyə əvəz edə və ya silə bilər — heç bir Firestore dəyişikliyi baş vermədiyi üçün heç bir moderasiya/admin siqnalı işə düşmür.

### K-7. App Check 25/25 Cloud Function-da açıq şəkildə söndürülüb, rate limiting kod bazasında sıfırdır
**Mənbə:** F (INFRA-45), G (#174, #176, #177), E (RT-40, RT-41), A (AUTH-14)
**Fayl:** `functions/src/index.ts:27-40` + bütün 25 `onCall`-da `enforceAppCheck: false`
Bu, TƏKBAŞINA ən pis tapıntı olmaya bilər, amma **bütün digərlərinin miqyaslana bilməsinin səbəbidir**: real cihaz, real tətbiq, jailbreak lazım deyil — bir atılan hesab + skript kifayətdir ki, yuxarıdakı bütün K-1…K-6 hücumları avtomatlaşdırılsın.

### K-8. Reputasiya sayğaclarının (`starCount`/`heartCount`/`dislikeCount`/`reportedCount`) tam saxtalaşdırılması
**Mənbə:** C (#38), F (INFRA-3, INFRA-22, INFRA-23, INFRA-24), E (RT-34, RT-35) — üç müstəqil blok
**Fayl:** `firestore.rules:114-125`
İki qat problem: (1) istənilən istifadəçi başqasının sayğacını dəyişə bilər, "bir istifadəçi bir səs" heç bir formada yoxdur; (2) `hasOnly` + `||` məntiq qüsuru sayəsində BİR yazı ilə DÖRD sahədən üçünü ixtiyari dəyərə (999999999) qoymaq mümkündür, tək bir sahənin +1 şərti ödənsə kifayətdir. Qurbanın `reportedCount`-unu süni şişirdib avtomatik/moderasiya təsirli ban tetiklemek mümkündür.

### K-9. PinBox yaradılanda venue sahibliyi HEÇ yoxlanmır
**Mənbə:** C (#58), E (RT-26) — müstəqil təsdiqləndi
**Fayl:** `firestore.rules:885-893` — qonşu `venueEvents` qaydası (`:937-938`) bunu düzgün edir, `pinboxes` etmir
İstənilən istifadəçi başqasının restoranının adından real pul yığan PinBox elanı yerləşdirə bilər; admin təsdiqindən sonra alıcılar ödəyir, 85% payout öhdəliyi isə **günahsız** məkan sahibinin adına yazılır (`functions/src/index.ts:4855-4872`).

### K-10. Köhnəlmiş Epoint checkout linkləri hələ ödənilə bilir — real pul səssizcə udulur
**Mənbə:** D (PAY-6)
**Fayl:** `functions/src/index.ts:3190-3192, 3525-3540, 4548-4563` (supersede) + `epoint.ts` (ləğv API-si yoxdur) + `:4650` (səssiz udma)
"Şəbəkə qopdu, yenidən öd" adi ssenarisi belə bunu yaradır: köhnə link Epoint tərəfdə canlı qalır, ödənildikdə webhook `failed` statuslu sənədə düşür, heç nə yazılmadan, heç kimə xəbər getmədən HTTP 200 qaytarılır. Nəticə: real pul alınır, heç bir xidmət verilmir.

### K-11. Refund heç vaxt qazanılmış imtiyazı geri almır — PinBox-da PeakPin özü 85% ödəyə bilər
**Mənbə:** D (PAY-7, PAY-8)
**Fayl:** `functions/src/index.ts:2973-3039` (yalnız status dəyişir) + `venuePayouts` kolleksiyasının `cancelled` statusu ÜMUMIYYƏTLƏ yoxdur (`pinbox-payouts.ts:5, 30-32` — naməlum status avtomatik `pending`-ə "geri qayıdır")
Müştəri 100% geri alır, PeakPin isə artıq venue-ya 85% ödəmiş ola bilər — razılaşdırılmış cüt bunu ayda bir dəfə təkrarlaya bilər.

### K-12. Admin panelə `emergencyToken` — URL-də daşınan tam admin credential-ı
**Mənbə:** B (RBAC-1), A (AUTH-7) — müstəqil təsdiqləndi
**Fayl:** `admin-panel/src/app/login/page.tsx:70-85` + `scripts/mint-emergency-token.ts`
Token minti üçün service-account açarı lazımdır (xarici hücumçu saxtalaşdıra bilməz), AMMA URL-də daşındığı üçün Cloud Run request loglarına yazılır — yalnız `logging.viewer` icazəsi olan (admin OLMAYAN) biri 1 saat ərzində linki "oğurlayıb" tam admin ola bilər. 24 avqustda "MÜVƏQQƏTİ" commit edilib, hələ də canlıdır.

### K-13. 13 yaşından qeydiyyat mümkündür — 18+ tələbinə baxmayaraq, server-side yoxlama yoxdur
**Mənbə:** H (#218)
**Fayl:** `lib/features/auth/presentation/screens/onboarding_screen.dart:135`
K-1 + K-4 ilə birləşdikdə: 13-14 yaşlı hesab tam dəqiqlikli canlı koordinatla yaxınlıqdakı böyüklərə göstərilir, bir-toxunuşla birbaşa çat açıla bilər. Nəşr olunmuş Uşaq Təhlükəsizliyi səhifəsi mövcud olmayan nəzarəti iddia etdiyi üçün bu, həm də Google Play-ə qarşı yalan bəyanatdır.

---

## 3. Yüksək Tapıntılar (HIGH) — tematik qruplaşdırma (60+ tapıntı, əsasları)

**Autentifikasiya (Blok A)**
- Uzaqdan "cihazı çıxar" real işləmir — `revokeRefreshTokens` heç vaxt çağırılmır, oğurlanmış refresh token hesabda qalır (AUTH-3)
- "Yeni cihazdan giriş" xəbərdarlığı susdurula bilir — barmaq izi yalnız user-agent heşi, K-1-ə görə hər kəsə oxunaqlı siyahıda saxlanır (AUTH-9)
- Email təsdiqi göndərilir, amma HEÇ yerdə tələb edilmir — başqasının ünvanını əvvəlcədən tutub Google girişindən kilidləmək mümkündür (AUTH-12)
- `username` sahəsi rezervasiya ilə bağlı deyil — istənilən istifadəçi `@support`/`@admin` kimi görünə bilər (AUTH-6)
- Hesab silinərkən username rezervasiyası və təsdiqlənməmiş ID sənədləri silinmir (AUTH-10, AUTH-11)
- Heç bir yerdə MFA yoxdur, admin parolu minimum 6 simvol (AUTH-8)
- `submitIdentityVerification` client-seçimli `requestId` ilə `.set()` — başqasının sənədini əvəz etmək mümkün (AUTH-15)

**RBAC/Admin (Blok B)**
- Heç bir yerdə MFA yoxdur — dövlət ID sənədlərinə giriş tək faktorludur (RBAC-2)
- `changeAdminRole` uid-i yoxlamadan əvvəl claim yazır — gizli, loglanmayan admin yaratmaq mümkündür (RBAC-8)
- Audit-trail xətaları udur, əməliyyatdan SONRA yazılır — Admin SDK öz izini silə bilər (RBAC-11)
- Moderatorlar "yalnız kontent moderasiyası" icazəsi ilə geri-ödəmələri və PinBox ödənişlərini "ödənilib" işarələyə bilir (RBAC-12)
- KYC sənədlərinə (pasport/selfie) baxış heç loglanmır (RBAC-14)
- `/api/health` autentifikasiyasız, Admin SDK çağırır, xəta mətnini olduğu kimi qaytarır (RBAC-18)

**Ödənişlər (Blok D)**
- Eyni ödəniş paralel webhook-larla iki dəfə tətbiq oluna bilər — TOCTOU race (PAY-5)
- Üç ödəniş növünün (boost, VIP profil, PinBox) HEÇ BİR refund yolu yoxdur — yalnız əl ilə Firestore redaktəsi (PAY-9)
- Ödənilməmiş venue abunəliyi görünürlüyə heç təsir etmir — bir ödənişdən sonra sonsuza qədər görünən qalır (PAY-10)
- Sürət limiti yoxdur — kart-testinq (oğurlanmış kart yoxlama) platforması kimi istifadə edilə bilər (PAY-16)
- VIP abunəsi bir qəbzlə limitsiz hesaba paylaşıla bilər (PAY-25, K-6/K-7-yə bənzər H tapıntısı ilə üst-üstə düşür)
- Hesab silinərkən PinBox sifarişləri/payout-lar orphan qalır (PAY-24)
- Saved-card ödənişində itən cavab — pul çıxa bilər, entitlement verilmir (PAY-18)

**Database/İnfra (Blok F)**
- `offers`/`pinboxes` update qaydası MƏZMUNU (title/price/description) kilidləmir — təsdiqlənmiş elan sonradan scam məzmununa çevrilə bilər (INFRA-5)
- `reviews` avtorizasiyasız (hesabsız!) oxunur — kim hansı məkana getdiyi ictimaidir (INFRA-8)
- Shared, məhdudlaşdırılmamış Google Maps API açarı hər iki platforma üçün — bir açar iki platformada eyni zamanda restrict edilə bilməz (INFRA-32)
- Root/jailbreak aşkarlanması, sertifikat pinning, ProGuard/R8 obfuskasiya — heç biri yoxdur (INFRA-34, 35, 36)
- `shared_preferences`-də şifrələnməmiş email/doğum tarixi (INFRA-40)
- Debug keystore-a sükutlu keçid, release build-i saxtalaşdırıla bilər (INFRA-37)

**Real-time/Chat/PinBox (Blok E)**
- Chat mesajı yaratmada uzunluq/məzmun limiti yoxdur — 1MB mesaj OOM yaradır (RT-2)
- `whoCanMessageMe: followersOnly` tam fiktivdir — client-only (RT-6)
- Söhbət sorğusu rədd edilsə belə mesaj göndərmək mümkündür — server enforcement yoxdur (RT-5)
- `getTurnCredentials` limitsiz — Cloudflare hesabına yazılan pulsuz TURN relay yaratmaq mümkündür (RT-15)
- PinBox stok ödənişdən ƏVVƏL azaldılır, tərk edilmiş checkout-u geri qaytaran sweep yoxdur — rəqib bütün stoku pulsuz "tuta" bilər (RT-29)
- `users` kolleksiyası tam `list` icazəsi ilə (RT-25 — K-1-in genişlənməsi)

**Lokasiya/Uyğunluq (Blok C, G, H)**
- EXIF GPS metadatası heç vaxt təmizlənmir, `image_picker_android` GPS-i geri köçürür (C #43)
- Remote Config-in bütün "kill-switch"ləri (maintenance/read-only/force-update/10 feature flag) yalnız kosmetikdir — server heç birini tanımır (G #165-170)
- Publik Oferta qəbulu client-in göndərdiyi versiya/URL-ə əsaslanır (H #181)
- Play Data Safety bəyanatı köhnəlib — Branch.io, Analytics, Crashlytics açıqlanmayıb (H #213, #217)

---

## 4. Orta (MEDIUM) və Aşağı (LOW) Tapıntılar — qısa xülasə

**MEDIUM (40+):** chat/söhbət silinməsi mesajları silmir (INFRA-20, RT-7); chat media Storage-da alıcı tərəfindən silinə bilir + token-li URL həmişəlik açıqdır (RT-8); zəng sənədləri heç silinmir, süresiz saxlanır (RT-19); `showOnlineStatus` parametri kod bazasında heç yerdə oxunmur — tam fiktiv (RT-24); MIME validasiyası yalnız client-bəyanına əsaslanır, magic-byte yoxlanmır (C #40); venue/offer sahiblik-birləşmiş sahələr (`gallery`, `verified`) qaydalarda kilidli deyil (C #61); Storage-da per-user kvota/limit yoxdur (INFRA-28); `birthdayMatches` kolleksiyası hər kəsə açıq (INFRA-11); dependency-lərdə Node 20 EOL, vendored abandoned paket (INFRA-44).

**LOW (25+):** timing-safe olmayan webhook imza müqayisəsi (PAY-2); `redeemPinBoxOrder`-da brute-force rate-limiti yoxdur (RT-31, PAY-22); admin panel security header-ləri yoxdur (RBAC-21); logout server-tərəfdə sessiyanı ləğv etmir (RBAC-19); pul hesablamalarında float dəyərlər (PAY-28).

---

## 5. Quick Wins (≤48 saat) — mövcud naxışların təkrarı, yeni infrastruktur lazım deyil

1. `usernames` və `reviews` oxuma qaydalarını `request.auth != null`-a bağla
2. `firestore.rules:114-125`-dəki reputasiya sayğaclarının qeyri-sahib update budağını **tamamilə sil** (K-8-i bağlayır — heç bir legitim client-yazıcı qalmayıb)
3. `pinboxes` create qaydasına `venueEvents`-dəki mövcud sahiblik sətrini köçür (K-9-u bağlayır)
4. `chats/{chatId}/messages` update qaydasını sahə-məhdud iki budağa böl (K-2-ni bağlayır)
5. `venues/{venueId}/activeCheckins` oxuma icazəsini sahibə/venue-sahibinə məhdudlaşdır (K-4-ü bağlayır)
6. `follows` create qaydasına followee-nin `accountPrivacy`-sini yoxlayan `get()` əlavə et (K-5-i bağlayır)
7. `venue_photos`/`offer_photos`/`pinbox_photos`/`event_covers` Storage yollarına `{ownerUid}/` seqmenti əlavə et (K-6-nı bağlayır)
8. `venues.verified`-i bloklanmış sahələr siyahısına əlavə et
9. Admin panel `emergencyToken` bypass-ını sil (K-12)
10. Onboarding tarix seçicisini `now.year - 18`-ə düzəlt (K-13-ün client hissəsi)
11. Google Maps API açarını platformaya görə məhdudlaşdır (Cloud Console-da, kod dəyişikliyi yox)
12. `remoteconfig.template.json`-u canlı şablonla sinxronlaşdır və ya `firebase.json`-dan çıxar
13. GCP Billing budget + hard alert qur (Console-da)

---

## 6. Production-dan Əvvəl Checklist — Top 20 (P0-P3)

**P0 (buraxılışdan əvvəl mütləq):**
1. `users/{uid}` sahə-səviyyəli oxu ayrımı (K-1)
2. Admin panel `emergencyToken` bypass-ını sil, MFA əlavə et (K-12, RBAC-2)
3. Server-side yaş yoxlaması 18+ (K-13)
4. Chat mesaj update qaydasını sıxlaşdır (K-2)
5. Blok mexanizmini server-tərəfə köçür — ən azı `chats`/`calls` create qaydalarında (K-3)
6. `activeCheckins` və `activeCheckinVenueId` oxu icazəsini sıxlaşdır (K-4)
7. `follows` create-i server-tərəf yoxlamaya bağla (K-5)
8. Storage-da venue/offer/pinbox/event şəkil yollarına sahiblik əlavə et (K-6)
9. Reputasiya sayğaclarının qeyri-sahib yazısını sil (K-8)
10. `pinboxes` create-ə venue-ownership yoxlaması əlavə et (K-9)
11. Superseded Epoint linklərini deaktiv et / "tətbiq olunmamış ödəniş" alert-i qur (K-10)
12. Refund → entitlement revocation + PinBox payout ləğvi axını qur (K-11)
13. VIP satınalma-hesab bağlılığı + sandbox rədd (H #194, #196)
14. App Check-i ən azı ödəniş/PII/PinBox funksiyalarında aktiv et (K-7)

**P1 (ilk 2 həftə):**
15. Rate limiting infrastrukturu (per-uid sayğac) — TURN, PinBox reservation, redemption, checkout
16. `offers`/`pinboxes` update qaydasına məzmun sahələrini kilidlə
17. EXIF GPS metadatasını yükləmədən əvvəl təmizlə

**P2 (1 ay):**
18. Firestore rules regression test suite (`@firebase/rules-unit-testing`)
19. Play Data Safety + App Store Privacy Label yenilə

**P3 (davamlı):**
20. Strukturlu təhlükəsizlik hadisə logging-i + Cloud Monitoring alert

---

## 7. Ödəniş Fırıldaqçılığı Ssenariləri

1. **Superseded-link udma/ikiqat ödəniş** (K-10) — "şəbəkə qopdu, yenidən öd" hər dəfə real risk yaradır
2. **PinBox refund + payout collusion** (K-11) — cüt ayda bir dəfə 85% xalis mənfəət çıxara bilər
3. **VIP paylaşma zənciri** (PAY-25) — bir abunə limitsiz hesaba VIP verə bilər, "restore purchases" hər dəfə
4. **Sandbox/tester VIP** (H #196) — production-da pulsuz VIP
5. **Kart testinq** (PAY-16) — heç bir velocity limiti olmadan oğurlanmış kartları yoxlamaq platforması
6. **PinBox stok tutma** (RT-29) — rəqib rəqibinin bütün stokunu pulsuz "tuta" bilər, satışı dayandırır
7. **Race-condition double-grant** (PAY-5) — paralel webhook-la bir ödənişdən iki abunə dövrü
8. **Webhook məbləğ təsdiqi yoxdur** (PAY-4) — qismən capture tam qrant ala bilər

---

## 8. Səlahiyyət Eskalasiyası Matrisi

| Rol | Öz datası | Başqa istifadəçi PII/GPS | Başqa venue-ya yazı | Admin panel | VIP status | Verified nişanı | Financial ops (moderator) |
|---|---|---|---|---|---|---|---|
| **Anonim** | — | ❌ (hesab yaratmaq pulsuz, elə bilə k-1-ə keçid asan) | ❌ | ❌ | ❌ | ❌ | — |
| **Adi istifadəçi** | ✅ | 🔴 BƏLİ (K-1) | 🔴 PinBox-da BƏLİ (K-9) | ❌ | 🔴 sandbox/replay (H, PAY-25) | ❌ | — |
| **Biznes istifadəçi** (öz-idarəli sahə) | ✅ | 🔴 BƏLİ | 🔴 BƏLİ | ❌ | 🔴 BƏLİ | 🔴 **BƏLİ** (C #61) | — |
| **Moderator** | ✅ | ✅ (nəzərdə tutulan) | ✅ | Qismən | ✅ | ✅ | 🔴 **BƏLİ** (RBAC-12 — "yalnız kontent" icazəsi ilə refund/payout) |
| **Admin** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **"Emergency" token sahibi** (admin olmayan log-oxuyucu daxil) | ✅ | ✅ | ✅ | 🔴 **BƏLİ, MFA-sız** | ✅ | ✅ | ✅ |

**Nəticə: FAIL.** Backend adi istifadəçi ilə admin arasındakı sərhədi bir çox kritik nöqtədə (PII, verified nişan, PinBox venue-ownership, VIP grant) real ayırmır; moderator rolu isə öz təyin olunmuş sərhədini (yalnız kontent) də aşır.

---

## 9. Xərc Sui-istifadəsi Ssenariləri

1. **TURN credential mint** (RT-15) — limitsiz çağırış, hər dəfə Cloudflare-də 1 saatlıq credential, real zəng şərti yoxdur → Cloudflare fakturası
2. **Storage bombalanması** (INFRA-28, G #176) — paralel 200 axınla 50MB video, say limiti yoxdur, resize extension əlavə xərc yaradır
3. **Tam venue/pinbox/user bazasının çıxarılması** (K-1, G #177) — `.limit()` olmayan sorğular
4. **Şikayət/e-poçt bombalanması** (RT-36, G #178) — `reportedCount` və `reports` dedup-suz, hər sənəd bir Resend e-poçtu
5. **Webhook flooding** (INFRA-46) — `epointWebhook`/`appStoreServerNotifications`-da Cloud Armor/rate limit yoxdur, hər saxta sorğu iki tam sertifikat-zənciri yoxlaması yaradır
6. **PinBox redemption brute-force** (RT-31, PAY-22) — 6 rəqəmli kod, cəhd limiti yoxdur

---

## 10. Top 10 Production Riskləri

1. `users` kolleksiyasının açıq oxunması — kütləvi PII + canlı GPS (K-1)
2. `activeCheckins` real-time fiziki izləmə — rəqəmsal deyil, fiziki təhlükəsizlik riski (K-4)
3. Chat mesaj tamperinq + blok mexanizminin tam fiktiv olması (K-2, K-3)
4. Minorların qeydiyyatı + tam açıq lokasiya/çat kombinasiyası (K-13)
5. Admin panel MFA-sız `emergencyToken` bypass (K-12)
6. Ödəniş udulması/ikiqat ödəniş + refund-entitlement əlaqəsizliyi (K-10, K-11)
7. PinBox venue-sahiblik yoxlanmaması — üçüncü şəxsin adından satış (K-9)
8. Reputasiya sayğaclarının bir-yazıda tam saxtalaşdırılması (K-8)
9. App Check 25/25 funksiyada söndürülüb + sıfır rate limiting — yuxarıdakı hər şeyin miqyaslana bilməsinin səbəbi (K-7)
10. Storage-da kütləvi biznes-şəkil dağıntı imkanı (K-6)

---

## 11. Yoxlanıla Bilməyənlər (Cannot Verify)

- **Canlı Firebase Remote Config şablonu** — yerli fayl 45 açardan yalnız 4-ünü saxlayır, `firebase remoteconfig:get` bu auditdə qadağandır (G #166, #170)
- **Firebase Console-dakı App Check enforcement vəziyyəti** (Monitoring vs Enforced) — yalnız Console-dan yoxlanıla bilər (G #173, F INFRA-45's "monitor mode" tövsiyəsi)
- **Play Console/App Store Connect-in cari track vəziyyəti** — hansı versiya kodları hələ aktivdir (H #212)
- **Google Cloud Console-da API açarlarının restriction vəziyyəti** (INFRA-32, INFRA-33) — Maps açarının restrict olunub-olunmadığı yalnız Console-dan görünür
- **`peakpin_vip_*` SKU-larının Play Console/App Store Connect-də faktiki mövcudluğu**
- **Production-da real itki həcmi** (PAY-34) — `payments` sənədlərində `status: failed` amma `epointTransaction` mövcud olan sənədlərin sayı yalnız bağlanmış, hədd qoyulmuş sayğac sorğusu ilə (əvvəlcədən təsdiq alınaraq) yoxlanıla bilər

---

## 12. Yekun Qərar (Final Verdict)

# **NOT SAFE FOR PRODUCTION**

Tam, 8-bloklu, 250+ bəndlik audit bu qərarı yalnız gücləndirdi. Bu, tək bir zəiflik deyil — sistemli arxitektura problemidir: backend demək olar heç bir yerdə client-in göndərdiyi məlumata etibar etməməli olduğu halda edir, "gizlilik", "blok", "Ghost Mode", "read-only", "kateqoriya məhdudiyyəti" kimi istifadəçiyə vəd edilən demək olar hər müdafiə qatı yalnız UI-dadır.

**Mütləq düzəldilməli (buraxılışdan əvvəl, minimum) — Bölmə 6-nın P0 siyahısı, 14 maddə.**

Bu maddələr həll olunmadan mağaza buraxılışı davam edərsə: kütləvi PII/GPS sızması və real-time fiziki izləmə (K-1, K-4) canlıdır; taciz/təqib qurbanlarının blok düyməsi işləmir (K-3); real pul itkisi (K-10, K-11) davam edir; 13 yaşından kiçiklər tam açıq lokasiya ilə böyüklərə göstərilir (K-13); admin sisteminin ələ keçirilmə ehtimalı (K-12) mövcuddur — hamısı hazırda istismar oluna bilən vəziyyətdədir.

**Müsbət qeyd:** Ödəniş MƏBLƏĞLƏRİNİN təyini (server-tərəf sabit cədvəllər), admin panelin ROL modeli (kim admin ola bilər), və 25 Cloud Function-un HAMISINDA düzgün sahiblik yoxlaması — bunlar arxitektural olaraq düzgün qurulub. Problem əsasən "pul/məlumat DAXİL OLDUQDAN SONRA nə baş verir" sualında cəmlənib, ilkin giriş nəzarətində deyil. Bu, düzəlişlərin — nə qədər çox olsalar da — konseptual cəhətdən səpələnmiş deyil, bir neçə təkrarlanan naxışın (server-tərəf enforcement, App Check, rate limiting) sistemli tətbiqi ilə mümkün olduğunu göstərir.
