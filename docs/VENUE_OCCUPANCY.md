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

**Nəzərdə tutulan:** sistemin hesabladığı, istifadəçinin heç bir
hərəkəti olmadan alınan say.

**Faktiki:** check-in sayğacı (yuxarıdakı qarışıqlıq).

**Harada:** Canlı tab — kart (`live_feed_card.dart`,
`Icons.groups_rounded`) və yuxarı tiker (`live_feed_ticker.dart`).
**Toxunula bilmir** — informativdir, məkana keçid vermir.

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
