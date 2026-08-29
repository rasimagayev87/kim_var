# Düzəliş Prompt 10 — Manual doğrulama addımları

Bu sənəd deploy edildikdən sonra istifadə üçündür. Kod indi YALNIZ yazılıb.

## 0. ÇOX VACİB ön şərt — deploydan ƏVVƏL

**`config/businessOffer` sənədi MÜTLƏQ set edilməlidir DEPLOY-DAN ƏVVƏL** —
əks halda `submitVenue` (yeni məkan yaratma) VƏ `retryVenueSubscriptionPayment`-in
yenidən-qəbul axını dərhal sınar (`business-offer-not-configured` xətası
atır). Hazırkı Remote Config-dəki `business_offer_version`/`url_business_offer`
dəyərlərini (və ya real hazırkı PDF versiyasını/linkini) istifadə edin:

```bash
npm run set-business-offer-version -- 1.0 https://peakpin.app/legal/business-offer-v1.0.pdf
```

(Real versiya/URL-i özünüz təsdiqləyin — yuxarıdakı yalnız nümunədir.)

## 1. AUTH-6 — rezerv username

1. Tətbiqdə qeydiyyatdan keçin, username kimi `admin`, `support`, ya da
   `peakpin` yazmağa çalışın.

**Gözlənilən:** "Bu istifadəçi adı ayrılıb." xətası, qeydiyyat bloklanır.

## 2. AUTH-12 — provider toqquşması

1. `test@nümunə.com` (real qutunuza çıxışınız olan bir ünvan) ilə
   email/parol qeydiyyatı edin.
2. Çıxış edin, EYNİ email-ə bağlı Google hesabı ilə "Continue with Google"
   sınayın.

**Gözlənilən:** Əvvəllər çöküş-bənzəri, izahsız xəta görünürdü. İndi aydın
mesaj: "Bu e-poçt artıq başqa üsulla qeydiyyatdan keçib. Parolla daxil
olmağı, ya da 'Şifrəni unutmusunuz?' ilə yeni parol təyin etməyi sınayın."

## 2b. AUTH-12 (əlavə) — e-poçt doğrulaması məcburiliyi

1. Real bir e-poçt ünvanı ilə (qutunuza çıxışınız olsun) parolla
   qeydiyyatdan keçin.

**Gözlənilən:** birbaşa Onboarding-ə DEYİL, "E-poçtunuzu təsdiqləyin"
ekranına yönləndirilirsiniz. "Yenidən göndər" düyməsi işləyir (30 saniyə
cooldown ilə). Linkə klikləmədən "Davam et" basanda "Hələ təsdiqlənməyib"
mesajı görünür.

2. Real qutunuzda gələn linkə klikləyin, tətbiqə qayıdıb "Davam et" basın.

**Gözlənilən:** indi Onboarding ekranına keçirsiniz, adi axın davam edir.

3. Google/Apple ilə qeydiyyatdan keçin (yeni hesab).

**Gözlənilən:** e-poçt təsdiqi ekranı HEÇ GÖRÜNMÜR — birbaşa Onboarding-ə
keçir (Google/Apple email-i artıq provayderin özü tərəfindən təsdiqlənmiş
sayılır).

4. (Əgər mövcud, KÖHNƏ bir test hesabınız varsa, bu düzəlişdən ƏVVƏL
   yaradılıb və heç vaxt e-poçtunu təsdiqləməyib) — həmin hesabla daxil
   olun.

**Gözlənilən:** normal daxil olur, Home-a keçir — RETROAKTİV olaraq
kilidlənmir (yalnız YENİ, hələ onboarding etməmiş hesablar bu yoxlamaya
tabedir).

## 3. `forwardMessage` — B3 düzəlişi

1. Bir söhbətdə şəkil/video göndərin.
2. Onu 2 FƏRQLİ söhbətə yönləndirin ("forward").
3. ORİJİNAL mesajı "hər kəs üçün sil" edin.

**Gözlənilən:** hər iki yönləndirilmiş nüsxə HƏLƏ DƏ öz şəkli/videosunu
göstərir (əvvəllər hər ikisi qırılırdı — 404).

## 4. Çat silinməsi kaskadı — B1 düzəlişi

1. Bir söhbəti silin ("Delete chat").
2. Firebase Console → Firestore → `chats/{chatId}/messages` — bir neçə
   dəqiqə sonra (trigger asinxrondur) alt-kolleksiyanın BOŞ olduğunu
   yoxlayın.
3. EYNİ iki nəfər YENİDƏN yazışsın.

**Gözlənilən:** köhnə mesajlar GERİ QAYITMIR (əvvəllər `chatIdFor`-un
determinizmi ucbatından geri qayıdırdı).

## 5. Release imzalama sərtləşdirməsi — C2

```bash
# key.properties-i müvəqqəti köçürün (və ya olmayan bir kopyada test edin)
mv android/key.properties android/key.properties.bak
cd android && ./gradlew assembleRelease
```

**Gözlənilən:** build AÇIQ-AŞKAR uğursuz olur, mesaj: "Release keystore
tapılmadı..." (əvvəllər sükutla debug-a keçib müvəffəqiyyətlə bitirdi).

```bash
./gradlew assembleRelease -PallowDebugSigning=true
```

**Gözlənilən:** bu dəfə uğurla bitir (debug imzası ilə, açıq-aşkar bayraqla).

```bash
mv android/key.properties.bak android/key.properties  # geri qaytarın
```

## 6. PAY-24 — hesab silinməsi

1. Test hesabı ilə bir PinBox sifarişi verin.
2. Həmin hesabı silin ("Delete account").
3. Firebase Console → Firestore → `pinboxOrders/{orderId}` — `buyerDeleted:
   true` olduğunu, `buyerId`-in HƏLƏ DƏ mövcud olduğunu (silinməyib)
   yoxlayın.

## 7. PAY-28 — düstur

Kodun özü artıq riyazi cəhətdən yoxlanılıb (bax əsas hesabat). Real bir
PinBox sifarişi tamamlayıb `venuePayouts/{orderId}.payoutAmount`-ın
`Math.floor`-a uyğun (heç vaxt yuxarı yuvarlaqlanmayan) olduğunu təsdiqləyə
bilərsiniz — məcburi deyil.

## 8. Play Console / App Store Connect bəyannamələri (D2)

Bu, kod deyil — əsas hesabatın D2 bölməsindəki addımları özünüz Play
Console-un "Data safety" formasında və App Store Connect-in "App Privacy"
bölməsində tamamlamalısınız.
