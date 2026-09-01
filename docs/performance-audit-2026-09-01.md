# Performans və cavabdehlik auditi

**Tarix:** 2026-09-01 · **Metod:** statik təhlil + koddan çıxan elan
edilmiş hədlər. Cihaz ölçmələri (startup, kadr) **hələ edilməyib** —
Samsung USB-dən düşüb; bərpa olunanda `am start -W` ilə əlavə ediləcək.

Rəqəmlərin statusu bu sənəddə açıq göstərilir: **[ölçülmüş]**,
**[koddan]** (elan edilmiş timeout, faktdır), **[təxmini]**.

---

## 🔴 P-1 — İlk kadra qədər 10 ardıcıl `await`

```
YER:       lib/main.dart:31–159, runApp() sətir 147
AXIN:      tətbiqi açmaq
GECİKMƏ:   [koddan] ən pis hal 8+ saniyə, ilk açılışda
SƏBƏB:     runApp()-dan əvvəl 10 ardıcıl await, ikisi şəbəkə gözləyir
PRİORİTET: 🔴
```

Zəncir: `Firebase.initializeApp` → `CallPushService.initialize` →
`listenToCallkitEvents` → `AppCheck.activate` → **`AppCheck.getToken()
.timeout(5s)`** → `SharedPreferences` → `resolveInitialLocale` →
**`appConfigRepository.init()`** → `PackageInfo` → `FlutterBranchSdk.init`.

İki nöqtə həlledicidir:

* **`main.dart:121` — App Check tokeni, 5 saniyəlik timeout.** Və bu
  timeout **boşa çıxmır**: logcat-da atestasiyanın uğursuz olduğu
  qeydə alınıb — `403 App attestation failed`, ardınca `Too many
  attempts`. Yəni hər soyuq başlanğıcda bu 5 saniyə çox güman ki tam
  sərf olunur.
* **`remote_config_data_source.dart:91` — ilk fetch, 3 saniyəlik
  timeout.** Yalnız ilk açılışda, amma məhz ilk təəssürat orada
  formalaşır.

**Düzəliş yanaşması:** hər ikisi `runApp()`-dan SONRA, arxa fonda
işləyə bilər. App Check tokeni ilk kadr üçün lazım deyil — heç bir
callable `enforceAppCheck: true` deyil (yoxlanılıb: 40 funksiyanın
hamısı `false`). Remote Config-in paketlənmiş defoltları onsuz da var,
yəni fetch gəlməmiş tətbiq işləyə bilər; gələndə `AppConfig` yenilənir.

---

## 🔴 P-2 — Callable timeout-ları (DÜZƏLDİLDİ)

```
YER:       39 çağırış yeri
GECİKMƏ:   [koddan] 60 saniyə → 20s (adi), 40s (ödəniş)
SƏBƏB:     Firebase-in defolt callable timeout-u 60s, heç yerdə override yox idi
PRİORİTET: 🔴 → bağlandı
```

Ödəniş ekranındakı «çox fırlanır» şikayətinin sistemli səbəbi.
Bu gün düzəldildi (`lib/core/utils/callables.dart`).

---

## 🟠 P-3 — Vizual geri bildirişi olmayan toxunma sahələri

```
AXIN:      istifadəçi düyməyə basır, heç nə olmur
GECİKMƏ:   [təxmini] 0 ms — heç vaxt reaksiya yoxdur
SƏBƏB:     GestureDetector ripple vermir
PRİORİTET: 🟠
```

| Fayl | GestureDetector | InkWell |
|---|---|---|
| `chat/.../chat_conversation_screen.dart` | 10 | **0** |
| `offers/.../create_offer_screen.dart` | 7 | **0** |
| `post_share/.../post_reel_item.dart` | 6 | **0** |
| `post_share/.../comments_sheet.dart` | 6 | **0** |
| `calls/.../call_screen.dart` | 5 | **0** |
| `privacy/.../privacy_security_screen.dart` | 3 | **0** |
| `auth/.../onboarding_screen.dart` | 3 | **0** |

Bütün kod bazasında `InkWell`/`InkResponse` işlədən ekran **yoxdur**.
Bu, tək-tək qüsur deyil, sistemli boşluqdur.

---

## 🟠 P-4 — Naviqasiyadan əvvəl şəbəkə gözləmək

```
AXIN:      elementə toxunmaq → ekran açılması
GECİKMƏ:   [təxmini] 200–800 ms yaxşı şəbəkədə, pis şəbəkədə 20s (yeni timeout)
SƏBƏB:     await ... .future ondan sonra Navigator.push
PRİORİTET: 🟠
```

| Yer | Nə gözləyir |
|---|---|
| `live_feed_screen.dart:95` | `pinboxByIdProvider` → sonra `PinBoxCheckoutScreen` |
| `notification_navigation.dart:108` | `pinboxByIdProvider` → sonra push |
| `notification_navigation.dart:141` | `venueByIdProvider` → sonra push |
| `my_venues_screen.dart:137,140` | **iki ardıcıl** await → sonra menyu açılır |
| `story_providers.dart:52` | `otherUserPrivacySettingsProvider` |

`my_venues_screen.dart` xüsusilə pisdir: iki sorğu **ardıcıl** gedir,
`Future.wait` ilə paralelləşdirilə bilər.

**Düzəliş yanaşması:** əvvəlcə ekranı aç (skeleton/shimmer ilə),
məlumatı orada yüklə. İstifadəçi dərhal cavab görür.

---

## 🟠 P-5 — İlişən `loading` vəziyyətləri

```
YER:       location_providers.dart (DÜZƏLDİLDİ), digərləri yoxlanmalı
PRİORİTET: 🟠
```

Lokasiyada tapılan naxış bu gün düzəldildi: `timeLimit` yox idi,
`didChangeAppLifecycleState` yalnız `hasError` bərpa edirdi, ilişmiş
`loading` üçün çıxış yolu yox idi.

**Qalan iş:** eyni naxış üçün bütün `AsyncValue` istifadələrini
yoxlamaq — hansılarında timeout, xəta halı və «yenidən cəhd» var.
Bu, hələ edilməyib.

---

## 🟡 P-6 — Siyahı qurulması

```
SingleChildScrollView istifadə edən fayl:  7
ListView.builder istifadə edən fayl:       9
```

`SingleChildScrollView` + `Column` bütün elementləri **birdən** qurur.
7 faylın hansılarında siyahı böyüyə bilər — ayrıca yoxlanmalıdır.

---

## 🟡 P-7 — Realtime dinləyicilər

```
.snapshots() çağırışı: 68
.cancel() çağırışı:    64
```

Nisbət balanslıdır, açıq sızma əlaməti yoxdur. Amma bu, statik saydır —
hansı dinləyicinin hansı `cancel`-a uyğun gəldiyi yoxlanmayıb.

---

## Növbəti addımlar

1. **Cihaz ölçmələri** — `am start -W` ilə soyuq başlanğıc (3 təkrar),
   P-1-in real rəqəmini vermək. Kabel bərpa olunan kimi.
2. P-1 düzəlişi — ən böyük təsir, ən aydın səbəb.
3. P-3 — `InkWell` sweep-i, ən çox istifadə olunan ekranlardan başlayaraq
   (çat, kəşf, təklif yaratma).
4. P-4 — naviqasiyanı şəbəkədən qabağa çıxarmaq.
