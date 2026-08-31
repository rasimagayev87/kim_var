# PeakPin — Üçüncü mərhələ təhlükəsizlik auditi

**Tarix:** 2026-08-30 · **Commit:** `8dc2fa4` (`full-local-version`)
**Rejim:** yalnız oxuma. Kod dəyişdirilmədi, deploy edilmədi,
production-a yazılmadı, Epoint API-sinə sorğu göndərilmədi.
Yeganə icra edilən şey: yerli emulator-da bir müvəqqəti probe testi
(nəticəsi A3-H1-də, fayl dərhal silindi) və artıq təsdiqlənmiş
read-only telefon audit skripti.

## Bu auditin fokusu

Audit 2 (2026-08-28/30) ilkin kod bazasını əhatə etdi və 3 CRITICAL +
9 HIGH bağlandı. O remediasiya **böyük həcmli** idi: 40 callable,
2114 sətir Firestore rules, 249 sətir Storage rules, iki ayrı hesab
silmə axını. Audit 3 ona görə iki şeyə baxır:

1. **Remediasiyanın öz regressiya səthi** — düzəlişlər yeni deşik
   açıbmı, və elan edilən nəzarətlər həqiqətən hər yoldan işləyirmi.
2. **Audit 2-nin çatmadığı sahələr** — Storage obyektlərinin həyat
   dövrü, Resize Images uzantısı, kolleksiya siyahılama (`list`)
   səthi, rate-limit əhatəsi.

Nəticə: **2 HIGH, 4 MEDIUM, 4 LOW**. Yeni CRITICAL yoxdur — Audit 2-də
bağlanan CRITICAL-lərin heç biri geri qayıtmayıb (hər biri üçün
regressiya testi mövcuddur və 296/296 keçir).

---

## Əvvəlki hesabatımdakı bir səhvin düzəlişi

Faza 3-4 hesabatında rate-limit əlavə edildiyini bildirdiyim
funksiyaların bir hissəsində **rate limit yoxdur**. Git tarixçəsi
təsdiqləyir ki, bu heç vaxt yazılmayıb — merge-də itməyib, sadəcə
mənim hesabatım işin həcmini olduğundan geniş göstərib:

```
$ git log --all -S'"kyc"' -- functions/src/index.ts        → 0 commit
$ git log --all -S'"qr"' -- functions/src/index.ts         → 0 commit
$ git log --all -S'"delete-account"' -- .../index.ts       → 0 commit
```

Faktiki vəziyyət A3-M1-də cədvəl şəklindədir. `submitOffer`
(`submit-listing 10/3600s`) və `forwardChatMedia`
(`forward-chat-media 30/600s`) mövcuddur, amma adları/limitləri
hesabatda yazdığımdan fərqlidir.

---

# HIGH

## A3-H1 — İstifadəçinin sildiyi post/story/profil şəkli Storage-da qalır və oxunaqlı olaraq qalır

**Sinif:** məlumatın saxlanması / məxfilik · **Sübut edildi:** bəli, emulator

`storage.rules`-da `posts`, `stories`, `profile_photos` (və digər
sahib-əsaslı yollar) `allow write` istifadə edir və şərtdə
`request.resource.size` var:

```
storage.rules:215   match /posts/{userId}/{fileName} {
storage.rules:216     allow read: if request.auth != null;
storage.rules:218     allow write: if request.auth != null
storage.rules:219                  && request.auth.uid == userId
storage.rules:220                  && (
storage.rules:221                    (isAllowedImageType() && request.resource.size < 5 * 1024 * 1024) ||
storage.rules:222                    (isAllowedVideoType() && request.resource.size < 50 * 1024 * 1024)
storage.rules:223                  );
```

Storage Rules-da `write` = `create` + `update` + **`delete`**. DELETE
sorğusunda `request.resource` **null**-dur, ona görə
`request.resource.size` qiymətləndirilə bilmir və bütün şərt `false`
olur. Yəni **sahib öz faylını silə bilmir.**

Client silməyə cəhd edir və xətanı udur:

```dart
lib/features/post_share/data/repositories/firebase_post_repository.dart:171
    await _posts.doc(postId).delete();
:172   try {
:173     await _storage.refFromURL(mediaUrl).delete();
:174   } catch (_) {
:175     // Best-effort — the Firestore doc is already gone either way, and
:176     // an orphaned Storage object isn't worth failing the delete over.
:177   }
```

Şərh "orphaned Storage object" deyir — amma bu, sadəcə itmiş bayt
deyil. `posts/{userId}/{fileName}` üçün `allow read: if request.auth
!= null` qüvvədədir, üstəlik obyektin download token-i heç vaxt ləğv
edilmir. Yəni:

* Firestore sənədi gedir, şəkil qalır.
* URL-i saxlamış **istənilən qeydiyyatlı istifadəçi** onu oxumağa
  davam edir.
* Token-li URL-i saxlamış **istənilən kəs** (Firebase sessiyası
  olmadan, brauzerdən) onu oxumağa davam edir — token Storage Rules-u
  tamamilə keçir.

İstifadəçi "sildim" görür; heç nə silinməyib.

**Emulator sübutu** (müvəqqəti probe, sonra silindi — 4/4 keçdi):

```
✔ posts/{uid}: yükləyə bilir, AMMA silə bilmir
✔ stories/{uid}: eyni davranış
✔ profile_photos/{uid}: eyni davranış
✔ MÜQAYİSƏ — chat_photos ayrıca `allow delete` ilə: silmə İŞLƏYİR
```

Sonuncu sətir vacibdir: **düzgün naxış bu faylda artıq mövcuddur.**
`chat_photos`/`chat_videos`/`chat_audio` (Düzəliş Prompt 3 / RT-8)
`allow create` + ayrıca `allow delete: if request.auth.uid ==
senderId` yazır və silmə işləyir. Sahib-əsaslı digər yollar həmin
ayrılığı almayıb.

**Təklif olunan düzəliş:** hər sahib-əsaslı yolda `allow write`-ı
`allow create, update` (ölçü/tip şərti ilə) + `allow delete: if
request.auth != null && request.auth.uid == userId` şəklinə bölmək —
`chat_photos`-un eynisi. Probe testi daimi regressiya testinə
çevrilməlidir.

**Qeyd:** hesab tam silinəndə `deleteStoragePrefix('posts/{uid}/')`
(`functions/src/index.ts:377`) Admin SDK ilə işləyir və rules-a tabe
deyil — ona görə **hesab silinməsi düzgün işləyir**. Problem yalnız
tək-tək post/story silinməsindədir.

---

## A3-H2 — `_200x200` törəmə şəkillər heç vaxt silinmir və orijinalın token-ini paylaşır

**Sinif:** məlumatın saxlanması / məxfilik · **Sübut edildi:** kod səviyyəsində

Resize Images uzantısı aktivdir və **chat şəkilləri də daxil olmaqla**
demək olar hər yolu əhatə edir:

```
extensions/storage-resize-images.env:28  RESIZED_IMAGES_PATH=          ← boş: törəmə orijinalın YANINDA yaranır
extensions/storage-resize-images.env:29  INCLUDE_PATH_LIST=/profile_photos,/venue_photos,/offer_photos,/pinbox_photos,/stories,/posts,/event_covers,/chat_photos
extensions/storage-resize-images.env:51  REGENERATE_TOKEN=false        ← törəmə ORİJİNALIN token-ini təkrar istifadə edir
```

`RESIZED_IMAGES_PATH` boş olduğu üçün `chat_photos/{chatId}/{senderId}/{messageId}.jpg`
üçün törəmə `chat_photos/{chatId}/{senderId}/{messageId}_200x200.jpg`
olur (`lib/core/widgets/app_image.dart:31-34` bu adı məhz belə
düzəldir).

Silmə isə **dəqiq yol** ilə işləyir və yalnız orijinalı hədəfləyir:

| Sil | Yer | Törəmə |
|---|---|---|
| Çat mediası (C-1 düzəlişi) | `functions/src/index.ts:1996` — `deleteStorageFile(chatMediaPathForMessage(...))` | **qalır** |
| Məkan şəkli | `functions/src/index.ts:1860` — `venue_photos/{id}.jpg` | **qalır** |
| Təklif şəkli | `functions/src/index.ts:1871` — `offer_photos/{id}.jpg` | **qalır** |
| Hesab silinməsi | `deleteStoragePrefix(...)` — prefiks | silinir ✅ |

Ən ciddi hal çatdır. C-1 və H-4 işinin bütün məqsədi çat mediasının
düzgün silinməsi idi:

* İstifadəçi "hər kəs üçün sil" edir → orijinal gedir, `_200x200`
  qalır.
* Hər iki tərəf çatı gizlədir → `hardDeleteFullyHiddenChat` →
  `onChatDeleted` → orijinallar gedir, `_200x200`-lər qalır.

Və `REGENERATE_TOKEN=false` olduğu üçün törəmənin token-i orijinalın
token-i ilə **eynidir** — yəni qarşı tərəfin artıq gördüyü URL-də bir
sətirlik dəyişikliklə (`.jpg` → `_200x200.jpg`) "silinmiş" şəkil geri
gəlir. 200×200 kiçikdir, amma tanınmaq üçün tamamilə kifayətdir.

`.env`-dəki şərh "No security cost: the resized image is the exact
same content at a smaller size, so anyone who could already read one
could always derive the other" deyir. Bu, **silmə nəzərə alınmadan**
yazılmış mühakimədir: doğrudur ki, oxu icazəsi eynidir — amma silmə
icazəsi eyni deyil, çünki silən kod törəmənin adını heç vaxt
hesablamır.

**Təklif olunan düzəliş:** `deleteStorageFile`-a törəməni də silmək
məsuliyyəti vermək (adı `chatMediaPathForMessage`-in özü kimi saf
funksiya ilə törətmək — `{ad}_200x200.{uzantı}`), və `IMG_SIZES`
gələcəkdə dəyişərsə siyahının bir yerdən gəlməsi. Alternativ:
`RESIZED_IMAGES_PATH`-i ayrıca prefiksə vermək və prefiks silmədən
istifadə etmək — amma bu, mövcud URL-lərin hamısını sındırar, ona görə
tövsiyə etmirəm.

---

# MEDIUM

## A3-M1 — 14 callable-da rate limit yoxdur, biri autentifikasiyasız public endpoint-dir

`enforceRateLimit` (`functions/src/index.ts:147`) özü **düzgündür** —
tranzaksiyalıdır, Firestore çökərsə fail-closed davranır. Problem
əhatədir: 40 funksiyadan **14-də** heç bir çağırış yoxdur.

| Funksiya | Nəyə görə əhəmiyyətlidir |
|---|---|
| `appStoreServerNotifications` (`:8499`) | **Autentifikasiyasız, public HTTP.** Hər sorğu iki dəfə JWS imza doğrulaması edir (əvvəl Production, sonra Sandbox) — yəni zibil `signedPayload` göndərməklə kriptoqrafik iş və Cloud Functions faturası artırıla bilər. Ən yüksək prioritetli boşluq |
| `deleteAccount` (`:329`) | ~15 addımlıq kaskad: onlarla kolleksiya sorğusu + Storage prefiks silmələri. Geri qaytarıla bilməyən və çox bahalı |
| `submitIdentityVerification` (`:4813`) | KYC şəkillərinin yüklənməsi + admin növbəsinin doldurulması |
| `submitVenue` (`:5514`) | Moderasiya növbəsinin sel ilə doldurulması |
| `generatePinBoxQrToken` (`:6682`) | Token istehsalı |
| `updateVenue`, `resubmitVenue`, `updateOffer`, `resubmitOffer`, `updatePinBox`, `resubmitPinBox` | Moderasiya növbəsinin təkrar-təkrar sıfırlanması |
| `deleteSavedCard`, `setDefaultSavedCard` | Aşağı risk |
| `unregisterFcmToken` | Aşağı risk |

`appStoreServerNotifications` üçün nəzərə alın ki, Apple-ın öz
serveri App Check təqdim edə bilmir — ona görə IP əsaslı bir scope
(`enforceRateLimit("store-notify", req.ip, ...)`) məntiqlidir; Apple
öz bildirişlərini məhdud sayda IP-dən göndərir və uğursuz cəhdlərdə
təkrar göndərir, ona görə limit səxavətli olmalıdır.

## A3-M2 — ~~`audienceHistory` H-2-də qoyulan k-anonimlik həddini keçir~~ — BAĞLANDI (2026-08-31)

> Kolleksiya tamamilə bağlandı (`allow read: if false`). Canlı tab artıq
> `venues/{id}.currentAudienceCount` oxuyur — serverdə həddlənmiş
> aqreqat sahə. Xam seriya yalnız pik-saat detektoru üçün server
> tərəfdə qalır. Bax `docs/VENUE_OCCUPANCY.md`.


H-2-də `previewVenueAudience`-ə qəsdən mərtəbə qoyduq:

```
functions/src/index.ts:1274  const VENUE_AUDIENCE_MIN_REPORTABLE_COUNT = 5;
functions/src/index.ts:1365  return { count: count < VENUE_AUDIENCE_MIN_REPORTABLE_COUNT ? 0 : count };
```

Amma eyni məlumatın xam variantı hər qeydiyyatlı istifadəçiyə açıqdır:

```
firestore.rules:1432   match /venues/{venueId}/audienceHistory/{entryId} {
firestore.rules:1433     allow read: if request.auth != null;
firestore.rules:1434     allow write: if false;
```

`computeVenueAudienceHistory` (`functions/src/index.ts:2905`) hər 15
dəqiqədən bir `{count, hour, timestamp}` yazır və 7 gün saxlayır.
Sənədlərdə uid və ya demoqrafik yoxdur — ona görə bu HIGH deyil. Amma
`count: 1` və `count: 2` dəyərləri **məhz previewVenueAudience-in
verməkdən imtina etdiyi dəyərlərdir**, və burada hər məkan üçün, 15
dəqiqəlik dəqiqliklə, 7 günlük tarixçə şəklində əlçatandır. Kiçik bir
məkanda `count: 1` "orada bir nəfər var" deməkdir.

Qaydanın öz şərhi səbəbi açıq yazır: *"a future owner-facing analytics
view could read a venue's own history without a rules change"* — yəni
icazə **hələ mövcud olmayan bir funksiya üçün** əvvəlcədən
verilib.

**Təklif olunan düzəliş:** oxunu məkan sahibinə bağlamaq. Naxış eyni
faylda, iki blok aşağıda hazırdır — `venues/{venueId}/waitlist`
(`firestore.rules:1445+`) sabit valideyn sənədə `get()` edir və
məhz bu səbəbdən list-query problemi yaratmır.

## A3-M3 — `redemptions` və `likes` heç kimin istifadə etmədiyi uid siyahılaması verir

```
firestore.rules:1391   match /venues/{venueId}/likes/{userId}      → allow read: if request.auth != null;
firestore.rules:1606   match /offers/{offerId}/redemptions/{userId} → allow read: if request.auth != null;
```

`read` = `get` + **`list`**. Yəni istənilən hesab bütün
`offers/{id}/redemptions` kolleksiyasını siyahılayıb həmin təklifi
aktivləşdirmiş **bütün uid-ləri** ala bilər — sənədin ID-si elə
uid-in özüdür. `users/{uid}` public olduğuna görə bu, adlı siyahıya
çevrilir: "filan məkanın ilk-ziyarət təklifini kim istifadə edib".

Client bunu heç vaxt siyahılamır — yalnız öz sənədinə baxır:

```dart
lib/features/offers/data/datasources/firebase_offer_remote_datasource.dart:152
    return _redemptions(offerId).doc(uid).snapshots().map((doc) => doc.exists);
lib/features/venues/data/datasources/firebase_venue_remote_datasource.dart:160
    return _likes(venueId).doc(uid).snapshots().map((doc) => doc.exists);
```

`likeCount` valideyn sənəddə trigger ilə saxlanılır, ona görə sayma
üçün də siyahılama lazım deyil. `allow get: if ...; allow list: if
false;` heç nəyi sındırmır.

Bu, `reviews` (Audit 2-də bağlandı) və `activeCheckins` (əvvəlki
turda bağlandı — qaydanın öz şərhi *"Raw `activeCheckins` list access
is now owner/checked-in-user-only"* deyir) ilə **eyni sinifdir**; iki
qardaş kolleksiya sadəcə unudulub.

## A3-M4 — `config/{docId}` joker oxusu gələcək sənədləri avtomatik açır

```
firestore.rules:177   match /config/{docId} {
firestore.rules:178     allow read: if request.auth != null;
firestore.rules:179     allow write: if false;
```

Qaydanın şərhi hansı sənədlərin "harmless for the client to read"
olduğunu sadalayır — amma qayda joker `{docId}`-dir, yəni **sonradan
əlavə edilən hər config sənədi avtomatik olaraq bütün qeydiyyatlı
istifadəçilərə açılır**. Bunun artıq bir nümunəsi var:

`config/iapTesters.testerUids` — Sandbox qəbzi ilə pulsuz VIP almağa
icazəsi olan uid-lərin siyahısı (`functions/src/index.ts:8412`).
Birbaşa eskalasiya deyil (o uid **olmaq** lazımdır), amma daxili
allowlist-in hər kəsə görünməsinin heç bir səbəbi yoxdur.

**Təklif olunan düzəliş:** `docId in ['legal','waitlistCategories',
'eventCategories','businessOffer',...]` şəklində açıq siyahı.

---

# LOW

## A3-L1 — Silinmiş hesabı olan çatlar heç vaxt sərt silinə bilmir

`deleteAccount` çat **sənədlərinə** toxunmur — yalnız
`replaceMessagesWithPlaceholder(uid)` çağırılır
(`functions/src/index.ts:356`). Silinmiş uid `participants`-də qalır.

`isChatHiddenByEveryone` bütün iştirakçıların `hiddenFor`-da olmasını
tələb edir (`functions/src/chat-media.ts`), silinmiş istifadəçi isə
heç vaxt bayrağını qoya bilməz. Nəticə: qarşı tərəf çatı gizlətsə
belə `hardDeleteFullyHiddenChat` işə düşmür — sənəd, mesajlar və
qarşı tərəfin mediası əbədi qalır. H-4 kaskadı məhz ən çox tərk
edilən çatlarda səssizcə söndürülüb.

**Təklif:** `deleteAccount` istifadəçinin çatlarında
`hiddenFor.{uid} = true` qoysun — bir sətirlik, mövcud məntiqlə tam
uyğun.

## A3-L2 — `rateLimits` kolleksiyası heç vaxt təmizlənmir

`enforceRateLimit` hər `scope:key` üçün sənəd yaradır və heç bir
sweep yoxdur. Hər istifadəçi × hər scope = daimi sənəd. Təhlükəsizlik
deşiyi deyil, xərc/böyümə maddəsidir; `cleanupStaleCheckins`
naxışında planlaşdırılmış silmə kifayətdir.

## A3-L3 — Admin bildirişlərində sənəd səviyyəsində icazə yoxlaması yoxdur

`markAdminNotificationRead(id)` / `markAllAdminNotificationsRead()`
(`admin-panel/src/lib/actions/admin-notifications.ts:17,30`) yalnız
`getCurrentAdmin()` yoxlayır. RBAC-da `notification-visibility.ts`
ödəniş bildirişlərini moderator-dan gizlədir — amma o moderator
ID təxmin edərək həmin bildirişi oxunmuş kimi işarələyə bilər.
Məzmun sızmır (funksiya data qaytarmır), yalnız bütövlük məsələsidir.

## A3-L4 — Apple webhook-unda iki xırda dayanıqlıq problemi

`functions/src/index.ts:8540` — `verifyAppleTransaction` `try/catch`-siz
çağırılır; `:8558` — `db.collection("users").doc(uid).update(...)`
mövcud olmayan sənəddə `NOT_FOUND` atır. Hər ikisi 500 qaytarır və
Apple bildirişi təkrar-təkrar göndərir (A3-M1-dəki rate-limit
olmaması ilə birləşəndə özünü gücləndirən dövr).

---

# Yoxlanılıb, tapıntı DEYİL

Səs-küyü azaltmaq üçün açıq yazıram:

* **`google-services.json` və `firebase_options.dart`-dakı `AIza…`
  açarları** — bunlar sirr deyil, dizayn etibarilə publicdir. Firebase
  client açarı yalnız layihəni identifikasiya edir; qoruma Rules və
  Auth-dadır. **Tapıntı deyil.** (Ayrıca yoxlanmalı olan şey Google
  Cloud Console-da açarın API/platform məhdudiyyətidir — bu, koddan
  görünmür.)
* **Repo-da izlənən sirr faylı yoxdur.** `extensions/storage-resize-images.env`
  yalnız uzantı konfiqurasiyasıdır; `admin-panel/.gitignore:34` `.env*`
  tutur.
* **Admin panelin 6 "qorunmayan" server action-u** — `payments.ts`,
  `pinbox-payouts.ts`, `pinboxes.ts` inline `hasPermission(admin.role,
  "managePayments"/"moderateOffers")` istifadə edir, `requireX()`
  helper-i yox. Qorunurlar. İlk regex-im dar idi.
* **`enforceRateLimit`-in özü** — tranzaksiyalı, `HttpsError`
  tranzaksiyadan **sonra** atılır (Admin SDK-nın retry davranışına
  görə düzgün qərar), Firestore çökərsə fail-closed.
* **IAP Sandbox fallback-i** — `verifyInAppPurchase`-də
  `config/iapTesters` allowlist-i var (H #196). Webhook-da allowlist
  yoxdur, **amma** o, əvvəlcə `iapSubscriptions/{originalTransactionId}`
  sahibliyini axtarır və tapmasa heç nə etmir — yəni callable-in
  rədd etdiyi bir Sandbox qəbzi webhook vasitəsilə də VIP verə bilmir.
  Dolayı, lakin real qoruma.
* **Audit 2-nin CRITICAL/HIGH düzəlişləri** — hamısı yerindədir,
  regressiya testləri ilə: 296/296 keçir.

---

# Prioritet sırası

| # | Tapıntı | Ciddilik | Təxmini iş |
|---|---|---|---|
| 1 | A3-H1 — `allow write`/`allow delete` ayrılması | HIGH | ~1 saat + test |
| 2 | A3-H2 — `_200x200` törəmələrin silinməsi | HIGH | ~2 saat + test |
| 3 | A3-M1 — `appStoreServerNotifications` rate limit | MEDIUM | ~30 dəq |
| 4 | A3-M1 — qalan 13 callable | MEDIUM | ~2 saat |
| 5 | A3-M2 — `audienceHistory` sahibə bağlanması | MEDIUM | ~30 dəq + test |
| 6 | A3-M3 — `list: if false` (2 kolleksiya) | MEDIUM | ~30 dəq + test |
| 7 | A3-M4 — `config` docId allowlist | MEDIUM | ~20 dəq |
| 8 | A3-L1 — silinən hesabın çatlarına `hiddenFor` | LOW | ~20 dəq |
| 9 | A3-L4 — webhook dayanıqlığı | LOW | ~20 dəq |
| 10 | A3-L2, A3-L3 | LOW | BACKLOG |

A3-H1 və A3-H2 birlikdə bir mesaj verir: **PeakPin-də "sil"
düyməsi Storage səviyyəsində etibarlı deyil.** İkisi eyni turda
bağlanmalıdır, çünki ayrı-ayrılıqda bağlansa istifadəçi hələ də
"silinmiş" şəklini geri gətirə bilər.
