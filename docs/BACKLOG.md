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
  rethrow edir).
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

## 8. Telefon nömrəsində ikiqat ölkə prefiksi bug-ı

**Mənbə:** Təmizlik Prompt (production məlumatının silinməsi) — Mərhələ
3-ün doğrulanması zamanı təsadüfən aşkar edildi. `rasimagayev80@gmail.com`
hesabının `users/{uid}/private/data.phoneNumber` sahəsi
`"+994+994502749898"` kimi saxlanılıb — ölkə kodu (`+994`) İKİ DƏFƏ.
**Ehtimal edilən səbəb (təsdiqlənməyib, YALNIZ oxunan datadan çıxarım):**
`lib/features/auth/presentation/widgets/country_dial_code.dart`-ın dial-kod
siyahısı (`+994` = Azərbaycan) və onboarding/profil ekranlarının
`_applyDialCodeForCountry`-yə bənzər avtomatik-prefiks məntiqi — istifadəçi
telefon sahəsinə ARTIQ `+994` ilə başlayan nömrə yazıbsa, kod bunu
yoxlamadan YENƏ öz prefiksini əlavə edə bilər. Kod OXUNMADI, bu, sadəcə
simptomdan irəli gələn fərziyyədir.
**Təxmini iş həcmi:** ~2-4 saat (kökü tapmaq + düzəltmək + mövcud
istifadəçilərin `phoneNumber` sahələrini təmizləyən kiçik bir miqrasiya
skripti — indi yalnız 1 real istifadəçi olduğu üçün miqrasiya çox
kiçikdir).
**Niyə #9 (aşağı prioritet):** funksional pozuntu deyil (görünür SMS/zəng
funksiyası bu sahədən asılı deyil, əks halda daha tez aşkar edilərdi),
sadəcə data-keyfiyyəti məsələsidir — amma launch-dan əvvəl, ideal
olaraq yeni istifadəçi bazası böyüməzdən əvvəl düzəldilməlidir ki, hər
yeni qeydiyyatda təkrarlanmasın.

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

## 14. `bannedUsers/{uid}` tombstone-u hesab silinəndə qalır

**Mənbə:** Audit 2 / F-5 (`user-account-deletion.ts` auditi)
**Nə:** Nə `deleteAccount` (Cloud Function), nə də admin panelin
`deleteUserAccountPermanently`-si `bannedUsers/{uid}` sənədini silmir.
Banlanmış hesab silinəndə tombstone bucket-də qalır.
**Təsiri:** praktiki olaraq YOXDUR — Firebase uid-ləri təkrar istifadə
olunmur, yəni tombstone heç vaxt yanlış hesaba aid olmayacaq. Yalnız
gigiyena məsələsidir.
**Təxmini iş həcmi:** ~15 dəqiqə, hər iki kod bazasında bir sətir
(`db.collection("bannedUsers").doc(uid).delete()`).

## 15. Hesab silinməsində qalan orphan sənədlər (pinboxes, venueEvents)

**Mənbə:** Audit 2 / F-4-ün araşdırması zamanı aşkarlandı
**Nə:** `deleteAccount` (və admin paneldəki eyni məntiq) istifadəçinin
`posts`/`venues`/`offers`/`stories` sənədlərini silir, amma
**`pinboxes`** və **`venueEvents`** sənədlərinə toxunmur. Məkan silinəndən
sonra onlara istinad edən PinBox və tədbir sənədləri orphan qalır.
**Niyə bu turda EDİLMƏDİ:** silmə qərarı sadə deyil — PinBox sənədinin
arxasında alıcıların `pinboxOrders`-ı və `venuePayouts` öhdəlikləri dayanır
(`anonymizePinBoxOrders`-un öz şərhi məhz buna görə sifarişləri silmir,
anonimləşdirir). Yəni burada "sil" yox, "arxivləşdir/anonimləşdir" qərarı
lazımdır — `archiveCreatedEvents` naxışına bənzər.
**Təxmini iş həcmi:** ~4-6 saat (qərar + hər iki kod bazasında tətbiq +
testlər).
**Qeyd:** Storage tərəfi bu turda bağlandı — `pinbox_photos/{uid}/` və
`event_covers/{uid}/` prefiksləri artıq silinir, yəni ŞƏKİLLƏR qalmır,
yalnız sənədlər qalır.
