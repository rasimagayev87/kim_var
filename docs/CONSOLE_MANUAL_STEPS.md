# GCP əməliyyatları — hansı yol işləyir

**Bu sənəd əl ilə görüləcək işlərin siyahısı kimi başladı və artıq
elə deyil.** Hər üç iş avtomatlaşdırıla bildi; sənəd ona görə qalır ki,
növbəti dəfə eyni diaqnozu təkrar aparmayaq.

## Şəbəkə əlçatanlığı — ölçülmüş nəticələr (2026-08-31)

| Endpoint | Vəziyyət |
|---|---|
| `cloudfunctions.googleapis.com` | ✅ açıq |
| Cloud Functions HTTP (`*.a.run.app`, `*.cloudfunctions.net`) | ✅ açıq (400 = funksiya cavab verdi) |
| `gcloud firestore ...` (Admin API) | ✅ açıq |
| `firestore.googleapis.com` (data: `documents:runQuery`) | ⚠️ **qeyri-sabit** |
| `firebase deploy` (bütün hədəflər) | ✅ açıq |

### `firebase functions:call` mövcud deyil

Firebase CLI-nin bu versiyasında belə əmr yoxdur (`firebase --help`
ilə yoxlanıldı). Callable funksiyanı CLI-dən çağırmaq üçün yol
yoxdur — lazım olsa, HTTP `onRequest` funksiyası yazılmalı və `curl`
ilə çağırılmalıdır. Funksiya URL-ləri əlçatan olduğu üçün bu yol
işlək qalır.

### ⚠️ Ən vacib nəticə: Firestore data endpoint-i QEYRİ-SABİTDİR

Eyni ünvan bir neçə saat ərzində iki fərqli davranış göstərdi:

```
17:30 → connect ETIMEDOUT 142.251.142.106:443   (gRPC və REST, hər ikisi)
22:15 → HTTP 404                                 (yəni əlçatan)
```

Yəni bloklanma **daimi deyil**. Admin SDK skripti 17:30-da işləmədi,
22:15-də ilk cəhddə işlədi.

**Praktik nəticə:** Firestore-a birbaşa çıxış tələb edən iş uğursuz
olarsa, DƏRHAL «bloklanıb» qərarına gəlməyin — bir müddət sonra
təkrar sınayın. Vaxt itirməmək üçün ölçmə əmri:

```bash
curl -s -o /dev/null -w "%{http_code}\n" --max-time 15 https://firestore.googleapis.com/
# 404 → əlçatan (kök yol üçün normal cavab)
# 000 → o an bloklanıb, sonra təkrar sınayın
```

---

## Görülən işlər

### 1–2. `config/*` sənədlərinin deprecated işarələnməsi — ✅ EDİLDİ

```bash
cd ~/Developer/kim_var/admin-panel && npm run deprecate-category-configs
```

Nəticə:
```
config/eventCategories: deprecated olaraq işarələndi (mövcud dəyərlər saxlanıldı)
config/waitlistCategories: deprecated olaraq işarələndi (mövcud dəyərlər saxlanıldı)
```

Hər iki sənədə `deprecated: true`, `deprecatedAt`, `deprecatedReason`
merge edildi. `enabledCategories` **toxunulmadı**. Skript idempotentdir
— təkrar işlədilsə, artıq işarələnmişləri atlayır.

Birdəfəlik callable funksiya yazmağa ehtiyac qalmadı; yazılsaydı, o
funksiyanın kodda unudulması özü gələcək risk olardı.

### 3. `notificationIntents` üçün TTL siyasəti — ✅ EDİLDİ

```bash
gcloud firestore fields ttls update expiresAt \
  --collection-group=notificationIntents \
  --project=kim-var-73ce9 --enable-ttl
```

Yoxlama:
```bash
gcloud firestore fields ttls list --project=kim-var-73ce9
# → notificationIntents/fields/expiresAt, ttlConfig.state
```

Console lazım olmadı. Kolleksiya hələ mövcud olmasa da siyasət qəbul
edildi (TTL sahə konfiqurasiyasıdır, sənədlərdən asılı deyil), yəni
Mərhələ 2 deploy olunan kimi işləməyə başlayır.

**Siyasət `CREATING` → `ACTIVE` keçidi bir neçə dəqiqə çəkir.**
Aktivləşənə qədər sənədlər silinmir — bu, məlumat itkisi riski deyil,
sadəcə gecikmədir.

### 4. Ad günü axını üçün iki TTL siyasəti — ⏳ DEPLOY-DAN SONRA

Ad günü axınının yenidən qurulması (2026-09-01) iki yeni `expiresAt`
sahəsi gətirir. Hər ikisi eyni əsaslandırma ilə: yığıla bilməyən
struktur, təmizləyən funksiya yox.

```bash
# birthdayMatches — docs/BACKLOG.md #26. Gündə uyğun məkan başına bir
# sənəd yazılırdı və heç vaxt silinmirdi.
gcloud firestore fields ttls update expiresAt \
  --collection-group=birthdayMatches \
  --project=kim-var-73ce9 --enable-ttl

# birthdayFeed — 13:00 nəşrinin nəticəsi, istifadəçi başına gündə bir
# sənəd. ALT KOLLEKSİYADIR (`users/{uid}/birthdayFeed/{dateKey}`), amma
# TTL onsuz da kolleksiya QRUPU üzrə işləyir, yəni əmr eynidir.
gcloud firestore fields ttls update expiresAt \
  --collection-group=birthdayFeed \
  --project=kim-var-73ce9 --enable-ttl
```

Yoxlama — hər ikisi `ACTIVE` olmalıdır:
```bash
gcloud firestore fields ttls list --project=kim-var-73ce9
```

**Nə üçün üç gün:** hər ikisi eyni gün istifadə olunur və ertəsi gün
mənasızdır — `assertBirthdayTargeting` artıq yalnız bugünkü eşleşməni
qəbul edir. Üç gün uğursuz icranın sonradan araşdırılması üçün ehtiyat
pəncərədir, `INTENT_RETENTION_DAYS` ilə eyni.

**TTL yeganə təmizləyici deyil.** Story təcrübəsindən çıxan dərs
saxlanılıb: `cleanupExpiredStories` yazılmasının səbəbi TTL→trigger
zəncirini yoxlaya bilməməyimiz idi. Burada isə TTL-dən heç bir trigger
asılı deyil — sənədlərin özündən başqa silinəsi şey yoxdur (nə Storage
obyekti, nə alt kolleksiya), yəni zəncir sadəcə mövcud deyil.

### 5. Auth linklərinin brendləşdirilməsi — ⏳ CONSOLE TƏLƏB OLUNUR

Parol bərpası və e-poçt doğrulama linkləri
`kim-var-73ce9.firebaseapp.com/__/auth/action`-a gedir — həm layihənin
KÖHNƏ adı, həm də istifadəçinin şübhələnməyə öyrədildiyi tanımadığı
domen.

Əvəzedici səhifə **hazırdır və canlıdır**: `https://peakpin.app/auth-action`
(`peakpin-landing/public/auth-action.html`). Üç rejim, dörd dil, PeakPin
dizaynı, sıfır üçüncü tərəf skripti.

**Bu ayar API ilə edilə bilmir.** Cəhd edildi:

```
PATCH identitytoolkit.googleapis.com/admin/v2/projects/kim-var-73ce9/config
     ?updateMask=notification.sendEmail.callbackUri
→ INVALID_ARGUMENT: EMAIL_TEMPLATE_UPDATE_NOT_ALLOWED
```

Pulsuz Firebase Auth təbəqəsi e-poçt şablonu / `callbackUri`
yeniləmələrini API-dən bağlayır. Konfiqurasiya dəyişməyib — qismən
yazı baş verməyib.

**Console addımları (bir dəfə, hər üç şablon üçün ORTAQ ayardır):**

1. Firebase Console → **Authentication** → **Templates**
2. İstənilən şablonu aç (məsələn "Password reset") → karandaş ikonu
3. Aşağıda **"Customize action URL"** linkinə bas
4. Dəyəri belə et:
   ```
   https://peakpin.app/auth-action
   ```
5. **Save**

`callbackUri` **tək sahədir** — üçünü ayrı-ayrı təyin etmək lazım
deyil, birində dəyişmək `resetPassword`, `verifyEmail` və
`recoverEmail`-in hamısına tətbiq olunur (API-dən oxunan konfiqurasiya
bunu təsdiqləyir).

**Yoxlama:** ayarı dəyişəndən sonra tətbiqdən parol bərpası istə və
gələn linkin `peakpin.app/auth-action?mode=resetPassword&oobCode=…`
ilə başladığını yoxla.

**Geri qaytarma:** eyni sahəni
`https://kim-var-73ce9.firebaseapp.com/__/auth/action` et.

⚠️ `authDomain` DƏYİŞMİR. Bu, yalnız Console ayarıdır —
`firebase_options.dart`-a toxunmaq lazım deyil və toxunulmayıb.

### 6. `dailyStats` üçün TTL — ⏳ DEPLOY-DAN SONRA

Məkan analitikasının gündəlik sənədləri (`rollUpVenueDailyStats`,
docs/VENUE_ANALYTICS.md) 400 gün saxlanılır.

```bash
# ALT KOLLEKSİYADIR (`venues/{id}/dailyStats/{tarix}`), amma TTL
# kolleksiya QRUPU üzrə işləyir — əmr eynidir.
gcloud firestore fields ttls update expiresAt \
  --collection-group=dailyStats \
  --project=kim-var-73ce9 --enable-ttl
```

Yoxlama:
```bash
gcloud firestore fields ttls list --project=kim-var-73ce9
```

**Nə üçün 400 gün, 90 yox:** aylıq hesabatın ən dəyərli sətri «keçən ilin
eyni ayı» müqayisəsidir; qonaqpərvərlikdə mövsümilik əsas siqnaldır. 400
gün tam il + hesabatı yaratmaq üçün ehtiyat verir. 10 000 məkan × 400 gün
≈ 4M kiçik sənəd ≈ $1/ay.

---
## Bu, TTL-i toplayıcının öz silməsindən niyə üstün edir

Alternativ təklif — gündəlik toplayıcı oxuduğu sənədləri sonda özü
silsin — işlək idi və əlavə **oxu** tələb etmirdi. Amma iki zəifliyi
var idi:

1. **Buraxılmış işləmə sənədləri əbədi qoyur.** Toplayıcı son 24 saatı
   oxuyur; bir gün işləməsə, həmin günün sənədləri heç vaxt nə
   oxunur, nə silinir.
2. **Silmə əməliyyatı funksiyanın icra vaxtına düşür** — 50 000
   sənədlik gündə bu, funksiyanın timeout həddinə yaxınlaşan iş
   deməkdir.

TTL hər ikisini aradan qaldırır: silmə Firestore-un öz fon prosesidir,
funksiyanın uğurundan asılı deyil, və bizim tərəfdən nə oxu, nə icra
vaxtı sərf olunur. Silmə əməliyyatının özü sənəd silmə kimi hesablanır
— bu, hər iki variantda eynidir.

---
# E-poçt action URL: konsol xətası əsl səbəbi gizlədir

**Tarix:** 2026-09-02. **Status:** düzəldilməyib, BACKLOG-dadır.

Authentication → Templates → **Customize action URL** ilə dəyəri
`https://peakpin.app/auth-action` etməyə çalışanda konsol yalnız bunu
göstərir:

> An error occurred updating action URL

Bu mesaj heç nə demir. Eyni dəyişikliyi Identity Platform admin
API-si üzərindən göndərəndə əsl cavab çıxır:

```bash
TOKEN=$(gcloud auth print-access-token)
curl -s -X PATCH \
  "https://identitytoolkit.googleapis.com/admin/v2/projects/kim-var-73ce9/config?updateMask=notification.sendEmail.callbackUri" \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Goog-User-Project: kim-var-73ce9" \
  -H "Content-Type: application/json" \
  -d '{"notification":{"sendEmail":{"callbackUri":"https://peakpin.app/auth-action"}}}'
```

```
400 INVALID_ARGUMENT — EMAIL_TEMPLATE_UPDATE_NOT_ALLOWED
```

**Ümumi dərs:** Firebase Console-un "An error occurred …" mesajları
server cavabını udur. Konsolda ilişəndə eyni əməliyyatı admin API-si
ilə təkrarlayın — xəta kodu adətən birbaşa səbəbi adlandırır.

## Sahə hara yazılır

Action URL şablona görə deyil, layihə səviyyəsində saxlanılır:
`notification.sendEmail.callbackUri`. Şablonların öz sahələri yalnız
`senderLocalPart`, `subject`, `body`, `bodyFormat`, `replyTo`-dur —
`customUri` adlı sahə YOXDUR (ilk cəhdimiz bu adla getdi və "Cannot
find field" aldı).

## Bloklamanın səbəbi (ehtimal)

Ayırd edici sınaq: eyni `updateMask` üsulu ilə
`verifyEmailTemplate.subject` yazmaq **uğurla keçir**. Yəni şablon
yazıları bloklanmayıb — bloklama məhz `callbackUri` sahəsinə aiddir.

Konfiqurasiyada tək anomaliya budur:

```
notification.sendEmail.dnsInfo:
  customDomain: mail.peakpin.app
  useCustomDomain: true            ← aktiv işarələnib
  customDomainState: NOT_STARTED   ← doğrulama heç başlamayıb
  domainVerificationRequestTime: 1970-01-01T00:00:00Z
```

Layihə "xüsusi e-poçt domeni istifadə edirəm" deyir, amma doğrulama
heç vaxt işə salınmayıb. Yarımçıq domen vəziyyəti `sendEmail`
blokunun URL hissəsini kilidləyir.

Rədd EDİLƏN səbəblər — hər ikisi yoxlanıldı, problem deyil:

* **İcazəli domenlər.** `peakpin.app` siyahıdadır (`localhost`,
  `kim-var-73ce9.firebaseapp.com`, `kim-var-73ce9.web.app`,
  `admin.peakpin.app`, `auth.peakpin.app`, `peakpin.app`,
  `mail.peakpin.app`).
* **Səhifənin mövcudluğu.** `https://peakpin.app/auth-action` HTTP 200
  qaytarır — hazır və canlıdır, sadəcə hələ istifadə olunmur.

## Düzəliş sırası

1. **Əvvəlcə** SMTP settings → `mail.peakpin.app` üçün DNS
   doğrulamasını tamamlayın (`customDomainState` `NOT_STARTED`
   olmaqdan çıxmalıdır).
2. **Sonra** action URL-i `https://peakpin.app/auth-action` edin.

Sıra vacibdir: birincisi düzəlmədən ikincisi yazılmır.

## Niyə buraxılışı bloklamır

Cari dəyər `https://kim-var-73ce9.firebaseapp.com/__/auth/action` —
Firebase-in öz işlək standart səhifəsidir. E-poçt təsdiqi və parol
sıfırlama linkləri indi də işləyir, sadəcə brendsiz görünür. 2026-09-02
buraxılışında bu, bilərəkdən toxunulmadan saxlanıldı: mağaza baxışı
davam edərkən canlı e-poçt konfiqurasiyasını tərpətmək lazımsız risk
olardı.
