# Backlog

Bu siyahı GitHub Issues-a köçürülməlidir — hər maddə öz issue-su olmalıdır,
bu fayl yalnız MÜVƏQQƏTİ referansdır. Prioritet sırası ilə (1 = ən yüksək).
Hər maddənin tam kontekst/səbəbi [ACCEPTED_RISKS.md](ACCEPTED_RISKS.md)-da.

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

## 11. `auth_screen.dart` — ümumi `catch` bloku uğurlu qeydiyyatı "uğursuz" kimi göstərir

**Mənbə:** Post-launch QA — Qeydiyyat axını sınağı zamanı tapıldı (əsl
kök səbəb `firestore.rules`-un `resource == null` boşluğu idi, bu
sessiyada düzəldildi — amma bu ikinci, MÜSTƏQİL zəiflik qalır).
[`auth_screen.dart:217-224`](../lib/features/auth/presentation/screens/auth_screen.dart)-dəki
`catch (e, st)` bloku `FirebaseAuthException`-dan FƏRQLİ istənilən
xətanı (məs. `_hydrateFromFirestore`-un Firestore oxuma xətası)
eyni ümumi "Giriş uğursuz oldu" mesajı ilə göstərir — halbuki bu halda
`createUserWithEmailAndPassword` ARTIQ UĞURLA TAMAMLANIB və Firebase
Auth hesabı yaradılıb. İstifadəçi hesabının mövcud olduğunu bilmədən
"yenidən cəhd et" düyməsinə basanda `email-already-in-use` kimi YENİ
bir anlaşılmaz xəta ala bilər.
**Təxmini iş həcmi:** ~2-3 saat (register-specific fallback mesajı,
məsələn "Hesabınız yaradıldı, amma profilin tamamlanmasında xəta baş
verdi — yenidən daxil olmağı sınayın" + bu halın loglanması ki, oxşar
gizli boşluqlar gələcəkdə də tez tapılsın).
**Niyə aşağı prioritet:** kök səbəb (rules boşluğu) artıq düzəldilib,
bu, YALNIZ gələcəkdə bənzər bir Firestore/rules xətası yenidən baş
versə görünəcək ikinci qatlı simptomdur — özü başlı-başına heç nəyi
bloklamır.

## 12. iOS Crashlytics — dSYM yükləmə addımı yoxdur

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
