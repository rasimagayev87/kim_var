# Məkanda insan sayı — üç ayrı anlayış

Bu sənəd bir səbəbə görə var: layihədə məkanla bağlı **üç fərqli say**
mövcuddur, adları bir-birinə oxşayır və **ikisi kodda bir sahəni
paylaşır**. Hansının harada göründüyü aşağıda dəqiq yazılıb.

| | Kim yaradır | Nə göstərir | Harada görünür | Faktiki mənbə |
|---|---|---|---|---|
| **1. Növbə / boş yer** | Məkan sahibi | Neçə boş yer qalıb | Canlı tab **və** məkan profili | `venues/{id}.availableSeats` |
| **2. «Ətrafınızda» (audience)** | Sistem | Yaxınlıqda neçə nəfər var | Canlı tab (kart + tiker), toxunulmaz | ⚠️ `venues/{id}.activeCheckinCount` — **aşağıya bax** |
| **3. Könüllü check-in** | İstifadəçi özü | Məkanda neçə nəfər var | **Yalnız** məkan profili | `venues/{id}.activeCheckinCount` |

---

## ⚠️ Bilinən qarışıqlıq: 2 və 3 eyni sahədən qidalanır

**Bu, aşkar edilmiş qüsurdur, dizayn deyil.** Qərar gözləyir; heç nə
dəyişdirilməyib.

`LiveFeedService.fetchAudienceItems` — Canlı tabındakı «Ətrafınızda»
sətrini quran funksiya — belə oxuyur:

```dart
.where((venue) => venue.activeCheckinCount > 0)
subtitle: '${venue.activeCheckinCount} nəfər burada',
```

`activeCheckinCount` isə **könüllü check-in sayğacıdır**:
`activeCheckins/{uid}` sənədi yarananda/silinəndə
`bumpActiveCheckinCount` onu ±1 dəyişir.

Yəni **Canlı tabda «Ətrafınızda» adı altında göstərilən rəqəm faktiki
olaraq check-in sayıdır** — sistemin hesabladığı audience deyil.

**Sistem audience-i mövcuddur və tamam başqa şeydir:**
`computeVenueAudienceHistory` hər 15 dəqiqədə `users` kolleksiyasını
`lastSeen`/`online` və mövqeyə görə sayır, nəticəni
`venues/{id}/audienceHistory` altına yazır. Heç bir check-in iştirak
etmir. Bu dəyər **Canlı tabda istifadə olunmur** — yalnız sahibin
analitikası və pik-saat siqnalı üçündür.

**Nəticə:** iki məhsul funksiyası bir sahəni paylaşır. Praktik təsiri:
* Canlı tab yalnız **düymə basmış** adamları sayır — məkanda olub
  check-in etməyən heç kim görünmür
* Check-in edən adam **yalnız məkan profilində görünəcəyini** gözləyir,
  amma rəqəmi radiusdakı hər kəs Canlı tabda görür

**Səhv şərh də düzəldildi:** `firestore.rules`-da check-in-in
`audienceHistory`-ni qidalandırdığı yazılmışdı. Yanlışdır — həmin
şərhin özü bu qarışıqlığın nümunəsi idi.

---

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

**Xam siyahını heç kim oxuya bilmir — məkan sahibi də daxil.**
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

**«1 nəfər» problemi:** aqreqat olsa da, kiçik rəqəm müəyyənedicidir.
`previewVenueAudience`-də bu, 5-lik k-anonimlik döşəməsi ilə həll
edilib (P0 / H-2); check-in sayğacında **belə döşəmə yoxdur**.

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
