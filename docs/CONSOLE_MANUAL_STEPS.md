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
