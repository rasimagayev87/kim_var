// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Azerbaijani (`az`).
class AppLocalizationsAz extends AppLocalizations {
  AppLocalizationsAz([String locale = 'az']) : super(locale);

  @override
  String get welcomeSubtitle => 'Ətrafındakı insanları kəşf et,\nyeni tanışlıqlar və dostluqlar qur.';

  @override
  String get welcomeStartButton => 'Başla';

  @override
  String get loginTitle => 'Daxil ol';

  @override
  String get loginUsernameLabel => 'İstifadəçi adı';

  @override
  String get loginUsernameHint => 'istifadeci.adi';

  @override
  String get loginPasswordLabel => 'Parol';

  @override
  String get loginPasswordHint => '••••••••';

  @override
  String get loginButtonLabel => 'Daxil ol';

  @override
  String get loginRegisterButtonLabel => 'Qeydiyyatdan keç';

  @override
  String get loginForgotPasswordLabel => 'Parolu unutdum?';

  @override
  String get loginAccountNotFoundError => 'Bu məlumatlarla hesab tapılmadı.';

  @override
  String get loginTooManyAttemptsError => 'Çox sayda uğursuz cəhd oldu. Bir az sonra yenidən cəhd edin, ya da parolu \"Parolu unutdum\" ilə sıfırlayın.';

  @override
  String get loginNetworkError => 'İnternet bağlantısı yoxdur. Bağlantınızı yoxlayıb yenidən cəhd edin.';

  @override
  String get loginRegisterPromptLabel => 'Qeydiyyatdan keçmək istəyirsiniz?';

  @override
  String get registerTitle => 'Qeydiyyatdan keç';

  @override
  String get registerUsernameLabel => 'İstifadəçi adı';

  @override
  String get registerUsernameHint => 'istifadeci.adi';

  @override
  String get registerUsernameCheckingLabel => 'Yoxlanılır...';

  @override
  String get registerUsernameTakenError => 'Bu username artıq istifadə olunur.';

  @override
  String get registerUsernameInvalidFormatError => 'Username yalnız hərf, rəqəm, . və _ ola bilər (3-20 simvol).';

  @override
  String get registerPasswordLabel => 'Parol';

  @override
  String get registerPasswordHint => 'Ən azı 8 simvol';

  @override
  String get registerPasswordConfirmLabel => 'Parol (təkrar)';

  @override
  String get registerPasswordConfirmHint => 'Parolu təkrar yaz';

  @override
  String get registerPasswordTooShortError => 'Parol ən azı 8 simvoldan ibarət olmalıdır.';

  @override
  String get registerPasswordMismatchError => 'Parollar uyğun gəlmir.';

  @override
  String get registerSubmitButton => 'Qeydiyyatı tamamla';

  @override
  String get registerGenericError => 'Qeydiyyat tamamlanmadı. Bir az sonra yenidən cəhd edin.';

  @override
  String get registerSuccessMessage => 'Qeydiyyat tamamlandı, indi daxil ola bilərsiniz.';

  @override
  String get phoneAuthTitle => 'Telefon nömrən';

  @override
  String get phoneAuthSubtitle => 'SMS ilə göndəriləcək koda ehtiyacın olacaq.';

  @override
  String get phoneAuthNumberHint => '50 123 45 67';

  @override
  String get phoneAuthContinueButton => 'Telefon nömrəsi ilə davam et';

  @override
  String get phoneAuthInvalidNumberError => 'Düzgün telefon nömrəsi daxil edin';

  @override
  String get phoneAuthVerificationFailedError => 'Nömrə doğrulanmadı, yenidən cəhd edin.';

  @override
  String get pickCountryTitle => 'Ölkə seç';

  @override
  String get otpTitle => 'Kodu daxil et';

  @override
  String otpSubtitle(String phone) {
    return '$phone nömrəsinə göndərilən 6 rəqəmli kodu yaz.';
  }

  @override
  String get otpCodeHint => '••••••';

  @override
  String get otpConfirmButton => 'Təsdiqlə';

  @override
  String get otpIncompleteCodeError => '6 rəqəmli kodu tam daxil edin';

  @override
  String get otpInvalidCodeError => 'Kod yanlışdır və ya vaxtı bitib.';

  @override
  String get otpResendButton => 'Kodu yenidən göndər';

  @override
  String otpResendWaitLabel(String time) {
    return 'Yenidən göndər: $time';
  }

  @override
  String get verificationRequiredTitle => 'Hesabı təsdiq et';

  @override
  String get verificationRequiredMessage => 'Bu funksiyadan istifadə etmək üçün əvvəlcə hesabınızı təsdiqləməlisiniz.';

  @override
  String get verificationRequiredButton => 'Hesabı təsdiq et';

  @override
  String get accountVerificationTitle => 'Hesabı təsdiq et';

  @override
  String get accountVerificationSubtitle => 'Telefon nömrənizi təsdiqləyərək bütün funksiyalardan istifadə edə bilərsiniz.';

  @override
  String get accountVerificationPhoneTakenError => 'Bu telefon nömrəsi artıq başqa hesabda istifadə olunur.';

  @override
  String get accountVerificationSuccessMessage => 'Hesabınız təsdiqləndi.';

  @override
  String get settingsAccountVerificationRowTitle => 'Hesabı təsdiq et';

  @override
  String get settingsAccountVerifiedRowSubtitle => 'Hesabınız təsdiqlənib';

  @override
  String get settingsIdentityVerificationRowTitle => 'Kimlik doğrulama';

  @override
  String get swipeMatchedMessage => 'Bu istifadəçi ilə uyğunlaşdınız!';

  @override
  String get swipeErrorMessage => 'Əməliyyat baş tutmadı. Bir az sonra yenidən cəhd edin.';

  @override
  String get forgotPasswordTitle => 'Parolu unutdum';

  @override
  String get forgotPasswordSubtitle => 'Hesabınıza bağlı telefon nömrənizi daxil edin.';

  @override
  String get forgotPasswordAccountNotFoundError => 'Bu telefon nömrəsi ilə əlaqəli hesab tapılmadı.';

  @override
  String get newPasswordTitle => 'Yeni parol';

  @override
  String get newPasswordSubtitle => 'Hesabınız üçün yeni parol təyin edin.';

  @override
  String get newPasswordLabel => 'Yeni parol';

  @override
  String get newPasswordHint => 'Ən azı 8 simvol';

  @override
  String get newPasswordConfirmLabel => 'Yeni parol (təkrar)';

  @override
  String get newPasswordConfirmHint => 'Parolu təkrar yaz';

  @override
  String get newPasswordSubmitButton => 'Parolu yenilə';

  @override
  String get newPasswordSuccessMessage => 'Parolunuz yeniləndi. İndi daxil ola bilərsiniz.';

  @override
  String get newPasswordGenericError => 'Parol yenilənmədi. Bir az sonra yenidən cəhd edin.';

  @override
  String get changePasswordTitle => 'Parolu dəyiş';

  @override
  String get changePasswordCurrentLabel => 'Cari parol';

  @override
  String get changePasswordCurrentHint => 'Cari parolunuzu yazın';

  @override
  String get changePasswordNewLabel => 'Yeni parol';

  @override
  String get changePasswordNewHint => 'Ən azı 8 simvol';

  @override
  String get changePasswordConfirmLabel => 'Yeni parol (təkrar)';

  @override
  String get changePasswordConfirmHint => 'Parolu təkrar yaz';

  @override
  String get changePasswordSubmitButton => 'Parolu yenilə';

  @override
  String get changePasswordWrongCurrentError => 'Cari parol yanlışdır.';

  @override
  String get changePasswordSuccessMessage => 'Parolunuz yeniləndi.';

  @override
  String get changePasswordGenericError => 'Parol dəyişdirilmədi. Bir az sonra yenidən cəhd edin.';

  @override
  String get onboardingAppBarTitle => 'Profilini tamamla';

  @override
  String get onboardingPhotoOptionalLabel => 'Şəkil əlavə et (keçilə bilər)';

  @override
  String get fieldFirstNameLabel => 'Ad';

  @override
  String get fieldFirstNameHint => 'Rasim';

  @override
  String get fieldFirstNameRequiredError => 'Ad daxil et';

  @override
  String get fieldLastNameLabel => 'Soyad';

  @override
  String get fieldLastNameHint => 'Məmmədov';

  @override
  String get fieldLastNameRequiredError => 'Soyad daxil et';

  @override
  String get fieldBirthDateLabel => 'Doğum tarixi';

  @override
  String get fieldBirthDateHint => 'gg.aa.iiii';

  @override
  String get birthDatePickerHelpText => 'Doğum tarixini seç';

  @override
  String get fieldGenderLabel => 'Cins';

  @override
  String get sectionCountryCityTitle => 'Ölkə və şəhər';

  @override
  String get sectionAboutOptionalTitle => 'Haqqında (keçilə bilər)';

  @override
  String get bioHintOnboarding => 'Özün haqqında bir neçə cümlə...';

  @override
  String get onboardingFinishButton => 'Tamamla və davam et';

  @override
  String get onboardingSelectBirthDateError => 'Doğum tarixini seçin';

  @override
  String get onboardingSelectGenderError => 'Cinsini seçin';

  @override
  String get onboardingSelectCountryCityError => 'Ölkə və şəhəri seçin';

  @override
  String get onboardingPhotoUploadFailedError => 'Şəkil yüklənə bilmədi, sonra profildən əlavə edə bilərsiniz.';

  @override
  String errorWithDetails(String error) {
    return 'Xəta baş verdi: $error';
  }

  @override
  String get navDiscoverLabel => 'Kəşf et';

  @override
  String get navChatsLabel => 'Söhbət';

  @override
  String get navFeedLabel => 'Lent';

  @override
  String get navNotificationsLabel => 'Bildirişlər';

  @override
  String get navProfileLabel => 'Profil';

  @override
  String get notificationsFeedTitle => 'Bildirişlər';

  @override
  String get notifMenuMarkAllRead => 'Hamısını oxunmuş et';

  @override
  String get notifMenuDeleteRead => 'Oxunmuşları sil';

  @override
  String get notifMenuSettings => 'Bildiriş ayarları';

  @override
  String get notifEmptyTitle => 'Bildiriş yoxdur';

  @override
  String get notifEmptySubtitle => 'Yeni bildirişlər burada görünəcək.';

  @override
  String get notifErrorOfflineTitle => 'İnternet bağlantısı yoxdur';

  @override
  String get notifErrorOfflineMessage => 'Bildirişləri yükləmək üçün internetə qoşulun.';

  @override
  String get notifErrorPermissionTitle => 'İcazə yoxdur';

  @override
  String get notifErrorPermissionMessage => 'Bu bildirişləri görmək üçün icazəniz yoxdur.';

  @override
  String get notifErrorUnknownTitle => 'Xəta baş verdi';

  @override
  String get notifErrorUnknownMessage => 'Bildirişlər yüklənə bilmədi. Bir az sonra yenidən cəhd edin.';

  @override
  String get notifMarkAllReadDone => 'Bütün bildirişlər oxunmuş kimi işarələndi';

  @override
  String get notifDeleteReadDone => 'Oxunmuş bildirişlər silindi';

  @override
  String get notifActionErrorMessage => 'Əməliyyat baş tutmadı. Bir az sonra yenidən cəhd edin.';

  @override
  String get discoverTitle => 'Kəşf et';

  @override
  String get viewSwitcherPeopleLabel => 'İnsanlar';

  @override
  String get viewSwitcherPlacesLabel => 'Məkanlar';

  @override
  String get viewSwitcherOffersLabel => 'Təkliflər';

  @override
  String get genderFilterAll => 'Hamı';

  @override
  String get genderFilterMale => 'Kişi';

  @override
  String get genderFilterFemale => 'Qadın';

  @override
  String get genderFilterTooltip => 'Filtr';

  @override
  String get genderFilterSheetTitle => 'Cinsə görə filtr';

  @override
  String get locationSearchingTitle => 'Lokasiya müəyyən edilir...';

  @override
  String get locationSearchingSubtitle => 'Bir neçə saniyə çəkə bilər.';

  @override
  String get locationServiceDisabledTitle => 'Lokasiya xidməti sönülüdür';

  @override
  String get locationServiceDisabledSubtitle => 'Yaxınlıqdakı insanları görmək üçün cihazında lokasiyanı aç.';

  @override
  String get actionOpenSettings => 'Ayarları aç';

  @override
  String get locationPermissionDeniedTitle => 'Lokasiya icazəsi lazımdır';

  @override
  String get locationPermissionDeniedSubtitle => 'Ətrafındakı insanları görmək üçün icazə ver.';

  @override
  String get actionRetry => 'Yenidən cəhd et';

  @override
  String get chatPermissionDeniedMessage => 'Hazırda bu söhbətə girişiniz yoxdur. Yenidən daxil olmağı və ya bir az sonra təkrar cəhd etməyi sınayın.';

  @override
  String get chatLoadErrorMessage => 'Yüklənmə zamanı xəta baş verdi. Zəhmət olmasa yenidən cəhd edin.';

  @override
  String get locationPermissionDeniedForeverTitle => 'İcazə həmişəlik rədd edilib';

  @override
  String get locationPermissionDeniedForeverSubtitle => 'Telefonun ayarlarından \"Meevima\" üçün lokasiya icazəsini əl ilə aç.';

  @override
  String get actionOpenAppSettings => 'Tətbiq ayarlarını aç';

  @override
  String get errorTitle => 'Xəta baş verdi';

  @override
  String get meMarkerLabel => 'Sən buradasan';

  @override
  String get defaultUserName => 'İstifadəçi';

  @override
  String get startChatButton => 'Söhbətə başla';

  @override
  String get viewProfileButton => 'Profilə bax';

  @override
  String get chatMessageHint => 'Mesaj yaz...';

  @override
  String get chatRequestSentNotice => 'Mesaj istəyi göndərildi';

  @override
  String get chatRequestBannerTitle => 'Mesaj istəyi';

  @override
  String get chatRequestBannerSubtitle => 'Bir-birinizlə söhbətə başlamaq üçün qəbul edin.';

  @override
  String get chatRequestAcceptButton => 'Qəbul et';

  @override
  String get chatRequestDeclineButton => 'Rədd et';

  @override
  String get chatRequestPendingNotice => 'Mesaj istəyinizin qəbul edilməsini gözləyin.';

  @override
  String get chatRequestDeclinedNotice => 'Bu mesaj istəyi rədd edildi.';

  @override
  String get chatRequestDeclinedByPeerNotice => 'Bu istifadəçi mesaj istəyinizi rədd edib.';

  @override
  String get chatRequestActionErrorMessage => 'Əməliyyat baş tutmadı. Bir az sonra yenidən cəhd edin.';

  @override
  String get chatOnlineStatus => 'Onlayn';

  @override
  String get chatLastSeenUnknown => 'Oflayn';

  @override
  String chatLastSeenAt(String time) {
    return 'Son görülmə: $time';
  }

  @override
  String get chatTypingIndicator => 'yazır...';

  @override
  String get chatDateToday => 'Bugün';

  @override
  String get chatDateYesterday => 'Dünən';

  @override
  String get chatMenuViewProfile => 'Profilə bax';

  @override
  String get chatMenuBlock => 'İstifadəçini blok et';

  @override
  String get chatMenuUnblock => 'Blokdan çıxart';

  @override
  String get chatUserUnblockedNotice => 'İstifadəçi blokdan çıxarıldı.';

  @override
  String get chatMenuReport => 'İstifadəçini şikayət et';

  @override
  String get chatMenuDeleteChat => 'Söhbəti sil';

  @override
  String get chatBlockConfirmTitle => 'Bu istifadəçini blok edim?';

  @override
  String get chatBlockConfirmMessage => 'O, artıq sənə mesaj yaza bilməyəcək.';

  @override
  String get chatDeleteConfirmTitle => 'Bu söhbəti silim?';

  @override
  String get chatDeleteConfirmMessage => 'Bu yazışma həmişəlik silinəcək.';

  @override
  String get chatReportTitle => 'İstifadəçini şikayət et';

  @override
  String get chatReportReasonHint => 'Problemi izah edin...';

  @override
  String get chatReportSubmitButton => 'Şikayəti göndər';

  @override
  String get chatReportSentNotice => 'Şikayətiniz göndərildi, təşəkkürlər.';

  @override
  String get chatReportReasonInappropriate => 'Uyğunsuz məzmun';

  @override
  String get chatReportReasonFakeProfile => 'Sahtə profil';

  @override
  String get chatReportReasonDangerous => 'Təhlükəli davranış';

  @override
  String get chatReportReasonOther => 'Digər';

  @override
  String get chatSendBlockedError => 'Bu istifadəçiyə mesaj göndərə bilməzsiniz.';

  @override
  String get chatUserBlockedNotice => 'İstifadəçi blok edildi.';

  @override
  String get chatEmptyConversation => 'Salam de 👋';

  @override
  String get chatEmptyStateTitle => 'İlk mesajı sən göndər';

  @override
  String get chatEmptyStateSubtitle => 'Söhbətə başlamaq üçün mesaj yaz və ya aşağıdan salamla başla.';

  @override
  String get chatEmptyStateGreetingButton => 'Salam 👋';

  @override
  String get chatVoiceComingSoonMessage => 'Səs mesajları tezliklə əlavə olunacaq.';

  @override
  String get chatEmojiPickerTitle => 'Emoji seç';

  @override
  String get chatImageMessageLabel => 'Şəkil';

  @override
  String get chatVideoMessageLabel => 'Video';

  @override
  String get chatAudioMessageLabel => 'Səsli mesaj';

  @override
  String get chatSendButton => 'Göndər';

  @override
  String get chatRetakeButton => 'Yenidən çək';

  @override
  String get chatAttachmentSheetTitle => 'Media seç';

  @override
  String get chatAttachmentImageOption => 'Şəkil';

  @override
  String get chatAttachmentVideoOption => 'Video';

  @override
  String get chatRecordingCancelHint => 'Ləğv etmək üçün sürüşdürün';

  @override
  String get chatRecordingLockHint => 'Kilidləmək üçün yuxarı sürüşdürün';

  @override
  String get chatVoiceFinishButton => 'Bitir';

  @override
  String get chatVoiceTooShortMessage => 'Səsli mesaj çox qısadır';

  @override
  String get chatMicPermissionDeniedMessage => 'Səsli mesaj göndərmək üçün mikrofon icazəsi lazımdır.';

  @override
  String get chatCameraPermissionDeniedMessage => 'Şəkil çəkmək üçün kamera icazəsi lazımdır.';

  @override
  String get chatMediaUploadFailedMessage => 'Göndərilmədi';

  @override
  String get chatMediaTooLargeMessage => 'Fayl həddindən böyükdür.';

  @override
  String get chatCallComingSoonMessage => 'Zəng funksiyası tezliklə aktivləşəcək.';

  @override
  String get chatVoiceCallLabel => 'Səsli zəng';

  @override
  String get chatVideoCallLabel => 'Video zəng';

  @override
  String get chatMessageDeleteForMeOption => 'Özün üçün sil';

  @override
  String get chatMessageDeleteForEveryoneOption => 'Hər kəs üçün sil';

  @override
  String get chatMessageDeleteForEveryoneConfirmMessage => 'Bu mesaj hər iki tərəf üçün həmişəlik silinəcək.';

  @override
  String get chatMessageDeleteOption => 'Sil';

  @override
  String get chatMessageForwardOption => 'Yönləndir';

  @override
  String get chatForwardTitle => 'Yönləndir';

  @override
  String get chatForwardEmptyMessage => 'Yönləndirmək üçün söhbətiniz yoxdur.';

  @override
  String chatForwardSendButton(int count) {
    return 'Göndər ($count)';
  }

  @override
  String get chatForwardSuccessMessage => 'Mesaj yönləndirildi.';

  @override
  String get actionCancel => 'Ləğv et';

  @override
  String get actionDelete => 'Sil';

  @override
  String distanceMetersAway(int meters) {
    return '$meters m aralı';
  }

  @override
  String distanceKmAway(String km) {
    return '$km km aralı';
  }

  @override
  String distanceMilesAway(String mi) {
    return '$mi mil aralı';
  }

  @override
  String radiusPeopleCount(int count) {
    return '$count nəfər';
  }

  @override
  String get radiusMoreButtonLabel => 'Daha çox';

  @override
  String get radiusMorePanelTitle => 'Axtarış radiusu';

  @override
  String get premiumUpsellRadiusTitle => 'Daha uzaqdakı insanları kəşf et 🌍';

  @override
  String get premiumUpsellRadiusMessage => 'Premium üzvlüklə 5 km və 10 km radiusunda olan insanları görə və daha çox insanla tanış ola bilərsən.';

  @override
  String get premiumUpgradeButton => 'Premium-a keç';

  @override
  String get premiumLaterButton => 'Sonra';

  @override
  String get premiumComingSoonTitle => 'Premium';

  @override
  String get premiumComingSoonMessage => 'Premium üzvlük tezliklə aktivləşəcək.';

  @override
  String get chatsTitle => 'Söhbətlər';

  @override
  String get chatsEmptyTitle => 'Söhbətin yoxdur';

  @override
  String get chatsEmptySubtitle => 'Ətrafındakı insanlarla tanış olduqda söhbətlərin burada görünəcək.';

  @override
  String get chatsSearchHint => 'Söhbətlərdə axtar';

  @override
  String get chatsSearchEmptyTitle => 'Heç nə tapılmadı';

  @override
  String get chatsSearchEmptySubtitle => 'Başqa ad, username və ya söz ilə axtarmağı sınayın.';

  @override
  String get chatsFilterAll => 'Hamısı';

  @override
  String get chatsFilterUnread => 'Oxunmayanlar';

  @override
  String get chatsFilterArchived => 'Arxivlənənlər';

  @override
  String get chatsFilterRequests => 'Sorğular';

  @override
  String get chatsUnreadEmptyTitle => 'Oxunmamış mesaj yoxdur';

  @override
  String get chatsUnreadEmptySubtitle => 'Bütün mesajlar oxunub.';

  @override
  String get chatsArchivedEmptyTitle => 'Arxivlənmiş söhbət yoxdur';

  @override
  String get chatsArchivedEmptySubtitle => 'Arxivlənmiş söhbətlər burda görünəcək.';

  @override
  String get chatsRequestsEmptyTitle => 'Mesaj sorğusu yoxdur';

  @override
  String get chatsRequestsEmptySubtitle => 'Tanımadığınız insanlardan gələn ilk mesajlar burada görünəcək.';

  @override
  String get chatsPinLimitReachedMessage => 'Maksimum 3 söhbət sabitləyə bilərsiniz.';

  @override
  String get chatsPinAction => 'Sabitlə';

  @override
  String get chatsUnpinAction => 'Sabitləndən çıxart';

  @override
  String get chatsArchiveAction => 'Arxivlə';

  @override
  String get chatsUnarchiveAction => 'Arxivdən çıxart';

  @override
  String get chatsMuteAction => 'Səssiz';

  @override
  String get chatsUnmuteAction => 'Səsli et';

  @override
  String get chatsPinnedSectionLabel => 'Sabitlənənlər';

  @override
  String get chatsRecentSectionLabel => 'Son söhbətlər';

  @override
  String get eventSaveButton => 'Yadda saxla';

  @override
  String get venueCreateTitle => 'Məkan profili';

  @override
  String get venueEditTitle => 'Məkana düzəliş et';

  @override
  String get venuePhotoLabel => 'Şəkil/loqo əlavə et';

  @override
  String get venuePhotoSheetTitle => 'Şəkil əlavə et';

  @override
  String get venuePhotoGalleryOption => 'Qalereyadan seç';

  @override
  String get venuePhotoCameraOption => 'Kamera ilə çək';

  @override
  String get venueNameLabel => 'Ad';

  @override
  String get venueNameHint => 'Məkanın adı';

  @override
  String get venueFieldRequiredError => 'Bu sahə məcburidir';

  @override
  String get venueCategoryLabel => 'Xidmət sahəsi';

  @override
  String get venueCategoryPickerTitle => 'Xidmət sahəsini seç';

  @override
  String get venueCategorySearchHint => 'Kateqoriya axtar...';

  @override
  String get venueCategoryChangeHint => 'Toxunub dəyişin';

  @override
  String get venuePhotoCropTitle => 'Şəkli kəs';

  @override
  String get venueUploadingLabel => 'Yüklənir...';

  @override
  String get venueUploadCancelButton => 'Ləğv et';

  @override
  String get venueDirectionsGoogleMaps => 'Google Maps';

  @override
  String get venueDirectionsAppleMaps => 'Apple Maps';

  @override
  String get venueDirectionsWaze => 'Waze';

  @override
  String get venueScheduleLabel => 'Həftəlik cədvəl';

  @override
  String get venueFullAddressLabel => 'Tam ünvan';

  @override
  String get venuesSearchHint => 'Məkan axtar...';

  @override
  String get venueFilterTooltip => 'Filtr';

  @override
  String get venueCategoryFilterTitle => 'Kateqoriya seç';

  @override
  String get venueCategoryAllOption => 'Hamısı';

  @override
  String get offersSearchHint => 'Təklif axtar...';

  @override
  String get offerFilterTooltip => 'Filtr';

  @override
  String get offersEmptyTitle => 'Hələ heç bir təklif yoxdur';

  @override
  String get offersEmptySubtitle => 'Yaxınlıqdakı məkanlardan təkliflər burada görünəcək.';

  @override
  String get offerCategoryFilterTitle => 'Kateqoriya seç';

  @override
  String get offerCategoryAllOption => 'Hamısı';

  @override
  String get offerBadgeDiscountSuffix => 'endirim';

  @override
  String get offerBadgeGiftLabel => 'Hədiyyə';

  @override
  String get offerBadgeBuyOneGetOneLabel => '1+1';

  @override
  String get offerBadgeFixedPriceSuffix => 'AZN';

  @override
  String offerEndsOnLabel(String date) {
    return '$date-dək';
  }

  @override
  String get offerTermsLabel => 'Şərtlər';

  @override
  String get offerValidityLabel => 'Aktivlik müddəti';

  @override
  String get offerStartDateLabel => 'Başlanğıc';

  @override
  String get offerEndDateLabel => 'Bitmə';

  @override
  String get offerContactLabel => 'Əlaqə';

  @override
  String get offerOtherActiveOffersLabel => 'Digər aktiv təkliflər';

  @override
  String get offerViewVenueProfileButton => 'Məkan Profilinə keç';

  @override
  String get offerNotFoundMessage => 'Təklif tapılmadı.';

  @override
  String get offerGenericErrorMessage => 'Əməliyyat baş tutmadı. Bir az sonra yenidən cəhd edin.';

  @override
  String get offerCreateTitle => 'Təklif yarat';

  @override
  String get offerEditTitle => 'Təklifə düzəliş et';

  @override
  String get offerPhotoLabel => 'Şəkli/loqo əlavə et';

  @override
  String get offerNameLabel => 'Təklif adı';

  @override
  String get offerNameHint => 'Təklifin adını yazın';

  @override
  String get offerCategoryLabel => 'Kateqoriya seçin';

  @override
  String get offerTypeLabel => 'Təklif növü';

  @override
  String get offerTypeDiscountOption => 'Endirim';

  @override
  String get offerTypeGiftOption => 'Hədiyyə';

  @override
  String get offerTypeBuyOneGetOneOption => '1+1 Hədiyyə';

  @override
  String get offerTypeFixedPriceOption => 'Sabit qiymət';

  @override
  String get offerDiscountAmountLabel => 'Endirim məbləği';

  @override
  String get offerFixedPriceLabel => 'Qiymət (AZN)';

  @override
  String get offerFixedPriceHint => 'Qiyməti yazın';

  @override
  String get offerDescriptionLabel => 'Təklif haqqında qısa məlumat';

  @override
  String get offerDescriptionHint => 'Təklifin şərtlərini və üstünlüklərini yazın...';

  @override
  String get offerValidityPeriodLabel => 'Təklifin aktivlik müddəti';

  @override
  String get offerStartDatePickerLabel => 'Başlanğıc tarixi';

  @override
  String get offerEndDatePickerLabel => 'Bitmə tarixi';

  @override
  String get offerVenuePickerLabel => 'Məkan seçin';

  @override
  String get offerVenuePickerHint => 'Məkan seçin';

  @override
  String get offerNoVenuesTitle => 'Hələ heç bir məkanınız yoxdur';

  @override
  String get offerNoVenuesSubtitle => 'Təklif yaratmaq üçün əvvəlcə bir məkan əlavə edin.';

  @override
  String get offerAddVenueButton => 'Məkan əlavə et';

  @override
  String get offerTermsHint => 'Təklifin istifadə şərtlərini yazın...';

  @override
  String get offerAdditionalInfoLabel => 'Əlavə məlumatlar';

  @override
  String get offerContactPhoneHint => 'Telefon nömrəsi';

  @override
  String get offerContactWebsiteHint => 'Vebsayt';

  @override
  String get offerContactInstagramHint => 'Instagram';

  @override
  String get offerSubmitButton => 'Təklifi yarat';

  @override
  String get offerCreatedNotice => 'Təklif yaradıldı';

  @override
  String get offerUpdatedNotice => 'Təklif yeniləndi';

  @override
  String get offerRequiredFieldsMissing => 'Zəhmət olmasa bütün məcburi sahələri doldurun.';

  @override
  String get offerDatesInvalidError => 'Bitmə tarixi başlanğıcdan sonra olmalıdır.';

  @override
  String get offerDeleteMenuOption => 'Təklifi sil';

  @override
  String get offerDeleteConfirmMessage => 'Bu təklifi silmək istədiyinizə əminsiniz? Bu əməliyyat geri qaytarıla bilməz.';

  @override
  String get offerDeletedNotice => 'Təklif silindi';

  @override
  String get offerStatusActive => 'Aktiv';

  @override
  String get offerStatusExpired => 'Bitib';

  @override
  String get offerMyOffersTitle => 'Mənim təkliflərim';

  @override
  String get offerMyOffersEmptyTitle => 'Hələ heç bir təklif əlavə etməmisiniz';

  @override
  String get offerMyOffersEmptySubtitle => 'Əlavə etdiyiniz təkliflər burada görünəcək və onları istənilən vaxt redaktə edə və ya silə bilərsiniz.';

  @override
  String get offerMyOffersTooltip => 'Mənim təkliflərim';

  @override
  String get offerAddButtonTooltip => 'Təklif yarat';

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
  String get venueCategoryTeaHouse => 'Çayxana';

  @override
  String get venueCategorySweetsShop => 'Şirniyyat evi';

  @override
  String get venueCategoryHotel => 'Hotel';

  @override
  String get venueCategoryMotel => 'Motel';

  @override
  String get venueCategoryCinema => 'Kino teatr';

  @override
  String get venueCategoryKaraoke => 'Karaoke Bar';

  @override
  String get venueCategoryGameHall => 'Oyun zalı';

  @override
  String get venueCategoryNightClub => 'Gecə klubu';

  @override
  String get venueCategoryFitness => 'Fitnes';

  @override
  String get venueCategoryGym => 'GYM';

  @override
  String get venueCategorySpa => 'Spa, masaj və sauna';

  @override
  String get venueCategoryFootballField => 'Futbol meydançası';

  @override
  String get venueCategoryClinic => 'Klinika';

  @override
  String get venueCategoryBeautySalon => 'Gözəllik salonu';

  @override
  String get venueCategoryBarbershop => 'Bərbərxana';

  @override
  String get venueCategoryCosmetology => 'Kosmetologiya';

  @override
  String get venueCategoryTattoo => 'Tatu və pirsinq';

  @override
  String get venueCategoryPhotoStudio => 'Foto studio';

  @override
  String get venueCategoryKidsEntertainment => 'Uşaq əyləncə';

  @override
  String get venueCategoryOther => 'Digər';

  @override
  String get venueHoursLabel => 'Açılış/bağlanma saatları';

  @override
  String get venueHours24Label => '24 saat açıqdır';

  @override
  String get venueHoursSameEveryDayLabel => 'Hər gün eyni saat';

  @override
  String get venueWeekdayMon => 'B.e';

  @override
  String get venueWeekdayTue => 'Ç.a';

  @override
  String get venueWeekdayWed => 'Ç';

  @override
  String get venueWeekdayThu => 'C.a';

  @override
  String get venueWeekdayFri => 'C';

  @override
  String get venueWeekdaySat => 'Ş';

  @override
  String get venueWeekdaySun => 'B';

  @override
  String get venueLocationLabel => 'Ünvan/yer';

  @override
  String get venuePickOnMapButton => 'Xəritədən seç';

  @override
  String get venueLocationPickedLabel => 'Xəritədə seçildi ✓';

  @override
  String get venueLocationPickerTitle => 'Xəritədən yer seç';

  @override
  String get venueLocationPickerHint => 'Dəqiq nöqtəni seçmək üçün xəritəyə toxunun və ya pini sürüşdürün';

  @override
  String get venueLocationResolvingAddress => 'Ünvan müəyyən edilir...';

  @override
  String get venueLocationAddressUnavailable => 'Ünvan tapılmadı';

  @override
  String get venueLocationPickerConfirmButton => 'Bu yeri seç';

  @override
  String get venueCreateButton => 'Əlavə et';

  @override
  String get venueSaveButton => 'Yadda saxla';

  @override
  String get venueRequiredFieldsMissing => 'Zəhmət olmasa bütün məcburi sahələri doldurun.';

  @override
  String get venueGenericErrorMessage => 'Əməliyyat baş tutmadı. Bir az sonra yenidən cəhd edin.';

  @override
  String get venueAddButtonTooltip => 'Məkan yerləşdir';

  @override
  String get venuesEmptyTitle => 'Yaxınlıqda məkan yoxdur';

  @override
  String get venuesEmptySubtitle => 'Seçdiyiniz radiusda hələ heç bir məkan əlavə edilməyib.';

  @override
  String get venueMyVenuesTooltip => 'Mənim məkanlarım';

  @override
  String get venueMyVenuesTitle => 'Mənim məkanlarım';

  @override
  String get venueMyVenuesEmptyTitle => 'Hələ heç bir məkan əlavə etməmisiniz';

  @override
  String get venueMyVenuesEmptySubtitle => 'Əlavə etdiyiniz məkanlar burada görünəcək və onları istənilən vaxt redaktə edə və ya silə bilərsiniz.';

  @override
  String get venueDeleteMenuOption => 'Məkanı sil';

  @override
  String get venueDeleteConfirmMessage => 'Bu məkanı silmək istədiyinizə əminsiniz? Bu əməliyyat geri qaytarıla bilməz.';

  @override
  String get venueDeletedNotice => 'Məkan silindi';

  @override
  String get venueOpenNowLabel => 'Açıq';

  @override
  String get venueClosedNowLabel => 'Bağlı';

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileNamePlaceholder => 'Adını əlavə et';

  @override
  String get profileBioPlaceholder => 'Şəkil, bio və maraqlarını əlavə et';

  @override
  String get shareProfileLabel => 'Profili paylaş';

  @override
  String get profileStatsFriends => 'Dostlar';

  @override
  String get profileStatsLikes => 'Bəyənilər';

  @override
  String get profileGalleryEmptyMessage => 'Hələ heç bir şəkil və ya video yükləməmisiniz';

  @override
  String get editProfileTitle => 'Şəxsi məlumatlar';

  @override
  String get personalInfoSubtitle => 'Məlumatlarınızı yeniləyin və dəyişiklikləri yadda saxlayın.';

  @override
  String get profileSaveSuccessMessage => 'Məlumatlar yeniləndi.';

  @override
  String get menuSettings => 'Ayarlar';

  @override
  String get menuPrivacySecurity => 'Məxfilik və təhlükəsizlik';

  @override
  String get privacySecurityTitle => 'Məxfilik və təhlükəsizlik';

  @override
  String get privacyProfileVisibilityTitle => 'Media görünürlüyü';

  @override
  String get privacyProfileVisibilitySubtitle => 'Profilinizdəki paylaşımları kimin görə biləcəyini seçin.';

  @override
  String get privacyVisibilityEveryone => 'Hamı';

  @override
  String get privacyVisibilityFollowersOnly => 'Takip və Takipçilər';

  @override
  String get privacyVisibilityNoOne => 'Heçkəs';

  @override
  String get privacyClosedProfileNotice => 'Bağlı profil';

  @override
  String get privacyRadiusTitle => 'Görünmə radiusu';

  @override
  String get privacyRadiusCountryLabel => 'Ölkə üzrə';

  @override
  String get privacyRadiusWorldLabel => 'Dünya üzrə';

  @override
  String get privacyOnlineStatusTitle => 'Onlayn olduğumu göstər';

  @override
  String get privacyReadReceiptsTitle => 'Mesaj oxundu məlumatını göstər';

  @override
  String get privacyReadReceiptsHelperText => 'Bağladığınız halda siz də qarşı tərəfin oxundu statusunu görə bilməyəcəksiniz.';

  @override
  String get privacyWhoCanMessageTitle => 'Kim mənə mesaj göndərə bilər';

  @override
  String get privacyMessagePermEveryone => 'Hamı';

  @override
  String get privacyMessagePermVerifiedOnly => 'Yalnız təsdiqlənmiş istifadəçilər';

  @override
  String get privacyMessagePermNoOne => 'Heç kim';

  @override
  String get privacyGhostModeTitle => 'Ghost Mode';

  @override
  String get privacyGhostModeDescription => 'Siz digər istifadəçiləri görə bilərsiniz. Digər istifadəçilər sizi xəritədə görə bilməz. İstədiyiniz zaman aktiv/deaktiv edə bilərsiniz.';

  @override
  String get privacyGhostModePremiumTitle => 'Ghost Mode ilə görünməz olun 👻';

  @override
  String get privacyGhostModePremiumMessage => 'Premium üzvlüklə digər istifadəçiləri görə bilərsiniz, amma onlar sizi xəritədə görə bilməyəcək.';

  @override
  String get privacySettingUpdateErrorMessage => 'Dəyişiklik saxlanılmadı. Bir az sonra yenidən cəhd edin.';

  @override
  String get privacyTwoFactorTitle => 'İki mərhələli doğrulamanı aktiv et';

  @override
  String get privacyTwoFactorHelperText => 'Hazırda yalnız seçiminiz saxlanılır — SMS və Authenticator dəstəyi tezliklə əlavə olunacaq.';

  @override
  String get privacyExportDataTitle => 'Məlumatlarımı yüklə';

  @override
  String get privacyExportDataDescription => 'Tətbiqdə saxlanılan məlumatlarınız hazırlanaraq sizə təqdim olunacaq.';

  @override
  String get exportDataScreenTitle => 'Məlumatlarım';

  @override
  String get exportDataCopyButton => 'Kopyala';

  @override
  String get exportDataCopiedNotice => 'Məlumatlar buferə kopyalandı.';

  @override
  String get exportDataLoadErrorMessage => 'Məlumatlar yüklənmədi. Yenidən cəhd edin.';

  @override
  String get privacyDeleteAccountTitle => 'Hesabımı sil';

  @override
  String get deleteAccountWarningTitle => 'Hesabınızı silmək istədiyinizə əminsiniz?';

  @override
  String get deleteAccountWarningMessage => 'Profiliniz, söhbətləriniz və bütün məlumatlarınız həmişəlik silinəcək. Bu əməliyyat geri qaytarıla bilməz.';

  @override
  String get deleteAccountFinalConfirmTitle => 'Son təsdiq';

  @override
  String get deleteAccountFinalConfirmMessage => 'Hesabınızı silmək üzərəsiniz. Bu addımdan sonra geri dönüş yoxdur.';

  @override
  String get deleteAccountConfirmButton => 'Bəli, hesabımı sil';

  @override
  String get deleteAccountReauthTitle => 'Kimliyinizi təsdiqləyin';

  @override
  String get deleteAccountReauthMessage => 'Təhlükəsizlik üçün, hesabı silmədən əvvəl telefon nömrənizi yenidən təsdiqləməlisiniz.';

  @override
  String get deleteAccountSendCodeButton => 'Kod göndər';

  @override
  String get deleteAccountCodeSentMessage => 'Kod göndərildi';

  @override
  String get deleteAccountOtpHint => 'SMS kodu';

  @override
  String get deleteAccountConfirmCodeButton => 'Təsdiqlə';

  @override
  String get deleteAccountReauthFailedMessage => 'Təsdiqləmə uğursuz oldu. Yenidən cəhd edin.';

  @override
  String get deleteAccountErrorMessage => 'Hesab silinmədi. Bir az sonra yenidən cəhd edin.';

  @override
  String get blockedUsersTitle => 'Bloklanmış istifadəçilər';

  @override
  String get blockedUsersEmptyTitle => 'Bloklanmış istifadəçi yoxdur';

  @override
  String get blockedUsersEmptySubtitle => 'Blokladığınız istifadəçilər burada görünəcək.';

  @override
  String get menuNotifications => 'Bildirişlər';

  @override
  String get menuHelp => 'Kömək';

  @override
  String get menuLogout => 'Çıxış et';

  @override
  String uploadingProgress(String percent) {
    return '$percent% yüklənir...';
  }

  @override
  String get removePhotoButton => 'Şəkli sil';

  @override
  String get fieldAgeLabel => 'Yaş';

  @override
  String get fieldAgeHint => '25';

  @override
  String get fieldEmailOptionalLabel => 'Email (məcburi deyil)';

  @override
  String get fieldEmailHint => 'nümunə@email.com';

  @override
  String get sectionAboutTitle => 'Haqqında';

  @override
  String get bioHintEdit => 'Özün haqqında bir neçə cümlə yaz...';

  @override
  String get saveButton => 'Yadda saxla';

  @override
  String get waitPhotoUploadError => 'Şəkil yüklənməsini gözləyin...';

  @override
  String get invalidEmailError => 'Düzgün email daxil edin';

  @override
  String saveFailedError(String error) {
    return 'Yadda saxlanmadı: $error';
  }

  @override
  String get photoOperationFailedError => 'Şəkil əməliyyatı uğursuz oldu.';

  @override
  String get storageErrorFileTooLarge => 'Şəkil 5MB-dan böyük ola bilməz.';

  @override
  String get storageErrorInvalidContentType => 'Dəstəklənməyən fayl formatı.';

  @override
  String get storageErrorUploadFailed => 'Şəkil yüklənə bilmədi.';

  @override
  String get storageErrorDownloadUrlFailed => 'Şəkil yüklənə bilmədi.';

  @override
  String get storageErrorDeleteFailed => 'Şəkil silinə bilmədi.';

  @override
  String get storageErrorPermissionDenied => 'Bu əməliyyat üçün icazəniz yoxdur.';

  @override
  String get storageErrorUnauthenticated => 'İstifadəçi daxil olmayıb.';

  @override
  String get storageErrorUnknown => 'Naməlum yaddaş xətası baş verdi.';

  @override
  String get comingSoonDefaultMessage => 'Bu funksiya tezliklə aktivləşəcək.';

  @override
  String get pickCountryHint => 'Ölkə axtar';

  @override
  String get pickCityTitle => 'Şəhər seç';

  @override
  String get pickCityHint => 'Şəhər axtar';

  @override
  String get searchNotFound => 'Tapılmadı';

  @override
  String get fieldCountryLabel => 'Ölkə';

  @override
  String get fieldCitySelectFirstHint => 'Əvvəlcə ölkə seç';

  @override
  String get fieldCityLabel => 'Şəhər';

  @override
  String get contactRequiredError => 'E-poçt və ya nömrənizi daxil edin';

  @override
  String get contactInvalidError => 'Düzgün e-poçt və ya nömrə daxil edin';

  @override
  String get stampLike => 'BƏYƏN';

  @override
  String get stampReject => 'İMTİNA';

  @override
  String get stampSuper => 'SUPER';

  @override
  String get emptyStackTitle => 'Ətrafında hələ kimsə yoxdur';

  @override
  String get emptyStackSubtitle => 'Radius və ya filtri dəyişməyi sınayın.';

  @override
  String get discoverActiveNowLabel => 'İndi aktivdir';

  @override
  String get discoverSwipeUpHint => 'Növbəti kart üçün yuxarı sürüşdür';

  @override
  String get discoverMatchTitle => 'Uyğunluq!';

  @override
  String get discoverMatchMessage => 'Siz bir-birinizi bəyəndiniz!';

  @override
  String get discoverMatchLaterButton => 'Sonra';

  @override
  String get storyVisibilitySheetTitle => 'Kim görə bilər?';

  @override
  String get storyVisibilityPickPrompt => 'Kim görə bilər?';

  @override
  String get storyVisibilityFollowers => 'Takip və Takipçilər';

  @override
  String get storyVisibilityEveryone => 'Hamı';

  @override
  String get storyShareButton => 'Paylaş';

  @override
  String get storyVideoTooLongMessage => 'Video maksimum 60 saniyə ola bilər';

  @override
  String get storyShareErrorMessage => 'Paylaşım edilə bilmədi. Bir az sonra yenidən cəhd edin.';

  @override
  String get storyViewersEmptyMessage => 'Hələ heç kim baxmayıb';

  @override
  String get storyViewersTitle => 'Baxanlar';

  @override
  String get postCaptureSheetTitle => 'Paylaşım əlavə et';

  @override
  String get postCameraOption => 'Kamera ilə çək';

  @override
  String get postGalleryPhotoOption => 'Şəkil seç';

  @override
  String get postGalleryVideoOption => 'Video seç';

  @override
  String get postShareButton => 'Paylaş';

  @override
  String get postShareErrorMessage => 'Paylaşım edilə bilmədi. Bir az sonra yenidən cəhd edin.';

  @override
  String get postFeedEmptyMessage => 'Hələ heç bir paylaşım yoxdur';

  @override
  String get postCommentsSheetTitle => 'Rəylər';

  @override
  String get postCommentsEmptyMessage => 'Hələ heç bir rəy yoxdur';

  @override
  String get postCommentHint => 'Rəy yaz...';

  @override
  String get postCommentSendButton => 'Göndər';

  @override
  String get postCommentErrorMessage => 'Rəy göndərilmədi. Bir az sonra yenidən cəhd edin.';

  @override
  String get postLikeErrorMessage => 'Bəyənmə saxlanılmadı. Bir az sonra yenidən cəhd edin.';

  @override
  String get feedSearchHint => 'Axtar';

  @override
  String get feedSearchNoResultsMessage => 'Nəticə tapılmadı';

  @override
  String get feedDownloadVideoOption => 'Videonu endir';

  @override
  String feedDownloadInProgressMessage(int percent) {
    return 'Yüklənir... $percent%';
  }

  @override
  String get feedDownloadCompleteMessage => 'Video qalereyanıza endirildi';

  @override
  String get feedDownloadErrorMessage => 'Video endirilə bilmədi. Bir az sonra yenidən cəhd edin.';

  @override
  String get postTimeJustNow => 'İndicə';

  @override
  String postTimeMinutesAgo(int count) {
    return '$count dəqiqə əvvəl';
  }

  @override
  String postTimeHoursAgo(int count) {
    return '$count saat əvvəl';
  }

  @override
  String postTimeDaysAgo(int count) {
    return '$count gün əvvəl';
  }

  @override
  String postTimeWeeksAgo(int count) {
    return '$count həftə əvvəl';
  }

  @override
  String get postCaptionHint => 'Açıqlama yaz...';

  @override
  String get postMenuEdit => 'Düzəliş et';

  @override
  String get postMenuDelete => 'Sil';

  @override
  String get postEditCaptionTitle => 'Açıqlamanı düzəlt';

  @override
  String get postEditCaptionSave => 'Yadda saxla';

  @override
  String get postEditCaptionErrorMessage => 'Yadda saxlanmadı. Bir az sonra yenidən cəhd edin.';

  @override
  String get postDeleteConfirmTitle => 'Paylaşımı silmək istədiyinizə əminsiniz?';

  @override
  String get postDeleteConfirmMessage => 'Bu əməliyyat geri qaytarıla bilməz.';

  @override
  String get postDeleteErrorMessage => 'Paylaşım silinmədi. Bir az sonra yenidən cəhd edin.';

  @override
  String get storyDeleteConfirmTitle => 'Statusu silmək istədiyinizə əminsiniz?';

  @override
  String get storyDeleteConfirmMessage => 'Bu əməliyyat geri qaytarıla bilməz.';

  @override
  String get storyDeleteErrorMessage => 'Status silinmədi. Bir az sonra yenidən cəhd edin.';

  @override
  String get viewActiveStoryButton => 'Statusu izlə';

  @override
  String get postReplyAction => 'Cavab yaz';

  @override
  String postReplyingToLabel(String name) {
    return 'Cavab yazılır: $name';
  }

  @override
  String get postCommentDeleteConfirmTitle => 'Rəyi silmək istədiyinizə əminsiniz?';

  @override
  String get postCommentDeleteErrorMessage => 'Rəy silinmədi. Bir az sonra yenidən cəhd edin.';

  @override
  String get postCommentEditErrorMessage => 'Rəy yenilənmədi. Bir az sonra yenidən cəhd edin.';

  @override
  String get postShareOptionsSheetTitle => 'Paylaş';

  @override
  String get postShareToChatOption => 'Söhbətdə göndər';

  @override
  String get postShareExternalOption => 'Xarici tətbiqlə paylaş';

  @override
  String get postSendToSheetTitle => 'Kimə göndər?';

  @override
  String get postSendToEmptyMessage => 'Hələ söhbətiniz yoxdur';

  @override
  String get postSentToChatSuccessMessage => 'Paylaşım göndərildi';

  @override
  String get postSentToChatErrorMessage => 'Paylaşım göndərilə bilmədi. Bir az sonra yenidən cəhd edin.';

  @override
  String get chatPostMessageLabel => 'Paylaşım';

  @override
  String get friendRequestSendButton => 'Dostluq göndər';

  @override
  String get friendRequestSentLabel => 'Göndərildi';

  @override
  String get friendRequestPendingLabel => 'Gözləmədədir';

  @override
  String get friendRequestAcceptedLabel => 'Dostsunuz';

  @override
  String get friendRequestDeclinedLabel => 'Rədd edilib';

  @override
  String get friendRequestErrorMessage => 'Sorğu göndərilə bilmədi. Bir az sonra yenidən cəhd edin.';

  @override
  String get sendMessageButton => 'Mesaj yaz';

  @override
  String get followButton => 'Takip et';

  @override
  String get followingButton => 'Takipdə';

  @override
  String get followErrorMessage => 'Əməliyyat baş tutmadı. Bir az sonra yenidən cəhd edin.';

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
  String get settingsAccountRowTitle => 'Hesab';

  @override
  String get settingsAccountRowSubtitle => 'Şəxsi məlumatlar, telefon, e-poçt, şifrə';

  @override
  String get changePhotoScreenTitle => 'Profil şəklini dəyiş';

  @override
  String get settingsChangePhotoRowSubtitle => 'Profil şəklinizi yeniləyin və ya silin';

  @override
  String get settingsPrivacyRowSubtitle => 'Görünürlük, bloklar, aktiv cihazlar və s.';

  @override
  String get settingsNotificationsRowSubtitle => 'Mesajlar, push bildirişləri';

  @override
  String get settingsLanguageRowSubtitle => 'Tətbiq dili seçimi';

  @override
  String get settingsIdentityRowSubtitle => 'Şəxsiyyətini təsdiqlə, etibarlı profil nişanı qazan';

  @override
  String get settingsVipRowTitle => 'Meevima VIP';

  @override
  String get settingsVipRowSubtitle => 'VIP-ə keç, paketini idarə et';

  @override
  String get settingsVipActiveLabel => 'Aktiv';

  @override
  String get settingsVipBadgeLabel => 'VIP';

  @override
  String get settingsMapRowTitle => 'Xəritə və Lokasiya';

  @override
  String get settingsMapRowSubtitle => 'Xəritə tipi, məsafə vahidi, GPS';

  @override
  String get settingsPaymentsRowTitle => 'Ödənişlər';

  @override
  String get settingsPaymentsRowSubtitle => 'Ödəniş tarixçəsi, kartlar, abunəlik';

  @override
  String get settingsHelpRowTitle => 'Yardım';

  @override
  String get settingsHelpRowSubtitle => 'FAQ, bizimlə əlaqə, problem bildir';

  @override
  String get settingsLegalRowTitle => 'Hüquqi';

  @override
  String get settingsLegalRowSubtitle => 'Məxfilik siyasəti, istifadə şərtləri';

  @override
  String get settingsAboutRowTitle => 'Haqqında';

  @override
  String get settingsAboutRowSubtitle => 'Versiya, yeniliklər, sosial şəbəkələr';

  @override
  String get settingsLogoutRowTitle => 'Çıxış';

  @override
  String get settingsLogoutRowSubtitle => 'Hesabdan çıx';

  @override
  String get notificationsScreenTitle => 'Bildirişlər';

  @override
  String get notifMessagesTitle => 'Mesajlar';

  @override
  String get notifMessagesSubtitle => 'Yeni mesaj gələndə bildiriş al';

  @override
  String get notifFollowersTitle => 'İzləyicilər';

  @override
  String get notifFollowersSubtitle => 'Yeni izləyici və izləmə istəyi olanda';

  @override
  String get notifNewUsersTitle => 'Yeni istifadəçilər';

  @override
  String get notifNewUsersSubtitle => 'Yaxınlıqda yeni istifadəçi qeydiyyatdan keçəndə';

  @override
  String get notifLikesTitle => 'Bəyənmələr';

  @override
  String get notifLikesSubtitle => 'Kimsə səni bəyənəndə bildiriş al';

  @override
  String get notifCommentsTitle => 'Şərhlər';

  @override
  String get notifCommentsSubtitle => 'Şərh və reaksiyalar üçün bildiriş al';

  @override
  String get notifVenueOffersTitle => 'Məkan təklifləri';

  @override
  String get notifVenueOffersSubtitle => 'İzlədiyin məkanlardan yeni təkliflər';

  @override
  String get notifVenueUpdatesTitle => 'Məkan yenilikləri';

  @override
  String get notifVenueUpdatesSubtitle => 'Məkan əlavəsi və təsdiqlənməsi haqqında';

  @override
  String get notifSecurityTitle => 'Təhlükəsizlik';

  @override
  String get notifSecuritySubtitle => 'Hesabınla bağlı vacib təhlükəsizlik xəbərdarlıqları';

  @override
  String get notifSystemTitle => 'Sistem bildirişləri';

  @override
  String get notifSystemSubtitle => 'Tətbiqlə bağlı vacib elanlar';

  @override
  String get notifMarketingTitle => 'Marketinq';

  @override
  String get notifMarketingSubtitle => 'Kampaniya və endirimlərdən xəbərdar ol';

  @override
  String get notifPushTitle => 'Push bildirişləri';

  @override
  String get notifEmailTitle => 'Email bildirişləri';

  @override
  String get notifUpdateErrorMessage => 'Dəyişiklik saxlanılmadı. Bir az sonra yenidən cəhd edin.';

  @override
  String get mapLocationScreenTitle => 'Xəritə və Lokasiya';

  @override
  String get mapTypeTitle => 'Xəritə tipi';

  @override
  String get mapTypeStandard => 'Standart';

  @override
  String get mapTypeSatellite => 'Peyk';

  @override
  String get mapTypeHybrid => 'Hibrid';

  @override
  String get distanceUnitTitle => 'Məsafə vahidi';

  @override
  String get distanceUnitKm => 'Kilometr';

  @override
  String get distanceUnitMi => 'Mil';

  @override
  String get gpsAccuracyTitle => 'GPS dəqiqliyi';

  @override
  String get gpsAccuracyHigh => 'Yüksək';

  @override
  String get gpsAccuracyStandard => 'Standart';

  @override
  String get backgroundLocationTitle => 'Fon lokasiyası';

  @override
  String get backgroundLocationSubtitle => 'Tətbiq fonda olduqda da lokasiyan yenilənsin';

  @override
  String get backgroundLocationDeniedMessage => 'Fon lokasiyasını aktiv etmək üçün Ayarlar > Tətbiqlər bölməsindən \"Həmişə icazə ver\" seçin.';

  @override
  String get mapLocationUpdateErrorMessage => 'Dəyişiklik saxlanılmadı. Bir az sonra yenidən cəhd edin.';

  @override
  String get helpScreenTitle => 'Yardım';

  @override
  String get helpFaqSectionTitle => 'Tez-tez verilən suallar';

  @override
  String get helpFaq1Question => 'Meevima necə işləyir?';

  @override
  String get helpFaq1Answer => 'Tətbiq lokasiyanı istifadə edərək yaxınlıqdakı digər istifadəçiləri sənə göstərir. Kəşf et bölməsindən radiusu və filtrləri seçə bilərsən.';

  @override
  String get helpFaq2Question => 'Lokasiyamı kim görür?';

  @override
  String get helpFaq2Answer => 'Yalnız təxmini məsafən digər istifadəçilərə göstərilir, dəqiq koordinatların paylaşılmır. Ayarlar > Məxfilik və Təhlükəsizlik bölməsindən Ghost Mode aktivləşdirərək tam gizlənə bilərsən.';

  @override
  String get helpFaq3Question => 'Hesabımı necə silə bilərəm?';

  @override
  String get helpFaq3Answer => 'Ayarlar > Hesab > Hesabımı sil bölməsindən hesabını həmişəlik silə bilərsən. Bu əməliyyat geri qaytarıla bilməz.';

  @override
  String get helpFaq4Question => 'Kimsə məni narahat edirsə nə etməliyəm?';

  @override
  String get helpFaq4Answer => 'İstənilən profildən həmin istifadəçini bloklaya və ya şikayət edə bilərsən. Bloklanan istifadəçi səni bir daha görə bilməyəcək.';

  @override
  String get helpFaq5Question => 'Meevima VIP nə üçündür?';

  @override
  String get helpFaq5Answer => 'VIP üzvlük genişləndirilmiş görünmə radiusu, Ghost Mode və əlavə filtrlər kimi imkanlar təqdim edir.';

  @override
  String get helpFaq6Question => 'Görünmə radiusunu necə dəyişə bilərəm?';

  @override
  String get helpFaq6Answer => 'Kəşf et bölməsində xəritənin altındakı radius seçicisindən istədiyin məsafəni seçə bilərsən.';

  @override
  String get helpContactRowTitle => 'Bizimlə əlaqə';

  @override
  String get helpContactRowSubtitle => 'Suallarınız üçün bizə yazın';

  @override
  String get helpReportProblemRowTitle => 'Problem bildir';

  @override
  String get helpReportProblemRowSubtitle => 'Qarşılaşdığın texniki problemi bizə bildir';

  @override
  String get helpSendSuggestionRowTitle => 'Təklif göndər';

  @override
  String get helpSendSuggestionRowSubtitle => 'Tətbiqi necə yaxşılaşdıraq?';

  @override
  String get contactUsSheetTitle => 'Bizimlə əlaqə';

  @override
  String get contactUsEmailCopiedNotice => 'E-poçt ünvanı kopyalandı';

  @override
  String get contactUsSendEmailButton => 'E-poçt göndər';

  @override
  String get reportProblemSheetTitle => 'Problem bildir';

  @override
  String get sendSuggestionSheetTitle => 'Təklif göndər';

  @override
  String get supportMessageHint => 'Mesajını buraya yaz...';

  @override
  String get supportMessageSendButton => 'Göndər';

  @override
  String get supportMessageSentNotice => 'Mesajın göndərildi. Təşəkkürlər!';

  @override
  String get supportMessageErrorMessage => 'Mesaj göndərilmədi. Bir az sonra yenidən cəhd edin.';

  @override
  String get legalPrivacyPolicyTitle => 'Məxfilik siyasəti';

  @override
  String get legalTermsOfServiceTitle => 'İstifadə şərtləri';

  @override
  String get legalLicensesTitle => 'Lisenziyalar';

  @override
  String get aboutWhatsNewTitle => 'Yeniliklər';

  @override
  String get aboutSocialMediaTitle => 'Sosial media';

  @override
  String get aboutSocialMediaComingSoonLabel => 'Tezliklə';

  @override
  String get aboutCopyrightText => '© 2026 Meevima. Bütün hüquqlar qorunur.';

  @override
  String get aboutChangelogV1Title => 'v1.0.0';

  @override
  String get aboutChangelogV1Body => 'İlk buraxılış: yaxınlıqdakı istifadəçiləri kəşf et, dostluq sorğuları, söhbətlər, hekayələr və profil idarəetməsi.';

  @override
  String get vipHeaderTitle => 'Meevima VIP';

  @override
  String get vipHeaderSubtitle => 'Genişləndirilmiş imkanlarla daha çox insanla tanış ol';

  @override
  String get vipChoosePackageTitle => 'Paket seç';

  @override
  String get vipPeriodMonthly => 'Aylıq';

  @override
  String get vipPeriodQuarterly => '3 Aylıq';

  @override
  String get vipPeriodYearly => 'İllik';

  @override
  String get vipBestValueBadge => 'Ən sərfəli';

  @override
  String get vipPriceComingSoonNote => 'Qiymətlər mağaza tərəfindən aktivləşdikdə burada göstəriləcək.';

  @override
  String get vipSubscribeButton => 'Abunə ol';

  @override
  String get vipAlreadySubscribedButton => 'Artıq VIP-siniz';

  @override
  String get vipBillingComingSoonMessage => 'Ödəniş sistemi tezliklə aktivləşəcək.';

  @override
  String get vipCurrentPackageTitle => 'Cari paket';

  @override
  String get vipCurrentPackageActiveLabel => 'Aktiv';

  @override
  String get vipManageButton => 'İdarə et';

  @override
  String get vipFeatureGhostTitle => 'Ghost Mode';

  @override
  String get vipFeatureGhostDescription => 'Digər istifadəçiləri gör, amma sən xəritədə görünmə.';

  @override
  String get vipFeatureRadiusTitle => 'Genişləndirilmiş radius';

  @override
  String get vipFeatureRadiusDescription => '5 km və 10 km radiusunda olan insanları kəşf et.';

  @override
  String get vipFeatureFilterTitle => 'Əlavə filtrlər';

  @override
  String get vipFeatureFilterDescription => 'Cins və digər filtrlərlə axtarışını dəqiqləşdir.';

  @override
  String get accountScreenTitle => 'Hesab';

  @override
  String get accountPersonalInfoTitle => 'Şəxsi məlumatlar';

  @override
  String get accountPhoneRowTitle => 'Telefon nömrəsi';

  @override
  String get accountEmailRowTitle => 'E-poçt';

  @override
  String get accountEmailEmptyValue => 'Əlavə edilməyib';

  @override
  String get accountPasswordRowTitle => 'Şifrəni dəyiş';

  @override
  String get accountPhoneUnsetValue => 'Təsdiqlənməyib';

  @override
  String get accountChangeEmailSheetTitle => 'E-poçtu dəyiş';

  @override
  String get accountNewEmailLabel => 'Yeni e-poçt ünvanı';

  @override
  String get accountEmailInvalidError => 'Düzgün e-poçt ünvanı daxil edin';

  @override
  String get accountEmailUpdatedNotice => 'E-poçt yeniləndi';

  @override
  String get accountDeleteRowTitle => 'Hesabı sil';

  @override
  String get accountDeleteRowSubtitle => 'Hesabınızı və bütün məlumatlarınızı silin';

  @override
  String get accountDeleteConfirmWordLabel => 'Təsdiq üçün aşağıya \"SİL\" yazın';

  @override
  String get accountDeleteConfirmWordHint => 'SİL';

  @override
  String get accountDeleteConfirmWordMismatchError => 'Davam etmək üçün \"SİL\" sözünü düz yazın';

  @override
  String get paymentsScreenTitle => 'Ödənişlər';

  @override
  String get paymentHistoryRowTitle => 'Ödəniş tarixçəsi';

  @override
  String get myCardsTitle => 'Kartlarım';

  @override
  String get addCardButton => 'Kart əlavə et';

  @override
  String get noCardsMessage => 'Heç bir kart əlavə edilməyib';

  @override
  String get cardOptionsSetDefault => 'Default kart et';

  @override
  String get cardOptionsDelete => 'Sil';

  @override
  String get paymentHistoryEmptyMessage => 'Hələ heç bir əməliyyat yoxdur';

  @override
  String get paymentTypePurchase => 'Alış';

  @override
  String get paymentTypeRenewal => 'Uzatma';

  @override
  String get paymentTypeCancellation => 'Ləğv';

  @override
  String get paymentTypeRefund => 'Geri qaytarma';

  @override
  String get activeDevicesTitle => 'Aktiv cihazlar';

  @override
  String get privacyActiveDevicesSubtitle => 'Aktiv cihazların siyahısı';

  @override
  String get activeDevicesEmptyMessage => 'Aktiv cihaz tapılmadı';

  @override
  String get thisDeviceLabel => 'Bu cihaz';

  @override
  String get lastActiveLabel => 'Son aktivlik';

  @override
  String get signOutDeviceButton => 'Çıxış et';

  @override
  String get signOutDeviceConfirmTitle => 'Bu cihazdan çıxış edilsin?';

  @override
  String get signOutDeviceConfirmMessage => 'Bu cihaz hesabdan uzaqdan çıxarılacaq. Əgər həmin cihaz internetə qoşulu deyilsə, növbəti qoşulanda çıxış ediləcək.';

  @override
  String get signOutDeviceErrorMessage => 'Çıxış edilə bilmədi. Bir az sonra yenidən cəhd edin.';

  @override
  String get privacyTwoFactorActivateTitle => 'İki mərhələli doğrulamanı aktivləşdir';

  @override
  String get privacyTwoFactorDisableButton => 'Deaktiv et';
}
