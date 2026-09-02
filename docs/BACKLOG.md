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

## 22. ~~`subscription_overdue` admin paneldə "approved" kimi görünür~~ — BAĞLANDI (2026-08-30)

**Nə idi:** `parseStatus` (`lib/data/venues.ts`) tanımadığı hər dəyəri
`"approved"`-a çevirirdi. `renewVenueSubscriptions` isə ödəniş
gecikəndə məkanı `subscription_overdue` edir və belə məkan tətbiqdə
görünmür — yəni borclu, dayandırılmış məkan admin paneldə **aktiv**
görünürdü. `awaiting_payment` eyni funksiyaya elə həmin gün əlavə
edilmişdi; bu isə unudulmuşdu.

**Düzəliş:**
* Status lüğəti asılılıqsız `lib/venue-status.ts` modulunda —
  `lib/data/venues.ts` `server-only`-dir, yəni client komponentlər və
  testlər ondan import edə bilmir (`auth/roles.ts` ilə eyni vəziyyət,
  eyni həll).
* `parseStatus` və `/venues` filtri artıq `isVenueStatus`-dan törəyir
  — ikinci siyahı yoxdur ki, unudulsun.
* «Abunə gecikib» etiketi, `destructive` variantla: belə məkan
  tətbiqdə görünmür, ona görə neytral rəngdə olmamalıdır.

**Bir addım daha — tip ikiyə ayrıldı.** `VenueStatus` məkanın saxlaya
biləcəyi hər statusdur; `VenueModerationStatus` isə `setVenueStatus`-un
**yaza biləcəyi** altçoxluqdur (`subscription_overdue` və
`awaiting_payment` daxil deyil). Sadəcə birləşməyə əlavə etsəydim,
moderasiya UI-ı həmin statusu əl ilə yaza bilərdi — yəni admin məkanı
borclu edə, və ya real borcu ödəniş qeydi olmadan «silə» bilərdi.
Ayrım tətbiq edilən kimi `tsc` `venue-status-actions.tsx`-in geniş
tipdən istifadə etdiyini dərhal tutdu.

**Test:** `tests/rules/venue-status.test.ts` — 5 test, göstəriş
birləşməsi və yazıla bilən altçoxluq ayrıca yoxlanılır.

## 23. Canlı feed poll xərci — istifadəçi sayı artanda yenidən qiymətləndirilməli

**Mənbə:** «Boş yer» yenilənmə sürətinin 30 saniyəyə endirilməsi
(2026-08-31)
**Nə:** Canlı tab qəsdən **polling** işlədir, realtime dinləyici yox —
əks halda istifadəçi başına beşdən çox eyni vaxtlı `.snapshots()`
axını lazım olardı. İndi iki dövr var:

| Dövr | Nə gətirir | Tezlik |
|---|---|---|
| `liveFeedVenueSnapshotPollInterval` | 1 `venues` geo-sorğusu → boş yer + check-in sayı | **30s** |
| `liveFeedPollInterval` | məkanlar + tədbirlər + təkliflər + PinBox + izlənən məkanlar | 60s |

**Xərc düsturu.** Açıq tab başına dəqiqədə təxminən:

```
2N  (30s-lik məkan sorğusu)  +  N + E + O + P + F  (60s-lik dövr)
```

`N` = radius daxilindəki təsdiqlənmiş məkanlar, `E`/`O`/`P` = həmin
radiusdakı tədbir/təklif/PinBox sənədləri, `F` = izlənən məkanlar.

**Miqyas ssenarisi (2026-08-31-də hesablanıb):**

| Vəziyyət | N | Eyni vaxtlı baxan | Oxu / saat |
|---|---|---|---|
| Bu gün | 1 | 1 | ~180 |
| Orta | 30 | 20 | ~110 min |
| **Sıx** | **100** | **100** | **~1.8 milyon** |

Sonuncu ssenaridə **yalnız Canlı tabı** aylıq onlarla milyon oxu
deməkdir. Firestore-un oxu qiyməti ilə bu, artıq nəzərə çarpan
məbləğdir — və bu rəqəm istifadəçi sayı ilə **xətti**, məkan sıxlığı
ilə də **xətti** artır, yəni ikisi birlikdə **kvadratik** effekt verir.

**Hədd — nə vaxt yenidən baxılmalı:**
* **MAU 5000-i keçəndə**, VƏ YA
* bir şəhərdə radius daxilində orta `N` 50-ni keçəndə, VƏ YA
* Firestore aylıq oxu xərci ümumi infrastruktur xərcinin 20%-ni
  keçəndə — hansı əvvəl gəlsə.

**Baxarkən nəzərdən keçiriləcək variantlar:**
1. **Serverdə aqreqat sənəd** — planlaşdırılmış funksiya hər 30
   saniyədə geohash blokları üzrə `liveFeed/{geohashPrefix}` sənədi
   yazsın; client bir sənəd oxusun. Oxu xərci istifadəçi sayından
   asılı olmayan sabitə çevrilir.
2. **Görünürlüyə görə dayandırma** — artıq var (`stop()`), amma
   yalnız tab dəyişəndə; ekran sönəndə də dayandırıla bilər.
3. **Adaptiv tezlik** — hərəkətsiz istifadəçidə interval uzansın.
4. **30s-i geri 60s-ə qaytarmaq** — ən sadəsi, amma «boş yer»in
   dəyərini azaldır (bax həmin sabitin öz şərhi).

**Təxmini iş həcmi:** (1) ~1 gün · (2) ~2 saat · (3) ~3 saat

## 24. `venues/{id}.activeCheckinCount` köhnə sahəsinin silinməsi

**Mənbə:** check-in sayğacının ayrılması (2026-08-31)
**Nə:** Xam check-in sayı `venues/{id}/private/counters`-ə köçdü, məkan
sənədində `visibleCheckinCount` (həddlənmiş) qaldı. Köhnə
`activeCheckinCount` sahəsi **qəsdən silinmədi**: mağazadakı build hələ
onu oxuyur, silinsə həmin istifadəçilərdə sayğac yox olardı. İndi isə
sadəcə dayanmış rəqəm göstərir.

**Nə vaxt:** yeni AAB mağazada yayıldıqdan və köhnə versiyaların payı
əhəmiyyətsizləşdikdən sonra.

**Nə edilməli:** `venues` üzərində bir keçid, `activeCheckinCount`
sahəsini `FieldValue.delete()` ilə silmək. Skript
`migrate-checkin-counters.ts` naxışı ilə yazıla bilər.

**Təxmini iş həcmi:** ~30 dəqiqə.

## 25. ~~`computeVenueAudienceHistory` yanlış sənəddən oxuyur~~ — BAĞLANDI (2026-08-31)

**Mənbə:** Audit 4 remediasiyası, 7-ci bəndi yazarkən aşkarlandı.

**Nə idi.** Funksiya namizədləri **publik** `users` sənədlərindən
yığırdı, halbuki `computeAudienceCount`-un istifadə etdiyi HƏR sahə —
`lat`, `lng`, `ghostModeEnabled`, `visibilityRadiusMode`/`Km` —
Düzəliş Prompt 4 / K-1-də `users/{uid}/private/data`-ya köçmüşdü. Dördü
də `undefined` oxunurdu.

İki ayrı nəticə, biri görünən, biri görünməyən:

* **`distance` rejimi (hər üç rejimdən defolt olanı) daim 0 sayırdı.**
  «Ətrafınızda» kartı **heç vaxt göstərilməyib**, pik-saat push-u
  **heç vaxt getməyib**. Yəni sayğac ayrımının (`VENUE_OCCUPANCY.md`)
  görünən yarısı ilk gündən işləmirdi.
* **`country`/`world` rejimləri işləyirdi, amma Ghost Mode süzgəci
  no-op idi** — o da publik sənəddəki `ghostModeEnabled`-i oxuyurdu.
  Say düzgün GÖRÜNDÜYÜ üçün bu yarısı nəzərə çarpmırdı. Sənəd Ghost
  Mode-un «hər üç rejimdə» çıxarıldığını yazırdı; faktiki olaraq heç
  birində çıxarılmırdı.

**Sinif:** P0 / H-9 ilə eyni (sahə köçdü, oxuyucu qalmadı), **əks
işarəli**. H-9 fail-open idi — `withPrivateData` iki sənədi
birləşdirdiyi üçün publikdəki köhnə `birthDate` canlı fallback olurdu.
Bu isə fail-closed idi: mövqe yoxdursa say 0-dır, yəni verilə biləcək
ən təhlükəsiz cavab. Ona görə bu, sızma yox, **işə düşməmiş funksiya**
idi və launch-ı bloklamırdı.

### Xərc — əvvəlki qeyddəki çərçivə səhv idi

Bu maddənin ilk versiyası düzəlişin xərcini («10 000 aktivdə ayda ~29
milyon oxu») əhəmiyyətli kimi təqdim edirdi. Arifmetika düzdür,
çərçivə səhvdir, iki səbəbdən: `N` *eyni vaxtlı aktiv* istifadəçidir
(MAU deyil), və 29 mln oxu ~$17/aydır — o həddə çatmış tətbiq üçün
əhəmiyyətsiz məbləğ. Bugünkü qiymət: **192 oxu/gün.**

Əsl xərc tamamilə başqa yerdə idi. Funksiya hər tick-də hər məkanın
`audienceHistory` alt-kolleksiyasını **bütöv** oxuyurdu:

```
retensiya 7 gün × 96 tick/gün ≈ 672 sənəd
96 tick/gün × 672 = məkan başına gündə 64 512 oxu
```

~7 nümunəlik ortalama hesablamaq və vaxtı keçmiş ~1 sənədi tapmaq
üçün. **Bu, TƏK məkanla belə Firestore-un 50 000 oxu/gün pulsuz həddini
keçirdi** — və nəticə daim sıfır idi. Məkan sayı ilə xətti böyüyürdü.

Nisbət: düzəlişin əlavə etdiyi 192 oxu/gün, funksiyanın onsuz da
yandırdığının **0.3%-i** idi.

### Nə edildi

| Dəyişiklik | Təsir |
|---|---|
| Namizədlər `private/data` ilə birləşdirilir (run daxilində uid üzrə keşlənən, təkrarsız oxu) | `distance` rejimi işləyir; Ghost Mode hər üç rejimdə tətbiq olunur |
| `audienceHistory.get()` → iki dar sorğu: `where(hour ==) + where(timestamp >=)` və `where(timestamp <).limit(200)` | Məkan başına tick-də **672 → ~8 oxu** (~98% azalma) |
| Kompozit indeks `audienceHistory(hour ASC, timestamp ASC)` | Yuxarıdakı sorğunun ön şərti — **indeks funksiyalardan ƏVVƏL deploy edilməlidir** |
| Təsdiqlənmiş məkanların heç biri `distance` rejimində deyilsə, `users` skanı və `private/data` oxuları tamamilə atlanır | Kiçik/qarışıq məkan bazasında hər tick-də tam qənaət |

Nəticədə funksiya həm **işlək**, həm indikindən **ucuz** oldu.

**Təhlükəsizlik tərəfi əvvəlcədən hazır idi.** Audit 4 turunda
`computeAudienceCount`-a `isWithinNearbyVisibility`, pik şərtinə
k-anonimlik döşəməsi (`count >= VENUE_AUDIENCE_MIN_REPORTABLE_COUNT`)
əlavə edilmiş, `audienceRadiusKm` isə picker-in allowlist-inə
bağlanmışdı — məhz ona görə ki, mənbə düzəldilən anda funksiya
sızmağa başlamasın.

### Qalan bilinən məhdudiyyət

`users where lastSeen > cutoff` sorğusunda `limit` yoxdur, yəni oxu
sayı eyni vaxtlı aktiv istifadəçi sayı ilə xətti artır. Bugün
əhəmiyyətsizdir. Miqyas problemə çevrilsə, düzgün həll `withPrivateData`-nı
daha da ucuzlaşdırmaq deyil, **server-only iştirak indeksi**dir:
`private/data` yazısına trigger, Ghost Mode və görünmə radiusu **yazma
anında** tətbiq olunur, funksiya isə bir neçə hücrə sənədi oxuyur —
xərc `O(hücrə)` olur, `O(istifadəçi)` yox. Bu, #23-ün 1-ci variantının
eyni formasıdır və hər ikisi eyni sessiyada edilməlidir.

**Yenidən baxılma şərti:** eyni vaxtlı aktiv istifadəçi sayı 1000-i
keçəndə, VƏ YA Firestore aylıq oxu xərci ümumi infrastruktur xərcinin
20%-ni keçəndə.

## 26. ~~`birthdayMatches` təmizlənmir, `offerCreated` ölü sahədir~~ — BAĞLANDI

**Mənbə:** ad günü axınının auditi (2026-08-31)
**Bağlandı:** ad günü axınının yenidən qurulması (2026-09-01)

**Nə idi:** `computeBirthdayMatches` hər gün uyğun məkan başına bir
`birthdayMatches/{YYYY-MM-DD}_{venueId}` sənədi yazırdı və bu sənədlər
heç vaxt silinmirdi — nə planlaşdırılmış təmizləmə, nə TTL. 1000 uyğun
məkanda ildə ~365 000 sənəd. Ayrıca `offerCreated: false` sahəsi heç
vaxt `true` edilmirdi.

**Nə edildi:**

(a) **Təmizləmə.** Sənədə `expiresAt` əlavə edildi
(`BIRTHDAY_MATCH_RETENTION_DAYS = 3`) və kolleksiyaya native TTL
siyasəti quruldu. Planlaşdırılmış təmizləmə yazılmadı — `expireLapsedPremium`
naxışı gündə bir oxuma + bir silmə xərcləyir və unudula bilən daha bir
iş deməkdir. `notificationIntents` ilə eyni quruluş: yığıla bilməyən
struktur, təmizləyən funksiya yox.

Üç gün kifayətdir, çünki `assertBirthdayTargeting` artıq **yalnız
bugünkü** eşleşməni qəbul edir (bu da həmin yenidənqurmada əlavə edilən
ayrıca düzəlişdir — onsuz sahib dünənki `birthdayMatchId` ilə ad günü
çoxdan keçmiş adamlara push göndərə bilirdi).

(b) **`offerCreated` silindi**, bağlanmadı. Sahəni `submitOffer`-də
`true` etmək cazibədar idi, amma bu, düzgün cavab olmazdı: kampaniya
göndərilib sonra rədd edilə bilər, yəni «sahib bu nudge-dan istifadə
etdimi» sualına yalnız təklifin son statusuna baxaraq cavab vermək olar.
Heç nə bu sahəni oxumurdu. Həmişə `false` deyən sahə heç bir sahədən
pisdir — çünki cavab kimi görünür.

**Fayllar:** `functions/src/index.ts` (`computeBirthdayMatches`,
`assertBirthdayTargeting`), `docs/CONSOLE_MANUAL_STEPS.md` (TTL).

## 27. Ödəniş təsviri serverdə yaranır — çoxdilli deyil

**Mənbə:** Ödənişlər ekranının düzəldilməsi (2026-08-31)

**Nə:** `payments/{id}.description` ödəniş anında serverdə qurulur və
**yalnız Azərbaycancadır**: `Məkan abunəliyi — {ad}`, `PinBox —
{başlıq}`, `Təklif yerləşdirmə haqqı — {başlıq}`. Server yazma anında
oxuyanın dilini bilmir.

**Nəticə:** rus və ya ingilis dilində işlədən istifadəçi Ödənişlər
ekranında qarışıq görüntü alır — başlıq (`type`-ın l10n etiketi)
tərcümə olunur, detal sətri yox.

**Niyə indi qəbul edilir:** alternativ, `description`-ı strukturlaşmış
sahələrə bölmək (`kind` + `subjectName`) və client-də qurmaqdır — bu,
sxem dəyişikliyidir və mövcud ödəniş sənədləri üçün miqrasiya tələb
edir. Mətn oxunaqlıdır və məbləğ/tarix onsuz da dil-neytraldır.

**Nə vaxt yenidən baxılmalı:** tətbiq Azərbaycandan kənar bazara
çıxanda, VƏ YA çoxdilli istifadəçilərin payı əhəmiyyətli olanda.

**Təxmini iş həcmi:** ~3-4 saat (sxem + miqrasiya + client formatlama).

## 28. `offers.boostedFrom` yoxdur — boost saatları ölçülə bilmir

**Mənbə:** məkan analitikası yığımı (2026-09-01)

**Nə:** `offers.boostedUntil` yalnız boost-un BİTMƏ anını saxlayır.
Başlanğıc heç yerdə yazılmır, ona görə «həmin gün boost neçə saat aktiv
idi» sualına cavab vermək mümkün deyil — nə indi, nə geriyə dönük.

`rollUpVenueDailyStats` hazırda yalnız `boostActive` (bool) yazır:
«həmin gün boost aktiv idimi». Aylıq hesabatda «boost-a X saat xərclədiniz,
Y əlavə baxış gətirdi» sətri bu sahə olmadan yazıla bilməz.

**Nə edilməli:** `applyPaymentOutcome`-un `boost_fee` budağında
`boostedUntil` ilə yanaşı `boostedFrom: serverTimestamp()` yazmaq. Bir
sətirdir. Sonra `rollUpVenueDailyStats`-də `boostActive` boolean-ı
`boostHours` rəqəminə çevirmək.

**Geriyə dönük məlumat bərpa olunmur** — sahə əlavə edilənə qədər olan
boost-lar üçün yalnız bool qalır.

**Təxmini iş həcmi:** ~1 saat.

## 29. Analytics impression seçilsə məxfilik §2.6 yenilənməlidir

**Mənbə:** məkan analitikası yığımı (2026-09-01)

**Nə:** «Kəşf et-də neçə dəfə göründü» göstəricisi üçün tövsiyə edilən
həll Firebase Analytics hadisəsidir (`venue_impression`), çünki Firestore
sayğacı bu həcmdə hesabatın gətirdiyi gəlirdən baha olar
(docs/VENUE_ANALYTICS.md).

Amma məxfilik siyasəti §2.6 hazırda yalnız ümumi ifadə saxlayır:
«Tətbiqin istifadə statistikası Firebase Analytics… vasitəsilə toplanır».
Məkan səviyyəsində göstəriş sayımı — yəni istifadəçinin hansı məkanları
gördüyünün Analytics-ə göndərilməsi — bundan aydın oxunmur.

**Nə edilməli:** impression izləməsi qurulmazdan ƏVVƏL §2.6-ya konkret
bənd əlavə edilməli və `currentPrivacyVersion` artırılmalıdır (ardıcıllıq:
docs/legal-gap-analysis.md §5.3).

**Nə vaxt:** impression izləməsi qurulanda, ondan əvvəl yox.

**Təxmini iş həcmi:** ~1 saat + versiya artımı prosesi.

## 30. Dəstək mesajları üçün admin panel ekranı

**Mənbə:** funksional bütövlük auditi (2026-09-01)

**Nə:** `supportMessages` kolleksiyasının **oxuyucusu yox idi** —
tətbiq yazırdı, admin paneldə ekran yoxdur (`UNIMPLEMENTED_PERMISSIONS`
bunu özü qeyd edirdi), serverdə trigger yoxdur. İstifadəçi dəstəyə
yazırdı və mesaj heç kimə çatmırdı.

**İndi nə var:** `onSupportMessageCreated` mesajı `support@peakpin.app`
ünvanına e-poçtla göndərir, hesabın öz təsdiqlənmiş e-poçtunu
`replyToEmail` sahəsində əlavə edir və `status: "open"` yazır.

**Niyə bu müvəqqətidir:** e-poçt qutusu növbə deyil. Miqyasda lazımdır:

- siyahı və axtarış (növ, tarix, status üzrə filtr)
- status idarəsi (`open` → `answered` → `closed`) — sahə onsuz da yazılır
- panel daxilindən cavab (və ya cavab verilib işarələmə)
- eyni istifadəçinin əvvəlki mesajları — kontekst üçün
- cavabsız qalmış mesajların yaşı üzrə xəbərdarlıq

`viewSupportMessages` / `manageSupportMessages` icazələri **artıq
matrisdədir** və `UNIMPLEMENTED_PERMISSIONS`-dədir — ekran qurulanda
yeni icazə əlavə edilməməlidir, mövcudları bağlanmalıdır.

**Nə vaxt:** gündəlik dəstək mesajı sayı e-poçt qutusunda idarə edilə
biləndən çox olanda, VƏ YA cavab müddəti ölçülməli olanda.

**Təxmini iş həcmi:** ~4-6 saat (`/offers` naxışı ilə).

## 31. `offers` update qaydası blocklist-dir — allowlist olmalıdır

**Mənbə:** A5 hədəflənmiş auditi (2026-09-01), A5-C1-in kök səbəbi

**Nə:** `offers` üçün `allow update` **blocklist**-dir: siyahıda
olmayan sahə **yazıla bilir**. Hər yeni server-only sahə əl ilə əlavə
edilməlidir.

`freeCampaignHold` bunun nəyə gətirdiyini göstərdi — o, `venues`
sənədindəki `freeCampaignsUsed` ilə eyni gün, eyni funksiyanın hissəsi
kimi əlavə edildi, amma TƏKLİF sənədində olduğu üçün yalnız `venues`
siyahısı yenidən oxundu. Nəticə: sahib bayrağı təsdiqlənmiş kampaniyaya
geri yazıb silə və kvota slotunu qaytara bilirdi — limitsiz pulsuz
kampaniya. Emulyatorda sübut edildi.

`venueEvents` eyni funksiyaya sahibdir və bu səhv orada baş vermədi,
çünki onun qaydası `hasOnly` ilə **allowlist**-dir.

**Nə üçün asandır:** klient `offers` sənədinə **ümumiyyətlə birbaşa
yazmır**. `FirebaseOfferRemoteDatasource.setOffer` mövcuddur, amma heç
yerdən çağırılmır (ölü metod); yaratma, yeniləmə və silmə `submitOffer`
/ `updateOffer` / `deleteOffer` callable-larından keçir. Bloklanmayan
sahələr faktiki olaraq yalnız `createdAt`, `updatedAt` və `ownerId`-dir
(sonuncu ayrıca bərabərlik yoxlaması ilə qorunur).

**Nə edilməli:** qayda `allow update: if false` edilə bilər, ya da çox
dar `hasOnly([...])` ilə. Bu, təhlükəsizlik yamağı ilə eyni keçiddə
edilmədi, çünki tapılmayan bir yazı yolu varsa təkliflər redaktə
edilməz hala düşər — dəyişiklik ayrıca, öz test dəsti ilə getməlidir:
`submitOffer`, `updateOffer`, `retryOfferPayment`, `createBoostCheckout`
və admin panelin `setOfferStatus`-u dəyişiklikdən sonra işləməlidir.

**Təxmini iş həcmi:** ~2 saat (dəyişiklik bir sətir, testlər qalanı).

## 32. `venues.gallery` kilidlidir, amma heç bir yazıcısı yoxdur

**Tapılıb:** 2026-09-01, «kilidləndi, amma açarı verilmədi» sweep-i.

`touchesLockedVenueFields()` 46 sahəni bloklayır. Onlardan 45-i üçün
serverdə qanuni yol var (`submitVenue`, `updateVenue`, `resubmitVenue`,
ödəniş axınları, sayğac triggerləri). `gallery` istisnadır: bütün kod
bazasında — Dart, `functions/src`, admin panel — ona yazan heç nə
yoxdur. Yeganə istinadlar `l10n`-dakı "Choose from gallery" mətnləridir,
yəni şəkil seçicisinə aiddir, bu sahəyə deyil.

Yəni sahə ölüdür: nə oxunur, nə yazılır. `starCount`/`heartCount`/
`dislikeCount` ilə eyni sinifdəndir (Düzəliş Prompt 2 / K-8 onları
silmişdi).

**Risk:** yoxdur. Kilid heç bir legitim axını dayandırmır — dayandıracaq
axın mövcud deyil. Ona görə bu düzəliş deyil, təmizlikdir.

**Nə etməli:** ya `touchesLockedVenueFields()`-dən çıxarmaq (sahə
yoxdursa kilid mənasızdır), ya da məkan qalereyası funksiyası
planlaşdırılırsa saxlamaq və `updateVenue`-a yazma yolu əlavə etmək.
Qərar məhsul tərəfindədir; kod tərəfində təcili heç nə yoxdur.

**Qeyd:** bu bənd sweep-in nəticəsi kimi yazılıb ki, gələcək audit eyni
sahəni yenidən «boşluq» kimi tapıb təcili düzəliş etməsin.

---
## 33. E-poçt action URL yazıla bilmir — `mail.peakpin.app` doğrulaması yarımçıq

**Aşkarlandı:** 2026-09-02, mağaza buraxılışı hazırlığında.
**Təcilidir?** Xeyr — buraxılışı bloklamır, aşağıya bax.

Firebase Console-da action URL-i `https://peakpin.app/auth-action`
etmək mümkün deyil; konsol yalnız "An error occurred updating action
URL" göstərir. Admin API-si əsl cavabı verir:

```
PATCH …/config?updateMask=notification.sendEmail.callbackUri
→ 400 INVALID_ARGUMENT — EMAIL_TEMPLATE_UPDATE_NOT_ALLOWED
```

**Etibarsız sınaq — buna güvənməyin.** Əvvəlcə `verifyEmailTemplate.subject`
yazıb keçdiyinə əsasən "bloklama yalnız `callbackUri`-yə aiddir" nəticəsi
çıxarıldı. Sınaq eyni dəyəri geri yazırdı, yəni heç bir dəyişiklik yox
idi — server onu no-op kimi keçirmiş ola bilər. Bloklamanın bütün
`notification.sendEmail` blokuna aid olub-olmadığı hələ bilinmir; yenidən
yoxlanarsa, mütləq FƏRQLİ dəyər yazılmalıdır.

Konfiqurasiyadakı tək anomaliya:

```
notification.sendEmail.dnsInfo:
  customDomain: mail.peakpin.app
  useCustomDomain: true            ← aktiv işarələnib
  customDomainState: NOT_STARTED   ← doğrulama heç başlamayıb
  domainVerificationRequestTime: 1970-01-01T00:00:00Z
```

Yoxlanıb və səbəb DEYİL: `peakpin.app` icazəli domenlər siyahısındadır;
`https://peakpin.app/auth-action` HTTP 200 qaytarır — səhifə hazır və
canlıdır, sadəcə hələ istifadə olunmur.

## Yoxlanmış və RƏDD EDİLMİŞ fərziyyələr

**1. "Domen Firebase Hosting-ə bağlı olmalıdır."** Məntiqli idi:
`peakpin.app` Vercel-dədir (`server: Vercel`), layihənin Hosting saytı
isə yalnız `kim-var-73ce9`. Amma `auth.peakpin.app` — Hosting-də
`DOMAIN_ACTIVE`, icazəli domenlər siyahısında, `__/auth/action` yolu
HTTP 200 qaytarır — həmin xəta ilə rədd olundu. Fərziyyə səhvdir.

**2. `dnsInfo.customDomainState: NOT_STARTED`.** Yeganə görünən
anomaliyadır (`mail.peakpin.app`, `useCustomDomain: true`,
`domainVerificationRequestTime: 1970-01-01`), amma səbəb olduğu
sübut edilməyib.

**3. İcazəli domenlər.** `peakpin.app`, `auth.peakpin.app`,
`mail.peakpin.app` — hamısı siyahıdadır. Səbəb deyil.

## Vəziyyət

2026-09-02: Firebase Support-a müraciət göndərildi (Auth → custom
domain kateqoriyası). Formanın ilk göndərişi Google tərəfdə sındı;
mətn qısaldılıb URL-lər çıxarılandan sonra keçdi. Cavab gözlənilir.

Alternativ kanal: `firebase-support@google.com`.

**Bloklama açılanda yazılacaq dəyər:**

```
https://auth.peakpin.app/__/auth/action
```

Bu ünvan artıq işləkdir (HTTP 200) — kod və ya DNS işi lazım deyil,
yalnız sahənin yazılması. `peakpin.app/auth-action` səhifəsi də canlıdır,
amma Vercel-də olduğu üçün onu hədəf seçmək riskli; öz dizaynınız
lazımdırsa səhifə `auth.peakpin.app` altına köçürülməlidir.

## Alternativ yol YOXDUR

Yoxlanıldı: link həmişə `callbackUri`-dən qurulur. Admin SDK-nın
`generateEmailVerificationLink` funksiyası ilə linki serverdə yaratsanız
da, `ActionCodeSettings.url` yalnız "davam et" ünvanıdır — işləyici
domeni yenə həmin sahədən gəlir. Resend ilə öz e-poçtunuzu göndərmək də
domeni dəyişmir.

**Niyə gözləyə bilər:** cari dəyər
`https://kim-var-73ce9.firebaseapp.com/__/auth/action` — Firebase-in öz
işlək standart səhifəsi. E-poçt təsdiqi və parol sıfırlama linkləri
indi də işləyir, sadəcə brendsiz görünür. 2026-09-02-də bilərəkdən
toxunulmadı: mağaza baxışı gedərkən canlı e-poçt konfiqurasiyasını
dəyişmək lazımsız risk idi.

Təfərrüat və təkrar istehsal əmrləri: `docs/CONSOLE_MANUAL_STEPS.md`.
