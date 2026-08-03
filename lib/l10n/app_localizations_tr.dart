// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get welcomeSubtitle => 'Çevrendeki insanları keşfet,\nyeni tanışıklıklar ve dostluklar kur.';

  @override
  String get welcomeStartButton => 'Başla';

  @override
  String get loginTitle => 'Giriş yap';

  @override
  String get loginUsernameLabel => 'Kullanıcı adı';

  @override
  String get loginUsernameHint => 'kullanici.adi';

  @override
  String get loginPasswordLabel => 'Şifre';

  @override
  String get loginPasswordHint => '••••••••';

  @override
  String get loginButtonLabel => 'Giriş yap';

  @override
  String get loginRegisterButtonLabel => 'Kayıt ol';

  @override
  String get loginForgotPasswordLabel => 'Şifremi unuttum?';

  @override
  String get loginAccountNotFoundError => 'Bu bilgilerle hesap bulunamadı.';

  @override
  String get loginTooManyAttemptsError => 'Çok fazla başarısız deneme. Kısa süre sonra tekrar deneyin ya da \"Şifremi unuttum\" ile sıfırlayın.';

  @override
  String get loginNetworkError => 'İnternet bağlantısı yok. Bağlantınızı kontrol edip tekrar deneyin.';

  @override
  String get loginRegisterPromptLabel => 'Kayıt olmak ister misiniz?';

  @override
  String get registerTitle => 'Kayıt ol';

  @override
  String get registerUsernameLabel => 'Kullanıcı adı';

  @override
  String get registerUsernameHint => 'kullanici.adi';

  @override
  String get registerUsernameCheckingLabel => 'Kontrol ediliyor...';

  @override
  String get registerUsernameTakenError => 'Bu kullanıcı adı zaten kullanılıyor.';

  @override
  String get registerUsernameInvalidFormatError => 'Kullanıcı adı yalnızca harf, rakam, . ve _ içerebilir (3-20 karakter).';

  @override
  String get registerPasswordLabel => 'Şifre';

  @override
  String get registerPasswordHint => 'En az 8 karakter';

  @override
  String get registerPasswordConfirmLabel => 'Şifre (tekrar)';

  @override
  String get registerPasswordConfirmHint => 'Şifreyi tekrar girin';

  @override
  String get registerPasswordTooShortError => 'Şifre en az 8 karakter olmalıdır.';

  @override
  String get registerPasswordMismatchError => 'Şifreler eşleşmiyor.';

  @override
  String get registerSubmitButton => 'Kaydı tamamla';

  @override
  String get registerGenericError => 'Kayıt tamamlanamadı. Lütfen daha sonra tekrar deneyin.';

  @override
  String get registerSuccessMessage => 'Kayıt tamamlandı, şimdi giriş yapabilirsiniz.';

  @override
  String get phoneAuthTitle => 'Telefon numaran';

  @override
  String get phoneAuthSubtitle => 'SMS ile gönderilecek koda ihtiyacın olacak.';

  @override
  String get phoneAuthNumberHint => '50 123 45 67';

  @override
  String get phoneAuthContinueButton => 'Telefon numarasıyla devam et';

  @override
  String get phoneAuthInvalidNumberError => 'Geçerli bir telefon numarası girin';

  @override
  String get phoneAuthVerificationFailedError => 'Numara doğrulanamadı, tekrar deneyin.';

  @override
  String get pickCountryTitle => 'Ülke seç';

  @override
  String get otpTitle => 'Kodu gir';

  @override
  String otpSubtitle(String phone) {
    return '$phone numarasına gönderilen 6 haneli kodu yaz.';
  }

  @override
  String get otpCodeHint => '••••••';

  @override
  String get otpConfirmButton => 'Onayla';

  @override
  String get otpIncompleteCodeError => '6 haneli kodun tamamını girin';

  @override
  String get otpInvalidCodeError => 'Kod yanlış veya süresi doldu.';

  @override
  String get otpResendButton => 'Kodu yeniden gönder';

  @override
  String otpResendWaitLabel(String time) {
    return 'Yeniden gönder: $time';
  }

  @override
  String get verificationRequiredTitle => 'Hesabını doğrula';

  @override
  String get verificationRequiredMessage => 'Bu özelliği kullanmak için önce hesabınızı doğrulamalısınız.';

  @override
  String get verificationRequiredButton => 'Hesabı doğrula';

  @override
  String get accountVerificationTitle => 'Hesabını doğrula';

  @override
  String get accountVerificationSubtitle => 'Telefon numaranızı doğrulayarak tüm özellikleri kullanabilirsiniz.';

  @override
  String get accountVerificationPhoneTakenError => 'Bu telefon numarası zaten başka bir hesapta kullanılıyor.';

  @override
  String get accountVerificationSuccessMessage => 'Hesabınız doğrulandı.';

  @override
  String get settingsAccountVerificationRowTitle => 'Hesabı doğrula';

  @override
  String get settingsAccountVerifiedRowSubtitle => 'Hesabınız doğrulandı';

  @override
  String get settingsIdentityVerificationRowTitle => 'Kimlik doğrulama';

  @override
  String get swipeMatchedMessage => 'Bu kullanıcıyla eşleştiniz!';

  @override
  String get swipeErrorMessage => 'Bir şeyler ters gitti. Lütfen daha sonra tekrar deneyin.';

  @override
  String get forgotPasswordTitle => 'Şifremi unuttum';

  @override
  String get forgotPasswordSubtitle => 'Hesabınıza bağlı telefon numarasını girin.';

  @override
  String get forgotPasswordAccountNotFoundError => 'Bu telefon numarasıyla ilişkili hesap bulunamadı.';

  @override
  String get newPasswordTitle => 'Yeni şifre';

  @override
  String get newPasswordSubtitle => 'Hesabınız için yeni bir şifre belirleyin.';

  @override
  String get newPasswordLabel => 'Yeni şifre';

  @override
  String get newPasswordHint => 'En az 8 karakter';

  @override
  String get newPasswordConfirmLabel => 'Yeni şifre (tekrar)';

  @override
  String get newPasswordConfirmHint => 'Şifreyi tekrar girin';

  @override
  String get newPasswordSubmitButton => 'Şifreyi güncelle';

  @override
  String get newPasswordSuccessMessage => 'Şifreniz güncellendi, şimdi giriş yapabilirsiniz.';

  @override
  String get newPasswordGenericError => 'Şifre güncellenemedi. Lütfen daha sonra tekrar deneyin.';

  @override
  String get changePasswordTitle => 'Şifreyi değiştir';

  @override
  String get changePasswordCurrentLabel => 'Mevcut şifre';

  @override
  String get changePasswordCurrentHint => 'Mevcut şifrenizi girin';

  @override
  String get changePasswordNewLabel => 'Yeni şifre';

  @override
  String get changePasswordNewHint => 'En az 8 karakter';

  @override
  String get changePasswordConfirmLabel => 'Yeni şifre (tekrar)';

  @override
  String get changePasswordConfirmHint => 'Şifreyi tekrar girin';

  @override
  String get changePasswordSubmitButton => 'Şifreyi güncelle';

  @override
  String get changePasswordWrongCurrentError => 'Mevcut şifre yanlış.';

  @override
  String get changePasswordSuccessMessage => 'Şifreniz güncellendi.';

  @override
  String get changePasswordGenericError => 'Şifre değiştirilemedi. Lütfen daha sonra tekrar deneyin.';

  @override
  String get onboardingAppBarTitle => 'Profilini tamamla';

  @override
  String get onboardingPhotoOptionalLabel => 'Fotoğraf ekle (isteğe bağlı)';

  @override
  String get fieldFirstNameLabel => 'Ad';

  @override
  String get fieldFirstNameHint => 'Rasim';

  @override
  String get fieldFirstNameRequiredError => 'Adını gir';

  @override
  String get fieldLastNameLabel => 'Soyad';

  @override
  String get fieldLastNameHint => 'Memmedov';

  @override
  String get fieldLastNameRequiredError => 'Soyadını gir';

  @override
  String get fieldBirthDateLabel => 'Doğum tarihi';

  @override
  String get fieldBirthDateHint => 'gg.aa.yyyy';

  @override
  String get birthDatePickerHelpText => 'Doğum tarihini seç';

  @override
  String get fieldGenderLabel => 'Cinsiyet';

  @override
  String get sectionCountryCityTitle => 'Ülke ve şehir';

  @override
  String get sectionAboutOptionalTitle => 'Hakkında (isteğe bağlı)';

  @override
  String get bioHintOnboarding => 'Kendinle ilgili birkaç cümle...';

  @override
  String get onboardingFinishButton => 'Tamamla ve devam et';

  @override
  String get onboardingSelectBirthDateError => 'Doğum tarihini seç';

  @override
  String get onboardingSelectGenderError => 'Cinsiyetini seç';

  @override
  String get onboardingSelectCountryCityError => 'Ülke ve şehrini seç';

  @override
  String get onboardingPhotoUploadFailedError => 'Fotoğraf yüklenemedi, daha sonra profilinden ekleyebilirsin.';

  @override
  String errorWithDetails(String error) {
    return 'Bir hata oluştu: $error';
  }

  @override
  String get navDiscoverLabel => 'Keşfet';

  @override
  String get navChatsLabel => 'Sohbet';

  @override
  String get navFeedLabel => 'Akış';

  @override
  String get navNotificationsLabel => 'Bildirimler';

  @override
  String get navProfileLabel => 'Profil';

  @override
  String get notificationsFeedTitle => 'Bildirimler';

  @override
  String get notifMenuMarkAllRead => 'Tümünü okundu işaretle';

  @override
  String get notifMenuDeleteRead => 'Okunanları sil';

  @override
  String get notifMenuSettings => 'Bildirim ayarları';

  @override
  String get notifEmptyTitle => 'Bildirim yok';

  @override
  String get notifEmptySubtitle => 'Yeni bildirimler burada görünecek.';

  @override
  String get notifErrorOfflineTitle => 'İnternet bağlantısı yok';

  @override
  String get notifErrorOfflineMessage => 'Bildirimleri yüklemek için internete bağlanın.';

  @override
  String get notifErrorPermissionTitle => 'İzin yok';

  @override
  String get notifErrorPermissionMessage => 'Bu bildirimleri görüntüleme izniniz yok.';

  @override
  String get notifErrorUnknownTitle => 'Bir hata oluştu';

  @override
  String get notifErrorUnknownMessage => 'Bildirimler yüklenemedi. Kısa süre sonra tekrar deneyin.';

  @override
  String get notifMarkAllReadDone => 'Tüm bildirimler okundu olarak işaretlendi';

  @override
  String get notifDeleteReadDone => 'Okunan bildirimler silindi';

  @override
  String get notifActionErrorMessage => 'İşlem başarısız oldu. Kısa süre sonra tekrar deneyin.';

  @override
  String get discoverTitle => 'Keşfet';

  @override
  String get viewSwitcherPeopleLabel => 'İnsanlar';

  @override
  String get viewSwitcherPlacesLabel => 'Mekanlar';

  @override
  String get viewSwitcherOffersLabel => 'Teklifler';

  @override
  String get genderFilterAll => 'Herkes';

  @override
  String get genderFilterMale => 'Erkek';

  @override
  String get genderFilterFemale => 'Kadın';

  @override
  String get genderFilterTooltip => 'Filtre';

  @override
  String get genderFilterSheetTitle => 'Cinsiyete göre filtrele';

  @override
  String get locationSearchingTitle => 'Konum belirleniyor...';

  @override
  String get locationSearchingSubtitle => 'Birkaç saniye sürebilir.';

  @override
  String get locationServiceDisabledTitle => 'Konum servisi kapalı';

  @override
  String get locationServiceDisabledSubtitle => 'Çevrendeki insanları görmek için cihazında konumu aç.';

  @override
  String get actionOpenSettings => 'Ayarları aç';

  @override
  String get locationPermissionDeniedTitle => 'Konum izni gerekiyor';

  @override
  String get locationPermissionDeniedSubtitle => 'Çevrendeki insanları görmek için izin ver.';

  @override
  String get actionRetry => 'Tekrar dene';

  @override
  String get chatPermissionDeniedMessage => 'Şu anda bu sohbete erişiminiz yok. Çıkış yapıp tekrar giriş yapmayı veya biraz sonra tekrar denemeyi deneyin.';

  @override
  String get chatLoadErrorMessage => 'Yüklenirken bir hata oluştu. Lütfen tekrar deneyin.';

  @override
  String get locationPermissionDeniedForeverTitle => 'İzin kalıcı olarak reddedildi';

  @override
  String get locationPermissionDeniedForeverSubtitle => 'Telefonunun ayarlarından \"Meevima\" için konum iznini elle aç.';

  @override
  String get actionOpenAppSettings => 'Uygulama ayarlarını aç';

  @override
  String get errorTitle => 'Bir hata oluştu';

  @override
  String get meMarkerLabel => 'Sen buradasın';

  @override
  String get defaultUserName => 'Kullanıcı';

  @override
  String get startChatButton => 'Sohbete başla';

  @override
  String get viewProfileButton => 'Profili görüntüle';

  @override
  String get chatMessageHint => 'Mesaj yaz...';

  @override
  String get chatRequestSentNotice => 'Mesaj isteği gönderildi';

  @override
  String get chatRequestBannerTitle => 'Mesaj isteği';

  @override
  String get chatRequestBannerSubtitle => 'Birbirinizle sohbet etmeye başlamak için kabul edin.';

  @override
  String get chatRequestAcceptButton => 'Kabul et';

  @override
  String get chatRequestDeclineButton => 'Reddet';

  @override
  String get chatRequestPendingNotice => 'Mesaj isteğinizin kabul edilmesini bekleyin.';

  @override
  String get chatRequestDeclinedNotice => 'Bu mesaj isteği reddedildi.';

  @override
  String get chatRequestDeclinedByPeerNotice => 'Bu kullanıcı mesaj isteğinizi reddetti.';

  @override
  String get chatRequestActionErrorMessage => 'İşlem tamamlanamadı. Lütfen birazdan tekrar deneyin.';

  @override
  String get chatOnlineStatus => 'Çevrimiçi';

  @override
  String get chatLastSeenUnknown => 'Çevrimdışı';

  @override
  String chatLastSeenAt(String time) {
    return 'Son görülme: $time';
  }

  @override
  String get chatTypingIndicator => 'yazıyor...';

  @override
  String get chatDateToday => 'Bugün';

  @override
  String get chatDateYesterday => 'Dün';

  @override
  String get chatMenuViewProfile => 'Profili görüntüle';

  @override
  String get chatMenuBlock => 'Kullanıcıyı engelle';

  @override
  String get chatMenuUnblock => 'Engeli kaldır';

  @override
  String get chatUserUnblockedNotice => 'Kullanıcının engeli kaldırıldı.';

  @override
  String get chatMenuReport => 'Kullanıcıyı bildir';

  @override
  String get chatMenuDeleteChat => 'Sohbeti sil';

  @override
  String get chatBlockConfirmTitle => 'Bu kullanıcıyı engelle?';

  @override
  String get chatBlockConfirmMessage => 'Artık sana mesaj gönderemeyecek.';

  @override
  String get chatDeleteConfirmTitle => 'Bu sohbeti sil?';

  @override
  String get chatDeleteConfirmMessage => 'Bu görüşme kalıcı olarak silinecek.';

  @override
  String get chatReportTitle => 'Kullanıcıyı bildir';

  @override
  String get chatReportReasonHint => 'Sorunu açıklayın...';

  @override
  String get chatReportSubmitButton => 'Bildirimi gönder';

  @override
  String get chatReportSentNotice => 'Bildiriminiz gönderildi, teşekkürler.';

  @override
  String get chatReportReasonInappropriate => 'Uygunsuz içerik';

  @override
  String get chatReportReasonFakeProfile => 'Sahte profil';

  @override
  String get chatReportReasonDangerous => 'Tehlikeli davranış';

  @override
  String get chatReportReasonOther => 'Diğer';

  @override
  String get chatSendBlockedError => 'Bu kullanıcıya mesaj gönderemezsiniz.';

  @override
  String get chatUserBlockedNotice => 'Kullanıcı engellendi.';

  @override
  String get chatEmptyConversation => 'Merhaba de 👋';

  @override
  String get chatEmptyStateTitle => 'İlk mesajı sen gönder';

  @override
  String get chatEmptyStateSubtitle => 'Aşağıdan yazarak sohbete başla ya da bir selamla buzları kır.';

  @override
  String get chatEmptyStateGreetingButton => 'Selam 👋';

  @override
  String get chatVoiceComingSoonMessage => 'Sesli mesajlar yakında eklenecek.';

  @override
  String get chatEmojiPickerTitle => 'Emoji seç';

  @override
  String get chatImageMessageLabel => 'Fotoğraf';

  @override
  String get chatVideoMessageLabel => 'Video';

  @override
  String get chatAudioMessageLabel => 'Sesli mesaj';

  @override
  String get chatSendButton => 'Gönder';

  @override
  String get chatRetakeButton => 'Yeniden çek';

  @override
  String get chatAttachmentSheetTitle => 'Medya seç';

  @override
  String get chatAttachmentImageOption => 'Fotoğraf';

  @override
  String get chatAttachmentVideoOption => 'Video';

  @override
  String get chatRecordingCancelHint => 'İptal etmek için kaydırın';

  @override
  String get chatRecordingLockHint => 'Kilitlemek için yukarı kaydırın';

  @override
  String get chatVoiceFinishButton => 'Bitir';

  @override
  String get chatVoiceTooShortMessage => 'Sesli mesaj çok kısa';

  @override
  String get chatMicPermissionDeniedMessage => 'Sesli mesaj göndermek için mikrofon erişimi gerekir.';

  @override
  String get chatCameraPermissionDeniedMessage => 'Fotoğraf çekmek için kamera erişimi gerekir.';

  @override
  String get chatMediaUploadFailedMessage => 'Gönderilemedi';

  @override
  String get chatMediaTooLargeMessage => 'Dosya çok büyük.';

  @override
  String get chatCallComingSoonMessage => 'Arama özelliği yakında aktif olacak.';

  @override
  String get chatVoiceCallLabel => 'Sesli arama';

  @override
  String get chatVideoCallLabel => 'Görüntülü arama';

  @override
  String get chatMessageDeleteForMeOption => 'Benden sil';

  @override
  String get chatMessageDeleteForEveryoneOption => 'Herkesten sil';

  @override
  String get chatMessageDeleteForEveryoneConfirmMessage => 'Bu mesaj her iki taraf için kalıcı olarak silinecek.';

  @override
  String get chatMessageDeleteOption => 'Sil';

  @override
  String get chatMessageForwardOption => 'İlet';

  @override
  String get chatForwardTitle => 'İlet';

  @override
  String get chatForwardEmptyMessage => 'İletebileceğiniz bir sohbet yok.';

  @override
  String chatForwardSendButton(int count) {
    return 'Gönder ($count)';
  }

  @override
  String get chatForwardSuccessMessage => 'Mesaj iletildi.';

  @override
  String get actionCancel => 'Vazgeç';

  @override
  String get actionDelete => 'Sil';

  @override
  String distanceMetersAway(int meters) {
    return '$meters m uzaklıkta';
  }

  @override
  String distanceKmAway(String km) {
    return '$km km uzaklıkta';
  }

  @override
  String distanceMilesAway(String mi) {
    return '$mi mil uzaklıkta';
  }

  @override
  String radiusPeopleCount(int count) {
    return '$count kişi';
  }

  @override
  String get radiusMoreButtonLabel => 'Daha fazla';

  @override
  String get radiusMorePanelTitle => 'Arama yarıçapı';

  @override
  String get premiumUpsellRadiusTitle => 'Daha uzaktaki insanları keşfet 🌍';

  @override
  String get premiumUpsellRadiusMessage => 'Premium üyelikle 5 km ve 10 km yarıçapındaki insanları görebilir ve daha çok insanla tanışabilirsin.';

  @override
  String get premiumUpgradeButton => 'Premium\'a geç';

  @override
  String get premiumLaterButton => 'Sonra';

  @override
  String get premiumComingSoonTitle => 'Premium';

  @override
  String get premiumComingSoonMessage => 'Premium üyelik yakında aktif olacak.';

  @override
  String get chatsTitle => 'Sohbetler';

  @override
  String get chatsEmptyTitle => 'Henüz sohbetin yok';

  @override
  String get chatsEmptySubtitle => 'Çevrendeki insanlarla tanıştığında sohbetlerin burada görünecek.';

  @override
  String get chatsSearchHint => 'Sohbetlerde ara';

  @override
  String get chatsSearchEmptyTitle => 'Sonuç bulunamadı';

  @override
  String get chatsSearchEmptySubtitle => 'Farklı bir ad, kullanıcı adı veya kelime deneyin.';

  @override
  String get chatsFilterAll => 'Tümü';

  @override
  String get chatsFilterUnread => 'Okunmamış';

  @override
  String get chatsFilterArchived => 'Arşivlenenler';

  @override
  String get chatsFilterRequests => 'İstekler';

  @override
  String get chatsUnreadEmptyTitle => 'Okunmamış mesaj yok';

  @override
  String get chatsUnreadEmptySubtitle => 'Tüm mesajlar okundu.';

  @override
  String get chatsArchivedEmptyTitle => 'Arşivlenmiş sohbet yok';

  @override
  String get chatsArchivedEmptySubtitle => 'Arşivlenen sohbetler burada görünecek.';

  @override
  String get chatsRequestsEmptyTitle => 'Mesaj isteği yok';

  @override
  String get chatsRequestsEmptySubtitle => 'Tanımadığınız kişilerden gelen ilk mesajlar burada görünecek.';

  @override
  String get chatsPinLimitReachedMessage => 'En fazla 3 sohbet sabitleyebilirsiniz.';

  @override
  String get chatsPinAction => 'Sabitle';

  @override
  String get chatsUnpinAction => 'Sabitlemeyi kaldır';

  @override
  String get chatsArchiveAction => 'Arşivle';

  @override
  String get chatsUnarchiveAction => 'Arşivden çıkar';

  @override
  String get chatsMuteAction => 'Sessize al';

  @override
  String get chatsUnmuteAction => 'Sesi aç';

  @override
  String get chatsPinnedSectionLabel => 'Sabitlenenler';

  @override
  String get chatsRecentSectionLabel => 'Son sohbetler';

  @override
  String get eventSaveButton => 'Kaydet';

  @override
  String get venueCreateTitle => 'Mekan profili';

  @override
  String get venueEditTitle => 'Mekanı düzenle';

  @override
  String get venuePhotoLabel => 'Fotoğraf/logo ekle';

  @override
  String get venuePhotoSheetTitle => 'Fotoğraf ekle';

  @override
  String get venuePhotoGalleryOption => 'Galeriden seç';

  @override
  String get venuePhotoCameraOption => 'Fotoğraf çek';

  @override
  String get venueNameLabel => 'Ad';

  @override
  String get venueNameHint => 'Mekanın adı';

  @override
  String get venueFieldRequiredError => 'Bu alan zorunludur';

  @override
  String get venueCategoryLabel => 'Hizmet alanı';

  @override
  String get venueCategoryPickerTitle => 'Hizmet alanı seç';

  @override
  String get venueCategorySearchHint => 'Kategori ara...';

  @override
  String get venueCategoryChangeHint => 'Değiştirmek için dokunun';

  @override
  String get venuePhotoCropTitle => 'Fotoğrafı kırp';

  @override
  String get venueUploadingLabel => 'Yükleniyor...';

  @override
  String get venueUploadCancelButton => 'İptal';

  @override
  String get venueDirectionsGoogleMaps => 'Google Maps';

  @override
  String get venueDirectionsAppleMaps => 'Apple Maps';

  @override
  String get venueDirectionsWaze => 'Waze';

  @override
  String get venueScheduleLabel => 'Haftalık program';

  @override
  String get venueFullAddressLabel => 'Tam adres';

  @override
  String get venuesSearchHint => 'Mekan ara...';

  @override
  String get venueFilterTooltip => 'Filtre';

  @override
  String get venueCategoryFilterTitle => 'Kategori seç';

  @override
  String get venueCategoryAllOption => 'Hepsi';

  @override
  String get offersSearchHint => 'Teklif ara...';

  @override
  String get offerFilterTooltip => 'Filtre';

  @override
  String get offersEmptyTitle => 'Henüz teklif yok';

  @override
  String get offersEmptySubtitle => 'Yakındaki mekanlardan teklifler burada görünecek.';

  @override
  String get offerCategoryFilterTitle => 'Kategori seç';

  @override
  String get offerCategoryAllOption => 'Tümü';

  @override
  String get offerBadgeDiscountSuffix => 'indirim';

  @override
  String get offerBadgeGiftLabel => 'Hediye';

  @override
  String get offerBadgeBuyOneGetOneLabel => '1+1';

  @override
  String get offerBadgeFixedPriceSuffix => 'AZN';

  @override
  String offerEndsOnLabel(String date) {
    return '$date tarihine kadar';
  }

  @override
  String get offerTermsLabel => 'Şartlar';

  @override
  String get offerValidityLabel => 'Geçerlilik süresi';

  @override
  String get offerStartDateLabel => 'Başlangıç';

  @override
  String get offerEndDateLabel => 'Bitiş';

  @override
  String get offerContactLabel => 'İletişim';

  @override
  String get offerOtherActiveOffersLabel => 'Diğer aktif teklifler';

  @override
  String get offerViewVenueProfileButton => 'Mekan profiline git';

  @override
  String get offerNotFoundMessage => 'Teklif bulunamadı.';

  @override
  String get offerGenericErrorMessage => 'İşlem başarısız oldu. Kısa süre sonra tekrar deneyin.';

  @override
  String get offerCreateTitle => 'Teklif oluştur';

  @override
  String get offerEditTitle => 'Teklifi düzenle';

  @override
  String get offerPhotoLabel => 'Fotoğraf/logo ekle';

  @override
  String get offerNameLabel => 'Teklif adı';

  @override
  String get offerNameHint => 'Teklifin adını yazın';

  @override
  String get offerCategoryLabel => 'Kategori seçin';

  @override
  String get offerTypeLabel => 'Teklif türü';

  @override
  String get offerTypeDiscountOption => 'İndirim';

  @override
  String get offerTypeGiftOption => 'Hediye';

  @override
  String get offerTypeBuyOneGetOneOption => '1+1 hediye';

  @override
  String get offerTypeFixedPriceOption => 'Sabit fiyat';

  @override
  String get offerDiscountAmountLabel => 'İndirim miktarı';

  @override
  String get offerFixedPriceLabel => 'Fiyat (AZN)';

  @override
  String get offerFixedPriceHint => 'Fiyatı yazın';

  @override
  String get offerDescriptionLabel => 'Kısa açıklama';

  @override
  String get offerDescriptionHint => 'Teklifin şartlarını ve avantajlarını yazın...';

  @override
  String get offerValidityPeriodLabel => 'Teklifin geçerlilik süresi';

  @override
  String get offerStartDatePickerLabel => 'Başlangıç tarihi';

  @override
  String get offerEndDatePickerLabel => 'Bitiş tarihi';

  @override
  String get offerVenuePickerLabel => 'Mekan seçin';

  @override
  String get offerVenuePickerHint => 'Mekan seçin';

  @override
  String get offerNoVenuesTitle => 'Henüz mekanınız yok';

  @override
  String get offerNoVenuesSubtitle => 'Teklif oluşturmak için önce bir mekan ekleyin.';

  @override
  String get offerAddVenueButton => 'Mekan ekle';

  @override
  String get offerTermsHint => 'Teklifin kullanım şartlarını yazın...';

  @override
  String get offerAdditionalInfoLabel => 'Ek bilgiler';

  @override
  String get offerContactPhoneHint => 'Telefon numarası';

  @override
  String get offerContactWebsiteHint => 'Web sitesi';

  @override
  String get offerContactInstagramHint => 'Instagram';

  @override
  String get offerSubmitButton => 'Teklifi oluştur';

  @override
  String get offerCreatedNotice => 'Teklif oluşturuldu';

  @override
  String get offerUpdatedNotice => 'Teklif güncellendi';

  @override
  String get offerRequiredFieldsMissing => 'Lütfen tüm zorunlu alanları doldurun.';

  @override
  String get offerDatesInvalidError => 'Bitiş tarihi başlangıç tarihinden sonra olmalıdır.';

  @override
  String get offerDeleteMenuOption => 'Teklifi sil';

  @override
  String get offerDeleteConfirmMessage => 'Bu teklifi silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.';

  @override
  String get offerDeletedNotice => 'Teklif silindi';

  @override
  String get offerStatusActive => 'Aktif';

  @override
  String get offerStatusExpired => 'Süresi doldu';

  @override
  String get offerMyOffersTitle => 'Tekliflerim';

  @override
  String get offerMyOffersEmptyTitle => 'Henüz hiç teklif eklemediniz';

  @override
  String get offerMyOffersEmptySubtitle => 'Eklediğiniz teklifler burada görünecek ve istediğiniz zaman düzenleyebilir veya silebilirsiniz.';

  @override
  String get offerMyOffersTooltip => 'Tekliflerim';

  @override
  String get offerAddButtonTooltip => 'Teklif oluştur';

  @override
  String get venueCategoryUnselectedLabel => 'Seçin';

  @override
  String get venueCategoryRestaurant => 'Restoran';

  @override
  String get venueCategoryPub => 'Pub';

  @override
  String get venueCategoryCoffeeShop => 'Coffee Shops';

  @override
  String get venueCategoryFastFood => 'Fast-Food';

  @override
  String get venueCategoryTeaHouse => 'Çayhane';

  @override
  String get venueCategorySweetsShop => 'Tatlıcı';

  @override
  String get venueCategoryHotel => 'Otel';

  @override
  String get venueCategoryMotel => 'Motel';

  @override
  String get venueCategoryCinema => 'Sinema';

  @override
  String get venueCategoryKaraoke => 'Karaoke Bar';

  @override
  String get venueCategoryGameHall => 'Oyun salonu';

  @override
  String get venueCategoryNightClub => 'Gece kulübü';

  @override
  String get venueCategoryFitness => 'Fitness';

  @override
  String get venueCategoryGym => 'GYM';

  @override
  String get venueCategorySpa => 'Spa, masaj ve sauna';

  @override
  String get venueCategoryFootballField => 'Futbol sahası';

  @override
  String get venueCategoryClinic => 'Klinik';

  @override
  String get venueCategoryBeautySalon => 'Güzellik salonu';

  @override
  String get venueCategoryBarbershop => 'Berber';

  @override
  String get venueCategoryCosmetology => 'Kozmetoloji';

  @override
  String get venueCategoryTattoo => 'Dövme ve piercing';

  @override
  String get venueCategoryPhotoStudio => 'Foto stüdyo';

  @override
  String get venueCategoryKidsEntertainment => 'Çocuk eğlencesi';

  @override
  String get venueCategoryOther => 'Diğer';

  @override
  String get venueHoursLabel => 'Açılış/kapanış saatleri';

  @override
  String get venueHours24Label => '24 saat açık';

  @override
  String get venueHoursSameEveryDayLabel => 'Her gün aynı saat';

  @override
  String get venueWeekdayMon => 'Pzt';

  @override
  String get venueWeekdayTue => 'Sal';

  @override
  String get venueWeekdayWed => 'Çar';

  @override
  String get venueWeekdayThu => 'Per';

  @override
  String get venueWeekdayFri => 'Cum';

  @override
  String get venueWeekdaySat => 'Cmt';

  @override
  String get venueWeekdaySun => 'Paz';

  @override
  String get venueLocationLabel => 'Adres/konum';

  @override
  String get venuePickOnMapButton => 'Haritadan seç';

  @override
  String get venueLocationPickedLabel => 'Haritada seçildi ✓';

  @override
  String get venueLocationPickerTitle => 'Konum seç';

  @override
  String get venueLocationPickerHint => 'Tam noktayı seçmek için haritaya dokunun veya pini sürükleyin';

  @override
  String get venueLocationResolvingAddress => 'Adres belirleniyor...';

  @override
  String get venueLocationAddressUnavailable => 'Adres bulunamadı';

  @override
  String get venueLocationPickerConfirmButton => 'Bu konumu seç';

  @override
  String get venueCreateButton => 'Ekle';

  @override
  String get venueSaveButton => 'Kaydet';

  @override
  String get venueRequiredFieldsMissing => 'Lütfen tüm zorunlu alanları doldurun.';

  @override
  String get venueGenericErrorMessage => 'İşlem tamamlanamadı. Lütfen birazdan tekrar deneyin.';

  @override
  String get venueAddButtonTooltip => 'Mekan ekle';

  @override
  String get venuesEmptyTitle => 'Yakında mekan yok';

  @override
  String get venuesEmptySubtitle => 'Seçtiğiniz yarıçapta henüz kimse mekan eklemedi.';

  @override
  String get venueMyVenuesTooltip => 'Mekanlarım';

  @override
  String get venueMyVenuesTitle => 'Mekanlarım';

  @override
  String get venueMyVenuesEmptyTitle => 'Henüz mekan eklemediniz';

  @override
  String get venueMyVenuesEmptySubtitle => 'Eklediğiniz mekanlar burada görünecek ve onları istediğiniz zaman düzenleyebilir veya silebilirsiniz.';

  @override
  String get venueDeleteMenuOption => 'Mekanı sil';

  @override
  String get venueDeleteConfirmMessage => 'Bu mekanı silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.';

  @override
  String get venueDeletedNotice => 'Mekan silindi';

  @override
  String get venueOpenNowLabel => 'Açık';

  @override
  String get venueClosedNowLabel => 'Kapalı';

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileNamePlaceholder => 'Adını ekle';

  @override
  String get profileBioPlaceholder => 'Fotoğraf, biyografi ve ilgi alanlarını ekle';

  @override
  String get shareProfileLabel => 'Profili paylaş';

  @override
  String get profileStatsFriends => 'Arkadaşlar';

  @override
  String get profileStatsLikes => 'Beğeniler';

  @override
  String get profileGalleryEmptyMessage => 'Henüz fotoğraf veya video yüklemediniz';

  @override
  String get editProfileTitle => 'Kişisel bilgiler';

  @override
  String get personalInfoSubtitle => 'Bilgilerinizi güncelleyin ve değişiklikleri kaydedin.';

  @override
  String get profileSaveSuccessMessage => 'Bilgileriniz güncellendi.';

  @override
  String get menuSettings => 'Ayarlar';

  @override
  String get menuPrivacySecurity => 'Gizlilik ve güvenlik';

  @override
  String get privacySecurityTitle => 'Gizlilik ve güvenlik';

  @override
  String get privacyProfileVisibilityTitle => 'Medya görünürlüğü';

  @override
  String get privacyProfileVisibilitySubtitle => 'Profilinizdeki paylaşımları kimlerin görebileceğini seçin.';

  @override
  String get privacyVisibilityEveryone => 'Herkes';

  @override
  String get privacyVisibilityFollowersOnly => 'Takip ve Takipçiler';

  @override
  String get privacyVisibilityNoOne => 'Hiç kimse';

  @override
  String get privacyClosedProfileNotice => 'Kapalı profil';

  @override
  String get privacyRadiusTitle => 'Görünürlük yarıçapı';

  @override
  String get privacyRadiusCountryLabel => 'Ülkeye göre';

  @override
  String get privacyRadiusWorldLabel => 'Dünya çapında';

  @override
  String get privacyOnlineStatusTitle => 'Çevrimiçi olduğumu göster';

  @override
  String get privacyReadReceiptsTitle => 'Okundu bilgisini göster';

  @override
  String get privacyReadReceiptsHelperText => 'Bunu kapatırsanız karşı tarafın okundu durumunu da göremezsiniz.';

  @override
  String get privacyWhoCanMessageTitle => 'Bana kim mesaj gönderebilir';

  @override
  String get privacyMessagePermEveryone => 'Herkes';

  @override
  String get privacyMessagePermVerifiedOnly => 'Yalnızca doğrulanmış kullanıcılar';

  @override
  String get privacyMessagePermNoOne => 'Hiç kimse';

  @override
  String get privacyGhostModeTitle => 'Ghost Mode';

  @override
  String get privacyGhostModeDescription => 'Diğer kullanıcıları görebilirsiniz. Diğer kullanıcılar sizi haritada göremez. İstediğiniz zaman açıp kapatabilirsiniz.';

  @override
  String get privacyGhostModePremiumTitle => 'Ghost Mode ile görünmez olun 👻';

  @override
  String get privacyGhostModePremiumMessage => 'Premium ile diğer kullanıcıları görebilirsiniz, ancak onlar sizi haritada göremez.';

  @override
  String get privacySettingUpdateErrorMessage => 'Değişiklik kaydedilemedi. Lütfen birazdan tekrar deneyin.';

  @override
  String get privacyTwoFactorTitle => 'İki aşamalı doğrulamayı etkinleştir';

  @override
  String get privacyTwoFactorHelperText => 'Şimdilik yalnızca seçiminiz kaydedilir — SMS ve Authenticator desteği yakında eklenecek.';

  @override
  String get privacyExportDataTitle => 'Verilerimi indir';

  @override
  String get privacyExportDataDescription => 'Uygulamada saklanan verileriniz hazırlanıp size sunulacak.';

  @override
  String get exportDataScreenTitle => 'Verilerim';

  @override
  String get exportDataCopyButton => 'Kopyala';

  @override
  String get exportDataCopiedNotice => 'Veriler panoya kopyalandı.';

  @override
  String get exportDataLoadErrorMessage => 'Verileriniz yüklenemedi. Lütfen tekrar deneyin.';

  @override
  String get privacyDeleteAccountTitle => 'Hesabımı sil';

  @override
  String get deleteAccountWarningTitle => 'Hesabınızı silmek istediğinizden emin misiniz?';

  @override
  String get deleteAccountWarningMessage => 'Profiliniz, sohbetleriniz ve tüm verileriniz kalıcı olarak silinecek. Bu işlem geri alınamaz.';

  @override
  String get deleteAccountFinalConfirmTitle => 'Son onay';

  @override
  String get deleteAccountFinalConfirmMessage => 'Hesabınızı silmek üzeresiniz. Bu adımdan sonra geri dönüş yoktur.';

  @override
  String get deleteAccountConfirmButton => 'Evet, hesabımı sil';

  @override
  String get deleteAccountReauthTitle => 'Kimliğinizi doğrulayın';

  @override
  String get deleteAccountReauthMessage => 'Güvenlik için, hesabı silmeden önce telefon numaranızı yeniden doğrulamanız gerekir.';

  @override
  String get deleteAccountSendCodeButton => 'Kod gönder';

  @override
  String get deleteAccountCodeSentMessage => 'Kod gönderildi';

  @override
  String get deleteAccountOtpHint => 'SMS kodu';

  @override
  String get deleteAccountConfirmCodeButton => 'Onayla';

  @override
  String get deleteAccountReauthFailedMessage => 'Doğrulama başarısız oldu. Lütfen tekrar deneyin.';

  @override
  String get deleteAccountErrorMessage => 'Hesap silinemedi. Lütfen birazdan tekrar deneyin.';

  @override
  String get blockedUsersTitle => 'Engellenen kullanıcılar';

  @override
  String get blockedUsersEmptyTitle => 'Engellenen kullanıcı yok';

  @override
  String get blockedUsersEmptySubtitle => 'Engellediğiniz kullanıcılar burada görünecek.';

  @override
  String get menuNotifications => 'Bildirimler';

  @override
  String get menuHelp => 'Yardım';

  @override
  String get menuLogout => 'Çıkış yap';

  @override
  String uploadingProgress(String percent) {
    return '%$percent yükleniyor...';
  }

  @override
  String get removePhotoButton => 'Fotoğrafı sil';

  @override
  String get fieldAgeLabel => 'Yaş';

  @override
  String get fieldAgeHint => '25';

  @override
  String get fieldEmailOptionalLabel => 'E-posta (zorunlu değil)';

  @override
  String get fieldEmailHint => 'ornek@email.com';

  @override
  String get sectionAboutTitle => 'Hakkında';

  @override
  String get bioHintEdit => 'Kendinle ilgili birkaç cümle yaz...';

  @override
  String get saveButton => 'Kaydet';

  @override
  String get waitPhotoUploadError => 'Fotoğrafın yüklenmesini bekleyin...';

  @override
  String get invalidEmailError => 'Geçerli bir e-posta girin';

  @override
  String saveFailedError(String error) {
    return 'Kaydedilemedi: $error';
  }

  @override
  String get photoOperationFailedError => 'Fotoğraf işlemi başarısız oldu.';

  @override
  String get storageErrorFileTooLarge => 'Fotoğraf 5MB\'tan büyük olamaz.';

  @override
  String get storageErrorInvalidContentType => 'Desteklenmeyen dosya biçimi.';

  @override
  String get storageErrorUploadFailed => 'Fotoğraf yüklenemedi.';

  @override
  String get storageErrorDownloadUrlFailed => 'Fotoğraf yüklenemedi.';

  @override
  String get storageErrorDeleteFailed => 'Fotoğraf silinemedi.';

  @override
  String get storageErrorPermissionDenied => 'Bu işlem için izniniz yok.';

  @override
  String get storageErrorUnauthenticated => 'Oturum açmadınız.';

  @override
  String get storageErrorUnknown => 'Bilinmeyen bir depolama hatası oluştu.';

  @override
  String get comingSoonDefaultMessage => 'Bu özellik yakında aktif olacak.';

  @override
  String get pickCountryHint => 'Ülke ara';

  @override
  String get pickCityTitle => 'Şehir seç';

  @override
  String get pickCityHint => 'Şehir ara';

  @override
  String get searchNotFound => 'Sonuç bulunamadı';

  @override
  String get fieldCountryLabel => 'Ülke';

  @override
  String get fieldCitySelectFirstHint => 'Önce ülke seç';

  @override
  String get fieldCityLabel => 'Şehir';

  @override
  String get contactRequiredError => 'E-posta veya numaranı gir';

  @override
  String get contactInvalidError => 'Geçerli bir e-posta veya numara gir';

  @override
  String get stampLike => 'BEĞEN';

  @override
  String get stampReject => 'REDDET';

  @override
  String get stampSuper => 'SÜPER';

  @override
  String get emptyStackTitle => 'Çevrende henüz kimse yok';

  @override
  String get emptyStackSubtitle => 'Yarıçapı veya filtreyi değiştirmeyi deneyin.';

  @override
  String get discoverActiveNowLabel => 'Şu an aktif';

  @override
  String get discoverSwipeUpHint => 'Sonraki kart için yukarı kaydır';

  @override
  String get discoverMatchTitle => 'Eşleşme!';

  @override
  String get discoverMatchMessage => 'Birbirinizi beğendiniz!';

  @override
  String get discoverMatchLaterButton => 'Sonra';

  @override
  String get storyVisibilitySheetTitle => 'Kimler görebilir?';

  @override
  String get storyVisibilityPickPrompt => 'Kimler görebilir?';

  @override
  String get storyVisibilityFollowers => 'Takip ve Takipçiler';

  @override
  String get storyVisibilityEveryone => 'Herkes';

  @override
  String get storyShareButton => 'Paylaş';

  @override
  String get storyVideoTooLongMessage => 'Video en fazla 60 saniye olabilir';

  @override
  String get storyShareErrorMessage => 'Paylaşılamadı. Lütfen daha sonra tekrar deneyin.';

  @override
  String get storyViewersEmptyMessage => 'Henüz kimse görüntülemedi';

  @override
  String get storyViewersTitle => 'Görüntüleyenler';

  @override
  String get postCaptureSheetTitle => 'Gönderi ekle';

  @override
  String get postCameraOption => 'Kamerayla çek';

  @override
  String get postGalleryPhotoOption => 'Fotoğraf seç';

  @override
  String get postGalleryVideoOption => 'Video seç';

  @override
  String get postShareButton => 'Paylaş';

  @override
  String get postShareErrorMessage => 'Gönderi paylaşılamadı. Lütfen daha sonra tekrar deneyin.';

  @override
  String get postFeedEmptyMessage => 'Henüz gönderi yok';

  @override
  String get postCommentsSheetTitle => 'Yorumlar';

  @override
  String get postCommentsEmptyMessage => 'Henüz yorum yok';

  @override
  String get postCommentHint => 'Yorum yaz...';

  @override
  String get postCommentSendButton => 'Gönder';

  @override
  String get postCommentErrorMessage => 'Yorum gönderilmedi. Lütfen daha sonra tekrar deneyin.';

  @override
  String get postLikeErrorMessage => 'Beğeni kaydedilmedi. Lütfen daha sonra tekrar deneyin.';

  @override
  String get feedSearchHint => 'Ara';

  @override
  String get feedSearchNoResultsMessage => 'Sonuç bulunamadı';

  @override
  String get feedDownloadVideoOption => 'Videoyu indir';

  @override
  String feedDownloadInProgressMessage(int percent) {
    return 'İndiriliyor... %$percent';
  }

  @override
  String get feedDownloadCompleteMessage => 'Video galerinize indirildi';

  @override
  String get feedDownloadErrorMessage => 'Video indirilemedi. Lütfen daha sonra tekrar deneyin.';

  @override
  String get postTimeJustNow => 'Az önce';

  @override
  String postTimeMinutesAgo(int count) {
    return '$count dakika önce';
  }

  @override
  String postTimeHoursAgo(int count) {
    return '$count saat önce';
  }

  @override
  String postTimeDaysAgo(int count) {
    return '$count gün önce';
  }

  @override
  String postTimeWeeksAgo(int count) {
    return '$count hafta önce';
  }

  @override
  String get postCaptionHint => 'Açıklama yaz...';

  @override
  String get postMenuEdit => 'Düzenle';

  @override
  String get postMenuDelete => 'Sil';

  @override
  String get postEditCaptionTitle => 'Açıklamayı düzenle';

  @override
  String get postEditCaptionSave => 'Kaydet';

  @override
  String get postEditCaptionErrorMessage => 'Kaydedilmedi. Lütfen daha sonra tekrar deneyin.';

  @override
  String get postDeleteConfirmTitle => 'Bu gönderiyi silmek istediğinizden emin misiniz?';

  @override
  String get postDeleteConfirmMessage => 'Bu işlem geri alınamaz.';

  @override
  String get postDeleteErrorMessage => 'Gönderi silinmedi. Lütfen daha sonra tekrar deneyin.';

  @override
  String get storyDeleteConfirmTitle => 'Bu hikayeyi silmek istediğinizden emin misiniz?';

  @override
  String get storyDeleteConfirmMessage => 'Bu işlem geri alınamaz.';

  @override
  String get storyDeleteErrorMessage => 'Hikaye silinmedi. Lütfen daha sonra tekrar deneyin.';

  @override
  String get viewActiveStoryButton => 'Hikayeyi izle';

  @override
  String get postReplyAction => 'Yanıtla';

  @override
  String postReplyingToLabel(String name) {
    return '$name yanıtlanıyor';
  }

  @override
  String get postCommentDeleteConfirmTitle => 'Bu yorumu silmek istediğinizden emin misiniz?';

  @override
  String get postCommentDeleteErrorMessage => 'Yorum silinmedi. Lütfen daha sonra tekrar deneyin.';

  @override
  String get postCommentEditErrorMessage => 'Yorum güncellenmedi. Lütfen daha sonra tekrar deneyin.';

  @override
  String get postShareOptionsSheetTitle => 'Paylaş';

  @override
  String get postShareToChatOption => 'Sohbette gönder';

  @override
  String get postShareExternalOption => 'Diğer uygulamalarla paylaş';

  @override
  String get postSendToSheetTitle => 'Kime gönder?';

  @override
  String get postSendToEmptyMessage => 'Henüz sohbetiniz yok';

  @override
  String get postSentToChatSuccessMessage => 'Gönderi gönderildi';

  @override
  String get postSentToChatErrorMessage => 'Gönderi gönderilemedi. Lütfen daha sonra tekrar deneyin.';

  @override
  String get chatPostMessageLabel => 'Gönderi';

  @override
  String get friendRequestSendButton => 'Arkadaşlık gönder';

  @override
  String get friendRequestSentLabel => 'Gönderildi';

  @override
  String get friendRequestPendingLabel => 'Beklemede';

  @override
  String get friendRequestAcceptedLabel => 'Arkadaşsınız';

  @override
  String get friendRequestDeclinedLabel => 'Reddedildi';

  @override
  String get friendRequestErrorMessage => 'İstek gönderilemedi. Lütfen daha sonra tekrar deneyin.';

  @override
  String get sendMessageButton => 'Mesaj yaz';

  @override
  String get followButton => 'Takip et';

  @override
  String get followingButton => 'Takip ediliyor';

  @override
  String get followErrorMessage => 'Bir şeyler ters gitti. Lütfen daha sonra tekrar deneyin.';

  @override
  String get profileStatsFollowing => 'Takip';

  @override
  String get profileStatsFollowers => 'Takipçi';

  @override
  String get settingsTitle => 'Ayarlar';

  @override
  String get settingsLanguageRowLabel => 'Dil';

  @override
  String get languagePickerTitle => 'Dil seç';

  @override
  String get settingsAccountRowTitle => 'Hesap';

  @override
  String get settingsAccountRowSubtitle => 'Kişisel bilgiler, telefon, e-posta, şifre';

  @override
  String get changePhotoScreenTitle => 'Profil fotoğrafını değiştir';

  @override
  String get settingsChangePhotoRowSubtitle => 'Profil fotoğrafınızı güncelleyin veya kaldırın';

  @override
  String get settingsPrivacyRowSubtitle => 'Görünürlük, engellemeler, aktif cihazlar vb.';

  @override
  String get settingsNotificationsRowSubtitle => 'Mesajlar, push bildirimleri';

  @override
  String get settingsLanguageRowSubtitle => 'Uygulama dili seçimi';

  @override
  String get settingsIdentityRowSubtitle => 'Kimliğini doğrula, güvenilir profil rozeti kazan';

  @override
  String get settingsVipRowTitle => 'Meevima VIP';

  @override
  String get settingsVipRowSubtitle => 'VIP\'e geç, paketini yönet';

  @override
  String get settingsVipActiveLabel => 'Aktif';

  @override
  String get settingsVipBadgeLabel => 'VIP';

  @override
  String get settingsMapRowTitle => 'Harita ve Konum';

  @override
  String get settingsMapRowSubtitle => 'Harita türü, mesafe birimi, GPS';

  @override
  String get settingsPaymentsRowTitle => 'Ödemeler';

  @override
  String get settingsPaymentsRowSubtitle => 'Ödeme geçmişi, kartlar, abonelik';

  @override
  String get settingsHelpRowTitle => 'Yardım';

  @override
  String get settingsHelpRowSubtitle => 'SSS, bize ulaşın, sorun bildirin';

  @override
  String get settingsLegalRowTitle => 'Yasal';

  @override
  String get settingsLegalRowSubtitle => 'Gizlilik politikası, kullanım şartları';

  @override
  String get settingsAboutRowTitle => 'Hakkında';

  @override
  String get settingsAboutRowSubtitle => 'Sürüm, yenilikler, sosyal medya';

  @override
  String get settingsLogoutRowTitle => 'Çıkış';

  @override
  String get settingsLogoutRowSubtitle => 'Hesaptan çıkış yap';

  @override
  String get notificationsScreenTitle => 'Bildirimler';

  @override
  String get notifMessagesTitle => 'Mesajlar';

  @override
  String get notifMessagesSubtitle => 'Yeni mesaj geldiğinde bildirim al';

  @override
  String get notifFollowersTitle => 'Takipçiler';

  @override
  String get notifFollowersSubtitle => 'Yeni takipçiler ve takip istekleri';

  @override
  String get notifNewUsersTitle => 'Yeni kullanıcılar';

  @override
  String get notifNewUsersSubtitle => 'Yakında yeni bir kullanıcı katıldığında';

  @override
  String get notifLikesTitle => 'Beğeniler';

  @override
  String get notifLikesSubtitle => 'Biri seni beğendiğinde bildirim al';

  @override
  String get notifCommentsTitle => 'Yorumlar';

  @override
  String get notifCommentsSubtitle => 'Yorum ve tepkiler için bildirim al';

  @override
  String get notifVenueOffersTitle => 'Mekan teklifleri';

  @override
  String get notifVenueOffersSubtitle => 'Takip ettiğin mekanlardan yeni teklifler';

  @override
  String get notifVenueUpdatesTitle => 'Mekan güncellemeleri';

  @override
  String get notifVenueUpdatesSubtitle => 'Mekan eklenmesi ve onaylanması hakkında';

  @override
  String get notifSecurityTitle => 'Güvenlik';

  @override
  String get notifSecuritySubtitle => 'Hesabınla ilgili önemli güvenlik uyarıları';

  @override
  String get notifSystemTitle => 'Sistem bildirimleri';

  @override
  String get notifSystemSubtitle => 'Uygulamayla ilgili önemli duyurular';

  @override
  String get notifMarketingTitle => 'Pazarlama';

  @override
  String get notifMarketingSubtitle => 'Kampanya ve indirimlerden haberdar ol';

  @override
  String get notifPushTitle => 'Push bildirimleri';

  @override
  String get notifEmailTitle => 'E-posta bildirimleri';

  @override
  String get notifUpdateErrorMessage => 'Değişiklik kaydedilmedi. Lütfen daha sonra tekrar deneyin.';

  @override
  String get mapLocationScreenTitle => 'Harita ve Konum';

  @override
  String get mapTypeTitle => 'Harita tipi';

  @override
  String get mapTypeStandard => 'Standart';

  @override
  String get mapTypeSatellite => 'Uydu';

  @override
  String get mapTypeHybrid => 'Hibrit';

  @override
  String get distanceUnitTitle => 'Mesafe birimi';

  @override
  String get distanceUnitKm => 'Kilometre';

  @override
  String get distanceUnitMi => 'Mil';

  @override
  String get gpsAccuracyTitle => 'GPS hassasiyeti';

  @override
  String get gpsAccuracyHigh => 'Yüksek';

  @override
  String get gpsAccuracyStandard => 'Standart';

  @override
  String get backgroundLocationTitle => 'Arka plan konumu';

  @override
  String get backgroundLocationSubtitle => 'Uygulama arka plandayken konumun güncellensin';

  @override
  String get backgroundLocationDeniedMessage => 'Arka plan konumunu etkinleştirmek için Ayarlar > Uygulamalar bölümünden \"Her zaman izin ver\"i seçin.';

  @override
  String get mapLocationUpdateErrorMessage => 'Değişiklik kaydedilmedi. Lütfen daha sonra tekrar deneyin.';

  @override
  String get helpScreenTitle => 'Yardım';

  @override
  String get helpFaqSectionTitle => 'Sık sorulan sorular';

  @override
  String get helpFaq1Question => 'Meevima nasıl çalışır?';

  @override
  String get helpFaq1Answer => 'Uygulama konumunu kullanarak yakınındaki diğer kullanıcıları sana gösterir. Keşfet sekmesinden yarıçapı ve filtreleri seçebilirsin.';

  @override
  String get helpFaq2Question => 'Konumumu kim görebilir?';

  @override
  String get helpFaq2Answer => 'Diğer kullanıcılara yalnızca yaklaşık mesafen gösterilir, kesin koordinatların paylaşılmaz. Ayarlar > Gizlilik ve Güvenlik bölümünden Ghost Mode\'u açarak tamamen gizlenebilirsin.';

  @override
  String get helpFaq3Question => 'Hesabımı nasıl silebilirim?';

  @override
  String get helpFaq3Answer => 'Ayarlar > Hesap > Hesabımı sil bölümünden hesabını kalıcı olarak silebilirsin. Bu işlem geri alınamaz.';

  @override
  String get helpFaq4Question => 'Biri beni rahatsız ediyorsa ne yapmalıyım?';

  @override
  String get helpFaq4Answer => 'İstediğin zaman herhangi bir profilden o kullanıcıyı engelleyebilir veya şikayet edebilirsin. Engellenen kullanıcı seni bir daha göremez.';

  @override
  String get helpFaq5Question => 'Meevima VIP ne işe yarar?';

  @override
  String get helpFaq5Answer => 'VIP üyelik genişletilmiş görünürlük yarıçapı, Ghost Mode ve ek filtreler sunar.';

  @override
  String get helpFaq6Question => 'Görünürlük yarıçapımı nasıl değiştirebilirim?';

  @override
  String get helpFaq6Answer => 'Keşfet sekmesinde haritanın altındaki yarıçap seçiciden istediğin mesafeyi seçebilirsin.';

  @override
  String get helpContactRowTitle => 'Bizimle iletişime geç';

  @override
  String get helpContactRowSubtitle => 'Sorularınız için bize yazın';

  @override
  String get helpReportProblemRowTitle => 'Sorun bildir';

  @override
  String get helpReportProblemRowSubtitle => 'Karşılaştığın teknik sorunu bize bildir';

  @override
  String get helpSendSuggestionRowTitle => 'Öneri gönder';

  @override
  String get helpSendSuggestionRowSubtitle => 'Uygulamayı nasıl geliştirelim?';

  @override
  String get contactUsSheetTitle => 'Bizimle iletişime geç';

  @override
  String get contactUsEmailCopiedNotice => 'E-posta adresi kopyalandı';

  @override
  String get contactUsSendEmailButton => 'E-posta gönder';

  @override
  String get reportProblemSheetTitle => 'Sorun bildir';

  @override
  String get sendSuggestionSheetTitle => 'Öneri gönder';

  @override
  String get supportMessageHint => 'Mesajını buraya yaz...';

  @override
  String get supportMessageSendButton => 'Gönder';

  @override
  String get supportMessageSentNotice => 'Mesajın gönderildi. Teşekkürler!';

  @override
  String get supportMessageErrorMessage => 'Mesaj gönderilmedi. Lütfen daha sonra tekrar deneyin.';

  @override
  String get legalPrivacyPolicyTitle => 'Gizlilik Politikası';

  @override
  String get legalTermsOfServiceTitle => 'Kullanım Şartları';

  @override
  String get legalLicensesTitle => 'Lisanslar';

  @override
  String get aboutWhatsNewTitle => 'Yenilikler';

  @override
  String get aboutSocialMediaTitle => 'Sosyal medya';

  @override
  String get aboutSocialMediaComingSoonLabel => 'Yakında';

  @override
  String get aboutCopyrightText => '© 2026 Meevima. Tüm hakları saklıdır.';

  @override
  String get aboutChangelogV1Title => 'v1.0.0';

  @override
  String get aboutChangelogV1Body => 'İlk sürüm: yakındaki kullanıcıları keşfet, arkadaşlık istekleri, sohbetler, hikayeler ve profil yönetimi.';

  @override
  String get vipHeaderTitle => 'Meevima VIP';

  @override
  String get vipHeaderSubtitle => 'Genişletilmiş özelliklerle daha çok insanla tanış';

  @override
  String get vipChoosePackageTitle => 'Paket seç';

  @override
  String get vipPeriodMonthly => 'Aylık';

  @override
  String get vipPeriodQuarterly => '3 Aylık';

  @override
  String get vipPeriodYearly => 'Yıllık';

  @override
  String get vipBestValueBadge => 'En avantajlı';

  @override
  String get vipPriceComingSoonNote => 'Mağaza bağlantısı aktif olduğunda fiyatlar burada gösterilecek.';

  @override
  String get vipSubscribeButton => 'Abone ol';

  @override
  String get vipAlreadySubscribedButton => 'Zaten VIP\'siniz';

  @override
  String get vipBillingComingSoonMessage => 'Ödeme sistemi yakında etkinleştirilecek.';

  @override
  String get vipCurrentPackageTitle => 'Mevcut paket';

  @override
  String get vipCurrentPackageActiveLabel => 'Aktif';

  @override
  String get vipManageButton => 'Yönet';

  @override
  String get vipFeatureGhostTitle => 'Ghost Mode';

  @override
  String get vipFeatureGhostDescription => 'Diğer kullanıcıları gör, ama sen haritada görünme.';

  @override
  String get vipFeatureRadiusTitle => 'Genişletilmiş yarıçap';

  @override
  String get vipFeatureRadiusDescription => '5 km ve 10 km yarıçapındaki insanları keşfet.';

  @override
  String get vipFeatureFilterTitle => 'Ek filtreler';

  @override
  String get vipFeatureFilterDescription => 'Cinsiyet ve diğer filtrelerle aramanı daraltın.';

  @override
  String get accountScreenTitle => 'Hesap';

  @override
  String get accountPersonalInfoTitle => 'Kişisel bilgiler';

  @override
  String get accountPhoneRowTitle => 'Telefon numarası';

  @override
  String get accountEmailRowTitle => 'E-posta';

  @override
  String get accountEmailEmptyValue => 'Eklenmemiş';

  @override
  String get accountPasswordRowTitle => 'Şifreyi değiştir';

  @override
  String get accountPhoneUnsetValue => 'Doğrulanmadı';

  @override
  String get accountChangeEmailSheetTitle => 'E-postayı değiştir';

  @override
  String get accountNewEmailLabel => 'Yeni e-posta adresi';

  @override
  String get accountEmailInvalidError => 'Geçerli bir e-posta adresi girin';

  @override
  String get accountEmailUpdatedNotice => 'E-posta güncellendi';

  @override
  String get accountDeleteRowTitle => 'Hesabı sil';

  @override
  String get accountDeleteRowSubtitle => 'Hesabınızı ve tüm verilerinizi silin';

  @override
  String get accountDeleteConfirmWordLabel => 'Onaylamak için aşağıya \"SİL\" yazın';

  @override
  String get accountDeleteConfirmWordHint => 'SİL';

  @override
  String get accountDeleteConfirmWordMismatchError => 'Devam etmek için \"SİL\" yazın';

  @override
  String get paymentsScreenTitle => 'Ödemeler';

  @override
  String get paymentHistoryRowTitle => 'Ödeme geçmişi';

  @override
  String get myCardsTitle => 'Kartlarım';

  @override
  String get addCardButton => 'Kart ekle';

  @override
  String get noCardsMessage => 'Henüz kart eklenmedi';

  @override
  String get cardOptionsSetDefault => 'Varsayılan yap';

  @override
  String get cardOptionsDelete => 'Sil';

  @override
  String get paymentHistoryEmptyMessage => 'Henüz işlem yok';

  @override
  String get paymentTypePurchase => 'Satın alma';

  @override
  String get paymentTypeRenewal => 'Yenileme';

  @override
  String get paymentTypeCancellation => 'İptal';

  @override
  String get paymentTypeRefund => 'İade';

  @override
  String get activeDevicesTitle => 'Aktif cihazlar';

  @override
  String get privacyActiveDevicesSubtitle => 'Aktif cihazlarınızın listesi';

  @override
  String get activeDevicesEmptyMessage => 'Aktif cihaz bulunamadı';

  @override
  String get thisDeviceLabel => 'Bu cihaz';

  @override
  String get lastActiveLabel => 'Son aktiflik';

  @override
  String get signOutDeviceButton => 'Çıkış yap';

  @override
  String get signOutDeviceConfirmTitle => 'Bu cihazdan çıkış yapılsın mı?';

  @override
  String get signOutDeviceConfirmMessage => 'Bu cihaz hesaptan uzaktan çıkış yaptırılacak. Çevrimdışıysa, bir sonraki bağlantısında çıkış yapılacak.';

  @override
  String get signOutDeviceErrorMessage => 'Çıkış yapılamadı. Lütfen daha sonra tekrar deneyin.';

  @override
  String get privacyTwoFactorActivateTitle => 'İki aşamalı doğrulamayı etkinleştir';

  @override
  String get privacyTwoFactorDisableButton => 'Kapat';
}
