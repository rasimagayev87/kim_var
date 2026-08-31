# 2 AZN boost — real ödəniş test təlimatı

**Əvəz edir:** `docs/prompt6-real-payment-test-guide.md` (2026-08-29). O
sənəd hələ deploy edilməmiş koda görə yazılmışdı; o vaxtdan `payments`
sxemi, webhook, admin panel və rollar dəyişdi.

**Niyə bu test:** Epoint əməliyyat logunda **bir dənə də uğurlu ödəniş
yoxdur** — hamısı ya «linkin müddəti bitib», ya «vəsait yoxdur». Yəni
`webhook → completed → entitlement` yolu production-da heç vaxt
işləməyib. 2 AZN ən ucuz yoldur.

**Vəziyyət:** kod deploy edilib (`646a033`). Ödənişi siz edirsiniz.

---

## 0. Ön şərtlər

- [ ] Təsdiqlənmiş (`status: approved`) bir təklifiniz olmalıdır — boost
      yalnız mövcud təklifə tətbiq olunur. Yoxdursa əvvəlcə təklif
      yaradın və admin paneldən təsdiqləyin.
- [ ] Cihazda **1.0.1 (12)** build.
- [ ] Kartda ən azı 2 AZN. Əvvəlki testlər «kifayət qədər vəsait yoxdur»
      ilə dayanıb — bu dəfə əsas uğursuzluq səbəbi olmasın.
- [ ] Admin panelə `admin` və ya `finance` rolu ilə girişiniz açıq olsun
      (`/payments` `viewPayments` tələb edir; moderator **görmür**).

**Terminalı hazır saxlayın** — webhook 1-2 saniyə ərzində gəlir:

```bash
firebase functions:log --only epointWebhook -n 40
```

---

## 1. Checkout-un yaradılması

Tətbiqdə: **Təkliflərim → təklif → «Önə çək» → 6 saat (2 AZN) → ödə.**

**Dərhal yoxlayın — Firestore `payments`** (yeni sənəd yaranmalıdır):

| Sahə | Gözlənilən |
|---|---|
| `type` | `boost_fee` |
| `listingType` | `offer` |
| `listingId` | təklifin id-si |
| `boostHours` | `6` |
| `amount` | `2` |
| `currency` | `AZN` |
| `status` | **`pending`** |
| `description` | `Təklifi önə çək — 6 saat` |
| `ownerId` | sizin uid |
| `createdAt` / `updatedAt` | indiki vaxt |

**Sənədin id-si = Epoint-in `order_id`-idir.** Yazın — bütün sonrakı
addımlarda ona baxacağıq.

⚠️ `checkoutStartedAt` bu mərhələdə **olmaya bilər** — o, yalnız
abunə axınında (`ensurePendingSubscriptionPayment`) yazılır.

---

## 2. Ödəniş

Epoint səhifəsində kartla ödəyin.

⏱️ **Link müddəti var.** İndiyə qədərki bütün testlər burada dayanıb —
səhifəni açıq saxlayıb sonra qayıtmayın, dərhal ödəyin.

---

## 3. Cloud Functions logu — sıra ilə görməli olduqlarınız

```bash
firebase functions:log --only epointWebhook -n 40
```

**(a) Webhook gəldi və imza doğrulandı.** Bu sətri görməlisiniz:

```
epointWebhook: decoded payload { decoded: { order_id: '…', status: 'success', … } }
```

Bu sətir **imza doğrulamasından SONRA** yazılır. Görürsünüzsə, imza
keçib. Görmürsünüzsə → 6-cı bölmə.

**(b) `applyPaymentOutcome` uğursuzluq sətirlərinin heç biri
OLMAMALIDIR:**

| Sətir | Mənası |
|---|---|
| `applyPaymentOutcome: unknown payment` | `order_id` üçün sənəd yoxdur |
| `applyPaymentOutcome: paid-for listing is gone` | **yeni** — təklif silinib, ödəniş `orphan_target` oldu |
| `Ödəniş məbləği uyğunsuzluğu` | PAY-4 tetiklənib — aşağıya bax |

**(c) Uğurlu halda əlavə sətir yoxdur.** `applyPaymentOutcome` uğurda
səssizdir — təsdiq Firestore-dadır, logda yox. Yəni «log boşdur»
narahat olmayın; (a) sətri + 4-cü bölmə kifayətdir.

---

## 4. Firestore — gözlənilən son vəziyyət

### `payments/{orderId}`

| Sahə | Gözlənilən | Qeyd |
|---|---|---|
| `status` | **`completed`** | `pending` qalıbsa webhook gəlməyib |
| `epointTransaction` | **dolu olmalıdır** | Epoint-in öz tranzaksiya id-si. **Geri qaytarma yalnız bununla mümkündür** — boşdursa 6-cı bölmə |
| `amount` | `2` | dəyişməməlidir |
| `updatedAt` | webhook vaxtı | `createdAt`-dan sonra |
| `failureCode` / `failureMessage` | **olmamalıdır** | |

### `offers/{offerId}`

| Sahə | Gözlənilən |
|---|---|
| `boostedUntil` | **webhook vaxtı + 6 saat** |
| `updatedAt` | webhook vaxtı |

**Hesablamanı yoxlayın:** `boostedUntil` = `applyPaymentOutcome`-un
işlədiyi an + `boostHours × 60 × 60 × 1000` ms. Yəni ödəniş
12:00-da tamamlanıbsa, `boostedUntil` ≈ **18:00** olmalıdır.

⚠️ **Mövcud boost üzərinə yığılmır** — abunə/premium yenilənməsindən
fərqli olaraq boost `Date.now() + hours`-a **təyin edilir**, uzadılmır.
Aktiv boost üzərinə ikinci boost alsanız qalan vaxt itir. Bu, qəsdəndir,
amma test edərkən bilin.

### Tətbiqdə
Təklif kəşf siyahısında öndə görünməlidir və 6 saatdan sonra öz yerinə
qayıtmalıdır.

---

## 5. Admin panel

`admin.peakpin.app/payments` (rol: **admin** və ya **finance**;
moderator bu səhifəni görmür — P0 / H-7).

| Sütun | Gözlənilən |
|---|---|
| Sahib | sizin adınız |
| Elan | təklifin adı |
| Növ | **«Təklifi önə çəkmə»** |
| Məbləğ | **2 AZN** |
| Status | **«Ödənilib»** (yaşıl) |

Sonra `/dashboard` → **bugünkü gəlir 2 AZN artmalıdır** (yalnız
`viewRevenue` olan rollarda: admin, finance, analyst).

Və `/analytics` → «Gəlir» bloku (aqreqat `sum()`) — orada da
görünməlidir.

---

## 6. PAY-4 — hələ açıq sual, **məhz bu test cavab verəcək**

`applyPaymentOutcome` webhook-un bildirdiyi məbləği gözlənilənlə
tutuşdurur — **əgər Epoint onu göndərirsə**. Göndərib-göndərmədiyi
təsdiqlənməyib, ona görə yoxlama `webhookAmount === undefined` olduqda
özünü tamamilə söndürür. Yəni hazırda bu qoruma **ya işləyir, ya da
sükutla yoxdur** və hansı olduğunu bilmirik.

**Cavabı burada tapacaqsınız** — 3(a)-dakı log sətrinə baxın:

```
epointWebhook: decoded payload { decoded: { … } }
```

`decoded` obyektində **`amount` və `currency` açarları varmı?**

| Nəticə | Mənası | Nə etməli |
|---|---|---|
| Hər ikisi **var** | PAY-4 qorumasi **canlıdır və işləyir** | Mənə deyin — `ACCEPTED_RISKS`-dən çıxarıb sənədləşdirəcəyəm |
| **Yoxdur** | Qoruma heç vaxt işləmir — məbləğ manipulyasiyası yoxlanılmır | Mənə deyin — alternativ lazımdır (məsələn Epoint-in status-sorğu API-si ilə məbləği ayrıca təsdiqləmək) |

**Bu, testin ən dəyərli hissəsidir.** Ödəniş uğurlu olsa da olmasa da,
həmin log sətri cavabı verir — sadəcə `decoded`-in tam məzmununu mənə
göndərin.

---

## 7. Uğursuz hallar — nə etməli

### «Linkin müddəti bitib»
Ən çox rast gəlinən hal. Firestore-da ödəniş `pending` qalır, webhook
gəlmir. **Epoint açıq checkout-u ləğv etmək API-si təklif etmir**
(`ACCEPTED_RISKS`), ona görə sənəd `pending` qalacaq. Yenidən sınayın —
yeni checkout yeni `payments` sənədi yaradır.

### «İmtina, kifayət qədər vəsait yoxdur»
Webhook **gəlir**, `status: "failed"`, `failureCode`/`failureMessage`
dolur, `boostedUntil` **dəyişmir**. Bu, **düzgün davranışdır** — uğursuz
hal da test sayılır. Log-da `decoded` sətrini yenə oxuyun (PAY-4 sualı
üçün uğursuz webhook da işə yarayır).

### `status` `pending` qalıb, webhook logu boşdur
Epoint webhook URL-i qeydiyyatdan keçməyib və ya səhvdir. Doğru URL:
```
https://epointwebhook-ezhsohlpta-uc.a.run.app
```
Epoint panelində yoxlayın.

### `status: orphan_target` göründü
Ödəniş gəldi, amma **təklif artıq mövcud deyil**. Admin paneldə
«Sahibsiz ödəniş» kimi qırmızı görünür, `adminNotifications`-a
xəbərdarlıq düşür. Pul alınıb, heç nə verilməyib →
**`epointTransaction` ilə əl ilə geri qaytarılmalıdır.**

### `Ödəniş məbləği uyğunsuzluğu` sətri
Webhook fərqli məbləğ bildirib. Entitlement **verilmir**, admin
bildirişi yazılır. Bu, PAY-4 qorumasının işlədiyi deməkdir — mənə
deyin, çünki bu, həm də (a) variantının təsdiqidir.

### Pul çıxdı, amma `status` `completed` deyil
**Dayanın, təkrar sınamayın.** Mənə deyin:
`order_id`, Epoint tranzaksiya id-si, və `firebase functions:log
--only epointWebhook -n 60` çıxışı. `processPaymentRefund` ilə geri
qaytarma yolu var, amma əvvəlcə səbəbi görməliyik.

---

## 8. Testdən sonra

Bu, **real 2 AZN**-dir və geri qaytarılmır (boost həqiqətən verilir).
Testdən sonra:

- [ ] `boostedUntil` 6 saatdan sonra öz-özünə keçir — silmək lazım deyil
- [ ] `payments` sənədini **silməyin** — `completed` ödəniş audit izidir
      və `onOfferDeleted` onu qəsdən toxunmadan buraxır
- [ ] Nəticəni (xüsusən 6-cı bölmənin cavabını) mənə bildirin
