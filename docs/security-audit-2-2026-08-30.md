# PeakPin — İkinci Mərhələ Hücum Auditi (Second-Pass Adversarial Audit)

**Tarix:** 2026-08-30
**Metod:** read-only kod auditi (heç bir fayl dəyişdirilmədi, heç bir deploy/commit
edilmədi, production Firestore/Storage-a heç nə yazılmadı, Epoint-ə heç bir sorğu
göndərilmədi).
**Əhatə:** `firestore.rules` (1723 sətir), `storage.rules` (208), `functions/src/`
(8339 sətir TS), `admin-panel/` (13206 sətir TS/TSX), `lib/` (376 Dart faylı),
`android/`, `ios/`, git tarixçəsi.
**Əvvəlki audit:** `docs/security-audit-2026-08-28.md` — YALNIZ 10-cu bölmədə
müqayisə üçün oxundu, tapıntı mənbəyi kimi istifadə edilmədi.

---

## 1. Executive Summary

Birinci auditdən sonrakı 12 düzəliş prompt-u **real və ölçülə bilən irəliləyiş**
yaratdı. Əvvəlki 13 CRITICAL-dan 8-i tam bağlanıb (K-2, K-4, K-5, K-6, K-8, K-9,
K-10, K-11), 3-ü qismən (K-1, K-3, K-13), 2-si açıqdır (K-7, K-12). Ödəniş axını
(Epoint + Store IAP) bu kod bazasının **ən güclü hissəsidir** — qiymət heç bir
yerdə client-dən gəlmir, idempotentlik tranzaksiya daxilindədir, imza yoxlaması
`timingSafeEqual`-dır, refund zənciri beş ödəniş növünün hamısını əhatə edir.

Buna baxmayaraq **buraxılış qərarı 🔴 DO NOT RELEASE**-dir. Səbəb üç CRITICAL
tapıntıdır və onlardan ikisi **bu gün yazılmış yeni kodda**:

1. **C-1 (NEW)** — istənilən daxil olmuş istifadəçi bütün Storage bucket-indəki
   **istənilən faylı silə bilər** (profil şəkilləri, məkan/təklif şəkilləri,
   story/post videoları, hətta `identity_verifications/` sənədləri). Kök səbəb:
   `onChatDeleted` (yeni funksiya) client-in tam nəzarətində olan `mediaUrl`
   sahəsini Admin SDK ilə `bucket.file(path).delete()`-ə ötürür. Heç bir yol
   yoxlaması yoxdur. İstismarı ~5 sətir kod tələb edir.
2. **C-2 (PREVIOUSLY-KNOWN)** — `emergencyToken` URL-də daşınır; Cloud
   Run/Logging oxu icazəsi olan, admin OLMAYAN daxili şəxs 1 saat ərzində tam
   admin sessiyası əldə edir və refresh token ilə onu qeyri-müəyyən müddətə
   uzadır.
3. **C-3 (NEW / K-13-ün yarımçıq düzəlişi)** — `completeOnboarding` Cloud
   Function-ın 18+, e-poçt doğrulaması və rezerv-username yoxlamalarının
   **hamısı client naviqasiyasında udulur**: `AsyncValue.guard` xətanı tutur,
   rethrow etmir, ekran isə şərtsiz `HomeScreen`-ə keçir. Nəticədə 18 yaşdan
   kiçik (və ya e-poçtu təsdiqlənməmiş) hesab profil sənədi olmadan tətbiqin
   içinə düşür və post/story yarada bilir.

Bundan əlavə, tətbiqin **əsas fərqləndirici xüsusiyyəti olan lokasiya məxfiliyi
ən zəif sahədir (4/10)**: `findNearbyUsers` marker koordinatını 100m şəbəkəyə
yuvarlaqlaşdırır, amma **eyni cavabda tam dəqiqlikli `distanceMeters` qaytarır**
və hücumçu öz `lat`/`lng`-ini `private/data`-ya sərbəst yaza bildiyi üçün üç
nöqtədən trilaterasiya ilə hədəfin əsl koordinatını metr dəqiqliyi ilə bərpa edə
bilir — yuvarlaqlaşdırma tamamilə mənasızlaşır.

**Bal: 56/100** (əvvəlki: 32/100).

**Ən dəyərli tapıntı kateqoriyaları:** 2 REGRESSION, 4 FIX-INCOMPLETE — yəni
düzəlişin özünün yaratdığı və ya yarımçıq qoyduğu boşluqlar. Xüsusilə
`users/{uid}/private/data` ayrımı (Prompt 4) `birthDate`-i **client tərəfindən
tam yazıla bilən** hala gətirdi, halbuki `firestore.rules` hələ də onu valideyn
sənəddə "kilidli" siyahıda saxlayır — kilid artıq mövcud olmayan bir sahəni
qoruyur.

---

## 2. Arxitektura və Hücum Səthi Xəritəsi

### 2.1. Struktur inventarı

| Komponent | Texnologiya | Qeyd |
|---|---|---|
| Mobil | Flutter, Dart; `minSdk 24`, `targetSdk 36`, `compileSdk 36` | `android/app/build.gradle.kts:44-47` |
| State | Riverpod (`flutter_riverpod ^2.6.1`) | |
| Backend | Firebase Cloud Functions v2, TypeScript, **Node 20 (EOL)** | `functions/package.json:5` |
| DB | Cloud Firestore | 40+ kolleksiya, 1723 sətirlik rules |
| Storage | Firebase Storage + `storage-resize-images` extension | |
| Auth | Firebase Auth (email/parol, Google, Apple) + custom claims (admin) | |
| Admin panel | Next.js 16.2.11, React 19, Server Components/Actions, Firebase App Hosting (Cloud Run) | |
| Ödəniş | **Epoint.az** (kart, saved-card, Apple/Google Pay Token Widget) | `functions/src/epoint.ts` |
| Store IAP | Apple App Store Server API v2, Google Play Developer API + RTDN | `functions/src/iap.ts` |
| Xəritə | Google Maps SDK (Android), Geocoding API | |
| Realtime | WebRTC + Cloudflare Realtime TURN | `getTurnCredentials` |
| Deep link | App Links (`peakpin.app/p/*`, `/u/*`) + `peakpin://` sxemi + Branch SDK | |
| Analytics | Firebase Analytics, Crashlytics, Remote Config | |
| E-poçt | Resend API (`privacy@peakpin.app` bildirişləri) | |

### 2.2. Data flow

```
                    ┌───────────────────────────────────────────┐
                    │  FLUTTER CLIENT (etibarsız — B, C, D)     │
                    └───────┬───────────────────────┬───────────┘
                            │ Firebase ID token     │ Firebase ID token
                            ▼                       ▼
                 ┌──────────────────┐    ┌────────────────────────┐
                 │ FIRESTORE (rules)│    │ CLOUD FUNCTIONS (onCall)│
                 │  ~40 kolleksiya  │◀───│  Admin SDK — rules-u    │
                 │  rules = yeganə  │    │  TAM BYPASS edir        │
                 │  sərhəd          │    └──────┬──────────┬───────┘
                 └────────┬─────────┘           │          │
                          │ triggerlər          │          │ HTTPS
                          ▼                     ▼          ▼
                 ┌──────────────────┐   ┌──────────┐  ┌──────────────┐
                 │ STORAGE (rules)  │   │ EPOINT   │  │ APPLE/GOOGLE │
                 │ + download token │   │ /request │  │ IAP verify   │
                 │ (rules-BYPASS!)  │   │ /reverse │  └──────────────┘
                 └──────────────────┘   └────┬─────┘
                                             │ webhook (imzalı)
                                             ▼
                                    ┌──────────────────┐
                                    │ epointWebhook    │
                                    │ (HTTP, auth YOX) │
                                    └──────────────────┘

  ┌──────────────────────────────────────────────────────────────┐
  │ ADMIN PANEL (Next.js, Cloud Run)                             │
  │  __session cookie → verifySessionCookie → custom claim role  │
  │  BÜTÜN data girişi Admin SDK ilə → firestore.rules TƏTBİQ    │
  │  OLUNMUR. Yeganə avtorizasiya sərhədi: hasPermission()       │
  └──────────────────────────────────────────────────────────────┘
```

**Etibar zəncirinin zəif halqaları:**

* Firestore Rules **client üçün yeganə sərhəddir** — Cloud Functions və admin
  panel onu tam bypass edir. Deməli rules-dakı hər boşluq birbaşa istismar
  edilir (C, B təhdid modelləri).
* Cloud Functions **client-in göndərdiyi sahələri** bir çox yerdə birbaşa
  Firestore-a yazır (`mediaUrl`, `photoUrl`, `imageUrl`) — bunlar sonradan
  Admin SDK əməliyyatlarına (silmə, kopyalama) və client render-inə düşür.
* Storage `download token`-ları **rules-dan asılı deyil** — bir dəfə sızan URL
  əbədi ictimai olur (`extensions/storage-resize-images.env`-in öz şərhi bunu
  açıq etiraf edir).
* Admin panel `getCurrentAdmin()`-dən başqa heç bir müdafiə qatına malik deyil
  — MFA yox, security header yox, `/api/*` proxy-dən kənardadır.

### 2.3. Hücum səthi xəritəsi

**Callable funksiyalar (28) — hamısında `enforceAppCheck: false`**

| Funksiya | Auth | Rol/sahiblik | Rate limit | assertActiveUser |
|---|---|---|---|---|
| `getTurnCredentials` | ✅ | — | `turn` 30/600s | ❌ |
| `deleteAccount` | ✅ | öz uid + 5dq fresh login | ❌ | ❌ (qəsdən) |
| `completeOnboarding` | ✅ | öz uid | `onboard` 10/600s | ❌ (qəsdən) |
| `getDiscoverCandidates` | ✅ | `premium == true` | **❌ YOX** | **❌ YOX** |
| `findNearbyUsers` | ✅ | — | `nearby` 10/60s | ✅ |
| `previewVenueAudience` | ✅ | venue owner | `nearby` 10/60s | ❌ |
| `searchUsersByName` | ✅ | — | **❌ YOX** | **❌ YOX** |
| `forwardChatMedia` | ✅ | chat participant | 30/600s | ✅ |
| `joinWaitlist` | ✅ | — | **❌ YOX** | ✅ |
| `updateVenue` / `resubmitVenue` | ✅ | `ownerId` | ❌ | ✅ |
| `updateOffer` / `resubmitOffer` | ✅ | `ownerId` | ❌ | ✅ |
| `updatePinBox` / `resubmitPinBox` | ✅ | `ownerId` | ❌ | ✅ |
| `submitIdentityVerification` | ✅ | öz uid + path prefix | **❌ YOX** | ✅ |
| `submitVenue` | ✅ | `businessStatus != none` | **❌ YOX** | ✅ |
| `submitOffer` | ✅ | venue owner | ❌ | ✅ |
| `createBoostCheckout` | ✅ | offer owner | `checkout` 10/600s | ✅ |
| `createVenuePremiumCheckout` | ✅ | venue owner | `checkout` | ✅ |
| `retryOfferPayment` / `retryVenue*Payment` | ✅ | owner | `checkout` | ✅ |
| `reservePinBoxOrder` | ✅ | — | `reserve` 10/600s | ✅ |
| `generatePinBoxQrToken` | ✅ | `buyerId` | **❌ YOX** | ✅ |
| `redeemPinBoxOrder` | ✅ | venue owner | `redeem` 30/300s | ✅ |
| `createEpointWidgetCheckout` | ✅ | payment owner | `checkout` | ✅ |
| `startCardRegistration` / `payWithSavedCard` | ✅ | owner | `checkout` | ✅ |
| `deleteSavedCard` / `setDefaultSavedCard` | ✅ | `ownerId` | ❌ | ✅ |
| `verifyInAppPurchase` | ✅ | öz uid | `iap-verify` 10/600s | ✅ |

**HTTP / webhook (3)**

| Endpoint | Auth mexanizmi | Rate limit |
|---|---|---|
| `epointWebhook` | SHA1 imza (`timingSafeEqual`) | IP üzrə 60/60s |
| `appStoreServerNotifications` | Apple JWS sertifikat zənciri | **❌ YOX** |
| `googlePlayRtdn` | Pub/Sub (GCP IAM) | Pub/Sub-un öz limiti |
| `admin-panel /api/auth/session` | ID token → custom claim | ❌ |
| `admin-panel /api/health` | **HEÇ NƏ — açıqdır** | ❌ |

**Client-dən BİRBAŞA yazıla bilən kolleksiyalar:**
`users/{uid}` (məhdud sahələr), `users/{uid}/private/**` (**TAM**),
`users/{uid}/media|favoriteOffers|reposts|sessions|notifications(isRead)|profileViews`,
`usernames`, `follows`, `chats` + `chats/*/messages`, `calls` + candidates,
`venues` (məhdud), `reviews`, `venues/*/likes|followers|waitlist(update)|activeCheckins`,
`offers` (məhdud), `offers/*/redemptions`, `pinboxes`, `venueEvents`,
`stories` + `views`, `posts` + `likes|comments`, `reports`, `eventReports`,
`reviewReports`, `supportMessages`.

**Storage yolları:** `profile_photos/{uid}/`, `chat_{photos,videos,audio}/{chatId}/{senderId}/`,
`{venue,offer,pinbox}_photos/{ownerUid}/`, `event_covers/{ownerUid}/`,
`stories/{uid}/`, `posts/{uid}/`, `identity_verifications/{uid}/{requestId}/` (write-only),
+ 4 köhnə flat yol (yalnız read, keçid dövrü).

**Admin panel route-ları:** `/login`, `/unauthorized`, `/payment/{success,error}`
(public); `/dashboard`, `/users`, `/venues`, `/offers`, `/pinboxes`, `/payments`,
`/premium-payments`, `/pinbox-payouts`, `/identity-verifications`, `/feedback`,
`/event-reports`, `/review-reports`, `/notifications`, `/logs`, `/admins`.

**Deep link:** `https://peakpin.app/p/{postId}`, `https://peakpin.app/u/{username}`,
`peakpin://u/{username}`, Google OAuth reversed-client-id sxemi (iOS).

---

## 3. Təhdid Modeli Nəticələri

| # | Hücumçu | Nə əldə edir | Nəyi dəyişir/silir | Bypass |
|---|---|---|---|---|
| **A** | Adi istifadəçi | Bütün public profillər, məkanlar, təkliflər, reviews (kim harada olub) | öz məzmunu | — |
| **B** | Zərərli client | + xam Firestore/Storage SDK: `private/data`-ya ixtiyari yazı, `birthDate` saxtalaşdırma, `photoUrl`-a xarici URL, chat `participants` dəyişmə | **bütün Storage bucket** (C-1), qarşı tərəfin bütün chat tarixçəsi (H-4) | blok, `followersOnly`, 18+ yaş, moderasiya |
| **C** | Birbaşa API (tətbiq yoxdur) | B ilə eyni — App Check söndürülü olduğu üçün heç bir fərq yoxdur; + `usernames` list ilə tam istifadəçi bazası enumerasiyası | B ilə eyni | App Check (mövcud deyil) |
| **D** | Oğurlanmış hesab | Qurbanın bütün datası; VIP-dirsə `getDiscoverCandidates` ilə limitsiz baza taraması | qurbanın məzmunu, chat tarixçəsi (birtərəfli silmə) | "yeni cihaz" xəbərdarlığı (`knownDeviceSignatures` client-yazılabilir) |
| **E** | Saxta biznes hesabı | `previewVenueAudience` ilə **istənilən koordinatda** istifadəçi sıxlığı oraklı (H-2); öz məkanına 5-ulduzlu "təsdiqlənmiş" rəy (M-6) | öz elanları | rəy həqiqiliyi, audience məxfiliyi |
| **F** | Ələ keçirilmiş moderator | Bütün venue/offer/pinbox moderasiyası, **bütün ödənişlərin siyahısı**, `initiateRefund` (real pul geri qaytarma), `markPinBoxPayoutPaid`, moderationLogs | ödəniş statusları, payout qeydləri | maliyyə/admin ayrımı (H-7) |
| **G** | Admin hədəf alan | Tam platforma nəzarəti; KYC sənədləri; broadcast | hər şey | MFA yoxdur, parol min. 6 simvol (server) |
| **H** | **Cloud Logging oxucusu (admin DEYİL)** | `emergencyToken` linki → **tam admin** (C-2); `epointWebhook`-un tam decoded payload-u (kart maskası, məbləğ, order id) (M-8); `logCallableInvocation` uid izləri | — | bütün admin RBAC |

**H xüsusi qeyd:** `roles/logging.viewer` GCP-də ən çox paylanan "zərərsiz" rol-dur
(dev, SRE, analitik). C-2 bu rolu tam admin-ə çevirir. `mint-emergency-token.ts`
skripti hələ də `package.json`-da (`npm run mint-emergency-token`) və login səhifəsi
hələ də tokeni qəbul edir.

---

## 4. 🔴 CRITICAL Tapıntılar

### C-1 — İxtiyari Storage obyektinin silinməsi (bütün bucket)

```
ID:            C-1
BAŞLIQ:        Chat mesajının `mediaUrl` sahəsi Admin SDK-nın fayl silmə
               əməliyyatına yoxlanmadan ötürülür — istənilən istifadəçi
               bucket-dəki İSTƏNİLƏN faylı silə bilər
STATUS:        NEW  (yeni kod: `onChatDeleted`, Bölmə 2.1 siyahısından)
KATEQORİYA:    Broken Object Level Authorization / Destructive IDOR
SEVERITY:      🔴 CRITICAL
CVSS:          9.1  (AV:N/AC:L/PR:L/UI:N/S:C/C:N/I:H/A:H)
HÜCUMÇU:       B, C, D  (adi daxil olmuş hesab kifayətdir)
```

**FAYL:SƏTİR**

* `functions/src/index.ts:5217-5229` — `onChatDeleted`
* `functions/src/index.ts:1287-1291` — `deleteStorageObjectByUrl`
* `functions/src/index.ts:1271-1280` — `storagePathFromUrl`
* `functions/src/index.ts:1257-1263` — `deleteStorageFile`
* `functions/src/index.ts:1054-1069` — `replaceMessagesWithPlaceholder` (ikinci giriş nöqtəsi)
* `firestore.rules:746-755` — `chats/{chatId}/messages` `allow create` (mediaUrl validasiyası YOXDUR)
* `firestore.rules:696` — `chats/{chatId}` `allow delete`

**SÜBUT**

```ts
// functions/src/index.ts:5217
export const onChatDeleted = onDocumentDeleted("chats/{chatId}", async (event) => {
  const messagesSnap = await chatRef.collection("messages").get();
  await Promise.all(messagesSnap.docs.map(async (doc) => {
    const mediaUrl = doc.data().mediaUrl as string | undefined;   // ← CLIENT-İN YAZDIĞI SAHƏ
    if (mediaUrl) await deleteStorageObjectByUrl(mediaUrl);       // ← heç bir yoxlama
    await doc.ref.delete();
  }));
});

// functions/src/index.ts:1271
function storagePathFromUrl(url: string): string | null {
  const markerIndex = url.indexOf("/o/");                          // ← "/o/" olsa kifayətdir
  ...
  return decodeURIComponent(encodedPath);                          // ← ixtiyari yol
}

// functions/src/index.ts:1257
async function deleteStorageFile(path: string): Promise<void> {
  try { await storage.bucket().file(path).delete(); }              // ← ADMIN SDK, rules BYPASS
  catch { /* səssiz — hücumçu üçün ideal */ }
}
```

`firestore.rules`-un mesaj yaratma qaydası `mediaUrl`-ə **heç bir məhdudiyyət
qoymur** — yalnız `senderId`, chatId üzvlüyü, `isActiveUser`, `text` ölçüsü, blok
və `declined` statusu yoxlanır:

```
// firestore.rules:746
allow create: if request.auth != null &&
  request.auth.uid == request.resource.data.senderId &&
  chatId.split('_').hasAny([request.auth.uid]) &&
  isActiveUser(request.auth.uid) &&
  (!('text' in request.resource.data) || request.resource.data.text.size() <= 2000) &&
  !isBlockedPair(...) && (...status != 'declined');
```

**İSTİSMAR YOLU (icra edilmədi)**

1. Hücumçu `U_a` normal yolla bir çat açır — məsələn `chats/{U_a}_{U_b}` (`U_b`
   mesaj qəbul edən istənilən hesab; `canMessage` və `isBlockedPair` keçilir).
2. Həmin çatda mesaj yaradır:
   ```json
   { "senderId": "U_a", "sentAt": <ts>, "type": "image",
     "mediaUrl": "x/o/identity_verifications%2FVICTIM_UID%2FREQ_ID%2Fselfie.jpg" }
   ```
   URL-in real Firebase Storage URL-i olması **tələb olunmur** — `storagePathFromUrl`
   yalnız `/o/` ayırıcısını axtarır və qalanını `decodeURIComponent` edir.
3. Bir mesaj = bir fayl. 500 mesaj = 500 fayl (batch limiti yoxdur, `Promise.all`).
4. Hücumçu çat sənədini silir (`allow delete` hər iki iştirakçıya açıqdır).
5. `onChatDeleted` işə düşür və 500 faylı Admin SDK ilə silir. Xətalar udulur,
   heç bir moderasiya/audit siqnalı yaranmır.

**Hədəf yollar tam açıqdır** (heç birinin təxmin edilməsi lazım deyil):
`users/{uid}.photoUrl` (hər kəs oxuya bilir), `venues/{id}.photoUrl`,
`offers/{id}.imageUrl`, `pinboxes/{id}.imageUrl`, `venueEvents/{id}.coverImageUrl`,
`posts/{id}.mediaUrl` — hamısı `allow read: if request.auth != null` olan
sənədlərdə saxlanılır. `identity_verifications/{uid}/{requestId}/*` yolları isə
`identityVerifications` sənədində sahibə görünür və struktur olaraq təxmin edilə
biləndir.

**TƏSİR**

* Bütün istifadəçilərin profil şəkilləri, bütün məkan/təklif/PinBox şəkilləri,
  bütün story və post medialarının **birdəfəlik, geri qaytarılmayan silinməsi**.
  Firestore sənədləri qalır → tətbiq hər yerdə sınıq şəkil göstərir.
* **KYC sübutlarının məhv edilməsi**: fırıldaqçı öz `identity_verifications`
  sənədlərini (və ya başqasının) moderator baxmazdan əvvəl silir.
* Rəqib biznesin bütün vizual məzmununun silinməsi (kommersiya zərəri).
* Heç bir jurnal qalmır (`catch {}`), heç bir bildiriş getmir.

**DÜZƏLİŞ YANAŞMASI**

1. `deleteStorageObjectByUrl`-ə **məcburi prefiks arqumenti** əlavə et:
   `deleteStorageObjectByUrl(url, allowedPrefixes: string[])`, yol prefikslə
   başlamırsa `logger.error` + no-op. `onChatDeleted` üçün icazəli prefiks
   `chat_photos/{chatId}/`, `chat_videos/{chatId}/`, `chat_audio/{chatId}/`
   olmalıdır — `forwardChatMedia`-nın (`index.ts:1352-1356`) artıq etdiyi
   `CHAT_MEDIA_FOLDERS` yoxlamasının eynisi.
2. `replaceMessagesWithPlaceholder` üçün eyni prefiks (`chat_*/{chatId}/{uid}/`).
3. Əlavə qat: `firestore.rules`-un mesaj `create` qaydasına
   `(!('mediaUrl' in request.resource.data) || request.resource.data.mediaUrl.matches('https://firebasestorage.googleapis.com/.*'))`
   — amma bu TƏK BAŞINA kifayət DEYİL (yol hissəsi hələ ixtiyaridir), yalnız
   dərinlikdə müdafiədir.
4. `deleteStorageFile`-ın `catch {}`-ini `logger.warn` ilə əvəz et — səssiz
   uğursuzluq hücumun aşkarlanmasını qeyri-mümkün edir.

**REQRESSİYA TESTİ**

* Emulator: `chats/{a}_{b}/messages/{m}` sənədi `mediaUrl:
  "x/o/profile_photos%2Fvictim%2Fprofile.jpg"` ilə yaradılır, çat silinir →
  `profile_photos/victim/profile.jpg` **hələ də mövcud olmalıdır**.
* Normal hal: real `chat_photos/{chatId}/{uid}/f.jpg` URL-i ilə mesaj → çat
  silinəndə fayl **silinməlidir** (mövcud davranış pozulmamalıdır).

---

### C-2 — `emergencyToken` URL-də: Logging oxucusundan tam admin-ə

```
ID:            C-2
BAŞLIQ:        Admin panelinin fövqəladə giriş tokeni URL query string-ində
               daşınır → Cloud Run/Logging request loglarına düşür
STATUS:        PREVIOUSLY-KNOWN  (əvvəlki audit K-12) — HƏLƏ AÇIQDIR
KATEQORİYA:    Broken Authentication / Credential in URL (CWE-598)
SEVERITY:      🔴 CRITICAL
CVSS:          8.8  (AV:N/AC:L/PR:L/UI:N/S:C/C:H/I:H/A:H)
HÜCUMÇU:       H  (admin OLMAYAN, yalnız `roles/logging.viewer` olan daxili şəxs)
```

**FAYL:SƏTİR**

* `admin-panel/src/app/login/page.tsx:70-84` — `searchParams.get("emergencyToken")` → `signInWithCustomToken`
* `admin-panel/scripts/mint-emergency-token.ts:86` — `${ORIGIN}/login?emergencyToken=${token}`
* `admin-panel/package.json:12` — `"mint-emergency-token"` skripti hələ mövcuddur
* `admin-panel/apphosting.yaml` — Firebase App Hosting = Cloud Run

**ÖN ŞƏRT:** biri bir dəfə `npm run mint-emergency-token -- <admin@...>` icra edib
linkə klikləyir (skriptin öz sənədləşməsinə görə bu, Email+Password provayderinin
kəsintisi zamanı **artıq baş verib**).

**SÜBUT**

```ts
// admin-panel/scripts/mint-emergency-token.ts:85-86
const token = await auth.createCustomToken(user.uid);
const link = `${ADMIN_PANEL_ORIGIN}/login?emergencyToken=${encodeURIComponent(token)}`;

// admin-panel/src/app/login/page.tsx:71-77
const token = searchParams.get("emergencyToken");
if (!token) return;
signInWithCustomToken(auth, token).then((c) => completeSignIn(auth, c));
```

**İSTİSMAR YOLU**

1. `H` GCP Console → Logging → Logs Explorer-də sorğu verir:
   `resource.type="cloud_run_revision" httpRequest.requestUrl=~"emergencyToken"`.
   Cloud Run **default olaraq tam request URL-ini query string ilə birlikdə**
   `httpRequest.requestUrl` sahəsində loglayır — bunun üçün əlavə heç bir
   konfiqurasiya lazım deyil.
2. Tokeni kopyalayıb `https://admin.peakpin.app/login?emergencyToken=<token>`
   ünvanını açır.
3. `signInWithCustomToken` **birdəfəlik deyil** — token 1 saat ərzində sonsuz
   dəfə istifadə oluna bilər.
4. Mübadilə nəticəsində alınan **refresh token 1 saatlıq məhdudiyyətə tabe
   deyil** — `revokeRefreshTokens` çağırılmadıqca sessiya davam edir; `__session`
   cookie 5 gün etibarlıdır (`session.ts:11`).

**Əlavə sızma kanalları:** brauzer tarixçəsi/sinxronizasiyası, HTTP Referer
(eyni-mənşəli sub-resurslar üçün), korporativ proxy logları, Slack/e-poçt
linkinin öz-özünə önizləməsi.

**TƏSİR:** Tam platforma ələ keçirilməsi — bütün istifadəçi PII-si, KYC
sənədləri (pasport + selfie), ödəniş qeydləri, ban/premium vermə, admin əlavə
etmə (`addAdmin` → `manageAdmins`).

**DÜZƏLİŞ YANAŞMASI**

1. **Ən sadə və ən doğru:** skripti və login səhifəsindəki `useEffect` blokunu
   sil. Email+Password provayderinin kəsintisi (skriptin öz səbəbi) artıq
   `auth_screen.dart`-ın işlədiyinə görə həll olunub görünür — əgər belədirsə,
   bu kodun mövcud olması üçün heç bir səbəb qalmayıb.
2. Saxlanılacaqsa: tokeni URL-də DEYİL, `POST /api/auth/emergency` gövdəsində
   qəbul et; tokeni Firestore-da birdəfəlik (`usedAt`) qeyd et; TTL-i 5 dəqiqəyə
   endir; hər istifadəni `moderationLogs`-a yaz və bütün adminlərə bildiriş göndər.
3. Hər halda: mövcud bütün admin hesabları üçün `revokeRefreshTokens` çağır —
   artıq minlənmiş tokenlərdən yaranmış sessiyalar hələ canlı ola bilər.

**REQRESSİYA TESTİ:** `/login?emergencyToken=<hər hansı>` → giriş baş
verməməlidir; Cloud Logging-də `emergencyToken` sətri üçün sorğu 0 nəticə
verməlidir.

---

### C-3 — Onboarding qapısının client-də tamamilə keçilməsi (18+ yaş daxil)

```
ID:            C-3
BAŞLIQ:        `AsyncValue.guard` `completeOnboarding`-in bütün server-side
               xətalarını udur; ekran şərtsiz HomeScreen-ə keçir — 18+ yaş,
               e-poçt doğrulaması və rezerv-username yoxlamaları effektiv
               şəkildə mövcud deyil
STATUS:        NEW  /  K-13-ün FIX-INCOMPLETE-i
KATEQORİYA:    Improper Error Handling → Authentication/Authorization Bypass
SEVERITY:      🔴 CRITICAL  (uşaq təhlükəsizliyi + mağaza siyasəti)
CVSS:          8.2  (AV:N/AC:L/PR:L/UI:N/S:C/C:L/I:H/A:N)
HÜCUMÇU:       A (təsadüfən), B (qəsdən)
```

**FAYL:SƏTİR**

* `lib/features/auth/presentation/providers/auth_providers.dart:85-97` — `AsyncValue.guard`
* `lib/features/auth/presentation/screens/onboarding_screen.dart:213-252` — `try` bloku
* `lib/features/auth/presentation/screens/onboarding_screen.dart:254-272` — heç vaxt işə düşməyən `catch`-lər
* `functions/src/index.ts:470-472, 509-511` — server yoxlamaları (düzgündür, amma nəticəsi udulur)
* `firestore.rules:1601` — `posts` create (profil sənədi TƏLƏB ETMİR)

**SÜBUT**

```dart
// auth_providers.dart:83-97 — controller
Future<void> completeOnboarding({...}) async {
  state = const AsyncValue.loading();
  state = await AsyncValue.guard(                 // ← xətanı TUTUR, RETHROW ETMİR
    () => _repository.completeOnboarding(...),
  );
}                                                 // ← normal şəkildə tamamlanır
```

```dart
// onboarding_screen.dart:213-252
try {
  await ref.read(authControllerProvider.notifier).completeOnboarding(...);
  ...
  await _requestPermissionsThenContinue();
  Navigator.pushAndRemoveUntil(                    // ← HƏMİŞƏ icra olunur
    context, MaterialPageRoute(builder: (_) => const HomeScreen()), (r) => false);
} on UnderageOnboardingException {                 // ← ÖLÜ KOD
  ...
} on EmailNotVerifiedException {                   // ← ÖLÜ KOD
  ...
} catch (e) {                                      // ← ÖLÜ KOD
```

Server tərəf yoxlamaları özləri **düzgündür**:

```ts
// functions/src/index.ts:470-472
if (calculateAgeUtc(birthDate, now) < MINIMUM_AGE_YEARS) {
  throw new HttpsError("failed-precondition", "age-under-18");
}
// functions/src/index.ts:509-511
if (loginProvider === "email" && request.auth?.token.email_verified !== true) {
  throw new HttpsError("permission-denied", "email-not-verified");
}
```

— amma `HttpsError` client-də `AsyncValue.error`-a çevrilib heç vaxt oxunmur.

**İSTİSMAR YOLU**

1. 15 yaşlı istifadəçi (və ya `birthDateMs`-i dəyişdirilmiş client) onboarding
   formunu doldurur.
2. `completeOnboarding` `age-under-18` ilə imtina edir — `users/{uid}` sənədi
   **yaradılmır**.
3. Client xətanı udur, `HomeScreen`-ə keçir. İstifadəçi tətbiqin içindədir.
4. Həmin sessiyada `firestore.rules`-a görə hələ də edə bildikləri:
   * bütün profilləri oxumaq (`users/{uid}` `allow get: if request.auth != null`),
   * bütün məkan/təklif/tədbir/story/post oxumaq,
   * **post yaratmaq** (`firestore.rules:1601` — yalnız `userId == uid`,
     `isActiveUser` YOXDUR, profil sənədi tələb olunmur),
   * **story yaratmaq** (`firestore.rules:1523`), şərh yazmaq (`:1617`),
     `supportMessages` yazmaq (`:1698`).
   * Chat/zəng/report bloklanır (`isActiveUser` → `users/{uid}` yoxdur) — yeganə
     qoruyucu.
5. Eyni yol `email-not-verified` (təsdiqlənməmiş e-poçtla qeydiyyat),
   `username-taken` və `rate-limit-exceeded` üçün də işləyir.

**Qeyd:** tətbiq yenidən başladıldıqda `restoreSession()` `null` qaytarır
(`firebase_auth_repository.dart:161-173`) və `SplashScreen:58` düzgün şəkildə
`WelcomeScreen`-ə yönləndirir — yəni bu, **sessiya-daxili** bypass-dır, davamlı
deyil. Amma bir sessiya post/story yaratmaq üçün tamamilə kifayətdir.

**TƏSİR**

* `legal/child-safety-standards.html` və Terms §2-nin iddia etdiyi 18+ nəzarəti
  praktikada işləmir → **Google Play Uşaq Təhlükəsizliyi bəyannaməsinə qarşı yanlış
  bəyanat** (birinci auditin K-13-ünün eyni hüquqi riski, sadəcə bir qat dərində).
* E-poçt doğrulaması qapısı (AUTH-12-nin düzəlişi) keçilir.
* İstifadəçi "hesabım yaradıldı" zənn edir, əslində profil sənədi yoxdur →
  BACKLOG #11-də təsvir edilən "ilişmiş hesab" hadisəsinin əsl kökü də budur.

**DÜZƏLİŞ YANAŞMASI**

1. `AuthController.completeOnboarding`-i `AsyncValue.guard`-dan çıxar:
   ```dart
   Future<void> completeOnboarding({...}) async {
     state = const AsyncValue.loading();
     try {
       final user = await _repository.completeOnboarding(...);
       state = AsyncValue.data(user);
     } catch (e, st) {
       state = AsyncValue.error(e, st);
       rethrow;                      // ← ekran öz catch bloklarını görsün
     }
   }
   ```
2. Əlavə qat (bel bağlama): `onboarding_screen.dart`-da naviqasiyadan ƏVVƏL
   `ref.read(authControllerProvider).hasError` yoxlanışı və/veya
   `_repository`-dən qayıdan `AppUser`-in `null` olmadığının təsdiqi.
3. `firestore.rules`: `posts`, `stories`, `comments`, `supportMessages` create
   qaydalarına `isActiveUser(request.auth.uid)` əlavə et. Bu, `ACCEPTED_RISKS.md`-də
   "banlanmış istifadəçi məzmun yarada bilir" kimi qəbul edilmiş maddədir — amma
   **onboarding etməmiş hesab** ssenarisi orada nəzərdən keçirilməyib və bu, ayrıca
   (uşaq təhlükəsizliyi) səbəbdən qəbul edilə bilməz.

**REQRESSİYA TESTİ**

* Widget testi: `completeOnboarding` `HttpsError('failed-precondition',
  'age-under-18')` atsın → `HomeScreen`-ə naviqasiya **olmamalı**, snackbar
  görünməlidir.
* Emulator rules testi: `users/{uid}` sənədi olmayan auth istifadəçisi
  `posts/{id}` yarada **bilməməlidir**.

---

## 5. 🟠 HIGH Tapıntılar

### H-1 — Trilaterasiya: dəqiq `distanceMeters` 100m şəbəkə yuvarlaqlaşdırmasını tamamilə mənasızlaşdırır

```
ID: H-1 | STATUS: NEW | KATEQORİYA: Location Privacy / Information Disclosure
SEVERITY: 🟠 HIGH | CVSS: 7.5 (AV:N/AC:L/PR:L/UI:N/S:U/C:H/I:N/A:N)
HÜCUMÇU: B, C, D
```

**FAYL:SƏTİR**
* `functions/src/index.ts:884-890` — `distanceMeters` cavaba əlavə olunur
* `functions/src/index.ts:641-644` — `roundToGrid` (~100 m)
* `functions/src/index.ts:850` — hücumçunun öz `lat`/`lng`-i `private/data`-dan oxunur
* `firestore.rules:352` — `users/{uid}/private/{document}` `allow read, write` = sahibə TAM

**SÜBUT**
```ts
// index.ts:850 — sorğu mərkəzi hücumçunun ÖZ yazdığı sənəddən gəlir
const lat = callerPrivateSnap.data()?.lat as number | undefined;
const lng = callerPrivateSnap.data()?.lng as number | undefined;
...
// index.ts:884-890
.map(({ candidate, distanceMeters }) => ({
  ...buildPublicCandidatePayload(candidate.id, candidate.data),  // lat/lng 100m-ə yuvarlaqlanır
  distanceMeters,                                                // ← XAM, TAM DƏQİQLİK
}));
```
```
// firestore.rules:351-353
match /private/{document} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
}
```

**İSTİSMAR YOLU**
1. Hücumçu `users/{me}/private/data`-ya `{lat: L1, lng: G1}` yazır (SDK ilə, tətbiq lazım deyil).
2. `findNearbyUsers` çağırır → hədəf üçün `d1 = distanceMeters` (float, ~santimetr dəqiqliyi).
3. `lat/lng`-i `L2,G2`-yə, sonra `L3,G3`-ə dəyişib təkrarlayır → `d2`, `d3`.
4. Üç dairənin kəsişməsi hədəfin **əsl** koordinatını verir. Yuvarlaqlaşdırma
   `distanceMeters`-ə tətbiq edilmədiyi üçün nəticə tam dəqiqdir.
5. Rate limit (`nearby` 10/60s) bunu **əngəlləmir** — cəmi 3 çağırış lazımdır.
   `visibilityRadiusKm` də əngəlləmir: hücumçu sadəcə hədəfin radiusuna girir.
6. Ghost Mode-u aktiv OLMAYAN hər kəs hədəf ola bilər (default: qeyri-aktiv).

**TƏSİR:** Fiziki təqib. Tətbiqin bütün lokasiya-məxfiliyi arxitekturası (Prompt 4 /
K-1, K-4) bu tək sahə ilə keçilir. `roundToGrid`-in "anti-averaging" şərhi
(`index.ts:632-640`) düzgündür, amma qoruduğu dəyər cavabın başqa sahəsində
xam formada verilir.

**DÜZƏLİŞ YANAŞMASI**
`distanceMeters`-i də diskretləşdir — məsələn 100 m-lik səbətlərə yuvarlaqlaşdır
(`Math.round(d/100)*100`) və ya UI-ın həqiqətən göstərdiyi səviyyəyə endir
("<1 km", "1-3 km", "3-10 km"). Client-in nə göstərdiyini yoxla: əgər ekran
"850 m" yazırsa, 100 m-lik səbət kifayətdir və trilaterasiyanı ~100 m
qeyri-müəyyənliyə çevirir (yuvarlaqlanmış marker ilə eyni səviyyə).
Əlavə: `private/data.lat/lng` yazılışını client-dən alıb ayrıca callable-a
(`updateMyLocation`) köçür və server tərəfdə "ağlabatan sıçrayış" yoxlaması qoy
(məs. 15 saniyədə 500 km hərəkət qeyri-mümkündür) — bu, həm GPS spoofing-i, həm
də sürətli trilaterasiya nümunəsini aşkarlanan hala gətirər.

**REQRESSİYA TESTİ:** eyni hədəf üçün 3 fərqli mövqedən çağırışın qaytardığı
`distanceMeters` dəyərləri 100-ün tam qatları olmalıdır.

---

### H-2 — `previewVenueAudience`: ixtiyari koordinatda istifadəçi sıxlığı oraklı

```
ID: H-2 | STATUS: NEW | KATEQORİYA: Location Privacy / Missing Input Validation
SEVERITY: 🟠 HIGH | CVSS: 6.5
HÜCUMÇU: E (saxta biznes hesabı — 15 AZN-lik abunə kifayətdir)
```

**FAYL:SƏTİR** `functions/src/index.ts:911-965`, xüsusilə `:944-956`.

**SÜBUT**
```ts
// index.ts:945-956 — mərkəz və radius TAM client-dən, məkanın öz koordinatı DEYİL
const lat = request.data?.lat as number | undefined;
const lng = request.data?.lng as number | undefined;
const radiusKm = request.data?.radiusKm as number | undefined;
if (typeof lat !== "number" || typeof lng !== "number" || typeof radiusKm !== "number") {
  throw new HttpsError("invalid-argument", "lat/lng/radiusKm tələb olunur.");
}
count = nonGhost.filter((c) => { ... distanceMeters <= radiusKm * 1000 ... }).length;
```
Sahiblik yoxlaması (`:930`) yalnız "bu `venueId` sənindirmi" sualına cavab verir —
sorğunun **mərkəzinin** həmin məkanın koordinatı olduğunu heç kim yoxlamır.
`radiusKm`-in yuxarı həddi yoxdur.

**İSTİSMAR YOLU**
1. Hücumçu bir məkan yaradıb təsdiqlətdirir (və ya sadəcə `awaiting_payment`
   mərhələsində? — xeyr, `venues` sənədi mövcud olmalıdır; `submitVenue` onu
   ödənişdən ƏVVƏL `status: awaiting_payment` ilə yaradır, sahiblik yoxlaması isə
   `status`-a baxmır → **ödəniş belə lazım deyil**).
2. `previewVenueAudience({venueId, mode:'distance', lat, lng, radiusKm: 0.05})`
   çağırır → həmin 50 m-lik dairədə neçə (ghost olmayan, online) istifadəçi
   olduğunu öyrənir.
3. Şəhəri şəbəkə ilə tarayaraq real vaxt sıxlıq xəritəsi qurur; kiçik radiusla
   sayğac 0→1 keçidi konkret şəxsin mövcudluğunu təsdiqləyir.
4. `mode` `'country'`/`'world'`/`'distance'`-dan fərqli göndərilsə (`:942`
   `else` budağı) `count = nonGhost.length` — **bütün onlayn istifadəçi sayı**
   qaytarılır (kiçik, amma qəsdən olmayan biznes-metrik sızması).
5. Rate limit `nearby` 10/60s → saatda 600 sorğu, gündə 14,400 nöqtə.

**TƏSİR:** Bakı miqyasında real vaxt istifadəçi sıxlığı xəritəsi; hədəfli
mövcudluq təsdiqi. `visibilityRadiusKm` tətbiq olunur, `ghostModeEnabled` tətbiq
olunur — amma bunların heç biri "50 m radiusda kimsə varmı" sualını bağlamır.

**DÜZƏLİŞ YANAŞMASI**
`lat`/`lng`-i client-dən **qəbul etmə** — məkanın öz sənədindəki `venue.lat`/
`venue.lng`-dən oxu (funksiya artıq `venue`-nu oxuyub). `radiusKm`-i məkanın
`audienceRadiusKm`-i ilə məhdudlaşdır və hər halda minimum həddi tətbiq et
(məs. `< 1 km` üçün sayğac qaytarma, və ya k-anonimlik: `count < 5` isə `"<5"`
qaytar). `mode` üçün açıq allowlist (`['distance','country','world']`) qoy,
`else` budağını `invalid-argument`-ə çevir. `assertActiveUser` əlavə et.

**REQRESSİYA TESTİ:** `lat`/`lng` göndərilən çağırış məkanın koordinatını
istifadə etməlidir (fərqli koordinat göndərmək nəticəni dəyişməməlidir);
`radiusKm: 20000` `invalid-argument` verməlidir.

---

### H-3 — `chats.participants` dəyişdirilə bilir → blok və `followersOnly` keçilir, istənilən istifadəçinin çat siyahısına mesaj yeridilir

```
ID: H-3 | STATUS: NEW (Prompt 5-in blok mexanizmində qalan boşluq)
KATEQORİYA: Broken Access Control / Mass Assignment
SEVERITY: 🟠 HIGH | CVSS: 7.1
HÜCUMÇU: B, C, D
```

**FAYL:SƏTİR** `firestore.rules:676-693` (`chats/{chatId}` `allow update`),
`lib/features/chat/data/repositories/firebase_chat_repository.dart:39,49`
(`.where('participants', arrayContains: myUid)`).

**SÜBUT**
```
// firestore.rules:676-682 — 1-ci budaq
allow update: if request.auth != null && request.auth.uid in resource.data.participants && (
  (
    request.resource.data.status == resource.data.status &&
    !request.resource.data.diff(resource.data).affectedKeys().hasAny(['lastMessageOverride'])
  ) || ( ... )
);
```
`participants` **kilidli deyil**. Müqayisə üçün: `calls/{callId}` `allow update`
(`firestore.rules:826-829`) `participants` və `callerId`-ni açıq şəkildə sabit
saxlayır — çat qaydasında həmin qoruma yoxdur.

**İSTİSMAR YOLU**
1. Hücumçu `U_a` `canMessage`/`isBlockedPair`-i keçən hər hansı `U_x` ilə çat
   yaradır (`chats/{a}_{x}`) — və ya `participants: [U_a, U_a]` ilə özü ilə.
2. Sonra həmin sənədə `update` göndərir:
   `{ participants: ["U_a", "U_victim"], lastMessage: "<ixtiyari mətn>",
      lastMessageAt: <now>, lastMessageSenderId: "U_a", unreadCount: {U_victim: 1} }`.
   `status` dəyişmir, `lastMessageOverride`-a toxunulmur → 1-ci budaq keçir.
3. `U_victim`-in çat siyahısı sorğusu (`participants array-contains U_victim`)
   bu sənədi qaytarır → qurban oxunmamış bir söhbət və hücumçunun yazdığı
   önizləmə mətnini görür.
4. **Bu, `isBlockedPair`-i, `whoCanMessageMe: followersOnly`-ni və qurbanın
   söhbəti əvvəllər silməsini tamamilə keçir** — Prompt 5-in bütün K-3/RT-6
   qoruması yalnız `create` və `messages/create`-də tətbiq olunur, `update`-də yox.
5. Qurban söhbəti açsa `chats/{a}_{x}/messages` oxunur — `chatId.split('_')`-də
   qurbanın uid-i olmadığı üçün mesajlar boş görünür; amma zərər (mətn çatdırılması
   + taciz) artıq baş verib və təkrarlana bilər.

**TƏSİR:** Bloklanmış tacizçi qurbana mətn çatdırmağa davam edir; `followersOnly`
məxfilik ayarı işləmir; hücumçu istənilən uid-i öz çatına "yerləşdirib" onun
siyahısını çirkləndirə bilər.

**DÜZƏLİŞ YANAŞMASI**
`chats/{chatId}` `allow update`-in 1-ci budağına əlavə et:
```
request.resource.data.participants == resource.data.participants &&
request.resource.data.initiatorId == resource.data.initiatorId &&
```
(`calls/{callId}`-in artıq etdiyinin eynisi). Əlavə olaraq `create` qaydasında
`chatId == participants[0] + '_' + participants[1]` və `participants.size() == 2`
yoxlaması — hazırda chatId ilə `participants` arasında heç bir struktur bağ
tələb edilmir.

**REQRESSİYA TESTİ:** emulator — mövcud çatın `participants`-ini dəyişməyə cəhd
`permission-denied` verməlidir; normal mesaj göndərmə (lastMessage/unreadCount
yeniləməsi) işləməyə davam etməlidir.

---

### H-4 — Bir iştirakçı qarşı tərəfin bütün çat tarixçəsini və medialarını birdəfəlik məhv edir

```
ID: H-4 | STATUS: NEW (yeni `onChatDeleted` bunu Storage-a da genişləndirdi)
KATEQORİYA: Improper Authorization / Destructive Action
SEVERITY: 🟠 HIGH | CVSS: 6.5
HÜCUMÇU: B, D (taciz edən tərəf — sübutun məhvi)
```

**FAYL:SƏTİR** `firestore.rules:696`, `functions/src/index.ts:5217-5229`,
`lib/features/chat/data/repositories/firebase_chat_repository.dart:554-559`.

**SÜBUT**
```
// firestore.rules:696
allow delete: if request.auth != null && request.auth.uid in resource.data.participants;
```
```dart
// firebase_chat_repository.dart:554-558
Future<void> deleteChat(String chatId, String myUid) {
  // "Delete for me only" isn't modeled yet ...
  return _chats.doc(chatId).delete();     // ← paylaşılan sənəd
}
```
`onChatDeleted` (`index.ts:5217`) bundan sonra **bütün** mesajları və **hər iki
tərəfin** Storage medialarını silir.

**İSTİSMAR YOLU:** Tacizçi qurbana təhqiramiz/təhdidedici mesajlar göndərir,
sonra "Söhbəti sil" düyməsinə basır. Qurbanın cihazında da, serverdə də söhbətin
heç bir izi qalmır — mesaj mətnləri, şəkil/video/səs faylları daxil. Qurbanın
şikayət etmək üçün heç bir sübutu qalmır; `reports` mexanizmi `reason` mətnindən
başqa heç nə saxlamır.

**TƏSİR:** Taciz/təhdid sübutunun məhvi (məhkəmə/moderasiya baxımından kritik),
qarşı tərəfin razılığı olmadan data itkisi. Bu, mövcud kodda "MVP qərarı" kimi
sənədləşdirilib, amma auditin təhdid modelində (F, D) qəbul edilə bilməz.

**DÜZƏLİŞ YANAŞMASI**
Per-user `deletedFor` naxışını çat səviyyəsinə qaldır: `chats/{id}.hiddenFor:
string[]` (mesajların artıq istifadə etdiyi eyni naxış, `firestore.rules:762-768`),
`allow delete: if false`, client sorğusuna `hiddenFor` filtri əlavə. Fiziki silmə
yalnız hər iki tərəf gizlədəndə (Cloud Function trigger) və ya `deleteAccount`
axınında baş versin. Ən azı: `reports` yaradılanda əlaqəli mesajların bir
snapshot-ı moderasiya üçün saxlanılsın.

**REQRESSİYA TESTİ:** `U_a` çatı silir → `U_b` üçün mesajlar və media hələ
mövcud olmalıdır; `U_b` də silsə → fiziki təmizlənməlidir.

---

### H-5 — `photoUrl` / `imageUrl` / `coverImageUrl` ixtiyari xarici URL ola bilər: IP toplama + tam moderasiya bypass-ı

```
ID: H-5 | STATUS: NEW | KATEQORİYA: SSRF-adjacent / Content Moderation Bypass / Privacy
SEVERITY: 🟠 HIGH | CVSS: 7.4
HÜCUMÇU: A, B, C, E
```

**FAYL:SƏTİR**
* `firestore.rules:334-338` — `users` `allow update`: `photoUrl` kilidli sahələr siyahısında **yoxdur**
* `functions/src/index.ts:3775, 3826` — `updateOffer`-in `imageUrl`-i validasiyasız yazılır
* `functions/src/index.ts:4806, 4859` — `submitVenue`-nin `photoUrl`-i validasiyasız
* `firestore.rules:1601` — `posts` create (bütün sahələr sərbəst, `mediaUrl` daxil)
* Render: `lib/features/home/presentation/widgets/avatar_pin_marker.dart:68-70`,
  `lib/features/home/presentation/tabs/discover_tab.dart:652`,
  `lib/core/widgets/app_image.dart:81`, `lib/features/chat/.../chats_tab.dart:577` və s.

**SÜBUT** — heç bir yerdə mənşə yoxlaması yoxdur:
```
$ grep -n "firebasestorage\|matches('https" firestore.rules      → 0 nəticə
$ grep -n "imageUrl|photoUrl" functions/src/index.ts | grep -i "valid|matches|startsWith"  → 0 nəticə
```
```dart
// avatar_pin_marker.dart:68-70 — xəritə markeri xam URL-i yükləyir
static Future<ui.Image> _loadNetworkImage(String url) {
  final stream = NetworkImage(url).resolve(const ImageConfiguration());
```

**İSTİSMAR YOLU (a) — kütləvi IP/deanonimləşdirmə**
1. Hücumçu `users/{me}` sənədinə `photoUrl:
   "https://tracker.example/px.jpg?u=peakpin"` yazır (bu sahə kilidli deyil).
2. Hücumçunun profili göründüyü **hər yerdə** — yaxınlıq xəritəsi markeri,
   Kəşf et kartı, çat siyahısı, zəng ekranı, növbə siyahısı — qurbanın cihazı
   birbaşa hücumçunun serverinə HTTPS sorğusu göndərir.
3. Hücumçu hər sorğunun IP-sini, User-Agent-ini və vaxtını toplayır → PeakPin
   istifadəçilərinin coğrafi/şəbəkə profili. Lokasiya tətbiqi üçün bu, bilavasitə
   deanonimləşdirmə vasitəsidir (IP → şəhər/ISP, yaxınlıq siyahısında görünmə
   faktı isə artıq ~radius məlumatı verir).

**İSTİSMAR YOLU (b) — moderasiya bypass-ı**
1. Biznes sahibi təklif/məkan yaradır, `imageUrl` olaraq öz serverindəki
   `https://evil.example/a.jpg` verir; həmin an fayl təmiz şəkildir.
2. Moderator təsdiqləyir (`status: approved`).
3. Sahib **öz serverində** faylın məzmununu dəyişir — Firestore-da heç nə
   dəyişmir, `updateOffer`-in `contentChanged` diff-i (`index.ts:3794-3805`) heç
   nə görmür, elan yenidən moderasiyaya düşmür.
4. Nəticə: təsdiqlənmiş elanın şəkli istənilən qadağan olunmuş məzmuna çevrilir.
   Eyni yol `users.photoUrl` üçün ümumiyyətlə moderasiya olmadan işləyir.

**TƏSİR:** İstifadəçi bazasının IP-lərinin toplanması; Prompt 6 / INFRA-5-in bütün
"məzmun kilidi + təkrar moderasiya" işinin keçilməsi; mağaza siyasəti riski
(qadağan olunmuş məzmunun tətbiq daxilində göstərilməsi).

**DÜZƏLİŞ YANAŞMASI**
1. `firestore.rules`-a paylaşılan funksiya:
   ```
   function isOwnStorageUrl(url, prefix) {
     return url is string &&
       url.matches('^https://firebasestorage\\.googleapis\\.com/v0/b/kim-var-73ce9\\.firebasestorage\\.app/o/' + prefix + '.*');
   }
   ```
   `users.photoUrl` (`profile_photos%2F{uid}%2F`), `posts.mediaUrl`
   (`posts%2F{uid}%2F`), `stories.mediaUrl` üçün tətbiq et.
2. Cloud Functions tərəfdə (`submitVenue`, `updateVenue`, `submitOffer`,
   `updateOffer`, `updatePinBox`) `storagePathFromUrl(url)` ilə yolu çıxar və
   `{venue,offer,pinbox}_photos/{uid}/` prefiksini tələb et — `forwardChatMedia`
   (`index.ts:1352-1356`) və `submitIdentityVerification` (`index.ts:4090-4094`)
   artıq bu naxışı istifadə edir, sadəcə şəkil sahələrinə genişləndirilməyib.
3. Client tərəfdə `AppImage`-a mənşə allowlist-i (əlavə qat).

**REQRESSİYA TESTİ:** `users/{me}` sənədinə `photoUrl: "https://evil.test/x.jpg"`
yazmaq `permission-denied` verməlidir; real Storage URL-i işləməlidir.

---

### H-6 — `usernames` list + `users` get = bütün istifadəçi bazasının enumerasiyası (RT-25 keçilir)

```
ID: H-6 | STATUS: FIX-INCOMPLETE (K-1 / RT-25)
KATEQORİYA: Excessive Data Exposure / Enumeration
SEVERITY: 🟠 HIGH | CVSS: 6.5
HÜCUMÇU: C (birbaşa SDK/REST, tətbiq lazım deyil)
```

**FAYL:SƏTİR** `firestore.rules:545` (`usernames` `allow list`),
`firestore.rules:225` (`users` `allow list: if false` — keçilir),
`firestore.rules:220-221` (`users` `allow get`).

**SÜBUT**
```
// firestore.rules:545
allow list: if request.auth != null;          // usernames — sənəd id-si = username, data = {uid}
// firestore.rules:225
allow list: if false;                          // users — "kütləvi scraping bağlandı"
// firestore.rules:220-221
allow get: if request.auth != null &&
  (resource == null || !resource.data.get('blockedUsers', []).hasAny([request.auth.uid]));
```

**İSTİSMAR YOLU**
1. `db.collection('usernames').orderBy(FieldPath.documentId).startAt(['']).limit(1000).get()`
   — client-in öz `.limit(20)`-si rules-da tətbiq oluna bilməz; səhifələmə ilə
   **bütün kolleksiya** çəkilir → tam `username → uid` xəritəsi.
2. Hər uid üçün `users/{uid}` `get` (icazəlidir) → `username`, `firstName`,
   `lastName`, `bio`, `photoUrl`, `country`, `online`, `lastSeen`, `premium`,
   `identityVerified`, `accountPrivacy`, `businessStatus`, **`blockedUsers`**
   (sosial qraf!), **`reportedCount`** (moderasiya siqnalı!), `activeCheckinCount`.
3. `lastSeen` + `online` sahələrini periodik yığmaqla bütün istifadəçi bazasının
   fəaliyyət qrafiki qurulur (koordinat olmadan belə: kim nə vaxt aktivdir).

RT-25-in `allow list: if false` düzəlişi yalnız **bir addım** əlavə etdi; nəticə
eynidir. `ACCEPTED_RISKS.md`-də `usernames.get`-in imzasız açıq qalması qəbul
edilib — amma orada müzakirə edilən `get` (deep link üçün), `list` deyil, və
qəbul səbəbi enumerasiya deyil.

**TƏSİR:** Kütləvi PII/sosial-qraf toplama; `blockedUsers`-in ictimai olması
"X, Y-i bloklayıb" faktını hər kəsə açır (öz-özlüyündə həssas sosial məlumat).

**DÜZƏLİŞ YANAŞMASI**
1. `usernames` `allow list: if false` — username axtarışını `searchUsersByName`
   kimi callable-a köçür (`searchUsersByUsername` üçün server-side ekvivalent).
   Client artıq `searchUsersByName` callable-ını istifadə edir; eyni naxış.
2. `blockedUsers`-i `users/{uid}` sənədindən çıxar. `privateDataRef`-in şərhi
   (`index.ts:69-75`) bunu `scrubFromOthersBlockLists`-in `array-contains`
   sorğusuna görə saxlayır — həmin sorğu artıq Admin SDK-dadır və
   `collectionGroup` indeksi ilə `private/data`-dan da işləyə bilər; client-side
   `_isBlockedPair` isə Prompt 5-dən sonra artıq lazım deyil (rules özü yoxlayır).
3. `reportedCount`-u da `private/data`-ya və ya ayrıca server-only kolleksiyaya köçür.

**REQRESSİYA TESTİ:** `usernames` üzərində `list` sorğusu `permission-denied`
verməlidir; deep link `get` işləməyə davam etməlidir.

---

### H-7 — Moderator real pul hərəkət etdirə bilir (`initiateRefund`, `markPinBoxPayoutPaid`)

```
ID: H-7 | STATUS: PREVIOUSLY-KNOWN (əvvəlki HIGH: RBAC-12) — AÇIQDIR
KATEQORİYA: Privilege Escalation (vertical) / Broken Function Level Authorization
SEVERITY: 🟠 HIGH | CVSS: 7.2
HÜCUMÇU: F
```

**FAYL:SƏTİR**
* `admin-panel/src/lib/auth/permissions.ts:30` — `moderator.moderateVenues: true`
* `admin-panel/src/lib/actions/payments.ts:24-27` — `markPaymentRefunded` → `moderateVenues`
* `admin-panel/src/lib/actions/payments.ts:74-77` — `initiateRefund` → `moderateVenues`
* `admin-panel/src/lib/actions/pinbox-payouts.ts:24-27` — `markPinBoxPayoutPaid` → `moderateVenues`
* `admin-panel/src/app/(protected)/payments/page.tsx:27` — `/payments` səhifəsi `moderateVenues`
* `admin-panel/src/app/(protected)/premium-payments/page.tsx:10` — eyni

**SÜBUT**
```ts
// permissions.ts — moderator matrisi
moderator: { manageUsers: false, moderateVenues: true, manageVenues: false, ... }
// payments.ts:73-77
export async function initiateRefund(paymentId: string): Promise<ActionResult> {
  const admin = await getCurrentAdmin();
  if (!admin || !hasPermission(admin.role, "moderateVenues")) {   // ← moderator KEÇİR
    return { ok: false, error: "forbidden" };
  }
```
`initiateRefund` `payments/{id}.status`-u `refund_pending`-ə çevirir, bu isə
`processPaymentRefund` trigger-ini (`index.ts:4259`) işə salır və o, **Epoint-in
`/reverse` API-si ilə real pulu geri qaytarır** (`index.ts:4299-4305`) və
entitlement-i ləğv edir.

**İSTİSMAR YOLU:** Ələ keçirilmiş (və ya zərərli) moderator hesabı:
`/payments` səhifəsini açır → bütün `completed` ödənişləri görür →
`initiateRefund` çağırır. Hər çağırış real bank əməliyyatıdır. Paralel olaraq
`markPinBoxPayoutPaid` ilə ödənilməmiş venue payout-larını "ödənilib"
işarələyərək məkanların pulunu qeydiyyatdan silə bilər.
Nə MFA, nə məbləğ həddi, nə ikinci təsdiq, nə də limit var. Yalnız
`moderationLogs`-a bir sətir yazılır (`payments.ts:84-89`) — həmin log səhifəsi
də moderator üçün açıqdır (`logs/page.tsx` — heç bir permission gate).

**TƏSİR:** Birbaşa maliyyə itkisi; "Finance" rolunun ayrılmasının bütün məqsədi
pozulur. Prompt sənədində sadalanan rollar (Super Admin, Admin, Moderator,
Finance, Support, Analyst) — **kod bazasında yalnız 2 rol var** (`admin`,
`moderator`), qalan 4 mövcud deyil.

**DÜZƏLİŞ YANAŞMASI**
`PERMISSION_MATRIX`-ə ayrıca `managePayments` (və istəyə görə `viewPayments`)
icazəsi əlavə et; `admin: true`, `moderator: false`. `initiateRefund`,
`markPaymentRefunded`, `markPinBoxPayoutPaid`, `/payments`,
`/premium-payments`, `/pinbox-payouts` — hamısını ona bağla. Əlavə: refund üçün
məbləğ həddi və gündəlik say limiti; hər refund üçün bütün adminlərə
`adminNotifications` yaz.

**REQRESSİYA TESTİ:** moderator sessiyası ilə `initiateRefund` → `forbidden`;
`/payments` → `/dashboard`-a redirect.

---

### H-8 — `/api/health`: autentifikasiyasız Admin SDK endpoint-i

```
ID: H-8 | STATUS: PREVIOUSLY-KNOWN (RBAC-18) — AÇIQDIR
KATEQORİYA: Missing Authentication / Information Disclosure / Resource Exhaustion
SEVERITY: 🟠 HIGH | CVSS: 6.5
HÜCUMÇU: Anonim internet
```

**FAYL:SƏTİR** `admin-panel/src/app/api/health/route.ts:13-26`,
`admin-panel/src/proxy.ts:76` (matcher `api`-ni istisna edir).

**SÜBUT**
```ts
// route.ts:13-26 — heç bir auth
export async function GET() {
  try {
    const result = await getAdminAuth().listUsers(1);      // ← Firebase Auth Admin API
    return NextResponse.json({ ok: true, projectId: process.env.FIREBASE_PROJECT_ID, ... });
  } catch (error) {
    return NextResponse.json({ ok: false, error: error instanceof Error ? error.message : String(error) }, { status: 500 });
  }
}
// proxy.ts:76
matcher: ["/((?!api|_next/static|_next/image|favicon.ico|peakpin-logo.png).*)"],
```

**İSTİSMAR YOLU**
1. `curl https://admin.peakpin.app/api/health` → `{"ok":true,"projectId":"kim-var-73ce9",...}`
   — admin panelin mövcudluğu, layihə id-si və service-account-un işlədiyi təsdiqlənir.
2. Xəta halında **xam Firebase xəta mətni** qaytarılır (daxili konfiqurasiya sızması).
3. Yüklənmiş sorğu axını: hər çağırış bir `listUsers` Admin API sorğusudur.
   Firebase Auth Admin API-nin öz kvotası var (layihə üzrə); doldurulduqda
   **admin panelin özü də daxil olmaq üçün Auth SDK-nı istifadə edə bilmir** →
   effektiv DoS. Rate limit yoxdur, Cloud Run `maxInstances: 3` (`apphosting.yaml`)
   → 3 instansiya doyduqda bütün panel əlçatmaz olur.

**DÜZƏLİŞ YANAŞMASI:** Faylı sil (öz şərhi "Temporary Phase 1 verification
endpoint ... can be deleted once one of those is live" deyir — dashboard artıq
canlıdır). Saxlanılacaqsa: `getCurrentAdmin()` tələb et, `listUsers`-i çıxar
(sadə `{ok:true}` qaytar), xəta mətnini qaytarma.

**REQRESSİYA TESTİ:** `GET /api/health` sessiya olmadan → 401/404.

---

### H-9 — `users/{uid}/private/data` tam client-yazılabilir: `birthDate` kilidi effektiv deyil, `phoneNumber` admin panelə saxta göstərilir

```
ID: H-9 | STATUS: REGRESSION (Prompt 4 / K-1 miqrasiyasının yan təsiri)
KATEQORİYA: Broken Access Control / Data Integrity
SEVERITY: 🟠 HIGH | CVSS: 6.5
HÜCUMÇU: B, C
```

**FAYL:SƏTİR**
* `firestore.rules:351-353` — `match /private/{document} { allow read, write: ... uid == userId }`
* `firestore.rules:334-338` — `touchesLockedUserFields()` hələ də `'birthDate'`-i sadalayır (artıq orada olmayan sahə)
* `admin-panel/scripts/migrate-users-private-data.ts:53-83` — `birthDate`, `email`, `phoneNumber` `PRIVATE_FIELDS`-ə daxil, valideyn sənəddən `FieldValue.delete()` edilir (`:112-113`)
* `functions/src/index.ts:606-618, 954` — `ageYearsFromBirthDate(data.birthDate)` `private/data`-dan gələn dəyəri istifadə edir
* `admin-panel/src/lib/data/users.ts:104-112` — `fetchPhoneNumbers` `private/data.phoneNumber`-i oxuyur
* `functions/src/index.ts:1696-1700` — `blockedByUsers` qurbanın `private/data`-sına yazılır

**SÜBUT**
```
// firestore.rules:334-338 — kilid HƏLƏ birthDate-i qoruyur...
function touchesLockedUserFields() {
  return request.resource.data.diff(resource.data).affectedKeys()
    .hasAny(['premium', 'identityVerified', 'premiumExpiresAt', 'birthDate', 'reportedCount']);
}
// ...amma birthDate artıq `users/{uid}`-də DEYİL:
// migrate-users-private-data.ts:56  "birthDate",   ← PRIVATE_FIELDS
// firestore.rules:352
match /private/{document} { allow read, write: if request.auth != null && request.auth.uid == userId; }
```
`completeOnboarding` (`index.ts:573-580`) `birthDate`-i `privateDataRef(uid)`-ə
yazır — yəni **yeni hesablarda da** sahə client-yazılabilir yerdədir.

**İSTİSMAR YOLU / TƏSİR**
* **(a) Yaşın saxtalaşdırılması:** `set('users/{me}/private/data', {birthDate: <ixtiyari>}, merge)`.
  `buildPublicCandidatePayload` (`index.ts:672`) yaşı bu sahədən hesablayır və
  yaxınlıq/Kəşf et kartlarında göstərir → böyük istifadəçi özünü **yetkinlik
  yaşına çatmamış** kimi göstərə bilər (uşaq təhlükəsizliyi/grooming riski) və
  ya əksinə. `firestore.rules`-un "immutable once set ... A wrong birth date now
  has to go through support" iddiası (`:262-266`) artıq doğru deyil.
* **(b) Ad günü təkliflərinin istismarı:** `computeBirthdayMatches`
  (`index.ts:2281`) `private/data.birthDate`-i oxuyur → istifadəçi hər gün
  `birthDate`-i bugünə qoyaraq ad günü təkliflərini/bildirişlərini təkrar-təkrar
  ala bilər.
* **(c) Admin panelə saxta telefon nömrəsi:** `fetchPhoneNumbers` client-in
  yazdığı dəyəri moderatora "istifadəçinin telefonu" kimi göstərir → dəstək/
  moderasiya qərarlarının manipulyasiyası, başqasının nömrəsinin göstərilməsi.
* **(d) `blockedByUsers`-in özü tərəfindən silinməsi:** `onUserUpdated`
  (`index.ts:1696`) tərs indeksi qurbanın `private/data`-sına yazır; bloklanan
  şəxs onu silərək client-side feed filtrini söndürür → bloklayanın post/story/
  şərhlərini görməyə davam edir.
* **(e)** `fcmTokens`, `knownDeviceSignatures`, `notificationPreferences`,
  `consent`, `loginProvider`, `email` — hamısı client-yazılabilir; `consent`
  (`termsAccepted`, `acceptedAt`, `termsVersion`) hüquqi sübut kimi
  saxlanılırsa, artıq etibarlı deyil.

**DÜZƏLİŞ YANAŞMASI**
`private/{document}` qaydasını sahə səviyyəsində böl:
```
match /private/{document} {
  allow read: if request.auth != null && request.auth.uid == userId;
  allow write: if request.auth != null && request.auth.uid == userId &&
    !request.resource.data.diff(resource.data).affectedKeys().hasAny([
      'birthDate','email','phoneNumber','consent','loginProvider',
      'blockedByUsers','premiumExpiresAt'
    ]);
}
```
(`birthDate`/`phoneNumber`/`consent` yalnız `completeOnboarding` və dəstək
axını ilə; `email` `FirebaseAccountRepository.updateEmail`-in yerinə ayrıca
callable ilə — həmin funksiya `onUserPrivateDataUpdated`-in təhlükəsizlik
bildirişini də mənalı saxlayar). `firestore.rules:337`-dəki artıq işə yaramayan
`'birthDate'` girişini valideyn kiliddən çıxar (yanıltıcıdır).

**REQRESSİYA TESTİ:** `private/data.birthDate`-i dəyişməyə cəhd
`permission-denied` verməlidir; `lat`/`lng`/`ghostModeEnabled`/`visibilityRadius*`
yazılışı işləməyə davam etməlidir.

---

## 6. 🟡 MEDIUM Tapıntılar

### M-1 — `getDiscoverCandidates`: rate limit yoxdur, çağırış başına ~1000 Firestore oxunuşu
`STATUS: NEW | KATEQORİYA: Cost Abuse / DoS | CVSS: 5.3 | HÜCUMÇU: D (VIP hesab)`

**FAYL:** `functions/src/index.ts:724-777` (`enforceRateLimit` YOXDUR, `assertActiveUser` YOXDUR),
`functions/src/index.ts:3261-3270` (`withPrivateData` — N ədəd ayrı `get()`).

```ts
// index.ts:757-758 — world rejimi
query = query.limit(DISCOVER_WORLD_CANDIDATES_LIMIT);   // 500
const merged = await withPrivateData(snap.docs);         // + 500 ayrıca get()
```
Bir çağırış = **~1000 sənəd oxunuşu**. VIP hesab (aylıq abunə) bunu limitsiz
təkrarlaya bilər. Saniyədə 5 çağırış = 18 milyon oxunuş/saat ≈ **$10.8/saat**
(Firestore $0.06/100k oxu) → gündə ~$260, tək bir hesabdan.
`findNearbyUsers`/`previewVenueAudience` eyni `withPrivateData` amplifikasiyasına
malikdir, amma onlarda `nearby` 10/60s limiti var — bu funksiyada heç nə yoxdur.

**DÜZƏLİŞ:** `enforceRateLimit("nearby", uid, 10, 60)` və `assertActiveUser(uid)`
əlavə et (digər iki funksiya ilə eyni scope, ki hücumçu aralarında paylaya
bilməsin). Orta müddətli: `withPrivateData`-nı `getAll()` batch oxunuşuna çevir
(oxu sayı dəyişmir, latency azalır) və ya lat/lng-i `users`-də şifrələnmiş/
yuvarlaqlanmış formada saxlayıb subcollection get-lərini aradan qaldır.

---

### M-2 — `searchUsersByName`: limit/aktivlik yoxlaması yoxdur + prefiks axtarışı sınıqdır
`STATUS: NEW | KATEQORİYA: Rate Limiting / Correctness | CVSS: 4.3`

**FAYL:** `functions/src/index.ts:1018-1050`.
```ts
// index.ts:1030-1035
.orderBy("nameLower")
.startAt(query)
.endAt(`${query}`)          // ← `${query}` = query. PREFIKS DEYİL, DƏQİQ BƏRABƏRLİK.
.limit(SEARCH_BY_NAME_LIMIT)
```
Client-in əvəz etdiyi köhnə sorğu (`firebase_discover_search_repository.dart:32-36`)
`endAt(['$q$_kPrefixRangeEnd'])` istifadə edirdi. Serverdə `` sonluğu
itib → "ras" axtarışı "rasim agayev"-i **tapmır**, yalnız `nameLower` tam
"ras" olan hesabları qaytarır. Ad üzrə axtarış praktikada işləmir.

Eyni funksiyada `enforceRateLimit` və `assertActiveUser` yoxdur — banlanmış hesab
axtarış edə bilir və limitsiz çağırış mümkündür (hər çağırış 20 sənəd oxunuşu).

**DÜZƏLİŞ:** `.endAt(`${query}`)`; `enforceRateLimit("search", uid, 30, 60)`;
`assertActiveUser(uid)`.

---

### M-3 — `joinWaitlist`: rate limit yoxdur → məkan sahibinə bildiriş spam-ı, növbənin doldurulması
`STATUS: NEW | KATEQORİYA: Rate Limiting / Business Logic Abuse | CVSS: 5.3`

**FAYL:** `functions/src/index.ts:2848-2921`. Dublikat yoxlaması yalnız
`phoneNumber` + `status == 'waiting'` üzrədir (`:2882-2884`) — hücumçu hər
çağırışda fərqli (uydurma) nömrə göndərərək limitsiz giriş yarada bilər. Hər
giriş: bir Firestore yazısı + `maintainWaitlistQueuePositions` trigger-inin tam
yenidən hesablanması + məkan sahibinə **FCM push** (`:2911-2919`).

**DÜZƏLİŞ:** `enforceRateLimit("waitlist", uid, 5, 3600)`; əlavə olaraq
`userId` üzrə də dublikat yoxlaması (bir istifadəçi — bir aktiv giriş, nömrədən
asılı olmayaraq); `phoneNumber` formatının E.164-ə uyğunluğunun yoxlanması.

---

### M-4 — `submitVenue`: rate limit yoxdur + `venueId` client tərəfindən seçilir
`STATUS: NEW | KATEQORİYA: Rate Limiting / Resource Squatting | CVSS: 5.3`

**FAYL:** `functions/src/index.ts:4774-4885`, xüsusilə `:4780` (`clientVenueId`),
`:4845` (mövcudluq yoxlaması), `:4879` (`startEpointCheckoutForPayment`).

Hər çağırış: bir `venues` sənədi + bir `payments` sənədi + **Epoint `/request`
API-sinə real çıxış sorğusu**. Limit yoxdur. Hücumçu:
* minlərlə `awaiting_payment` məkan yaradıb admin panelin siyahılarını çirkləndirə,
* Epoint-in merchant hesabına sorğu axını göndərib rate-limit/bloklanmaya səbəb ola,
* `clientVenueId`-ni özü seçdiyi üçün istənilən sənəd id-sini "tuta" bilər
  (gələcək bir legitim id ilə toqquşma; `submitOffer`/`submitVenue`
  `already-exists` verər).

**DÜZƏLİŞ:** `enforceRateLimit("submit-venue", uid, 3, 3600)`;
`venueId`-ni server tərəfdə `db.collection("venues").doc()` ilə yarat (client-in
göndərdiyini qəbul etmə — client onsuz da cavabda `venueId` alır).

---

### M-5 — `appStoreServerNotifications`: rate limit yoxdur, bahalı JWS doğrulaması
`STATUS: NEW | KATEQORİYA: DoS / Cost Abuse | CVSS: 5.3 | HÜCUMÇU: Anonim`

**FAYL:** `functions/src/index.ts:7642-7660`. Endpoint publikdir; hər sorğu üçün
`verifyAppleNotification` tam sertifikat zənciri yoxlaması edir (Production, sonra
Sandbox — yəni **uğursuz sorğu iki dəfə bahalıdır**). `epointWebhook`
(`index.ts:7031-7041`) məhz bu səbəbdən IP üzrə limitlənib və öz şərhində
"unlike `appStoreServerNotifications`'s JWS verification, this one is not an
expensive verification per fake request" deyir — yəni bahalı olanın özündə limit
yoxdur.

**DÜZƏLİŞ:** `epointWebhook` ilə eyni naxış:
`await enforceRateLimit("webhook-apple", req.ip ?? "unknown", 60, 60)` və 429.

---

### M-6 — Məkan sahibi öz məkanına "təsdiqlənmiş" 5 ulduzlu rəy yaza bilir
`STATUS: NEW | KATEQORİYA: Business Logic / Trust Manipulation | CVSS: 5.3 | HÜCUMÇU: E`

**FAYL:** `functions/src/index.ts:2848-2921` (`joinWaitlist` — sahibi istisna
etmir), `firestore.rules:1195-1210` (`waitlist` `allow update` — sahib `seated`
qoya bilir), `firestore.rules:1017-1024` (`reviews` `allow create` →
`hasVerifiedVisit`).

**ZƏNCİR:** sahib → öz məkanının növbəsinə yazılır (`joinWaitlist`, `userId` =
öz uid-i) → sahib kimi həmin girişi `status: 'seated'` edir → `hasVerifiedVisit`
(`firestore.rules:995-998`) ödənir → `reviews/{venueId}_{ownerUid}` yaradılır →
`onReviewWritten` (`index.ts:1838`) `ratingAverage`/`ratingCount`-u yenidən
hesablayır. Eyni yolla sahib istənilən dostunun girişini `seated` edərək
saxta rəy fabriki qura bilər — "Verified Reviews"-in bütün dəyər təklifi bu.

**DÜZƏLİŞ:** `joinWaitlist`-də `venue.ownerId === uid` → `permission-denied`.
`reviews` `create` qaydasına
`request.auth.uid != get(/databases/$(database)/documents/venues/$(request.resource.data.venueId)).data.ownerId`
əlavə et. Dost-fabriki üçün: `seatedAt` ilə `reviews.createdAt` arasında minimum
fasilə və ya sahibin `seated` etdiyi girişlərin gün ərzində say limiti.

---

### M-7 — `reviews` tam siyahılana bilir: uid ↔ məkan ziyarət tarixçəsi hər kəsə açıq
`STATUS: PREVIOUSLY-KNOWN (INFRA-8, qismən düzəldilib) | KATEQORİYA: Location Privacy | CVSS: 5.3`

**FAYL:** `firestore.rules:1013` (`allow read: if request.auth != null`),
sənəd id-si `{venueId}_{userId}` (`firestore.rules:1018`).

Əvvəlki audit `if true`-nu `request.auth != null`-a endirib — amma məsələ
autentifikasiya deyil, **enumerasiyadır**. Rəyin mövcudluğu `hasVerifiedVisit`
sayəsində **fiziki ziyarətin sübutudur**. Hər hansı daxil olmuş istifadəçi
`db.collection('reviews').get()` ilə bütün "kim hansı məkanda fiziki olub"
qrafını çəkə bilər (H-6 ilə birləşdikdə uid → ad/foto). Ghost Mode buna heç
toxunmur.

**DÜZƏLİŞ:** `allow get: if request.auth != null; allow list: if false;` —
məkan səhifəsinin rəy siyahısını `venueId` üzrə server-side callable ilə ver
(və ya `list`-i yalnız `where('venueId','==',X)` şəklində provable et:
`allow list: if request.auth != null && request.query.limit <= 50` + `venueId`
bərabərlik filtri tələb edən qayda strukturu). Uzunmüddətli həll BACKLOG #5
(təsadüfi review id) bunu da bağlayır.

---

### M-8 — `epointWebhook` tam decoded payload-u qalıcı olaraq loglayır
`STATUS: NEW | KATEQORİYA: Sensitive Data in Logs | CVSS: 4.9 | HÜCUMÇU: H`

**FAYL:** `functions/src/index.ts:7062` — `logger.info("epointWebhook: decoded payload", { decoded })`.

Payload-un tam sxemi sənədləşdirilməyib (kodun öz şərhi bunu etiraf edir), yəni
orada kart maskası (`card_mask`), `card_name`, RRN, `transaction`, `order_id`,
məbləğ və potensial olaraq müştəri identifikatorları ola bilər. Bu, Cloud
Logging-də **default 30 gün** (və ya konfiqurasiyaya görə daha uzun) saxlanılır
və `roles/logging.viewer` olan hər kəsə açıqdır (təhdid modeli H).
`logCallableInvocation` (`index.ts:97-104`) da hər `completeOnboarding`/
`findNearbyUsers` çağırışı üçün uid loglayır — birlikdə "kim nə vaxt harada
axtarış edib" izini yaradır.

**DÜZƏLİŞ:** Şərhdə deyildiyi kimi, real webhook müşahidə edildikdən sonra bu
sətri **yalnız istifadə olunan sahələrə** (`order_id`, `status`, `code`,
`transaction`) endir. Bunu launch-dan əvvəl et — istehsalatda ilk real ödənişlə
birlikdə həssas data loglanmağa başlayacaq. `logCallableInvocation` üçün log
retention-u qısalt və ya uid-i heşlə.

---

### M-9 — `superseded` sənədin qəbulu ikiqat ödənişə gətirir (avtomatik refund yoxdur)
`STATUS: FIX-INCOMPLETE (K-10) | KATEQORİYA: Payment Logic | CVSS: 4.3`

**FAYL:** `functions/src/index.ts:6408-6410` (`superseded` də emal olunur),
`functions/src/index.ts:4987-5002` (`supersedeOtherPendingPayments`),
`functions/src/index.ts:6614-6621` (`boost_fee` — stack ETMİR, üzərinə yazır).

**Ssenari:** sahib boost checkout-u açır (P1, 6 AZN), şəbəkə kəsilir, yenidən
açır (P1 → `superseded`, P2 yaradılır). Hər iki linki ödəyir (Epoint-də köhnə
link canlıdır — `ACCEPTED_RISKS.md`-də sənədləşdirilib).
* P1 webhook-u: `superseded` → **emal olunur** → `boostedUntil = now + 18s`.
* P2 webhook-u: `pending` → emal olunur → `boostedUntil = now + 18s` (**üzərinə
  yazır, stack etmir**).
* Nəticə: 12 AZN alınıb, 18 saat boost verilib.

K-10 "pul udulur, xidmət verilmir" problemini düzəltdi, amma yerinə "iki dəfə
ödə, bir dəfə al" problemi qoydu. `venue_premium` (`:6640-6642`) və
`venue_subscription` (`:6584-6586`) stack etdiyi üçün onlarda problem yoxdur —
**yalnız `boost_fee`** üzərinə yazır.

`honoredAfterSupersede` bayrağı yazılır, amma admin panelin ödəniş siyahısında
ona görə filtr yoxdur (`admin-panel/src/lib/data/payments.ts:60-64` şərhi bunu
"Prompt 9 scope" kimi qeyd edir) → heç kim bu halı görmür.

**DÜZƏLİŞ:** `boost_fee` budağını `venue_premium` kimi stack et
(`base = boostedUntil > now ? boostedUntil : now`) — ödənilən hər saat verilir.
Və ya: `wasSuperseded === true` olduqda avtomatik `status: 'refund_pending'`
yaz (mövcud `processPaymentRefund` axını hər şeyi edir). Admin panelə
`honoredAfterSupersede` filtri əlavə et.

---

### M-10 — Storage `contentType.matches('image/.*')` SVG-yə icazə verir
`STATUS: NEW | KATEQORİYA: Content Injection | CVSS: 4.3`

**FAYL:** `storage.rules:18, 39, 87, 101, 111, 121, 160, 172, 196`.

`image/svg+xml` bu naxışa uyğun gəlir. Firebase Storage faylı saxlanılan
`Content-Type` ilə `inline` olaraq təqdim edir → `firebasestorage.googleapis.com`
mənşəyində JavaScript icra edən SVG. `ACCEPTED_RISKS.md`-nin "magic-byte MIME"
maddəsi **fərqli bir problemdir** (baytların formatı) — bu, elan edilmiş
Content-Type-ın allowlist-i olmamasıdır və Storage Rules-da tamamilə həll edilə
biləndir.

**DÜZƏLİŞ:**
`request.resource.contentType in ['image/jpeg','image/png','image/webp','image/heic']`
(video üçün `['video/mp4','video/quicktime']`, audio üçün `['audio/mpeg','audio/m4a','audio/aac']`).
~1 saatlıq iş, heç bir legitim axını pozmur (tətbiq yalnız kamera/qalereya
şəkilləri yükləyir).

---

### M-11 — `forwardChatMedia`: hədəf çat mövcud deyilsə üzvlük yoxlaması atlanır; server-side kopyalama Storage abuse-unu gücləndirir
`STATUS: NEW | KATEQORİYA: Improper Authorization / Cost Abuse | CVSS: 4.3`

**FAYL:** `functions/src/index.ts:1364-1366`.
```ts
if (!sourceChatSnap.exists || !isParticipant(sourceChatSnap) ||
    (targetChatSnap.exists && !isParticipant(targetChatSnap))) {   // ← mövcud DEYİLSƏ yoxlama yoxdur
  throw new HttpsError("permission-denied", ...);
}
```
Hücumçu mövcud olmayan `chatId` verə bilər → fayl `chat_photos/{ixtiyari}/{uid}/{messageId}`
yoluna kopyalanır. Daha vacibi: **kopyalama server tərəfdədir** — hücumçu bir
dəfə 50 MB video yükləyib sonra onu yükləmə trafiki sərf etmədən 30 dəfə/600s
kopyalaya bilər (10 dəqiqədə 1.5 GB, gündə ~216 GB). `ACCEPTED_RISKS.md`-dəki
"per-user kvota yoxdur" maddəsi bu amplifikasiyanı nəzərə almır.

**DÜZƏLİŞ:** `targetChatSnap.exists` şərtini çıxar — hədəf çat mövcud olmalı VƏ
çağıran onun iştirakçısı olmalıdır (forward axını onsuz da mövcud söhbətə
göndərir). `messageId`-nin `chats/{chatId}/messages` altında hələ mövcud
olmadığını yoxla. Kopyalama üçün ayrıca, daha sıx limit (məs. 10/3600s).

---

### M-12 — `EpointTokenWidgetScreen` WebView-ində naviqasiya allowlist-i yoxdur, JS körpüsü hər mənşəyə yenidən yeridilir
`STATUS: NEW | KATEQORİYA: Mobile / WebView Security | CVSS: 4.3`

**FAYL:** `lib/core/payments/epoint_token_widget_screen.dart:39-60`.
```dart
..setJavaScriptMode(JavaScriptMode.unrestricted)
..addJavaScriptChannel('PeakPinBridge', onMessageReceived: _onBridgeMessage)
..setNavigationDelegate(NavigationDelegate(
    onPageFinished: (_) {                       // ← HƏR səhifə üçün, mənşədən asılı olmayaraq
      _controller.runJavaScript('''window.addEventListener('message', ...
        PeakPinBridge.postMessage(JSON.stringify(event.data)); ...''');
    },
    // ← onNavigationRequest YOXDUR
))
```
Ödəniş WebView-i istənilən mənşəyə keçə bilər və `PeakPinBridge` orada da mövcud
olur. `epoint_card_checkout_screen.dart:51-60` ən azı redirect prefikslərini
tutur, amma o da domen allowlist-i tətbiq etmir. Körpünün hazırkı funksiyası
məhduddur (yalnız ekranı bağlayır), amma bu, ödəniş ekranında phishing/
redirect üçün açıq qapıdır.

**DÜZƏLİŞ:** Hər iki ekrana `onNavigationRequest` əlavə et: yalnız
`https://epoint.az`, `https://*.epoint.az`, `https://admin.peakpin.app/payment/`
və Apple/Google Pay-in tələb etdiyi mənşələr `NavigationDecision.navigate`
alsın; qalanı `prevent` + `url_launcher` ilə xarici brauzerə çıxarılsın.
JS yeridilməsini yalnız gözlənilən mənşədə et.

---

### M-13 — Admin paneldə heç bir təhlükəsizlik başlığı yoxdur (CSP / HSTS / X-Frame-Options / Referrer-Policy)
`STATUS: NEW | KATEQORİYA: Security Misconfiguration | CVSS: 4.3`

**FAYL:** `admin-panel/next.config.ts:1-11` — `headers()` konfiqurasiyası yoxdur.

Nəticələr: clickjacking (admin əməliyyat düymələri iframe-də), XSS baş verərsə
heç bir CSP azaldıcısı, `Referrer-Policy` default olduğu üçün C-2-nin
`emergencyToken`-i xarici sub-resurs sorğularında sıza bilər.

**DÜZƏLİŞ:**
```ts
async headers() {
  return [{ source: "/:path*", headers: [
    { key: "Content-Security-Policy", value: "default-src 'self'; img-src 'self' data: https://firebasestorage.googleapis.com; connect-src 'self' https://*.googleapis.com; frame-ancestors 'none'" },
    { key: "Strict-Transport-Security", value: "max-age=63072000; includeSubDomains; preload" },
    { key: "X-Frame-Options", value: "DENY" },
    { key: "X-Content-Type-Options", value: "nosniff" },
    { key: "Referrer-Policy", value: "no-referrer" },
    { key: "Permissions-Policy", value: "camera=(), microphone=(), geolocation=()" },
  ]}];
}
```

---

### M-14 — Android: `allowBackup` default `true`, `dataExtractionRules` yoxdur
`STATUS: NEW | KATEQORİYA: Mobile Data Protection | CVSS: 4.0`

**FAYL:** `android/app/src/main/AndroidManifest.xml:27-31` — `<application>`
elementində nə `android:allowBackup`, nə `android:fullBackupContent`, nə də
`android:dataExtractionRules` var.

Nəticə: tətbiqin `shared_prefs` (profil keşi — `photoUrl`, `bio`, `gender`,
`country`, `city`), Firebase Auth-un davamlı sessiya faylları və digər daxili
faylları Google Drive avtomatik yedəkləməsinə və (uyğun cihaz/API səviyyəsində)
`adb backup`-a daxil olur. `flutter_secure_storage` (email/birthDate) Keystore
ilə qorunur, qalanı isə açıq.

**DÜZƏLİŞ:** `android:allowBackup="false"` (ən sadə) və ya
`android:dataExtractionRules="@xml/data_extraction_rules"` +
`android:fullBackupContent="@xml/backup_rules"` ilə `shared_prefs` və Firebase
Auth qovluqlarını istisna et.

---

### M-15 — `posts` / `stories` / `comments` create qaydalarında sahə validasiyası yoxdur
`STATUS: NEW | KATEQORİYA: Mass Assignment / Missing Input Validation | CVSS: 4.3`

**FAYL:** `firestore.rules:1601` (`posts` create), `firestore.rules:1523`
(`stories` create), `firestore.rules:1617` (`comments` create).

```
allow create: if request.auth != null && request.auth.uid == request.resource.data.userId;
```
Heç bir `keys().hasOnly(...)`, heç bir ölçü limiti, heç bir server-only sahə
kilidi. Nəticələr:
* `likesCount`/`commentsCount` yaradılış anında istənilən dəyərlə (məs. 999999)
  qoyula bilər — `bumpPostCounter` (`index.ts:1391-1405`) yalnız delta tətbiq
  edir, mütləq dəyəri yenidən hesablamır → **qalıcı saxta engagement**.
* `authorIsPublic: true` client tərəfindən qoyula bilir; `onPostCreated`
  (`index.ts:2436-2437`) onu düzəldir, amma **trigger gecikməsi (~1-2 s) ərzində**
  private hesabın postu ictimai kəşf şəbəkəsində görünür.
* `caption` və `comments.text` üçün ölçü limiti yoxdur (müqayisə üçün: chat
  mesajında 2000, `bio`-da 200, `reason`-da 1000 limit var — Prompt 8 / RT-2
  bu üç yeri əhatə etməyib).
* `posts.mediaUrl` ixtiyari xarici URL ola bilər (H-5).
* `isActiveUser` yoxdur (ACCEPTED_RISKS-də qəbul edilib, amma C-3 ilə birləşəndə
  onboarding etməmiş hesab da post yarada bilir).

**DÜZƏLİŞ:** Hər üç qaydaya `request.resource.data.keys().hasOnly([...])`,
sayğac sahələrinin `== 0` olması şərti, `caption`/`text` üçün ölçü limiti
(1000/500) və `authorIsPublic`-in create-də qadağan edilməsi.

---

### M-16 — Chat media məxfiliyi Storage Rules-a əsaslanır, amma `mediaUrl` autentifikasiyasız bearer URL-dir
`STATUS: NEW | KATEQORİYA: Broken Access Control (arxitektural) | CVSS: 4.3`

**FAYL:** `storage.rules:34-45` (`chat_photos` read = yalnız iştirakçılar),
`extensions/storage-resize-images.env:41-52` (öz şərhi mexanizmi təsvir edir),
`functions/src/index.ts:1375-1377` (`forwardChatMedia` yeni token yaradır).

`storage.rules`-un chat media üçün oxu məhdudiyyəti yalnız **Firebase SDK**
yolunu qoruyur. Tətbiq `getDownloadURL()`-un qaytardığı
`...?alt=media&token=<uuid>` URL-ini Firestore mesaj sənədinə yazır və
`Image.network` ilə yükləyir — bu URL **heç bir Firebase Auth sessiyası tələb
etmir**. Bir dəfə sızan URL (screenshot, log, keş, üçüncü tərəf klaviatura,
şəbəkə vasitəçisi) əbədi ictimaidir və bloklama/silmə onu ləğv etmir (yalnız
faylın özünün silinməsi və ya token rotasiyası edir).

Komanda bu mexanizmi bilir — `identity_verifications` üçün **qəsdən URL yerinə
PATH** saxlanılır (`firestore.rules:1112-1113` şərhi). Eyni mühakimə chat
mediasına tətbiq edilməyib.

**DÜZƏLİŞ:** Chat mediasını da path kimi saxla; göstərmə anında qısa ömürlü
(5-15 dəq) signed URL verən callable (`getChatMediaUrl`) əlavə et. Bu, orta
həcmli iş olduğu üçün launch-blokerı deyil, amma BACKLOG-a düşməlidir.
Qısa müddətdə: `deleteAccount`/`deleteMessageForEveryone` axınlarında faylın
həqiqətən silindiyinin təsdiqi (hazırda `catch {}` uddurur).

---

## 7. 🔵 LOW / ⚪ INFO Tapıntılar

### L-1 — Haqq cədvəllərində `in` operatoru prototip açarlarını qəbul edir
`STATUS: NEW | THEORETICAL | 🔵 LOW`
**FAYL:** `functions/src/index.ts:5027` (`hours in BOOST_FEE_BY_HOURS`),
`:7089` (`months in VENUE_PREMIUM_FEE_BY_MONTHS`), `:7508` (`productId in VIP_PRODUCT_DURATIONS_MS`).
`"toString" in {6:2,12:4,18:6}` → `true` (Object.prototype-dan). Nəticədə
`amount` bir funksiya olur və Firestore `set()` "Cannot use type function"
xətası verir — yəni **istismar edilə bilmir**, pulsuz boost alınmır. Yenə də
allowlist yoxlaması `Object.prototype.hasOwnProperty.call(TABLE, key)` və ya
`typeof TABLE[key] === "number"` ilə edilməlidir.

### L-2 — `findNearbyUsers`-in taraması ən KÖHNƏ 200 girişi seçir
`STATUS: NEW | KATEQORİYA: Correctness (miqyas) | 🔵 LOW`
**FAYL:** `functions/src/index.ts:851-856`.
```ts
.where("lastSeen", ">", Timestamp.fromMillis(Date.now() - NEARBY_LAST_SEEN_WINDOW_MS))  // 15 dəq
.limit(NEARBY_CANDIDATE_SCAN_LIMIT)   // 200
```
Firestore bərabərsizlik filtrində implicit `orderBy(lastSeen, asc)` tətbiq edir →
15 dəqiqəlik pəncərənin **ən köhnə** 200 girişi seçilir. Sonra
`isRecentlyOnlineServer` (`:788-791`) yalnız son **90 saniyəni** qəbul edir →
istifadəçi sayı artdıqca funksiya sistematik olaraq boş nəticə qaytarmağa
başlayacaq. Təhlükəsizlik deyil, amma "yaxınlıq" xüsusiyyətinin miqyasda sakit
sıradan çıxmasıdır. **Düzəliş:** `.orderBy("lastSeen", "desc")` əlavə et
(indeks tələb edir) və ya pəncərəni 90 s-ə endir.

### L-3 — `peakpin://` custom sxemi başqa tətbiq tərəfindən mənimsənilə bilər
`STATUS: NEW | 🔵 LOW`
**FAYL:** `android/app/src/main/AndroidManifest.xml:97-103`,
`ios/Runner/Info.plist:75-78`.
Custom sxemlər eksklüziv deyil (Android disambiguation, iOS "ilk quraşdırılan
qalib"). Hazırda sxem yalnız profil linki daşıyır
(`lib/core/navigation/deep_link_handler.dart:51`) — həssas token yoxdur, ona görə
təsir aşağıdır. **Qeyd:** Manifest-in şərhi (`:90-95`) bu sxemi "Firebase Email
Link sign-in" üçün olduğunu deyir, lakin kod bazasında
`signInWithEmailLink`/`sendSignInLinkToEmail` **ümumiyyətlə yoxdur** (grep: 0
nəticə) — şərh köhnəlmişdir və gələcəkdə kimisə yanlış istiqamətə yönəldə bilər.

### L-4 — Client-side açarlar (gözlənilən, amma məhdudiyyət yoxlanmalıdır)
`STATUS: NEW | ⚪ INFO`
* `lib/firebase_options.dart:53,61` — `AIza***REDACTED***` (Firebase Web API
  açarları — dizayn etibarı ilə ictimaidir, amma GCP Console → Credentials-də
  **API restriction** tətbiq edilməlidir: yalnız Identity Toolkit, Firestore,
  Storage, FCM).
* `android/.../AndroidManifest.xml:40` — Branch key (`key_live_***REDACTED***`) —
  client açarıdır, Branch Secret düzgün şəkildə yoxdur.
* `admin-panel/apphosting.yaml:20` — `NEXT_PUBLIC_FIREBASE_API_KEY`
  (`AIza***REDACTED***`) — ictimai.
* `android/key.properties`, `android/keystore/*.jks`, `admin-panel/.env.local`
  — **git-də izlənmir** (`git ls-files` təsdiqlədi). ✅
* **Git tarixçəsi taraması:** `git log -p --all` üzərində private key / service
  account JSON / Resend / Epoint açar naxışları üçün axtarış — **heç bir real
  sirr tapılmadı**, yalnız `defineSecret()` adları və şərhlər. ✅

### L-5 — BACKLOG #10-un 3 `resource == null` boşluğu hələ açıqdır
`STATUS: PREVIOUSLY-KNOWN | ⚪ INFO`
`firestore.rules:1064` (`payments` read), `:1112` (`identityVerifications` read),
`:1396` (`pinboxOrders` read). BACKLOG-un təhlili doğrudur (bu üç sənəd növü
praktikada silinmir), risk deyil, ~1 saatlıq təmizlikdir.

### I-1 — `APPLE_APP_STORE_ID` təyin edilməyib → iOS IAP Production doğrulaması işləməyəcək
`STATUS: NEW | ⚪ INFO (iOS launch olunmur)`
**FAYL:** `functions/src/index.ts:7392`. `undefined` olduğu üçün
`verifyAppleTransaction(..., environment: "Production")` `INVALID_APP_IDENTIFIER`
ilə uğursuz olacaq → `catch` Sandbox-a keçəcək → `config/iapTesters`-də
olmayan hər kəs `failed-precondition` alacaq. Yəni **iOS-da VIP alışı heç kimə
işləməyəcək**. Təhlükəsizlik baxımından fail-closed (doğru istiqamət), amma
iOS buraxılışından əvvəl mütləq doldurulmalıdır.

### I-2 — `storage.rules`-un `allow write` qaydaları silməni bloklayır
`STATUS: NEW | ⚪ INFO`
`profile_photos` (`storage.rules:16-20`), `stories` (`:157-165`), `posts`
(`:170-178`), `{venue,offer,pinbox}_photos`, `event_covers` — hamısında
`allow write` şərti `request.resource.size < N` yoxlayır. Silmə əməliyyatında
`request.resource` `null`-dur → ifadə xəta verir → **silmə həmişə rədd edilir**.
Şərhlər "A user can only upload/replace/delete their OWN photo" deyir, amma
delete işləmir. Chat yollarında bu düzgün ayrılıb (`allow create` + ayrıca
`allow delete`). Funksional; təhlükəsizlik baxımından fail-closed.

### I-3 — Köhnə flat Storage yolları hələ oxuna bilir
`STATUS: PREVIOUSLY-KNOWN | ⚪ INFO`
`storage.rules:136-149` — keçid bloku. `migrate-storage-owner-paths.ts` icra
edildiyi təsdiqlənməyib. Yalnız `read`, `write` yoxdur → yeni risk yaratmır,
amma miqrasiyadan sonra silinməlidir.

### I-4 — Zəng sənədləri və `calls` alt-kolleksiyaları heç vaxt silinmir
`STATUS: PREVIOUSLY-KNOWN (ACCEPTED_RISKS B4) | ⚪ INFO` — qəbul edilmiş, hələ açıqdır.

---

## 8. YENİ TAPINTILAR (yalnız `STATUS: NEW`)

| ID | Başlıq | Severity |
|---|---|---|
| C-1 | İxtiyari Storage obyektinin silinməsi (`onChatDeleted` + `mediaUrl`) | 🔴 CRITICAL |
| C-3 | Onboarding qapısının client-də keçilməsi (18+ / e-poçt / username) | 🔴 CRITICAL |
| H-1 | Trilaterasiya: xam `distanceMeters` | 🟠 HIGH |
| H-2 | `previewVenueAudience` ixtiyari koordinat oraklı | 🟠 HIGH |
| H-3 | `chats.participants` dəyişdirilə bilir (blok bypass) | 🟠 HIGH |
| H-4 | Birtərəfli çat + media məhvi | 🟠 HIGH |
| H-5 | İxtiyari xarici `photoUrl`/`imageUrl` | 🟠 HIGH |
| M-1 | `getDiscoverCandidates` limitsiz, 1000 oxu/çağırış | 🟡 MEDIUM |
| M-2 | `searchUsersByName` limitsiz + sınıq prefiks | 🟡 MEDIUM |
| M-3 | `joinWaitlist` limitsiz | 🟡 MEDIUM |
| M-4 | `submitVenue` limitsiz + client `venueId` | 🟡 MEDIUM |
| M-5 | `appStoreServerNotifications` limitsiz JWS | 🟡 MEDIUM |
| M-6 | Sahibin öz məkanına "təsdiqlənmiş" rəyi | 🟡 MEDIUM |
| M-8 | Webhook payload-unun tam loglanması | 🟡 MEDIUM |
| M-10 | SVG `image/.*` allowlist-ində | 🟡 MEDIUM |
| M-11 | `forwardChatMedia` hədəf yoxlaması + kopyalama abuse | 🟡 MEDIUM |
| M-12 | Ödəniş WebView-ində naviqasiya allowlist-i yox | 🟡 MEDIUM |
| M-13 | Admin paneldə security header yox | 🟡 MEDIUM |
| M-14 | Android `allowBackup` default | 🟡 MEDIUM |
| M-15 | `posts`/`stories`/`comments` create validasiyasız | 🟡 MEDIUM |
| M-16 | Chat media bearer URL-ləri | 🟡 MEDIUM |
| L-1, L-2, L-3, I-1, I-2 | (yuxarıda) | 🔵/⚪ |

**Cəmi NEW: 27** (bunlardan **2 CRITICAL**, 5 HIGH).

---

## 9. REQRESSİYALAR VƏ YARIMÇIQ DÜZƏLİŞLƏR

### REGRESSION (2)

**R-1 = H-9 — `birthDate` kilidinin itməsi.**
Prompt 2/10-da `firestore.rules`-un `touchesLockedUserFields()`-inə `'birthDate'`
əlavə edildi və şərhdə "immutable once set, so neither a compromised nor a
well-meaning client can back-date past the age check after the fact"
(`firestore.rules:262-266`) yazıldı. Prompt 4-ün miqrasiyası isə `birthDate`-i
`users/{uid}/private/data`-ya köçürdü (`migrate-users-private-data.ts:56`), o yer
isə `allow read, write: if ... uid == userId` (`firestore.rules:352`) —
**tam client-yazılabilir**. Kilid indi mövcud olmayan bir sahəni qoruyur; yaş
dəyişməzliyi qarantiyası itib. Eyni yolla `email`, `phoneNumber`, `consent`,
`loginProvider` da qorumasız qaldı.

**R-2 = M-2 — `searchUsersByName`-in prefiks axtarışının itməsi.**
Prompt 5-də client-in `users.orderBy('nameLower').startAt(q).endAt('$q')`
sorğusu server callable-ına köçürüldü, amma köçürmə zamanı `` sonluğu
düşdü (`functions/src/index.ts:1032-1033`) → ad üzrə prefiks axtarışı işləmir.
Funksional reqressiyadır (təhlükəsizlik deyil), amma köçürmənin özünün
məqsədini pozur.

### FIX-INCOMPLETE (4)

**F-1 = H-6 — RT-25 (`users` `allow list: if false`).**
`users` üzərində birbaşa list bağlandı, amma `usernames` `allow list`
(`firestore.rules:545`) eyni nəticəni bir addım artıqla verir. K-1-in "kütləvi
scraping" məqsədi bağlanmayıb.

**F-2 = M-9 — K-10 (`superseded` ödənişlər).**
"Pul udulur, xidmət verilmir" bağlandı; yerinə `boost_fee` üçün "iki dəfə ödə,
bir dəfə al" açıldı (`index.ts:6614-6621` stack etmir). `honoredAfterSupersede`
yazılır, amma admin paneldə görünmür.

**F-3 = C-3 — K-13 (18+ server yoxlaması).**
Server yoxlaması **düzgün əlavə edilib** (`index.ts:470-472`) — amma client onun
nəticəsini udur, yəni tətbiq davranışı düzəlişdən əvvəlki ilə eynidir. Bu, "kod
yazıldı, effekt yoxdur" halının ən təmiz nümunəsidir.

**F-4 = qismən K-3 (blok mexanizmi).**
Rules səviyyəsində blok real oldu (`isBlockedPair` — profil oxu, chat create,
mesaj, zəng). Qalan boşluqlar:
* H-3 — `chats` `update` yolu ilə tam bypass;
* `posts`/`stories`/`comments` **oxu** qaydalarında blok yoxlaması yoxdur —
  bloklanan şəxs bloklayanın ictimai postlarını/story-lərini oxumağa davam edir
  (`firestore.rules:1595`, `:1519`);
* `blockedByUsers` tərs indeksi qurbanın client-yazılabilir `private/data`-sındadır
  (H-9d) → client-side filtr söndürülə bilər.

---

## 10. ƏVVƏLKİ AUDİTİN 13 CRITICAL-ININ VƏZİYYƏTİ

| # | Başlıq | Vəziyyət | Sübut |
|---|---|---|---|
| **K-1** | `users` tam oxunaqlı — PII + GPS + push token | 🟡 **QİSMƏN** | PII `private/data`-ya köçüb (`firestore.rules:351-353`), `list` bağlanıb (`:225`), koordinat server-side filtrlənir. AMMA: `usernames` list ilə tam enumerasiya qalır (H-6), `blockedUsers`/`reportedCount` hələ ictimai (`:220`), `distanceMeters` ilə xam koordinat bərpa edilir (H-1), `private/data` client-yazılabilir (H-9) |
| **K-2** | Mesaj sahələrinin yenidən yazılması | 🟢 **BAĞLANDI** | `firestore.rules:772-780` — `hasOnly(['deliveredAt','readAt'])` və ya yalnız `deletedFor`-a öz uid-ini əlavə etmə |
| **K-3** | Blok mexanizmi fiktivdir | 🟡 **QİSMƏN** | `isBlockedPair` (`firestore.rules:42-44`) profil oxu (`:220`), chat create (`:668`), mesaj (`:751`), zəng (`:816`) üzərində real. Qalan: H-3 (participants), feed oxu qaydalarında blok yoxdur, `blockedByUsers` self-yazılabilir |
| **K-4** | `activeCheckins` real-time izləmə | 🟢 **BAĞLANDI** | `firestore.rules:1233-1236` — oxu yalnız istifadəçi + məkan sahibi; `activeCheckinVenueId` `private/data`-ya köçüb; `activeCheckinCount` server-computed (`onActiveCheckinCreated/Deleted`) |
| **K-5** | `follows.status` client-dən qəbul edilir | 🟢 **BAĞLANDI** | `firestore.rules:600-607` — `accepted` yalnız `accountPrivacy != 'private'` olduqda |
| **K-6** | Storage sahiblik yoxlaması yoxdur | 🟢 **BAĞLANDI** | `storage.rules:82-131` — bütün yollar `{ownerUid}` seqmentli; köhnə flat yollar yalnız read (`:136-149`) |
| **K-7** | App Check 25/25-də söndürülüb + rate limiting sıfır | 🟠 **AÇIQDIR (qismən)** | App Check hələ `false` (28/28 funksiyada) — **qəsdən, sənədləşdirilib** (`index.ts:27-40`). Rate limiting **12 nöqtədə var**, **9 callable-da yoxdur** (`getDiscoverCandidates`, `searchUsersByName`, `joinWaitlist`, `submitVenue`, `submitOffer`, `updateVenue/Offer/PinBox`, `resubmit*`, `generatePinBoxQrToken`, `submitIdentityVerification`, `deleteAccount`, `appStoreServerNotifications`) |
| **K-8** | Reputasiya sayğaclarının saxtalaşdırılması | 🟢 **BAĞLANDI** | `firestore.rules:344-350` — `hasOnly(['reportedCount'])` + `== köhnə + 1`; `starCount`/`heartCount`/`dislikeCount` silinib; `reportedCount` sahib üçün də kilidli (`:337`) |
| **K-9** | PinBox-da venue sahibliyi yoxlanmır | 🟢 **BAĞLANDI** | `firestore.rules:1354-1355` — `request.auth.uid == get(venues/$(venueId)).data.ownerId` |
| **K-10** | Köhnəlmiş checkout linkləri — pul udulur | 🟡 **QİSMƏN (F-2)** | `index.ts:6408-6410` `superseded`-i emal edir → pul artıq udulmur. Yeni problem: `boost_fee` ikiqat ödənişdə stack etmir (M-9) |
| **K-11** | Refund imtiyazı geri almır | 🟢 **BAĞLANDI** | `processPaymentRefund` (`index.ts:4259-4400`) — `boost_fee` → `boostedUntil` təmizlənir, `venue_premium` → geri sarılır, `pinbox_order` → `venuePayouts` `cancelled`/mənfi sətir; Epoint `/reverse` real çağırılır |
| **K-12** | `emergencyToken` URL-də | 🔴 **AÇIQDIR** | `login/page.tsx:71-84` + `mint-emergency-token.ts:86` + `package.json:12` dəyişməyib → **C-2** |
| **K-13** | 18+ server yoxlaması yoxdur | 🔴 **QİSMƏN — effektiv deyil** | Server yoxlaması var (`index.ts:470-472`), amma client onu udur → **C-3** |

**Yekun: 7 tam bağlandı, 4 qismən, 2 açıqdır.**

Əvvəlki HIGH-lardan seçmə vəziyyət:
* RBAC-12 (moderator ödəniş əməliyyatları) — **AÇIQDIR** (H-7)
* RBAC-18 (`/api/health`) — **AÇIQDIR** (H-8)
* AUTH-3 (`revokeRefreshTokens`) — **BAĞLANDI** (`index.ts:325`, `admins.ts:101`)
* AUTH-6 (rezerv username) — **BAĞLANDI** (`index.ts:390-414` + rules)
* AUTH-15 (`requestId` üzərinə yazma) — **BAĞLANDI** (`index.ts:4118-4126`)
* INFRA-5 (məzmun kilidi) — **BAĞLANDI** (rules + `updateVenue`/`updateOffer`/`updatePinBox`), amma xarici URL-lə keçilir (H-5)
* INFRA-8 (`reviews` açıq oxu) — **QİSMƏN** (M-7)
* INFRA-40 (plaintext email/birthDate) — **BAĞLANDI** (`flutter_secure_storage`)
* PAY-5 (TOCTOU) — **BAĞLANDI** (`index.ts:6396-6404` tranzaksiya daxilində)
* PAY-16 (kart-testinq üçün rate limit) — **BAĞLANDI** (`checkout` 10/600s, 8 funksiyada paylaşılan scope)
* PAY-25 (bir qəbzlə çoxlu VIP) — **BAĞLANDI** (`claimIapSubscriptionOwnership`, `index.ts:7440-7477`)
* RT-2 (mesaj ölçüsü) — **QİSMƏN** (chat 2000 ✅, `posts.caption`/`comments.text` hələ limitsiz — M-15)
* RT-5/RT-6 (`declined`, `followersOnly`) — **BAĞLANDI** (`firestore.rules:753-754`, `:48-56`), amma H-3 ilə keçilir
* INFRA-32/34/35/36 (Maps açarı, R8, root detection, pinning) — **AÇIQDIR**, ACCEPTED_RISKS/BACKLOG-da

---

## 11. QƏBUL EDİLMİŞ RİSKLƏRİN YENİDƏN QİYMƏTLƏNDİRİLMƏSİ

`docs/ACCEPTED_RISKS.md`-dəki hər maddə üçün: qərar hələ əsaslıdırmı?

| Maddə | Qərar hələ əsaslıdır? | Yeni məlumat |
|---|---|---|
| `usernames.get` imzasız açıq | ⚠️ **QİSMƏN — yenidən baxılmalı** | `get` üçün əsaslandırma (deep link) doğrudur və dəyişməyib. AMMA sənəd `list`-i müzakirə etmir; `list` (`firestore.rules:545`) tam istifadəçi bazası enumerasiyasına aparır (H-6) və 50,000 MAU şərtini gözləmək üçün səbəb yoxdur — `get`-i saxlayıb `list`-i bağlamaq deep link axınına heç bir təsir etmir. **Tövsiyə: `list`-i indi bağla, `get` qəbul edilmiş qalsın.** |
| Banlanmış istifadəçi post/story/pinbox/venueEvent/supportMessage yarada bilir | ⚠️ **ŞƏRAİT DƏYİŞDİ** | Xərc əsaslandırması (əlavə `get()`) hələ keçərlidir. Lakin C-3 göstərir ki, bu qaydalar **onboarding etməmiş** (yəni `users/{uid}` sənədi olmayan) hesabları da buraxır — bu, ban deyil, uşaq təhlükəsizliyi məsələsidir və orijinal qərarın əhatəsində deyildi. **Tövsiyə: ən azı `posts` və `stories` create-ə `isActiveUser()` əlavə et** (bunlar ictimai görünən məzmundur; `supportMessages` qala bilər). |
| Silinmiş/banlanmış hesabın oxu tərəfi ~1 saat açıq | ✅ **ƏSASLIDIR** | Firebase Auth-un texniki məhdudiyyəti dəyişməyib. `assertActiveUser` + rules `isActiveUser` yazı tərəfini düzgün qapayır. |
| Storage-da per-user kvota yoxdur | ⚠️ **RİSK ARTDI** | `forwardChatMedia` (M-11) **server-side kopyalama** əlavə etdi: hücumçu yükləmə trafiki sərf etmədən 50 MB faylı 30/600s tezliyi ilə çoxalda bilər. Bu, orijinal qiymətləndirmə zamanı mövcud deyildi. **Tövsiyə: yenidən baxılma şərtini (50 AZN) saxla, amma `forwardChatMedia` üçün ayrıca sıx limit qoy.** |
| Magic-byte MIME yoxlaması yoxdur | ✅ **ƏSASLIDIR**, amma natamam | Baytların yoxlanması həqiqətən yalnız trigger ilə mümkündür. AMMA elan edilmiş Content-Type-ın **allowlist**-i Storage Rules-da tam mümkündür və edilməyib (M-10, `image/svg+xml`). Bu, qəbul edilmiş riskin bir hissəsi deyil — ayrıca, ucuz düzəlişdir. |
| Epoint checkout-ləğv API-si yoxdur | ✅ **ƏSASLIDIR** | İnteqrasiya məhdudiyyəti. `superseded` mexanizmi işləyir; yeganə qalan boşluq `boost_fee`-nin stack etməməsidir (M-9) — bu, Epoint-in məhdudiyyəti deyil, öz kodumuzun seçimidir. |
| AUTH-8a — parol min. 6 simvol | ✅ **ƏSASLIDIR** | Dəyişməyib. BACKLOG #2. |
| AUTH-8b — real MFA yoxdur | ⚠️ **PRİORİTET ARTMALIDIR** | Admin panelin özündə MFA yoxdur və C-2 (emergencyToken) + H-7 (moderator refund) birlikdə admin/moderator hesabının dəyərini əhəmiyyətli artırır. Son istifadəçi MFA-sı üçün 50,000 şərti əsaslıdır; **admin MFA-sı üçün isə şərt "launch" olmalıdır**, istifadəçi sayı deyil. |
| `_TwoFactorSheet` ölü kod | ✅ **ƏSASLIDIR** | Təsdiqləndi: heç yerdən çağırılmır. |
| B4 — `calls` sənədləri silinmir | ✅ **ƏSASLIDIR** | Dəyişməyib. |
| C1a — ProGuard/R8 yoxdur | ✅ **ƏSASLIDIR** | Dəyişməyib. Qeyd: H-5 (xarici URL) və H-1 (trilaterasiya) obfuskasiyadan asılı deyil — R8 bunları azaltmır. |
| C1b — root detection / TLS pinning | ✅ **ƏSASLIDIR** | Dəyişməyib. |
| C3 — Node 20 EOL | ✅ **ƏSASLIDIR, təcili** | `functions/package.json:5` hələ `"20"`. BACKLOG #1. |
| D4 — `reviews` miqrasiyası | ⚠️ **ƏHATƏ GENİŞLƏNMƏLİDİR** | Orijinal əsaslandırma silinmə/anonimləşdirmə idi. M-7 göstərir ki, eyni sxem **ziyarət tarixçəsinin enumerasiyasına** da imkan verir — bu, GDPR-dən əvvəl gələn cari məxfilik məsələsidir. **Tövsiyə: `allow list: if false` indi tətbiq edilsin** (miqrasiyanı gözləmədən). |
| E1 — float→qəpik miqrasiyası | ✅ **ƏSASLIDIR** | PinBox düsturu düzəldilib; `applyPaymentOutcome`-un `amount_mismatch` toleransı 0.005 (`index.ts:6427`) float noise üçün doğrudur. |

**`docs/BACKLOG.md` üzrə:** 12 maddənin hamısı hələ keçərlidir və heç biri
launch-blokerı deyil. Prioritet sırasına **yalnız bir dəyişiklik** tövsiyə
edirəm: #10 (`resource == null` 3 yer) və #12 (dSYM) olduğu yerdə qalsın, amma
**yeni #0 olaraq bu auditin CRITICAL-ları əlavə edilsin**.

---

## 12. Hücum Simulyasiyası Nəticələri (25 ssenari)

| # | Ssenari | Nəticə | Sübut / səbəb |
|---|---|---|---|
| 1 | Adi user → Admin API | ❌ **UĞURSUZ** | `session.ts:43-45` — `role` claim-i olmayan ID token üçün cookie mintlənmir; `proxy.ts:60-67` + hər `page.tsx`/action `getCurrentAdmin()` |
| 2 | User A → User B məlumatı | ⚠️ **QİSMƏN UĞURLU** | `private/data` oxunmur ✅. Amma: `usernames` list → bütün uid-lər → `users/{uid}` get (`blockedUsers`, `reportedCount`, `online`, `lastSeen`) — **H-6** |
| 3 | User → Moderator səlahiyyəti | ❌ **UĞURSUZ** | Rol yalnız custom claim-dədir; `admins/{uid}` `read, write: if false` (`firestore.rules:1683`); claim yalnız Admin SDK ilə |
| 4 | Moderator → Admin səlahiyyəti | ❌ **UĞURSUZ** | `requireAdminManagement()` (`admins.ts:16-23`) `manageAdmins` tələb edir, moderator-da `false` |
| 5 | Saxta ödəniş → Boost | ❌ **UĞURSUZ** | `offers.boostedUntil` rules-da kilidli (`firestore.rules:1310`); yalnız `applyPaymentOutcome` yazır; webhook SHA1 imza ilə (`epoint.ts:104-110`) |
| 6 | Replay ödəniş → ikiqat Boost | ❌ **UĞURSUZ** | `applyPaymentOutcome` tranzaksiya daxilində `status !== pending && !== superseded` yoxlaması (`index.ts:6396-6410`) |
| 7 | Dəyişdirilmiş qiymət → ucuz Boost | ❌ **UĞURSUZ** | `amount` server cədvəlindən (`BOOST_FEE_BY_HOURS`, `index.ts:5005`); client heç bir məbləğ göndərmir; webhook `amount_mismatch` yoxlayır (`:6423-6438`) |
| 8 | VIP bypass (venue premium) | ❌ **UĞURSUZ** | `isPremium`/`premiumExpiresAt` rules-da kilidli (`firestore.rules:962`) |
| 9 | Abunə manipulyasiyası | ❌ **UĞURSUZ** | `subscriptionRenewsAt` kilidli; IAP `claimIapSubscriptionOwnership` (`index.ts:7440`); Sandbox qəbzi `config/iapTesters` ilə məhdud (`:7556-7570`) |
| 10 | Lokasiya spoofing | ✅ **UĞURLU** | `private/data.lat/lng` client-yazılabilir (`firestore.rules:352`); server heç bir ağlabatanlıq yoxlaması etmir → **H-1**-in ön şərti |
| 11 | Radius bypass | ⚠️ **QİSMƏN** | Hədəfin `visibilityRadiusKm`-i server-side tətbiq olunur ✅ (`index.ts:794-799`). Amma hücumçu öz mövqeyini hədəfin radiusuna "köçürərək" onu keçir (10 ilə birlikdə) |
| 12 | Chat IDOR (başqasının mesajını oxumaq) | ❌ **UĞURSUZ** | `chatId.split('_').hasAny([uid])` (`firestore.rules:703, 771`) — hücumçunun uid-i chatId-də olmalıdır. Mesaj redaktəsi də bağlıdır (K-2) |
| 12b | Chat siyahısına mesaj yeritmə | ✅ **UĞURLU** | `participants` `update`-də kilidli deyil → **H-3** |
| 13 | PinBox ownership bypass | ❌ **UĞURSUZ** | `firestore.rules:1354-1355` `get(venues/$(venueId)).data.ownerId` yoxlayır (K-9 düzəlişi) |
| 14 | Biznes ownership bypass | ❌ **UĞURSUZ** | `venues` `create: if false`; `ownerId` immutable (`firestore.rules:960`); `submitVenue`/`updateVenue` `ownerId !== uid` → `permission-denied` |
| 15 | Saxta verification (blue check) | ❌ **UĞURSUZ** | `identityVerified` rules-da kilidli (`firestore.rules:336`); yalnız `setIdentityVerificationStatus` (admin, `moderateIdentityVerifications`) |
| 15b | Saxta "təsdiqlənmiş" rəy | ✅ **UĞURLU** | Sahib öz növbəsinə yazılıb özünü `seated` edə bilir → **M-6** |
| 16 | Mass assignment | ✅ **QİSMƏN UĞURLU** | `users`/`venues`/`offers`/`pinboxes` yaxşı qorunub ✅. Amma `private/**` (H-9), `posts`/`stories`/`comments` create (M-15), `chats` update (H-3) qorunmayıb |
| 17 | Firebase rules bypass | ⚠️ **QİSMƏN** | Rules özü möhkəmdir; bypass rules-ın **əhatə etmədiyi** yerlərdən gəlir: Storage download token-ləri (M-16), Cloud Functions-un client sahələrinə etibarı (C-1, H-5) |
| 18 | Storage icazəsiz giriş | ⚠️ **QİSMƏN** | Yükləmə/oxu yolları düzgündür ✅. Amma **silmə** Cloud Function vasitəsilə tamamilə açıqdır → **C-1**; sızmış download URL-ləri rules-dan asılı deyil (M-16) |
| 19 | Token manipulyasiyası | ❌ **UĞURSUZ** | Firebase ID token imzası; `verifySessionCookie` + `checkRevoked` (`server.ts:31`); custom claim client tərəfindən yazıla bilmir |
| 20 | Admin session ələ keçirmə | ✅ **UĞURLU** | `emergencyToken` → **C-2**. Cookie özü `httpOnly`/`secure`/`sameSite:lax` ✅ (`session/route.ts:35-41`), amma URL tokeni bunu keçir |
| 21 | Silinmiş/banlanmış hesabın davam edən sessiyası | ⚠️ **QİSMƏN** | Yazı: `isActiveUser`/`assertActiveUser` bloklayır ✅ (chat, zəng, report, əksər callable). Oxu: ~1 saat açıq (qəbul edilmiş risk). `posts`/`stories` create hələ açıqdır |
| 22 | `findNearbyUsers` ilə bazanın çıxarılması | ⚠️ **QİSMƏN** | Rate limit 10/60s + 50 nəticə + 200 tarama ✅ məhdudlaşdırır. Amma `getDiscoverCandidates` (VIP) **limitsizdir** və 500 nəticə verir → **M-1**; `usernames` list isə hər şeyi verir → **H-6** |
| 23 | `searchUsersByName` ilə enumerasiya | ❌ **UĞURSUZ (təsadüfən)** | `endAt(`${query}`)` prefiks deyil, dəqiq bərabərlikdir (M-2) → enumerasiya işləmir. Amma bu, qorumadan deyil, səhvdən irəli gəlir; düzəldiləndə limit əlavə edilməlidir |
| 24 | `superseded` ilə ikiqat entitlement | ❌ **UĞURSUZ** | `boost_fee` üzərinə yazır, stack etmir → hücumçu üstünlük almır. **Tərs problem var**: müştəri iki dəfə ödəyir, bir dəfə alır (M-9) |
| 25 | Cloud Logging oxucusu → tam admin | ✅ **UĞURLU** | **C-2** — istismar yolu tam işlək |

**Yekun: 25 ssenaridən 6-sı tam uğurlu, 8-i qismən uğurlu, 11-i uğursuz.**

---

## 13. RBAC Access Matrix

Kod bazasında **cəmi 2 rol** var (`admin-panel/src/lib/auth/session.ts:14`):
`admin`, `moderator`. Prompt-da sadalanan `Super Admin`, `Finance`, `Support`,
`Analyst` rolları **mövcud deyil** — bu, özlüyündə tapıntıdır (ayrılıq prinsipi
tətbiq oluna bilmir).

| Əməliyyat | admin | moderator | Qeyd |
|---|---|---|---|
| `/dashboard` (KPI, **bugünkü gəlir**) | ✅ | ✅ | gate yoxdur — moderator maliyyə metrikasını görür |
| `/logs` (moderasiya audit izi) | ✅ | ✅ | qəsdən (`logs/page.tsx:5-8`) |
| `/venues`, `/offers`, `/pinboxes` moderasiya | ✅ | ✅ | `moderateVenues`/`moderateOffers` |
| `setVenuePremium` (pulsuz premium vermə) | ✅ | ❌ | `manageVenues` |
| `/users`, `setUserBanned`, `setUserPremium`, `setUserIdentityVerified` | ✅ | ❌ | `manageUsers` |
| `/identity-verifications` (pasport + selfie) | ✅ | ❌ | `moderateIdentityVerifications` |
| `/notifications` (broadcast) | ✅ | ❌ | `broadcastNotifications` |
| `/admins` (rol vermə/silmə) | ✅ | ❌ | `manageAdmins` |
| `/feedback`, `/event-reports`, `/review-reports` | ✅ | ✅ | `manageFeedback`/`moderateVenues` |
| **`/payments`, `/premium-payments` (bütün ödəniş qeydləri)** | ✅ | ⚠️ **✅** | `moderateVenues` — **H-7** |
| **`initiateRefund` (real Epoint `/reverse`)** | ✅ | ⚠️ **✅** | `moderateVenues` — **H-7** |
| **`markPaymentRefunded`** | ✅ | ⚠️ **✅** | `moderateVenues` — **H-7** |
| **`markPinBoxPayoutPaid` (venue payout)** | ✅ | ⚠️ **✅** | `moderateVenues` — **H-7** |
| MFA | ❌ | ❌ | heç bir rolda yoxdur |
| Sessiya ömrü | 5 gün (`session.ts:11`) | 5 gün | `checkRevoked: true` hər sorğuda ✅ |

**Mobil tərəfdə rol yoxdur** — yeganə "rol"a bənzər ayrım `businessStatus`
(`none` / digər) və `premium` bayrağıdır; hər ikisi server tərəfdə düzgün
tətbiq olunur.

---

## 14. Kolleksiya üzrə İcazə Cədvəli

| Kolleksiya | read | create | update | delete | Qeyd |
|---|---|---|---|---|---|
| `config/*` | auth | ✗ | ✗ | ✗ | ✅ |
| `bannedUsers/*` | ✗ | ✗ | ✗ | ✗ | server-only tombstone ✅ |
| `users/{uid}` | get: auth (blok yoxlaması); **list: ✗** | ✗ (CF) | sahib (kilidli sahələr istisna) + `reportedCount+1` | sahib | `blockedUsers`/`reportedCount` ictimai — H-6 |
| `users/{uid}/private/**` | sahib | sahib | **sahib — TAM** | sahib | **H-9** |
| `users/{uid}/media` | auth | sahib | sahib | sahib | boş, upload axını yoxdur |
| `users/{uid}/favoriteOffers`, `reposts`, `sessions` | sahib | sahib | sahib | sahib | ✅ |
| `users/{uid}/likedPosts`, `notifiedVenues`, `notifiedEvents` | sahib/✗ | ✗ | ✗ | ✗ | ✅ |
| `users/{uid}/notifications` | sahib | ✗ | sahib (`isRead`) | sahib | ✅ |
| `users/{uid}/payments` | sahib | ✗ | ✗ | ✗ | ✅ |
| `users/{uid}/profileViews` | sahib | viewer (öz uid) | viewer | ✗ | ✅ |
| `usernames/{id}` | **get: hamı; list: auth** | auth (rezerv siyahısı) | ✗ | sahib | **H-6** |
| `follows/{id}` | mürəkkəb (məxfilik) | follower | followee (`status`) | hər iki tərəf | ✅ |
| `chats/{id}` | iştirakçı | iştirakçı + blok + `canMessage` | **iştirakçı — `participants` KİLİDLİ DEYİL** | iştirakçı | **H-3, H-4** |
| `chats/*/messages` | chatId üzvü | sender + blok + `isActiveUser` + 2000 simvol | `deliveredAt/readAt` və ya `deletedFor`+öz uid | sender | `mediaUrl` validasiyasız → **C-1** |
| `calls/{id}` + candidates | iştirakçı | caller + blok + `isActiveUser` | iştirakçı (`participants`/`callerId` sabit) | ✗ | ✅ |
| `venues/{id}` | auth | ✗ (CF) | sahib (35 sahə kilidli) | sahib | `photoUrl` xarici URL ola bilər — H-5 |
| `venues/*/likes` | auth | sahib(uid) | ✗ | sahib | ✅ |
| `venues/*/followers` | sahib/venue owner | sahib | ✗ | sahib | ✅ |
| `venues/*/audienceHistory` | auth | ✗ | ✗ | ✗ | ✅ |
| `venues/*/waitlist` | entry user / venue owner | ✗ (CF) | user (cancel) / owner (status) | ✗ | **M-6** |
| `venues/*/activeCheckins` | user / venue owner | user | user | user | ✅ (K-4) |
| `venues/*/offerAcceptances` | venue owner | ✗ | ✗ | ✗ | ✅ |
| `reviews/{venueId}_{uid}` | **auth (list daxil)** | author + `hasVerifiedVisit` + kateqoriya | author / venue owner (`ownerReply`) | ✗ | **M-7, M-6** |
| `payments/{id}` | `ownerId` | ✗ | ✗ | ✗ | ✅ |
| `savedCards/{id}` | `ownerId` | ✗ | ✗ | ✗ | ✅ |
| `iapSubscriptions/*` | ✗ | ✗ | ✗ | ✗ | ✅ |
| `identityVerifications/{id}` | `userId` | ✗ | ✗ | ✗ | ✅ (BACKLOG #10) |
| `adminNotifications/*` | ✗ | ✗ | ✗ | ✗ | ✅ |
| `offers/{id}` | auth | ✗ (CF) | sahib (21 sahə kilidli) | sahib | `imageUrl` — H-5 |
| `offers/*/redemptions/{uid}` | auth | sahib(uid) | ✗ | ✗ | ✅ (once-only create) |
| `pinboxes/{id}` | auth | sahib + venue ownership + kateqoriya | sahib (13 sahə kilidli) | sahib | ✅ |
| `pinboxOrders/{id}` | `buyerId` | ✗ | ✗ | ✗ | ✅ |
| `venuePayouts/*` | ✗ | ✗ | ✗ | ✗ | ✅ |
| `venueEvents/{id}` | auth | venue owner + kateqoriya + 300 simvol | venue owner (2 forma) | ✗ | `coverImageUrl` — H-5 |
| `eventReports`, `reports`, `reviewReports` | ✗ | reporter + `isActiveUser` + 1000 simvol | ✗ | ✗ | ✅ |
| `birthdayMatches/{id}` | venue owner (get) / list ✗ | ✗ | ✗ | ✗ | ✅ |
| `accountDeletions/*` | ✗ | ✗ | ✗ | ✗ | ✅ |
| `stories/{id}` | məxfilik qaydası | **creator — validasiyasız** | ✗ | creator | **M-15** |
| `stories/*/views/{uid}` | story creator | viewer | ✗ | ✗ | ✅ |
| `posts/{id}` | məxfilik / `authorIsPublic` | **author — validasiyasız** | author (`caption`) | author | **M-15, H-5** |
| `posts/*/likes`, `comments`, `comments/*/likes` | `canReadPost` | uid / author | author (`text`) | author / post owner | **M-15** (ölçü limiti yox) |
| `moderationLogs`, `admins` | ✗ | ✗ | ✗ | ✗ | ✅ |
| `vipFeatures/*` | auth | ✗ | ✗ | ✗ | ✅ |
| `supportMessages/*` | ✗ | uid + 2000 simvol | ✗ | ✗ | ✅ |
| `rateLimits/*` | ✗ (catch-all) | ✗ | ✗ | ✗ | ✅ |
| `{document=**}` | ✗ | ✗ | ✗ | ✗ | default deny ✅ |

---

## 15. API Endpoint Cədvəli

| Endpoint | Metod | Auth | Rol/sahiblik | Əsas input | Output | Risk |
|---|---|---|---|---|---|---|
| `getTurnCredentials` | callable | ✅ | — | — | `iceServers` | ✅ (30/600s) |
| `deleteAccount` | callable | ✅ | öz uid + 5dq fresh | — | `{success}` | ⚠️ limit yox; `mediaUrl` yolu ilə C-1-in ikinci girişi |
| `completeOnboarding` | callable | ✅ | öz uid | ad, doğum tarixi, ölkə… | `{success}` | ⚠️ xətası client-də udulur (**C-3**) |
| `getDiscoverCandidates` | callable | ✅ | `premium` | `mode`, `country`, `genderFilter` | 500 profil | 🟡 **M-1** (limit yox, ~1000 oxu) |
| `findNearbyUsers` | callable | ✅ | — | `genderFilter` | 50 profil + **dəqiq məsafə** | 🟠 **H-1** |
| `previewVenueAudience` | callable | ✅ | venue owner | **`lat`,`lng`,`radiusKm` (client!)** | `{count}` | 🟠 **H-2** |
| `searchUsersByName` | callable | ✅ | — | `query` | ≤20 profil | 🟡 **M-2** |
| `forwardChatMedia` | callable | ✅ | source chat üzvü | `sourceUrl`,`chatId`,`messageId` | `mediaUrl` (yeni token) | 🟡 **M-11** |
| `joinWaitlist` | callable | ✅ | — | `venueId`,`partySize`,`phoneNumber` | `{entryId}` | 🟡 **M-3**, **M-6** |
| `updateVenue` / `updateOffer` / `updatePinBox` | callable | ✅ | `ownerId` | məzmun sahələri | `{sentForReReview}` | 🟠 **H-5** (`photoUrl`/`imageUrl`) |
| `resubmitVenue/Offer/PinBox` | callable | ✅ | `ownerId` | id | — | ⚠️ limit yox |
| `submitIdentityVerification` | callable | ✅ | öz uid + path prefix | 3 Storage yolu | `{ok}` | ⚠️ limit yox; path yoxlaması ✅ |
| `submitVenue` | callable | ✅ | `businessStatus != none` | **client `venueId`**, ad, kateqoriya, `photoUrl` | `{venueId, checkoutUrl}` | 🟡 **M-4**, **H-5** |
| `submitOffer` | callable | ✅ | venue owner | məzmun | `{offerId, checkoutUrl}` | ⚠️ limit yox |
| `createBoostCheckout` | callable | ✅ | offer owner | `offerId`, **`hours` (cədvəldən)** | `checkoutUrl` | ✅ (qiymət serverdə) |
| `createVenuePremiumCheckout` | callable | ✅ | venue owner | `venueId`, `months` | `checkoutUrl` | ✅ |
| `retryOfferPayment` / `retryVenue*Payment` | callable | ✅ | owner | id | `checkoutUrl` | ✅ |
| `reservePinBoxOrder` | callable | ✅ | — | `pinboxId`, `quantity` | `{orderId, checkoutUrl}` | ✅ (stok tranzaksiyada) |
| `generatePinBoxQrToken` | callable | ✅ | `buyerId` | `orderId` | 6 rəqəm + 40s TTL | ⚠️ limit yox (yazma spam-ı) |
| `redeemPinBoxOrder` | callable | ✅ | venue owner | `venueId`, `code` | sifariş | ✅ (30/300s, 1M kod, 40s) |
| `createEpointWidgetCheckout` | callable | ✅ | payment owner + `pending` | `paymentId` | `widgetUrl` | ✅ |
| `startCardRegistration` | callable | ✅ | öz uid | — | `redirectUrl` | ✅ |
| `payWithSavedCard` | callable | ✅ | payment + card owner | `paymentId`,`cardId` | nəticə | ✅ (sinxron, TOCTOU bağlı) |
| `deleteSavedCard` / `setDefaultSavedCard` | callable | ✅ | `ownerId` | `cardId` | — | ✅ |
| `verifyInAppPurchase` | callable | ✅ | öz uid | `productId`,`platform`,`receiptData` | `{expiresAt}` | ✅ (store-da doğrulanır, ownership claim) |
| `epointWebhook` | POST | imza | — | `data`,`signature` | 200/400/429 | 🟡 **M-8** (payload logu) |
| `appStoreServerNotifications` | POST | JWS | — | `signedPayload` | 200/400 | 🟡 **M-5** (limit yox) |
| `googlePlayRtdn` | Pub/Sub | GCP IAM | — | RTDN mesajı | — | ✅ |
| `admin /api/auth/session` | POST/DELETE | ID token → claim | `role` tələb | `{idToken}` | cookie | ✅ |
| `admin /api/health` | GET | **YOX** | — | — | `{projectId, ...}` / **xam xəta** | 🟠 **H-8** |
| `admin /login?emergencyToken=` | GET | custom token | admin/moderator | URL query | sessiya | 🔴 **C-2** |

---

## 16. OWASP Mapping

### OWASP API Security Top 10 (2023)

| # | Kateqoriya | Vəziyyət | Tapıntılar |
|---|---|---|---|
| API1 | Broken Object Level Authorization | 🔴 | **C-1** (Storage), H-3, H-4 |
| API2 | Broken Authentication | 🔴 | **C-2**, **C-3** |
| API3 | Broken Object Property Level Auth | 🟠 | **H-9**, H-3, M-15 |
| API4 | Unrestricted Resource Consumption | 🟠 | M-1, M-2, M-3, M-4, M-5, M-11 |
| API5 | Broken Function Level Authorization | 🟠 | **H-7** (moderator → refund) |
| API6 | Unrestricted Access to Sensitive Business Flows | 🟡 | M-6 (saxta rəy), M-3 |
| API7 | SSRF | 🟡 | **H-5** (client-render SSRF — server deyil, amma eyni sinif) |
| API8 | Security Misconfiguration | 🟠 | **H-8**, M-13, M-14, App Check off |
| API9 | Improper Inventory Management | 🟡 | `/api/health` "temporary" qalıb, `mint-emergency-token` "TEMPORARY" qalıb |
| API10 | Unsafe Consumption of 3rd-party APIs | 🟢 | Epoint imza + `EPOINT_ENV` fail-safe; Apple/Google real doğrulama ✅ |

### OWASP MASVS (mobil)

| Kontrol | Vəziyyət | Qeyd |
|---|---|---|
| MASVS-STORAGE-1 (həssas data yaddaşda) | 🟡 | email/birthDate Keychain/Keystore-da ✅; qalan keş `shared_prefs`-də + `allowBackup` default (**M-14**) |
| MASVS-STORAGE-2 (loglar) | 🟡 | **M-8** (webhook payload), `logCallableInvocation` uid izləri |
| MASVS-CRYPTO-1/2 | 🟢 | Öz kripto yoxdur; Epoint SHA1 imzası provayder tələbidir, `timingSafeEqual` ✅ |
| MASVS-AUTH-1/2/3 | 🔴 | **C-3** (onboarding gate), MFA yox, server-side parol min. 6 |
| MASVS-NETWORK-1 | 🟢 | ATS override yoxdur (iOS), `usesCleartextTraffic` yoxdur (targetSdk 36 → default deny) |
| MASVS-NETWORK-2 (pinning) | 🔵 | Yoxdur — qəbul edilmiş risk (C1b) |
| MASVS-PLATFORM-1 (IPC/exported) | 🟢 | Yalnız `MainActivity` exported, `singleTop`, `taskAffinity=""` ✅ |
| MASVS-PLATFORM-2 (WebView) | 🟡 | **M-12** — allowlist yox, JS bridge hər mənşəyə yeridilir |
| MASVS-PLATFORM-3 (deep link) | 🔵 | App Links `autoVerify` ✅; `peakpin://` mənimsənilə bilər (L-3) |
| MASVS-CODE-1 (üçüncü tərəf) | 🟡 | Node 20 EOL; `video_thumbnail` tərk edilmiş, lokal fork |
| MASVS-CODE-4 (debug) | 🟢 | Release imzası məcburi (`build.gradle.kts:87-99`), `-PallowDebugSigning` açıq opt-in ✅ |
| MASVS-RESILIENCE-* | 🔵 | R8/root detection yoxdur — qəbul edilmiş (C1a/C1b) |
| MASVS-PRIVACY-1/2 | 🔴 | **H-1** (trilaterasiya), **H-2**, **H-5** (IP toplama), M-7 (ziyarət tarixçəsi) |

---

## 17. Asılılıq Auditi

**Cloud Functions (`functions/package.json`)**

| Paket | Versiya | Qeyd |
|---|---|---|
| `engines.node` | **`"20"`** | 🔴 **EOL (Maintenance LTS 2026 aprelində bitib)** — ACCEPTED_RISKS C3 / BACKLOG #1 |
| `firebase-admin` | `^14.3.0` | ✅ cari |
| `firebase-functions` | `^7.3.2` | ✅ cari |
| `@apple/app-store-server-library` | `^3.1.0` | ✅ |
| `googleapis` | `^176.0.0` | ✅ |
| `geofire-common` | `^6.0.0` | ✅ |

**Admin panel (`admin-panel/package.json`)**

| Paket | Versiya | Qeyd |
|---|---|---|
| `next` | `16.2.11` | ✅ cari (Server Actions üçün daxili Origin yoxlaması — CSRF qorunması var) |
| `react`/`react-dom` | `19.2.4` | ✅ |
| `firebase-admin` | `^14.2.0` | ✅ |
| `firebase` (client) | `^12.16.0` | ✅ |
| `overrides.jose` | `^5.9.6` | ⚠️ Qəsdən pin — `jwks-rsa` üçün. `jose` 5.x-in bilinən CVE-si yoxdur, amma bu override versiya yüksəlişini bloklayır; rüblük yoxlanmalıdır |
| `shadcn` | `^4.14.0` | ⚠️ Bu, adətən CLI-dir (devDependency olmalıdır), runtime `dependencies`-dədir — lazımsız istehsalat asılılığı |

**Flutter (`pubspec.yaml`)** — 50 birbaşa asılılıq. Firebase ailəsi cari
(`firebase_core ^3.8.0`, `cloud_firestore ^5.5.0`). Diqqət çəkənlər:

| Paket | Qeyd |
|---|---|
| `video_thumbnail` | 🟡 **Tərk edilmiş upstream** — `dependency_overrides` ilə `packages/video_thumbnail/` lokal fork (jcenter → mavenCentral). Təhlükəsizlik yaması gəlməyəcək; media emalı kodudur (parse riski) |
| `geocoding ^3.0.0` | 🔵 `compileSdk 33` hardcoded (build.gradle.kts-in workaround-u) — köhnəlmiş plugin |
| `flutter_branch_sdk ^9.3.3` | 🔵 Üçüncü tərəf analitika — Data Safety bəyannaməsində göstərilməlidir |
| `webview_flutter ^4.10.0` | ✅ cari, amma istifadə tərzi M-12 |
| `flutter_secure_storage ^9.2.2` | ✅ |

**`npm audit` / `flutter pub outdated` icra EDİLMƏDİ** — hər ikisi şəbəkə
sorğusu tələb edir və Bölmə 0.3 çərçivəsində təsdiq gözlədim. Yuxarıdakı
qiymətləndirmə manifest versiyalarının analizinə əsaslanır.
**Tövsiyə:** launch-dan əvvəl `npm audit --production` (functions və
admin-panel) və `flutter pub outdated` icra edilsin.

---

## 18. Secrets Auditi (git tarixçəsi daxil)

**Sirlərin idarə olunması — ümumilikdə YAXŞI.**

| Sirr | Saxlanma yeri | Vəziyyət |
|---|---|---|
| `EPOINT_PUBLIC_KEY` / `EPOINT_PRIVATE_KEY` / `EPOINT_ENV` | Secret Manager (`defineSecret`) | ✅ |
| `CLOUDFLARE_TURN_KEY_ID` / `_API_TOKEN` | Secret Manager | ✅ (client-ə heç vaxt ötürülmür) |
| `RESEND_API_KEY` | Secret Manager | ✅ |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | Secret Manager | ✅ |
| Admin SDK credentials (production) | App Hosting ADC (`apphosting.yaml` şərhi) | ✅ ən yaxşı praktika |
| Admin SDK credentials (local) | `.env.local` | ✅ git-də izlənmir |
| Release keystore + parollar | `android/key.properties`, `android/keystore/*.jks` | ✅ git-də izlənmir (`git ls-files` təsdiqlədi) |
| Maps API açarı | `key.properties` → manifest placeholder | ✅ commit edilmir |
| Firebase Web/Android/iOS API açarları | `firebase_options.dart`, `google-services.json`, `GoogleService-Info.plist`, `apphosting.yaml` | ⚪ dizayn etibarı ilə ictimai — **GCP-də API restriction yoxlanmalıdır** |
| Branch key | Manifest (`key_live_***REDACTED***`) | ⚪ client açarı; Branch **Secret** düzgün şəkildə yoxdur ✅ |

**Git tarixçəsi taraması** (`git log -p --all`):
`BEGIN ... PRIVATE KEY`, `private_key"`, `re_[A-Za-z0-9]{20,}`, `serviceAccount*.json`,
`EPOINT_PRIVATE=`, `CLOUDFLARE_TURN_API_TOKEN=` naxışları üçün —
**heç bir real sirr tapılmadı**. Bütün uyğunluqlar `defineSecret("…")` çağırışları
və şərhlərdir. Silinmiş fayllar arasında yalnız `assets/payments/google_pay_config.json`
var (konfiqurasiya, sirr deyil).

⚠️ **İstisna:** `mint-emergency-token.ts` ilə yaradılmış tokenlər **Cloud Logging-də
sirr kimi qalır** (C-2). Bu, git-də deyil, amma eyni sinifdəndir və launch-dan
əvvəl loglardan təmizlənməli və ya bütün admin refresh tokenləri ləğv edilməlidir.

---

## 19. Məxfilik Auditi

| Data | Saxlanma yeri | Kim görür | Saxlama müddəti |
|---|---|---|---|
| E-poçt, telefon, doğum tarixi, cinsi, şəhər, razılıq | `users/{uid}/private/data` | sahib + Admin SDK | hesab silinənə qədər |
| Dəqiq `lat`/`lng` (25 m-də bir yenilənir) | `users/{uid}/private/data` | sahib + Cloud Functions | **son dəyər əbədi** — tarixçə saxlanmır ✅ |
| Yaxınlıq marker koordinatı | cavabda, 100 m şəbəkə | yaxınlıqdakı istifadəçilər | anlıq |
| **`distanceMeters` (dəqiq)** | cavabda | yaxınlıqdakı istifadəçilər | anlıq — **H-1: xam koordinat bərpa edilir** |
| Fiziki ziyarət (waitlist `seated`) | `venues/*/waitlist` + `reviews` | **`reviews` hər kəsə açıq — M-7** | əbədi |
| Aktiv check-in | `venues/*/activeCheckins` | user + venue owner ✅ | check-out-a qədər |
| FCM tokenləri, cihaz imzaları | `private/data` | sahib + CF | əbədi |
| Kimlik sənədləri (ID + selfie) | Storage `identity_verifications/` (oxu qaydası YOXDUR) | yalnız `admin` rolu, signed URL | `cleanupExpiredIdentityVerificationImages` ilə təmizlənir ✅ |
| Ödəniş qeydləri | `payments`, `venuePayouts` | sahib + admin **+ moderator (H-7)** | əbədi (audit) |
| Chat mesajları + media | `chats/**` + Storage | iştirakçılar — **URL bearer (M-16)** | əbədi / birtərəfli silinə bilər (H-4) |
| Rəylər | `reviews/{venueId}_{uid}` | hər kəs | əbədi, **anonimləşdirilə bilməz** (ACCEPTED_RISKS D4) |
| Silinmə audit izi | `accountDeletions` | server-only | əbədi (yalnız uid + tarix) ✅ |

**Hesab silinəndə (`deleteAccount`, `index.ts:299-345`) — ~15 addım:**
mesajlar placeholder-ə çevrilir (+ media silinir), yaradılmış tədbirlər
arxivlənir, qoşulduqları tərk edilir, `follows` silinir, başqalarının blok
siyahılarından çıxarılır, story/post/venue/offer silinir, PinBox sifarişləri
anonimləşdirilir, telefon/username rezervasiyaları buraxılır, kimlik
doğrulamaları silinir, `users/{uid}` + alt-kolleksiyalar silinir, 3 Storage
prefiksi silinir, Auth hesabı silinir. **Çox yaxşı əhatə.**

**Qalan orphan data:**
* `reviews` — silinmir (ID uid daşıyır — ACCEPTED_RISKS D4) 🟡
* `payments` — qəsdən saxlanılır (maliyyə audit) ✅ sənədləşdirilib
* `venuePayouts` — `ownerId` sahəsi qalır 🔵
* `calls` — heç vaxt silinmir (ACCEPTED_RISKS B4) 🔵
* `rateLimits/{scope}:{uid}` — **heç vaxt silinmir**, uid daşıyır 🔵 (yeni qeyd: kiçik, amma silinmiş hesabın uid-i orada qalır)
* `moderationLogs` — `targetId` uid daşıyır ✅ (audit üçün əsaslıdır)
* `chat_photos/{chatId}/...` — `chatId` hər iki uid-i daşıyır; qarşı tərəfin faylları qalır ✅ (doğru)

**GDPR/eksport:** `exportUserData` mövcuddur (rules şərhində istinad edilir).
Silinmə hüququ əsasən təmin olunur; `reviews` istisnadır və sənədləşdirilib.

---

## 20. Store Hazırlığı

| Element | Vəziyyət |
|---|---|
| Release imzalama | ✅ məcburi, debug fallback açıq opt-in (`build.gradle.kts:87-99`) |
| `minSdk 24` / `targetSdk 36` | ✅ pinlənib, `BACKWARD_COMPATIBILITY.md`-də əsaslandırılıb |
| Advertising ID icazələri | ✅ hər iki permission `tools:node="remove"` ilə çıxarılıb |
| İcazələr | ⚠️ `ACCESS_BACKGROUND_LOCATION` — Play Console-da ayrıca əsaslandırma tələb edir; formanın doldurulduğunu təsdiqləyə bilmədim |
| `allowBackup` / `dataExtractionRules` | 🟡 **M-14** — təyin edilməyib |
| ProGuard/R8 | 🔵 söndürülü (ACCEPTED_RISKS C1a) |
| Crashlytics dSYM (iOS) | 🔵 BACKLOG #12 |
| `ITSAppUsesNonExemptEncryption` | ⚠️ `Info.plist`-də tapılmadı — App Store yükləməsində hər dəfə əl ilə cavab tələb edəcək (bloklamır) |
| ATS (iOS) | ✅ override yoxdur |
| Hesab silmə (Play tələbi) | ✅ `deleteAccount` + in-app axın |
| Uşaq təhlükəsizliyi səhifəsi | ✅ mövcud (`legal/child-safety-standards.html`) — **AMMA C-3 iddia edilən 18+ nəzarətini effektiv olmayan edir** 🔴 |
| Data Safety uyğunluğu | ⚠️ **H-5** səbəbindən: tətbiq istifadəçi cihazını **ixtiyari üçüncü tərəf serverinə** sorğu göndərməyə məcbur edə bilir (profil şəkli URL-i) — bu, bəyan edilməmiş data paylaşımıdır |
| Məzmun moderasiyası | ⚠️ **H-5** — təsdiqdən sonra məzmun dəyişdirilə bilər; profil şəkli heç vaxt moderasiya olunmur |
| Crash handling | ✅ Crashlytics (Android tam, iOS dSYM yoxdur) |
| Force update / maintenance | ✅ Remote Config ilə (`splash_screen.dart:31-41`) |

**Mağaza baxımından ən risklisi C-3 + H-5 birləşməsidir:** yayımlanmış uşaq
təhlükəsizliyi standartı mövcud olmayan nəzarəti iddia edir, və profil şəkilləri
üçün heç bir moderasiya yoxdur (üstəlik URL xarici ola bilər). Bu ikisi Google
Play-in "Child Safety Standards" və "Deceptive Behavior" siyasətlərinə qarşı real
risk yaradır — bu, texniki deyil, **hesab dayandırılması** riskidir.

---

## 21. Yoxlana Bilməyənlər

| Nə | Niyə | Nə lazımdır |
|---|---|---|
| Epoint webhook-un real payload sxemi | Production-a sorğu göndərmək qadağandır (0.2) | Bir real əməliyyatdan sonra Cloud Logging-dəki `epointWebhook: decoded payload` sətrinin nəzərdən keçirilməsi — `webhookAmount` yoxlamasının həqiqətən işlədiyini yalnız bu təsdiqləyə bilər |
| Firebase Console ayarları | Console-a giriş auditin əhatəsində deyil | App Check qeydiyyat vəziyyəti; "Link accounts that use the same email" ayarı; API açar məhdudiyyətləri; parol siyasəti; Storage token rotasiyası |
| Deploy edilmiş rules-ın kodla eyniliyi | `firebase deploy` və Console oxunuşu qadağandır | `firebase firestore:rules:get` ilə production rules-ın bu repo ilə diff-i |
| `migrate-users-private-data.ts` / `migrate-storage-owner-paths.ts` icra olunubmu | Production oxunuşu qadağandır | Skriptlərin icra jurnalı; icra olunmayıbsa köhnə sənədlərdə `birthDate`/`lat`/`lng` hələ ictimai `users/{uid}`-dədir → **K-1 tam açıq qalar** |
| GCP IAM rol paylanması (təhdid modeli H) | GCP Console əhatədə deyil | `roles/logging.viewer` kimə verilib — C-2-nin real hücumçu bazasını bu müəyyən edir |
| `npm audit` / `flutter pub outdated` | Şəbəkə + paket əməliyyatı, təsdiq gözlədim (0.3) | Hər ikisinin icrası |
| Emulator rules testləri | `tests/` qovluğu mövcuddur, icra üçün `npm install` lazım ola bilər (0.1) | `firebase emulators:exec` ilə mövcud test dəstinin icrası |
| Cari `moderationLogs` / `adminNotifications` məzmunu | Production oxunuşu qadağandır | `iap.receipt_theft_attempt`, `iap.sandbox_rejected`, `epointWebhook: unknown order_id` hadisələrinin sayı — real hücum siqnalları |
| iOS runtime davranışı | Simulyator/cihaz icrası əhatədə deyil | `peakpin://` sxemi ilə deep link davranışı; App Check DeviceCheck |

---

## 22. Tələb Olunan Düzəlişlər (prioritetlə)

### P0 — BURAXILIŞDAN ƏVVƏL MÜTLƏQ (buraxılışı bloklayır)

| # | ID | İş | Təxmini həcm |
|---|---|---|---|
| 1 | **C-1** | `deleteStorageObjectByUrl`-ə prefiks allowlist-i (`chat_photos/{chatId}/`, `chat_videos/…`, `chat_audio/…`); `deleteStorageFile`-ın `catch{}`-inə `logger.warn` | **~2 saat** |
| 2 | **C-3** | `AuthController.completeOnboarding`-dən `AsyncValue.guard`-ı çıxar + `rethrow`; `posts`/`stories` create-ə `isActiveUser()` | **~3 saat** |
| 3 | **C-2** | `emergencyToken` axınını sil (skript + login `useEffect` + `package.json` sətri); bütün admin hesabları üçün `revokeRefreshTokens` | **~1 saat** |
| 4 | **H-3** | `chats` `allow update`-ə `participants`/`initiatorId` sabitliyi | **~30 dəq** |
| 5 | **H-1** | `distanceMeters`-i 100 m səbətlərə yuvarlaqlaşdır | **~30 dəq** |
| 6 | **H-2** | `previewVenueAudience`: `lat`/`lng`-i məkan sənədindən oxu, `radiusKm`-i məhdudlaşdır, `mode` allowlist-i | **~1 saat** |
| 7 | **H-5** | `photoUrl`/`imageUrl`/`coverImageUrl`/`mediaUrl` üçün Storage-mənşə yoxlaması (rules + 5 callable) | **~4 saat** |
| 8 | **H-7** | `managePayments` icazəsi əlavə et, 3 action + 3 səhifəni ona bağla | **~1 saat** |
| 9 | **H-8** | `/api/health` faylını sil | **~5 dəq** |
| 10 | **H-9** | `private/{document}` write qaydasına sahə blocklist-i (`birthDate`,`email`,`phoneNumber`,`consent`,`loginProvider`,`blockedByUsers`) | **~1 saat** |
| 11 | **H-4** | `chats` `allow delete: if false` + `hiddenFor` per-user gizlətmə (və ya minimum: silmədən əvvəl təsdiq + hər iki tərəfə bildiriş) | **~1 gün** |
| 12 | **M-8** | `epointWebhook`-un tam payload logunu istifadə olunan 4 sahəyə endir | **~15 dəq** |

**P0 cəmi: ~2.5 gün.**

### P1 — Buraxılışdan sonra ilk həftə

| # | ID | İş |
|---|---|---|
| 13 | M-1, M-2, M-3, M-4, M-5 | Çatışmayan `enforceRateLimit` çağırışları (5 nöqtə) + `assertActiveUser` (2 nöqtə) |
| 14 | H-6 | `usernames` `allow list: if false` + `searchUsersByUsername` callable-a köçür |
| 15 | M-7 | `reviews` `allow list: if false` |
| 16 | M-10 | Storage Content-Type allowlist-i (SVG-ni çıxar) |
| 17 | M-13 | Admin panel security header-ləri |
| 18 | M-14 | `android:allowBackup="false"` |
| 19 | M-15 | `posts`/`stories`/`comments` create validasiyası (`hasOnly` + ölçü + sayğac == 0) |
| 20 | M-6 | `joinWaitlist`-də sahibin öz məkanı istisnası + `reviews` create-də owner istisnası |
| 21 | M-9 | `boost_fee` stack etsin (və ya `superseded` → avtomatik `refund_pending`) |
| 22 | M-2 | `endAt(`${query}`)` — prefiks axtarışının bərpası |
| 23 | M-11 | `forwardChatMedia` hədəf çat yoxlaması + ayrıca limit |
| 24 | M-12 | WebView `onNavigationRequest` allowlist-i |

### P2 — Buraxılış + 1 ay

* Admin panel MFA (ACCEPTED_RISKS AUTH-8b-nin şərtini "launch"-a dəyişdir)
* Node 20 → 22 (BACKLOG #1)
* Blok mexanizminin feed oxu qaydalarına genişləndirilməsi (F-4)
* M-16 — chat mediasının path + signed URL modelinə keçidi
* ProGuard/R8 (BACKLOG #4)
* Mövcud BACKLOG #2, #3, #8, #10, #11, #12

---

## 23. Reqressiya Testləri (əlavə edilməli)

`tests/` qovluğundakı mövcud emulator test dəstinə əlavə olunmalı hallar:

**Firestore Rules testləri**
1. `chats/{id}` `update` ilə `participants`-i dəyişmək → **DENY** (H-3)
2. `chats/{id}` `delete` → **DENY** (H-4 düzəlişindən sonra)
3. `users/{uid}/private/data`-ya `birthDate`/`email`/`phoneNumber`/`consent` yazmaq → **DENY**; `lat`/`lng`/`ghostModeEnabled` yazmaq → **ALLOW** (H-9)
4. `users/{uid}` sənədi olmayan auth istifadəçisi `posts`/`stories` yaratmaq → **DENY** (C-3)
5. `usernames` üzərində `list` → **DENY**; `get` → **ALLOW** (H-6)
6. `reviews` üzərində `list` → **DENY**; `get` → **ALLOW** (M-7)
7. `users/{me}`-yə `photoUrl: "https://evil.test/x.jpg"` → **DENY**; real Storage URL → **ALLOW** (H-5)
8. `posts` create-də `likesCount: 999` → **DENY**; `authorIsPublic: true` → **DENY** (M-15)
9. Məkan sahibinin öz məkanına `reviews` yaratması → **DENY** (M-6)

**Cloud Functions testləri (emulator)**
10. `chats/{a}_{b}/messages` sənədi `mediaUrl: "x/o/profile_photos%2Fvictim%2Fp.jpg"` ilə → çat silinəndə həmin fayl **qalmalıdır**; real `chat_photos/…` URL-i → **silinməlidir** (C-1)
11. `previewVenueAudience` fərqli `lat`/`lng` göndərsə nəticə **dəyişməməlidir**; `radiusKm: 20000` → `invalid-argument` (H-2)
12. `findNearbyUsers`-in qaytardığı `distanceMeters` 100-ün tam qatı olmalıdır (H-1)
13. `joinWaitlist` məkan sahibi tərəfindən → `permission-denied` (M-6)
14. `getDiscoverCandidates` 11-ci çağırışda `resource-exhausted` (M-1)
15. `searchUsersByName("ras")` → `nameLower` "ras" ilə başlayan profillər qaytarmalıdır (M-2)
16. `submitVenue`-nin qaytardığı `venueId` client-in göndərdiyindən **fərqli** olmalıdır (M-4)
17. `boost_fee`: iki `completed` ödəniş → `boostedUntil` **cəmlənməlidir** (M-9)

**Admin panel testləri**
18. moderator sessiyası ilə `initiateRefund`/`markPaymentRefunded`/`markPinBoxPayoutPaid` → `forbidden`; `/payments` → redirect (H-7)
19. `GET /api/health` sessiyasız → 404 (H-8)
20. `/login?emergencyToken=<hər hansı>` → giriş **olmamalıdır** (C-2)
21. Cavab başlıqlarında `X-Frame-Options: DENY`, `Strict-Transport-Security`, `Content-Security-Policy` mövcud olmalıdır (M-13)

**Client (Flutter) testləri**
22. Widget testi: `completeOnboarding` `HttpsError('failed-precondition','age-under-18')` atsın → `HomeScreen`-ə naviqasiya **olmamalı**, xəta mesajı görünməlidir (C-3)

---

## 24. Təhlükəsizlik Balı

```
Authentication:        6/10   (C-3 onboarding gate; MFA yox; server parol min. 6.
                               Müsbət: token/sessiya idarəsi, revokeRefreshTokens,
                               fresh-login pəncərəsi, email doğrulaması qapısı)
Authorization / RBAC:  5/10   (H-7 moderator→maliyyə; H-9 private/data; H-3 chats.
                               Yalnız 2 rol; Server Action-ların hamısı auth yoxlayır ✅)
Firebase Rules:        6/10   (Çox güclü sənədləşdirilmiş, əksər kolleksiyalar
                               möhkəm. Boşluqlar: chats.participants, usernames list,
                               posts/stories/comments create, private/data)
API:                   5/10   (9 callable-da rate limit yox; H-2 input validasiyası;
                               C-1 client sahələrinə etibar)
Payments (Epoint):     8/10   (Ən güclü sahə: server-side qiymət, tranzaksiyada
                               idempotentlik, timingSafeEqual, amount_mismatch,
                               tam refund zənciri, EPOINT_ENV fail-safe.
                               Çıxılan: M-8 log, M-9 boost stack)
Payments (Store IAP):  8/10   (Real store doğrulaması, ownership claim, sandbox
                               tester allowlist-i, RTDN/ASSN imzaları.
                               Çıxılan: APPLE_APP_STORE_ID yox, M-5 limit yox)
Business Logic:        6/10   (M-6 saxta rəy; M-3 növbə spam-ı; M-4.
                               Boost/premium/PinBox stok məntiqi möhkəm ✅)
Location Privacy:      4/10   (H-1 trilaterasiya bütün modeli sındırır; H-2 orakl;
                               M-7 ziyarət tarixçəsi. Ghost Mode və radius server
                               tərəfdə düzgün tətbiq olunur ✅ — amma keçilir)
Chat:                  4/10   (C-1 kökü buradadır; H-3 blok bypass; H-4 birtərəfli
                               məhv; M-16 bearer URL. Mesaj redaktəsi/oxu ✅)
Mobile Security:       5/10   (M-14 backup; M-12 WebView; H-5 xarici URL;
                               R8/pinning yox. Secure storage ✅, imzalama ✅,
                               exported komponentlər ✅)
Admin Security:        4/10   (C-2 emergencyToken; H-8 /api/health; H-7 RBAC;
                               M-13 header yox; MFA yox. Sessiya modeli ✅,
                               server-only Admin SDK ✅, audit izi ✅)
Infrastructure:        6/10   (Node 20 EOL; App Check off (qəsdən).
                               Secret idarəsi əla ✅, ADC ✅, git təmiz ✅)
Dependencies:          6/10   (Node 20 EOL; tərk edilmiş video_thumbnail forku;
                               qalan hər şey cari)
Store Readiness:       5/10   (C-3 uşaq təhlükəsizliyi bəyannaməsini yanlış edir;
                               H-5 moderasiya + Data Safety riski; M-14.
                               İmzalama, hesab silmə, force-update ✅)

OVERALL: 56/100
```

### Müqayisə

```
PREVIOUS AUDIT:     13 CRITICAL, 60+ HIGH, 32/100
SECOND PASS:         3 CRITICAL,  9 HIGH, 56/100
NEW ISSUES:         27 (bunlardan 2 CRITICAL, 5 HIGH)
REGRESSIONS:         2 (R-1 birthDate kilidi, R-2 prefiks axtarışı)
FIX-INCOMPLETE:      4 (F-1 RT-25, F-2 K-10, F-3 K-13, F-4 K-3)
REMAINING FROM #1:   6 (K-1 qismən, K-3 qismən, K-7 açıq, K-10 qismən,
                        K-12 açıq, K-13 qismən + RBAC-12, RBAC-18)
```

---

## 25. Buraxılış Qərarı

# 🔴 DO NOT RELEASE — CRITICAL SECURITY ISSUES

### Əsaslandırma

Bu qərar üç konkret, kod səviyyəsində sübut edilmiş tapıntıya söykənir — nəzəri
riskə deyil:

**1. C-1 — bütün Storage bucket-i istənilən istifadəçi tərəfindən silinə bilər.**
`functions/src/index.ts:5225` client-in yazdığı `mediaUrl`-i
`functions/src/index.ts:1259`-un `storage.bucket().file(path).delete()`-inə
ötürür. Aradakı `storagePathFromUrl` (`:1271`) yalnız `/o/` ayırıcısını axtarır.
`firestore.rules:746-755` `mediaUrl`-ə heç bir məhdudiyyət qoymur. Bu, tək bir
zərərli hesabla bütün istifadəçilərin profil şəkillərinin, bütün biznes
məzmununun və KYC sübutlarının geri qaytarılmaz şəkildə silinməsi deməkdir.
Bu, buraxılışdan sonra düzəldilə bilən bir şey deyil — silinən fayllar geri
gəlmir.

**2. C-3 — 18+ yaş qapısı istehsalatda mövcud deyil.**
Server yoxlaması doğru yazılıb (`functions/src/index.ts:470-472`), lakin
`lib/features/auth/presentation/providers/auth_providers.dart:85-97`-nin
`AsyncValue.guard`-ı xətanı udur və
`lib/features/auth/presentation/screens/onboarding_screen.dart:249-252` şərtsiz
`HomeScreen`-ə keçir. `legal/child-safety-standards.html` mövcud olmayan bir
nəzarəti iddia edir. Bu, təkcə təhlükəsizlik məsələsi deyil — Google Play-in
Uşaq Təhlükəsizliyi bəyannaməsinə qarşı yanlış bəyanatdır və hesab
dayandırılması riski daşıyır.

**3. C-2 — admin panelin tam ələ keçirilməsi bir Cloud Logging sorğusu
uzaqlıqdadır.** `admin-panel/src/app/login/page.tsx:71-84` hələ də URL-dən
custom token qəbul edir, `scripts/mint-emergency-token.ts:86` hələ də belə link
yaradır və `package.json:12` bunu bir əmr uzaqlığında saxlayır. Bu tapıntı
**birinci auditdə də var idi (K-12)** və 12 düzəliş promptu ərzində
toxunulmayıb.

Bunların üzərinə H-1 (lokasiya trilaterasiyası) gəlir: bu, tətbiqin əsas
məhsul vədini — "yaxınlıqdakı insanları görün, amma dəqiq yeriniz gizli
qalsın" — kod səviyyəsində yalana çevirir. Yuvarlaqlaşdırma var, amma eyni
cavabda xam məsafə verilir.

### Buraxılışdan əvvəl bağlanması MÜTLƏQ olanlar

| # | ID | Niyə bloklayır |
|---|---|---|
| 1 | **C-1** | Geri qaytarılmaz kütləvi data məhvi; bir hesabla istismar edilir |
| 2 | **C-3** | 18+ nəzarəti mövcud deyil; yayımlanmış bəyannamə yanlışdır |
| 3 | **C-2** | Bir daxili şəxs → tam admin; birinci auditdən qalıb |
| 4 | **H-1** | Dəqiq lokasiya bərpası — məhsulun əsas məxfilik vədinin pozulması |
| 5 | **H-2** | İxtiyari nöqtədə istifadəçi mövcudluğu oraklı (fiziki təhlükəsizlik) |
| 6 | **H-3** | Prompt 5-in bütün blok mexanizminin keçilməsi (anti-taciz) |
| 7 | **H-5** | Moderasiya olunmayan xarici məzmun + IP toplama (mağaza siyasəti) |
| 8 | **H-9** | `birthDate`/`consent`/`phoneNumber` bütövlüyünün itməsi (C-3 ilə birlikdə uşaq təhlükəsizliyi) |
| 9 | **H-7** | Moderator real pul hərəkət etdirə bilir |
| 10 | **H-8** | Autentifikasiyasız Admin SDK endpoint-i |

H-4 və M-8 də P0-dadır (bax Bölmə 22), amma yuxarıdakı 10 mütləq minimumdur.

**Təxmini iş həcmi: ~2.5 gün.** Bundan sonra bal təxminən **78-82/100**
səviyyəsinə qalxar və qərar **🟡 READY AFTER MEDIUM FIXES**-ə çevrilər (P1
maddələri ilk həftədə).

---

*Hesabat sonu. Bütün tapıntılar fayl:sətir ilə əsaslandırılıb; yoxlana
bilməyənlər Bölmə 21-də açıq sadalanıb. Heç bir zəiflik production-da istismar
edilmədi — hər biri yalnız kod səviyyəsində sübut olundu.*
