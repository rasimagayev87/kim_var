# Düzəliş Prompt 7 — VIP IAP manual doğrulama addımları

Bu sənəd YALNIZ deploy edildikdən sonra istifadə üçündür (Google Play tərəfi
üçün). Kod indi YALNIZ yazılıb — deploy edilməyib, real satınalma edilməyib.

## 0. Ön şərt

1. `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` secret-i real dəyərlə qoyulmalıdır
   (bax əsas hesabatın 3-cü bəndi).
2. RTDN Pub/Sub topic-i yaradılmalı və Play Console-a bağlanmalıdır (bax
   əsas hesabatın 4-cü bəndi).
3. `functions/` deploy olunmalıdır (`verifyInAppPurchase`, `googlePlayRtdn`,
   `appStoreServerNotifications`, `expireLapsedPremium`).
4. `firestore.rules` deploy olunmalıdır.
5. (İstəyə görə) `npm run set-iap-testers -- <öz-uid-iniz>` — Android-də
   sandbox anlayışı olmadığı üçün BU ADDIM YALNIZ iOS testi üçün lazımdır,
   Apple aktiv olanda.

## 1. Play Console license tester ilə test satınalması

1. Play Console → Setup → License testing → öz Google hesabınızı əlavə edin.
2. Tətbiqi (internal/closed testing track-dən) həmin Google hesabı ilə
   quraşdırın.
3. VIP ekranına keçin, bir paket seçib alın — license tester olduğu üçün
   real pul çıxmayacaq.

**Yoxlanmalı:**
- Firestore Console → `users/{sizin-uid}.premium` → `true`, `premiumExpiresAt`
  dolu.
- `iapSubscriptions/{purchaseToken}` sənədi yaranıb, `uid` sizin uid-inizdir.
- Tətbiqdə "Artıq VIP-siniz" düyməsi görünür.
- Firebase Functions logs-da `verifyInAppPurchase` üçün xəta YOXDUR.

## 2. Eyni qəbzin ikinci hesabda rədd edilməsi (PAY-25)

Bunu birbaşa tətbiq UI-dan simulyasiya etmək çətindir (eyni purchase token-i
əl ilə ikinci hesabla göndərmək lazımdır) — Firebase Console-dan Functions
shell və ya bir test skripti ilə:

1. Addım 1-dəki `purchaseToken`-i (Firestore-dakı `iapSubscriptions` sənəd
   ID-si) tapın.
2. İKİNCİ bir test hesabı (fərqli uid) ilə daxil olun.
3. `verifyInAppPurchase`-i EYNİ `receiptData` (purchaseToken) ilə, YENİ
   uid-in auth kontekstində çağırın (bunu Firebase Emulator Suite-də və ya
   bir Node skripti ilə edə bilərsiniz — real Play Store-dan ikinci real
   alış etməyə ehtiyac yoxdur, çünki server heç vaxt "bu token artıq
   istifadə olunub" — yalnız "artıq FƏRQLİ uid-ə bağlıdır" yoxlayır).

**Gözlənilən:** `permission-denied` xətası, mesaj: "Bu alış artıq başqa
hesaba bağlıdır." `adminNotifications`-da `iap.receipt_theft_attempt` tipli
qeyd yaranır. Birinci hesabın `premium` statusu DƏYİŞMİR.

## 3. Restore purchases-in eyni hesabda işləməsi

1. Addım 1-dəki hesabla VIP alın.
2. Tətbiqi silin, yenidən quraşdırın (və ya `flutter clean` + yenidən
   build), EYNİ PeakPin hesabına daxil olun.
3. VIP ekranına keçin, "Alışları bərpa et" düyməsini basın.

**Gözlənilən:** bir neçə saniyə sonra `premium` statusu YENİDƏN `true` olur
(server-dən təsdiq gözlədiyi üçün dərhal deyil), heç bir xəta mesajı
görünmür.

## 4. Refund sonrası VIP-in geri alınması

Google Play Console-da test alışını ləğv edin (Order management → Refund),
sonra RTDN-in gəlməsini gözləyin (adətən bir neçə dəqiqə):

**Yoxlanmalı:** Firebase Functions logs-da `googlePlayRtdn` çağırışı
görünür, `users/{uid}.premium` → `false` olur.

## 5. Nəticələri necə bildirin

Ən vacib: addım 2-nin (PAY-25 rəddi) nəticəsi — bu, əsas kritik düzəlişin
işlədiyini təsdiqləyir. Hər hansı gözlənilməyən nəticə olarsa, Firebase
Functions logs-un screenshot-unu mənə göndərin.
