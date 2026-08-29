# Düzəliş Prompt 6 — Real ödəniş testi təlimatı (2 AZN boost, öz kartınızla)

Bu sənəd YALNIZ AAB build-dən sonra, deploy edildikdən sonra, öz real kartınızla
test edərkən istifadə üçündür. Kod indi YALNIZ yazılıb — deploy edilməyib.

## 0. Ön şərt: deploy

Bu prompt heç nəyi deploy etməyib (qayda belə idi). Testə başlamazdan əvvəl:

1. `firestore.rules` deploy olunmalıdır (offers/pinboxes məzmun kilidi + əvvəlki
   promptların qaydaları ilə BİRLİKDƏ — siz bütün promptların rules-larını
   sona saxlamağı seçmişdiniz, unutmayın ki bu da o partiyaya daxildir).
2. `functions/` deploy olunmalıdır — xüsusilə bu prompt YENİ və ya
   DƏYİŞDİRİLMİŞ funksiyalar yaratdı: `applyPaymentOutcome` (daxili, export
   olunmur, amma `epointWebhook`/`payWithSavedCard` onu çağırır),
   `epointWebhook`, `processPaymentRefund`, `renewVenueSubscriptions`,
   `createBoostCheckout`, `createVenuePremiumCheckout`,
   `ensurePendingSubscriptionPayment`-dən istifadə edən 3 funksiya,
   `payWithSavedCard`, YENİ `updateOffer`/`updatePinBox`.
3. Admin panel (Vercel və ya harada host olunursa) yenidən deploy olunmalıdır
   — `payments.ts`/`pinbox-payouts.ts`/`initiateRefund` üçün.

## 1. Test ssenarisi A — normal uğurlu ödəniş (2 AZN boost)

**Addımlar:**
1. Tətbiqdə bir təklifi (offer) seçin, "Təklifi önə çək" (boost) düyməsini basın, 6 saatlıq (ən ucuz, ~2 AZN) seçimi seçin.
2. Epoint checkout səhifəsi açılanda öz real kartınızla ödəyin.
3. Ödəniş uğurla bitdikdən sonra tətbiqə qayıdın.

**Yoxlanmalı olan yerlər:**

- **Firebase Console → Functions → Logs** (və ya `firebase functions:log`):
  - `epointWebhook: decoded payload` log sətrini tapın — bu, PAY-4-ün açıq
    sualını (Epoint webhook-u həqiqətən `amount`/`currency` göndərirmi?)
    HƏLL EDƏCƏK. `decoded` obyektinin TAM məzmununu qeyd edin (screenshot və ya
    kopyalayın) — bunu mənə göstərin, mən ona görə PAY-4-ün yoxlamasını ya
    aktivləşdirəcəyəm, ya təsdiqləyəcəyəm ki, artıq düzgün işləyir.
  - Bu logdan sonra `amountMismatch`/`amount_mismatch` sözü GÖRÜNMƏMƏLİDİR
    (əgər görünürsə, deməli real webhook-un məbləği gözlədiyimizdən fərqlidir
    — mənə dərhal bildirin, bu, PAY-4-ün YENİDƏN nəzərdən keçirilməsini tələb
    edəcək).
  - Xəta/`error` səviyyəli log olmamalıdır bu axın üçün.

- **Firestore Console → `payments` kolleksiyası**:
  - Bu ödənişin sənədini tapın (`type: "boost_fee"`).
  - `status` → `"completed"` olmalıdır.
  - `epointTransaction` sahəsi dolu olmalıdır (Epoint-in öz əməliyyat ID-si).
  - `honoredAfterSupersede` sahəsi YOXDUR və ya `false`-dur (normal axında bu
    bayraq heç görünməməlidir — yalnız köhnəlmiş linkdən gec ödəniş halında
    görünür, aşağı bax Ssenari C).

- **Firestore Console → `offers/{offerId}`**:
  - `boostedUntil` indiki vaxtdan ~6 saat sonrakı bir `Timestamp` olmalıdır.

- **Admin panel → Ödənişlər səhifəsi**:
  - Bu ödəniş `completed` statusu ilə görünməlidir, məbləğ düzgün.

## 2. Test ssenarisi B — uğursuz/rədd edilmiş ödəniş

**Addımlar:**
1. Yenidən boost checkout açın.
2. Epoint səhifəsində ödənişi QƏSDƏN uğursuz edin (məs. kartı ləğv edin,
   yanlış CVV daxil edin 3 dəfə, və ya sadəcə səhifəni bağlayın/geri qayıdın).

**Yoxlanmalı olan yerlər:**

- `payments/{paymentId}.status` → `"failed"` olmalıdır.
- `offers/{offerId}.boostedUntil` DƏYİŞMƏMƏLİDİR (heç bir pulsuz boost
  verilməməlidir).
- Tətbiqdə "Ödəniş uğursuz oldu" mesajı görünməlidir, ikinci cəhd üçün yenidən
  boost checkout açıla bilməlidir (yeni `payments` sənədi yaranacaq, köhnəsi
  `failed` olaraq qalacaq).

## 3. Test ssenarisi C — köhnəlmiş link + gec ödəniş (K-10, ehtiyat plan)

Bu ssenarini yalnız VAXT VARSA sınayın — məcburi deyil, amma K-10-un əsl
düzəlişini canlıda görmək üçün ən yaxşı yoldur:

1. Boost checkout açın, Epoint linkini açın AMMA ÖDƏMƏYİN (browser-i açıq
   saxlayın və ya linki kopyalayıb saxlayın).
2. Tətbiqə qayıdın, EYNİ təklif üçün YENİDƏN boost checkout açın (bu, birinci
   sənədi `superseded`-ə keçirəcək, `createBoostCheckout`-un yeni
   `supersedeOtherPendingPayments` məntiqi ilə).
3. İkinci linki bağlayın, BİRİNCİ (köhnəlmiş) linkə qayıdıb ONUNLA ödəyin.

**Gözlənilən nəticə:**
- Birinci `payments` sənədi: əvvəlcə `status: "superseded"` idi, indi
  `status: "completed"` OLMALIDIR — GEC ödəniş rədd edilməməli, xidmət
  verilməlidir.
- `honoredAfterSupersede: true` bu sənlə üzərində görünməlidir.
- Firebase Functions loglarında `applyPaymentOutcome: honoring late success
  on a superseded payment` xəbərdarlıq (warn) səviyyəli log görünməlidir.
- Admin bildirişi (`adminNotifications` kolleksiyası və ya admin panelin Bell
  düyməsi) `payment.honored_after_supersede` tipli bir qeyd görünməlidir.
- `offers/{offerId}.boostedUntil` UZANMALIDIR (əlavə 6 saat) — çünki bu, real
  İKİNCİ ödənişdir (iki ayrı Epoint əməliyyatı = iki real pul tutulması).

## 4. Test ssenarisi D — saxlanmış kartla ödəniş (PAY-18)

Əgər "Kartlarım" funksiyası artıq deploy/aktiv olubsa:

1. Əvvəlcə bir kartı qeydiyyatdan keçirin (`startCardRegistration`).
2. Saxlanmış kartla bir boost ödəyin (`payWithSavedCard`).

**Yoxlanmalı olan:** eyni Ssenari A yoxlamaları — bu axın sinxron olduğu üçün
(`chargeEpointSavedCard` → `applyPaymentOutcome` eyni funksiya çağırışında),
webhook gözləməyə ehtiyac yoxdur, nəticə dərhal `payments` sənədində
görünməlidir.

## 5. Nəticələri necə bildirin

Ən vacib məlumat — **`epointWebhook: decoded payload` logunun tam məzmunu**
(Ssenari A-dan). Bunu mənə göndərin (screenshot və ya mətn) — bunun üzərindən
PAY-4-ün amount/currency yoxlamasının real production-da işə düşüb-düşmədiyini
birbaşa təsdiqləyə biləcəyəm.
