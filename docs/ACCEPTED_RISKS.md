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
**Nə:** `firestore.rules`-un `usernames/{usernameId}` `allow get: if true` —
imzalanmamış (heç bir hesaba daxil olmamış) istifadəçi belə istənilən
username-in mövcudluğunu yoxlaya bilər.
**Niyə qəbul edilib:** `deep_link_handler.dart`-ın `_openProfileByUsername`-i
paylaşılan `peakpin.app/u/{username}` linklərini imzasız istifadəçi üçün də
açmalıdır — `request.auth != null` tələbi bu axını sakitcə sındırardı (link
açılmır, xəta da göstərilmir). Sənədin özü `{uid, createdAt}`-dan başqa heç
nə daşımır.
**Nə vaxt yenidən baxılmalı:** aylıq aktiv istifadəçi sayı (MAU) 50,000-i
keçəndə (bu miqyasda username-enumeration iqtisadi cəhətdən cəlbedici olur)
— o zamana qədər Cloud Logging-də `usernames` kolleksiyasının `get`
tezliyini izləməyə başlamaq lazımdır (hazırda izlənmir, bu ayrıca kiçik
tapşırıqdır).

### Banlanmış istifadəçi `pinboxes`/`venueEvents`/`supportMessages` yarada bilir
**Nə:** `isActiveUser()` yoxlaması bu 3 kolleksiyanın `create` qaydasına
tətbiq olunmayıb.

> **2026-08-30 yenilənməsi (P0 / C-3):** `posts`, `stories` və post
> `comments` bu siyahıdan ÇIXARILDI və artıq `isActiveUser()` ilə
> qorunur. Səbəb ban deyil: həmin yoxlama eyni zamanda `users/{uid}`
> sənədi ÜMUMİYYƏTLƏ olmayan hesabları da bloklayır — yəni
> `completeOnboarding`-in 18+ qapısından keçməmiş hesabları. Bu, xərc
> mülahizəsi ilə tarazlanan moderasiya məsələsi deyil, uşaq
> təhlükəsizliyi və mağaza siyasəti məsələsidir. `supportMessages`
> qəsdən qorunmamış qalır ki, məhz bu vəziyyətdə ilişmiş istifadəçi
> dəstəyə yaza bilsin.
**Niyə qəbul edilib:** xərc qərarı — hər yazı yolunda əlavə bir `get()`
sorğusu (banlanma statusunu yoxlamaq üçün) hər YAZI əməliyyatının qiymətini
artırır; banlanmış istifadəçinin YENİ məzmun yaratması nadir hadisədir (adətən
ban SONRA, mövcud məzmuna görə tətbiq olunur), moderasiya axını (post/venue/
pinbox review) bunu artıq real vaxtda tutur.
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
**Nə vaxt yenidən baxılmalı:** Firebase Storage-un aylıq faktura xərci
50 AZN-i keçəndə (Firebase Console → Usage and billing-dən yoxlanılır).

### Magic-byte MIME yoxlaması yoxdur
**Nə:** yüklənən şəkil/video faylların `Content-Type`-ı client-in bəyan
etdiyi dəyərə görə qəbul edilir, faylın öz baytlarının HƏQİQƏTƏN həmin
format olduğu yoxlanılmır.
**Niyə qəbul edilib:** bu yoxlama YALNIZ bir Cloud Storage trigger-lə
(faylın özünü oxuyub baytları təhlil edən) mümkündür — Storage Rules
faylın MƏZMUNUNA giriş əldə edə bilmir, yalnız metadata-ya.
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

**Son yeniləmə:** Düzəliş Prompt 10 (əlavə tur — bütün "nə vaxt yenidən
baxılmalı" şərtləri konkretləşdirildi, BACKLOG.md ayrıldı).
