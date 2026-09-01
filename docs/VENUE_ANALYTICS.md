# Məkan analitikası — məlumat qatı

**Status:** yığım qatı qurulub (2026-09-01). **Ekran və bildiriş yoxdur** — launch-dan sonra.

## Niyə yığım əvvəl gəlir

`audienceHistory` 7 gün saxlanılır. Aylıq hesabat launch-dan sonra qurulsa,
**ilk ay boş çıxar** və yığım başlamazdan əvvəlki hər ay həmişəlik boş qalar.
Bu, analitika işinin sonraya qoyula bilməyən yeganə hissəsidir.

---

## Qurulmuş: `rollUpVenueDailyStats`

Hər gecə **00:30 UTC**, bitmiş gün üçün. `venues/{venueId}/dailyStats/{YYYY-MM-DD}`.

### UTC, məkanın yerli vaxtı yox

Azərbaycan UTC+4-dür, yəni «gün» yerli saat 04:00-da bitir — restoranın gec
axşamı əvvəlki UTC gününə düşür və pik saat UTC ilə yazılır.

Aydan-aya müqayisə üçün bu zərərsizdir: hər gün eyni cür sürüşür və müqayisə
məkanın **öz tarixçəsi** ilə aparılır. Yalnız hesabat sahibə **mütləq saat**
desə əhəmiyyət kəsb edir — o zaman `audiencePeakHour` göstərişdə +4 edilməlidir.

### İdempotentlik

Sənəd ID-si tarixdir və yazı tam `set`-dir. Eyni gün üçün ikinci icra üzərinə
yazır, dublikat yaranmır.

### Xəta izolyasiyası

Hər məkan ayrıca `try/catch`-dədir. Bir məkanın sınması loglanır və növbətiyə
keçilir — əks halda bir istisna gecənin qalan bütün məkanlarını **həmişəlik**
itirərdi.

---

## Xərc

`audienceHistory` 15 dəqiqədə bir yazılır → **gündə 96 sənəd/məkan**. Yığım
onları oxusaydı, bu, xərcin ~80%-i olardı.

Ona görə `computeVenueAudienceHistory` (onsuz da hər 15 dəqiqədə
`private/counters`-ə yazır) günün aqreqatını orada saxlayır:

```
private/counters.audienceToday = { date, sum, samples, peak, peakHour }
private/counters.audiencePrev  = { … }   ← tarix dəyişəndə köçürülür
```

**İki slot, tarix açarlı map yox.** Map hər gün bir açar artırır və onu
təmizləyən iş məhz unudulan iş növüdür. İki slot sənədi quruluşca bağlayır.

Yığım `audiencePrev`-i oxuyur. Tapmasa (deploy-dan sonrakı ilk gecə, və ya
audience cədvəli dayanıbsa) `audienceHistory`-yə düşür — **doğruluq birinci,
xərc ikinci**.

```
oxu/gecə ≈ V × (2 + 6 sorğu + O + D)
             O = məkanın canlı təklif sayı (redemption sorğusu)
             D = günün digər sənədləri

V=2:      ~20             (bugün)
V=1000:   ~10 000/gecə    ≈ 0.3M/ay   ≈ $0.09/ay
V=10000:  ~100 000/gecə   ≈ 3M/ay     ≈ $0.90/ay
```

Sayğac olmasaydı V=10000-də ~37M/ay olardı — **96× fərq**.

### Hədd — BACKLOG #23 naxışı

**V > 5000-də** tək icra 9 dəqiqəlik limitə yaxınlaşır. Səhifələmə (200-lük)
yaddaşı qoruyur, vaxtı yox. Həll: `venues`-i Pub/Sub ilə fan-out etmək —
hər mesaj bir səhifə. **İndi qurulmayıb**, çünki bugün 2 məkan var.

---

## Check-in — niyə ayrıca sayğac lazım idi

`activeCheckins` **efemerdir**: çıxışda silinir, başqa məkana keçəndə silinir,
`cleanupStaleCheckins` 2 saatdan sonra silir. Gecə işləyən funksiya yalnız
**gecə yarısı hələ aktiv olanları** görər — bu, günün check-in sayı deyil,
və tarixçə bərpa oluna bilməz.

`onActiveCheckinCreated` onsuz da tranzaksiya işlədir, ona görə sayğac
**pulsuzdur**:

```
private/counters.checkinsByDay["2026-09-01"] += 1
```

Yalnız artımlar sayılır (`delta === 1`) — çıxış ziyarəti geri almır. Açarlar
yığım tərəfindən təmizlənir.

---

## Məxfilik

**1. Fərdi məlumat yoxdur.** `DAILY_STATS_FIELDS` (`functions/src/daily-stats.ts`)
icazə verilən sahələrin siyahısıdır; `daily-stats.test.ts` hər sahə adını
qadağan naxışlara (`uid`, `email`, `lat`, `name`, …) qarşı yoxlayır. TypeScript
altı ay sonra əlavə ediləcək `uid` sahəsini dayandırmaz — test dayandırır.

**2. k-anonimlik: `null`, `0` yox.** Mövcud `VENUE_AUDIENCE_MIN_REPORTABLE_COUNT`
(5) istifadə olunur, yeni hədd icad edilməyib. Həddən aşağı → `null`.

Fərq mahiyyətdir: «5-dən az adam var idi» ilə «heç kim yox idi» fərqli
faktlardır. Üstəlik bir ay sıfırların içindəki tək bir `7` gizlədilən dəyərləri
açardı.

**Pik gizlədilirsə pik SAAT da gizlədilir** — sayı gizlədib «ən sıx saat 21:00
idi» demək, həmin saatda konkret adamın orada olduğunu yenə açır.

**Orta xam nümunələrdən hesablanır**, sonra bütövlükdə gizlədilir. Hər nümunəni
ayrıca gizlətsək orta yuxarı sürüşərdi.

**`audienceSamples` gizlədilmir** — o, insanları yox, ölçmənin özünü təsvir edir;
«sakit gün» ilə «cədvəl işləməyib» fərqlənməlidir.

**Pul göstəriciləri gizlədilmir** — PinBox gəliri məkanın öz gəliridir.

**3. Xam check-in siyahısı heç yerdə saxlanılmır** — yalnız say.

**4. ⚠️ Ghost Mode istifadəçiləri audience hesabına DAXİL EDİLMİR.**
`computeVenueAudienceHistory` onları `if (user.ghostModeEnabled) continue` ilə
atır, yəni `audienceHistory` onları heç vaxt saymayıb və `dailyStats` də
saymayacaq.

**Nəticə: sahibə göstərilən say faktiki mövcud adamdan AZ ola bilər.** Sahib
«10 nəfər var» görüb faktiki 14 olduğunu bilmir. Bu, məxfilik lehinə səhvdir və
qərar bilərəkdən belədir (məhsul sahibi, 2026-09-01) — amma hesabat ekranı
qurulanda mətndə «təxmini» ifadəsi istifadə edilməlidir, «dəqiq» yox.

---

## Saxlama: 400 gün

TTL, `expiresAt` üzərində — `notificationIntents`/`birthdayFeed` naxışı.

90 gün deyil, çünki aylıq hesabatın ən dəyərli sətri **«keçən ilin eyni ayı»**
müqayisəsidir; qonaqpərvərlikdə mövsümilik əsas siqnaldır. 400 gün tam il +
hesabatı yaratmaq üçün ehtiyat verir.

10 000 məkan × 400 gün ≈ 4M kiçik sənəd ≈ **$1/ay saxlama**.

---

## QURULMAYIB — aylıq yığım dizaynı

`venues/{venueId}/monthlyReports/{YYYY-MM}`, ayın 1-i, əvvəlki ay üçün.

**Sahə adları gündəlik sxemlə eynidir**, prefikssiz: `audienceAvg` gündəlikdə
«həmin günün ortası», aylıqda «ayın ortası». Hesabat ekranı iki fərqli sxem
bilməməlidir.

**Müqayisə:** `prevMonth: { audienceAvg, checkins, … }` + `deltaPercent`.
Əvvəlki ay yoxdursa **`null`, sıfır yox** — «ilk ay» ilə «heç nə olmayıb»
fərqlidir, gündəlik sənəddəki eyni qayda.

**Kateqoriya ortalaması** — ən dəyərli müqayisə.
`analytics/categoryBenchmarks/{YYYY-MM}/{category}`:

- **Median, orta yox** — bir nəhəng məkan ortanı sürüşdürür
- **Kateqoriyada 5-dən az məkan varsa yazılmır**: 2 məkan olanda «kateqoriya
  ortası» faktiki olaraq rəqibin öz rəqəmidir

**Xərc:** ayda bir, məkan başına 28-31 oxu — cüzi.

---

## QURULMAYIB — çatdırılma modeli

1. **Tətbiqdə «Məkanlarım → Hesabatlar» ekranı**, keçmiş aylar saxlanılır
2. **Ayın son günü push**, rəqəmlə: «Avqust hesabatınız hazırdır — 142 baxış, +23%»
   — quru «hesabatınız hazırdır» açılmır, rəqəm açır
3. **Bildiriş kateqoriyası: `venueUpdates`** — söndürülə bilən. Bu, sahibə
   faydalı təklifdir, öhdəlik deyil; `account` olsaydı söndürülə bilməzdi
4. **E-poçt sonraya**

Ekran qurulanda `dailyStats`/`monthlyReports` üçün **oxu icazəsi ayrıca qərar
verilməlidir** — hazırda hər ikisi `allow read, write: if false`.

---

## QURULMAYIB — ölçülməyən göstəricilər

| Göstərici | Harada artırılar | Xərc | Tövsiyə |
|---|---|---|---|
| Yol/zəng/sayt klikləri | Düymənin `onTap` | 🟢 az | **Birbaşa yazı** — qəsdən edilən əməldir, gündə onlarla |
| Profil açılışı | `VenueProfileScreen` | 🔴 hər açılışda 1 yazı | **Batch** — client 20 hadisəni yığıb bir callable ilə göndərir, 50× azalma. Risk: tətbiq öldürülsə son partiya itir (analitika üçün qəbul ediləndir) |
| Kəşf-də göstəriş | Discover render | 🔴🔴 hər sorğuda 10-30 yazı | **Firestore-a YAZMA.** Firebase Analytics hadisəsi (`venue_impression`) — ən böyük həcm, ən az dəyər. Firestore sayğacı hesabatın gətirdiyi gəlirdən baha olar |

⚠️ Analytics seçilsə **məxfilik siyasəti §2.6 yenilənməlidir** — hazırda ümumi
«istifadə statistikası» var, məkan səviyyəsində göstəriş sayımı qeyd edilməyib.
docs/BACKLOG.md-yə yazıldı.
