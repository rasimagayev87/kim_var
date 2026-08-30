# Öz hesabatlarımın doğrulanması — 2026-08-30

**Səbəb:** rate-limit şişirtməsi təkbaşına bir hadisə deyilsə, bunu
mağazadan əvvəl bilmək lazımdır. Bu sənəd bu gün verdiyim HƏR
yoxlanıla bilən iddianı kodla tutuşdurur.

**Mənbələr:** sessiya transkripti (`a1ccc03a….jsonl`, 5.7 MB — 156
mesaj blokum çıxarıldı), `security-audit-2-2026-08-30.md`,
`ACCEPTED_RISKS.md`, `BACKLOG.md`, 2026-08-28-dən bəri 11 commit.
**Metod:** yalnız oxu. Kod dəyişdirilmədi.

**Təsnifat:**
**(a)** qoruma iddia edilib, YOXDUR · **(b)** qoruma var, rəqəm/ad
səhvdir · **(c)** qoruma var, hesabat düzdür (mənim yoxlama üsulum
səhv idi) · **(d)** qismən tətbiq — bir yerdə var, qardaş yerdə yox.

---

## Yekun

| Kateqoriya | Say | Buraxılışı bloklayır |
|---|---|---|
| (a) tam yoxdur | **2** | 0 |
| (b) mühasibat səhvi | 3 | 0 |
| (c) düzgün, mənim səhvim | 3 | — |
| (d) qismən tətbiq | **6** | **2** |

**Yaxşı xəbər:** C-1, C-2, C-3, H-2, H-3, H-4, H-5, H-6, H-7, H-8,
H-9, Bölmə 3(c)-nin hər üç blocklist genişlənməsi, A-2, A-3, A-4,
F-1…F-5 — **hamısı kodda faktiki mövcuddur**, file:line ilə
təsdiqləndi. Bağlandığını dediyim heç bir CRITICAL və ya HIGH
uydurma deyil.

**Pis xəbər:** iki (d) buraxılışı bloklayır (hər ikisi artıq Audit
3-dən tanışdır), və "hər düzəliş üçün test" iddiam iki HIGH üçün
doğru deyil.

---

# (a) Qoruma iddia edilib, YOXDUR

## a1 — Beş callable-da rate limit heç vaxt yazılmayıb

Faza 7 hesabatımda sadaladığım limitlərdən beşi mövcud deyil. Git
tarixçəsi göstərir ki, bu scope-lar **heç bir commit-də olmayıb** —
merge-də itməyib:

```
git log --all -S'"kyc"'            → 0    git log --all -S'"qr"'             → 0
git log --all -S'"delete-account"' → 0    git log --all -S'"submit-venue"'   → 0
git log --all -S'"store-notify"'   → 0
```

Faktiki vəziyyət: 40 funksiyadan 26-sında `enforceRateLimit` var,
**14-ündə yoxdur**. Tam siyahı `security-audit-3-2026-08-30.md`
A3-M1-dədir.

**Ciddilik:** `appStoreServerNotifications` (autentifikasiyasız
public HTTP, hər sorğuda iki JWS doğrulaması) 🟠 **HIGH**; qalan 13
🟡 MEDIUM. **Buraxılışı bloklamır** — heç biri icazə boşluğu deyil,
hamısı sui-istifadə/xərc səthidir.

## a2 — "Hər düzəliş üçün test" iddiası H-1 və H-2 üçün doğru deyil

Dəfələrlə "hər düzəliş üçün regressiya testi" dedim. Faktiki:

| Düzəliş | Test faylı | Vəziyyət |
|---|---|---|
| C-1 | `firestore-p0-c1.test.ts` + `chat-media-path.test.ts` (21 test) | ✅ |
| C-3, H-3, H-4, H-5, H-6, H-9 | hər biri üçün ayrıca fayl | ✅ |
| Bölmə 3(c) | `firestore-p0-blocklists.test.ts` | ✅ |
| C-2, H-8 | kodun silinməsi — canlı `curl` ilə təsdiq | ✅ (test yox, amma sübut var) |
| **H-1** (`bucketDistanceMeters`, `assertPlausibleMovement`) | **yoxdur** | ❌ |
| **H-2** (k-anonimlik 5, radius clamp 50 km, mode allowlist) | **yoxdur** | ❌ |

Yoxlama:
```
grep -rl "bucketDistanceMeters|assertPlausibleMovement|MIN_REPORTABLE|MAX_RADIUS" tests/ test/
→ heç bir test faylı
```

Kök səbəb d6-dadır: `functions/`-un **ümumiyyətlə test infrastrukturu
yoxdur** (`package.json`-da `test` skripti yoxdur). C-1 və telefon
normalizatoru üçün məntiqi saf modula (`chat-media.ts`, `phone.ts`)
çıxardım və beləcə test edilə bildi; H-1/H-2 üçün eyni şeyi
etmədim — onlar 8674 sətirlik `index.ts`-in içində qaldı.

**Ciddilik:** 🟡 MEDIUM. Düzəlişlərin özü **mövcuddur** (aşağıda
təsdiqlənir) — çatışmayan şey gələcək redaktənin onları səssizcə
sındırmasının qarşısını alan qorumadır. K-anonimlik həddi məhz belə
səssizcə itə bilən növ koddur. **Buraxılışı bloklamır.**

---

# (b) Qoruma var, rəqəm/ad səhvdir

| # | İddia | Faktiki | Qeyd |
|---|---|---|---|
| b1 | "Rate limit 12 → **27** nöqtə" | **26** çağırış nöqtəsi | Bir ədəd |
| b2 | `forwardChatMedia` → `forward-copy` **10/3600s** | `forward-chat-media` **30/600s** | Limit var, adı və rəqəmi səhv yazmışam |
| b3 | "`assertActiveUser` tətbiq edilən **21** callable" | **35** callable | Az göstərmişəm — təhlükəsiz istiqamətdə səhv |

Heç biri boşluq yaratmır.

---

# (c) Qoruma var, hesabat düzdür — mənim yoxlama üsulum səhv idi

* **c1** — `deleteStorageObjectByUrl` və `emergencyToken` sətirləri
  hələ də `grep`-də görünür, amma **yalnız şərhlərdə**
  (`index.ts:1931,1971,6004`; `login/page.tsx:14`;
  `revoke-admin-sessions.ts:4`) — silinmənin nə üçün edildiyini
  sənədləşdirirlər. İcra edilən kod yoxdur. **C-1 və C-2 həqiqətən
  bağlıdır.**
* **c2** — `isOwnStorageUrl` üçün "create **və** update" dedim.
  Faktiki: `posts`/`stories`/`pinboxes` yalnız `create`-də
  yoxlanır — **amma boşluq yoxdur**, çünki `stories` `allow update:
  if false`, `posts` update-i `hasOnly(['caption'])`-lə
  məhdudlaşır, `pinboxes.imageUrl` update blocklist-indədir və
  redaktə `updatePinBox`-dan (`assertOwnStorageUrl`) keçir.
  `venueEvents` həqiqətən hər ikisinə malikdir, `users.photoUrl`
  isə yalnız update-ə — çünki `users` `allow create: if false`.
  **Beş sahənin hamısı hər client-yazılabilir yolda qorunur.**
* **c3** — sizin verdiyiniz iki (d) nümunəsi **artıq bağlıdır**:
  `offers` blocklist-ində `venueId` var (`firestore.rules:1591`) və
  `chats` `participants`+`initiatorId`-i pinləyir (`:885-887`),
  `calls` kimi (`:1072-1073`). Çox güman remediasiyadan əvvəlki
  vəziyyəti xatırlayırsınız.

---

# (d) Qismən tətbiq — sizin dediyiniz naxış

Bu, doğrudan da bu günün ən çox təkrarlanan naxışıdır. Altısını
tapdım.

## d1 — Storage `allow delete`: 3 yol düzgün, **7 yol yanlış** 🔴 BLOKLAYIR

`chat_photos`/`chat_videos`/`chat_audio` `allow create` +
ayrıca `allow delete` yazır. Qalan sahib-əsaslı yollar `allow write`
yazır və şərtdə `request.resource.size` var; DELETE-də
`request.resource` null olduğu üçün **silmə rədd edilir**.

| Yol | sətir |
|---|---|
| `/profile_photos/{userId}/{fileName}` | `storage.rules:57` |
| `/event_covers/{ownerUid}/{fileName}` | `:130` |
| `/venue_photos/{ownerUid}/{fileName}` | `:143` |
| `/offer_photos/{ownerUid}/{fileName}` | `:156` |
| `/pinbox_photos/{ownerUid}/{fileName}` | `:169` |
| `/stories/{userId}/{fileName}` | `:205` |
| `/posts/{userId}/{fileName}` | `:218` |
| `/identity_verifications/…` | `:239` — **bu qəsdəndir**, KYC şəkilləri istifadəçi tərəfindən silinməməlidir; server `cleanupExpiredIdentityVerificationImages` ilə süpürür. Yalnız açıq şəkilə salınmalıdır |

Yəni **7 yol düzəlməlidir**, biri sənədləşdirilməlidir.
= Audit 3 / A3-H1, emulator-da sübut edilib.

## d2 — `_200x200` törəmələr: prefiks silmələri tutur, dəqiq yol silmələri tutmur 🔴 BLOKLAYIR

`deleteStoragePrefix(...)` (hesab silinməsi) törəməni də silir ✅.
`deleteStorageFile(dəqiq yol)` silmir ❌ — və məhz çat mediası
(C-1/H-4-ün bütün mövzusu), `venue_photos/{id}.jpg`,
`offer_photos/{id}.jpg` bu yolla silinir.
= Audit 3 / A3-H2.

## d3 — `assertActiveUser`: 35/40, çatışmayanı isə pul xərcləyəndir 🟡

| Funksiya | Qiymət |
|---|---|
| `completeOnboarding`, `recordConsent` | ✅ qəsdən — istifadəçi sənədi hələ yoxdur |
| `epointWebhook`, `appStoreServerNotifications` | ✅ qəsdən — server-server, istifadəçi konteksti yoxdur |
| **`getTurnCredentials`** | ❌ **boşluq** |

`getTurnCredentials`-in öz şərhi deyir: *"a direct billing surface on
the project's Cloudflare account"*. Banlanmış istifadəçinin ID
token-i ~1 saat etibarlı qalır (`ACCEPTED_RISKS.md`-də sənədləşib),
`setUserBanned` `revokeRefreshTokens` çağırsa da `onCall`
`checkRevoked` etmir. Yəni banlanmış hesab bir saat ərzində
30/600s tezliyi ilə ödənişli TURN kreditləri istehsal edə bilər.

**Ciddilik:** 🟡 MEDIUM (xərc, icazə deyil). Buraxılışı bloklamır,
amma bir sətirlik düzəlişdir.

## d4 — Rules-da `isActiveUser()`: 8 create qorunur, ~10 qorunmur, `ACCEPTED_RISKS` yalnız 3-ünü adlandırır 🟡

Qorunan: `chats/*/messages`, `calls`, `posts`, `stories`,
`posts/*/comments`, `reports`, `eventReports`, `reviewReports`.

`ACCEPTED_RISKS.md` "banlanmış istifadəçi yarada bilir" deyə
**yalnız** `pinboxes`, `venueEvents`, `supportMessages` adlandırır.
Faktiki olaraq client-yazılabilir və qorunmayan digərləri:

| Kolleksiya | Təsir |
|---|---|
| **`reviews`** (`:1273`) | Banlanmış hesab **ictimai rəy** yaza bilir → məkanın reytinqinə təsir. `hasVerifiedVisit()` tələbi məhdudlaşdırır (yeni ziyarət uydura bilmir), amma köhnə ziyarəti olan banlanmış hesab yaza bilir. Ən yüksək təsirli qorunmayan hal |
| `venues/*/activeCheckins` | Məkanın canlı sayına və `audienceHistory`-yə qidalanır |
| `follows`, `profileViews` | Qurbanın bildirişlərində/profilində görünür — təqib vektoru |
| `chats` (sənədin özü) | Boş söhbət yarada bilir; mesaj göndərə bilmir |
| `likes`, `views`, `redemptions`, `reposts` | Səs-küy |

**Ciddilik:** 🟡 MEDIUM. `firestore.rules`-un öz şərhi bunu etiraf
edir (*"Not every collection a banned user could still write to is
gated this way"*), amma `ACCEPTED_RISKS.md` natamamdır — sənəd
oxuyan adam `reviews`-in açıq olduğunu bilməz. **Buraxılışı
bloklamır**, lakin ən azı sənəd düzəldilməlidir.

## d5 — `list` bağlanması: 3 bağlı, 3 açıq 🟡

Bağlanıb: `reviews` (Audit 2), `usernames` (H-6), `activeCheckins`
(əvvəlki tur). Açıq qalıb: `venues/*/likes`, `offers/*/redemptions`,
`venues/*/audienceHistory` — heç biri client tərəfindən
siyahılanmır. = Audit 3 / A3-M2, A3-M3.

## d6 — Test edilə bilən saf modula çıxarma: 2 hal edilib, 2 hal edilməyib 🟡

`chat-media.ts` (C-1) və `phone.ts` — çıxarıldı, test edildi.
`bucketDistanceMeters`/`assertPlausibleMovement` (H-1) və
`previewVenueAudience`-in k-anonimlik/clamp məntiqi (H-2) —
`index.ts`-də qaldı, test edilmədi. a2-nin kök səbəbi budur.

---

# Prioritet

| Sıra | Maddə | Ciddilik | Buraxılış |
|---|---|---|---|
| 1 | **d1** — Storage `allow delete` (7 yol) | 🔴 HIGH | **BLOKLAYIR** |
| 2 | **d2** — `_200x200` törəmələr | 🔴 HIGH | **BLOKLAYIR** |
| 3 | a1 — `appStoreServerNotifications` rate limit | 🟠 HIGH | bloklamır, eyni turda edilməli |
| 4 | d3 — `getTurnCredentials` + `assertActiveUser` | 🟡 MED | bloklamır (1 sətir) |
| 5 | a1 — qalan 13 callable | 🟡 MED | bloklamır |
| 6 | d5 — `list: if false` × 3 | 🟡 MED | bloklamır |
| 7 | d4 — `reviews` + `ACCEPTED_RISKS` düzəlişi | 🟡 MED | bloklamır |
| 8 | a2 / d6 — H-1, H-2 üçün saf modul + test | 🟡 MED | bloklamır |
| 9 | b1, b2, b3 | ⚪ — | sənəd düzəlişi |

**Buraxılışı bloklayan iki maddə d1 və d2-dir — ikisi də Audit
3-də artıq təsbit edilib və Mərhələ 2-nin mövzusudur.** Yəni bu
doğrulama yeni bloklayıcı aşkar etmədi; onun aşkar etdiyi şey
**bloklamayan altı əlavə boşluq** və hesabatlarımdakı beş dəqiqlik
səhvidir.
