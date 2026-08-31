# PeakPin — Audit 4 (release-blocker), 2026-08-31

**Metod:** yalnız oxu. Heç bir kod dəyişdirilmədi, heç bir production
sistemə toxunulmadı. Emulator sübutları `demo-peakpin-rules-test`
layihəsində alındı; müvəqqəti probe faylı işlədikdən sonra silindi
(`git status` təmizdir).

**Ön oxu:** `ACCEPTED_RISKS.md`, `BACKLOG.md`, `VENUE_OCCUPANCY.md`,
`self-verification-2026-08-30.md` — hamısı oxundu, məlum maddələr
yenidən "kəşf" kimi verilmir.

**Baza doğrulama:** mövcud qayda paketi işlədildi —
`tests/rules` → **428 test / 428 keçdi / 0 uğursuz** (24.9 s).

```
CRITICAL: 1    HIGH: 2    MEDIUM: 4    LOW: 1
REGRESSION: 1  FIX-INCOMPLETE: 3
RELEASE BLOCKER: 1
```

**SON QƏRAR: 🔴 DO NOT RELEASE** — bir CRITICAL var (A4-C1). O
bağlandıqdan sonra vəziyyət 🟡 READY AFTER FIXES olur; qalan heç bir
tapıntı tək başına buraxılışı bloklamır.

---

# ƏN VACİB 5 PROBLEM

| # | ID | Nə | Blokla­yır |
|---|---|---|---|
| 1 | **A4-C1** | Admin panel post silərkən client-in yazdığı `mediaUrl`-i Admin SDK ilə silir → **bucket-da istənilən faylın silinməsi** (C-1 vektoru admin paneldə sağ qalıb) | **BƏLİ** |
| 2 | **A4-H1** | `users/{uid}.username` rezervasiyaya bağlı deyil → **istənilən handle-ın mənimsənilməsi** | Xeyr |
| 3 | **A4-H2** | Məkan sənədindəki iki YENİ sayğac (`visibleCheckinCount`, `currentAudienceCount`) kilid siyahısında yoxdur — kilid köhnə sahə adında qalıb | Xeyr |
| 4 | **A4-M1** | Çat mediasında `mediaUrl` **istənilən** Firebase bucket-ını qəbul edir (H-5 yarımçıq) | Xeyr |
| 5 | **A4-M2** | `previewVenueAudience` fasiləsiz radius oraculu; ön şərt = ödənişsiz `awaiting_payment` məkan | Xeyr |

---

# CRITICAL

```
ID:              A4-C1
BAŞLIQ:          Admin panelin post silmə axını client-in yazdığı URL-dən
                 yol çıxarıb Admin SDK ilə silir — bucket-da ixtiyari
                 obyektin silinməsi
STATUS:          FIX-INCOMPLETE  (P0 / C-1 `functions/` -də bağlandı,
                 admin paneldə eyni naxış qaldı)
SEVERITY:        🔴 CRITICAL
RELEASE BLOCKER: BƏLİ
```

**FAYL:SƏTİR**
* `admin-panel/src/lib/actions/content.ts:48` — `storagePathFromUrl`
* `admin-panel/src/lib/actions/content.ts:37-42` — `tryDeleteStorageUrl`
* `admin-panel/src/lib/actions/content.ts:78-79` — `deletePost`-un çağırışı
* `firestore.rules:2000-2001` — `posts` create-də `isOwnStorageUrl` yoxlaması
* Müqayisə (düzgün naxış): `functions/src/chat-media.ts:75-94`,
  `functions/src/index.ts:2038-2054`

**HÜCUMÇU:** istənilən qeydiyyatlı istifadəçi. Ön şərt: post yarada
bilmək (`isActiveUser`) və postun moderator/admin tərəfindən
silinməsi — hücumçu bunu öz postunu şikayət edərək və ya qayda pozan
məzmun yerləşdirərək etibarlı şəkildə təhrik edə bilir.

**TƏSİR:** Production Storage bucket-ında **istənilən obyektin geri
qaytarılmayan silinməsi** — Storage Rules tamamilə bypass olunur
(Admin SDK). Hədəflər: başqa istifadəçilərin `profile_photos/`,
`posts/`, `stories/`, `venue_photos/`, `offer_photos/`,
`pinbox_photos/`, `event_covers/` faylları və — ən ağırı —
`identity_verifications/{uid}/{requestId}/*` (KYC sübutu, hüquqi
saxlama predmeti). Bir post iki silmə verir (`mediaUrl` +
`thumbnailUrl`); post sayı məhdud deyil.

**SÜBUT**

```ts
// admin-panel/src/lib/actions/content.ts:48
function storagePathFromUrl(url: string): string {
  const match = url.match(/\/o\/([^?]+)/);
  return match ? decodeURIComponent(match[1]) : url;
}

// :37-42
async function tryDeleteStorageUrl(url: string | undefined): Promise<void> {
  if (!url) return;
  try {
    await getAdminStorage().bucket().file(storagePathFromUrl(url)).delete();
  } catch { /* Ignore */ }
}

// :78-79 — dəyər POST SƏNƏDİNDƏN, yəni client-dən gəlir
tryDeleteStorageUrl(data?.mediaUrl as string | undefined),
tryDeleteStorageUrl(data?.thumbnailUrl as string | undefined),
```

Qaydanın yeganə məhdudiyyəti bucket prefiksidir, yoldan sonrası
sərbəstdir:

```
// firestore.rules:2000
(!('mediaUrl' in request.resource.data) || isOwnStorageUrl(request.resource.data.mediaUrl)) &&
// isOwnStorageUrl → '…/kim-var-73ce9.firebasestorage.app/o/.*'
```

**İSTİSMAR YOLU** (icra EDİLMƏDİ)

1. Hücumçu `posts/{id}` yaradır və `mediaUrl`-i belə qoyur:
   `https://firebasestorage.googleapis.com/v0/b/kim-var-73ce9.firebasestorage.app/o/identity_verifications%2F{QURBAN_UID}%2F{reqId}%2Ffront.jpg`
   — qayda keçir, çünki prefiks düzgündür.
2. Postu şikayət edir (və ya onsuz da silinəcək məzmun qoyur).
3. Moderator `/feedback`-də «Sil» basır.
4. `deletePost` → `storagePathFromUrl` → `identity_verifications/{QURBAN_UID}/{reqId}/front.jpg`
   → `bucket().file(path).delete()`. Fayl gedir; `catch {}` xətanı udur,
   moderator heç nə görmür.

**NİYƏ CRITICAL:** bu, P0-da CRITICAL kimi təsnif edilmiş **eyni
mexanizmdir** — `functions/` -də düzəldilib, admin paneldə düzəldilməyib.
Silmə geri qaytarıla bilməz, başqa istifadəçilərin məlumatına dəyir və
hüquqi saxlanma predmeti olan KYC sübutunu məhv edə bilər.

**DÜZƏLİŞ YANAŞMASI:** URL-dən yol çıxarmağı tamamilə ləğv edin. Yolu
server-məlum dəyərlərdən qurun (`chat-media.ts` naxışı):
`posts/{userId}/{postId}.{ext}`. Yol qurmaq mümkün deyilsə — heç nə
silməyin. Aralıq (zəif) variant: silinən yolu `posts/{uid}/` prefiksi
ilə yoxlamaq. Eyni funksiya `_200x200` törəməsini də silməlidir
(bax **A4-M3**).

---

# HIGH

```
ID:              A4-H1
BAŞLIQ:          `users/{uid}.username` rezervasiya sistemindən asılı
                 deyil — istənilən handle mənimsənilə bilir
STATUS:          NEW
SEVERITY:        🟠 HIGH
RELEASE BLOCKER: XEYR
```

**FAYL:SƏTİR**
* `firestore.rules:307-323` — `touchesLockedUserFields()`; siyahı yalnız
  `premium, identityVerified, premiumExpiresAt, birthDate, reportedCount`
* `firestore.rules:400-401` — `allow update` (sahibin sərbəst yazısı)
* `firestore.rules:715-720` — `usernames` create (unikallıq YALNIZ burada)
* `lib/features/auth/data/repositories/firebase_auth_repository.dart:261-291`
  — `updateUsername` iki addımlı **client** əməliyyatıdır
* `functions/src/index.ts:1463` — `buildSearchProfilePayload` `data.username` oxuyur

**HÜCUMÇU:** istənilən qeydiyyatlı istifadəçi (dəyişdirilmiş client və
ya birbaşa Firestore REST çağırışı).

**TƏSİR:** Profil ekranında, axtarış nəticələrində, paylaşım kartında
və çat siyahısında `@handle` başqasının rezerv etdiyi (və ya
`isReservedUsername`-də qadağan edilmiş — `@peakpin`, `@admin`,
`@support`) ad kimi görünür. Yəni tətbiqin içində istifadəçinin
kimliyi yoxlamaq üçün baxdığı yeganə unikal sahə unikal deyil. Sosial
mühəndislik / brend imitasiyası vektoru. (`identityVerified` kilidli
olduğu üçün nişanı saxtalaşdırmaq mümkün deyil — təsiri məhdudlaşdıran
amil budur.)

**SÜBUT** — `firestore.rules:322`:

```
return request.resource.data.diff(resource.data).affectedKeys()
  .hasAny(['premium', 'identityVerified', 'premiumExpiresAt', 'birthDate', 'reportedCount']);
```

`username` bu siyahıda YOXDUR və `firestore.rules`-un heç bir yerində
`users` sənədindəki `username` sahəsi `usernames/{lower}` sənədi ilə
tutuşdurulmur (`grep -n username firestore.rules` — 20 uyğunluğun
hamısı şərh və ya `usernames` kolleksiyasının özüdür).

**EMULATOR SÜBUTU** (müvəqqəti probe, işlədikdən sonra silindi — 2/2 keçdi):

```
▶ AUDIT4 — users.username sahiblik yoxlaması
  ✔ rezervasiyası OLMAYAN username-i öz sənədinə yaza bilirmi?      (assertSucceeds)
  ✔ BAŞQASININ rezervasiyasındakı username-i öz sənədinə yaza bilirmi? (assertSucceeds)
```

**İSTİSMAR YOLU** (icra EDİLMƏDİ)
1. Hücumçu normal qeydiyyatdan keçir (`@random_123`).
2. `usernames` kolleksiyasına HEÇ NƏ yazmadan birbaşa
   `users/{öz_uid}` sənədinə `{ username: "qurban_handle" }` yazır.
3. Qayda keçir. Artıq profili və axtarış nəticəsi `@qurban_handle`
   göstərir. `peakpin.app/u/qurban_handle` deep link-i hələ də əsl
   sahibə gedir — yəni uyğunsuzluğu yalnız link vasitəsilə görmək olar.

**DÜZƏLİŞ YANAŞMASI:** İki variant.
* **(a) Qayda ilə:** `allow update`-ə şərt əlavə edin —
  `!affectedKeys().hasAny(['username']) ||
   get(/databases/$(database)/documents/usernames/$(request.resource.data.username.lower())).data.uid == request.auth.uid`.
  Ucuzdur, amma hər username yazısına bir `get()` əlavə edir.
* **(b) Tövsiyə olunan:** `username`-i `touchesLockedUserFields()`-ə
  əlavə edin və ad dəyişməsini `completeOnboarding` naxışında bir
  callable-a (`updateUsername`) köçürün — rezervasiyanın alınması,
  köhnəsinin buraxılması və profil yazısı bir tranzaksiyada. Hazırkı
  client axını onsuz da atomik deyil (`firebase_auth_repository.dart:285`
  — köhnə rezervasiyanın silinməsi `catch (_)` ilə udulur).

---

```
ID:              A4-H2
BAŞLIQ:          Sayğacların ayrılmasında kilid köhnə sahə adında qaldı —
                 məkan sahibi hər iki YENİ ictimai sayğacı özü yaza bilir
STATUS:          REGRESSION  (commit 451cbce, «separate the two counts»)
SEVERITY:        🟠 HIGH
RELEASE BLOCKER: XEYR
```

**FAYL:SƏTİR**
* `firestore.rules:1232` — `venues` update blocklist-i
* `functions/src/index.ts:2675` — `visibleCheckinCount` server yazısı
* `functions/src/index.ts:3012-3013` — `currentAudienceCount` +
  `audienceCountUpdatedAt` server yazısı
* `docs/VENUE_OCCUPANCY.md` — pozulan invariant burada sənədləşib

**HÜCUMÇU:** məkan sahibi (öz məkanı üçün; kənar istifadəçi üçün
`ownerId` yoxlaması işləyir və qoruyur).

**TƏSİR:** «Ətrafınızda N nəfər (son 15 dəqiqə)» (Canlı tab kartı +
tiker) və «Hazırda N PeakPin istifadəçisi buradadır» (məkan profili)
rəqəmləri sahib tərəfindən istənilən dəyərə qoyula bilir.
`audienceCountUpdatedAt` da açıq olduğu üçün 20 dəqiqəlik köhnəlik
qoruması da bypass olunur — saxta rəqəm daimi görünür. Nəticə: radius
daxilindəki bütün istifadəçilərə yalan sosial sübut; platformanın öz
sənədləşdirdiyi «serverdə hesablanır» zəmanətinin pozulması.

İkinci dərəcəli: sahib `visibleCheckinCount`-a nişan dəyər yazıb onun
nə vaxt sıfırlandığını izləyərək check-in hadisələrinin **vaxtını**
öyrənə bilər (kimliyi yox — `activeCheckins` və `private/counters`
bağlıdır).

**SÜBUT** — `firestore.rules:1232` (kilid siyahısının sonu):

```
'verified', 'gallery', 'activeCheckinCount', 'nameLower']);
```

`activeCheckinCount` — BACKLOG #24-ə görə **artıq istifadə edilməyən**
köhnə sahədir. Onu əvəz edən `visibleCheckinCount` və
`currentAudienceCount`/`audienceCountUpdatedAt` siyahıda yoxdur.

**EMULATOR SÜBUTU** (müvəqqəti probe, işlədikdən sonra silindi — 4/4 keçdi):

```
▶ AUDIT4 — venues update blocklist
  ✔ KÖHNƏ activeCheckinCount — sahib yaza BİLMİR                     (assertFails)
  ✔ YENİ visibleCheckinCount — sahib yaza bilir                       (assertSucceeds)
  ✔ YENİ currentAudienceCount + audienceCountUpdatedAt — sahib yaza bilir (assertSucceeds)
  ✔ kənar istifadəçi yaza BİLMİR (sahiblik yoxlaması işləyir)         (assertFails)
```

**İSTİSMAR YOLU** (icra EDİLMƏDİ)
1. Sahib məkanını yaradır və təsdiqlədir.
2. Birbaşa Firestore yazısı:
   `venues/{id}.update({ currentAudienceCount: 250, audienceCountUpdatedAt: now, visibleCheckinCount: 180 })`.
3. Radius daxilindəki hər kəsin Canlı tabında «250 nəfər ətrafda»
   görünür; profil «180 PeakPin istifadəçisi buradadır» yazır.

**DÜZƏLİŞ YANAŞMASI:** blocklist-ə üç ad əlavə edin —
`'visibleCheckinCount', 'currentAudienceCount', 'audienceCountUpdatedAt'`.
`activeCheckinCount` BACKLOG #24 icra olunana qədər qalsın. Reqressiya
testi: `tests/rules/firestore-checkin.test.ts`-ə sahibin bu üç sahəni
yaza bilmədiyini yoxlayan üç `assertFails` əlavə edin — sayğac
adları gələcəkdə yenə dəyişəcəksə, kilidin arxada qalmasını məhz belə
bir test tutar.

---

# MEDIUM

```
ID:              A4-M1
BAŞLIQ:          Çat mesajının `mediaUrl`-i İSTƏNİLƏN Firebase bucket-ını
                 qəbul edir — H-5 bu yolda tətbiq olunmayıb
STATUS:          FIX-INCOMPLETE (P0 / H-5)
SEVERITY:        🟡 MEDIUM
RELEASE BLOCKER: XEYR
FAYL:SƏTİR:      firestore.rules:1015
```

**SÜBUT** — müqayisə:

```
// firestore.rules:1015 (chats/*/messages create) — bucket YOXLANMIR
request.resource.data.mediaUrl.matches('https://firebasestorage[.]googleapis[.]com/.*')

// firestore.rules:131 (isOwnStorageUrl) — hər digər yolda BU işlədilir
url.matches('https://firebasestorage[.]googleapis[.]com/v0/b/kim-var-73ce9[.]firebasestorage[.]app/o/.*')
```

**HÜCUMÇU / TƏSİR:** hücumçu öz pulsuz Firebase layihəsini yaradır,
şəkli oraya yükləyir və çatda o URL-i göndərir. Qurbanın cihazı şəkli
çəkir; hücumçu öz bucket-ında Cloud Storage giriş loglarını aktiv
edərək qurbanın **IP** və User-Agent-ini toplayır. `firestore.rules`-un
öz şərhi (`:110-125`) məhz bunu «yaxınlıq üzərində qurulmuş tətbiq üçün
deanonimləşdirmə primitivi» adlandırır — qayda hər yerdə tətbiq
edilib, çatdan başqa. Əlavə: hücumçu sonradan baytları dəyişə bilər
(Firestore yazısı olmadan).

**DÜZƏLİŞ YANAŞMASI:** `:1015`-i `isOwnStorageUrl(request.resource.data.mediaUrl)`
ilə əvəz edin. `forwardChatMedia` (`index.ts:2133-2137`) onsuz da yolu
`CHAT_MEDIA_FOLDERS` ilə yoxlayır, yəni legitim axın pozulmur.

---

```
ID:              A4-M2
BAŞLIQ:          `previewVenueAudience` fasiləsiz radius oraculudur;
                 ön şərti pulsuz `awaiting_payment` məkandır
STATUS:          NEW (H-2-nin qalıq səthi)
SEVERITY:        🟡 MEDIUM
RELEASE BLOCKER: XEYR
```

**FAYL:SƏTİR**
* `functions/src/index.ts:1338-1421` — funksiya; **status yoxlaması yoxdur**,
  yalnız `venue.ownerId !== uid`
* `functions/src/index.ts:5585-5710` — `submitVenue`; **rate limit yoxdur**
  (A3-M1-də sadalanıb), `lat`/`lng` client-dən gəlir,
  `status: "awaiting_payment"` sənədi ÖDƏNİŞDƏN ƏVVƏL yaranır (`:5687`)
* `functions/src/geo.ts:66-73` — k-anonimlik döşəməsi (5) və radius
  clamp-i (50 km) — **hər ikisi mövcud və düzgündür**

**TƏSİR:** `radiusKm` ixtiyari müsbət **float**-dur, cavab isə
tam ədəddir. Radiusu ikili axtarışla dəyişərək hücumçu `count`-un
addım nöqtələrini tapa bilir — yəni skan edilən istifadəçilərin
məkandan **radial məsafəsini metr dəqiqliyində** öyrənir. Bu, eyni
layihədə `findNearbyUsers` üçün qəsdən qoyulmuş 100 m səbətdən
(`bucketDistanceMeters`) xeyli incədir. Üç fərqli koordinatda üç məkan
yaradaraq trilaterasiya mümkündür.

**Məhdudlaşdıran amillər (real və əhəmiyyətli):**
* Cavab **anonimdir** — kimlik qaytarılmır, yalnız say.
* k-döşəməsi 5-dən aşağı hər şeyi 0 edir, yəni ən həssas hal
  («burada 1 nəfər var») bağlıdır.
* Skan `lastSeen > now-15dəq` və `limit 200` ilə məhduddur.
* Rate limit `nearby` 10/60 s — `findNearbyUsers`/`getDiscoverCandidates`
  ilə PAYLAŞILIR (bu, düzgün qərardır).

**İSTİSMAR YOLU** (icra EDİLMƏDİ)
1. `submitVenue` çağırılır, `lat`/`lng` seçilir. Sənəd dərhal yaranır,
   ödəniş gözlənilmir.
2. `previewVenueAudience({venueId, mode:'distance', radiusKm: R})` —
   R üzərində ikili axtarış (~26 addım / 1 nəfər).
3. Üç məkanla eyni anonim şəxsin mövqeyi kəsişmədən çıxarılır.

**DÜZƏLİŞ YANAŞMASI** (üçü də ucuzdur, birlikdə edilməlidir):
* `previewVenueAudience`-də `venue.status === "approved"` tələb edin —
  funksiya sahibin abunə radiusunu seçməsi üçündür, ödənişsiz məkan
  üçün lazım deyil.
* `radiusKm`-i UI-ın öz seçicisindəki diskret dəyərlərə (allowlist)
  bağlayın — fasiləsiz float oraculunu bu tək dəyişiklik öldürür.
* `submitVenue`-ə `enforceRateLimit("submit-listing", uid, …)` əlavə
  edin (A3-M1-də onsuz da planlıdır) — hər çağırış həm də Epoint
  production API-sinə real sorğu göndərir.

---

```
ID:              A4-M3
BAŞLIQ:          Admin panelin post silməsi `_200x200` törəməsini
                 silmir — «silinmiş» şəkil token-li URL ilə oxunaqlı qalır
STATUS:          FIX-INCOMPLETE (Audit 3 / A3-H2)
SEVERITY:        🟡 MEDIUM
RELEASE BLOCKER: XEYR
FAYL:SƏTİR:      admin-panel/src/lib/actions/content.ts:37-42
```

**SÜBUT** — üç kod bazasından ikisi düzgündür:

```ts
// functions/src/index.ts:1979-1992 — DÜZGÜN
const derivative = resizedVariantPath(path);
if (derivative) await deleteStorageObject(derivative);

// admin-panel/src/lib/user-account-deletion.ts:311-318 — DÜZGÜN
const derivative = resizedVariantPath(path);

// admin-panel/src/lib/actions/content.ts:37-42 — TÖRƏMƏ SİLİNMİR
await getAdminStorage().bucket().file(storagePathFromUrl(url)).delete();
```

`REGENERATE_TOKEN=false` olduğuna görə törəmə orijinalın token-ini
paylaşır (`chat-media.ts:128-150`), yəni URL-i saxlamış istənilən kəs
(Firebase sessiyası olmadan) moderasiya tərəfindən silinmiş şəkli bir
yol seqmentini dəyişməklə oxumağa davam edir.

**DÜZƏLİŞ YANAŞMASI:** A4-C1 düzəlişi ilə eyni funksiyada —
`resizedVariantPath` (`admin-panel/src/lib/chat-media-path.ts` onsuz da
import edilib) çağırılsın.

---

```
ID:              A4-M4
BAŞLIQ:          `getDiscoverCandidates` — bir VIP hesab saatda ~600k
                 Firestore oxusu yarada bilir
STATUS:          PREVIOUSLY-KNOWN (funksiyanın öz şərhində etiraf edilib),
                 burada rəqəmlə kəmiyyətləndirilir
SEVERITY:        🟡 MEDIUM (maliyyə, icazə deyil)
RELEASE BLOCKER: XEYR
FAYL:SƏTİR:      functions/src/index.ts:1089-1106, :890-891
```

`world` rejimi 500 `users` + hər biri üçün bir `private/data` = ~1000
oxu/çağırış. `nearby` scope-u 10/60 s → 600 çağırış/saat →
**~600 000 oxu/saat**, hesab başına. Ön şərt: bir aylıq VIP abunəsi
(15 AZN). Ödəyən tərəf platformadır.

Qoruma **mövcuddur və düzgündür** (limit paylaşılan scope-dadır ki,
üç endpoint arasında yayılmasın) — çatışmayan şey mütləq gündəlik
tavandır.

**DÜZƏLİŞ YANAŞMASI:** `nearby` scope-una ikinci, uzun pəncərəli limit
əlavə edin (məs. 2000/24 saat). BACKLOG #23-ün aqreqat-sənəd variantı
eyni problemin memarlıq həllidir.

---

# LOW

```
ID:              A4-L1
BAŞLIQ:          KYC sübutu istifadəçi tərəfindən ÜZƏRİNƏ YAZILA bilir
                 (silinə bilmir — sənəd yalnız silmədən danışır)
STATUS:          NEW
SEVERITY:        🔵 LOW
RELEASE BLOCKER: XEYR
FAYL:SƏTİR:      storage.rules:292-295
```

```
allow write: if request.auth != null && request.auth.uid == userId && …
```

Storage-da `write` = `create` + `update` + `delete`. Ölçü şərti
`delete`-i bloklayır (bu, qəsdəndir və şərhdə izah olunub), amma
`update` işləyir — istifadəçi baxış gözləyən sənədin şəklini
dəyişdirə bilər. Şərh «KYC evidence must not disappear from under a
moderator» deyir; faktiki olaraq yox olmur, amma **əvəzlənə bilir**.
Təsir audit izinin zəifləməsidir, icazə artımı deyil.

**DÜZƏLİŞ YANAŞMASI:** `allow create:` (yalnız) yazın — `{requestId}`
onsuz da hər təqdimatı ayırır, yəni yenidən göndərmə yeni yola düşür.

---

# BÖLMƏ 7 — REGRESSİYA YOXLAMASI

| ID | Nəticə | Sübut |
|---|---|---|
| **C-1** Storage arbitrary deletion | **FIX VERIFIED** (`functions/`) · **FIX-INCOMPLETE** (admin panel → **A4-C1**) | `functions/src/chat-media.ts:75-94` yolu server dəyərlərindən qurur; `index.ts:2038-2054` şərhi yeganə qalan çağırışın `forwardChatMedia` olduğunu deyir və `:2133-2137` onu `CHAT_MEDIA_FOLDERS` + iştirakçılıq ilə yoxlayır. **Amma** `admin-panel/.../content.ts:48` eyni köhnə naxışı saxlayır |
| **C-2** `emergencyToken` | **FIX VERIFIED** | İcra edilən kod yoxdur; yeganə uyğunluq şərhdir — `admin-panel/src/app/login/page.tsx:14` |
| **C-3** onboarding bypass | **FIX VERIFIED** | `firestore.rules:339` `allow create: if false`; `functions/src/index.ts:598-600` server-side 18+ yoxlaması; `:642` email provayderi üçün `email_verified` tələbi |
| **H-1** trilaterasiya | **FIX VERIFIED** | `geo.ts:53-58` `bucketDistanceMeters` (döşəmə 100 m), `geo.ts:84-101` + `index.ts:981-1008` `assertPlausibleMovement` (rədd edilən probe də yazılır — bayat mənşə saxlamaq mümkün deyil). Qalıq səth ayrı endpoint-dədir → **A4-M2** |
| **H-2** venue audience oracle | **FIX VERIFIED** | `index.ts:1363-1367` mode allowlist; `:1398-1401` mərkəz məkanın öz koordinatıdır (client-in `lat`/`lng`-i **ignore edilir**); `:1408` `clampAudienceRadiusKm`; `:1421` `reportableAudienceCount` |
| **H-3** chat participants | **FIX VERIFIED** | `firestore.rules:885-887` — `participants` və `initiatorId` update-də pinlənib |
| **H-6** username enumeration | **FIX VERIFIED** | `firestore.rules:713` `allow list: if false`; `get` qəsdən açıq (ACCEPTED_RISKS) |
| **H-7** moderator refund | **FIX VERIFIED** | `admin-panel/src/lib/actions/payments.ts:75-78` — `managePayments`; matrisdə `moderator` üçün `false` (`permissions.ts:55`) |
| **H-8** `/api/health` | **FIX VERIFIED** | `admin-panel/src/app/api/` altında yalnız `auth/session/route.ts` var — matcher istisnasında başqa açıq endpoint qalmayıb |
| **H-9** `birthDate` | **FIX VERIFIED** | Hər iki yerdə kilidli: `firestore.rules:322` (public sənəd) və `:279` `serverOnlyFields()` (private sənəd) |
| **A3-H1** Storage delete (7 yol) | **FIX VERIFIED — emulator** | `storage.rules:72,150,168,186,204,247,265` — hər yeddi sahib-yolunda ayrıca `allow delete`. Test paketi: 14/14 keçdi (`A3-H1 — sahib-əsaslı yollarda silmə`) |
| **A3-H2** `_200x200` törəmələr | **FIX VERIFIED** (`functions/`, `user-account-deletion.ts`) · **FIX-INCOMPLETE** (admin panel `content.ts` → **A4-M3**) | `index.ts:1979-1992`; `user-account-deletion.ts:311-318` |
| **A3-M2** `audienceHistory` | **FIX VERIFIED** | `firestore.rules:1477-1478` — `allow read: if false; allow write: if false` |

---

# BÖLMƏ 8 — FINAL ATTACK MATRIX

| # | ATTACK | RESULT | SEVERITY | EVIDENCE | FIX NEEDED |
|---|---|---|---|---|---|
| 1 | Account takeover | **PASS** | — | `index.ts:642` (email provayderi üçün `email_verified` məcburi) — doğrulanmamış parol hesabı `users/{uid}` yarada bilmir, yəni Console-un «link same email» ayarı ilə ələ keçirmə yolu bağlıdır. `session.ts:34-36` fail-closed rol | Xeyr |
| 2 | Authentication bypass | **PASS** | — | 40 callable-ın hamısında `request.auth?.uid` yoxlaması; `firestore.rules:2178` default-deny; admin panel `proxy.ts:57` + `server.ts:32` (`checkRevoked: true`) ikiqat sədd | Xeyr |
| 3 | User A → User B data | **PASS** | — | `users` `allow list: if false` (`:269`); `private/{document}` yalnız sahib (`:292`); `payments`/`identityVerifications`/`pinboxOrders` sahib-oxumalı; `notifications` `create: if false`; `nearbyProbes`/`adminNotifications`/`moderationLogs`/`admins`/`bannedUsers`/`iapSubscriptions`/`venues/*/private` tam bağlı | Xeyr |
| 4 | User → Admin | **PASS** | — | Authorization YALNIZ custom claim-dən (`session.ts:34`); `admins/{uid}` `read, write: if false` (`:2156`); `addAdmin`/`changeAdminRole`/`removeAdmin` üçün `manageAdmins` | Xeyr |
| 5 | User → Moderator | **PASS** | — | Eyni mexanizm; 24 səhifənin hamısında səhifə-səviyyəli `hasPermission`, 15 action faylının hamısında action-səviyyəli yoxlama (yoxlanıldı, istisna yoxdur) | Xeyr |
| 6 | Firebase Rules bypass | **PASS** | — | `tests/rules` 428/428; `match /{document=**} { allow read, write: if false }` (`:2178-2180`) | Xeyr |
| 7 | Sensitive field manipulation | **FAIL** | 🟠 HIGH | `username` (**A4-H1**), `visibleCheckinCount`/`currentAudienceCount`/`audienceCountUpdatedAt` (**A4-H2**). Qalan bütün siyahı kilidlidir: `premium`, `premiumExpiresAt`, `identityVerified`, `birthDate`, `reportedCount`, `role`, `banned`, `boostedUntil`, `subscriptionRenewsAt`, `status`, `ownerId`, `blockedByUsers`, `fcmTokens`, `knownDeviceSignatures`, `consent`, `email`, `phoneNumber`, `activeCheckinVenueId`, `hiddenFor` (başqasının uid-i), `lastMessageOverride`, `stockRemaining`, `offerAcceptedVersion` | **BƏLİ** |
| 8 | Fake payment | **PASS** | — | `epoint.ts:105-111` — `sha1(privateKey+data+privateKey)`, `timingSafeEqual`, uzunluq əvvəl yoxlanır. İmzasız/yanlış imzalı sorğu 400 alır (`index.ts:8198-8202`) | Xeyr |
| 9 | Payment replay | **PASS** | — | `index.ts:8256` — idempotentlik yoxlaması TRANZAKSİYANIN İÇİNDƏDİR; `status !== "pending" && !== "superseded"` → çıxış. `superseded` yeni vektor yaratmır: hər `payments` sənədi bir Epoint order-idir, hər ödəniş öz entitlement-ini alır. `isCancellableOnListingDelete` (`payment-targets.ts:46`) yalnız `pending`-i ləğv edir və qalan hallar `orphan_target` qapısına düşür (`index.ts:7570-7590`) | Xeyr |
| 10 | Amount manipulation | **PASS** | — | Məbləğ serverdə hesablanır (`venue-fees.ts`, `BOOST_FEE_BY_HOURS` `:5847`), webhook məbləği saxlanılan dəyərlə tutuşdurulur (`index.ts:7469-7473`) → uyğunsuzluqda `amount_mismatch`, entitlement verilmir. **Valyuta yoxlaması ölüdür** — ACCEPTED_RISKS / PAY-4, yeni tapıntı deyil | Xeyr |
| 11 | VIP / Boost bypass | **PASS** | — | `premium` rules-da kilidli, yalnız `grantPremium` (`:8549`); sandbox qəbzi `config/iapTesters`-ə bağlıdır (`:8702-8715`); `claimIapSubscriptionOwnership` (`:8585`) tranzaksiyalı, başqa canlı hesaba bağlı qəbzi rədd edir; `boostedUntil` `offers` blocklist-ində (`:1591`) | Xeyr |
| 12 | Location / radius bypass | **QISMƏN** | 🟡 MEDIUM | Ghost Mode, görünmə radiusu, bloklama, ban süzgəci və k-döşəməsi **hamısı serverdədir** (`index.ts:1264-1279`, `:1417`, `:3012`). Qalıq: `previewVenueAudience` fasiləsiz radius oraculu → **A4-M2** | Bax A4-M2 |
| 13 | Storage arbitrary deletion | **FAIL** | 🔴 CRITICAL | **A4-C1** — `admin-panel/src/lib/actions/content.ts:48` | **BƏLİ** |
| 14 | Chat IDOR | **PASS** | — | `chats` oxu iştirakçı-only (`:806`); `participants`/`initiatorId` pinlənib (`:885-887`); `hiddenFor` yalnız öz açarı (`:894-897`); `lastMessageOverride` **heç bir client budağından yazıla bilmir** (`:900-916` — hər üç budaqda ya `hasAny` qadağası, ya `hasOnly(['status'])`); `deletedFor` yalnız öz uid-ini əlavə edə bilir, başqasınınkını sil bilməz (`:1023-1025`); mesaj silmə `senderId`-ə bağlı (`:1027`); `hardDeleteFullyHiddenChat` (`:6143`) hər iki tərəfin gizlətməsini tələb edir. Qalıq: media URL bucket-i (**A4-M1**) | Bax A4-M1 |
| 15 | Business ownership bypass | **PASS** | — | `updateVenue`/`updateOffer`/`updatePinBox` və hər üç `resubmit*` tranzaksiya daxilində `ownerId !== uid` yoxlayır (`:4483`, `:4636`, `:4766`, `:4569`, `:4701`, `:4825`); `redeemPinBoxOrder` (`:6925`) və `previewVenueAudience` (`:1355`) də sahiblik tələb edir; `venues.ownerId` immutable (`:1230`); `reservePinBoxOrder` (`:6737-6741`) silinmiş/təsdiqlənməmiş məkanda satışı bloklayır | Xeyr |
| 16 | Waitlist telefon nömrəsinin sızması | **PASS** | — | `firestore.rules:1495-1497` + `firestore-waitlist-privacy.test.ts` (paketdə keçdi) — növbədəki A növbədəki B-nin nömrəsini nə `get`, nə `list`, nə süzülmüş sorğu ilə görə bilmir | Xeyr |
| 17 | Secret leakage | **PASS** | — | Repo və **git tarixçəsində** service account, private key, Epoint/webhook/OAuth secret **yoxdur**. Yeganə tapılan `AIza…` dəyərləri publik Firebase Web API açarlarıdır (`google-services.json`, `GoogleService-Info.plist`, `firebase_options.dart`, `apphosting.yaml`) — zəiflik sayılmır. Epoint və Google Play açarları `defineSecret` ilə Secret Manager-dədir | Xeyr |

---

# QƏBUL EDİLMİŞ RİSKLƏRİN YENİDƏN QİYMƏTLƏNDİRİLMƏSİ

| Maddə | Qərar hələ də əsaslıdırmı | Qeyd |
|---|---|---|
| `usernames/{id}.get` açıqdır | **Bəli** | `list` bağlıdır, `get` bir bilinən handle-ı açır. **AMMA** bu maddə A4-H1 işığında yenidən yazılmalıdır: sənəd `usernames`-i «kimliyin doğruluq mənbəyi» kimi təqdim edir, halbuki `users.username` ona bağlı deyil |
| Banlanmış hesabın 16 yazı yolu | **Bəli** | `isActiveUser()` xərci real (2 oxu/yazı). `reviews`, `follows`, `chats`, `activeCheckins` bu turda bağlanıb — sənəd faktiki vəziyyəti düzgün əks etdirir |
| Ban sonrası ~1 saatlıq oxu pəncərəsi | **Bəli** | Firebase Auth-un texniki məhdudiyyəti. `findNearbyUsers`/`getDiscoverCandidates` görünürlük süzgəcləri (`banned !== true`) bu pəncərənin ən pis nəticəsini onsuz da bağlayıb |
| Storage-da per-user kvota yoxdur | **Bəli** | `forwardChatMedia` amplifikasiyası limitlə bağlanıb (`:2120`, 30/600s). Kvotanın özü Storage Rules-da mümkün deyil |
| Magic-byte MIME yoxlaması yoxdur | **Bəli** | Elan edilən tip allowlist-i BACKLOG #12 kimi **tətbiq edilib** (`storage.rules:36-45`) və emulator testi ilə örtülüb (SVG rədd edilir, 4 test). Qalan hissə həqiqətən yalnız Storage trigger-i ilə həll olunur |
| PAY-4 valyuta yoxlaması ölüdür | **Bəli** | Real payload açarları sənəddə sadalanıb, `amount` yoxlaması **canlıdır** (`index.ts:7469`). Şərhdə «CONFIRMED DEAD» işarəsi var — kimsə onu işlək saymır |
| Epoint checkout ləğv API-si yoxdur | **Bəli** | `superseded` + `orphan_target` cütü boşluğun real nəticəsini bağlayır. Audit 4-də ayrıca yoxlandı, replay vektoru yaratmır |
| AUTH-8a — parol min. 6 simvol | **Bəli** | Buraxılışı bloklamır |
| AUTH-8b — real MFA yoxdur | **Bəli** | Admin panel üçün daha kritikdir (5 günlük sessiya cookie-si), amma admin sayı kiçikdir və `revokeRefreshTokens` + `checkRevoked` dərhal təsir edir |
| B4 — `calls` sənədləri silinmir | **Bəli** | Yalnız SDP mətni, oxu iştirakçılarla məhdud |
| C1a — ProGuard/R8 | **ARTIQ AKTUAL DEYİL** | `android/app/build.gradle.kts:87,90` — `isMinifyEnabled = true`, `isShrinkResources = true`. Keep qaydaları geniş (`-keep class com.google.firebase.** { *; }`) — obfuskasiya faydasını azaldır, amma heç bir sirr açmır. **Cihazda test hələ edilməyib** — bu, təhlükəsizlik deyil, buraxılış keyfiyyəti riskidir |
| C1b — root/jailbreak, TLS pinning | **Bəli** | Mağaza tələb etmir |
| C3 — Node 20 EOL | **Bəli, amma vaxt daralır** | BACKLOG #1, 2026-10-31 həddi |
| D4 — `reviews` miqrasiyası | **Bəli** | `list` BAĞLANIB (`:1247`) və `listVenueReviews` callable-ı ilə əvəzlənib — məxfilik yarımı həll olunub. Anonimləşdirmə miqrasiyası açıq qalır |
| E1 — float→qəpik | **Bəli** | `amount` yoxlaması 0.005 tolerantlıqla işləyir; real ödənişdə problem çıxmayıb |

**Yeni əlavə edilməli maddə yoxdur** — A4 tapıntılarının hamısı
düzəldilə biləndir, qəbul edilməli deyil.

---

# BÖLMƏ 2-nin MƏLUM MADDƏLƏRİ — CARİ VƏZİYYƏT

| Məlum vəziyyət | Audit 4-də təsdiqlənən |
|---|---|
| App Check 40 funksiyada `false` | Doğru. **Real hücum səthi:** App Check yoxluğu heç bir icazə boşluğu açmır — hər callable `request.auth` + `assertActiveUser` + (35/40-da) rate limit ilə qorunur. Faktiki nəticəsi budur ki, botun **hesab açması** ucuzlaşır; hər hesab isə yenə də öz rate limit sayğacına bağlıdır. Ən çox təsirlənən: A4-M4 (VIP oxu xərci) və `submitVenue` (limit yoxdur) |
| iOS launch olunmur | Təsdiqləndi; iOS-a xas tapıntı verilmir |
| R8 aktiv, cihazda test edilməyib | Təsdiqləndi (`build.gradle.kts:87-93`) |
| Node 20 EOL | Təsdiqləndi (`functions/package.json`) |
| 13 callable-da rate limit yoxdur | **12-yə düşüb** — `appStoreServerNotifications` artıq limitlidir (`index.ts:8799`, `store-notify` 120/60). Qalan siyahı dəyişməyib |
| `admin.peakpin.app` Vercel-dədir | Dəyişməyib (BACKLOG #17) |
| `activeCheckinCount` qəsdən saxlanılır | Təsdiqləndi — **və məhz buna görə A4-H2 baş verib**: kilid köhnə adda qalıb |
| Valyuta yoxlaması ölüdür | Təsdiqləndi, `amount` yoxlaması canlıdır |

---

# BÖLMƏ 3.1 — ÜÇ SAYĞACIN AYRIMI: SUAL-CAVAB

| Sual | Cavab | Sübut |
|---|---|---|
| `private/counters` və `audienceHistory` həqiqətən heç kimə açıq deyilmi — sahib də daxil? | **Bəli, tam bağlıdır** | `firestore.rules:1554-1556` və `:1463-1480` — hər ikisi `allow read, write: if false` |
| k-anonimlik həddi (5) hər iki sayğacda **serverdə** tətbiq olunurmu? | **Bəli, üç yerin hamısında** | `geo.ts:66-68` → `index.ts:1421` (preview), `:2675` (check-in), `:3012` (audience). Client-də heç bir yerdə tətbiq edilmir |
| `bumpActiveCheckinCount` hər iki sahəni eyni tranzaksiyada yazırmı? | **Bəli, drift mümkün deyil** | `index.ts:2666-2679` — `runTransaction` daxilində `tx.set(countersRef…)` + `tx.update(venueRef…)` |
| `currentAudienceCount` köhnəlik qoruması (20 dəq) bypass edilə bilərmi? | **BƏLİ** | Sahib `audienceCountUpdatedAt`-ı özü yaza bilir → **A4-H2** |
| Ghost Mode başqa yerdə sızmırmı? | **Xeyr** | `computeAudienceCount` və `previewVenueAudience` (`:1387`) hər ikisi `ghostModeEnabled !== true` süzgəcini tətbiq edir; `findNearbyUsers` (`:1279`) və `getDiscoverCandidates` də. Check-in-də qəsdən tətbiq edilmir və 5-lik döşəmə «1 nəfər» halını bağlayır |
| Üç sayğac harasa yenidən qarışıbmı? İki mühafizə testi kifayətdirmi? | Qarışmayıb (`audience-source.test.ts` 4 test keçdi) — **amma testlər OXU tərəfini yoxlayır, YAZMA tərəfini yox**. A4-H2 məhz bu boşluqdan keçdi | `tests/rules/audience-source.test.ts` |

---

# NƏ İŞLƏYİR — ƏSAS TEST NƏTİCƏLƏRİ

«Problem tapmadım» kifayət etmədiyi üçün, konkret olaraq nə
yoxlanıldı və nə keçdi:

* **Qayda paketi:** `bash tests/rules/run.sh` → **428/428 keçdi**,
  0 uğursuz, 24.9 s. Firestore + Storage emulator, `demo-` layihə.
* **A3-H1 (Storage silmə):** 14 test — yeddi sahib-yolunun hər birində
  «sahib silir» ✔ və «özgə silə bilmir» ✔; `identity_verifications`
  üçün «sahib silə bilmir» ✔ (qəsdən).
* **SVG / content-type allowlist:** 4 test — SVG profil, məkan, story,
  post və çat mediasında rədd edilir ✔; real formatlar qəbul edilir ✔.
* **Waitlist məxfiliyi:** növbədəki istifadəçi başqasının nömrəsini
  oxuya bilmir ✔ (get, list və süzülmüş sorğu — üçü də).
* **RBAC:** `rbac-permissions.test.ts` — `analyst` PII görmür ✔,
  gəlir bloku `moderator`/`support`-dan gizlidir ✔.
* **Paritet cütləri:** `venue-fees` (8 test), `venue-status` (5 test),
  `phone-normalize`, `chat-media-path`, `payment-targets`, `geo` —
  hamısı keçdi; iki kod bazası arasında fərq yoxdur.
* **Öz probe-um:** `venues` sahiblik yoxlaması işləyir (kənar istifadəçi
  rədd edildi ✔), köhnə `activeCheckinCount` kilidlidir ✔ — yəni
  A4-H2 kilid mexanizminin sınması deyil, siyahının natamamlığıdır.

---

# TÖVSİYƏ OLUNAN DÜZƏLİŞ SIRASI

| Sıra | ID | İş həcmi | Buraxılış |
|---|---|---|---|
| 1 | **A4-C1** + **A4-M3** (eyni funksiya) | ~1 saat | **BLOKLAYIR** |
| 2 | **A4-H2** (rules blocklist + 3 test) | ~30 dəq | Eyni deploy-da |
| 3 | **A4-M1** (rules, bir sətir) | ~15 dəq | Eyni deploy-da |
| 4 | **A4-H1** (callable + rules kilidi) | ~3-4 saat | Launch-dan sonra ilk həftə |
| 5 | **A4-M2** (status yoxlaması + radius allowlist + submitVenue limiti) | ~2 saat | Launch-dan sonra ilk həftə |
| 6 | **A4-M4** (gündəlik tavan) | ~1 saat | BACKLOG |
| 7 | **A4-L1** (`write` → `create`) | ~10 dəq | BACKLOG |

Sıra 1-3 bir rules + bir Vercel deploy-udur (~2 saat) və ondan sonra
qərar **🟡 READY AFTER FIXES → 🟢** olur.
