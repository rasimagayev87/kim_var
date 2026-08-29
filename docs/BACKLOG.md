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

## 8. Real MFA (TOTP)

**Mənbə:** Prompt 10 / AUTH-8b
**Təxmini iş həcmi:** ~1-2 həftə (TOTP secret generasiyası/saxlanması,
QR-kod ilə enrollment UI-si, doğrulama axını sign-in-ə inteqrasiyası,
"backup kodlar" axını, mövcud dekorativ `twoFactorEnabled` bayrağının
əvəzlənməsi ya da silinməsi).
**Niyə #8:** ən böyük iş həcmi, hazırkı miqyasda ən aşağı təcililik —
istifadəçi bazası böyüdükcə prioritetləşdirilməlidir.
