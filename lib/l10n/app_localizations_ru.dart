// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get welcomeSubtitle => 'Знакомься с людьми рядом,\nзаводи новые знакомства и дружбу.';

  @override
  String get welcomeStartButton => 'Начать';

  @override
  String get loginTitle => 'Войти';

  @override
  String get loginUsernameLabel => 'Имя пользователя';

  @override
  String get loginUsernameHint => 'имя.пользователя';

  @override
  String get loginPasswordLabel => 'Пароль';

  @override
  String get loginPasswordHint => '••••••••';

  @override
  String get loginButtonLabel => 'Войти';

  @override
  String get loginRegisterButtonLabel => 'Зарегистрироваться';

  @override
  String get loginForgotPasswordLabel => 'Забыли пароль?';

  @override
  String get loginAccountNotFoundError => 'Аккаунт с такими данными не найден.';

  @override
  String get loginTooManyAttemptsError => 'Слишком много неудачных попыток. Повторите позже или сбросьте пароль через \"Забыли пароль\".';

  @override
  String get loginNetworkError => 'Нет подключения к интернету. Проверьте соединение и повторите попытку.';

  @override
  String get loginRegisterPromptLabel => 'Хотите зарегистрироваться?';

  @override
  String get registerTitle => 'Регистрация';

  @override
  String get registerUsernameLabel => 'Имя пользователя';

  @override
  String get registerUsernameHint => 'имя.пользователя';

  @override
  String get registerUsernameCheckingLabel => 'Проверка...';

  @override
  String get registerUsernameTakenError => 'Это имя пользователя уже занято.';

  @override
  String get registerUsernameInvalidFormatError => 'Имя пользователя может содержать только буквы, цифры, . и _ (3-20 символов).';

  @override
  String get registerPasswordLabel => 'Пароль';

  @override
  String get registerPasswordHint => 'Минимум 8 символов';

  @override
  String get registerPasswordConfirmLabel => 'Повторите пароль';

  @override
  String get registerPasswordConfirmHint => 'Введите пароль ещё раз';

  @override
  String get registerPasswordTooShortError => 'Пароль должен содержать не менее 8 символов.';

  @override
  String get registerPasswordMismatchError => 'Пароли не совпадают.';

  @override
  String get registerSubmitButton => 'Завершить регистрацию';

  @override
  String get registerGenericError => 'Регистрация не завершена. Повторите попытку позже.';

  @override
  String get registerSuccessMessage => 'Регистрация завершена — теперь вы можете войти.';

  @override
  String get phoneAuthTitle => 'Твой номер телефона';

  @override
  String get phoneAuthSubtitle => 'Тебе понадобится код, отправленный по SMS.';

  @override
  String get phoneAuthNumberHint => '50 123 45 67';

  @override
  String get phoneAuthContinueButton => 'Продолжить с номером телефона';

  @override
  String get phoneAuthInvalidNumberError => 'Введите корректный номер телефона';

  @override
  String get phoneAuthVerificationFailedError => 'Не удалось подтвердить номер, попробуйте ещё раз.';

  @override
  String get pickCountryTitle => 'Выберите страну';

  @override
  String get otpTitle => 'Введите код';

  @override
  String otpSubtitle(String phone) {
    return 'Введите 6-значный код, отправленный на $phone.';
  }

  @override
  String get otpCodeHint => '••••••';

  @override
  String get otpConfirmButton => 'Подтвердить';

  @override
  String get otpIncompleteCodeError => 'Введите полный 6-значный код';

  @override
  String get otpInvalidCodeError => 'Код неверен или срок его действия истёк.';

  @override
  String get otpResendButton => 'Отправить код повторно';

  @override
  String otpResendWaitLabel(String time) {
    return 'Повторная отправка через: $time';
  }

  @override
  String get verificationRequiredTitle => 'Подтвердите аккаунт';

  @override
  String get verificationRequiredMessage => 'Чтобы использовать эту функцию, сначала подтвердите свой аккаунт.';

  @override
  String get verificationRequiredButton => 'Подтвердить аккаунт';

  @override
  String get accountVerificationTitle => 'Подтвердите аккаунт';

  @override
  String get accountVerificationSubtitle => 'Подтвердите номер телефона, чтобы разблокировать все функции.';

  @override
  String get accountVerificationPhoneTakenError => 'Этот номер телефона уже используется в другом аккаунте.';

  @override
  String get accountVerificationSuccessMessage => 'Ваш аккаунт подтверждён.';

  @override
  String get settingsAccountVerificationRowTitle => 'Подтвердить аккаунт';

  @override
  String get settingsAccountVerifiedRowSubtitle => 'Аккаунт подтверждён';

  @override
  String get settingsIdentityVerificationRowTitle => 'Проверка личности';

  @override
  String get swipeMatchedMessage => 'Вы понравились друг другу!';

  @override
  String get swipeErrorMessage => 'Что-то пошло не так. Повторите попытку позже.';

  @override
  String get forgotPasswordTitle => 'Забыли пароль';

  @override
  String get forgotPasswordSubtitle => 'Введите номер телефона, привязанный к вашему аккаунту.';

  @override
  String get forgotPasswordAccountNotFoundError => 'Аккаунт с этим номером телефона не найден.';

  @override
  String get newPasswordTitle => 'Новый пароль';

  @override
  String get newPasswordSubtitle => 'Установите новый пароль для вашего аккаунта.';

  @override
  String get newPasswordLabel => 'Новый пароль';

  @override
  String get newPasswordHint => 'Минимум 8 символов';

  @override
  String get newPasswordConfirmLabel => 'Повторите новый пароль';

  @override
  String get newPasswordConfirmHint => 'Введите пароль ещё раз';

  @override
  String get newPasswordSubmitButton => 'Обновить пароль';

  @override
  String get newPasswordSuccessMessage => 'Пароль обновлён — теперь вы можете войти.';

  @override
  String get newPasswordGenericError => 'Пароль не обновлён. Повторите попытку позже.';

  @override
  String get changePasswordTitle => 'Изменить пароль';

  @override
  String get changePasswordCurrentLabel => 'Текущий пароль';

  @override
  String get changePasswordCurrentHint => 'Введите текущий пароль';

  @override
  String get changePasswordNewLabel => 'Новый пароль';

  @override
  String get changePasswordNewHint => 'Минимум 8 символов';

  @override
  String get changePasswordConfirmLabel => 'Повторите новый пароль';

  @override
  String get changePasswordConfirmHint => 'Введите пароль ещё раз';

  @override
  String get changePasswordSubmitButton => 'Обновить пароль';

  @override
  String get changePasswordWrongCurrentError => 'Текущий пароль неверен.';

  @override
  String get changePasswordSuccessMessage => 'Пароль обновлён.';

  @override
  String get changePasswordGenericError => 'Пароль не изменён. Повторите попытку позже.';

  @override
  String get onboardingAppBarTitle => 'Заполни профиль';

  @override
  String get onboardingPhotoOptionalLabel => 'Добавить фото (необязательно)';

  @override
  String get fieldFirstNameLabel => 'Имя';

  @override
  String get fieldFirstNameHint => 'Расим';

  @override
  String get fieldFirstNameRequiredError => 'Введите имя';

  @override
  String get fieldLastNameLabel => 'Фамилия';

  @override
  String get fieldLastNameHint => 'Мамедов';

  @override
  String get fieldLastNameRequiredError => 'Введите фамилию';

  @override
  String get fieldBirthDateLabel => 'Дата рождения';

  @override
  String get fieldBirthDateHint => 'дд.мм.гггг';

  @override
  String get birthDatePickerHelpText => 'Выберите дату рождения';

  @override
  String get fieldGenderLabel => 'Пол';

  @override
  String get sectionCountryCityTitle => 'Страна и город';

  @override
  String get sectionAboutOptionalTitle => 'О себе (необязательно)';

  @override
  String get bioHintOnboarding => 'Несколько предложений о себе...';

  @override
  String get onboardingFinishButton => 'Завершить и продолжить';

  @override
  String get onboardingSelectBirthDateError => 'Выберите дату рождения';

  @override
  String get onboardingSelectGenderError => 'Выберите пол';

  @override
  String get onboardingSelectCountryCityError => 'Выберите страну и город';

  @override
  String get onboardingPhotoUploadFailedError => 'Не удалось загрузить фото, вы сможете добавить его позже в профиле.';

  @override
  String errorWithDetails(String error) {
    return 'Произошла ошибка: $error';
  }

  @override
  String get navDiscoverLabel => 'Обзор';

  @override
  String get navChatsLabel => 'Чат';

  @override
  String get navFeedLabel => 'Лента';

  @override
  String get navNotificationsLabel => 'Уведомления';

  @override
  String get navProfileLabel => 'Профиль';

  @override
  String get notificationsFeedTitle => 'Уведомления';

  @override
  String get notifMenuMarkAllRead => 'Отметить все как прочитанные';

  @override
  String get notifMenuDeleteRead => 'Удалить прочитанные';

  @override
  String get notifMenuSettings => 'Настройки уведомлений';

  @override
  String get notifEmptyTitle => 'Нет уведомлений';

  @override
  String get notifEmptySubtitle => 'Новые уведомления появятся здесь.';

  @override
  String get notifErrorOfflineTitle => 'Нет подключения к интернету';

  @override
  String get notifErrorOfflineMessage => 'Подключитесь к интернету, чтобы загрузить уведомления.';

  @override
  String get notifErrorPermissionTitle => 'Нет доступа';

  @override
  String get notifErrorPermissionMessage => 'У вас нет доступа для просмотра этих уведомлений.';

  @override
  String get notifErrorUnknownTitle => 'Произошла ошибка';

  @override
  String get notifErrorUnknownMessage => 'Не удалось загрузить уведомления. Повторите попытку позже.';

  @override
  String get notifMarkAllReadDone => 'Все уведомления отмечены как прочитанные';

  @override
  String get notifDeleteReadDone => 'Прочитанные уведомления удалены';

  @override
  String get notifActionErrorMessage => 'Операция не выполнена. Повторите попытку позже.';

  @override
  String get discoverTitle => 'Обзор';

  @override
  String get viewSwitcherPeopleLabel => 'Люди';

  @override
  String get viewSwitcherPlacesLabel => 'Места';

  @override
  String get viewSwitcherOffersLabel => 'Предложения';

  @override
  String get genderFilterAll => 'Все';

  @override
  String get genderFilterMale => 'Мужчины';

  @override
  String get genderFilterFemale => 'Женщины';

  @override
  String get genderFilterTooltip => 'Фильтр';

  @override
  String get genderFilterSheetTitle => 'Фильтр по полу';

  @override
  String get locationSearchingTitle => 'Определяем местоположение...';

  @override
  String get locationSearchingSubtitle => 'Это может занять несколько секунд.';

  @override
  String get locationServiceDisabledTitle => 'Службы геолокации отключены';

  @override
  String get locationServiceDisabledSubtitle => 'Включите геолокацию на устройстве, чтобы видеть людей поблизости.';

  @override
  String get actionOpenSettings => 'Открыть настройки';

  @override
  String get locationPermissionDeniedTitle => 'Нужен доступ к геолокации';

  @override
  String get locationPermissionDeniedSubtitle => 'Разрешите доступ, чтобы видеть людей вокруг вас.';

  @override
  String get actionRetry => 'Повторить';

  @override
  String get chatPermissionDeniedMessage => 'У вас сейчас нет доступа к этой переписке. Попробуйте выйти и снова войти в аккаунт или повторить попытку позже.';

  @override
  String get chatLoadErrorMessage => 'Произошла ошибка при загрузке. Попробуйте ещё раз.';

  @override
  String get locationPermissionDeniedForeverTitle => 'Доступ отклонён навсегда';

  @override
  String get locationPermissionDeniedForeverSubtitle => 'Включите доступ к геолокации для \"Meevima\" вручную в настройках телефона.';

  @override
  String get actionOpenAppSettings => 'Открыть настройки приложения';

  @override
  String get errorTitle => 'Произошла ошибка';

  @override
  String get meMarkerLabel => 'Вы здесь';

  @override
  String get defaultUserName => 'Пользователь';

  @override
  String get startChatButton => 'Начать чат';

  @override
  String get viewProfileButton => 'Смотреть профиль';

  @override
  String get chatMessageHint => 'Сообщение...';

  @override
  String get chatRequestSentNotice => 'Запрос на сообщение отправлен';

  @override
  String get chatRequestBannerTitle => 'Запрос на сообщение';

  @override
  String get chatRequestBannerSubtitle => 'Примите запрос, чтобы начать переписку.';

  @override
  String get chatRequestAcceptButton => 'Принять';

  @override
  String get chatRequestDeclineButton => 'Отклонить';

  @override
  String get chatRequestPendingNotice => 'Ожидайте, пока получатель примет ваш запрос.';

  @override
  String get chatRequestDeclinedNotice => 'Этот запрос на сообщение отклонён.';

  @override
  String get chatRequestDeclinedByPeerNotice => 'Этот пользователь отклонил ваш запрос на сообщение.';

  @override
  String get chatRequestActionErrorMessage => 'Не удалось выполнить действие. Попробуйте ещё раз чуть позже.';

  @override
  String get chatOnlineStatus => 'В сети';

  @override
  String get chatLastSeenUnknown => 'Не в сети';

  @override
  String chatLastSeenAt(String time) {
    return 'Был(а) в сети: $time';
  }

  @override
  String get chatTypingIndicator => 'печатает...';

  @override
  String get chatDateToday => 'Сегодня';

  @override
  String get chatDateYesterday => 'Вчера';

  @override
  String get chatMenuViewProfile => 'Смотреть профиль';

  @override
  String get chatMenuBlock => 'Заблокировать пользователя';

  @override
  String get chatMenuUnblock => 'Разблокировать';

  @override
  String get chatUserUnblockedNotice => 'Пользователь разблокирован.';

  @override
  String get chatMenuReport => 'Пожаловаться на пользователя';

  @override
  String get chatMenuDeleteChat => 'Удалить чат';

  @override
  String get chatBlockConfirmTitle => 'Заблокировать этого пользователя?';

  @override
  String get chatBlockConfirmMessage => 'Он больше не сможет писать вам.';

  @override
  String get chatDeleteConfirmTitle => 'Удалить этот чат?';

  @override
  String get chatDeleteConfirmMessage => 'Эта переписка будет удалена без возможности восстановления.';

  @override
  String get chatReportTitle => 'Пожаловаться на пользователя';

  @override
  String get chatReportReasonHint => 'Опишите проблему...';

  @override
  String get chatReportSubmitButton => 'Отправить жалобу';

  @override
  String get chatReportSentNotice => 'Жалоба отправлена, спасибо.';

  @override
  String get chatReportReasonInappropriate => 'Неприемлемый контент';

  @override
  String get chatReportReasonFakeProfile => 'Поддельный профиль';

  @override
  String get chatReportReasonDangerous => 'Опасное поведение';

  @override
  String get chatReportReasonOther => 'Другое';

  @override
  String get chatSendBlockedError => 'Вы не можете отправить сообщение этому пользователю.';

  @override
  String get chatUserBlockedNotice => 'Пользователь заблокирован.';

  @override
  String get chatEmptyConversation => 'Поздоровайтесь 👋';

  @override
  String get chatEmptyStateTitle => 'Отправьте первое сообщение';

  @override
  String get chatEmptyStateSubtitle => 'Начните разговор снизу или поздоровайтесь одним касанием.';

  @override
  String get chatEmptyStateGreetingButton => 'Привет 👋';

  @override
  String get chatVoiceComingSoonMessage => 'Голосовые сообщения скоро появятся.';

  @override
  String get chatEmojiPickerTitle => 'Выберите эмодзи';

  @override
  String get chatImageMessageLabel => 'Фото';

  @override
  String get chatVideoMessageLabel => 'Видео';

  @override
  String get chatAudioMessageLabel => 'Голосовое сообщение';

  @override
  String get chatSendButton => 'Отправить';

  @override
  String get chatRetakeButton => 'Переснять';

  @override
  String get chatAttachmentSheetTitle => 'Выберите медиа';

  @override
  String get chatAttachmentImageOption => 'Фото';

  @override
  String get chatAttachmentVideoOption => 'Видео';

  @override
  String get chatRecordingCancelHint => 'Проведите, чтобы отменить';

  @override
  String get chatRecordingLockHint => 'Проведите вверх, чтобы заблокировать';

  @override
  String get chatVoiceFinishButton => 'Готово';

  @override
  String get chatVoiceTooShortMessage => 'Голосовое сообщение слишком короткое';

  @override
  String get chatMicPermissionDeniedMessage => 'Для отправки голосовых сообщений нужен доступ к микрофону.';

  @override
  String get chatCameraPermissionDeniedMessage => 'Для съёмки фото нужен доступ к камере.';

  @override
  String get chatMediaUploadFailedMessage => 'Не отправлено';

  @override
  String get chatMediaTooLargeMessage => 'Файл слишком большой.';

  @override
  String get chatCallComingSoonMessage => 'Звонки скоро появятся.';

  @override
  String get chatVoiceCallLabel => 'Голосовой звонок';

  @override
  String get chatVideoCallLabel => 'Видеозвонок';

  @override
  String get chatMessageDeleteForMeOption => 'Удалить у себя';

  @override
  String get chatMessageDeleteForEveryoneOption => 'Удалить у всех';

  @override
  String get chatMessageDeleteForEveryoneConfirmMessage => 'Это сообщение будет удалено навсегда для обеих сторон.';

  @override
  String get chatMessageDeleteOption => 'Удалить';

  @override
  String get chatMessageForwardOption => 'Переслать';

  @override
  String get chatForwardTitle => 'Переслать';

  @override
  String get chatForwardEmptyMessage => 'У вас нет чатов для пересылки.';

  @override
  String chatForwardSendButton(int count) {
    return 'Отправить ($count)';
  }

  @override
  String get chatForwardSuccessMessage => 'Сообщение переслано.';

  @override
  String get actionCancel => 'Отмена';

  @override
  String get actionDelete => 'Удалить';

  @override
  String distanceMetersAway(int meters) {
    return '$meters м от вас';
  }

  @override
  String distanceKmAway(String km) {
    return '$km км от вас';
  }

  @override
  String distanceMilesAway(String mi) {
    return '$mi ми от вас';
  }

  @override
  String radiusPeopleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count человека',
      many: '$count человек',
      few: '$count человека',
      one: '$count человек',
    );
    return '$_temp0';
  }

  @override
  String get radiusMoreButtonLabel => 'Ещё';

  @override
  String get radiusMorePanelTitle => 'Радиус поиска';

  @override
  String get premiumUpsellRadiusTitle => 'Знакомься с людьми на большем расстоянии 🌍';

  @override
  String get premiumUpsellRadiusMessage => 'С Premium ты сможешь видеть людей в радиусе 5 и 10 км и знакомиться с большим числом людей.';

  @override
  String get premiumUpgradeButton => 'Перейти на Premium';

  @override
  String get premiumLaterButton => 'Позже';

  @override
  String get premiumComingSoonTitle => 'Premium';

  @override
  String get premiumComingSoonMessage => 'Premium-подписка скоро станет доступна.';

  @override
  String get chatsTitle => 'Чаты';

  @override
  String get chatsEmptyTitle => 'Пока нет чатов';

  @override
  String get chatsEmptySubtitle => 'Здесь появятся чаты, когда вы познакомитесь с людьми рядом.';

  @override
  String get chatsSearchHint => 'Поиск по чатам';

  @override
  String get chatsSearchEmptyTitle => 'Ничего не найдено';

  @override
  String get chatsSearchEmptySubtitle => 'Попробуйте другое имя, username или слово.';

  @override
  String get chatsFilterAll => 'Все';

  @override
  String get chatsFilterUnread => 'Непрочитанные';

  @override
  String get chatsFilterArchived => 'Архив';

  @override
  String get chatsFilterRequests => 'Запросы';

  @override
  String get chatsUnreadEmptyTitle => 'Нет непрочитанных сообщений';

  @override
  String get chatsUnreadEmptySubtitle => 'Все сообщения прочитаны.';

  @override
  String get chatsArchivedEmptyTitle => 'Нет архивированных чатов';

  @override
  String get chatsArchivedEmptySubtitle => 'Архивированные чаты появятся здесь.';

  @override
  String get chatsRequestsEmptyTitle => 'Нет запросов на сообщения';

  @override
  String get chatsRequestsEmptySubtitle => 'Первые сообщения от незнакомых людей появятся здесь.';

  @override
  String get chatsPinLimitReachedMessage => 'Можно закрепить не более 3 чатов.';

  @override
  String get chatsPinAction => 'Закрепить';

  @override
  String get chatsUnpinAction => 'Открепить';

  @override
  String get chatsArchiveAction => 'Архивировать';

  @override
  String get chatsUnarchiveAction => 'Восстановить';

  @override
  String get chatsMuteAction => 'Без звука';

  @override
  String get chatsUnmuteAction => 'Включить звук';

  @override
  String get chatsPinnedSectionLabel => 'Закреплённые';

  @override
  String get chatsRecentSectionLabel => 'Недавние чаты';

  @override
  String get eventSaveButton => 'Сохранить';

  @override
  String get venueCreateTitle => 'Профиль заведения';

  @override
  String get venueEditTitle => 'Редактировать заведение';

  @override
  String get venuePhotoLabel => 'Добавить фото/логотип';

  @override
  String get venuePhotoSheetTitle => 'Добавить фото';

  @override
  String get venuePhotoGalleryOption => 'Выбрать из галереи';

  @override
  String get venuePhotoCameraOption => 'Сделать фото';

  @override
  String get venueNameLabel => 'Название';

  @override
  String get venueNameHint => 'Название заведения';

  @override
  String get venueFieldRequiredError => 'Это поле обязательно';

  @override
  String get venueCategoryLabel => 'Категория';

  @override
  String get venueCategoryPickerTitle => 'Выберите категорию';

  @override
  String get venueCategorySearchHint => 'Поиск категории...';

  @override
  String get venueCategoryChangeHint => 'Нажмите, чтобы изменить';

  @override
  String get venuePhotoCropTitle => 'Обрезать фото';

  @override
  String get venueUploadingLabel => 'Загрузка...';

  @override
  String get venueUploadCancelButton => 'Отмена';

  @override
  String get venueDirectionsGoogleMaps => 'Google Maps';

  @override
  String get venueDirectionsAppleMaps => 'Apple Maps';

  @override
  String get venueDirectionsWaze => 'Waze';

  @override
  String get venueScheduleLabel => 'Недельное расписание';

  @override
  String get venueFullAddressLabel => 'Полный адрес';

  @override
  String get venuesSearchHint => 'Поиск заведений...';

  @override
  String get venueFilterTooltip => 'Фильтр';

  @override
  String get venueCategoryFilterTitle => 'Выберите категорию';

  @override
  String get venueCategoryAllOption => 'Все';

  @override
  String get offersSearchHint => 'Поиск предложений...';

  @override
  String get offerFilterTooltip => 'Фильтр';

  @override
  String get offersEmptyTitle => 'Пока нет предложений';

  @override
  String get offersEmptySubtitle => 'Предложения от ближайших заведений появятся здесь.';

  @override
  String get offerCategoryFilterTitle => 'Выберите категорию';

  @override
  String get offerCategoryAllOption => 'Все';

  @override
  String get offerBadgeDiscountSuffix => 'скидка';

  @override
  String get offerBadgeGiftLabel => 'Подарок';

  @override
  String get offerBadgeBuyOneGetOneLabel => '1+1';

  @override
  String get offerBadgeFixedPriceSuffix => 'AZN';

  @override
  String offerEndsOnLabel(String date) {
    return 'До $date';
  }

  @override
  String get offerTermsLabel => 'Условия';

  @override
  String get offerValidityLabel => 'Срок действия';

  @override
  String get offerStartDateLabel => 'Начало';

  @override
  String get offerEndDateLabel => 'Окончание';

  @override
  String get offerContactLabel => 'Контакты';

  @override
  String get offerOtherActiveOffersLabel => 'Другие активные предложения';

  @override
  String get offerViewVenueProfileButton => 'Перейти в профиль заведения';

  @override
  String get offerNotFoundMessage => 'Предложение не найдено.';

  @override
  String get offerGenericErrorMessage => 'Операция не выполнена. Повторите попытку позже.';

  @override
  String get offerCreateTitle => 'Создать предложение';

  @override
  String get offerEditTitle => 'Изменить предложение';

  @override
  String get offerPhotoLabel => 'Добавить фото/логотип';

  @override
  String get offerNameLabel => 'Название предложения';

  @override
  String get offerNameHint => 'Введите название предложения';

  @override
  String get offerCategoryLabel => 'Выберите категорию';

  @override
  String get offerTypeLabel => 'Тип предложения';

  @override
  String get offerTypeDiscountOption => 'Скидка';

  @override
  String get offerTypeGiftOption => 'Подарок';

  @override
  String get offerTypeBuyOneGetOneOption => '1+1 подарок';

  @override
  String get offerTypeFixedPriceOption => 'Фиксированная цена';

  @override
  String get offerDiscountAmountLabel => 'Размер скидки';

  @override
  String get offerFixedPriceLabel => 'Цена (AZN)';

  @override
  String get offerFixedPriceHint => 'Введите цену';

  @override
  String get offerDescriptionLabel => 'Краткое описание';

  @override
  String get offerDescriptionHint => 'Опишите условия и преимущества предложения...';

  @override
  String get offerValidityPeriodLabel => 'Срок действия предложения';

  @override
  String get offerStartDatePickerLabel => 'Дата начала';

  @override
  String get offerEndDatePickerLabel => 'Дата окончания';

  @override
  String get offerVenuePickerLabel => 'Выберите заведение';

  @override
  String get offerVenuePickerHint => 'Выберите заведение';

  @override
  String get offerNoVenuesTitle => 'У вас пока нет заведений';

  @override
  String get offerNoVenuesSubtitle => 'Сначала добавьте заведение, чтобы создать предложение.';

  @override
  String get offerAddVenueButton => 'Добавить заведение';

  @override
  String get offerTermsHint => 'Опишите условия использования предложения...';

  @override
  String get offerAdditionalInfoLabel => 'Дополнительная информация';

  @override
  String get offerContactPhoneHint => 'Номер телефона';

  @override
  String get offerContactWebsiteHint => 'Веб-сайт';

  @override
  String get offerContactInstagramHint => 'Instagram';

  @override
  String get offerSubmitButton => 'Создать предложение';

  @override
  String get offerCreatedNotice => 'Предложение создано';

  @override
  String get offerUpdatedNotice => 'Предложение обновлено';

  @override
  String get offerRequiredFieldsMissing => 'Пожалуйста, заполните все обязательные поля.';

  @override
  String get offerDatesInvalidError => 'Дата окончания должна быть позже даты начала.';

  @override
  String get offerDeleteMenuOption => 'Удалить предложение';

  @override
  String get offerDeleteConfirmMessage => 'Вы уверены, что хотите удалить это предложение? Это действие нельзя отменить.';

  @override
  String get offerDeletedNotice => 'Предложение удалено';

  @override
  String get offerStatusActive => 'Активно';

  @override
  String get offerStatusExpired => 'Истекло';

  @override
  String get offerMyOffersTitle => 'Мои предложения';

  @override
  String get offerMyOffersEmptyTitle => 'Вы ещё не добавили ни одного предложения';

  @override
  String get offerMyOffersEmptySubtitle => 'Добавленные вами предложения появятся здесь, вы сможете редактировать или удалять их в любое время.';

  @override
  String get offerMyOffersTooltip => 'Мои предложения';

  @override
  String get offerAddButtonTooltip => 'Создать предложение';

  @override
  String get venueCategoryUnselectedLabel => 'Выбрать';

  @override
  String get venueCategoryRestaurant => 'Ресторан';

  @override
  String get venueCategoryPub => 'Паб';

  @override
  String get venueCategoryCoffeeShop => 'Coffee Shops';

  @override
  String get venueCategoryFastFood => 'Фастфуд';

  @override
  String get venueCategoryTeaHouse => 'Чайхана';

  @override
  String get venueCategorySweetsShop => 'Кондитерская';

  @override
  String get venueCategoryHotel => 'Отель';

  @override
  String get venueCategoryMotel => 'Мотель';

  @override
  String get venueCategoryCinema => 'Кинотеатр';

  @override
  String get venueCategoryKaraoke => 'Караоке-бар';

  @override
  String get venueCategoryGameHall => 'Игровой зал';

  @override
  String get venueCategoryNightClub => 'Ночной клуб';

  @override
  String get venueCategoryFitness => 'Фитнес';

  @override
  String get venueCategoryGym => 'Тренажёрный зал';

  @override
  String get venueCategorySpa => 'Спа, массаж и сауна';

  @override
  String get venueCategoryFootballField => 'Футбольное поле';

  @override
  String get venueCategoryClinic => 'Клиника';

  @override
  String get venueCategoryBeautySalon => 'Салон красоты';

  @override
  String get venueCategoryBarbershop => 'Барбершоп';

  @override
  String get venueCategoryCosmetology => 'Косметология';

  @override
  String get venueCategoryTattoo => 'Тату и пирсинг';

  @override
  String get venueCategoryPhotoStudio => 'Фотостудия';

  @override
  String get venueCategoryKidsEntertainment => 'Детские развлечения';

  @override
  String get venueCategoryOther => 'Другое';

  @override
  String get venueHoursLabel => 'Часы работы';

  @override
  String get venueHours24Label => 'Открыто круглосуточно';

  @override
  String get venueHoursSameEveryDayLabel => 'Одинаковые часы каждый день';

  @override
  String get venueWeekdayMon => 'Пн';

  @override
  String get venueWeekdayTue => 'Вт';

  @override
  String get venueWeekdayWed => 'Ср';

  @override
  String get venueWeekdayThu => 'Чт';

  @override
  String get venueWeekdayFri => 'Пт';

  @override
  String get venueWeekdaySat => 'Сб';

  @override
  String get venueWeekdaySun => 'Вс';

  @override
  String get venueLocationLabel => 'Адрес/местоположение';

  @override
  String get venuePickOnMapButton => 'Выбрать на карте';

  @override
  String get venueLocationPickedLabel => 'Выбрано на карте ✓';

  @override
  String get venueLocationPickerTitle => 'Выберите местоположение';

  @override
  String get venueLocationPickerHint => 'Нажмите на карту или перетащите метку в нужную точку';

  @override
  String get venueLocationResolvingAddress => 'Определение адреса...';

  @override
  String get venueLocationAddressUnavailable => 'Адрес не найден';

  @override
  String get venueLocationPickerConfirmButton => 'Выбрать это место';

  @override
  String get venueCreateButton => 'Добавить';

  @override
  String get venueSaveButton => 'Сохранить';

  @override
  String get venueRequiredFieldsMissing => 'Пожалуйста, заполните все обязательные поля.';

  @override
  String get venueGenericErrorMessage => 'Не удалось выполнить действие. Попробуйте ещё раз чуть позже.';

  @override
  String get venueAddButtonTooltip => 'Добавить заведение';

  @override
  String get venuesEmptyTitle => 'Поблизости нет заведений';

  @override
  String get venuesEmptySubtitle => 'В выбранном радиусе пока никто не добавил заведение.';

  @override
  String get venueMyVenuesTooltip => 'Мои заведения';

  @override
  String get venueMyVenuesTitle => 'Мои заведения';

  @override
  String get venueMyVenuesEmptyTitle => 'Вы ещё не добавили ни одного заведения';

  @override
  String get venueMyVenuesEmptySubtitle => 'Добавленные вами заведения появятся здесь, и вы сможете редактировать или удалять их в любое время.';

  @override
  String get venueDeleteMenuOption => 'Удалить заведение';

  @override
  String get venueDeleteConfirmMessage => 'Вы уверены, что хотите удалить это заведение? Это действие нельзя отменить.';

  @override
  String get venueDeletedNotice => 'Заведение удалено';

  @override
  String get venueOpenNowLabel => 'Открыто';

  @override
  String get venueClosedNowLabel => 'Закрыто';

  @override
  String get profileTitle => 'Профиль';

  @override
  String get profileNamePlaceholder => 'Добавьте имя';

  @override
  String get profileBioPlaceholder => 'Добавьте фото, био и интересы';

  @override
  String get shareProfileLabel => 'Поделиться профилем';

  @override
  String get profileStatsFriends => 'Друзья';

  @override
  String get profileStatsLikes => 'Лайки';

  @override
  String get profileGalleryEmptyMessage => 'Вы ещё не загрузили фото или видео';

  @override
  String get editProfileTitle => 'Личные данные';

  @override
  String get personalInfoSubtitle => 'Обновите свои данные и сохраните изменения.';

  @override
  String get profileSaveSuccessMessage => 'Ваши данные обновлены.';

  @override
  String get menuSettings => 'Настройки';

  @override
  String get menuPrivacySecurity => 'Конфиденциальность и безопасность';

  @override
  String get privacySecurityTitle => 'Конфиденциальность и безопасность';

  @override
  String get privacyProfileVisibilityTitle => 'Видимость медиа';

  @override
  String get privacyProfileVisibilitySubtitle => 'Выберите, кто может видеть публикации в вашем профиле.';

  @override
  String get privacyVisibilityEveryone => 'Все';

  @override
  String get privacyVisibilityFollowersOnly => 'Подписки и подписчики';

  @override
  String get privacyVisibilityNoOne => 'Никто';

  @override
  String get privacyClosedProfileNotice => 'Закрытый профиль';

  @override
  String get privacyRadiusTitle => 'Радиус видимости';

  @override
  String get privacyRadiusCountryLabel => 'По стране';

  @override
  String get privacyRadiusWorldLabel => 'По всему миру';

  @override
  String get privacyOnlineStatusTitle => 'Показывать, что я в сети';

  @override
  String get privacyReadReceiptsTitle => 'Показывать статус прочтения';

  @override
  String get privacyReadReceiptsHelperText => 'Отключив это, вы тоже не будете видеть статус прочтения собеседника.';

  @override
  String get privacyWhoCanMessageTitle => 'Кто может писать мне';

  @override
  String get privacyMessagePermEveryone => 'Все';

  @override
  String get privacyMessagePermVerifiedOnly => 'Только проверенные пользователи';

  @override
  String get privacyMessagePermNoOne => 'Никто';

  @override
  String get privacyGhostModeTitle => 'Скрытый режим';

  @override
  String get privacyGhostModeDescription => 'Вы можете видеть других пользователей. Другие пользователи не увидят вас на карте. Включайте и выключайте в любое время.';

  @override
  String get privacyGhostModePremiumTitle => 'Станьте невидимым со скрытым режимом 👻';

  @override
  String get privacyGhostModePremiumMessage => 'С Premium вы сможете видеть других пользователей, но они не увидят вас на карте.';

  @override
  String get privacySettingUpdateErrorMessage => 'Изменение не сохранено. Попробуйте ещё раз чуть позже.';

  @override
  String get privacyTwoFactorTitle => 'Включить двухфакторную аутентификацию';

  @override
  String get privacyTwoFactorHelperText => 'Пока сохраняется только ваш выбор — поддержка SMS и Authenticator появится позже.';

  @override
  String get privacyExportDataTitle => 'Скачать мои данные';

  @override
  String get privacyExportDataDescription => 'Данные, хранящиеся о вас в приложении, будут подготовлены и показаны вам.';

  @override
  String get exportDataScreenTitle => 'Мои данные';

  @override
  String get exportDataCopyButton => 'Копировать';

  @override
  String get exportDataCopiedNotice => 'Данные скопированы в буфер обмена.';

  @override
  String get exportDataLoadErrorMessage => 'Не удалось загрузить данные. Попробуйте ещё раз.';

  @override
  String get privacyDeleteAccountTitle => 'Удалить мой аккаунт';

  @override
  String get deleteAccountWarningTitle => 'Вы уверены, что хотите удалить аккаунт?';

  @override
  String get deleteAccountWarningMessage => 'Ваш профиль, чаты и все данные будут удалены навсегда. Это действие нельзя отменить.';

  @override
  String get deleteAccountFinalConfirmTitle => 'Окончательное подтверждение';

  @override
  String get deleteAccountFinalConfirmMessage => 'Вы собираетесь удалить свой аккаунт. После этого пути назад нет.';

  @override
  String get deleteAccountConfirmButton => 'Да, удалить мой аккаунт';

  @override
  String get deleteAccountReauthTitle => 'Подтвердите, что это вы';

  @override
  String get deleteAccountReauthMessage => 'Из соображений безопасности перед удалением аккаунта нужно заново подтвердить номер телефона.';

  @override
  String get deleteAccountSendCodeButton => 'Отправить код';

  @override
  String get deleteAccountCodeSentMessage => 'Код отправлен';

  @override
  String get deleteAccountOtpHint => 'SMS-код';

  @override
  String get deleteAccountConfirmCodeButton => 'Подтвердить';

  @override
  String get deleteAccountReauthFailedMessage => 'Подтверждение не удалось. Попробуйте ещё раз.';

  @override
  String get deleteAccountErrorMessage => 'Не удалось удалить аккаунт. Попробуйте ещё раз чуть позже.';

  @override
  String get blockedUsersTitle => 'Заблокированные пользователи';

  @override
  String get blockedUsersEmptyTitle => 'Нет заблокированных пользователей';

  @override
  String get blockedUsersEmptySubtitle => 'Заблокированные вами пользователи появятся здесь.';

  @override
  String get menuNotifications => 'Уведомления';

  @override
  String get menuHelp => 'Помощь';

  @override
  String get menuLogout => 'Выйти';

  @override
  String uploadingProgress(String percent) {
    return 'Загрузка $percent%...';
  }

  @override
  String get removePhotoButton => 'Удалить фото';

  @override
  String get fieldAgeLabel => 'Возраст';

  @override
  String get fieldAgeHint => '25';

  @override
  String get fieldEmailOptionalLabel => 'Email (необязательно)';

  @override
  String get fieldEmailHint => 'name@email.com';

  @override
  String get sectionAboutTitle => 'О себе';

  @override
  String get bioHintEdit => 'Напиши несколько предложений о себе...';

  @override
  String get saveButton => 'Сохранить';

  @override
  String get waitPhotoUploadError => 'Дождитесь завершения загрузки фото...';

  @override
  String get invalidEmailError => 'Введите корректный email';

  @override
  String saveFailedError(String error) {
    return 'Не удалось сохранить: $error';
  }

  @override
  String get photoOperationFailedError => 'Операция с фото не удалась.';

  @override
  String get storageErrorFileTooLarge => 'Фото не может быть больше 5 МБ.';

  @override
  String get storageErrorInvalidContentType => 'Неподдерживаемый формат файла.';

  @override
  String get storageErrorUploadFailed => 'Не удалось загрузить фото.';

  @override
  String get storageErrorDownloadUrlFailed => 'Не удалось загрузить фото.';

  @override
  String get storageErrorDeleteFailed => 'Не удалось удалить фото.';

  @override
  String get storageErrorPermissionDenied => 'У вас нет разрешения для этого действия.';

  @override
  String get storageErrorUnauthenticated => 'Вы не вошли в систему.';

  @override
  String get storageErrorUnknown => 'Произошла неизвестная ошибка хранилища.';

  @override
  String get comingSoonDefaultMessage => 'Эта функция скоро станет доступна.';

  @override
  String get pickCountryHint => 'Поиск страны';

  @override
  String get pickCityTitle => 'Выберите город';

  @override
  String get pickCityHint => 'Поиск города';

  @override
  String get searchNotFound => 'Ничего не найдено';

  @override
  String get fieldCountryLabel => 'Страна';

  @override
  String get fieldCitySelectFirstHint => 'Сначала выберите страну';

  @override
  String get fieldCityLabel => 'Город';

  @override
  String get contactRequiredError => 'Введите email или номер телефона';

  @override
  String get contactInvalidError => 'Введите корректный email или номер телефона';

  @override
  String get stampLike => 'НРАВИТСЯ';

  @override
  String get stampReject => 'МИМО';

  @override
  String get stampSuper => 'СУПЕР';

  @override
  String get emptyStackTitle => 'Рядом пока никого нет';

  @override
  String get emptyStackSubtitle => 'Попробуйте изменить радиус или фильтр.';

  @override
  String get discoverActiveNowLabel => 'Сейчас активен';

  @override
  String get discoverSwipeUpHint => 'Проведите вверх для следующей карточки';

  @override
  String get discoverMatchTitle => 'Совпадение!';

  @override
  String get discoverMatchMessage => 'Вы понравились друг другу!';

  @override
  String get discoverMatchLaterButton => 'Позже';

  @override
  String get storyVisibilitySheetTitle => 'Кто может видеть?';

  @override
  String get storyVisibilityPickPrompt => 'Кто может видеть?';

  @override
  String get storyVisibilityFollowers => 'Подписки и подписчики';

  @override
  String get storyVisibilityEveryone => 'Все';

  @override
  String get storyShareButton => 'Поделиться';

  @override
  String get storyVideoTooLongMessage => 'Видео может длиться не более 60 секунд';

  @override
  String get storyShareErrorMessage => 'Не удалось опубликовать. Попробуйте позже.';

  @override
  String get storyViewersEmptyMessage => 'Пока никто не просмотрел';

  @override
  String get storyViewersTitle => 'Просмотры';

  @override
  String get postCaptureSheetTitle => 'Добавить публикацию';

  @override
  String get postCameraOption => 'Снять на камеру';

  @override
  String get postGalleryPhotoOption => 'Выбрать фото';

  @override
  String get postGalleryVideoOption => 'Выбрать видео';

  @override
  String get postShareButton => 'Опубликовать';

  @override
  String get postShareErrorMessage => 'Не удалось опубликовать. Повторите попытку позже.';

  @override
  String get postFeedEmptyMessage => 'Пока нет публикаций';

  @override
  String get postCommentsSheetTitle => 'Комментарии';

  @override
  String get postCommentsEmptyMessage => 'Пока нет комментариев';

  @override
  String get postCommentHint => 'Напишите комментарий...';

  @override
  String get postCommentSendButton => 'Отправить';

  @override
  String get postCommentErrorMessage => 'Комментарий не отправлен. Повторите попытку позже.';

  @override
  String get postLikeErrorMessage => 'Лайк не сохранён. Повторите попытку позже.';

  @override
  String get feedSearchHint => 'Поиск';

  @override
  String get feedSearchNoResultsMessage => 'Результатов не найдено';

  @override
  String get feedDownloadVideoOption => 'Скачать видео';

  @override
  String feedDownloadInProgressMessage(int percent) {
    return 'Загрузка... $percent%';
  }

  @override
  String get feedDownloadCompleteMessage => 'Видео сохранено в вашей галерее';

  @override
  String get feedDownloadErrorMessage => 'Не удалось скачать видео. Повторите попытку позже.';

  @override
  String get postTimeJustNow => 'Только что';

  @override
  String postTimeMinutesAgo(int count) {
    return '$count мин назад';
  }

  @override
  String postTimeHoursAgo(int count) {
    return '$count ч назад';
  }

  @override
  String postTimeDaysAgo(int count) {
    return '$count дн назад';
  }

  @override
  String postTimeWeeksAgo(int count) {
    return '$count нед назад';
  }

  @override
  String get postCaptionHint => 'Напишите подпись...';

  @override
  String get postMenuEdit => 'Редактировать';

  @override
  String get postMenuDelete => 'Удалить';

  @override
  String get postEditCaptionTitle => 'Редактировать подпись';

  @override
  String get postEditCaptionSave => 'Сохранить';

  @override
  String get postEditCaptionErrorMessage => 'Не сохранено. Повторите попытку позже.';

  @override
  String get postDeleteConfirmTitle => 'Удалить эту публикацию?';

  @override
  String get postDeleteConfirmMessage => 'Это действие нельзя отменить.';

  @override
  String get postDeleteErrorMessage => 'Публикация не удалена. Повторите попытку позже.';

  @override
  String get storyDeleteConfirmTitle => 'Удалить эту историю?';

  @override
  String get storyDeleteConfirmMessage => 'Это действие нельзя отменить.';

  @override
  String get storyDeleteErrorMessage => 'История не удалена. Повторите попытку позже.';

  @override
  String get viewActiveStoryButton => 'Смотреть историю';

  @override
  String get postReplyAction => 'Ответить';

  @override
  String postReplyingToLabel(String name) {
    return 'Ответ для $name';
  }

  @override
  String get postCommentDeleteConfirmTitle => 'Удалить этот комментарий?';

  @override
  String get postCommentDeleteErrorMessage => 'Комментарий не удалён. Повторите попытку позже.';

  @override
  String get postCommentEditErrorMessage => 'Комментарий не обновлён. Повторите попытку позже.';

  @override
  String get postShareOptionsSheetTitle => 'Поделиться';

  @override
  String get postShareToChatOption => 'Отправить в чат';

  @override
  String get postShareExternalOption => 'Поделиться через другие приложения';

  @override
  String get postSendToSheetTitle => 'Кому отправить?';

  @override
  String get postSendToEmptyMessage => 'У вас пока нет чатов';

  @override
  String get postSentToChatSuccessMessage => 'Публикация отправлена';

  @override
  String get postSentToChatErrorMessage => 'Публикация не отправлена. Повторите попытку позже.';

  @override
  String get chatPostMessageLabel => 'Публикация';

  @override
  String get friendRequestSendButton => 'Добавить в друзья';

  @override
  String get friendRequestSentLabel => 'Отправлено';

  @override
  String get friendRequestPendingLabel => 'В ожидании';

  @override
  String get friendRequestAcceptedLabel => 'Вы друзья';

  @override
  String get friendRequestDeclinedLabel => 'Отклонено';

  @override
  String get friendRequestErrorMessage => 'Не удалось отправить запрос. Попробуйте позже.';

  @override
  String get sendMessageButton => 'Написать';

  @override
  String get followButton => 'Подписаться';

  @override
  String get followingButton => 'Вы подписаны';

  @override
  String get followErrorMessage => 'Что-то пошло не так. Попробуйте позже.';

  @override
  String get profileStatsFollowing => 'Подписки';

  @override
  String get profileStatsFollowers => 'Подписчики';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsLanguageRowLabel => 'Язык';

  @override
  String get languagePickerTitle => 'Выберите язык';

  @override
  String get settingsAccountRowTitle => 'Аккаунт';

  @override
  String get settingsAccountRowSubtitle => 'Личные данные, телефон, эл. почта, пароль';

  @override
  String get changePhotoScreenTitle => 'Изменить фото профиля';

  @override
  String get settingsChangePhotoRowSubtitle => 'Обновите или удалите фото профиля';

  @override
  String get settingsPrivacyRowSubtitle => 'Видимость, блокировки, активные устройства и др.';

  @override
  String get settingsNotificationsRowSubtitle => 'Сообщения, push-уведомления';

  @override
  String get settingsLanguageRowSubtitle => 'Выбор языка приложения';

  @override
  String get settingsIdentityRowSubtitle => 'Подтвердите личность, получите значок доверия';

  @override
  String get settingsVipRowTitle => 'Meevima VIP';

  @override
  String get settingsVipRowSubtitle => 'Перейти на VIP, управлять подпиской';

  @override
  String get settingsVipActiveLabel => 'Активен';

  @override
  String get settingsVipBadgeLabel => 'VIP';

  @override
  String get settingsMapRowTitle => 'Карта и геолокация';

  @override
  String get settingsMapRowSubtitle => 'Тип карты, единица расстояния, GPS';

  @override
  String get settingsPaymentsRowTitle => 'Платежи';

  @override
  String get settingsPaymentsRowSubtitle => 'История платежей, карты, подписка';

  @override
  String get settingsHelpRowTitle => 'Помощь';

  @override
  String get settingsHelpRowSubtitle => 'Вопросы и ответы, связаться с нами, сообщить о проблеме';

  @override
  String get settingsLegalRowTitle => 'Правовая информация';

  @override
  String get settingsLegalRowSubtitle => 'Политика конфиденциальности, условия использования';

  @override
  String get settingsAboutRowTitle => 'О приложении';

  @override
  String get settingsAboutRowSubtitle => 'Версия, новости, соцсети';

  @override
  String get settingsLogoutRowTitle => 'Выйти';

  @override
  String get settingsLogoutRowSubtitle => 'Выйти из аккаунта';

  @override
  String get notificationsScreenTitle => 'Уведомления';

  @override
  String get notifMessagesTitle => 'Сообщения';

  @override
  String get notifMessagesSubtitle => 'Получать уведомления о новых сообщениях';

  @override
  String get notifFollowersTitle => 'Подписчики';

  @override
  String get notifFollowersSubtitle => 'Новые подписчики и запросы на подписку';

  @override
  String get notifNewUsersTitle => 'Новые пользователи';

  @override
  String get notifNewUsersSubtitle => 'Когда рядом появляется новый пользователь';

  @override
  String get notifLikesTitle => 'Лайки';

  @override
  String get notifLikesSubtitle => 'Получать уведомление, когда вас лайкнули';

  @override
  String get notifCommentsTitle => 'Комментарии';

  @override
  String get notifCommentsSubtitle => 'Уведомления о комментариях и реакциях';

  @override
  String get notifVenueOffersTitle => 'Предложения от заведений';

  @override
  String get notifVenueOffersSubtitle => 'Новые предложения от заведений, на которые вы подписаны';

  @override
  String get notifVenueUpdatesTitle => 'Обновления заведений';

  @override
  String get notifVenueUpdatesSubtitle => 'Добавление и подтверждение заведений';

  @override
  String get notifSecurityTitle => 'Безопасность';

  @override
  String get notifSecuritySubtitle => 'Важные уведомления о безопасности вашего аккаунта';

  @override
  String get notifSystemTitle => 'Системные уведомления';

  @override
  String get notifSystemSubtitle => 'Важные объявления о приложении';

  @override
  String get notifMarketingTitle => 'Маркетинг';

  @override
  String get notifMarketingSubtitle => 'Узнавайте о акциях и скидках';

  @override
  String get notifPushTitle => 'Push-уведомления';

  @override
  String get notifEmailTitle => 'Email-уведомления';

  @override
  String get notifUpdateErrorMessage => 'Изменение не сохранено. Повторите попытку позже.';

  @override
  String get mapLocationScreenTitle => 'Карта и геолокация';

  @override
  String get mapTypeTitle => 'Тип карты';

  @override
  String get mapTypeStandard => 'Стандартная';

  @override
  String get mapTypeSatellite => 'Спутник';

  @override
  String get mapTypeHybrid => 'Гибрид';

  @override
  String get distanceUnitTitle => 'Единица измерения расстояния';

  @override
  String get distanceUnitKm => 'Километры';

  @override
  String get distanceUnitMi => 'Мили';

  @override
  String get gpsAccuracyTitle => 'Точность GPS';

  @override
  String get gpsAccuracyHigh => 'Высокая';

  @override
  String get gpsAccuracyStandard => 'Стандартная';

  @override
  String get backgroundLocationTitle => 'Геолокация в фоне';

  @override
  String get backgroundLocationSubtitle => 'Обновлять местоположение, пока приложение работает в фоне';

  @override
  String get backgroundLocationDeniedMessage => 'Чтобы включить фоновую геолокацию, выберите \"Разрешить всегда\" в Настройки > Приложения.';

  @override
  String get mapLocationUpdateErrorMessage => 'Изменение не сохранено. Повторите попытку позже.';

  @override
  String get helpScreenTitle => 'Помощь';

  @override
  String get helpFaqSectionTitle => 'Часто задаваемые вопросы';

  @override
  String get helpFaq1Question => 'Как работает Meevima?';

  @override
  String get helpFaq1Answer => 'Приложение использует вашу геолокацию, чтобы показывать других пользователей поблизости. Радиус и фильтры можно настроить на вкладке «Обзор».';

  @override
  String get helpFaq2Question => 'Кто видит мою геолокацию?';

  @override
  String get helpFaq2Answer => 'Другим пользователям показывается только примерное расстояние, точные координаты не передаются. Включите Ghost Mode в Настройки > Конфиденциальность и безопасность, чтобы полностью скрыться.';

  @override
  String get helpFaq3Question => 'Как удалить мой аккаунт?';

  @override
  String get helpFaq3Answer => 'Перейдите в Настройки > Аккаунт > Удалить аккаунт, чтобы окончательно удалить свой аккаунт. Это действие нельзя отменить.';

  @override
  String get helpFaq4Question => 'Что делать, если кто-то меня беспокоит?';

  @override
  String get helpFaq4Answer => 'Вы можете заблокировать или пожаловаться на пользователя в любой момент через его профиль. Заблокированный пользователь больше не сможет вас видеть.';

  @override
  String get helpFaq5Question => 'Для чего нужен Meevima VIP?';

  @override
  String get helpFaq5Answer => 'VIP-подписка открывает расширенный радиус видимости, Ghost Mode и дополнительные фильтры.';

  @override
  String get helpFaq6Question => 'Как изменить радиус видимости?';

  @override
  String get helpFaq6Answer => 'Используйте переключатель радиуса под картой на вкладке «Обзор», чтобы выбрать нужное расстояние.';

  @override
  String get helpContactRowTitle => 'Связаться с нами';

  @override
  String get helpContactRowSubtitle => 'Напишите нам, если есть вопросы';

  @override
  String get helpReportProblemRowTitle => 'Сообщить о проблеме';

  @override
  String get helpReportProblemRowSubtitle => 'Расскажите нам о технической проблеме';

  @override
  String get helpSendSuggestionRowTitle => 'Отправить предложение';

  @override
  String get helpSendSuggestionRowSubtitle => 'Как нам улучшить приложение?';

  @override
  String get contactUsSheetTitle => 'Связаться с нами';

  @override
  String get contactUsEmailCopiedNotice => 'Адрес электронной почты скопирован';

  @override
  String get contactUsSendEmailButton => 'Отправить письмо';

  @override
  String get reportProblemSheetTitle => 'Сообщить о проблеме';

  @override
  String get sendSuggestionSheetTitle => 'Отправить предложение';

  @override
  String get supportMessageHint => 'Напишите ваше сообщение здесь...';

  @override
  String get supportMessageSendButton => 'Отправить';

  @override
  String get supportMessageSentNotice => 'Ваше сообщение отправлено. Спасибо!';

  @override
  String get supportMessageErrorMessage => 'Сообщение не отправлено. Повторите попытку позже.';

  @override
  String get legalPrivacyPolicyTitle => 'Политика конфиденциальности';

  @override
  String get legalTermsOfServiceTitle => 'Условия использования';

  @override
  String get legalLicensesTitle => 'Лицензии';

  @override
  String get aboutWhatsNewTitle => 'Что нового';

  @override
  String get aboutSocialMediaTitle => 'Социальные сети';

  @override
  String get aboutSocialMediaComingSoonLabel => 'Скоро';

  @override
  String get aboutCopyrightText => '© 2026 Meevima. Все права защищены.';

  @override
  String get aboutChangelogV1Title => 'v1.0.0';

  @override
  String get aboutChangelogV1Body => 'Первый релиз: поиск пользователей поблизости, заявки в друзья, чаты, истории и управление профилем.';

  @override
  String get vipHeaderTitle => 'Meevima VIP';

  @override
  String get vipHeaderSubtitle => 'Знакомьтесь с большим количеством людей благодаря расширенным возможностям';

  @override
  String get vipChoosePackageTitle => 'Выберите пакет';

  @override
  String get vipPeriodMonthly => 'Ежемесячно';

  @override
  String get vipPeriodQuarterly => '3 месяца';

  @override
  String get vipPeriodYearly => 'Ежегодно';

  @override
  String get vipBestValueBadge => 'Выгоднее всего';

  @override
  String get vipPriceComingSoonNote => 'Цены появятся здесь после подключения магазина.';

  @override
  String get vipSubscribeButton => 'Оформить подписку';

  @override
  String get vipAlreadySubscribedButton => 'Вы уже VIP';

  @override
  String get vipBillingComingSoonMessage => 'Оплата будет доступна в ближайшее время.';

  @override
  String get vipCurrentPackageTitle => 'Текущий пакет';

  @override
  String get vipCurrentPackageActiveLabel => 'Активен';

  @override
  String get vipManageButton => 'Управлять';

  @override
  String get vipFeatureGhostTitle => 'Ghost Mode';

  @override
  String get vipFeatureGhostDescription => 'Видьте других пользователей, оставаясь невидимым на карте.';

  @override
  String get vipFeatureRadiusTitle => 'Расширенный радиус';

  @override
  String get vipFeatureRadiusDescription => 'Находите людей в радиусе 5 км и 10 км.';

  @override
  String get vipFeatureFilterTitle => 'Дополнительные фильтры';

  @override
  String get vipFeatureFilterDescription => 'Уточняйте поиск по полу и другим фильтрам.';

  @override
  String get accountScreenTitle => 'Аккаунт';

  @override
  String get accountPersonalInfoTitle => 'Личные данные';

  @override
  String get accountPhoneRowTitle => 'Номер телефона';

  @override
  String get accountEmailRowTitle => 'Эл. почта';

  @override
  String get accountEmailEmptyValue => 'Не добавлено';

  @override
  String get accountPasswordRowTitle => 'Изменить пароль';

  @override
  String get accountPhoneUnsetValue => 'Не подтверждён';

  @override
  String get accountChangeEmailSheetTitle => 'Изменить эл. почту';

  @override
  String get accountNewEmailLabel => 'Новый адрес эл. почты';

  @override
  String get accountEmailInvalidError => 'Введите действительный адрес эл. почты';

  @override
  String get accountEmailUpdatedNotice => 'Эл. почта обновлена';

  @override
  String get accountDeleteRowTitle => 'Удалить аккаунт';

  @override
  String get accountDeleteRowSubtitle => 'Удалите аккаунт и все свои данные';

  @override
  String get accountDeleteConfirmWordLabel => 'Введите «УДАЛИТЬ» ниже для подтверждения';

  @override
  String get accountDeleteConfirmWordHint => 'УДАЛИТЬ';

  @override
  String get accountDeleteConfirmWordMismatchError => 'Введите «УДАЛИТЬ» точно, чтобы продолжить';

  @override
  String get paymentsScreenTitle => 'Платежи';

  @override
  String get paymentHistoryRowTitle => 'История платежей';

  @override
  String get myCardsTitle => 'Мои карты';

  @override
  String get addCardButton => 'Добавить карту';

  @override
  String get noCardsMessage => 'Карты ещё не добавлены';

  @override
  String get cardOptionsSetDefault => 'Сделать основной';

  @override
  String get cardOptionsDelete => 'Удалить';

  @override
  String get paymentHistoryEmptyMessage => 'Пока нет операций';

  @override
  String get paymentTypePurchase => 'Покупка';

  @override
  String get paymentTypeRenewal => 'Продление';

  @override
  String get paymentTypeCancellation => 'Отмена';

  @override
  String get paymentTypeRefund => 'Возврат';

  @override
  String get activeDevicesTitle => 'Активные устройства';

  @override
  String get privacyActiveDevicesSubtitle => 'Список ваших активных устройств';

  @override
  String get activeDevicesEmptyMessage => 'Активные устройства не найдены';

  @override
  String get thisDeviceLabel => 'Это устройство';

  @override
  String get lastActiveLabel => 'Последняя активность';

  @override
  String get signOutDeviceButton => 'Выйти';

  @override
  String get signOutDeviceConfirmTitle => 'Выйти на этом устройстве?';

  @override
  String get signOutDeviceConfirmMessage => 'Это устройство будет удалённо разлогинено. Если оно офлайн, выход произойдёт при следующем подключении.';

  @override
  String get signOutDeviceErrorMessage => 'Не удалось выйти. Попробуйте позже.';

  @override
  String get privacyTwoFactorActivateTitle => 'Включить двухфакторную аутентификацию';

  @override
  String get privacyTwoFactorDisableButton => 'Отключить';
}
