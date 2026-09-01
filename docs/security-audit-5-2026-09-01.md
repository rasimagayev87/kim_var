# «Kilidləndi, amma açarı verilmədi» — profil kimlik sahələri

**Tarix:** 2026-09-01
**Səbəb:** istifadəçi bildirdi ki, «Şəxsi məlumatlar» ekranında ad, soyad
və istifadəçi adı dəyişdirmək `permission-denied` verir.

Bu, adi bir səhv deyil, ayrıca səhv sinfidir: **bir sahə kilidləndi,
amma ona qanuni dəyişmə yolu qurulmadı.** Əvvəlki funksional bütövlük
auditi bunu tutmadı, çünki hər tapıntı üçün «bu sahəni kim yaza bilər?»
soruşulmuşdu, «qanuni istifadəçi hələ də bunu edə bilirmi?» yox.

---

## 1. Kök səbəb — `.lower()` ASCII-dir

Həmin gün əlavə edilmiş qayda:

```
nameLower == (firstName + ' ' + lastName).trim().lower()
```

Firestore Rules-un `.lower()` funksiyası **yalnız ASCII** hərfləri
kiçildir. Dart-ın `String.toLowerCase()` isə tam Unicode-dur. İki tərəf
Ə, İ, Ş, Ç, Ö, Ü, Ğ hərflərində razılaşmır.

Emulyatorda ölçüldü:

| Ad | Nəticə |
|---|---|
| Rasim Agayev | keçir |
| Əli Məmmədov | **rədd** |
| İlqar Şükürov | **rədd** |
| Ülvi Çobanov | **rədd** |
| Günel Öztürk | **rədd** |

Yəni qaydanın davranışı istifadəçinin adının hərflərindən asılı idi.
Azərbaycan bazarı üçün bu, istifadəçilərin böyük hissəsi deməkdir.

**Testlər niyə tutmadı:** `firestore-p0-h6.test.ts`-in hər nümunəsi
("Ad Soyad", "Tək") ASCII idi. Qayda öz test dəstində 100% keçirdi.

**İkinci nəticə — yarımçıq yazma.** Ekran əvvəlcə `updateUsername()`,
sonra `save()` çağırırdı. İkincisi yuxarıdakı səbəbdən sınırdı, amma
birincisi artıq commit olunmuşdu: hesab yeni handle və köhnə adla
qalırdı, ekranda isə yalnız ümumi xəta görünürdü.

---

## 2. Kilid siyahılarının tam sweep-i

### `users/{uid}`

| Sahə | Qanuni yol | Vəziyyət |
|---|---|---|
| `premium`, `premiumExpiresAt` | server (VIP ödənişi) | düzgün |
| `identityVerified` | `submitIdentityVerification` | düzgün |
| `birthDate` (public) | ölü sahə, canlısı private-dədir | düzgün |
| `reportedCount` | başqa istifadəçi +1 | düzgün |
| `username` | rezervasiya + `updateUsername` | **işləyirdi** — istifadəçiyə sınıq görünürdü, çünki eyni saxlamada `nameLower` sınırdı |
| `nameLower` | — | **SINIQ** |

### `users/{uid}/private/data`

| Sahə | Qanuni yol | Vəziyyət |
|---|---|---|
| `email` | `syncContactEmail` | düzgün |
| `consent` | `recordConsent` | düzgün |
| `fcmTokens` | `registerFcmToken` / `unregisterFcmToken` | düzgün |
| `loginProvider`, `knownDeviceSignatures`, `blockedByUsers`, `banned` | server | düzgün |
| `birthDate` | **yox idi** | səhv yazılmış tarix əbədi qalırdı → ad günü kampaniyaları o istifadəçi üçün həmişə yanlış günə düşürdü |
| `phoneNumber` | **yox idi** | nömrə dəyişdirilə bilmirdi |

### `venues` (46 sahə)

`updateVenue` / `resubmitVenue` bütün məzmun sahələrini örtür (`name`,
`nameLower`, `category`, `photoUrl`, `address`, `lat`/`lng`,
`openingHours`, `socialLinks`, `audienceRadius*`,
`birthdayNotificationsEnabled`). Sayğaclar, status və ödəniş sahələri
qəsdən server-onlydir.

Yeganə istisna `gallery` — kod bazasında heç bir yazıcısı yoxdur, ölü
sahədir. BACKLOG #32.

### `offers`

`updateOffer` / `resubmitOffer` məzmunu örtür; `freeCampaignHold`,
`status` və ödəniş sahələri serverdədir. Boşluq yoxdur.

### `.lower()` sweep-i

`firestore.rules`-da cəmi üç çağırış:

- **424, 425** — `username.lower()`. Sınıq deyil: handle-lar
  `USERNAME_PATTERN` ilə ASCII-yə məhdudlaşdırılıb, ona görə iki tərəf
  heç vaxt ayrılmır.
- **458** — sınıq olan. Silindi.

`venues.nameLower` üçün qaydalarda heç bir `.lower()` yoxlaması YOXDUR —
o dəyər `submitVenue`/`updateVenue` içində Node-un tam Unicode
`toLowerCase()`-i ilə törədilir. **Məkan sahibləri bloklanmamışdı.**

---

## 3. Düzəliş

Tək yazma yolu: **`updateProfileDetails`** callable-ı.

- `username`, `firstName`, `lastName`, `nameLower`,
  `usernameChangedAt`, `nameChangedAt` → `touchesLockedUserFields()`
- `birthDateChangedAt` → `serverOnlyFields()`
- `usernameOwnedByCaller()` və `nameLowerMatchesName()` **silindi**

`nameLower` serverdə törədilir (`deriveNameLower`, `completeOnboarding`
ilə paylaşılan). Hər şey **bir tranzaksiyada** commit olunur — handle
dəyişimi, ad, doğum tarixi, telefon və rezervasiya swap-ları — yəni
yarımçıq vəziyyət struktur olaraq mümkün deyil.

### Dəyişmə tezliyi

| Sahə | Limit | Səbəb |
|---|---|---|
| Telefon | limitsiz | yeni SIM adi hadisədir, sui-istifadə vektoru deyil |
| İstifadəçi adı | 30 gün | handle dəyişimi başqalarının onu tapmasını pozur |
| Ad / soyad | 15 gün | eyni |
| Doğum tarixi | **ömürdə 1 dəfə** | dəyişən şey deyil; sərbəst buraxılsa hər gün tarixi dəyişib ad günü təklifi almaq mümkün olardı |

Doğum tarixi limitini keçən istifadəçi dəstəyə yönləndirilir — qalan hal
(iki dəfə səhv yazmaq) məhz insan yoxlaması tələb edən haldır.

### Xəta mesajları

`permission-denied` istifadəçiyə nə sındığını da, nə vaxt yenidən cəhd
edəcəyini də demirdi. İndi hər rədd tam cümlə qaytarır:

- «Bu istifadəçi adı artıq tutulub. Başqa bir ad seçin.»
- «Ad və soyadınızı 15 gündən bir dəyişə bilərsiniz. Növbəti
  dəyişikliyə 4 gün qalıb.»
- «Doğum tarixi yalnız bir dəfə dəyişdirilə bilər. Yenidən düzəliş üçün
  dəstəyə müraciət edin.»

`cooldownRemainingDays` YUXARI yuvarlaqlaşdırır: mesaj heç vaxt «0 gün
qalıb» deyib yazını rədd etmir.

---

## 4. Testlər

- `tests/rules/profile-identity.test.ts` — 15 test. Sabitlər mənbə
  faylından PARSE edilir; sınmış beş Azərbaycan adı regressiya hasarı
  kimi saxlanılır.
- `tests/rules/firestore-profile-identity.test.ts` — 12 test. Həm
  kilidlərin bağlı olduğunu, HƏM DƏ `bio`/`country`/`city`/`gender`-in
  hələ də sərbəst yazıldığını yoxlayır — ikincisi vacibdir, çünki bu
  düzəlişin özü kilid siyahısını genişləndirdi.
- `firestore-p0-h6.test.ts` — köhnə davranışı təsdiqləyən dörd test
  yenidən yazıldı. Qaydalar zəiflədilmədi.

Tam dəst: **796/796**.

---

## 5. Dərs

Kilid siyahısına sahə əlavə edən hər dəyişiklik iki sual tələb edir:

1. Bu sahəni indi kim yaza bilər?
2. **Qanuni istifadəçi hələ də bunu edə bilirmi — və hansı yolla?**

İkincisi soruşulmasa, nəticə təhlükəsizlik düzəlişi kimi görünən, amma
əslində məhsulun bir hissəsini söndürən dəyişiklikdir.

Əlavə dərs: **lokala aid davranışı ASCII nümunələrlə test etmək onu test
etmək deyil.** Bu qayda öz test dəstində tam keçirdi.
