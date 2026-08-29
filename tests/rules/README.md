# Rules davranış testləri (Düzəliş Prompt 12)

`firestore.rules` və `storage.rules`-un Prompt 1, 2, 3, 11-də edilmiş dəyişikliklərinin davranış-səviyyəli (real `allow`/`deny`) regression suite-i. Yalnız sintaksis compile-ını yox, real qayda nəticələrini yoxlayır.

## İşlətmə

```bash
npm --prefix tests/rules test
```

Bu, `firebase emulators:exec`-i **`demo-peakpin-rules-test`** layihə ID-si ilə çağırır (real `kim-var-73ce9` layihəsi İLƏ HEÇ ƏLAQƏSİ YOXDUR — Firebase CLI/SDK `demo-`-prefiksli ID-ni heç vaxt real GCP layihəsi ilə əlaqələndirmir, bu, "production-a sorğu getməsin" tələbini intizam yox, struktur səviyyəsində təmin edir), Firestore+Storage emulator-larını başladır, `tests/rules/*.test.ts`-i (Node-un built-in `node:test`-i, `tsx` vasitəsilə) işlədir, nəticəni çap edir, emulator-ları bağlayır.

**Diqqət — `firebase.json`-a əlavə olunan `emulators` bloku bu testlərə xasdır, `firebase deploy` davranışını HEÇ CÜR dəyişmir** (`deploy` əmri `emulators` açarına baxmır, yalnız `emulators:start`/`emulators:exec` ona baxır). O fayl sonra normal deploy üçün olduğu kimi istifadə oluna bilər.

## JAVA_HOME

Emulator-lar JVM-əsaslıdır. Bu Mac-da sistem `java`-sı işləmir ("Unable to locate a Java Runtime"). `run.sh` bunu avtomatik aşkarlayır: `JAVA_HOME` təyin olunmayıbsa VƏ Android Studio-nun bundled JBR-i (`/Applications/Android Studio.app/Contents/jbr/Contents/Home`) mövcuddursa, onu istifadə edir. **Başqa maşında** (normal `java` quraşdırılmış hər hansı mühit, o cümlədən standart GitHub Actions Ubuntu runner-ləri) bu blok heç nə etmir — sadəcə sistemin öz Java-sından istifadə olunur, əlavə iş lazım deyil.

## CI

Tələb olunanlar: `firebase-tools` qlobal quraşdırılmış (`npm install -g firebase-tools`), `java` mövcud (standart Ubuntu runner-lərində artıq var). Konkret workflow faylı yaradılmayıb — CI seçimi layihə sahibinin qərarıdır.

## Struktur

- `helpers.ts` — paylaşılan `RulesTestEnvironment` qurulumu + fixture funksiyaları.
- `firestore-prompt1.test.ts` — yaş qapısı (7 test).
- `firestore-prompt2.test.ts` — rules sərtləşdirmə paketi: K-2, K-5, K-8, K-9, reviews/usernames/birthdayMatches/venues (30 test).
- `firestore-prompt11.test.ts` — sessiya ləğvi: `isActiveUser()` gate-i + qəsdən-açıq yollar (22 test).
- `firestore-prompt4.test.ts` — `users` PII ayrımı (K-1/K-4/RT-25): publik sahələrin kross-oxusu, `users` üzərində `list` qadağası, `private/data`-nın sahib-yalnız qaydası, `activeCheckins`-in daraldılmış oxusu + `activeCheckinCount` sayğacının kiliddi (14 test).
- `firestore-prompt5.test.ts` — blok mexanizminin server tərəfə köçürülməsi (K-3/RT-5/RT-6/RT-14): chats/messages/calls-da iki-istiqamətli blok, `whoCanMessageMe: followersOnly`-nin server-side tətbiqi, rədd edilmiş söhbətə mesaj yazılmaması (RT-5, eyni-tranzaksiya `exists()` empirik təsdiqlənib), `users/{uid}` profil oxumasının BİR-İSTİQAMƏTLİ blok-aware olması (yalnız bloklanan tərəf bloklayanı görmür — asimmetriya `blocked_users_screen.dart`-ın öz siyahısını qorumaq üçün qəsdəndir) (20 test).
- `storage-prompt3.test.ts` — Storage sahiblik (15 test, 4-ü parametrik dövrdə).

## Nəticə (son işlətmə)

**108 test, 108 keçdi.**

İlk işlətmədə 1 test uğursuz oldu və real bir boşluq tapdı: `users/{uid}` sahibi öz `reportedCount`-unu (moderasiya siqnalı) sərbəst dəyişə bilirdi, çünki Prompt 2 / K-8-in düzəlişi yalnız QEYRİ-sahib budağını məhdudlaşdırmışdı. Tapıntı təsdiqləndikdən sonra düzəldildi — `reportedCount` `touchesLockedUserFields()`-ə əlavə olundu (yeganə legitim yazıcı, `firebase_safety_repository.dart:57`, HƏMİŞƏ başqa istifadəçinin sənədinə yazır, ona görə bu kilid legitim axını sındırmır — həm client-side self-report guard, həm rules-un öz `request.auth.uid != userId` şərti bunu təsdiqləyir). Suite indi tam yaşıldır.

Düzəliş Prompt 4-ün (`users` PII ayrımı) əlavə etdiyi 14 test heç bir yeni tapıntı olmadan birbaşa yaşıl keçdi — 88/88.

Düzəliş Prompt 5-in (blok mexanizmi) testləri 1 REGRESSİYA tapdı (özü yox, Prompt 11-in `calls create` fixture-u — real `startCall()` həmişə `receiverId` yazır, test fixture-u yazmırdı, yeni `isBlockedPair(callerId, receiverId)` yoxlaması bunu tələb etdiyi üçün üzə çıxdı) — fixture düzəldildi, blok qaydalarının özündə boşluq deyildi. RT-5-in `exists(chatPath)`-a əsaslanan naxışı (əvvəllər bir dəfə sınayıb geri çıxarılmışdı) bu dəfə eyni-tranzaksiya (`runTransaction`, çat+ilk mesaj birgə) ssenarisi ilə AYRICA, TƏK test kimi empirik təsdiqləndi. `users/{uid}` profil oxuması ilk versiyada iki-istiqamətli tətbiq edilmişdi, sonra istifadəçinin dəqiq tələbinə görə BİR-İSTİQAMƏTLİYƏ düzəldildi (yalnız bloklanan tərəf görmür) — simmetrik versiya `blocked_users_screen.dart`-ın öz siyahısını sındırardı (bloklayan öz bloklarının adını/fotosunu görə bilməzdi). Son nəticə — 108/108.
