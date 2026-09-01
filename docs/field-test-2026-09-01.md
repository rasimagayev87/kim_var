# Cihaz testi — 2026-09-01, birləşdirilmiş plan

Samsung SM-A057F (Android 15) + iPhone 12 Pro, release build.

---

## Ən vacib tapıntı: iki problem kodda deyil

Bunlar bütün zəng işini kölgədə qoyur, ona görə birinci sıradadırlar.

### T-1. Tətbiq arxa fonda şəbəkədən kəsilir (OS səviyyəsi)

Logcat, zəng çalarkən:

```
17:44:49  DNS Requested by 10964(com.peakpin.app), 4(FAIL), isBlocked=true
17:44:55  ... isBlocked=true          (13 saniyə ərzində 87 bloklanmış sorğu)
17:45:02  ... isBlocked=true
17:47:34  DNS Requested by 10964(com.peakpin.app), SUCCESS, 37ms      ← ön plana çıxandan sonra
```

Səbəb:

```
com.android.server.net.use_metered_firewall_chains: true
17:47:54.971  Firewall rule changed: 10964-background-allow
```

Cihaz **metered firewall chains** rejimindədir: tətbiq arxa fonda ikən
şəbəkəsi kəsilir, ön plana çıxanda açılır. Batareya optimizasiyası
istisnasında da deyil (`dumpsys deviceidle whitelist` → yoxdur).

Nəticə: arxa fonda **heç bir Firestore yazısı serverə çatmır**.
`deliveredAt` yazılmır (#3), CallKit-in `accepted` yazısı çatmır,
WebRTC siqnalizasiyası ümumiyyətlə mümkün deyil. Firestore yazını
lokal növbəyə qoyur və şəbəkə açılanda göndərir — «yalnız sonda
bildiriş» məhz budur.

**Vacib:** yüksək prioritetli FCM (bizdə var: `priority: "high"`,
data-only, ttl 45s) adətən qısa müddətlik şəbəkə pəncərəsi verir.
Pəncərə bağlanmışdırsa və ya heç açılmayıbsa, arxa fon işi mümkün
deyil. Bizim arxa fon işimiz isə indi UZUNDUR:
`Firebase.initializeApp()` + auth bərpasını 5 saniyəyə qədər gözləmə +
Firestore yazısı. O 5 saniyəlik gözləməni mən bu gün əlavə etdim və o,
məhz pəncərəyə qarşı işləyir.

### T-2. `logError` release build-də heç nə yazmır

`app_logger.dart:10` `dart:developer`-in `developer.log()` funksiyasını
işlədir. Release/AOT build-də bu, VM service-ə gedir və logcat-da
**görünmür**. Logcat-da `peakpin.*` adlı bir dənə də sətir yoxdur —
yoxladım, sıfır.

Yəni bütün gün «xətanı loga yazdıq» dediyimiz yerlər test etdiyimiz
build-də görünməzdir. T-1-i də loglardan yox, OS jurnalından tapdım.
Bu, diaqnostikanı kor edən qüsurdur və digər hər şeydən əvvəl
düzəlməlidir.

---

## Kodda olan problemlər

### K-1. Zəng: OS ekranından cavab (#1)

Kod düzəlişi yerindədir və doğrudur — `watchIncomingCall` artıq
`accepted`-i də tutur, `HomeScreen` `acceptCall()` çağırır, yazı
tranzaksiyalıdır, köhnəlmə həddi var, soyuq başlanğıc bərpası var.
**Amma T-1 həll olunmadan bunu cihazda təsdiqləmək mümkün deyil**,
çünki heç bir yazı serverə çatmır.

### K-2. «Zəng çalınır» (#3)

Kök səbəb T-1-dir. Bugünkü `Firebase.initializeApp()` düzəlişi zəruri
idi (onsuz izolyatda Firestore ümumiyyətlə işləmirdi), lakin kifayət
deyil.

### K-3. Çat düymələrinin həssaslığı (#2)

İki ayrı səbəb, ikisi də təsdiqlənib:

* Ekranda (2339 sətir) **sıfır** `InkWell`/`Material` ripple, 10
  `GestureDetector`. `GestureDetector` heç bir vizual cavab vermir —
  «boşluğa basdım» hissi buradandır.
* `_startCall` (sətir 610) naviqasiyadan ƏVVƏL `startCall()`-u
  `await` edir: mikrofon açılır, PeerConnection qurulur, Firestore-a
  yazılır. Bu saniyələr ərzində ekranda heç nə dəyişmir.

R8-lə əlaqəsi yoxdur — səbəb ölçüldü, fərziyyə deyil.

### K-4. Lokasiya icazəsi ilk açılışda istənilmir

`HomeScreen.initState:100` `syncSubscriptions()` → bildiriş icazəsi.
Eyni ilk kadrda `DiscoverTab.build:164` `locationControllerProvider`-i
qurur, o isə `LocationController()..refresh()` → lokasiya icazəsi.
**İki icazə eyni anda istənilir**; Android ikincini göstərmir.

Altındakı ikinci qüsur: `LocationController` `AsyncValue.loading()` ilə
başlayır, `getCurrentPosition`-da `timeLimit` yoxdur, və
`didChangeAppLifecycleState` (`discover_tab.dart:119`) yalnız
`hasError` olduqda yenidən cəhd edir. İlişmiş `loading` heç vaxt
bərpa olunmur — sonsuz spinner.

### K-5. Ödənilməmiş məkan (#4 və #6-dan çıxan)

Kvota sistemi həm serverdə, həm klientdə **düzgün işləyir** — #6 səhv
deyildi. Amma:

* Kampaniya/PinBox/tədbir yaratma ekranı `awaiting_payment` məkanı
  seçməyə icazə verir
* Ona qiymət göstərir
* Форма doldurulandan sonra ümumi «Əməliyyat baş tutmadı» ilə bitir

Server konkret səbəb bilir (`venue.status !== "approved"`), klient onu
ümumi mesaja çevirir.

### K-6. Profil saxlanması yavaşladı (mənim geriləməm)

`ProfileController.save` Firestore batch-dən callable-a keçdi. Batch
lokal olaraq dərhal tətbiq olunurdu və dinləyici o andaca UI-ı
yeniləyirdi; callable-da bu yoxdur. Kilidlər üçün callable zəruri idi,
gözləmə hissini isə kompensasiya etməmişəm.

---

## Sıra

**Mərhələ 0 — görmə qabiliyyəti**

1. `logError` release-də logcat-a yazsın (T-2). Bunsuz qalan hər şeyi
   kor-koranə düzəldirik.

**Mərhələ 1 — zəng (T-1 + K-1 + K-2)**

2. Arxa fon işini FCM pəncərəsinə sığacaq qədər qısaltmaq: auth
   gözləməsini 5s-dən ~1.5s-ə endirmək, `initializeApp` və Firestore
   yazısını paralel başlatmaq.
3. Batareya optimizasiyası istisnası istəmək
   (`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`) — zəng tətbiqləri üçün
   Play siyasətinə uyğundur. İstifadəçiyə bir dəfə izahlı dialoq.
4. Ondan sonra K-1-i cihazda təsdiqləmək.

**Mərhələ 2 — hiss olunan sürət**

5. K-4: icazələri ardıcıllaşdırmaq, `timeLimit`, ilişmiş `loading`-dən
   bərpa, `getLastKnownPosition()` ilə dərhal ilkin nəticə.
6. K-3: ripple + naviqasiyanı `await`-dən qabağa çıxarmaq.
7. K-6: optimistik profil yeniləməsi.

**Mərhələ 3 — mesajlar**

8. K-5: status-a görə konkret mətnlər (kampaniya/PinBox/tədbir, 4
   dildə) + ödənilməmiş məkanın seçim siyahısındakı davranışı.
9. Sweep: serverin konkret kod qaytarıb klientin ümumi mesaja
   çevirdiyi digər yerlər.

**Toxunulmur:** #5 (PushKit sertifikatı).
