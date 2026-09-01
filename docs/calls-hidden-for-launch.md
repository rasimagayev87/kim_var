# Zəng funksiyası launch üçün gizlədilib

**Tarix:** 2026-09-01
**Vəziyyət:** gizli, kod toxunulmamış
**Açmaq üçün:** aşağıdakı «Nə lazımdır» bölməsi

---

## Niyə

Cihaz testində zəng axını sabit işləmədi. Bir günlük iş nəticəsində dörd
ayrı qüsur tapıldı və düzəldildi (bax
`docs/field-test-2026-09-01.md`), amma iki maneə açıq qaldı:

* **T-1 — arxa fon şəbəkə bloku.** Android tətbiqi RESTRICTED standby
  kateqoriyasına salanda arxa fon şəbəkəsi kəsilir və WebRTC-nin ICE
  mübadiləsi baş tutmur. Cihazda ölçüldü: `isBlocked=true`, bucket 50.
  Həlli məhsul qərarı tələb edir (istifadəçidən batareya istisnası
  istəmək) və bir cihazın ölçüsü ilə ümumiləşdirilə bilməz.

* **iOS PushKit sertifikatı yoxdur.** Samsung→iPhone istiqamətində
  tətbiq arxa fonda ikən zəng ümumiyyətlə çatmır.

Zəng yarımçıq işləyən halda buraxılsa, istifadəçi onu sınayacaq və
işləməyəcək. Gizli funksiya sınıq funksiyadan yaxşıdır.

---

## Nə gizlədilib

| Yer | Nə edilib |
|---|---|
| Çat ekranı — səsli/video düymələr | **Çəkilmir** (`callsVisible`). Əvvəl boz halda görünürdü; boz düymə də funksiyanı reklam edir. |
| `_startCall` | Bayraq yoxlaması — düymələr gizli olsa da metod özü qorunur |
| Gələn zəng dinləyicisi (`home_screen`) | Bayraq bağlıdırsa heç nə etmir |
| `onCallCreated` (server) | `config/features.callsEnabled` yoxlanır, push göndərilmir |

Profil ekranında zəng düyməsi, ayrıca zəng tarixçəsi ekranı və ayarlarda
zənglə bağlı parametr **yoxdur** — sweep edildi, tapılmadı. Çat lentindəki
zəng qeydləri (buraxılmış zəng mesajları) tarixi qeydlərdir, giriş nöqtəsi
deyil, ona görə toxunulmayıb.

## Nə QALIB (silinməyib)

* `onCallCreated`, `onCallUpdated`, `sendCallPush`, `expireStaleWaitlistCalls`
* CallKit arxa fon handler-i və `listenToCallkitEvents`
* `IncomingCallScreen`, `CallScreen`, `ActiveCallController`
* `FirebaseCallRepository` bütövlükdə
* `firestore.rules`-dakı `calls` qaydaları və `participants;receiverId;status` indeksi
* Bütün testlər

Yəni açmaq üçün kod bərpası lazım deyil — yalnız iki bayraq.

---

## İki bayraq, ikisi də deploy tələb etmir

**Klient:** Remote Config `feature_calls_enabled`.
Paketlənmiş defolt **`false`** (`app_config.dart`). Bu vacibdir: defolt
Remote Config gəlməmiş tətbiq olunur, ona görə `true` olsaydı hər soyuq
başlanğıcda düymələr bir anlıq görünərdi. Bayraq **fail-closed**-dur.

**Server:** `config/features.callsEnabled` (Firestore).
Sənəd yoxdursa və ya oxunmursa **`false`** qaytarır. Kolleksiya
server-onlydir — `firestore.rules`-da `allow write: if false`, yeganə
wildcard da bağlayıcıdır; emulyatorda təsbit edilib
(`tests/rules/firestore-config-write.test.ts`), yəni bayrağı klientdən
`true` etmək mümkün deyil — konfiqurasiya
nasazlığı geri götürülmüş funksiyanı səssizcə bərpa etməməlidir.

### Niyə Remote Config, sabit dəyər deyil

Sabit dəyər (`const kCallingEnabled = false`) açmaq üçün yeni AAB və
mağaza baxışı tələb edərdi. Remote Config isə **artıq quraşdırılmış
buildlərdə də** işləyir: bayraq çevriləndə istifadəçilər yeni versiya
yükləmədən zəngi alır.

Bu, ilkin mülahizənin əksidir («köhnə buildlər onsuz da düyməni
göstərməyəcək, yəni yeni AAB lazım olacaq») — köhnə buildlər Remote
Config-i də oxuyur, ona görə yeni AAB lazım DEYİL. Mexanizm onsuz da
mövcud idi (`FeatureFlag.calls` enum-da vardı və çat düymələrinə
bağlanmışdı), yəni yeni bayraq sistemi qurulmadı.

Yeganə şərt: gizlədilmiş vəziyyəti daşıyan build mağazaya çıxmalıdır.
Ondan sonra açma tamamilə serverdəndir.

---

## Açmaq üçün nə lazımdır

Sıra ilə, hər biri əvvəlkindən asılıdır:

1. **T-1 həll olunsun** — arxa fon şəbəkə blokuna münasibət. Variantlar:
   istifadəçidən `ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS` ilə
   istisna istəmək (icazə tələb etmir, Play bəyannaməsi tələb etmir),
   və/və ya arxa fon işini FCM pəncərəsinə sığacaq qədər qısaltmaq.
   Stok Android cihazında təkrar ölçmə şərtdir — indiki nəticə bir
   Samsung-un ölçüsüdür.

2. **iOS PushKit VoIP sertifikatı** alınsın və qurulsun. Onsuz
   Samsung→iPhone arxa fon zəngi işləmir.

3. **İki cihazda tam test** — səsli və video, hər iki istiqamət, ön plan
   və arxa fon, ardıcıl bir neçə zəng. Bu gün «birinci zəng işlədi,
   sonrakılar sındı» naxışı iki dəfə təkrarlandı, ona görə tək uğurlu
   zəng nəticə sayılmır.

4. **Açılış — SIRA VACİBDİR:**

   > ### **ƏVVƏLCƏ SERVER, SONRA KLİENT**
   >
   > **1.** Firestore `config/features.callsEnabled = true`
   > **2.** Remote Config `feature_calls_enabled = true`
   >
   > **Tərsi düymələri işləməyən hala gətirər:** klient açılıb server
   > bağlı qalsa, istifadəçi zəng düyməsini görür, basır, `calls`
   > sənədi yaranır — amma `onCallCreated` push göndərmir. Zəng edən
   > gudok eşidir, qarşı tərəfin telefonu heç vaxt çalmır. Bu, gizli
   > funksiyadan da pis təcrübədir.

   Bağlamaq lazım gələrsə sıra da tərsinədir: **əvvəlcə klient, sonra
   server** — yəni hər iki halda əvvəlcə düymələri görünməz edən tərəf
   dəyişdirilir.

## Bilinən, hələ həll olunmamış

* iPhone-da səs zəif çıxır (Samsung-da normal). Video zəngdə dinamik
  onsuz da açılır (`active_call_controller.dart`), yəni səbəb iOS audio
  sessiyasının konfiqurasiyasıdır — kod bazasında `AVAudioSession`
  tənzimləməsi yoxdur.
* Eyni prosesdə `main()` iki dəfə qaçdıqda izlər cütləşir; push
  dinləyiciləri idempotent edildi, amma ayrı mühərrik nüsxələri arasında
  mühafizə işləmir.
