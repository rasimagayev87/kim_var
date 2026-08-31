# Qəbul Edilmiş Risklər

Bu sənəd PeakPin-in QƏSDƏN həll edilməmiş, məlum boşluqlarının siyahısıdır —
"unudulmuş" deyil, ölçülüb QƏBUL EDİLMİŞ. Növbəti təhlükəsizlik auditi
zamanı, bu siyahıdakı hər maddə YENİDƏN "CRITICAL" kimi göstərilmədən
əvvəl, əvvəlcə bu faylı oxuyun — səbəb və şərt burada izah olunub.

Hər maddə: **Nə** / **Niyə qəbul edilib** / **Nə vaxt yenidən baxılmalı**
(konkret, ölçülə bilən şərt — tarix, rəqəm, ya da hadisə sayı). Rəqəmli
hədlər (istifadəçi sayı, xərc həddi və s.) mənim kalibrlə etdiyim təxmini
dəyərlərdir — real biznes mülahizənizə görə dəyişdirin, sabit qanun deyil.
Aşağıdakı bütün "N ay sonra" şərtləri, əks halı qeyd edilməyibsə,
buraxılış (launch) tarixindən hesablanır. Effektiv iş həcmi (backlog kimi
görüləcək maddələr üçün) [BACKLOG.md](BACKLOG.md)-da.

---

## Server/Rules

### `usernames/{usernameId}.get` imzasız hər kəsə açıqdır
**Nə:** `firestore.rules:671` — `allow get: if true`. İmzalanmamış istifadəçi
belə BİLİNƏN bir username-in mövcudluğunu yoxlaya bilər.
**Niyə qəbul edilib:** `deep_link_handler.dart`-ın `_openProfileByUsername`-i
paylaşılan `peakpin.app/u/{username}` linklərini imzasız istifadəçi üçün də
açmalıdır — `request.auth != null` tələbi bu axını sakitcə sındırardı (link
açılmır, xəta da göstərilmir). Sənədin özü `{uid, createdAt}`-dan başqa heç
nə daşımır.

> **2026-08-30 yenidən qiymətləndirmə (audit 2 / H-6).** Bu maddənin
> orijinal versiyası `get` və `list`-i eyni şey kimi qiymətləndirirdi və
> hər ikisini MAU 50,000 şərtinə bağlayırdı. Bu, səhv idi: `list`
> (`allow list: if request.auth != null`) bütün kolleksiyanın
> səhifələnməsinə imkan verirdi, yəni TAM `username → uid` xəritəsi —
> və hər uid `users/{uid}` `get`-i ilə tam publik profilə (o cümlədən
> `blockedUsers` sosial qrafına və `reportedCount` moderasiya
> siqnalına) çevrilirdi. Bu, RT-25-in `users` üzərindəki
> `allow list: if false` qərarını bir addım artıqla keçirdi.
> **`list` 2026-08-30-da bağlandı** (`firestore.rules:705`) və
> `searchUsersByUsername` callable-ı ilə əvəzləndi.
> **`get` isə qəsdən açıq qalır** — bir bilinən username-i açmaq publik
> profil kəşfidir; hamısını sadalamaq isə identifikasiya enumerasiyası.
> Sərhəd məhz bu ikisinin arasındadır və indi düzgün yerdədir.

**Nə vaxt yenidən baxılmalı:** `get` üçün konkret şərt YOXDUR — bu, məhsulun
tələb etdiyi davranışdır və miqyasla dəyişmir. Yeganə izlənməli hal: eyni
IP-dən lüğət hücumu ilə username sınaması (Cloud Logging-də `usernames`
`get` tezliyi) — bu, hələ izlənmir və ayrıca kiçik tapşırıqdır.

### Banlanmış hesabın hələ də yaza bildiyi 16 yol

**Nə:** `isActiveUser()` (= `exists(users/{uid}) && !exists(bannedUsers/{uid})`)
client-yazılabilir hər `create` qaydasına tətbiq edilməyib.

> **2026-08-30 yenilənməsi (öz-doğrulama / d4):** bu bölmə əvvəllər
> ÜÇ kolleksiya sadalayırdı. Faktiki say iyirmi idi. Sənədin natamam
> olması boşluğun özündən pisdir — oxuyan adam adı çəkilməyəni
> "qorunub" sayır. Aşağıda tam siyahı var.

**Nə üçün əlavə bir yoxlama pulsuz deyil:** `isActiveUser()` hər
çağırışda İKİ sənəd oxuyur. Bunu ən çox yazılan yollara qoymaq
(bəyənmə, baxış, profil ziyarəti) həmin yolların qiymətini iki-üç
dəfə artırar.

#### Bağlanmış (tətbiq edilib)

`chats/{chatId}/messages`, `calls`, `posts`, `stories`,
`posts/*/comments`, `reports`, `eventReports`, `reviewReports` —
Düzəliş Prompt 11 / Y-1 və P0 / C-3.

2026-08-30-da əlavə edildi: **`reviews`** (daimi ictimai reputasiya
məzmunu, arxasında heç bir moderasiya növbəsi YOXDUR — şikayət
gəlməyincə ona heç kim baxmır), **`follows`** (adı bilinən şəxsin
cihazına bildiriş göndərir — bandan sonrakı ən ucuz təqib vasitəsi),
**`chats`** (valideyn sənəd; `messages` onsuz da qorunurdu, yəni bu,
qərar deyil yarımçıq tətbiq idi).

#### Qəsdən açıq qalan (hər biri üçün səbəb)

| Yol | Səbəb |
|---|---|
| `supportMessages` | Məhz bu vəziyyətdə ilişmiş adam dəstəyə yaza bilməlidir. Bloklamaq ban-a etiraz yolunu bağlayardı |
| `usernames`, `users/*/private/*` | `isActiveUser()` `users/{uid}`-in mövcudluğunu tələb edir, bu sənəd isə `completeOnboarding`-də hər ikisindən SONRA yaranır. Tətbiq etmək qeydiyyatı sındırardı |
| `users/*/media`, `users/*/reposts`, `users/*/notifications` | Yalnız öz sənədi; kənara heç nə çıxmır |
| `calls/*/offerCandidates`, `answerCandidates` | Valideyn `calls` **qorunur** — banlanmış hesab zəngi ümumiyyətlə başlada bilmir. ICE namizədləri partlayış şəklində onlarla yazılır; hər birinə iki oxu qoymaq qazanc vermir |
| `posts/*/likes`, `comments/*/likes`, `stories/*/views`, `venues/*/likes`, `venues/*/followers`, `offers/*/redemptions` | Ən yüksək yazma tezliyi, ən aşağı zərər — sayğac səs-küyü |
| `users/*/profileViews` | Zərər real, amma **ölçüldü**: hər profil açılışında bir yazı, üstəlik mövcud incognito oxusu. Tətbiq etmək tətbiqin ən isti yazma yolunun oxu sayını üç dəfə artırardı. Daha ucuz həll oxu tərəfində süzgəcdir — `BACKLOG.md` |
| `pinboxes`, `venueEvents` | Moderasiya növbəsinə düşür; admin rədd edir |

**QEYD — yazma qapısı görünürlüyü həll etmir; o, ayrıca bağlandı.**
Banlanmış hesab `private/data`-ya öz `lat`/`lng`-ini, `users/{uid}`-ə
isə `online`/`lastSeen` yaza bilir, və `findNearbyUsers`/
`getDiscoverCandidates`-in namizəd süzgəcləri əvvəllər ban statusunu
YOXLAMIRDI — yəni banlanmış hesab başqalarının kəşf nəticələrində
qalırdı. Bu, yuxarıdakı siyahının davamı deyil, ayrı bir sinifdir:
`private/*` yazısını bağlamaq onu **düzəltməzdi**, çünki hesabı
görünən saxlayan sahə (`online`) tamam başqa sənəddədir.

2026-08-30-da bağlandı (`BACKLOG.md` #20): hər iki süzgəcə
`banned !== true` şərti əlavə edildi. Doğruluq mənbəyi
`bannedUsers/{uid}` olaraq qalır; `users/{uid}/private/data.banned`
yalnız oxu tərəfi üçün güzgüdür və `serverOnlyFields()` ilə
qorunur. **Fərqləndikləri halda tombstone üstündür** — heç bir qayda
və heç bir callable güzgüyə baxmır, ona görə bayat güzgü ən pisi
kimisə siyahıda görünən saxlaya bilər, icazə verə bilməz.

**Nə vaxt yenidən baxılmalı:** `moderationLogs`-da qeydə alınan
"banlanmış-istifadəçi-yeni-məzmun" hadisələri 1 təqvim ayında 20-ni
keçəndə.

### Silinmiş/banlanmış hesabın oxu tərəfi ~1 saat açıq qalır
**Nə:** `assertActiveUser`/`isActiveUser()` yalnız YAZI əməliyyatlarını
qoruyur — Firebase-in öz ID token-ı (təbii ~1 saat ömürlü) silinmə/ban
ANINDA ləğv olunmur, deməli həmin pəncərədə köhnə token hələ oxu üçün
işləyə bilər.
**Niyə qəbul edilib:** texniki məhdudiyyət — Firebase Auth token-ları
default olaraq real-time revoke olunmur, `revokeRefreshTokens` YALNIZ YENİ
token almağı əngəlləyir, mövcud tokeni deyil. Tam həll (hər sorğuda
token-in tam təzələnməsini yoxlamaq) əhəmiyyətli performans xərcinə
gətirər.
**Nə vaxt yenidən baxılmalı:** bu boşluqdan istifadə edən 1 (bir)
təsdiqlənmiş insident baş verərsə — DƏRHAL, gözləmədən.

### Storage-da per-user kvota yoxdur
**Nə:** heç bir istifadəçi Storage-a yüklədiyi ÜMUMİ məlumat həcminə görə
məhdudlaşdırılmayıb (yalnız TƏK fayl ölçüsü limiti var, `storage.rules`-da).
**Niyə qəbul edilib:** texniki məhdudiyyət — Storage Rules request-lər
arasında STATE saxlamır (bir istifadəçinin əvvəlki yüklədiklərinin CƏMİNİ
bilmir), bu, ancaq Cloud Function-da say/həcm izləməklə mümkündür — böyük
əlavə infrastruktur.

> **2026-08-30 yenidən qiymətləndirmə (audit 2 / M-11).** Orijinal
> qiymətləndirmə `forwardChatMedia`-dan ƏVVƏL edilib. O funksiya
> SERVER TƏRƏFDƏ kopyalama əlavə etdi: hücumçu bir dəfə 50 MB video
> yükləyib sonra onu yükləmə trafiki sərf etmədən çoxalda bilirdi.
> Bu, kvotasızlığın öz riskini dəyişməsə də, ona çatma SÜRƏTİNİ
> köklü artırırdı. Həmin funksiyanın limiti 30/600s-dən **10/3600s**-ə
> endirildi və ayrıca `forward-copy` sayğacına köçürüldü, yəni
> amplifikasiya bağlandı. Kvotanın özü hələ də yoxdur — maddə açıq
> qalır.

**Nə vaxt yenidən baxılmalı:** Firebase Storage-un aylıq faktura xərci
50 AZN-i keçəndə (Firebase Console → Usage and billing-dən yoxlanılır).

### Magic-byte MIME yoxlaması yoxdur
**Nə:** yüklənən şəkil/video faylların `Content-Type`-ı client-in bəyan
etdiyi dəyərə görə qəbul edilir, faylın öz baytlarının HƏQİQƏTƏN həmin
format olduğu yoxlanılmır.
**Niyə qəbul edilib:** bu yoxlama YALNIZ bir Cloud Storage trigger-lə
(faylın özünü oxuyub baytları təhlil edən) mümkündür — Storage Rules
faylın MƏZMUNUNA giriş əldə edə bilmir, yalnız metadata-ya.

> **2026-08-30 qeyd (audit 2 / M-10).** Bu maddə faylın BAYTLARININ
> yoxlanmaması haqqındadır və o, doğrudan da yalnız Storage trigger-i
> ilə mümkündür. AMMA auditdə AYRI bir problem tapıldı və o, bu maddəyə
> aid DEYİL: elan edilən `Content-Type` üçün allowlist yoxdur, yəni
> `image/.*` naxışı `image/svg+xml`-i də qəbul edir (13 yerdə,
> `storage.rules`). SVG Storage-dan `inline` təqdim olunduğu üçün bu,
> icra edilə bilən məzmundur. Bu, Storage Rules-da tam həll edilə bilər
> və qəbul edilmiş risk DEYİL — BACKLOG-a düşdü.

**Nə vaxt yenidən baxılmalı:** zərərli fayl yükləmə (məs. maskalanmış icra
edilə bilən fayl) insidenti 1 (bir) dəfə baş verərsə — DƏRHAL.

### Epoint-in checkout-ləğv API-si yoxdur (Prompt 6-dan)
**Nə:** açıq (ödənilməmiş) bir Epoint checkout linkini proqramla ləğv etmək
mümkün deyil — yalnız TAMAMLANMIŞ əməliyyatı geri qaytarmaq (`/reverse`)
mövcuddur.
**Niyə qəbul edilib:** inteqrasiya məhdudiyyəti — Epoint-in öz API-si bunu
təklif etmir (təsdiq edilib, `functions/src/epoint.ts`). `superseded`
statusu (Prompt 6) bu boşluğun YARATDIĞI real riski (köhnəlmiş linkdən gec
ödəniş) artıq bağlayıb — özü ləğv edilə bilməsə də.
**Nə vaxt yenidən baxılmalı:** Epoint-in API sənədləşməsi hər 6 ayda bir
yenidən yoxlanılmalıdır (son yoxlama: 2026-08-29, növbəti: 2027-02-28).

---

## Prompt 10-da "bloklamır" təsnif edilən maddələr

Bu maddələrin təxmini iş həcmi və prioritet sırası [BACKLOG.md](BACKLOG.md)-da.

### AUTH-8a — parol minimum 6 simvol (Firebase Auth-un öz defolt-u)
**Nə:** UI 8 simvol + mürəkkəblik tələb edir, AMMA bu YALNIZ client-side —
backend (Firebase Auth) öz 6-simvol minimumunu tətbiq edir, dəyişdirilmiş
client bunu keçə bilər.
**Niyə qəbul edilib:** 6 simvol bir çox istehlakçı tətbiqinin başlanğıc
profilidir, launch-ı bloklayan səviyyə hesab edilmədi.
**Nə vaxt yenidən baxılmalı:** qeydiyyatdan keçmiş istifadəçi sayı 5,000-i
keçəndə server-side (Cloud Function) minimum 8 simvola qaldırılmalıdır —
ucuz düzəlişdir, tezliklə edilə bilər (bax BACKLOG.md).

### AUTH-8b — real MFA (TOTP/əlavə amil) heç yerdə yoxdur
**Nə:** "İki mərhələli doğrulama" konsepti yalnız `twoFactorEnabled`
bayrağıdır (aşağı bax) — real ikinci amil (TOTP enrollment, secret
saxlanması) mövcud deyil.
**Niyə qəbul edilib:** əksər tətbiqlərin ilk versiyasında olmayan, əlavə
infrastruktur tələb edən bir dizayn qərarıdır.
**Nə vaxt yenidən baxılmalı:** istifadəçi sayı 50,000-i keçəndə VƏ YA
hesab-ələ-keçirmə insidenti 1 (bir) dəfə qeydə alınarsa (hansı ƏVVƏL baş
verərsə).

### AUTH-8-lə əlaqəli tapıntı: "2FA" bölməsi kod səviyyəsində mövcuddur, AMMA UI-da HEÇ YERDƏN çağırılmır
Araşdırma zamanı aşkar edildi ki, `_TwoFactorSheet`/`_TwoFactorSheetState`
(`privacy_security_screen.dart`) artıq istifadəçiyə HEÇ BİR yerdən
göstərilmir (heç bir sətir bu widget-i çağırmır) — "aldadıcı dekorativ
düymə" narahatlığı faktiki olaraq artıq mövcud deyildi. Bu, risk DEYİL,
sadəcə ölü koddur — yenidən baxılma şərti yoxdur (AUTH-8b real MFA
tikiləndə, bu kod ya real MFA-ya bağlanacaq, ya silinəcək).

### B4 — RT-19, zəng sənədləri heç vaxt silinmir
**Nə:** `calls/{callId}` sənədləri (+ `offerCandidates`/`answerCandidates`
alt-kolleksiyaları) heç vaxt silinmir, `firestore.rules`-un özü
`allow delete: if false` ilə bunu bloklayır.
**Niyə qəbul edilib:** yalnız kiçik SDP mətn blokları (KB səviyyəsində),
heç bir media/fayl yoxdur, oxu hüququ artıq iştirakçılarla məhdudlaşır —
məxfilik sızması YOXDUR, təmiz "hygiene"/xərc məsələsidir.
**Nə vaxt yenidən baxılmalı:** `calls` kolleksiyasının ümumi sənəd sayı
(Firebase Console → Firestore → Usage-dən yoxlanılır) 500,000-i keçəndə,
VƏ YA launch + 6 ay (hansı ƏVVƏL baş verərsə).

### C1a — INFRA-34/35/36, ProGuard/R8 (kod obfuskasiyası)
**Nə:** `android/app/build.gradle.kts`-də `isMinifyEnabled`/`isShrinkResources`
aktivləşdirilməyib — release build kodu açıq (obfuskasiya olunmamış) yayılır.
**Niyə qəbul edilib:** aktivləşdirmə bütün native plugin-lərin hələ düzgün
işlədiyini yoxlamaq üçün tam reqressiya testi tələb edir — bugünkü əhatəyə
sığmadı.
**Nə vaxt yenidən baxılmalı:** launch + 1 ay (nisbətən ucuz, real dəyər —
BACKLOG.md-də ilk sıralarda).

### C1b — INFRA-35/36, root/jailbreak aşkarlanması, TLS/sertifikat pinning
**Nə:** heç biri tətbiq olunmayıb.
**Niyə qəbul edilib:** root-detection paketinin inteqrasiyası (cihaz-üzrə
test), TLS pinning-in pin-rotasiya strategiyası — böyük mühəndislik işi,
mağaza bunları tələb etmir.
**Nə vaxt yenidən baxılmalı:** launch + 4 ay, VƏ YA fırıldaqçılıq/hesab-
oğurluğu insidenti (dəstək müraciətləri ilə təsdiqlənən) 1 təqvim ayında
3-ü keçəndə (hansı ƏVVƏL baş verərsə).

### C3 — INFRA-44, Node 20 (Maintenance LTS-i 2026 aprelində bitib — HAZIRDA EOL)
**Nə:** `functions/package.json`-un `engines.node` sahəsi hələ də `"20"`.
**Niyə qəbul edilib:** Firebase Functions runtime-ı hələ dəstəkləyir,
versiya keçidi (Node 22-yə) bütün `functions/`-un reqressiya testini
tələb edir — bu, bugünkü əhatəyə sığmadı.
**Nə vaxt yenidən baxılmalı:** 2026-10-31-dək (launch-dan ASILI OLMAYARAQ
— runtime artıq bu gün EOL-dur, hər əlavə ay istehsalatda yamasız qalmaq
riskini artırır). BACKLOG.md-də #1 prioritet.

### D4 — `reviews` miqrasiyası (Prompt 11-dən təxirə salınıb, Prompt 10-da təsdiq edildi)
**Nə:** `reviews/{reviewId}` sənəd ID-si `{venueId}_{userId}` — silinmiş
istifadəçinin şərhi HEÇ VAXT tam anonimləşə bilməz cari sxemlə (ID-nin
özü uid daşıyır).
**Niyə qəbul edilib:** düzgün həll (ID sxemini dəyişmək, "bir istifadəçi —
bir şərh" invariantını Cloud Function-da unikallıq yoxlaması ilə əvəz
etmək) memarlıq dəyişikliyidir, bir günə sığmır.

> **2026-08-30 yenidən qiymətləndirmə (audit 2 / M-7).** Orijinal
> əsaslandırma yalnız SİLİNMƏ/anonimləşdirmə haqqında idi. Auditdə eyni
> sxemin ikinci, daha yaxın nəticəsi tapıldı: `reviews`
> `allow read: if request.auth != null` olduğu üçün `list` da açıqdır,
> sənəd id-si isə `{venueId}_{userId}`-dir. Rəyin mövcudluğu
> `hasVerifiedVisit` sayəsində FİZİKİ ziyarətin sübutudur — yəni
> istənilən daxil olmuş istifadəçi bütün "kim hansı məkanda olub"
> qrafını çəkə bilər. Bu, GDPR gözləməsindən asılı olmayan CARİ
> məxfilik məsələsidir və `allow list: if false` ilə (məkan səhifəsinin
> rəy siyahısı callable-a köçürülərək) miqrasiyadan ƏVVƏL bağlana bilər.
> BACKLOG-a ayrıca maddə kimi düşdü.

**Nə vaxt yenidən baxılmalı:** `reviews` kolleksiyasının sənəd sayı 5,000-i
keçəndə, VƏ YA launch + 6 ay (hansı ƏVVƏL baş verərsə) — GDPR-tipli
"silinmə hüququ" tələbi olan istənilən bazara giriş bundan ƏVVƏL edilməlidir.

### E1 — PAY-28, TAM float→qəpik miqrasiyası (yalnız düstur Prompt 10-da düzəldildi)
**Nə:** `payments.amount` və digər float AZN sahələri hələ də float-dur
(yalnız PinBox-un yuvarlaqlaşdırma DÜSTURU düzəldildi, sxem dəyişmədi).
**Niyə qəbul edilib:** Prompt 6-da qəsdən təxirə salınıb — çarpaz-kəsici,
bütün ödəniş axınına toxunur, ayrıca, tələsilmədən edilməli sessiya
tələb edir.
**Nə vaxt yenidən baxılmalı:** aylıq PinBox sifariş sayı 1,000-i keçəndə
(yığılan qəpik-səviyyəli fərqlər əhəmiyyətli olmağa başlayanda), VƏ YA
launch + 3 ay (hansı ƏVVƏL baş verərsə).

---

**Son yeniləmə:** 2026-08-30, P0 remediation (audit 2 sonrası). Bu turda:
`usernames` maddəsi `get`/`list` ayrımı ilə yenidən yazıldı (`list`
bağlandı), Storage kvotası `forwardChatMedia` amplifikasiyası nəzərə
alınaraq yeniləndi, magic-byte və `reviews` maddələrinə auditin tapdığı
AYRI (və həll edilə bilən) problemlər əlavə edildi. Əvvəlki yeniləmə:
Düzəliş Prompt 10.

---

## Admin panel qaydası — səhifə-səviyyəli `Promise.all` xəta idarəetməsi tələb edir

**Bu, qəbul edilmiş risk deyil — pozulmamalı qaydadır.** Buraya
yazılıb, çünki eyni nasazlıq **üç dəfə** baş verib və hər dəfə eyni
formada.

**Qayda:** admin panelin hər səhifəsində birdən çox Firestore sorğusu
paralel işlədilirsə, **hər biri ayrıca tutulmalıdır**. Bir sorğunun
rədd edilməsi səhifəni öldürməməlidir.

**Niyə:** `Promise.all` ilk rədd edilən promise-də bütün nəticəni
atır. Server Component-də bu, 500 deməkdir — istifadəçi «This page
couldn't load» görür, digər on sorğunun nəticəsi hazır olsa belə.

**Ən çox rast gəlinən səbəb — composite indeks.** Yeni sorğu yeni
indeks tələb edirsə, indeks qurulana qədər (dəqiqələr) və ya
`firestore.indexes.json`-a əlavə edilməyibsə (həmişəlik) həmin sorğu
`FAILED_PRECONDITION` atır.

**Tarixçə:**
1. `getPendingCounts` — `payments(type,status,createdAt)` sorğusu
   **hər qorunan səhifənin layout-unu** aşağı saldı. `try/catch` ilə
   düzəldildi (`lib/data/pending-counts.ts`-dəki şərhə bax).
2. `/analytics` — `sum()` aqreqatının **cəmlənən sahəni** də indeksdə
   tələb etməsi (`payments(status,createdAt,amount)`); səhifə ilk
   yüklənişdə 500 verdi.
3. Eyni forma `/dashboard` və `/subscriptions`-da da mövcud idi —
   sınmamışdı, sadəcə hələ sınmamışdı.

**Necə tətbiq edilir:** `safeAnalyticsQuery` (`lib/data/analytics.ts`)
— sorğunu işlədir, xətanı **loglayır** və `null` qaytarır. Səhifə
sınan blokları adları ilə banner-də göstərir.

**İki incəlik:**
* Xəta **udulmamalıdır** — səssizcə boş qalan panel öz növbəsində
  başqa bir qüsurdur.
* Fallback dəyər **etiketlənməlidir**. Dashboard-dakı sıfırlar açıq
  şəkildə «həqiqi dəyər deyil» yazısı ilə gəlir: etiketsiz sıfır
  «0 moderasiya gözləyir» ilə «soruşa bilmədik»i eyniləşdirir və
  xəta səhifəsindən pisdir.

**Yeni səhifə yazan üçün:** `/analytics`-in `page.tsx`-inə bax, eyni
naxışı təkrarla.
