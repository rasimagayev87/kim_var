# Məkanda insan sayı — üç ayrı anlayış

Bu sənəd bir səbəbə görə var: layihədə məkanla bağlı **üç fərqli say**
mövcuddur, adları bir-birinə oxşayır və **ikisi kodda bir sahəni
paylaşır**. Hansının harada göründüyü aşağıda dəqiq yazılıb.

| | Kim yaradır | Nə göstərir | Harada görünür | Faktiki mənbə |
|---|---|---|---|---|
| **1. Növbə / boş yer** | Məkan sahibi | Neçə boş yer qalıb | Canlı tab **və** məkan profili | `venues/{id}.availableSeats` |
| **2. «Ətrafınızda» (audience)** | Sistem | Yaxınlıqda neçə nəfər var | Canlı tab (kart + tiker), toxunulmaz | `venues/{id}.currentAudienceCount` |
| **3. Könüllü check-in** | İstifadəçi özü | Məkanda neçə nəfər var | **Yalnız** məkan profili | `venues/{id}.visibleCheckinCount` (xam say `private/counters`-də) |

---

## Qarışıqlıq bağlandı (2026-08-31)

Bir müddət **2 və 3 eyni sahədən qidalanırdı**: Canlı tabındakı
«Ətrafınızda» `activeCheckinCount` oxuyurdu, yəni könüllü check-in
sayını sistem audience-i adı altında göstərirdi. İki nəticəsi vardı —
tab yalnız düymə basmışları sayırdı, və düyməni basan adam yalnız
profildə görünəcəyini gözlədiyi halda radiusdakı hər kəsə görünürdü.

**İndi ayrıdır:**

```
«Ətrafınızda»  →  venues/{id}.currentAudienceCount
                  ← computeVenueAudienceHistory (15 dəq, lastSeen/online + mövqe)

Check-in       →  venues/{id}.visibleCheckinCount
                  ← bumpActiveCheckinCount ← activeCheckins/{uid}
```

Hər ikisi **serverdə k-anonimlik həddi (5) ilə** yazılır — həddən
aşağıda sahə 0-dır. Hədd client-də tətbiq edilmir: `venues/{id}` hər
qeydiyyatlı istifadəçiyə oxunaqlıdır, ona görə xam rəqəmi yazıb UI-da
gizlətmək məxfilik deyil, bəzək olardı.

**Doğruluq mənbəyi:**

| Dəyər | Harada | Kim oxuya bilər |
|---|---|---|
| Xam check-in sayı | `venues/{id}/private/counters.activeCheckinCount` | **heç kim** — server-only |
| Göstərilən check-in sayı | `venues/{id}.visibleCheckinCount` | hər qeydiyyatlı istifadəçi |
| Xam audience seriyası | `venues/{id}/audienceHistory/*` | **heç kim** — server-only |
| Göstərilən audience | `venues/{id}.currentAudienceCount` | hər qeydiyyatlı istifadəçi |

`bumpActiveCheckinCount` xam sayı və güzgünü **eyni tranzaksiyada**
yazır — drift mümkün deyil.

**`audienceHistory` bağlanması Audit 3 / A3-M2-ni də bağladı** — həmin
tapıntı kolleksiyanın hər qeydiyyatlı istifadəçiyə açıq olması və
k-anonimlik həddini keçməsi idi.

**Köhnəlik:** `currentAudienceCount` 15 dəqiqədə bir yenilənir.
`audienceCountUpdatedAt` 20 dəqiqədən köhnədirsə kart **göstərilmir** —
planlaşdırılmış funksiya dayanarsa rəqəm yox olur, köhnəlmir.

**Ghost Mode:** sistem audience-indən **çıxarılır** (hər üç rejimdə,
`computeAudienceCount`). Check-in-də **çıxarılmır** — istifadəçi
könüllü düymə basıb.

> **2026-08-31 düzəlişi — bu cümlə 2026-08-31-ə qədər DOĞRU DEYİLDİ.**
> `ghostModeEnabled` Düzəliş Prompt 4 / K-1-də `private/data`-ya
> köçmüşdü, `computeVenueAudienceHistory` isə onu hələ də publik
> `users` sənədindən oxuyurdu — yəni süzgəc üç rejimin **heç birində**
> işləmirdi. `distance` rejimində bunun əhəmiyyəti yox idi (say onsuz
> da 0 idi, aşağı bax), `country`/`world`-də isə Ghost Mode
> istifadəçiləri saya daxil olurdu və say düzgün GÖRÜNDÜYÜ üçün bu,
> nəzərə çarpmırdı. BACKLOG #25 ilə bağlandı.

**Etiketlər:** Canlı tabda «N nəfər ətrafda (son 15 dəqiqə)», profildə
«Hazırda N PeakPin istifadəçisi buradadır». Fərqli mənbə, fərqli
ifadə.

## 1. Növbə / boş yer

Məkan sahibinin təyin etdiyi tutum. `availableSeats > 0` olan məkanlar
Canlı tabda `LiveFeedType.seatAvailable` kartı kimi görünür
(`seatAvailableItemsFrom`). Bu sənədin əhatəsindən kənardır —
buraya yalnız qarışıqlıq yoxlaması üçün daxil edilib.

Yenilənmə: `liveFeedVenueSnapshotPollInterval` = **30 saniyə**.

---

## 2. «Ətrafınızda» (audience)

**Nə göstərir:** sistemin hesabladığı, istifadəçinin heç bir hərəkəti
olmadan alınan say. Mənbə `venues/{id}.currentAudienceCount`,
onu yazan `computeVenueAudienceHistory` (15 dəqiqədə bir).

**Harada:** Canlı tab — kart (`live_feed_card.dart`,
`Icons.groups_rounded`) və yuxarı tiker (`live_feed_ticker.dart`).
**Toxunula bilmir** — informativdir, məkana keçid vermir.

> **KART 2026-08-31-Ə QƏDƏR HEÇ VAXT GÖSTƏRİLMƏYİB.** Bu sənədin
> əvvəlki versiyaları onu mövcud funksiya kimi təsvir edirdi; belə
> deyildi.
>
> `computeVenueAudienceHistory` namizədləri publik `users`
> sənədlərindən oxuyurdu, `lat`/`lng` isə Düzəliş Prompt 4 / K-1-də
> `private/data`-ya köçmüşdü. Nəticədə `distance` rejimində — həm
> picker-in, həm `submitVenue`-nin defolt rejimi — hər namizəd
> `lat === undefined` qapısına düşürdü və say **daim 0** idi. Client
> `currentAudienceCount > 0` süzgəci tətbiq etdiyi üçün kart sadəcə
> çəkilmirdi; pik-saat push-u da heç vaxt getmirdi.
>
> `country`/`world` rejimləri işləyirdi (onlar mövqe yox, sənəd sayır)
> — amma Ghost Mode süzgəci onlarda da no-op idi, yuxarı bax.
>
> BACKLOG #25 ilə bağlandı: namizədlər indi `private/data` ilə
> birləşdirilir. Eyni turda `audienceHistory` sorğusu da daraldıldı
> (məkan başına tick-də 672 → ~8 oxu) — funksiya həm işlək, həm
> əvvəlkindən ucuz oldu.
>
> **Buradakı ilk üç sətir yalnız düzəliş yayımlandıqdan sonra
> doğrudur.** Növbəti oxuyan üçün: bu sənəd davranışı təsvir edir,
> niyyəti yox — bir iddia kodla təsdiqlənə bilmirsə, silinməli və ya
> belə işarələnməlidir.

### İstifadəçilərə gedən gündəlik bildiriş — MÖVCUD DEYİL

Yoxlanıldı: belə bir mexanizm yoxdur. `notifyUser`-in 50 tipi arasında
məkan-doluluğu bildirişi yoxdur.

Ən yaxın olan `venuePeakHour`-dur, amma o **məkan sahibinə** gedir
(«Pik andır! 🔥 — indi təklif yerləşdirin»), istifadəçilərə yox. Ona
görə «istifadəçinin radius seçimi nəzərə alınırmı» sualı hazırda
predmetsizdir — göndəriləcək bildiriş yoxdur. Belə bildiriş
istənilirsə, bu, **yeni işdir** və radius şərti onun dizaynına daxil
edilməlidir.

---

## 3. Könüllü check-in

### Axın (fayl:sətir)

| Addım | Yer |
|---|---|
| İstifadəçi «Check-in et» basır | `venue_profile_screen` → `checkIn()` |
| Tranzaksiya | `firebase_venue_remote_datasource.dart:203` |
| Sənəd | `venues/{venueId}/activeCheckins/{uid}` — yalnız `createdAt` |
| Əvvəlki məkandan çıxarılma | eyni tranzaksiyada `tx.delete(_activeCheckins(oldVenueId).doc(uid))` |
| Cari məkan yaddaşı | `users/{uid}/private/data.activeCheckinVenueId` |
| Sayğac | `onActiveCheckinCreated` / `onActiveCheckinDeleted` → `bumpActiveCheckinCount` (`index.ts:2647`) |
| Əl ilə çıxış | `checkOut()` — sənədi silir, `activeCheckinVenueId`-ni `null` edir |
| Avtomatik çıxış | `cleanupStaleCheckins` — saatda bir, `CHECKIN_EXPIRY_MS = 2 saat` |

**Eyni anda iki məkanda check-in mümkün deyil** — tranzaksiya
`activeCheckinVenueId`-ni oxuyur və köhnə sənədi eyni yazıda silir.

### Sayğacın doğruluğu

* `bumpActiveCheckinCount` **tranzaksiyalıdır** və `Math.max(0, …)`
  işlədir — **mənfi ola bilməz**.
* `cleanupStaleCheckins` sənədi silir; sayğacı **birbaşa düzəltmir**,
  amma silmə `onActiveCheckinDeleted`-i işə salır və sayğac o yolla
  azalır. Yəni öz-özünə düzəlir.
* **Drift mümkündür:** trigger uğursuz olarsa (məsələn məkan sənədi
  həmin anda yoxdursa) `bumpActiveCheckinCount` səssizcə çıxır.
  Sayğacı faktiki sənəd sayı ilə tutuşduran periodik yoxlama **yoxdur**.
  Riski aşağıdır (növbəti stale-sweep dövrü çox vaxt bərabərləşdirir),
  amma zəmanət deyil.

### Banlanmış istifadəçi

* `create` — **bağlıdır** (`isActiveUser()`, 2026-08-31)
* `delete` — **qəsdən açıqdır**: ban zamanı içəridə olan adam məkanın
  canlı sayında ilişib qalmamalıdır

### Məxfilik

**Xam siyahını da, xam sayı da heç kim oxuya bilmir — məkan sahibi
daxil.** Siyahı: `activeCheckins` yalnız öz sənədi. Say:
`private/counters` tamamilə bağlı.
2026-08-31-də bağlandı:

```
allow read: if request.auth != null && request.auth.uid == userId;
```

Əvvəl sahib də oxuya bilirdi (Prompt 4 / K-4 onu «hər qeydiyyatlı
istifadəçi»dən «sahib + check-in edən»ə daraltmışdı). İndi yalnız
istifadəçinin özü. Say hər kəsə açıqdır — `venues/{id}
.activeCheckinCount`. Heç bir ekran xam siyahını oxumurdu, ona görə
bağlanma heç nəyi sındırmadı.

**Ghost Mode check-in-ə TƏSİR ETMİR.** Check-in axınında
`ghostModeEnabled` istinadı ümumiyyətlə yoxdur. Yəni nearby-də
gizlənən istifadəçi check-in edəndə məkanın sayına daxil olur.
Aqreqat olduğu üçün adı görünmür, **amma məkanda bir nəfər varsa
«1 nəfər burada» həmin adamı müəyyən edir** — və Ghost Mode-un
mövcudluğu istifadəçidə əks gözlənti yaradır. **Qərar tələb edir.**

**«1 nəfər» problemi — bağlandı.** Kiçik rəqəm müəyyənedicidir, ona
görə check-in sayğacına da `previewVenueAudience`-dəki eyni 5-lik
döşəmə tətbiq edildi. Fərq: burada döşəmə **yazma anında** tətbiq
olunur, çünki oxunan sənəd ictimaidir.

### Xərc

| Əməliyyat | Oxu | Yazı |
|---|---|---|
| Check-in | 1 (`private/data`) | 2 (check-in sənədi + `activeCheckinVenueId`) + 1 trigger yazısı |
| Check-out | 1 | 2 + 1 trigger yazısı |
| Profildə say | 1 dinləyici (`venues/{id}` snapshot) | — |
| Canlı tab | **0 əlavə** — `fetchVenueSnapshots`-dan pulsuz gəlir | — |

**Rate limit yoxdur** — check-in/check-out client-in birbaşa Firestore
yazısıdır, callable deyil. Nəzəri olaraq bir istifadəçi cəld
check-in/check-out edərək sayğac triggerlərini işə sala bilər; hər
dövr 2 yazı + 1 trigger yazısıdır.

**200 nəfərlik məkan:** sayğac tək sahədir, ona görə oxu tərəfi
ucuzdur (1 sənəd). Yazı tərəfi `bumpActiveCheckinCount`-un **eyni
sənədə** tranzaksiyalı yazısıdır — Firestore-un tək sənəd üçün
təxminən **1 yazı/saniyə** həddi var. 200 nəfər eyni anda check-in
etsə (konsert, açılış) tranzaksiyalar bir-birini gözləyəcək və bəziləri
uğursuz ola bilər. Bu, real hədddir və sənədləşdirilməyə dəyər.

---

## Növbə girişindəki telefon nömrəsi — kim oxuyur

Növbəyə yazılan istifadəçi telefon nömrəsini verir; məkan sahibi onu
çağıra bilsin deyə. Giriş sənədi:
`venues/{venueId}/waitlist/{entryId}` — `userId`, `phoneNumber`,
`partySize`, `note`, `status`, `joinedAt`, `queuePosition`.

**Oxu qaydası:**

```
allow read: if request.auth != null &&
  (resource.data.userId == request.auth.uid || isVenueOwner());
```

**Emulator testi ilə təsdiqlənib** (`firestore-waitlist-privacy.test.ts`):

| Kim | Öz girişi | Başqasının girişi | Bütün siyahı |
|---|---|---|---|
| Növbədəki istifadəçi | ✅ | **❌** | **❌** |
| Məkan sahibi | ✅ | ✅ | ✅ |
| Kənar istifadəçi | — | ❌ | ❌ |

**Yəni növbədə duran biri digərinin nömrəsini görə bilmir** — nə
birbaşa sənədi oxumaqla, nə siyahılamaqla, nə də başqasının uid-i ilə
süzülmüş sorğu ilə. Firestore `list` sorğusunu sənəd-sənəd yox, bütöv
sorğu üzrə qiymətləndirir: `isVenueOwner()` `resource`-a bağlı
olmadığı üçün sahib üçün bütün sorğuya şamil olunur, digərləri isə
yalnız `where('userId', '==', öz uid)` ilə məhdudlaşdırılmış sorğu işlədə
bilər.

Client tərəfi də buna uyğundur: istifadəçi öz növbə yerini
`watchMyEntry` (`queuePosition` öz sənədində) ilə görür, tam siyahını
oxuyan yeganə ekran `VenueWaitlistScreen`-dir və o, sahibə aiddir
(`venueWaitingListProvider` — «Owner-only "Növbə" list»).

**Client birbaşa yaza da bilmir** — `allow create: if false`, giriş
yalnız `joinWaitlist` callable-ından keçir (telefon normalizasiyası,
təkrar-giriş yoxlaması və rate limit orada tətbiq olunur).

**Qalan məlumat axını:** nömrə **məkan sahibinə** çatır. Bu, funksiyanın
öz tələbidir — sahib müştərini çağırmalıdır — amma istifadəçiyə açıq
deyilməlidir. Növbəyə yazılma ekranında bunun bildirilməsi məhsul
qərarıdır; kod səviyyəsində əlavə qoruma tələb olunmur.

---

## PinBox `stockTotal` — qəsdən ictimai

`pinboxes/{id}` hər qeydiyyatlı istifadəçiyə oxunaqlıdır və həm
`stockRemaining`, həm `stockTotal` orada saxlanılır, yəni satılan sayı
(`stockTotal − stockRemaining`) hesablana bilir.

**Qərar (2026-08-31): belə qalır.** İstifadəçi «neçə qutu qalıb»
görməlidir — bu, alış qərarının bir hissəsidir. Rəqib də görür, amma
həmin məlumat onsuz da tətbiqə girməklə əlçatandır. Məxfilik məsələsi
deyil: fərdi alıcılar (`pinboxOrders` — yalnız alıcı) və sahibin gəlir
qeydləri (`venuePayouts` — server-only) ayrıca qorunur.
