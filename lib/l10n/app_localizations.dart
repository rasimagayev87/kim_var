import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_az.dart';
import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('az'),
    Locale('en'),
    Locale('ru'),
    Locale('tr')
  ];

  /// Welcome screen tagline
  ///
  /// In en, this message translates to:
  /// **'Discover people around you,\nmake new connections and friendships.'**
  String get welcomeSubtitle;

  /// Welcome screen primary CTA
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get welcomeStartButton;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get loginTitle;

  /// No description provided for @loginUsernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get loginUsernameLabel;

  /// No description provided for @loginUsernameHint.
  ///
  /// In en, this message translates to:
  /// **'username'**
  String get loginUsernameHint;

  /// No description provided for @loginPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get loginPasswordLabel;

  /// No description provided for @loginPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'••••••••'**
  String get loginPasswordHint;

  /// No description provided for @loginButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get loginButtonLabel;

  /// No description provided for @loginRegisterButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get loginRegisterButtonLabel;

  /// No description provided for @loginForgotPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get loginForgotPasswordLabel;

  /// No description provided for @loginAccountNotFoundError.
  ///
  /// In en, this message translates to:
  /// **'No account found with these details.'**
  String get loginAccountNotFoundError;

  /// No description provided for @loginTooManyAttemptsError.
  ///
  /// In en, this message translates to:
  /// **'Too many failed attempts. Try again shortly, or reset your password via \"Forgot password\".'**
  String get loginTooManyAttemptsError;

  /// No description provided for @loginNetworkError.
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Check your connection and try again.'**
  String get loginNetworkError;

  /// No description provided for @loginRegisterPromptLabel.
  ///
  /// In en, this message translates to:
  /// **'Want to create an account?'**
  String get loginRegisterPromptLabel;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get registerTitle;

  /// No description provided for @registerUsernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get registerUsernameLabel;

  /// No description provided for @registerUsernameHint.
  ///
  /// In en, this message translates to:
  /// **'username'**
  String get registerUsernameHint;

  /// No description provided for @registerUsernameCheckingLabel.
  ///
  /// In en, this message translates to:
  /// **'Checking...'**
  String get registerUsernameCheckingLabel;

  /// No description provided for @registerUsernameTakenError.
  ///
  /// In en, this message translates to:
  /// **'This username is already taken.'**
  String get registerUsernameTakenError;

  /// No description provided for @registerUsernameInvalidFormatError.
  ///
  /// In en, this message translates to:
  /// **'Username may only contain letters, numbers, . and _ (3-20 characters).'**
  String get registerUsernameInvalidFormatError;

  /// No description provided for @registerPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get registerPasswordLabel;

  /// No description provided for @registerPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get registerPasswordHint;

  /// No description provided for @registerPasswordConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get registerPasswordConfirmLabel;

  /// No description provided for @registerPasswordConfirmHint.
  ///
  /// In en, this message translates to:
  /// **'Re-enter your password'**
  String get registerPasswordConfirmHint;

  /// No description provided for @registerPasswordTooShortError.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters.'**
  String get registerPasswordTooShortError;

  /// No description provided for @registerPasswordMismatchError.
  ///
  /// In en, this message translates to:
  /// **'Passwords don\'t match.'**
  String get registerPasswordMismatchError;

  /// No description provided for @registerSubmitButton.
  ///
  /// In en, this message translates to:
  /// **'Complete registration'**
  String get registerSubmitButton;

  /// No description provided for @registerGenericError.
  ///
  /// In en, this message translates to:
  /// **'Registration failed. Please try again shortly.'**
  String get registerGenericError;

  /// No description provided for @registerSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Registration complete — you can now log in.'**
  String get registerSuccessMessage;

  /// No description provided for @phoneAuthTitle.
  ///
  /// In en, this message translates to:
  /// **'Your phone number'**
  String get phoneAuthTitle;

  /// No description provided for @phoneAuthSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You\'ll need the code sent to you by SMS.'**
  String get phoneAuthSubtitle;

  /// No description provided for @phoneAuthNumberHint.
  ///
  /// In en, this message translates to:
  /// **'50 123 45 67'**
  String get phoneAuthNumberHint;

  /// No description provided for @phoneAuthContinueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue with phone number'**
  String get phoneAuthContinueButton;

  /// No description provided for @phoneAuthInvalidNumberError.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number'**
  String get phoneAuthInvalidNumberError;

  /// No description provided for @phoneAuthVerificationFailedError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t verify the number, try again.'**
  String get phoneAuthVerificationFailedError;

  /// Bottom sheet title for the country picker, shared by phone dial-code and country/city pickers
  ///
  /// In en, this message translates to:
  /// **'Choose country'**
  String get pickCountryTitle;

  /// No description provided for @otpTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the code'**
  String get otpTitle;

  /// No description provided for @otpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code sent to {phone}.'**
  String otpSubtitle(String phone);

  /// No description provided for @otpCodeHint.
  ///
  /// In en, this message translates to:
  /// **'••••••'**
  String get otpCodeHint;

  /// No description provided for @otpConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get otpConfirmButton;

  /// No description provided for @otpIncompleteCodeError.
  ///
  /// In en, this message translates to:
  /// **'Enter the full 6-digit code'**
  String get otpIncompleteCodeError;

  /// No description provided for @otpInvalidCodeError.
  ///
  /// In en, this message translates to:
  /// **'The code is wrong or has expired.'**
  String get otpInvalidCodeError;

  /// No description provided for @otpResendButton.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get otpResendButton;

  /// No description provided for @otpResendWaitLabel.
  ///
  /// In en, this message translates to:
  /// **'Resend in: {time}'**
  String otpResendWaitLabel(String time);

  /// No description provided for @verificationRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your account'**
  String get verificationRequiredTitle;

  /// No description provided for @verificationRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'You need to verify your account before using this feature.'**
  String get verificationRequiredMessage;

  /// No description provided for @verificationRequiredButton.
  ///
  /// In en, this message translates to:
  /// **'Verify account'**
  String get verificationRequiredButton;

  /// No description provided for @accountVerificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your account'**
  String get accountVerificationTitle;

  /// No description provided for @accountVerificationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your phone number to unlock every feature.'**
  String get accountVerificationSubtitle;

  /// No description provided for @accountVerificationPhoneTakenError.
  ///
  /// In en, this message translates to:
  /// **'This phone number is already used by another account.'**
  String get accountVerificationPhoneTakenError;

  /// No description provided for @accountVerificationSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Your account is verified.'**
  String get accountVerificationSuccessMessage;

  /// No description provided for @settingsAccountVerificationRowTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify account'**
  String get settingsAccountVerificationRowTitle;

  /// No description provided for @settingsAccountVerifiedRowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your account is verified'**
  String get settingsAccountVerifiedRowSubtitle;

  /// No description provided for @settingsIdentityVerificationRowTitle.
  ///
  /// In en, this message translates to:
  /// **'Identity verification'**
  String get settingsIdentityVerificationRowTitle;

  /// No description provided for @swipeMatchedMessage.
  ///
  /// In en, this message translates to:
  /// **'You matched with this user!'**
  String get swipeMatchedMessage;

  /// No description provided for @swipeErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again shortly.'**
  String get swipeErrorMessage;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Forgot password'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the phone number linked to your account.'**
  String get forgotPasswordSubtitle;

  /// No description provided for @forgotPasswordAccountNotFoundError.
  ///
  /// In en, this message translates to:
  /// **'No account found with this phone number.'**
  String get forgotPasswordAccountNotFoundError;

  /// No description provided for @newPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPasswordTitle;

  /// No description provided for @newPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set a new password for your account.'**
  String get newPasswordSubtitle;

  /// No description provided for @newPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPasswordLabel;

  /// No description provided for @newPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get newPasswordHint;

  /// No description provided for @newPasswordConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get newPasswordConfirmLabel;

  /// No description provided for @newPasswordConfirmHint.
  ///
  /// In en, this message translates to:
  /// **'Re-enter your password'**
  String get newPasswordConfirmHint;

  /// No description provided for @newPasswordSubmitButton.
  ///
  /// In en, this message translates to:
  /// **'Update password'**
  String get newPasswordSubmitButton;

  /// No description provided for @newPasswordSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Your password has been updated — you can log in now.'**
  String get newPasswordSuccessMessage;

  /// No description provided for @newPasswordGenericError.
  ///
  /// In en, this message translates to:
  /// **'The password wasn\'t updated. Please try again shortly.'**
  String get newPasswordGenericError;

  /// No description provided for @changePasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePasswordTitle;

  /// No description provided for @changePasswordCurrentLabel.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get changePasswordCurrentLabel;

  /// No description provided for @changePasswordCurrentHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your current password'**
  String get changePasswordCurrentHint;

  /// No description provided for @changePasswordNewLabel.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get changePasswordNewLabel;

  /// No description provided for @changePasswordNewHint.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get changePasswordNewHint;

  /// No description provided for @changePasswordConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get changePasswordConfirmLabel;

  /// No description provided for @changePasswordConfirmHint.
  ///
  /// In en, this message translates to:
  /// **'Re-enter your password'**
  String get changePasswordConfirmHint;

  /// No description provided for @changePasswordSubmitButton.
  ///
  /// In en, this message translates to:
  /// **'Update password'**
  String get changePasswordSubmitButton;

  /// No description provided for @changePasswordWrongCurrentError.
  ///
  /// In en, this message translates to:
  /// **'The current password is wrong.'**
  String get changePasswordWrongCurrentError;

  /// No description provided for @changePasswordSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Your password has been updated.'**
  String get changePasswordSuccessMessage;

  /// No description provided for @changePasswordGenericError.
  ///
  /// In en, this message translates to:
  /// **'The password wasn\'t changed. Please try again shortly.'**
  String get changePasswordGenericError;

  /// No description provided for @onboardingAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Complete your profile'**
  String get onboardingAppBarTitle;

  /// No description provided for @onboardingPhotoOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Add a photo (optional)'**
  String get onboardingPhotoOptionalLabel;

  /// No description provided for @fieldFirstNameLabel.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get fieldFirstNameLabel;

  /// No description provided for @fieldFirstNameHint.
  ///
  /// In en, this message translates to:
  /// **'Rasim'**
  String get fieldFirstNameHint;

  /// No description provided for @fieldFirstNameRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Enter your first name'**
  String get fieldFirstNameRequiredError;

  /// No description provided for @fieldLastNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get fieldLastNameLabel;

  /// No description provided for @fieldLastNameHint.
  ///
  /// In en, this message translates to:
  /// **'Mammadov'**
  String get fieldLastNameHint;

  /// No description provided for @fieldLastNameRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Enter your last name'**
  String get fieldLastNameRequiredError;

  /// No description provided for @fieldBirthDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get fieldBirthDateLabel;

  /// No description provided for @fieldBirthDateHint.
  ///
  /// In en, this message translates to:
  /// **'dd.mm.yyyy'**
  String get fieldBirthDateHint;

  /// No description provided for @birthDatePickerHelpText.
  ///
  /// In en, this message translates to:
  /// **'Select your date of birth'**
  String get birthDatePickerHelpText;

  /// No description provided for @fieldGenderLabel.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get fieldGenderLabel;

  /// No description provided for @sectionCountryCityTitle.
  ///
  /// In en, this message translates to:
  /// **'Country and city'**
  String get sectionCountryCityTitle;

  /// No description provided for @sectionAboutOptionalTitle.
  ///
  /// In en, this message translates to:
  /// **'About you (optional)'**
  String get sectionAboutOptionalTitle;

  /// No description provided for @bioHintOnboarding.
  ///
  /// In en, this message translates to:
  /// **'A few sentences about yourself...'**
  String get bioHintOnboarding;

  /// No description provided for @onboardingFinishButton.
  ///
  /// In en, this message translates to:
  /// **'Finish and continue'**
  String get onboardingFinishButton;

  /// No description provided for @onboardingSelectBirthDateError.
  ///
  /// In en, this message translates to:
  /// **'Select your date of birth'**
  String get onboardingSelectBirthDateError;

  /// No description provided for @onboardingSelectGenderError.
  ///
  /// In en, this message translates to:
  /// **'Select your gender'**
  String get onboardingSelectGenderError;

  /// No description provided for @onboardingSelectCountryCityError.
  ///
  /// In en, this message translates to:
  /// **'Select your country and city'**
  String get onboardingSelectCountryCityError;

  /// No description provided for @onboardingPhotoUploadFailedError.
  ///
  /// In en, this message translates to:
  /// **'The photo couldn\'t be uploaded — you can add it later from your profile.'**
  String get onboardingPhotoUploadFailedError;

  /// No description provided for @errorWithDetails.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong: {error}'**
  String errorWithDetails(String error);

  /// No description provided for @navDiscoverLabel.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get navDiscoverLabel;

  /// No description provided for @navChatsLabel.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get navChatsLabel;

  /// No description provided for @navFeedLabel.
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get navFeedLabel;

  /// No description provided for @navNotificationsLabel.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get navNotificationsLabel;

  /// No description provided for @navProfileLabel.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfileLabel;

  /// No description provided for @notificationsFeedTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsFeedTitle;

  /// No description provided for @notifMenuMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get notifMenuMarkAllRead;

  /// No description provided for @notifMenuDeleteRead.
  ///
  /// In en, this message translates to:
  /// **'Delete read notifications'**
  String get notifMenuDeleteRead;

  /// No description provided for @notifMenuSettings.
  ///
  /// In en, this message translates to:
  /// **'Notification settings'**
  String get notifMenuSettings;

  /// No description provided for @notifEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No notifications'**
  String get notifEmptyTitle;

  /// No description provided for @notifEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'New notifications will show up here.'**
  String get notifEmptySubtitle;

  /// No description provided for @notifErrorOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get notifErrorOfflineTitle;

  /// No description provided for @notifErrorOfflineMessage.
  ///
  /// In en, this message translates to:
  /// **'Connect to the internet to load notifications.'**
  String get notifErrorOfflineMessage;

  /// No description provided for @notifErrorPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'No permission'**
  String get notifErrorPermissionTitle;

  /// No description provided for @notifErrorPermissionMessage.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission to view these notifications.'**
  String get notifErrorPermissionMessage;

  /// No description provided for @notifErrorUnknownTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get notifErrorUnknownTitle;

  /// No description provided for @notifErrorUnknownMessage.
  ///
  /// In en, this message translates to:
  /// **'Notifications couldn\'t be loaded. Try again shortly.'**
  String get notifErrorUnknownMessage;

  /// No description provided for @notifMarkAllReadDone.
  ///
  /// In en, this message translates to:
  /// **'All notifications marked as read'**
  String get notifMarkAllReadDone;

  /// No description provided for @notifDeleteReadDone.
  ///
  /// In en, this message translates to:
  /// **'Read notifications deleted'**
  String get notifDeleteReadDone;

  /// No description provided for @notifActionErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again shortly.'**
  String get notifActionErrorMessage;

  /// No description provided for @discoverTitle.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get discoverTitle;

  /// No description provided for @viewSwitcherPeopleLabel.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get viewSwitcherPeopleLabel;

  /// No description provided for @viewSwitcherPlacesLabel.
  ///
  /// In en, this message translates to:
  /// **'Places'**
  String get viewSwitcherPlacesLabel;

  /// No description provided for @viewSwitcherOffersLabel.
  ///
  /// In en, this message translates to:
  /// **'Offers'**
  String get viewSwitcherOffersLabel;

  /// No description provided for @genderFilterAll.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get genderFilterAll;

  /// No description provided for @genderFilterMale.
  ///
  /// In en, this message translates to:
  /// **'Men'**
  String get genderFilterMale;

  /// No description provided for @genderFilterFemale.
  ///
  /// In en, this message translates to:
  /// **'Women'**
  String get genderFilterFemale;

  /// No description provided for @genderFilterTooltip.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get genderFilterTooltip;

  /// No description provided for @genderFilterSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Filter by gender'**
  String get genderFilterSheetTitle;

  /// No description provided for @locationSearchingTitle.
  ///
  /// In en, this message translates to:
  /// **'Finding your location...'**
  String get locationSearchingTitle;

  /// No description provided for @locationSearchingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This can take a few seconds.'**
  String get locationSearchingSubtitle;

  /// No description provided for @locationServiceDisabledTitle.
  ///
  /// In en, this message translates to:
  /// **'Location services are off'**
  String get locationServiceDisabledTitle;

  /// No description provided for @locationServiceDisabledSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Turn on location on your device to see people nearby.'**
  String get locationServiceDisabledSubtitle;

  /// No description provided for @actionOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get actionOpenSettings;

  /// No description provided for @locationPermissionDeniedTitle.
  ///
  /// In en, this message translates to:
  /// **'Location permission needed'**
  String get locationPermissionDeniedTitle;

  /// No description provided for @locationPermissionDeniedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Grant permission to see people around you.'**
  String get locationPermissionDeniedSubtitle;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get actionRetry;

  /// No description provided for @chatPermissionDeniedMessage.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have access to this conversation right now. Try signing out and back in, or try again shortly.'**
  String get chatPermissionDeniedMessage;

  /// No description provided for @chatLoadErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong loading this. Please try again.'**
  String get chatLoadErrorMessage;

  /// No description provided for @locationPermissionDeniedForeverTitle.
  ///
  /// In en, this message translates to:
  /// **'Permission permanently denied'**
  String get locationPermissionDeniedForeverTitle;

  /// No description provided for @locationPermissionDeniedForeverSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manually enable location permission for \"Meevima\" in your phone\'s settings.'**
  String get locationPermissionDeniedForeverSubtitle;

  /// No description provided for @actionOpenAppSettings.
  ///
  /// In en, this message translates to:
  /// **'Open app settings'**
  String get actionOpenAppSettings;

  /// No description provided for @errorTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorTitle;

  /// No description provided for @meMarkerLabel.
  ///
  /// In en, this message translates to:
  /// **'You are here'**
  String get meMarkerLabel;

  /// No description provided for @defaultUserName.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get defaultUserName;

  /// No description provided for @startChatButton.
  ///
  /// In en, this message translates to:
  /// **'Start chatting'**
  String get startChatButton;

  /// No description provided for @viewProfileButton.
  ///
  /// In en, this message translates to:
  /// **'View profile'**
  String get viewProfileButton;

  /// No description provided for @chatMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Message...'**
  String get chatMessageHint;

  /// No description provided for @chatRequestSentNotice.
  ///
  /// In en, this message translates to:
  /// **'Message request sent'**
  String get chatRequestSentNotice;

  /// No description provided for @chatRequestBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Message request'**
  String get chatRequestBannerTitle;

  /// No description provided for @chatRequestBannerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Accept to start chatting with each other.'**
  String get chatRequestBannerSubtitle;

  /// No description provided for @chatRequestAcceptButton.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get chatRequestAcceptButton;

  /// No description provided for @chatRequestDeclineButton.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get chatRequestDeclineButton;

  /// No description provided for @chatRequestPendingNotice.
  ///
  /// In en, this message translates to:
  /// **'Waiting for them to accept your message request.'**
  String get chatRequestPendingNotice;

  /// No description provided for @chatRequestDeclinedNotice.
  ///
  /// In en, this message translates to:
  /// **'This message request was declined.'**
  String get chatRequestDeclinedNotice;

  /// No description provided for @chatRequestDeclinedByPeerNotice.
  ///
  /// In en, this message translates to:
  /// **'This user declined your message request.'**
  String get chatRequestDeclinedByPeerNotice;

  /// No description provided for @chatRequestActionErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t go through. Please try again in a moment.'**
  String get chatRequestActionErrorMessage;

  /// No description provided for @chatOnlineStatus.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get chatOnlineStatus;

  /// No description provided for @chatLastSeenUnknown.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get chatLastSeenUnknown;

  /// No description provided for @chatLastSeenAt.
  ///
  /// In en, this message translates to:
  /// **'Last seen: {time}'**
  String chatLastSeenAt(String time);

  /// No description provided for @chatTypingIndicator.
  ///
  /// In en, this message translates to:
  /// **'typing...'**
  String get chatTypingIndicator;

  /// No description provided for @chatDateToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get chatDateToday;

  /// No description provided for @chatDateYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get chatDateYesterday;

  /// No description provided for @chatMenuViewProfile.
  ///
  /// In en, this message translates to:
  /// **'View profile'**
  String get chatMenuViewProfile;

  /// No description provided for @chatMenuBlock.
  ///
  /// In en, this message translates to:
  /// **'Block user'**
  String get chatMenuBlock;

  /// No description provided for @chatMenuUnblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get chatMenuUnblock;

  /// No description provided for @chatUserUnblockedNotice.
  ///
  /// In en, this message translates to:
  /// **'User unblocked.'**
  String get chatUserUnblockedNotice;

  /// No description provided for @chatMenuReport.
  ///
  /// In en, this message translates to:
  /// **'Report user'**
  String get chatMenuReport;

  /// No description provided for @chatMenuDeleteChat.
  ///
  /// In en, this message translates to:
  /// **'Delete chat'**
  String get chatMenuDeleteChat;

  /// No description provided for @chatBlockConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Block this user?'**
  String get chatBlockConfirmTitle;

  /// No description provided for @chatBlockConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'They won\'t be able to message you anymore.'**
  String get chatBlockConfirmMessage;

  /// No description provided for @chatDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this chat?'**
  String get chatDeleteConfirmTitle;

  /// No description provided for @chatDeleteConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This conversation will be permanently deleted.'**
  String get chatDeleteConfirmMessage;

  /// No description provided for @chatReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Report user'**
  String get chatReportTitle;

  /// No description provided for @chatReportReasonHint.
  ///
  /// In en, this message translates to:
  /// **'Describe the issue...'**
  String get chatReportReasonHint;

  /// No description provided for @chatReportSubmitButton.
  ///
  /// In en, this message translates to:
  /// **'Submit report'**
  String get chatReportSubmitButton;

  /// No description provided for @chatReportSentNotice.
  ///
  /// In en, this message translates to:
  /// **'Report submitted, thank you.'**
  String get chatReportSentNotice;

  /// No description provided for @chatReportReasonInappropriate.
  ///
  /// In en, this message translates to:
  /// **'Inappropriate content'**
  String get chatReportReasonInappropriate;

  /// No description provided for @chatReportReasonFakeProfile.
  ///
  /// In en, this message translates to:
  /// **'Fake profile'**
  String get chatReportReasonFakeProfile;

  /// No description provided for @chatReportReasonDangerous.
  ///
  /// In en, this message translates to:
  /// **'Dangerous behavior'**
  String get chatReportReasonDangerous;

  /// No description provided for @chatReportReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get chatReportReasonOther;

  /// No description provided for @chatSendBlockedError.
  ///
  /// In en, this message translates to:
  /// **'You can\'t send a message to this user.'**
  String get chatSendBlockedError;

  /// No description provided for @chatUserBlockedNotice.
  ///
  /// In en, this message translates to:
  /// **'User blocked.'**
  String get chatUserBlockedNotice;

  /// No description provided for @chatEmptyConversation.
  ///
  /// In en, this message translates to:
  /// **'Say hello 👋'**
  String get chatEmptyConversation;

  /// No description provided for @chatEmptyStateTitle.
  ///
  /// In en, this message translates to:
  /// **'Send the first message'**
  String get chatEmptyStateTitle;

  /// No description provided for @chatEmptyStateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start the conversation by writing below, or break the ice with a hello.'**
  String get chatEmptyStateSubtitle;

  /// No description provided for @chatEmptyStateGreetingButton.
  ///
  /// In en, this message translates to:
  /// **'Hi 👋'**
  String get chatEmptyStateGreetingButton;

  /// No description provided for @chatVoiceComingSoonMessage.
  ///
  /// In en, this message translates to:
  /// **'Voice messages are coming soon.'**
  String get chatVoiceComingSoonMessage;

  /// No description provided for @chatEmojiPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick an emoji'**
  String get chatEmojiPickerTitle;

  /// No description provided for @chatImageMessageLabel.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get chatImageMessageLabel;

  /// No description provided for @chatVideoMessageLabel.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get chatVideoMessageLabel;

  /// No description provided for @chatAudioMessageLabel.
  ///
  /// In en, this message translates to:
  /// **'Voice message'**
  String get chatAudioMessageLabel;

  /// No description provided for @chatSendButton.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatSendButton;

  /// No description provided for @chatRetakeButton.
  ///
  /// In en, this message translates to:
  /// **'Retake'**
  String get chatRetakeButton;

  /// No description provided for @chatAttachmentSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose media'**
  String get chatAttachmentSheetTitle;

  /// No description provided for @chatAttachmentImageOption.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get chatAttachmentImageOption;

  /// No description provided for @chatAttachmentVideoOption.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get chatAttachmentVideoOption;

  /// No description provided for @chatRecordingCancelHint.
  ///
  /// In en, this message translates to:
  /// **'Slide to cancel'**
  String get chatRecordingCancelHint;

  /// No description provided for @chatRecordingLockHint.
  ///
  /// In en, this message translates to:
  /// **'Slide up to lock'**
  String get chatRecordingLockHint;

  /// No description provided for @chatVoiceFinishButton.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get chatVoiceFinishButton;

  /// No description provided for @chatVoiceTooShortMessage.
  ///
  /// In en, this message translates to:
  /// **'Voice message too short'**
  String get chatVoiceTooShortMessage;

  /// No description provided for @chatMicPermissionDeniedMessage.
  ///
  /// In en, this message translates to:
  /// **'Microphone access is needed to send voice messages.'**
  String get chatMicPermissionDeniedMessage;

  /// No description provided for @chatCameraPermissionDeniedMessage.
  ///
  /// In en, this message translates to:
  /// **'Camera access is needed to take a photo.'**
  String get chatCameraPermissionDeniedMessage;

  /// No description provided for @chatMediaUploadFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to send'**
  String get chatMediaUploadFailedMessage;

  /// No description provided for @chatMediaTooLargeMessage.
  ///
  /// In en, this message translates to:
  /// **'File is too large.'**
  String get chatMediaTooLargeMessage;

  /// No description provided for @chatCallComingSoonMessage.
  ///
  /// In en, this message translates to:
  /// **'Calling is coming soon.'**
  String get chatCallComingSoonMessage;

  /// No description provided for @chatVoiceCallLabel.
  ///
  /// In en, this message translates to:
  /// **'Voice call'**
  String get chatVoiceCallLabel;

  /// No description provided for @chatVideoCallLabel.
  ///
  /// In en, this message translates to:
  /// **'Video call'**
  String get chatVideoCallLabel;

  /// No description provided for @chatMessageDeleteForMeOption.
  ///
  /// In en, this message translates to:
  /// **'Delete for me'**
  String get chatMessageDeleteForMeOption;

  /// No description provided for @chatMessageDeleteForEveryoneOption.
  ///
  /// In en, this message translates to:
  /// **'Delete for everyone'**
  String get chatMessageDeleteForEveryoneOption;

  /// No description provided for @chatMessageDeleteForEveryoneConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This message will be permanently deleted for both sides.'**
  String get chatMessageDeleteForEveryoneConfirmMessage;

  /// No description provided for @chatMessageDeleteOption.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get chatMessageDeleteOption;

  /// No description provided for @chatMessageForwardOption.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get chatMessageForwardOption;

  /// No description provided for @chatForwardTitle.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get chatForwardTitle;

  /// No description provided for @chatForwardEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'You have no chats to forward to.'**
  String get chatForwardEmptyMessage;

  /// No description provided for @chatForwardSendButton.
  ///
  /// In en, this message translates to:
  /// **'Send ({count})'**
  String chatForwardSendButton(int count);

  /// No description provided for @chatForwardSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Message forwarded.'**
  String get chatForwardSuccessMessage;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @distanceMetersAway.
  ///
  /// In en, this message translates to:
  /// **'{meters} m away'**
  String distanceMetersAway(int meters);

  /// No description provided for @distanceKmAway.
  ///
  /// In en, this message translates to:
  /// **'{km} km away'**
  String distanceKmAway(String km);

  /// No description provided for @distanceMilesAway.
  ///
  /// In en, this message translates to:
  /// **'{mi} mi away'**
  String distanceMilesAway(String mi);

  /// No description provided for @radiusPeopleCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} person} other{{count} people}}'**
  String radiusPeopleCount(int count);

  /// No description provided for @radiusMoreButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get radiusMoreButtonLabel;

  /// No description provided for @radiusMorePanelTitle.
  ///
  /// In en, this message translates to:
  /// **'Search radius'**
  String get radiusMorePanelTitle;

  /// No description provided for @premiumUpsellRadiusTitle.
  ///
  /// In en, this message translates to:
  /// **'Discover people further away 🌍'**
  String get premiumUpsellRadiusTitle;

  /// No description provided for @premiumUpsellRadiusMessage.
  ///
  /// In en, this message translates to:
  /// **'With Premium you can see people within 5 km and 10 km, and meet more people.'**
  String get premiumUpsellRadiusMessage;

  /// No description provided for @premiumUpgradeButton.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Premium'**
  String get premiumUpgradeButton;

  /// No description provided for @premiumLaterButton.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get premiumLaterButton;

  /// No description provided for @premiumComingSoonTitle.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get premiumComingSoonTitle;

  /// No description provided for @premiumComingSoonMessage.
  ///
  /// In en, this message translates to:
  /// **'Premium membership will be available soon.'**
  String get premiumComingSoonMessage;

  /// No description provided for @chatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get chatsTitle;

  /// No description provided for @chatsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No chats yet'**
  String get chatsEmptyTitle;

  /// No description provided for @chatsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your chats will appear here once you meet people around you.'**
  String get chatsEmptySubtitle;

  /// No description provided for @chatsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search chats'**
  String get chatsSearchHint;

  /// No description provided for @chatsSearchEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get chatsSearchEmptyTitle;

  /// No description provided for @chatsSearchEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Try a different name, username, or word.'**
  String get chatsSearchEmptySubtitle;

  /// No description provided for @chatsFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get chatsFilterAll;

  /// No description provided for @chatsFilterUnread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get chatsFilterUnread;

  /// No description provided for @chatsFilterArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get chatsFilterArchived;

  /// No description provided for @chatsFilterRequests.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get chatsFilterRequests;

  /// No description provided for @chatsUnreadEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No unread messages'**
  String get chatsUnreadEmptyTitle;

  /// No description provided for @chatsUnreadEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'All messages have been read.'**
  String get chatsUnreadEmptySubtitle;

  /// No description provided for @chatsArchivedEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No archived chats'**
  String get chatsArchivedEmptyTitle;

  /// No description provided for @chatsArchivedEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Archived chats will show up here.'**
  String get chatsArchivedEmptySubtitle;

  /// No description provided for @chatsRequestsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No message requests'**
  String get chatsRequestsEmptyTitle;

  /// No description provided for @chatsRequestsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'First messages from people you don\'t know yet will show up here.'**
  String get chatsRequestsEmptySubtitle;

  /// No description provided for @chatsPinLimitReachedMessage.
  ///
  /// In en, this message translates to:
  /// **'You can pin up to 3 chats.'**
  String get chatsPinLimitReachedMessage;

  /// No description provided for @chatsPinAction.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get chatsPinAction;

  /// No description provided for @chatsUnpinAction.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get chatsUnpinAction;

  /// No description provided for @chatsArchiveAction.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get chatsArchiveAction;

  /// No description provided for @chatsUnarchiveAction.
  ///
  /// In en, this message translates to:
  /// **'Unarchive'**
  String get chatsUnarchiveAction;

  /// No description provided for @chatsMuteAction.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get chatsMuteAction;

  /// No description provided for @chatsUnmuteAction.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get chatsUnmuteAction;

  /// No description provided for @chatsPinnedSectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get chatsPinnedSectionLabel;

  /// No description provided for @chatsRecentSectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Recent chats'**
  String get chatsRecentSectionLabel;

  /// No description provided for @eventSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get eventSaveButton;

  /// No description provided for @venueCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Venue profile'**
  String get venueCreateTitle;

  /// No description provided for @venueEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit venue'**
  String get venueEditTitle;

  /// No description provided for @venuePhotoLabel.
  ///
  /// In en, this message translates to:
  /// **'Add photo/logo'**
  String get venuePhotoLabel;

  /// No description provided for @venuePhotoSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get venuePhotoSheetTitle;

  /// No description provided for @venuePhotoGalleryOption.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get venuePhotoGalleryOption;

  /// No description provided for @venuePhotoCameraOption.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get venuePhotoCameraOption;

  /// No description provided for @venueNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get venueNameLabel;

  /// No description provided for @venueNameHint.
  ///
  /// In en, this message translates to:
  /// **'Venue name'**
  String get venueNameHint;

  /// No description provided for @venueFieldRequiredError.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get venueFieldRequiredError;

  /// No description provided for @venueCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get venueCategoryLabel;

  /// No description provided for @venueCategoryPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a category'**
  String get venueCategoryPickerTitle;

  /// No description provided for @venueCategorySearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search categories...'**
  String get venueCategorySearchHint;

  /// No description provided for @venueCategoryChangeHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to change'**
  String get venueCategoryChangeHint;

  /// No description provided for @venuePhotoCropTitle.
  ///
  /// In en, this message translates to:
  /// **'Crop photo'**
  String get venuePhotoCropTitle;

  /// No description provided for @venueUploadingLabel.
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get venueUploadingLabel;

  /// No description provided for @venueUploadCancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get venueUploadCancelButton;

  /// No description provided for @venueDirectionsGoogleMaps.
  ///
  /// In en, this message translates to:
  /// **'Google Maps'**
  String get venueDirectionsGoogleMaps;

  /// No description provided for @venueDirectionsAppleMaps.
  ///
  /// In en, this message translates to:
  /// **'Apple Maps'**
  String get venueDirectionsAppleMaps;

  /// No description provided for @venueDirectionsWaze.
  ///
  /// In en, this message translates to:
  /// **'Waze'**
  String get venueDirectionsWaze;

  /// No description provided for @venueScheduleLabel.
  ///
  /// In en, this message translates to:
  /// **'Weekly schedule'**
  String get venueScheduleLabel;

  /// No description provided for @venueFullAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Full address'**
  String get venueFullAddressLabel;

  /// No description provided for @venuesSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search venues...'**
  String get venuesSearchHint;

  /// No description provided for @venueFilterTooltip.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get venueFilterTooltip;

  /// No description provided for @venueCategoryFilterTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose category'**
  String get venueCategoryFilterTitle;

  /// No description provided for @venueCategoryAllOption.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get venueCategoryAllOption;

  /// No description provided for @offersSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search offers...'**
  String get offersSearchHint;

  /// No description provided for @offerFilterTooltip.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get offerFilterTooltip;

  /// No description provided for @offersEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No offers yet'**
  String get offersEmptyTitle;

  /// No description provided for @offersEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Offers from nearby venues will show up here.'**
  String get offersEmptySubtitle;

  /// No description provided for @offerCategoryFilterTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a category'**
  String get offerCategoryFilterTitle;

  /// No description provided for @offerCategoryAllOption.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get offerCategoryAllOption;

  /// No description provided for @offerBadgeDiscountSuffix.
  ///
  /// In en, this message translates to:
  /// **'off'**
  String get offerBadgeDiscountSuffix;

  /// No description provided for @offerBadgeGiftLabel.
  ///
  /// In en, this message translates to:
  /// **'Gift'**
  String get offerBadgeGiftLabel;

  /// No description provided for @offerBadgeBuyOneGetOneLabel.
  ///
  /// In en, this message translates to:
  /// **'1+1'**
  String get offerBadgeBuyOneGetOneLabel;

  /// No description provided for @offerBadgeFixedPriceSuffix.
  ///
  /// In en, this message translates to:
  /// **'AZN'**
  String get offerBadgeFixedPriceSuffix;

  /// No description provided for @offerEndsOnLabel.
  ///
  /// In en, this message translates to:
  /// **'Until {date}'**
  String offerEndsOnLabel(String date);

  /// No description provided for @offerTermsLabel.
  ///
  /// In en, this message translates to:
  /// **'Terms'**
  String get offerTermsLabel;

  /// No description provided for @offerValidityLabel.
  ///
  /// In en, this message translates to:
  /// **'Validity period'**
  String get offerValidityLabel;

  /// No description provided for @offerStartDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Starts'**
  String get offerStartDateLabel;

  /// No description provided for @offerEndDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get offerEndDateLabel;

  /// No description provided for @offerContactLabel.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get offerContactLabel;

  /// No description provided for @offerOtherActiveOffersLabel.
  ///
  /// In en, this message translates to:
  /// **'Other active offers'**
  String get offerOtherActiveOffersLabel;

  /// No description provided for @offerViewVenueProfileButton.
  ///
  /// In en, this message translates to:
  /// **'View venue profile'**
  String get offerViewVenueProfileButton;

  /// No description provided for @offerNotFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'Offer not found.'**
  String get offerNotFoundMessage;

  /// No description provided for @offerGenericErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again shortly.'**
  String get offerGenericErrorMessage;

  /// No description provided for @offerCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create offer'**
  String get offerCreateTitle;

  /// No description provided for @offerEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit offer'**
  String get offerEditTitle;

  /// No description provided for @offerPhotoLabel.
  ///
  /// In en, this message translates to:
  /// **'Add a photo/logo'**
  String get offerPhotoLabel;

  /// No description provided for @offerNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Offer name'**
  String get offerNameLabel;

  /// No description provided for @offerNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the offer name'**
  String get offerNameHint;

  /// No description provided for @offerCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Choose a category'**
  String get offerCategoryLabel;

  /// No description provided for @offerTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Offer type'**
  String get offerTypeLabel;

  /// No description provided for @offerTypeDiscountOption.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get offerTypeDiscountOption;

  /// No description provided for @offerTypeGiftOption.
  ///
  /// In en, this message translates to:
  /// **'Gift'**
  String get offerTypeGiftOption;

  /// No description provided for @offerTypeBuyOneGetOneOption.
  ///
  /// In en, this message translates to:
  /// **'1+1 gift'**
  String get offerTypeBuyOneGetOneOption;

  /// No description provided for @offerTypeFixedPriceOption.
  ///
  /// In en, this message translates to:
  /// **'Fixed price'**
  String get offerTypeFixedPriceOption;

  /// No description provided for @offerDiscountAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Discount amount'**
  String get offerDiscountAmountLabel;

  /// No description provided for @offerFixedPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Price (AZN)'**
  String get offerFixedPriceLabel;

  /// No description provided for @offerFixedPriceHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the price'**
  String get offerFixedPriceHint;

  /// No description provided for @offerDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Short description'**
  String get offerDescriptionLabel;

  /// No description provided for @offerDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Describe the offer\'s terms and perks...'**
  String get offerDescriptionHint;

  /// No description provided for @offerValidityPeriodLabel.
  ///
  /// In en, this message translates to:
  /// **'Offer validity period'**
  String get offerValidityPeriodLabel;

  /// No description provided for @offerStartDatePickerLabel.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get offerStartDatePickerLabel;

  /// No description provided for @offerEndDatePickerLabel.
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get offerEndDatePickerLabel;

  /// No description provided for @offerVenuePickerLabel.
  ///
  /// In en, this message translates to:
  /// **'Choose a venue'**
  String get offerVenuePickerLabel;

  /// No description provided for @offerVenuePickerHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a venue'**
  String get offerVenuePickerHint;

  /// No description provided for @offerNoVenuesTitle.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have any venues yet'**
  String get offerNoVenuesTitle;

  /// No description provided for @offerNoVenuesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add a venue first to create an offer.'**
  String get offerNoVenuesSubtitle;

  /// No description provided for @offerAddVenueButton.
  ///
  /// In en, this message translates to:
  /// **'Add a venue'**
  String get offerAddVenueButton;

  /// No description provided for @offerTermsHint.
  ///
  /// In en, this message translates to:
  /// **'Write the offer\'s terms of use...'**
  String get offerTermsHint;

  /// No description provided for @offerAdditionalInfoLabel.
  ///
  /// In en, this message translates to:
  /// **'Additional info'**
  String get offerAdditionalInfoLabel;

  /// No description provided for @offerContactPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get offerContactPhoneHint;

  /// No description provided for @offerContactWebsiteHint.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get offerContactWebsiteHint;

  /// No description provided for @offerContactInstagramHint.
  ///
  /// In en, this message translates to:
  /// **'Instagram'**
  String get offerContactInstagramHint;

  /// No description provided for @offerSubmitButton.
  ///
  /// In en, this message translates to:
  /// **'Create offer'**
  String get offerSubmitButton;

  /// No description provided for @offerCreatedNotice.
  ///
  /// In en, this message translates to:
  /// **'Offer created'**
  String get offerCreatedNotice;

  /// No description provided for @offerUpdatedNotice.
  ///
  /// In en, this message translates to:
  /// **'Offer updated'**
  String get offerUpdatedNotice;

  /// No description provided for @offerRequiredFieldsMissing.
  ///
  /// In en, this message translates to:
  /// **'Please fill in all the required fields.'**
  String get offerRequiredFieldsMissing;

  /// No description provided for @offerDatesInvalidError.
  ///
  /// In en, this message translates to:
  /// **'The end date must be after the start date.'**
  String get offerDatesInvalidError;

  /// No description provided for @offerDeleteMenuOption.
  ///
  /// In en, this message translates to:
  /// **'Delete offer'**
  String get offerDeleteMenuOption;

  /// No description provided for @offerDeleteConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this offer? This can\'t be undone.'**
  String get offerDeleteConfirmMessage;

  /// No description provided for @offerDeletedNotice.
  ///
  /// In en, this message translates to:
  /// **'Offer deleted'**
  String get offerDeletedNotice;

  /// No description provided for @offerStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get offerStatusActive;

  /// No description provided for @offerStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get offerStatusExpired;

  /// No description provided for @offerMyOffersTitle.
  ///
  /// In en, this message translates to:
  /// **'My offers'**
  String get offerMyOffersTitle;

  /// No description provided for @offerMyOffersEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t added any offers yet'**
  String get offerMyOffersEmptyTitle;

  /// No description provided for @offerMyOffersEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Offers you add will show up here, and you can edit or delete them anytime.'**
  String get offerMyOffersEmptySubtitle;

  /// No description provided for @offerMyOffersTooltip.
  ///
  /// In en, this message translates to:
  /// **'My offers'**
  String get offerMyOffersTooltip;

  /// No description provided for @offerAddButtonTooltip.
  ///
  /// In en, this message translates to:
  /// **'Create offer'**
  String get offerAddButtonTooltip;

  /// No description provided for @venueCategoryUnselectedLabel.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get venueCategoryUnselectedLabel;

  /// No description provided for @venueCategoryRestaurant.
  ///
  /// In en, this message translates to:
  /// **'Restaurant'**
  String get venueCategoryRestaurant;

  /// No description provided for @venueCategoryPub.
  ///
  /// In en, this message translates to:
  /// **'Pub'**
  String get venueCategoryPub;

  /// No description provided for @venueCategoryCoffeeShop.
  ///
  /// In en, this message translates to:
  /// **'Coffee Shops'**
  String get venueCategoryCoffeeShop;

  /// No description provided for @venueCategoryFastFood.
  ///
  /// In en, this message translates to:
  /// **'Fast-Food'**
  String get venueCategoryFastFood;

  /// No description provided for @venueCategoryTeaHouse.
  ///
  /// In en, this message translates to:
  /// **'Tea House'**
  String get venueCategoryTeaHouse;

  /// No description provided for @venueCategorySweetsShop.
  ///
  /// In en, this message translates to:
  /// **'Sweets Shop'**
  String get venueCategorySweetsShop;

  /// No description provided for @venueCategoryHotel.
  ///
  /// In en, this message translates to:
  /// **'Hotel'**
  String get venueCategoryHotel;

  /// No description provided for @venueCategoryMotel.
  ///
  /// In en, this message translates to:
  /// **'Motel'**
  String get venueCategoryMotel;

  /// No description provided for @venueCategoryCinema.
  ///
  /// In en, this message translates to:
  /// **'Cinema'**
  String get venueCategoryCinema;

  /// No description provided for @venueCategoryKaraoke.
  ///
  /// In en, this message translates to:
  /// **'Karaoke Bar'**
  String get venueCategoryKaraoke;

  /// No description provided for @venueCategoryGameHall.
  ///
  /// In en, this message translates to:
  /// **'Game Hall'**
  String get venueCategoryGameHall;

  /// No description provided for @venueCategoryNightClub.
  ///
  /// In en, this message translates to:
  /// **'Night Club'**
  String get venueCategoryNightClub;

  /// No description provided for @venueCategoryFitness.
  ///
  /// In en, this message translates to:
  /// **'Fitness'**
  String get venueCategoryFitness;

  /// No description provided for @venueCategoryGym.
  ///
  /// In en, this message translates to:
  /// **'GYM'**
  String get venueCategoryGym;

  /// No description provided for @venueCategorySpa.
  ///
  /// In en, this message translates to:
  /// **'Spa, Massage & Sauna'**
  String get venueCategorySpa;

  /// No description provided for @venueCategoryFootballField.
  ///
  /// In en, this message translates to:
  /// **'Football Field'**
  String get venueCategoryFootballField;

  /// No description provided for @venueCategoryClinic.
  ///
  /// In en, this message translates to:
  /// **'Clinic'**
  String get venueCategoryClinic;

  /// No description provided for @venueCategoryBeautySalon.
  ///
  /// In en, this message translates to:
  /// **'Beauty Salon'**
  String get venueCategoryBeautySalon;

  /// No description provided for @venueCategoryBarbershop.
  ///
  /// In en, this message translates to:
  /// **'Barbershop'**
  String get venueCategoryBarbershop;

  /// No description provided for @venueCategoryCosmetology.
  ///
  /// In en, this message translates to:
  /// **'Cosmetology'**
  String get venueCategoryCosmetology;

  /// No description provided for @venueCategoryTattoo.
  ///
  /// In en, this message translates to:
  /// **'Tattoo & Piercing'**
  String get venueCategoryTattoo;

  /// No description provided for @venueCategoryPhotoStudio.
  ///
  /// In en, this message translates to:
  /// **'Photo Studio'**
  String get venueCategoryPhotoStudio;

  /// No description provided for @venueCategoryKidsEntertainment.
  ///
  /// In en, this message translates to:
  /// **'Kids Entertainment'**
  String get venueCategoryKidsEntertainment;

  /// No description provided for @venueCategoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get venueCategoryOther;

  /// No description provided for @venueHoursLabel.
  ///
  /// In en, this message translates to:
  /// **'Opening hours'**
  String get venueHoursLabel;

  /// No description provided for @venueHours24Label.
  ///
  /// In en, this message translates to:
  /// **'Open 24 hours'**
  String get venueHours24Label;

  /// No description provided for @venueHoursSameEveryDayLabel.
  ///
  /// In en, this message translates to:
  /// **'Same hours every day'**
  String get venueHoursSameEveryDayLabel;

  /// No description provided for @venueWeekdayMon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get venueWeekdayMon;

  /// No description provided for @venueWeekdayTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get venueWeekdayTue;

  /// No description provided for @venueWeekdayWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get venueWeekdayWed;

  /// No description provided for @venueWeekdayThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get venueWeekdayThu;

  /// No description provided for @venueWeekdayFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get venueWeekdayFri;

  /// No description provided for @venueWeekdaySat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get venueWeekdaySat;

  /// No description provided for @venueWeekdaySun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get venueWeekdaySun;

  /// No description provided for @venueLocationLabel.
  ///
  /// In en, this message translates to:
  /// **'Address/location'**
  String get venueLocationLabel;

  /// No description provided for @venuePickOnMapButton.
  ///
  /// In en, this message translates to:
  /// **'Pick on map'**
  String get venuePickOnMapButton;

  /// No description provided for @venueLocationPickedLabel.
  ///
  /// In en, this message translates to:
  /// **'Picked on map ✓'**
  String get venueLocationPickedLabel;

  /// No description provided for @venueLocationPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a location'**
  String get venueLocationPickerTitle;

  /// No description provided for @venueLocationPickerHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the map or drag the pin to the exact spot'**
  String get venueLocationPickerHint;

  /// No description provided for @venueLocationResolvingAddress.
  ///
  /// In en, this message translates to:
  /// **'Resolving address...'**
  String get venueLocationResolvingAddress;

  /// No description provided for @venueLocationAddressUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Address not found'**
  String get venueLocationAddressUnavailable;

  /// No description provided for @venueLocationPickerConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'Use this location'**
  String get venueLocationPickerConfirmButton;

  /// No description provided for @venueCreateButton.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get venueCreateButton;

  /// No description provided for @venueSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get venueSaveButton;

  /// No description provided for @venueRequiredFieldsMissing.
  ///
  /// In en, this message translates to:
  /// **'Please fill in all required fields.'**
  String get venueRequiredFieldsMissing;

  /// No description provided for @venueGenericErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t go through. Please try again in a moment.'**
  String get venueGenericErrorMessage;

  /// No description provided for @venueAddButtonTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add a venue'**
  String get venueAddButtonTooltip;

  /// No description provided for @venuesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No venues nearby'**
  String get venuesEmptyTitle;

  /// No description provided for @venuesEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'No one has added a venue within your selected radius yet.'**
  String get venuesEmptySubtitle;

  /// No description provided for @venueMyVenuesTooltip.
  ///
  /// In en, this message translates to:
  /// **'My venues'**
  String get venueMyVenuesTooltip;

  /// No description provided for @venueMyVenuesTitle.
  ///
  /// In en, this message translates to:
  /// **'My venues'**
  String get venueMyVenuesTitle;

  /// No description provided for @venueMyVenuesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t added any venues yet'**
  String get venueMyVenuesEmptyTitle;

  /// No description provided for @venueMyVenuesEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Venues you add will show up here, and you can edit or delete them anytime.'**
  String get venueMyVenuesEmptySubtitle;

  /// No description provided for @venueDeleteMenuOption.
  ///
  /// In en, this message translates to:
  /// **'Delete venue'**
  String get venueDeleteMenuOption;

  /// No description provided for @venueDeleteConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this venue? This action cannot be undone.'**
  String get venueDeleteConfirmMessage;

  /// No description provided for @venueDeletedNotice.
  ///
  /// In en, this message translates to:
  /// **'Venue deleted'**
  String get venueDeletedNotice;

  /// No description provided for @venueOpenNowLabel.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get venueOpenNowLabel;

  /// No description provided for @venueClosedNowLabel.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get venueClosedNowLabel;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileNamePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Add your name'**
  String get profileNamePlaceholder;

  /// No description provided for @profileBioPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Add a photo, bio and interests'**
  String get profileBioPlaceholder;

  /// No description provided for @shareProfileLabel.
  ///
  /// In en, this message translates to:
  /// **'Share profile'**
  String get shareProfileLabel;

  /// No description provided for @profileStatsFriends.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get profileStatsFriends;

  /// No description provided for @profileStatsLikes.
  ///
  /// In en, this message translates to:
  /// **'Likes'**
  String get profileStatsLikes;

  /// No description provided for @profileGalleryEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t uploaded any photos or videos yet'**
  String get profileGalleryEmptyMessage;

  /// No description provided for @editProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Personal info'**
  String get editProfileTitle;

  /// No description provided for @personalInfoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Update your details and save your changes.'**
  String get personalInfoSubtitle;

  /// No description provided for @profileSaveSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Your details have been updated.'**
  String get profileSaveSuccessMessage;

  /// No description provided for @menuSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get menuSettings;

  /// No description provided for @menuPrivacySecurity.
  ///
  /// In en, this message translates to:
  /// **'Privacy and security'**
  String get menuPrivacySecurity;

  /// No description provided for @privacySecurityTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy and security'**
  String get privacySecurityTitle;

  /// No description provided for @privacyProfileVisibilityTitle.
  ///
  /// In en, this message translates to:
  /// **'Media visibility'**
  String get privacyProfileVisibilityTitle;

  /// No description provided for @privacyProfileVisibilitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose who can see the posts on your profile.'**
  String get privacyProfileVisibilitySubtitle;

  /// No description provided for @privacyVisibilityEveryone.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get privacyVisibilityEveryone;

  /// No description provided for @privacyVisibilityFollowersOnly.
  ///
  /// In en, this message translates to:
  /// **'Following & Followers'**
  String get privacyVisibilityFollowersOnly;

  /// No description provided for @privacyVisibilityNoOne.
  ///
  /// In en, this message translates to:
  /// **'No one'**
  String get privacyVisibilityNoOne;

  /// No description provided for @privacyClosedProfileNotice.
  ///
  /// In en, this message translates to:
  /// **'Closed profile'**
  String get privacyClosedProfileNotice;

  /// No description provided for @privacyRadiusTitle.
  ///
  /// In en, this message translates to:
  /// **'Visibility radius'**
  String get privacyRadiusTitle;

  /// No description provided for @privacyRadiusCountryLabel.
  ///
  /// In en, this message translates to:
  /// **'By country'**
  String get privacyRadiusCountryLabel;

  /// No description provided for @privacyRadiusWorldLabel.
  ///
  /// In en, this message translates to:
  /// **'Worldwide'**
  String get privacyRadiusWorldLabel;

  /// No description provided for @privacyOnlineStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Show that I\'m online'**
  String get privacyOnlineStatusTitle;

  /// No description provided for @privacyReadReceiptsTitle.
  ///
  /// In en, this message translates to:
  /// **'Show read receipts'**
  String get privacyReadReceiptsTitle;

  /// No description provided for @privacyReadReceiptsHelperText.
  ///
  /// In en, this message translates to:
  /// **'Turning this off also hides the other person\'s read receipts from you.'**
  String get privacyReadReceiptsHelperText;

  /// No description provided for @privacyWhoCanMessageTitle.
  ///
  /// In en, this message translates to:
  /// **'Who can message me'**
  String get privacyWhoCanMessageTitle;

  /// No description provided for @privacyMessagePermEveryone.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get privacyMessagePermEveryone;

  /// No description provided for @privacyMessagePermVerifiedOnly.
  ///
  /// In en, this message translates to:
  /// **'Verified users only'**
  String get privacyMessagePermVerifiedOnly;

  /// No description provided for @privacyMessagePermNoOne.
  ///
  /// In en, this message translates to:
  /// **'No one'**
  String get privacyMessagePermNoOne;

  /// No description provided for @privacyGhostModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Ghost mode'**
  String get privacyGhostModeTitle;

  /// No description provided for @privacyGhostModeDescription.
  ///
  /// In en, this message translates to:
  /// **'You can see other users. Other users can\'t see you on the map. Turn it on or off any time you like.'**
  String get privacyGhostModeDescription;

  /// No description provided for @privacyGhostModePremiumTitle.
  ///
  /// In en, this message translates to:
  /// **'Go invisible with Ghost mode 👻'**
  String get privacyGhostModePremiumTitle;

  /// No description provided for @privacyGhostModePremiumMessage.
  ///
  /// In en, this message translates to:
  /// **'With Premium you can see other users, but they won\'t be able to see you on the map.'**
  String get privacyGhostModePremiumMessage;

  /// No description provided for @privacySettingUpdateErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'That change wasn\'t saved. Please try again in a moment.'**
  String get privacySettingUpdateErrorMessage;

  /// No description provided for @privacyTwoFactorTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable two-factor authentication'**
  String get privacyTwoFactorTitle;

  /// No description provided for @privacyTwoFactorHelperText.
  ///
  /// In en, this message translates to:
  /// **'Only your choice is saved for now — SMS and Authenticator support are coming soon.'**
  String get privacyTwoFactorHelperText;

  /// No description provided for @privacyExportDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Download my data'**
  String get privacyExportDataTitle;

  /// No description provided for @privacyExportDataDescription.
  ///
  /// In en, this message translates to:
  /// **'Data stored about you in the app will be prepared and shown to you.'**
  String get privacyExportDataDescription;

  /// No description provided for @exportDataScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'My data'**
  String get exportDataScreenTitle;

  /// No description provided for @exportDataCopyButton.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get exportDataCopyButton;

  /// No description provided for @exportDataCopiedNotice.
  ///
  /// In en, this message translates to:
  /// **'Data copied to clipboard.'**
  String get exportDataCopiedNotice;

  /// No description provided for @exportDataLoadErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your data. Please try again.'**
  String get exportDataLoadErrorMessage;

  /// No description provided for @privacyDeleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get privacyDeleteAccountTitle;

  /// No description provided for @deleteAccountWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete your account?'**
  String get deleteAccountWarningTitle;

  /// No description provided for @deleteAccountWarningMessage.
  ///
  /// In en, this message translates to:
  /// **'Your profile, chats and all your data will be permanently deleted. This can\'t be undone.'**
  String get deleteAccountWarningMessage;

  /// No description provided for @deleteAccountFinalConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Final confirmation'**
  String get deleteAccountFinalConfirmTitle;

  /// No description provided for @deleteAccountFinalConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'You\'re about to delete your account. There\'s no going back after this.'**
  String get deleteAccountFinalConfirmMessage;

  /// No description provided for @deleteAccountConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'Yes, delete my account'**
  String get deleteAccountConfirmButton;

  /// No description provided for @deleteAccountReauthTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify it\'s you'**
  String get deleteAccountReauthTitle;

  /// No description provided for @deleteAccountReauthMessage.
  ///
  /// In en, this message translates to:
  /// **'For security, you need to re-verify your phone number before deleting your account.'**
  String get deleteAccountReauthMessage;

  /// No description provided for @deleteAccountSendCodeButton.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get deleteAccountSendCodeButton;

  /// No description provided for @deleteAccountCodeSentMessage.
  ///
  /// In en, this message translates to:
  /// **'Code sent'**
  String get deleteAccountCodeSentMessage;

  /// No description provided for @deleteAccountOtpHint.
  ///
  /// In en, this message translates to:
  /// **'SMS code'**
  String get deleteAccountOtpHint;

  /// No description provided for @deleteAccountConfirmCodeButton.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get deleteAccountConfirmCodeButton;

  /// No description provided for @deleteAccountReauthFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Verification failed. Please try again.'**
  String get deleteAccountReauthFailedMessage;

  /// No description provided for @deleteAccountErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete the account. Please try again in a moment.'**
  String get deleteAccountErrorMessage;

  /// No description provided for @blockedUsersTitle.
  ///
  /// In en, this message translates to:
  /// **'Blocked users'**
  String get blockedUsersTitle;

  /// No description provided for @blockedUsersEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No blocked users'**
  String get blockedUsersEmptyTitle;

  /// No description provided for @blockedUsersEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Users you block will show up here.'**
  String get blockedUsersEmptySubtitle;

  /// No description provided for @menuNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get menuNotifications;

  /// No description provided for @menuHelp.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get menuHelp;

  /// No description provided for @menuLogout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get menuLogout;

  /// No description provided for @uploadingProgress.
  ///
  /// In en, this message translates to:
  /// **'{percent}% uploading...'**
  String uploadingProgress(String percent);

  /// No description provided for @removePhotoButton.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get removePhotoButton;

  /// No description provided for @fieldAgeLabel.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get fieldAgeLabel;

  /// No description provided for @fieldAgeHint.
  ///
  /// In en, this message translates to:
  /// **'25'**
  String get fieldAgeHint;

  /// No description provided for @fieldEmailOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Email (optional)'**
  String get fieldEmailOptionalLabel;

  /// No description provided for @fieldEmailHint.
  ///
  /// In en, this message translates to:
  /// **'name@email.com'**
  String get fieldEmailHint;

  /// No description provided for @sectionAboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About you'**
  String get sectionAboutTitle;

  /// No description provided for @bioHintEdit.
  ///
  /// In en, this message translates to:
  /// **'Write a few sentences about yourself...'**
  String get bioHintEdit;

  /// No description provided for @saveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveButton;

  /// No description provided for @waitPhotoUploadError.
  ///
  /// In en, this message translates to:
  /// **'Wait for the photo to finish uploading...'**
  String get waitPhotoUploadError;

  /// No description provided for @invalidEmailError.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get invalidEmailError;

  /// No description provided for @saveFailedError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save: {error}'**
  String saveFailedError(String error);

  /// No description provided for @photoOperationFailedError.
  ///
  /// In en, this message translates to:
  /// **'The photo operation failed.'**
  String get photoOperationFailedError;

  /// No description provided for @storageErrorFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The photo can\'t be larger than 5MB.'**
  String get storageErrorFileTooLarge;

  /// No description provided for @storageErrorInvalidContentType.
  ///
  /// In en, this message translates to:
  /// **'Unsupported file format.'**
  String get storageErrorInvalidContentType;

  /// No description provided for @storageErrorUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'The photo couldn\'t be uploaded.'**
  String get storageErrorUploadFailed;

  /// No description provided for @storageErrorDownloadUrlFailed.
  ///
  /// In en, this message translates to:
  /// **'The photo couldn\'t be loaded.'**
  String get storageErrorDownloadUrlFailed;

  /// No description provided for @storageErrorDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'The photo couldn\'t be deleted.'**
  String get storageErrorDeleteFailed;

  /// No description provided for @storageErrorPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission for this action.'**
  String get storageErrorPermissionDenied;

  /// No description provided for @storageErrorUnauthenticated.
  ///
  /// In en, this message translates to:
  /// **'You\'re not signed in.'**
  String get storageErrorUnauthenticated;

  /// No description provided for @storageErrorUnknown.
  ///
  /// In en, this message translates to:
  /// **'An unknown storage error occurred.'**
  String get storageErrorUnknown;

  /// No description provided for @comingSoonDefaultMessage.
  ///
  /// In en, this message translates to:
  /// **'This feature will be available soon.'**
  String get comingSoonDefaultMessage;

  /// No description provided for @pickCountryHint.
  ///
  /// In en, this message translates to:
  /// **'Search country'**
  String get pickCountryHint;

  /// No description provided for @pickCityTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose city'**
  String get pickCityTitle;

  /// No description provided for @pickCityHint.
  ///
  /// In en, this message translates to:
  /// **'Search city'**
  String get pickCityHint;

  /// No description provided for @searchNotFound.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get searchNotFound;

  /// No description provided for @fieldCountryLabel.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get fieldCountryLabel;

  /// No description provided for @fieldCitySelectFirstHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a country first'**
  String get fieldCitySelectFirstHint;

  /// No description provided for @fieldCityLabel.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get fieldCityLabel;

  /// No description provided for @contactRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Enter your email or phone number'**
  String get contactRequiredError;

  /// No description provided for @contactInvalidError.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email or phone number'**
  String get contactInvalidError;

  /// No description provided for @stampLike.
  ///
  /// In en, this message translates to:
  /// **'LIKE'**
  String get stampLike;

  /// No description provided for @stampReject.
  ///
  /// In en, this message translates to:
  /// **'PASS'**
  String get stampReject;

  /// No description provided for @stampSuper.
  ///
  /// In en, this message translates to:
  /// **'SUPER'**
  String get stampSuper;

  /// No description provided for @emptyStackTitle.
  ///
  /// In en, this message translates to:
  /// **'No one around yet'**
  String get emptyStackTitle;

  /// No description provided for @emptyStackSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Try changing the radius or filter.'**
  String get emptyStackSubtitle;

  /// No description provided for @discoverActiveNowLabel.
  ///
  /// In en, this message translates to:
  /// **'Active now'**
  String get discoverActiveNowLabel;

  /// No description provided for @discoverSwipeUpHint.
  ///
  /// In en, this message translates to:
  /// **'Swipe up for the next card'**
  String get discoverSwipeUpHint;

  /// No description provided for @discoverMatchTitle.
  ///
  /// In en, this message translates to:
  /// **'It\'s a match!'**
  String get discoverMatchTitle;

  /// No description provided for @discoverMatchMessage.
  ///
  /// In en, this message translates to:
  /// **'You both liked each other!'**
  String get discoverMatchMessage;

  /// No description provided for @discoverMatchLaterButton.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get discoverMatchLaterButton;

  /// No description provided for @storyVisibilitySheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Who can see this?'**
  String get storyVisibilitySheetTitle;

  /// No description provided for @storyVisibilityPickPrompt.
  ///
  /// In en, this message translates to:
  /// **'Who can see this?'**
  String get storyVisibilityPickPrompt;

  /// No description provided for @storyVisibilityFollowers.
  ///
  /// In en, this message translates to:
  /// **'Following & Followers'**
  String get storyVisibilityFollowers;

  /// No description provided for @storyVisibilityEveryone.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get storyVisibilityEveryone;

  /// No description provided for @storyShareButton.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get storyShareButton;

  /// No description provided for @storyVideoTooLongMessage.
  ///
  /// In en, this message translates to:
  /// **'Videos can be at most 60 seconds long'**
  String get storyVideoTooLongMessage;

  /// No description provided for @storyShareErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t share this. Please try again shortly.'**
  String get storyShareErrorMessage;

  /// No description provided for @storyViewersEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'No one has viewed this yet'**
  String get storyViewersEmptyMessage;

  /// No description provided for @storyViewersTitle.
  ///
  /// In en, this message translates to:
  /// **'Viewers'**
  String get storyViewersTitle;

  /// No description provided for @postCaptureSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a post'**
  String get postCaptureSheetTitle;

  /// No description provided for @postCameraOption.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get postCameraOption;

  /// No description provided for @postGalleryPhotoOption.
  ///
  /// In en, this message translates to:
  /// **'Choose a photo'**
  String get postGalleryPhotoOption;

  /// No description provided for @postGalleryVideoOption.
  ///
  /// In en, this message translates to:
  /// **'Choose a video'**
  String get postGalleryVideoOption;

  /// No description provided for @postShareButton.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get postShareButton;

  /// No description provided for @postShareErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'The post couldn\'t be shared. Please try again shortly.'**
  String get postShareErrorMessage;

  /// No description provided for @postFeedEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'No posts yet'**
  String get postFeedEmptyMessage;

  /// No description provided for @postCommentsSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get postCommentsSheetTitle;

  /// No description provided for @postCommentsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'No comments yet'**
  String get postCommentsEmptyMessage;

  /// No description provided for @postCommentHint.
  ///
  /// In en, this message translates to:
  /// **'Write a comment...'**
  String get postCommentHint;

  /// No description provided for @postCommentSendButton.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get postCommentSendButton;

  /// No description provided for @postCommentErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'The comment wasn\'t sent. Please try again shortly.'**
  String get postCommentErrorMessage;

  /// No description provided for @postLikeErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'The like wasn\'t saved. Please try again shortly.'**
  String get postLikeErrorMessage;

  /// No description provided for @feedSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get feedSearchHint;

  /// No description provided for @feedSearchNoResultsMessage.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get feedSearchNoResultsMessage;

  /// No description provided for @feedDownloadVideoOption.
  ///
  /// In en, this message translates to:
  /// **'Download video'**
  String get feedDownloadVideoOption;

  /// No description provided for @feedDownloadInProgressMessage.
  ///
  /// In en, this message translates to:
  /// **'Downloading... {percent}%'**
  String feedDownloadInProgressMessage(int percent);

  /// No description provided for @feedDownloadCompleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Video saved to your gallery'**
  String get feedDownloadCompleteMessage;

  /// No description provided for @feedDownloadErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t download the video. Please try again shortly.'**
  String get feedDownloadErrorMessage;

  /// No description provided for @postTimeJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get postTimeJustNow;

  /// No description provided for @postTimeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} min ago'**
  String postTimeMinutesAgo(int count);

  /// No description provided for @postTimeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String postTimeHoursAgo(int count);

  /// No description provided for @postTimeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String postTimeDaysAgo(int count);

  /// No description provided for @postTimeWeeksAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}w ago'**
  String postTimeWeeksAgo(int count);

  /// No description provided for @postCaptionHint.
  ///
  /// In en, this message translates to:
  /// **'Write a caption...'**
  String get postCaptionHint;

  /// No description provided for @postMenuEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get postMenuEdit;

  /// No description provided for @postMenuDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get postMenuDelete;

  /// No description provided for @postEditCaptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit caption'**
  String get postEditCaptionTitle;

  /// No description provided for @postEditCaptionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get postEditCaptionSave;

  /// No description provided for @postEditCaptionErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'The change wasn\'t saved. Please try again shortly.'**
  String get postEditCaptionErrorMessage;

  /// No description provided for @postDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this post?'**
  String get postDeleteConfirmTitle;

  /// No description provided for @postDeleteConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get postDeleteConfirmMessage;

  /// No description provided for @postDeleteErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'The post wasn\'t deleted. Please try again shortly.'**
  String get postDeleteErrorMessage;

  /// No description provided for @storyDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this story?'**
  String get storyDeleteConfirmTitle;

  /// No description provided for @storyDeleteConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get storyDeleteConfirmMessage;

  /// No description provided for @storyDeleteErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'The story wasn\'t deleted. Please try again shortly.'**
  String get storyDeleteErrorMessage;

  /// No description provided for @viewActiveStoryButton.
  ///
  /// In en, this message translates to:
  /// **'View story'**
  String get viewActiveStoryButton;

  /// No description provided for @postReplyAction.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get postReplyAction;

  /// No description provided for @postReplyingToLabel.
  ///
  /// In en, this message translates to:
  /// **'Replying to {name}'**
  String postReplyingToLabel(String name);

  /// No description provided for @postCommentDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this comment?'**
  String get postCommentDeleteConfirmTitle;

  /// No description provided for @postCommentDeleteErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'The comment wasn\'t deleted. Please try again shortly.'**
  String get postCommentDeleteErrorMessage;

  /// No description provided for @postCommentEditErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'The comment wasn\'t updated. Please try again shortly.'**
  String get postCommentEditErrorMessage;

  /// No description provided for @postShareOptionsSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get postShareOptionsSheetTitle;

  /// No description provided for @postShareToChatOption.
  ///
  /// In en, this message translates to:
  /// **'Send in chat'**
  String get postShareToChatOption;

  /// No description provided for @postShareExternalOption.
  ///
  /// In en, this message translates to:
  /// **'Share to other apps'**
  String get postShareExternalOption;

  /// No description provided for @postSendToSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Send to'**
  String get postSendToSheetTitle;

  /// No description provided for @postSendToEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have any chats yet'**
  String get postSendToEmptyMessage;

  /// No description provided for @postSentToChatSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Post sent'**
  String get postSentToChatSuccessMessage;

  /// No description provided for @postSentToChatErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'The post wasn\'t sent. Please try again shortly.'**
  String get postSentToChatErrorMessage;

  /// No description provided for @chatPostMessageLabel.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get chatPostMessageLabel;

  /// No description provided for @friendRequestSendButton.
  ///
  /// In en, this message translates to:
  /// **'Add friend'**
  String get friendRequestSendButton;

  /// No description provided for @friendRequestSentLabel.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get friendRequestSentLabel;

  /// No description provided for @friendRequestPendingLabel.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get friendRequestPendingLabel;

  /// No description provided for @friendRequestAcceptedLabel.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get friendRequestAcceptedLabel;

  /// No description provided for @friendRequestDeclinedLabel.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get friendRequestDeclinedLabel;

  /// No description provided for @friendRequestErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send the request. Please try again shortly.'**
  String get friendRequestErrorMessage;

  /// No description provided for @sendMessageButton.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get sendMessageButton;

  /// No description provided for @followButton.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get followButton;

  /// No description provided for @followingButton.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get followingButton;

  /// No description provided for @followErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again shortly.'**
  String get followErrorMessage;

  /// No description provided for @profileStatsFollowing.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get profileStatsFollowing;

  /// No description provided for @profileStatsFollowers.
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get profileStatsFollowers;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsLanguageRowLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageRowLabel;

  /// No description provided for @languagePickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose language'**
  String get languagePickerTitle;

  /// No description provided for @settingsAccountRowTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccountRowTitle;

  /// No description provided for @settingsAccountRowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Personal info, phone, email, password'**
  String get settingsAccountRowSubtitle;

  /// No description provided for @changePhotoScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Change profile photo'**
  String get changePhotoScreenTitle;

  /// No description provided for @settingsChangePhotoRowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Update or remove your profile photo'**
  String get settingsChangePhotoRowSubtitle;

  /// No description provided for @settingsPrivacyRowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Visibility, blocks, active devices and more'**
  String get settingsPrivacyRowSubtitle;

  /// No description provided for @settingsNotificationsRowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Messages, push notifications'**
  String get settingsNotificationsRowSubtitle;

  /// No description provided for @settingsLanguageRowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get settingsLanguageRowSubtitle;

  /// No description provided for @settingsIdentityRowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your identity, earn a trusted badge'**
  String get settingsIdentityRowSubtitle;

  /// No description provided for @settingsVipRowTitle.
  ///
  /// In en, this message translates to:
  /// **'Meevima VIP'**
  String get settingsVipRowTitle;

  /// No description provided for @settingsVipRowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Go VIP, manage your plan'**
  String get settingsVipRowSubtitle;

  /// No description provided for @settingsVipActiveLabel.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get settingsVipActiveLabel;

  /// No description provided for @settingsVipBadgeLabel.
  ///
  /// In en, this message translates to:
  /// **'VIP'**
  String get settingsVipBadgeLabel;

  /// No description provided for @settingsMapRowTitle.
  ///
  /// In en, this message translates to:
  /// **'Map & Location'**
  String get settingsMapRowTitle;

  /// No description provided for @settingsMapRowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Map type, distance unit, GPS'**
  String get settingsMapRowSubtitle;

  /// No description provided for @settingsPaymentsRowTitle.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get settingsPaymentsRowTitle;

  /// No description provided for @settingsPaymentsRowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Payment history, cards, subscription'**
  String get settingsPaymentsRowSubtitle;

  /// No description provided for @settingsHelpRowTitle.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get settingsHelpRowTitle;

  /// No description provided for @settingsHelpRowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'FAQ, contact us, report a problem'**
  String get settingsHelpRowSubtitle;

  /// No description provided for @settingsLegalRowTitle.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get settingsLegalRowTitle;

  /// No description provided for @settingsLegalRowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy, terms of use'**
  String get settingsLegalRowSubtitle;

  /// No description provided for @settingsAboutRowTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAboutRowTitle;

  /// No description provided for @settingsAboutRowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Version, what\'s new, social media'**
  String get settingsAboutRowSubtitle;

  /// No description provided for @settingsLogoutRowTitle.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get settingsLogoutRowTitle;

  /// No description provided for @settingsLogoutRowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out of your account'**
  String get settingsLogoutRowSubtitle;

  /// No description provided for @notificationsScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsScreenTitle;

  /// No description provided for @notifMessagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get notifMessagesTitle;

  /// No description provided for @notifMessagesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get notified about new messages'**
  String get notifMessagesSubtitle;

  /// No description provided for @notifFollowersTitle.
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get notifFollowersTitle;

  /// No description provided for @notifFollowersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'New followers and follow requests'**
  String get notifFollowersSubtitle;

  /// No description provided for @notifNewUsersTitle.
  ///
  /// In en, this message translates to:
  /// **'New users'**
  String get notifNewUsersTitle;

  /// No description provided for @notifNewUsersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When a new user joins nearby'**
  String get notifNewUsersSubtitle;

  /// No description provided for @notifLikesTitle.
  ///
  /// In en, this message translates to:
  /// **'Likes'**
  String get notifLikesTitle;

  /// No description provided for @notifLikesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get notified when someone likes you'**
  String get notifLikesSubtitle;

  /// No description provided for @notifCommentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get notifCommentsTitle;

  /// No description provided for @notifCommentsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get notified about comments and reactions'**
  String get notifCommentsSubtitle;

  /// No description provided for @notifVenueOffersTitle.
  ///
  /// In en, this message translates to:
  /// **'Venue offers'**
  String get notifVenueOffersTitle;

  /// No description provided for @notifVenueOffersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'New offers from venues you follow'**
  String get notifVenueOffersSubtitle;

  /// No description provided for @notifVenueUpdatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Venue updates'**
  String get notifVenueUpdatesTitle;

  /// No description provided for @notifVenueUpdatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Venue additions and verifications'**
  String get notifVenueUpdatesSubtitle;

  /// No description provided for @notifSecurityTitle.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get notifSecurityTitle;

  /// No description provided for @notifSecuritySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Important security alerts about your account'**
  String get notifSecuritySubtitle;

  /// No description provided for @notifSystemTitle.
  ///
  /// In en, this message translates to:
  /// **'System notifications'**
  String get notifSystemTitle;

  /// No description provided for @notifSystemSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Important announcements about the app'**
  String get notifSystemSubtitle;

  /// No description provided for @notifMarketingTitle.
  ///
  /// In en, this message translates to:
  /// **'Marketing'**
  String get notifMarketingTitle;

  /// No description provided for @notifMarketingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Stay updated on campaigns and discounts'**
  String get notifMarketingSubtitle;

  /// No description provided for @notifPushTitle.
  ///
  /// In en, this message translates to:
  /// **'Push notifications'**
  String get notifPushTitle;

  /// No description provided for @notifEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Email notifications'**
  String get notifEmailTitle;

  /// No description provided for @notifUpdateErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'The change wasn\'t saved. Please try again shortly.'**
  String get notifUpdateErrorMessage;

  /// No description provided for @mapLocationScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Map & Location'**
  String get mapLocationScreenTitle;

  /// No description provided for @mapTypeTitle.
  ///
  /// In en, this message translates to:
  /// **'Map type'**
  String get mapTypeTitle;

  /// No description provided for @mapTypeStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get mapTypeStandard;

  /// No description provided for @mapTypeSatellite.
  ///
  /// In en, this message translates to:
  /// **'Satellite'**
  String get mapTypeSatellite;

  /// No description provided for @mapTypeHybrid.
  ///
  /// In en, this message translates to:
  /// **'Hybrid'**
  String get mapTypeHybrid;

  /// No description provided for @distanceUnitTitle.
  ///
  /// In en, this message translates to:
  /// **'Distance unit'**
  String get distanceUnitTitle;

  /// No description provided for @distanceUnitKm.
  ///
  /// In en, this message translates to:
  /// **'Kilometers'**
  String get distanceUnitKm;

  /// No description provided for @distanceUnitMi.
  ///
  /// In en, this message translates to:
  /// **'Miles'**
  String get distanceUnitMi;

  /// No description provided for @gpsAccuracyTitle.
  ///
  /// In en, this message translates to:
  /// **'GPS accuracy'**
  String get gpsAccuracyTitle;

  /// No description provided for @gpsAccuracyHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get gpsAccuracyHigh;

  /// No description provided for @gpsAccuracyStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get gpsAccuracyStandard;

  /// No description provided for @backgroundLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Background location'**
  String get backgroundLocationTitle;

  /// No description provided for @backgroundLocationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep your location updated while the app is in the background'**
  String get backgroundLocationSubtitle;

  /// No description provided for @backgroundLocationDeniedMessage.
  ///
  /// In en, this message translates to:
  /// **'To enable background location, choose \"Allow all the time\" in Settings > Apps.'**
  String get backgroundLocationDeniedMessage;

  /// No description provided for @mapLocationUpdateErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'The change wasn\'t saved. Please try again shortly.'**
  String get mapLocationUpdateErrorMessage;

  /// No description provided for @helpScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get helpScreenTitle;

  /// No description provided for @helpFaqSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Frequently asked questions'**
  String get helpFaqSectionTitle;

  /// No description provided for @helpFaq1Question.
  ///
  /// In en, this message translates to:
  /// **'How does Meevima work?'**
  String get helpFaq1Question;

  /// No description provided for @helpFaq1Answer.
  ///
  /// In en, this message translates to:
  /// **'The app uses your location to show you other nearby users. You can choose the radius and filters from the Discover tab.'**
  String get helpFaq1Answer;

  /// No description provided for @helpFaq2Question.
  ///
  /// In en, this message translates to:
  /// **'Who can see my location?'**
  String get helpFaq2Question;

  /// No description provided for @helpFaq2Answer.
  ///
  /// In en, this message translates to:
  /// **'Only your approximate distance is shown to other users, never your exact coordinates. Turn on Ghost Mode under Settings > Privacy & Security to hide completely.'**
  String get helpFaq2Answer;

  /// No description provided for @helpFaq3Question.
  ///
  /// In en, this message translates to:
  /// **'How do I delete my account?'**
  String get helpFaq3Question;

  /// No description provided for @helpFaq3Answer.
  ///
  /// In en, this message translates to:
  /// **'Go to Settings > Account > Delete my account to permanently remove your account. This action cannot be undone.'**
  String get helpFaq3Answer;

  /// No description provided for @helpFaq4Question.
  ///
  /// In en, this message translates to:
  /// **'What should I do if someone is bothering me?'**
  String get helpFaq4Question;

  /// No description provided for @helpFaq4Answer.
  ///
  /// In en, this message translates to:
  /// **'You can block or report that user from their profile at any time. A blocked user will no longer be able to see you.'**
  String get helpFaq4Answer;

  /// No description provided for @helpFaq5Question.
  ///
  /// In en, this message translates to:
  /// **'What is Meevima VIP for?'**
  String get helpFaq5Question;

  /// No description provided for @helpFaq5Answer.
  ///
  /// In en, this message translates to:
  /// **'VIP membership unlocks an extended visibility radius, Ghost Mode, and extra filters.'**
  String get helpFaq5Answer;

  /// No description provided for @helpFaq6Question.
  ///
  /// In en, this message translates to:
  /// **'How do I change my visibility radius?'**
  String get helpFaq6Question;

  /// No description provided for @helpFaq6Answer.
  ///
  /// In en, this message translates to:
  /// **'Use the radius picker below the map on the Discover tab to choose the distance you want.'**
  String get helpFaq6Answer;

  /// No description provided for @helpContactRowTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact us'**
  String get helpContactRowTitle;

  /// No description provided for @helpContactRowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get in touch with any questions'**
  String get helpContactRowSubtitle;

  /// No description provided for @helpReportProblemRowTitle.
  ///
  /// In en, this message translates to:
  /// **'Report a problem'**
  String get helpReportProblemRowTitle;

  /// No description provided for @helpReportProblemRowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Let us know about a technical issue'**
  String get helpReportProblemRowSubtitle;

  /// No description provided for @helpSendSuggestionRowTitle.
  ///
  /// In en, this message translates to:
  /// **'Send a suggestion'**
  String get helpSendSuggestionRowTitle;

  /// No description provided for @helpSendSuggestionRowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How can we make the app better?'**
  String get helpSendSuggestionRowSubtitle;

  /// No description provided for @contactUsSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact us'**
  String get contactUsSheetTitle;

  /// No description provided for @contactUsEmailCopiedNotice.
  ///
  /// In en, this message translates to:
  /// **'Email address copied'**
  String get contactUsEmailCopiedNotice;

  /// No description provided for @contactUsSendEmailButton.
  ///
  /// In en, this message translates to:
  /// **'Send email'**
  String get contactUsSendEmailButton;

  /// No description provided for @reportProblemSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Report a problem'**
  String get reportProblemSheetTitle;

  /// No description provided for @sendSuggestionSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Send a suggestion'**
  String get sendSuggestionSheetTitle;

  /// No description provided for @supportMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Write your message here...'**
  String get supportMessageHint;

  /// No description provided for @supportMessageSendButton.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get supportMessageSendButton;

  /// No description provided for @supportMessageSentNotice.
  ///
  /// In en, this message translates to:
  /// **'Your message was sent. Thank you!'**
  String get supportMessageSentNotice;

  /// No description provided for @supportMessageErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'The message wasn\'t sent. Please try again shortly.'**
  String get supportMessageErrorMessage;

  /// No description provided for @legalPrivacyPolicyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get legalPrivacyPolicyTitle;

  /// No description provided for @legalTermsOfServiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get legalTermsOfServiceTitle;

  /// No description provided for @legalLicensesTitle.
  ///
  /// In en, this message translates to:
  /// **'Licenses'**
  String get legalLicensesTitle;

  /// No description provided for @aboutWhatsNewTitle.
  ///
  /// In en, this message translates to:
  /// **'What\'s new'**
  String get aboutWhatsNewTitle;

  /// No description provided for @aboutSocialMediaTitle.
  ///
  /// In en, this message translates to:
  /// **'Social media'**
  String get aboutSocialMediaTitle;

  /// No description provided for @aboutSocialMediaComingSoonLabel.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get aboutSocialMediaComingSoonLabel;

  /// No description provided for @aboutCopyrightText.
  ///
  /// In en, this message translates to:
  /// **'© 2026 Meevima. All rights reserved.'**
  String get aboutCopyrightText;

  /// No description provided for @aboutChangelogV1Title.
  ///
  /// In en, this message translates to:
  /// **'v1.0.0'**
  String get aboutChangelogV1Title;

  /// No description provided for @aboutChangelogV1Body.
  ///
  /// In en, this message translates to:
  /// **'First release: discover nearby users, friend requests, chats, stories, and profile management.'**
  String get aboutChangelogV1Body;

  /// No description provided for @vipHeaderTitle.
  ///
  /// In en, this message translates to:
  /// **'Meevima VIP'**
  String get vipHeaderTitle;

  /// No description provided for @vipHeaderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Meet more people with expanded features'**
  String get vipHeaderSubtitle;

  /// No description provided for @vipChoosePackageTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a package'**
  String get vipChoosePackageTitle;

  /// No description provided for @vipPeriodMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get vipPeriodMonthly;

  /// No description provided for @vipPeriodQuarterly.
  ///
  /// In en, this message translates to:
  /// **'3 Months'**
  String get vipPeriodQuarterly;

  /// No description provided for @vipPeriodYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get vipPeriodYearly;

  /// No description provided for @vipBestValueBadge.
  ///
  /// In en, this message translates to:
  /// **'Best value'**
  String get vipBestValueBadge;

  /// No description provided for @vipPriceComingSoonNote.
  ///
  /// In en, this message translates to:
  /// **'Prices will appear here once the store connection is live.'**
  String get vipPriceComingSoonNote;

  /// No description provided for @vipSubscribeButton.
  ///
  /// In en, this message translates to:
  /// **'Subscribe'**
  String get vipSubscribeButton;

  /// No description provided for @vipAlreadySubscribedButton.
  ///
  /// In en, this message translates to:
  /// **'You\'re already VIP'**
  String get vipAlreadySubscribedButton;

  /// No description provided for @vipBillingComingSoonMessage.
  ///
  /// In en, this message translates to:
  /// **'Billing will be enabled soon.'**
  String get vipBillingComingSoonMessage;

  /// No description provided for @vipCurrentPackageTitle.
  ///
  /// In en, this message translates to:
  /// **'Current package'**
  String get vipCurrentPackageTitle;

  /// No description provided for @vipCurrentPackageActiveLabel.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get vipCurrentPackageActiveLabel;

  /// No description provided for @vipManageButton.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get vipManageButton;

  /// No description provided for @vipFeatureGhostTitle.
  ///
  /// In en, this message translates to:
  /// **'Ghost Mode'**
  String get vipFeatureGhostTitle;

  /// No description provided for @vipFeatureGhostDescription.
  ///
  /// In en, this message translates to:
  /// **'See other users without appearing on the map yourself.'**
  String get vipFeatureGhostDescription;

  /// No description provided for @vipFeatureRadiusTitle.
  ///
  /// In en, this message translates to:
  /// **'Extended radius'**
  String get vipFeatureRadiusTitle;

  /// No description provided for @vipFeatureRadiusDescription.
  ///
  /// In en, this message translates to:
  /// **'Discover people within a 5 km or 10 km radius.'**
  String get vipFeatureRadiusDescription;

  /// No description provided for @vipFeatureFilterTitle.
  ///
  /// In en, this message translates to:
  /// **'Extra filters'**
  String get vipFeatureFilterTitle;

  /// No description provided for @vipFeatureFilterDescription.
  ///
  /// In en, this message translates to:
  /// **'Narrow your search with gender and other filters.'**
  String get vipFeatureFilterDescription;

  /// No description provided for @accountScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountScreenTitle;

  /// No description provided for @accountPersonalInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Personal info'**
  String get accountPersonalInfoTitle;

  /// No description provided for @accountPhoneRowTitle.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get accountPhoneRowTitle;

  /// No description provided for @accountEmailRowTitle.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get accountEmailRowTitle;

  /// No description provided for @accountEmailEmptyValue.
  ///
  /// In en, this message translates to:
  /// **'Not added'**
  String get accountEmailEmptyValue;

  /// No description provided for @accountPasswordRowTitle.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get accountPasswordRowTitle;

  /// No description provided for @accountPhoneUnsetValue.
  ///
  /// In en, this message translates to:
  /// **'Not verified'**
  String get accountPhoneUnsetValue;

  /// No description provided for @accountChangeEmailSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Change email'**
  String get accountChangeEmailSheetTitle;

  /// No description provided for @accountNewEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'New email address'**
  String get accountNewEmailLabel;

  /// No description provided for @accountEmailInvalidError.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get accountEmailInvalidError;

  /// No description provided for @accountEmailUpdatedNotice.
  ///
  /// In en, this message translates to:
  /// **'Email updated'**
  String get accountEmailUpdatedNotice;

  /// No description provided for @accountDeleteRowTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get accountDeleteRowTitle;

  /// No description provided for @accountDeleteRowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account and all your data'**
  String get accountDeleteRowSubtitle;

  /// No description provided for @accountDeleteConfirmWordLabel.
  ///
  /// In en, this message translates to:
  /// **'Type \"DELETE\" below to confirm'**
  String get accountDeleteConfirmWordLabel;

  /// No description provided for @accountDeleteConfirmWordHint.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get accountDeleteConfirmWordHint;

  /// No description provided for @accountDeleteConfirmWordMismatchError.
  ///
  /// In en, this message translates to:
  /// **'Type \"DELETE\" exactly to continue'**
  String get accountDeleteConfirmWordMismatchError;

  /// No description provided for @paymentsScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get paymentsScreenTitle;

  /// No description provided for @paymentHistoryRowTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment history'**
  String get paymentHistoryRowTitle;

  /// No description provided for @myCardsTitle.
  ///
  /// In en, this message translates to:
  /// **'My cards'**
  String get myCardsTitle;

  /// No description provided for @addCardButton.
  ///
  /// In en, this message translates to:
  /// **'Add card'**
  String get addCardButton;

  /// No description provided for @noCardsMessage.
  ///
  /// In en, this message translates to:
  /// **'No cards added yet'**
  String get noCardsMessage;

  /// No description provided for @cardOptionsSetDefault.
  ///
  /// In en, this message translates to:
  /// **'Set as default'**
  String get cardOptionsSetDefault;

  /// No description provided for @cardOptionsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get cardOptionsDelete;

  /// No description provided for @paymentHistoryEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get paymentHistoryEmptyMessage;

  /// No description provided for @paymentTypePurchase.
  ///
  /// In en, this message translates to:
  /// **'Purchase'**
  String get paymentTypePurchase;

  /// No description provided for @paymentTypeRenewal.
  ///
  /// In en, this message translates to:
  /// **'Renewal'**
  String get paymentTypeRenewal;

  /// No description provided for @paymentTypeCancellation.
  ///
  /// In en, this message translates to:
  /// **'Cancellation'**
  String get paymentTypeCancellation;

  /// No description provided for @paymentTypeRefund.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get paymentTypeRefund;

  /// No description provided for @activeDevicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Active devices'**
  String get activeDevicesTitle;

  /// No description provided for @privacyActiveDevicesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'List of your active devices'**
  String get privacyActiveDevicesSubtitle;

  /// No description provided for @activeDevicesEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'No active devices found'**
  String get activeDevicesEmptyMessage;

  /// No description provided for @thisDeviceLabel.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get thisDeviceLabel;

  /// No description provided for @lastActiveLabel.
  ///
  /// In en, this message translates to:
  /// **'Last active'**
  String get lastActiveLabel;

  /// No description provided for @signOutDeviceButton.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOutDeviceButton;

  /// No description provided for @signOutDeviceConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out this device?'**
  String get signOutDeviceConfirmTitle;

  /// No description provided for @signOutDeviceConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This device will be signed out remotely. If it\'s offline, it\'ll be signed out the next time it connects.'**
  String get signOutDeviceConfirmMessage;

  /// No description provided for @signOutDeviceErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t sign out. Please try again shortly.'**
  String get signOutDeviceErrorMessage;

  /// No description provided for @privacyTwoFactorActivateTitle.
  ///
  /// In en, this message translates to:
  /// **'Activate two-factor authentication'**
  String get privacyTwoFactorActivateTitle;

  /// No description provided for @privacyTwoFactorDisableButton.
  ///
  /// In en, this message translates to:
  /// **'Turn off'**
  String get privacyTwoFactorDisableButton;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['az', 'en', 'ru', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'az': return AppLocalizationsAz();
    case 'en': return AppLocalizationsEn();
    case 'ru': return AppLocalizationsRu();
    case 'tr': return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
