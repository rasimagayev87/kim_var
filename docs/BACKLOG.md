# Backlog

Bu siyahı GitHub Issues-a köçürülməlidir — hər maddə öz issue-su olmalıdır,
bu fayl yalnız MÜVƏQQƏTİ referansdır. Prioritet sırası ilə (1 = ən yüksək).
Hər maddənin tam kontekst/səbəbi [ACCEPTED_RISKS.md](ACCEPTED_RISKS.md)-da.

**2026-08-30 — P0 remediation turu.** Auditin (audit 2,
[security-audit-2-2026-08-30.md](security-audit-2-2026-08-30.md)) bütün
3 CRITICAL və 9 HIGH tapıntısı bağlandı və production-a deploy edildi
(commit `5aa5000`). Bu, aşağıdakı siyahıya iki cür təsir etdi:

* **Bağlandığı üçün çıxarılan maddələr:** köhnə #11 (`auth_screen.dart`-ın
  ümumi `catch` bloku — C-3 ilə birlikdə həll edildi, controller artıq
  rethrow edir); köhnə #8 (telefon ikiqat prefiksi), köhnə #14
  (`bannedUsers` tombstone-u), köhnə #15 (orphan `pinboxes`/`venueEvents`)
  — hamısı 2026-08-30-da bağlandı. Nömrələr yenidən istifadə
  EDİLMİR: qalan maddələr öz nömrələrini saxlayır ki, keçmiş
  müzakirələrdəki istinadlar qırılmasın.
* **Yeni əlavə edilənlər:** #12 (SVG content-type), #13 (`reviews` list),
  #14 (`bannedUsers` tombstone), #15 (hesab silinməsində qalan orphan
  sənədlər). Hər biri auditdə tapılıb, heç biri buraxılışı bloklamır.
  Siyahının SONUNA əlavə edildilər — nömrə prioritet DEYİL, yalnız
  identifikatordur (real prioritet #1 Node 22 keçidi olaraq qalır;
  yenilərindən ən təcilisi #12, ~1 saatlıq işdir).

Bağlanan və BURADA OLMAYAN, amma qeyd üçün: `posts`/`stories`/`comments`
üçün `isActiveUser()`, `deleteAccount`-un `likedPosts`/`reposts`/
`notifiedEvents` alt-kolleksiyaları və owner-scoped Storage prefiksləri
(`venue_photos/{uid}/` və s.) bu turda düzəldildi — onlar heç vaxt bu
siyahıda deyildi, auditdə tapıldı.

---

## 1. Node 20 → 22 keçidi

**Mənbə:** Prompt 10 / INFRA-44
**Təxmini iş həcmi:** ~1 gün (versiya dəyişikliyi özü kiçikdir, çoxu vaxt
`functions/`-un bütün Cloud Function-larının Node 22-də reqressiya testinə
gedir — xüsusilə `@apple/app-store-server-library`/`googleapis` kimi
üçüncü-tərəf paketlərin uyğunluğu yoxlanılmalıdır).
**Niyə #1:** runtime artıq texniki EOL-dur (Maintenance LTS 2026 aprelində
bitib) — təhlükəsizlik yaması almayan runtime-da istehsalatda qalmaq
davam etdikcə risk artır.

## 2. Server-side parol minimum 8 simvola qaldırılması

**Mənbə:** Prompt 10 / AUTH-8a
**Təxmini iş həcmi:** ~2-3 saat (client artıq 8 simvol tələb edir, YALNIZ
server-side — `registerWithEmailPassword` çağırışından ƏVVƏL, ya da
Cloud Function-da bir yoxlama — əlavə olunmalıdır; Firebase Auth-un öz
console ayarlarında minimum parol uzunluğu konfiqurasiya oluna bilərmi
yoxlanılmalıdır, mümkündürsə bu, kod dəyişikliyi belə tələb etməyəcək).
**Niyə #2:** çox ucuz, real (bəlkə minimal) təhlükəsizlik faydası —
sırf ucuzluğuna görə tez edilməlidir.

## 3. Zəng sənədlərinin (`calls`) periodik təmizlənməsi

**Mənbə:** Prompt 10 / B4 (RT-19)
**Təxmini iş həcmi:** ~2-3 saat (yeni `onSchedule` funksiyası,
`expireLapsedPremium`-un EYNİ naxışı — N gündən köhnə `calls` sənədlərini
+ `offerCandidates`/`answerCandidates` alt-kolleksiyalarını sil; rules-un
`allow delete: if false`-unu Admin SDK-nın bypass etdiyini xatırla).
**Niyə #3:** ucuz, aydın, təxirə salınması üçün əsl səbəb yoxdur —
sadəcə bugünkü sessiyanın əhatəsinə düşmədi.

## 4. ProGuard/R8 aktivləşdirilməsi (Android)

**Mənbə:** Prompt 10 / INFRA-34/36 (C1a)
**Təxmini iş həcmi:** ~1 gün (bayrağın özü 2 sətir, amma HƏR bir native
plugin-in (Firebase, WebRTC, in_app_purchase və s.) minifikasiyadan sonra
da işlədiyini yoxlayan tam manual reqressiya testi tələb olunur — bütün
əsas axınlar: giriş, çat, zəng, ödəniş, IAP).
**Niyə #4:** nisbətən ucuz, real tərs-mühəndislik müdafiəsi verir.

## 5. `reviews` kolleksiyasının anonimləşdirmə miqrasiyası

**Mənbə:** Prompt 10 / D4 (Prompt 11-dən təxirə salınıb)
**Təxmini iş həcmi:** ~3-5 gün (memarlıq dəyişikliyi: `{venueId}_{userId}`
sənəd ID sxemindən təsadüfi ID-yə keçid, "bir istifadəçi — bir şərh"
invariantının rules-level composite-key trick-i əvəzinə Cloud Function-da
transaction-based unikallıq yoxlaması ilə əvəzlənməsi, mövcud bütün
`reviews` sənədlərinin miqrasiya skripti, hər review-a istinad edən bütün
client sorğularının (venue profili, "mənim rəyim" və s.) yenidən
qurulması).
**Niyə #5:** yüksək təsir (GDPR-tipli "silinmə hüququ" tələbi olan
bazarlara giriş bundan asılıdır), amma böyük, ayrıca sessiya tələb edir.

## 6. PAY-28 — tam float→qəpik (integer cents) miqrasiyası

**Mənbə:** Prompt 6 / PAY-28 (təxirə salınıb), Prompt 10 / E1 (yalnız
PinBox düsturu düzəldildi, tam miqrasiya hələ də açıqdır)
**Təxmini iş həcmi:** ~3-5 gün (`payments.amount` və bütün digər float AZN
sahələrinin — haqq cədvəlləri, `venuePayouts`, s. — `amountCents`-ə
keçidi; köhnə sənədlər üçün miqrasiya skripti; admin panelin göstərmə
məntiqinin yenilənməsi; bütün Epoint-ə göndərilən `toFixed(2)` çağırışlarının
yenidən yoxlanması).
**Niyə #6:** çarpaz-kəsici, bütün ödəniş axınına toxunur — səhv edilərsə
real pul itkisi riski var, buna görə tələsilmədən, ayrıca edilməlidir.

## 7. Root/jailbreak aşkarlanması + TLS sertifikat pinning

**Mənbə:** Prompt 10 / INFRA-35/36 (C1b)
**Təxmini iş həcmi:** ~2-3 gün (root-detection paketinin (məs.
`freerasp`) inteqrasiyası + cihaz-üzrə (root edilmiş/jailbreak-lənmiş test
cihazı) doğrulama; TLS pinning üçün Firebase-in öz sertifikat
rotasiyasına uyğun pin-yeniləmə strategiyası — səhv pin=tətbiq tamamilə
işləməz qalır, ehtiyatla edilməlidir).
**Niyə #7:** orta təsir, orta-yüksək iş həcmi, mağaza tərəfindən tələb
olunmur.

## 9. Real MFA (TOTP)

**Mənbə:** Prompt 10 / AUTH-8b
**Təxmini iş həcmi:** ~1-2 həftə (TOTP secret generasiyası/saxlanması,
QR-kod ilə enrollment UI-si, doğrulama axını sign-in-ə inteqrasiyası,
"backup kodlar" axını, mövcud dekorativ `twoFactorEnabled` bayrağının
əvəzlənməsi ya da silinməsi).
**Niyə #8:** ən böyük iş həcmi, hazırkı miqyasda ən aşağı təcililik —
istifadəçi bazası böyüdükcə prioritetləşdirilməlidir.

## 10. `resource.data` mövcudluq yoxlaması olmadan (3 aşağı-ehtimallı yer)

**Mənbə:** Post-launch QA — Qeydiyyat axını sınağı zamanı tapılan
`resource == null` boşluğunun tam siyahısı (bax `firestore.rules`-un
`users/{userId}`, `follows/{followId}`, `calls/{callId}`,
`savedCards/{cardId}`, `stories/{storyId}`, `posts/{postId}` — bunların
hamısı EYNİ sessiyada `resource == null ||` ilə düzəldildi). Aşağıdakı
3 yer QƏSDƏN TOXUNULMADI:
- `payments/{paymentId}` — `allow read` (sətir ~1039)
- `identityVerifications/{requestId}` — `allow read` (sətir ~1067)
- `pinboxOrders/{orderId}` — `allow read` (sətir ~1355, üstəlik
  `allow write: if false` tam bağlıdır)
**Təxmini iş həcmi:** ~1 saat (3 yerdə eyni 1-sətirlik `resource ==
null ||` əlavəsi + hər biri üçün "mövcud olmayan sənədin oxunması
icazəlidir" testi, `firestore-postlaunch-qa.test.ts`-in eyni
nümunəsi ilə).
**Niyə aşağı prioritet:** bu 3 sənəd növü PRAKTIKİ olaraq HEÇ VAXT
silinmir (ID-lər server-generated, silmə yolu yoxdur və ya
`allow write: if false` tamdır) — deməli `resource == null` halı real
istifadədə demək olar ki, heç vaxt tetiklənmir. Launch-dan əvvəl
düzəltmək əlavə risk daşımadan mümkün olan ucuz təmizlikdir, amma
bloklayıcı deyil.

## 11. iOS Crashlytics — dSYM yükləmə addımı yoxdur

**Mənbə:** AAB build hazırlığı zamanı QA — `firebase_crashlytics: ^4.1.5`
`pubspec.yaml`-da mövcuddur, `DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym"`
release konfiqurasiyasında düzgün ayarlanıb (dSYM-lər GENERASİYA OLUNUR),
AMMA `ios/Runner.xcodeproj/project.pbxproj`-da onları Firebase-ə YÜKLƏYƏN
`FirebaseCrashlytics/run` build phase script-i YOXDUR.
**Təsir:** iOS-da baş verən real crash-lar Crashlytics konsolunda RAW
yaddaş ünvanları kimi görünəcək (funksiya/sətir adı olmadan) — crash-ları
diaqnoz etmək demək olar ki, mümkünsüz olacaq, məsələ üzə çıxana qədər.
**Təxmini iş həcmi:** ~1 saat (Xcode-da yeni "Run Script" build phase
əlavə et: `"${PODS_ROOT}/FirebaseCrashlytics/run"`, `GoogleService-
Info.plist`-i Input Files-a əlavə et — rəsmi Firebase sənədlərindəki
addımlar; alternativ: hər buraxılışdan sonra əl ilə `firebase
crashlytics:symbols:upload` CLI əmri).
**Niyə bloklamır:** tətbiqin işə düşməsinə, build-ə və ya App Store
təsdiqinə HEÇ bir təsiri yoxdur — yalnız GƏLƏCƏK crash-ların
diaqnostikasına təsir edir. İlk real production crash-dan ƏVVƏL
düzəldilməlidir ki, o crash-ın özü faydasız məlumatla itməsin.

## 12. Storage `Content-Type` allowlist — SVG qəbul edilir

**Mənbə:** Audit 2 / M-10
**Nə:** `storage.rules`-un 13 yerində `request.resource.contentType
.matches('image/.*')` istifadə olunur. Bu naxış `image/svg+xml`-i də
qəbul edir; Firebase Storage faylı saxlanılan Content-Type ilə `inline`
təqdim etdiyi üçün bu, `firebasestorage.googleapis.com` mənşəyində
JavaScript icra edən sənəd deməkdir.
**Niyə ACCEPTED_RISKS-dəki "magic-byte" maddəsindən FƏRQLİDİR:** o maddə
faylın BAYTLARININ yoxlanmasından bəhs edir və doğrudan da yalnız bir
Storage trigger-i ilə mümkündür. Bu isə ELAN EDİLƏN tipin allowlist-idir
və Storage Rules-da tam həll olunur — qəbul edilmiş risk deyil, sadəcə
edilməmiş iş.
**Təxmini iş həcmi:** ~1 saat. `matches('image/.*')` →
`in ['image/jpeg','image/png','image/webp','image/heic']`, video üçün
`['video/mp4','video/quicktime']`, audio üçün `['audio/mpeg','audio/m4a',
'audio/aac']`. Client yalnız kamera/qalereya şəkilləri yüklədiyi üçün heç
bir legitim axın pozulmur (`storage-prompt3.test.ts`-də content-type testi
artıq var, genişləndirilməlidir).

## 13. `reviews` üzərində `list` bağlanması

**Mənbə:** Audit 2 / M-7
**Nə:** `reviews` `allow read: if request.auth != null` — yəni `list` də
açıqdır. Sənəd id-si `{venueId}_{userId}`, rəyin mövcudluğu isə
`hasVerifiedVisit` sayəsində FİZİKİ ziyarətin sübutudur. Nəticədə istənilən
daxil olmuş istifadəçi bütün "kim hansı məkanda olub" qrafını çəkə bilər.
**Niyə #5-dən ayrıdır:** #5 (anonimləşdirmə miqrasiyası) memarlıq
dəyişikliyidir və 3-5 gün çəkir; bu isə ondan asılı deyil və indi
bağlana bilər.
**Təxmini iş həcmi:** ~3-4 saat. `allow get: if request.auth != null;
allow list: if false;` + məkan profilinin rəy siyahısı üçün
`listVenueReviews` callable (`searchUsersByName`-in eyni naxışı).
**Prioritet səbəbi:** məxfilik təsiri realdır, amma istismarı üçün daxil
olmuş hesab lazımdır və hazırda `reviews` praktiki olaraq boşdur.

## 16. Admin paneldə qalan üç əskik səhifə

**Mənbə:** 5 rollu RBAC işi (2026-08-30), 2026-08-30-da yeniləndi.

**Bağlandı:** səkkiz maddədən üçü quruldu — **`/roles`** (icazə
matrisi, `manageAdmins`), **`/analytics`** (`viewAnalytics` +
blok-səviyyəli `viewEngagementMetrics`/`viewRevenue`),
**`/subscriptions`** (`viewSubscriptions`, məbləğ `viewRevenue` ilə).
Hər üçü oxu-yalnızdır. Qalan beş maddədən ikisi (`viewFinancials`
hesabatları, export) hələ də ekran gözləyir; üçü aşağıda, hər biri
öz səbəbi ilə.

### Qurulmayan üç səhifə

**`/map` — Xəritə. Təhlükəsizlik qərarı tələb edir.**
Admin xəritəsi istifadəçi koordinatlarını göstərərsə, Düzəliş
Prompt 4-də (`lat`/`lng` public `users` sənədindən `private/data`-ya
köçürüldü) və P0 / H-1-də (məsafə 100 m-ə kvantlaşdırıldı, sürət
yoxlaması əlavə edildi) bağladığımız izləmə səthini **yenidən açar** —
bu dəfə admin panelin öz sessiyası vasitəsilə. Üstəlik `viewUsers`
icazəsi altında olardı, yəni `moderator` da görərdi.
**Şərt:** qurulacaqsa yalnız **məkanları** göstərsin, istifadəçiləri
yox. İstifadəçi koordinatı istənilirsə, əvvəlcə ayrıca qərar lazımdır:
kim, hansı halda, hansı dəqiqliklə və hansı audit qeydi ilə.

**`/settings` — Tənzimləmələr. Validasiya və audit dizaynı tələb edir.**
`config/*` sənədlərinə yazacaq: `businessOffer` (abunə müqaviləsinin
versiyası və URL-i — `submitVenue` ona güvənir), `iapTesters`
(Sandbox qəbzi ilə pulsuz VIP alan uid-lər), `waitlistCategories`,
`eventCategories`, `legal`. Səhv dəyər tətbiqi sındırır: məsələn
`legal.documentUrl` boş qalsa razılıq dialoqu açılmır, `iapTesters`-ə
səhv uid əlavə edilsə həmin hesab pulsuz VIP alır.
**Şərt:** sahə-səviyyəli validasiya, dəyişikliyin `moderationLogs`-a
yazılması, və kim dəyişdi/nə vaxt/köhnə dəyər nə idi. İcazə artıq
təyin edilib: `manageSystemSettings` (yalnız admin).

**`/ai-center` — AI Mərkəzi. Əhatəsi müəyyən deyil.**
Nə edəcəyi qərarlaşmayıb — moderasiya köməkçisi, məzmun xülasəsi,
yoxsa başqa şey. Nə etdiyi bilinməyən səhifənin icazəsini seçmək də
mümkün deyil. **Qurulmasın** ta ki əhatə yazılana qədər.

### Qalan iki ekran

`viewFinancials` (maliyyə hesabatları) və `exportData`/
`exportFinancialData` — icazələri var, ekranları yoxdur.
`UNIMPLEMENTED_PERMISSIONS` onları elan edir.

**Təxmini iş həcmi:** `/settings` ~1 gün · `/map` (yalnız məkanlar)
~4 saat · `/ai-center` — əhatə yazılana qədər qiymətləndirilə bilməz.

## 17. Vercel layihəsini GitHub-a bağlamaq (admin panel deploy-u)

**Mənbə:** 2026-08-30, admin panel deploy hadisəsi
**Nə:** `admin.peakpin.app` Vercel-dədir (`peakpin/admin-panel`), amma
layihə **heç bir git repo-suna bağlı deyil**. Bütün deploy-lar əl ilə,
bir developer maşınından `vercel --prod` ilə edilir — `vercel ls`
göstərir ki, son 12 production deploy-un hamısı bir istifadəçi adı
altındadır, git bot deyil.

**Niyə bu, sadəcə rahatlıq məsələsi deyil.** Bu gün konkret zərər verdi:

1. `git push` admin paneli deploy etmədiyi üçün, təhlükəsizlik
   düzəlişləri (H-7 moderator refund, H-8 açıq `/api/health`, C-2
   `emergencyToken`) commit edilib push edilsə də **canlıya çıxmadı**.
2. Layihədə istifadə edilməyən Firebase App Hosting backend-i
   (`kim-var-admin`) var və o, işləyən admin panelə oxşayır. Deploy
   yoxlaması səhvən onun URL-ində aparıldı, gözlənilən 404 alındı və
   düzəliş "canlıdır" kimi qeyd edildi — halbuki production hələ də
   `{"ok":true,"projectId":...}` qaytarırdı. Səhv bir neçə saat
   aşkarlanmadan qaldı.

Yəni cari qurulumda "commit edildi + push edildi" ilə "canlıdır"
arasında heç bir avtomatik əlaqə yoxdur, və bunu yoxlamağın yolu
əl ilə düzgün host-u curl etməkdir.

**Nə edilməli:**
- Vercel Dashboard → `admin-panel` → Settings → Git → `rasimagayev87/kim_var`
  repo-suna bağla, Root Directory `admin-panel`, production branch-i
  seç (hazırda iş `full-local-version`-dadır — `master` 26 gün köhnədir,
  bax #18 kimi ayrıca qərar).
- Bağlandıqdan sonra `README.md`-nin "Deploy (Vercel)" bölməsi və
  `DEPLOY_RUNBOOK.md`-nin 4-cü bölməsi yenilənməlidir — orada hazırda
  "git push deploy ETMİR" yazılıb.
- İstifadə edilməyən `kim-var-admin` App Hosting backend-i silinsin
  (`firebase apphosting:backends:delete kim-var-admin`) və
  `admin-panel/apphosting.yaml` faylı da onunla birlikdə. Backend
  mövcud olduğu müddətcə səhv host-a baxmaq riski qalır.

**Təxmini iş həcmi:** ~30 dəqiqə (Dashboard-da bağlama + bir test
deploy + sənəd yeniləməsi). Backend silinməsi ayrıca ~10 dəqiqə.

**Niyə yüksək prioritet:** ucuzdur, və bağlamadığımız müddətcə hər
admin panel dəyişikliyi "deploy edildi" zənn edilib canlıya çıxmama
riski daşıyır — bu risk artıq bir dəfə gerçəkləşib.

## 18. `phoneNumbers/{phone}` kolleksiyası ölüdür

**Mənbə:** BACKLOG #8 araşdırması (2026-08-30)
**Nə:** Kolleksiyaya **heç bir yerdə yazılmır**. Yeganə toxunan kod
`releasePhoneNumberReservation`-dır (həm `functions/src/index.ts`, həm
`admin-panel/src/lib/user-account-deletion.ts`) və o, yalnız oxuyub
silir. Üstəlik açar kimi `authUser.phoneNumber`-i (Firebase Auth
qeydini) istifadə edir — telefon/OTP girişi isə tətbiqdən çıxarılıb
(bax `AuthRepository`-nin öz şərhi), yəni həmin sahə həmişə `null`-dur
və funksiya hər dəfə no-op edir.

**Nəticə:** "bir nömrə — bir hesab" unikallıq mexanizmi mövcud kimi
görünür, amma **işləmir**. İstifadəçinin nömrəsi
`users/{uid}/private/data.phoneNumber`-dədir və orada heç bir unikallıq
yoxlaması yoxdur — eyni nömrə istənilən sayda hesabda ola bilər.

**Nə edilməli — iki yoldan biri:**
- **(a) Sənədləşdir və təmizlə:** unikallıq tələb olunmursa,
  `releasePhoneNumberReservation`-ı və `phoneNumbers` istinadlarını hər
  iki kod bazasından sil, `firestore.rules`-a kolleksiyanın istifadə
  edilmədiyini yazan şərh əlavə et.
- **(b) Həqiqətən tət et:** unikallıq lazımdırsa,
  `completeOnboarding`-də normalizə edilmiş nömrə üçün
  `phoneNumbers/{e164}` sənədini tranzaksiyada yarat (`usernames`
  naxışının eynisi) və hesab silinəndə burax.

**Qərar məhsul sualıdır:** eyni telefon nömrəsi ilə birdən çox hesab
olmasına icazə verilirmi? Cavab bilinmədən kodu silmək də, tətbiq etmək
də səhv ola bilər.

**Təxmini iş həcmi:** (a) ~1 saat · (b) ~3-4 saat + miqrasiya.

## 19. Məkan statusunun asılı axınlarda yoxlanılması — qalan hallar

**Mənbə:** 2026-08-30 sweep (BACKLOG #15 ilə birlikdə)
**Nə:** Məkandan asılı axınların hamısı nəzərdən keçirildi. Aydın
hallar həmin turda bağlandı (`reservePinBoxOrder`, `joinWaitlist`,
`generatePinBoxQrToken`, `offers/*/redemptions`, `venues/*/likes`).
Aşağıdakı üçü QƏSDƏN toxunulmadı, çünki `status == 'approved'` tələbi
legitim iş axınını sındıra bilər və bu, məhsul qərarıdır:

| Axın | Sual |
|---|---|
| `submitOffer` | Sahib məkanı `pending` ikən təklif hazırlaya bilməlidirmi? Hazırda bilir. Tələb qoyulsa, moderasiya gözləyən sahib heç nə hazırlaya bilməz |
| `createVenuePremiumCheckout` | `pending` məkana premium almaq — sahib təsdiqi gözləyərkən ödəyə bilər. `rejected` məkana ödəniş isə puldur itkisidir |
| `createBoostCheckout` | Təklifin öz statusu da yoxlanılmır — `rejected` təklifi boost etmək pul itkisidir |

**Qəsdən EDİLMƏYƏN:** `redeemPinBoxOrder`-ə status yoxlaması. Abunə
borcuna görə dayandırılmış məkanda təhvili bloklamaq **alıcını**
cəzalandırardı — sifariş artıq ödənilib.

**Təxmini iş həcmi:** ~2 saat (qərar veriləndən sonra).

## 20. ~~Kəşf namizədləri ban statusunu yoxlamır~~ — BAĞLANDI (2026-08-30)

Hər iki hissə həmin gün bağlandı:

* **Ban görünürlüyü:** `findNearbyUsers` və `getDiscoverCandidates`
  namizəd süzgəclərinə `c.data.banned !== true` əlavə edildi.
  `bannedUsers` doğruluq mənbəyi olaraq qalır;
  `users/{uid}/private/data.banned` yalnız oxu tərəfi üçün güzgüdür
  (`setUserBanned` hər ikisini bir batch-də yazır, `serverOnlyFields()`
  client-in silməsinin qarşısını alır). Alternativ — namizəd başına
  `bannedUsers` oxumaq — tətbiqin ən bahalı endpoint-inə +50% oxu
  əlavə edərdi (world rejimi: 1000 → 1500 oxu).
* **Bayat `online: true`:** `getDiscoverCandidates` artıq
  `isRecentlyOnlineServer`-i tətbiq edir, `findNearbyUsers` kimi.

Backfill skripti yazıldı (`admin-panel/scripts/backfill-banned-mirror.ts`),
**icra edilmədi** — `bannedUsers` hazırda **boşdur** (0 tombstone), yəni
backfill ediləcək heç nə yoxdur. Skript gələcək üçün qalır.


## 21. `changeAdminRole`/`removeAdmin` qorumaları testlə örtülmür

**Mənbə:** 5 rollu RBAC təhvili (2026-08-30)
**Nə:** Qorumaların özü **kodda mövcuddur** və işləyir:

| Qoruma | Yer |
|---|---|
| Tanınmayan rol rədd edilir | `admins.ts:55` — `isAdminRole` |
| Öz rolunu dəyişmək/özünü silmək rədd edilir | `admins.ts:142`, `:185` — `cannot-change-self` |
| Sonuncu admin rolundan salına bilməz | `admins.ts:152` — `remainingAdminCount` |
| Sonuncu admin silinə bilməz | `admins.ts:190` — eyni |

Testlə örtülməyən **yalnız bunlardır**, çünki hər ikisi Firebase Admin
SDK-ya bağlı Server Action-dır və `tests/rules` yalnız saf funksiyaları
və Firestore/Storage qaydalarını işlədir. Admin SDK mock-u yeni test
infrastrukturu deməkdir — qərar qəsdən təxirə salınıb.

**Nə itiririk:** bu dörd şərtdən biri gələcək redaktədə səssizcə
düşsə, heç nə xəbər verməz. Ən pisi «sonuncu admin» qorumasıdır —
düşsə, paneldə admin rolu olan heç kim qalmaya bilər və bunu geri
qaytarmağın yeganə yolu Firebase Console-dan custom claim-i əl ilə
yazmaqdır.

**İki yol:**
- **(a)** Firebase Admin mock-u ilə Server Action testləri (~1 saat +
  yeni infrastruktur).
- **(b)** Qərar məntiqini saf funksiyalara çıxarmaq (`geo.ts`,
  `phone.ts`, `chat-media.ts` naxışı) və yalnız onları test etmək —
  `canChangeRole(actorUid, targetUid, nextRole, remainingAdmins)`
  formasında. Ucuzdur, infrastruktur tələb etmir, dörd şərtin
  hamısını örtür. **Tövsiyə olunan.**

**Təxmini iş həcmi:** (a) ~1 saat · (b) ~40 dəqiqə.

## 22. `subscription_overdue` admin paneldə "approved" kimi görünür

**Mənbə:** `/subscriptions` səhifəsinin qurulması (2026-08-30)
**Nə:** `renewVenueSubscriptions` (`functions/src/index.ts:5403`) ödəniş
gecikəndə məkanı `status: "subscription_overdue"` edir və belə məkan
kəşfdə görünmür. Admin panelin `VenueStatus` birləşməsində
(`lib/data/venues.ts:55`) bu dəyər **yoxdur**, `parseStatus` isə
tanımadığı hər dəyəri **`"approved"`-a** çevirir.

**Nəticə:** `/venues` səhifəsində abunə borcuna görə dayandırılmış
məkan **təsdiqlənmiş** kimi görünür. Bu, admin roster-indəki
«naməlum rol» qüsuru ilə eyni sinifdir — köhnəlmiş allowlist, üstəlik
xoşagələn defolta yığılma — amma nəticəsi daha pisdir, çünki orada
`null` göstərilirdi, burada isə yanlış status göstərilir.

**Bu turda düzəldilmədi**, çünki `VenueStatus` birləşməsini
genişləndirmək `/venues` səhifəsinin filtrlərinə, `setVenueStatus`
server action-una və `StatusBadge` komponentinə toxunur — üç
səhifənin əhatəsindən kənardır. `/subscriptions` öz status
birləşməsini ayrıca elan edir, məhz bu çevirməni miras almamaq üçün.

**Düzəliş:** `VenueStatus`-a `"subscription_overdue"` əlavə etmək,
`parseStatus`-un defoltunu `"approved"`-dan çıxarmaq (tanınmayan dəyər
üçün `null` və ya açıq "naməlum"), `/venues` filtrinə əlavə etmək.

**Təxmini iş həcmi:** ~1 saat + testlər.
