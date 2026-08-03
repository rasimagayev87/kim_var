// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get welcomeSubtitle => 'Discover people around you,\nmake new connections and friendships.';

  @override
  String get welcomeStartButton => 'Start';

  @override
  String get loginTitle => 'Log in';

  @override
  String get loginUsernameLabel => 'Username';

  @override
  String get loginUsernameHint => 'username';

  @override
  String get loginPasswordLabel => 'Password';

  @override
  String get loginPasswordHint => '••••••••';

  @override
  String get loginButtonLabel => 'Log in';

  @override
  String get loginRegisterButtonLabel => 'Sign up';

  @override
  String get loginForgotPasswordLabel => 'Forgot password?';

  @override
  String get loginAccountNotFoundError => 'No account found with these details.';

  @override
  String get loginTooManyAttemptsError => 'Too many failed attempts. Try again shortly, or reset your password via \"Forgot password\".';

  @override
  String get loginNetworkError => 'No internet connection. Check your connection and try again.';

  @override
  String get loginRegisterPromptLabel => 'Want to create an account?';

  @override
  String get registerTitle => 'Sign up';

  @override
  String get registerUsernameLabel => 'Username';

  @override
  String get registerUsernameHint => 'username';

  @override
  String get registerUsernameCheckingLabel => 'Checking...';

  @override
  String get registerUsernameTakenError => 'This username is already taken.';

  @override
  String get registerUsernameInvalidFormatError => 'Username may only contain letters, numbers, . and _ (3-20 characters).';

  @override
  String get registerPasswordLabel => 'Password';

  @override
  String get registerPasswordHint => 'At least 8 characters';

  @override
  String get registerPasswordConfirmLabel => 'Confirm password';

  @override
  String get registerPasswordConfirmHint => 'Re-enter your password';

  @override
  String get registerPasswordTooShortError => 'Password must be at least 8 characters.';

  @override
  String get registerPasswordMismatchError => 'Passwords don\'t match.';

  @override
  String get registerSubmitButton => 'Complete registration';

  @override
  String get registerGenericError => 'Registration failed. Please try again shortly.';

  @override
  String get registerSuccessMessage => 'Registration complete — you can now log in.';

  @override
  String get phoneAuthTitle => 'Your phone number';

  @override
  String get phoneAuthSubtitle => 'You\'ll need the code sent to you by SMS.';

  @override
  String get phoneAuthNumberHint => '50 123 45 67';

  @override
  String get phoneAuthContinueButton => 'Continue with phone number';

  @override
  String get phoneAuthInvalidNumberError => 'Enter a valid phone number';

  @override
  String get phoneAuthVerificationFailedError => 'Couldn\'t verify the number, try again.';

  @override
  String get pickCountryTitle => 'Choose country';

  @override
  String get otpTitle => 'Enter the code';

  @override
  String otpSubtitle(String phone) {
    return 'Enter the 6-digit code sent to $phone.';
  }

  @override
  String get otpCodeHint => '••••••';

  @override
  String get otpConfirmButton => 'Confirm';

  @override
  String get otpIncompleteCodeError => 'Enter the full 6-digit code';

  @override
  String get otpInvalidCodeError => 'The code is wrong or has expired.';

  @override
  String get otpResendButton => 'Resend code';

  @override
  String otpResendWaitLabel(String time) {
    return 'Resend in: $time';
  }

  @override
  String get verificationRequiredTitle => 'Verify your account';

  @override
  String get verificationRequiredMessage => 'You need to verify your account before using this feature.';

  @override
  String get verificationRequiredButton => 'Verify account';

  @override
  String get accountVerificationTitle => 'Verify your account';

  @override
  String get accountVerificationSubtitle => 'Verify your phone number to unlock every feature.';

  @override
  String get accountVerificationPhoneTakenError => 'This phone number is already used by another account.';

  @override
  String get accountVerificationSuccessMessage => 'Your account is verified.';

  @override
  String get settingsAccountVerificationRowTitle => 'Verify account';

  @override
  String get settingsAccountVerifiedRowSubtitle => 'Your account is verified';

  @override
  String get settingsIdentityVerificationRowTitle => 'Identity verification';

  @override
  String get swipeMatchedMessage => 'You matched with this user!';

  @override
  String get swipeErrorMessage => 'Something went wrong. Please try again shortly.';

  @override
  String get forgotPasswordTitle => 'Forgot password';

  @override
  String get forgotPasswordSubtitle => 'Enter the phone number linked to your account.';

  @override
  String get forgotPasswordAccountNotFoundError => 'No account found with this phone number.';

  @override
  String get newPasswordTitle => 'New password';

  @override
  String get newPasswordSubtitle => 'Set a new password for your account.';

  @override
  String get newPasswordLabel => 'New password';

  @override
  String get newPasswordHint => 'At least 8 characters';

  @override
  String get newPasswordConfirmLabel => 'Confirm new password';

  @override
  String get newPasswordConfirmHint => 'Re-enter your password';

  @override
  String get newPasswordSubmitButton => 'Update password';

  @override
  String get newPasswordSuccessMessage => 'Your password has been updated — you can log in now.';

  @override
  String get newPasswordGenericError => 'The password wasn\'t updated. Please try again shortly.';

  @override
  String get changePasswordTitle => 'Change password';

  @override
  String get changePasswordCurrentLabel => 'Current password';

  @override
  String get changePasswordCurrentHint => 'Enter your current password';

  @override
  String get changePasswordNewLabel => 'New password';

  @override
  String get changePasswordNewHint => 'At least 8 characters';

  @override
  String get changePasswordConfirmLabel => 'Confirm new password';

  @override
  String get changePasswordConfirmHint => 'Re-enter your password';

  @override
  String get changePasswordSubmitButton => 'Update password';

  @override
  String get changePasswordWrongCurrentError => 'The current password is wrong.';

  @override
  String get changePasswordSuccessMessage => 'Your password has been updated.';

  @override
  String get changePasswordGenericError => 'The password wasn\'t changed. Please try again shortly.';

  @override
  String get onboardingAppBarTitle => 'Complete your profile';

  @override
  String get onboardingPhotoOptionalLabel => 'Add a photo (optional)';

  @override
  String get fieldFirstNameLabel => 'First name';

  @override
  String get fieldFirstNameHint => 'Rasim';

  @override
  String get fieldFirstNameRequiredError => 'Enter your first name';

  @override
  String get fieldLastNameLabel => 'Last name';

  @override
  String get fieldLastNameHint => 'Mammadov';

  @override
  String get fieldLastNameRequiredError => 'Enter your last name';

  @override
  String get fieldBirthDateLabel => 'Date of birth';

  @override
  String get fieldBirthDateHint => 'dd.mm.yyyy';

  @override
  String get birthDatePickerHelpText => 'Select your date of birth';

  @override
  String get fieldGenderLabel => 'Gender';

  @override
  String get sectionCountryCityTitle => 'Country and city';

  @override
  String get sectionAboutOptionalTitle => 'About you (optional)';

  @override
  String get bioHintOnboarding => 'A few sentences about yourself...';

  @override
  String get onboardingFinishButton => 'Finish and continue';

  @override
  String get onboardingSelectBirthDateError => 'Select your date of birth';

  @override
  String get onboardingSelectGenderError => 'Select your gender';

  @override
  String get onboardingSelectCountryCityError => 'Select your country and city';

  @override
  String get onboardingPhotoUploadFailedError => 'The photo couldn\'t be uploaded — you can add it later from your profile.';

  @override
  String errorWithDetails(String error) {
    return 'Something went wrong: $error';
  }

  @override
  String get navDiscoverLabel => 'Discover';

  @override
  String get navChatsLabel => 'Chat';

  @override
  String get navFeedLabel => 'Feed';

  @override
  String get navNotificationsLabel => 'Notifications';

  @override
  String get navProfileLabel => 'Profile';

  @override
  String get notificationsFeedTitle => 'Notifications';

  @override
  String get notifMenuMarkAllRead => 'Mark all as read';

  @override
  String get notifMenuDeleteRead => 'Delete read notifications';

  @override
  String get notifMenuSettings => 'Notification settings';

  @override
  String get notifEmptyTitle => 'No notifications';

  @override
  String get notifEmptySubtitle => 'New notifications will show up here.';

  @override
  String get notifErrorOfflineTitle => 'No internet connection';

  @override
  String get notifErrorOfflineMessage => 'Connect to the internet to load notifications.';

  @override
  String get notifErrorPermissionTitle => 'No permission';

  @override
  String get notifErrorPermissionMessage => 'You don\'t have permission to view these notifications.';

  @override
  String get notifErrorUnknownTitle => 'Something went wrong';

  @override
  String get notifErrorUnknownMessage => 'Notifications couldn\'t be loaded. Try again shortly.';

  @override
  String get notifMarkAllReadDone => 'All notifications marked as read';

  @override
  String get notifDeleteReadDone => 'Read notifications deleted';

  @override
  String get notifActionErrorMessage => 'Something went wrong. Try again shortly.';

  @override
  String get discoverTitle => 'Discover';

  @override
  String get viewSwitcherPeopleLabel => 'People';

  @override
  String get viewSwitcherPlacesLabel => 'Places';

  @override
  String get viewSwitcherOffersLabel => 'Offers';

  @override
  String get genderFilterAll => 'Everyone';

  @override
  String get genderFilterMale => 'Men';

  @override
  String get genderFilterFemale => 'Women';

  @override
  String get genderFilterTooltip => 'Filter';

  @override
  String get genderFilterSheetTitle => 'Filter by gender';

  @override
  String get locationSearchingTitle => 'Finding your location...';

  @override
  String get locationSearchingSubtitle => 'This can take a few seconds.';

  @override
  String get locationServiceDisabledTitle => 'Location services are off';

  @override
  String get locationServiceDisabledSubtitle => 'Turn on location on your device to see people nearby.';

  @override
  String get actionOpenSettings => 'Open settings';

  @override
  String get locationPermissionDeniedTitle => 'Location permission needed';

  @override
  String get locationPermissionDeniedSubtitle => 'Grant permission to see people around you.';

  @override
  String get actionRetry => 'Try again';

  @override
  String get chatPermissionDeniedMessage => 'You don\'t have access to this conversation right now. Try signing out and back in, or try again shortly.';

  @override
  String get chatLoadErrorMessage => 'Something went wrong loading this. Please try again.';

  @override
  String get locationPermissionDeniedForeverTitle => 'Permission permanently denied';

  @override
  String get locationPermissionDeniedForeverSubtitle => 'Manually enable location permission for \"Meevima\" in your phone\'s settings.';

  @override
  String get actionOpenAppSettings => 'Open app settings';

  @override
  String get errorTitle => 'Something went wrong';

  @override
  String get meMarkerLabel => 'You are here';

  @override
  String get defaultUserName => 'User';

  @override
  String get startChatButton => 'Start chatting';

  @override
  String get viewProfileButton => 'View profile';

  @override
  String get chatMessageHint => 'Message...';

  @override
  String get chatRequestSentNotice => 'Message request sent';

  @override
  String get chatRequestBannerTitle => 'Message request';

  @override
  String get chatRequestBannerSubtitle => 'Accept to start chatting with each other.';

  @override
  String get chatRequestAcceptButton => 'Accept';

  @override
  String get chatRequestDeclineButton => 'Decline';

  @override
  String get chatRequestPendingNotice => 'Waiting for them to accept your message request.';

  @override
  String get chatRequestDeclinedNotice => 'This message request was declined.';

  @override
  String get chatRequestDeclinedByPeerNotice => 'This user declined your message request.';

  @override
  String get chatRequestActionErrorMessage => 'That didn\'t go through. Please try again in a moment.';

  @override
  String get chatOnlineStatus => 'Online';

  @override
  String get chatLastSeenUnknown => 'Offline';

  @override
  String chatLastSeenAt(String time) {
    return 'Last seen: $time';
  }

  @override
  String get chatTypingIndicator => 'typing...';

  @override
  String get chatDateToday => 'Today';

  @override
  String get chatDateYesterday => 'Yesterday';

  @override
  String get chatMenuViewProfile => 'View profile';

  @override
  String get chatMenuBlock => 'Block user';

  @override
  String get chatMenuUnblock => 'Unblock';

  @override
  String get chatUserUnblockedNotice => 'User unblocked.';

  @override
  String get chatMenuReport => 'Report user';

  @override
  String get chatMenuDeleteChat => 'Delete chat';

  @override
  String get chatBlockConfirmTitle => 'Block this user?';

  @override
  String get chatBlockConfirmMessage => 'They won\'t be able to message you anymore.';

  @override
  String get chatDeleteConfirmTitle => 'Delete this chat?';

  @override
  String get chatDeleteConfirmMessage => 'This conversation will be permanently deleted.';

  @override
  String get chatReportTitle => 'Report user';

  @override
  String get chatReportReasonHint => 'Describe the issue...';

  @override
  String get chatReportSubmitButton => 'Submit report';

  @override
  String get chatReportSentNotice => 'Report submitted, thank you.';

  @override
  String get chatReportReasonInappropriate => 'Inappropriate content';

  @override
  String get chatReportReasonFakeProfile => 'Fake profile';

  @override
  String get chatReportReasonDangerous => 'Dangerous behavior';

  @override
  String get chatReportReasonOther => 'Other';

  @override
  String get chatSendBlockedError => 'You can\'t send a message to this user.';

  @override
  String get chatUserBlockedNotice => 'User blocked.';

  @override
  String get chatEmptyConversation => 'Say hello 👋';

  @override
  String get chatEmptyStateTitle => 'Send the first message';

  @override
  String get chatEmptyStateSubtitle => 'Start the conversation by writing below, or break the ice with a hello.';

  @override
  String get chatEmptyStateGreetingButton => 'Hi 👋';

  @override
  String get chatVoiceComingSoonMessage => 'Voice messages are coming soon.';

  @override
  String get chatEmojiPickerTitle => 'Pick an emoji';

  @override
  String get chatImageMessageLabel => 'Photo';

  @override
  String get chatVideoMessageLabel => 'Video';

  @override
  String get chatAudioMessageLabel => 'Voice message';

  @override
  String get chatSendButton => 'Send';

  @override
  String get chatRetakeButton => 'Retake';

  @override
  String get chatAttachmentSheetTitle => 'Choose media';

  @override
  String get chatAttachmentImageOption => 'Photo';

  @override
  String get chatAttachmentVideoOption => 'Video';

  @override
  String get chatRecordingCancelHint => 'Slide to cancel';

  @override
  String get chatRecordingLockHint => 'Slide up to lock';

  @override
  String get chatVoiceFinishButton => 'Finish';

  @override
  String get chatVoiceTooShortMessage => 'Voice message too short';

  @override
  String get chatMicPermissionDeniedMessage => 'Microphone access is needed to send voice messages.';

  @override
  String get chatCameraPermissionDeniedMessage => 'Camera access is needed to take a photo.';

  @override
  String get chatMediaUploadFailedMessage => 'Failed to send';

  @override
  String get chatMediaTooLargeMessage => 'File is too large.';

  @override
  String get chatCallComingSoonMessage => 'Calling is coming soon.';

  @override
  String get chatVoiceCallLabel => 'Voice call';

  @override
  String get chatVideoCallLabel => 'Video call';

  @override
  String get chatMessageDeleteForMeOption => 'Delete for me';

  @override
  String get chatMessageDeleteForEveryoneOption => 'Delete for everyone';

  @override
  String get chatMessageDeleteForEveryoneConfirmMessage => 'This message will be permanently deleted for both sides.';

  @override
  String get chatMessageDeleteOption => 'Delete';

  @override
  String get chatMessageForwardOption => 'Forward';

  @override
  String get chatForwardTitle => 'Forward';

  @override
  String get chatForwardEmptyMessage => 'You have no chats to forward to.';

  @override
  String chatForwardSendButton(int count) {
    return 'Send ($count)';
  }

  @override
  String get chatForwardSuccessMessage => 'Message forwarded.';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionDelete => 'Delete';

  @override
  String distanceMetersAway(int meters) {
    return '$meters m away';
  }

  @override
  String distanceKmAway(String km) {
    return '$km km away';
  }

  @override
  String distanceMilesAway(String mi) {
    return '$mi mi away';
  }

  @override
  String radiusPeopleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '$count person',
    );
    return '$_temp0';
  }

  @override
  String get radiusMoreButtonLabel => 'More';

  @override
  String get radiusMorePanelTitle => 'Search radius';

  @override
  String get premiumUpsellRadiusTitle => 'Discover people further away 🌍';

  @override
  String get premiumUpsellRadiusMessage => 'With Premium you can see people within 5 km and 10 km, and meet more people.';

  @override
  String get premiumUpgradeButton => 'Upgrade to Premium';

  @override
  String get premiumLaterButton => 'Later';

  @override
  String get premiumComingSoonTitle => 'Premium';

  @override
  String get premiumComingSoonMessage => 'Premium membership will be available soon.';

  @override
  String get chatsTitle => 'Chats';

  @override
  String get chatsEmptyTitle => 'No chats yet';

  @override
  String get chatsEmptySubtitle => 'Your chats will appear here once you meet people around you.';

  @override
  String get chatsSearchHint => 'Search chats';

  @override
  String get chatsSearchEmptyTitle => 'No results found';

  @override
  String get chatsSearchEmptySubtitle => 'Try a different name, username, or word.';

  @override
  String get chatsFilterAll => 'All';

  @override
  String get chatsFilterUnread => 'Unread';

  @override
  String get chatsFilterArchived => 'Archived';

  @override
  String get chatsFilterRequests => 'Requests';

  @override
  String get chatsUnreadEmptyTitle => 'No unread messages';

  @override
  String get chatsUnreadEmptySubtitle => 'All messages have been read.';

  @override
  String get chatsArchivedEmptyTitle => 'No archived chats';

  @override
  String get chatsArchivedEmptySubtitle => 'Archived chats will show up here.';

  @override
  String get chatsRequestsEmptyTitle => 'No message requests';

  @override
  String get chatsRequestsEmptySubtitle => 'First messages from people you don\'t know yet will show up here.';

  @override
  String get chatsPinLimitReachedMessage => 'You can pin up to 3 chats.';

  @override
  String get chatsPinAction => 'Pin';

  @override
  String get chatsUnpinAction => 'Unpin';

  @override
  String get chatsArchiveAction => 'Archive';

  @override
  String get chatsUnarchiveAction => 'Unarchive';

  @override
  String get chatsMuteAction => 'Mute';

  @override
  String get chatsUnmuteAction => 'Unmute';

  @override
  String get chatsPinnedSectionLabel => 'Pinned';

  @override
  String get chatsRecentSectionLabel => 'Recent chats';

  @override
  String get eventSaveButton => 'Save';

  @override
  String get venueCreateTitle => 'Venue profile';

  @override
  String get venueEditTitle => 'Edit venue';

  @override
  String get venuePhotoLabel => 'Add photo/logo';

  @override
  String get venuePhotoSheetTitle => 'Add photo';

  @override
  String get venuePhotoGalleryOption => 'Choose from gallery';

  @override
  String get venuePhotoCameraOption => 'Take a photo';

  @override
  String get venueNameLabel => 'Name';

  @override
  String get venueNameHint => 'Venue name';

  @override
  String get venueFieldRequiredError => 'This field is required';

  @override
  String get venueCategoryLabel => 'Category';

  @override
  String get venueCategoryPickerTitle => 'Choose a category';

  @override
  String get venueCategorySearchHint => 'Search categories...';

  @override
  String get venueCategoryChangeHint => 'Tap to change';

  @override
  String get venuePhotoCropTitle => 'Crop photo';

  @override
  String get venueUploadingLabel => 'Uploading...';

  @override
  String get venueUploadCancelButton => 'Cancel';

  @override
  String get venueDirectionsGoogleMaps => 'Google Maps';

  @override
  String get venueDirectionsAppleMaps => 'Apple Maps';

  @override
  String get venueDirectionsWaze => 'Waze';

  @override
  String get venueScheduleLabel => 'Weekly schedule';

  @override
  String get venueFullAddressLabel => 'Full address';

  @override
  String get venuesSearchHint => 'Search venues...';

  @override
  String get venueFilterTooltip => 'Filter';

  @override
  String get venueCategoryFilterTitle => 'Choose category';

  @override
  String get venueCategoryAllOption => 'All';

  @override
  String get offersSearchHint => 'Search offers...';

  @override
  String get offerFilterTooltip => 'Filter';

  @override
  String get offersEmptyTitle => 'No offers yet';

  @override
  String get offersEmptySubtitle => 'Offers from nearby venues will show up here.';

  @override
  String get offerCategoryFilterTitle => 'Choose a category';

  @override
  String get offerCategoryAllOption => 'All';

  @override
  String get offerBadgeDiscountSuffix => 'off';

  @override
  String get offerBadgeGiftLabel => 'Gift';

  @override
  String get offerBadgeBuyOneGetOneLabel => '1+1';

  @override
  String get offerBadgeFixedPriceSuffix => 'AZN';

  @override
  String offerEndsOnLabel(String date) {
    return 'Until $date';
  }

  @override
  String get offerTermsLabel => 'Terms';

  @override
  String get offerValidityLabel => 'Validity period';

  @override
  String get offerStartDateLabel => 'Starts';

  @override
  String get offerEndDateLabel => 'Ends';

  @override
  String get offerContactLabel => 'Contact';

  @override
  String get offerOtherActiveOffersLabel => 'Other active offers';

  @override
  String get offerViewVenueProfileButton => 'View venue profile';

  @override
  String get offerNotFoundMessage => 'Offer not found.';

  @override
  String get offerGenericErrorMessage => 'Something went wrong. Try again shortly.';

  @override
  String get offerCreateTitle => 'Create offer';

  @override
  String get offerEditTitle => 'Edit offer';

  @override
  String get offerPhotoLabel => 'Add a photo/logo';

  @override
  String get offerNameLabel => 'Offer name';

  @override
  String get offerNameHint => 'Enter the offer name';

  @override
  String get offerCategoryLabel => 'Choose a category';

  @override
  String get offerTypeLabel => 'Offer type';

  @override
  String get offerTypeDiscountOption => 'Discount';

  @override
  String get offerTypeGiftOption => 'Gift';

  @override
  String get offerTypeBuyOneGetOneOption => '1+1 gift';

  @override
  String get offerTypeFixedPriceOption => 'Fixed price';

  @override
  String get offerDiscountAmountLabel => 'Discount amount';

  @override
  String get offerFixedPriceLabel => 'Price (AZN)';

  @override
  String get offerFixedPriceHint => 'Enter the price';

  @override
  String get offerDescriptionLabel => 'Short description';

  @override
  String get offerDescriptionHint => 'Describe the offer\'s terms and perks...';

  @override
  String get offerValidityPeriodLabel => 'Offer validity period';

  @override
  String get offerStartDatePickerLabel => 'Start date';

  @override
  String get offerEndDatePickerLabel => 'End date';

  @override
  String get offerVenuePickerLabel => 'Choose a venue';

  @override
  String get offerVenuePickerHint => 'Choose a venue';

  @override
  String get offerNoVenuesTitle => 'You don\'t have any venues yet';

  @override
  String get offerNoVenuesSubtitle => 'Add a venue first to create an offer.';

  @override
  String get offerAddVenueButton => 'Add a venue';

  @override
  String get offerTermsHint => 'Write the offer\'s terms of use...';

  @override
  String get offerAdditionalInfoLabel => 'Additional info';

  @override
  String get offerContactPhoneHint => 'Phone number';

  @override
  String get offerContactWebsiteHint => 'Website';

  @override
  String get offerContactInstagramHint => 'Instagram';

  @override
  String get offerSubmitButton => 'Create offer';

  @override
  String get offerCreatedNotice => 'Offer created';

  @override
  String get offerUpdatedNotice => 'Offer updated';

  @override
  String get offerRequiredFieldsMissing => 'Please fill in all the required fields.';

  @override
  String get offerDatesInvalidError => 'The end date must be after the start date.';

  @override
  String get offerDeleteMenuOption => 'Delete offer';

  @override
  String get offerDeleteConfirmMessage => 'Are you sure you want to delete this offer? This can\'t be undone.';

  @override
  String get offerDeletedNotice => 'Offer deleted';

  @override
  String get offerStatusActive => 'Active';

  @override
  String get offerStatusExpired => 'Expired';

  @override
  String get offerMyOffersTitle => 'My offers';

  @override
  String get offerMyOffersEmptyTitle => 'You haven\'t added any offers yet';

  @override
  String get offerMyOffersEmptySubtitle => 'Offers you add will show up here, and you can edit or delete them anytime.';

  @override
  String get offerMyOffersTooltip => 'My offers';

  @override
  String get offerAddButtonTooltip => 'Create offer';

  @override
  String get venueCategoryUnselectedLabel => 'Select';

  @override
  String get venueCategoryRestaurant => 'Restaurant';

  @override
  String get venueCategoryPub => 'Pub';

  @override
  String get venueCategoryCoffeeShop => 'Coffee Shops';

  @override
  String get venueCategoryFastFood => 'Fast-Food';

  @override
  String get venueCategoryTeaHouse => 'Tea House';

  @override
  String get venueCategorySweetsShop => 'Sweets Shop';

  @override
  String get venueCategoryHotel => 'Hotel';

  @override
  String get venueCategoryMotel => 'Motel';

  @override
  String get venueCategoryCinema => 'Cinema';

  @override
  String get venueCategoryKaraoke => 'Karaoke Bar';

  @override
  String get venueCategoryGameHall => 'Game Hall';

  @override
  String get venueCategoryNightClub => 'Night Club';

  @override
  String get venueCategoryFitness => 'Fitness';

  @override
  String get venueCategoryGym => 'GYM';

  @override
  String get venueCategorySpa => 'Spa, Massage & Sauna';

  @override
  String get venueCategoryFootballField => 'Football Field';

  @override
  String get venueCategoryClinic => 'Clinic';

  @override
  String get venueCategoryBeautySalon => 'Beauty Salon';

  @override
  String get venueCategoryBarbershop => 'Barbershop';

  @override
  String get venueCategoryCosmetology => 'Cosmetology';

  @override
  String get venueCategoryTattoo => 'Tattoo & Piercing';

  @override
  String get venueCategoryPhotoStudio => 'Photo Studio';

  @override
  String get venueCategoryKidsEntertainment => 'Kids Entertainment';

  @override
  String get venueCategoryOther => 'Other';

  @override
  String get venueHoursLabel => 'Opening hours';

  @override
  String get venueHours24Label => 'Open 24 hours';

  @override
  String get venueHoursSameEveryDayLabel => 'Same hours every day';

  @override
  String get venueWeekdayMon => 'Mon';

  @override
  String get venueWeekdayTue => 'Tue';

  @override
  String get venueWeekdayWed => 'Wed';

  @override
  String get venueWeekdayThu => 'Thu';

  @override
  String get venueWeekdayFri => 'Fri';

  @override
  String get venueWeekdaySat => 'Sat';

  @override
  String get venueWeekdaySun => 'Sun';

  @override
  String get venueLocationLabel => 'Address/location';

  @override
  String get venuePickOnMapButton => 'Pick on map';

  @override
  String get venueLocationPickedLabel => 'Picked on map ✓';

  @override
  String get venueLocationPickerTitle => 'Pick a location';

  @override
  String get venueLocationPickerHint => 'Tap the map or drag the pin to the exact spot';

  @override
  String get venueLocationResolvingAddress => 'Resolving address...';

  @override
  String get venueLocationAddressUnavailable => 'Address not found';

  @override
  String get venueLocationPickerConfirmButton => 'Use this location';

  @override
  String get venueCreateButton => 'Add';

  @override
  String get venueSaveButton => 'Save';

  @override
  String get venueRequiredFieldsMissing => 'Please fill in all required fields.';

  @override
  String get venueGenericErrorMessage => 'That didn\'t go through. Please try again in a moment.';

  @override
  String get venueAddButtonTooltip => 'Add a venue';

  @override
  String get venuesEmptyTitle => 'No venues nearby';

  @override
  String get venuesEmptySubtitle => 'No one has added a venue within your selected radius yet.';

  @override
  String get venueMyVenuesTooltip => 'My venues';

  @override
  String get venueMyVenuesTitle => 'My venues';

  @override
  String get venueMyVenuesEmptyTitle => 'You haven\'t added any venues yet';

  @override
  String get venueMyVenuesEmptySubtitle => 'Venues you add will show up here, and you can edit or delete them anytime.';

  @override
  String get venueDeleteMenuOption => 'Delete venue';

  @override
  String get venueDeleteConfirmMessage => 'Are you sure you want to delete this venue? This action cannot be undone.';

  @override
  String get venueDeletedNotice => 'Venue deleted';

  @override
  String get venueOpenNowLabel => 'Open';

  @override
  String get venueClosedNowLabel => 'Closed';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileNamePlaceholder => 'Add your name';

  @override
  String get profileBioPlaceholder => 'Add a photo, bio and interests';

  @override
  String get shareProfileLabel => 'Share profile';

  @override
  String get profileStatsFriends => 'Friends';

  @override
  String get profileStatsLikes => 'Likes';

  @override
  String get profileGalleryEmptyMessage => 'You haven\'t uploaded any photos or videos yet';

  @override
  String get editProfileTitle => 'Personal info';

  @override
  String get personalInfoSubtitle => 'Update your details and save your changes.';

  @override
  String get profileSaveSuccessMessage => 'Your details have been updated.';

  @override
  String get menuSettings => 'Settings';

  @override
  String get menuPrivacySecurity => 'Privacy and security';

  @override
  String get privacySecurityTitle => 'Privacy and security';

  @override
  String get privacyProfileVisibilityTitle => 'Media visibility';

  @override
  String get privacyProfileVisibilitySubtitle => 'Choose who can see the posts on your profile.';

  @override
  String get privacyVisibilityEveryone => 'Everyone';

  @override
  String get privacyVisibilityFollowersOnly => 'Following & Followers';

  @override
  String get privacyVisibilityNoOne => 'No one';

  @override
  String get privacyClosedProfileNotice => 'Closed profile';

  @override
  String get privacyRadiusTitle => 'Visibility radius';

  @override
  String get privacyRadiusCountryLabel => 'By country';

  @override
  String get privacyRadiusWorldLabel => 'Worldwide';

  @override
  String get privacyOnlineStatusTitle => 'Show that I\'m online';

  @override
  String get privacyReadReceiptsTitle => 'Show read receipts';

  @override
  String get privacyReadReceiptsHelperText => 'Turning this off also hides the other person\'s read receipts from you.';

  @override
  String get privacyWhoCanMessageTitle => 'Who can message me';

  @override
  String get privacyMessagePermEveryone => 'Everyone';

  @override
  String get privacyMessagePermVerifiedOnly => 'Verified users only';

  @override
  String get privacyMessagePermNoOne => 'No one';

  @override
  String get privacyGhostModeTitle => 'Ghost mode';

  @override
  String get privacyGhostModeDescription => 'You can see other users. Other users can\'t see you on the map. Turn it on or off any time you like.';

  @override
  String get privacyGhostModePremiumTitle => 'Go invisible with Ghost mode 👻';

  @override
  String get privacyGhostModePremiumMessage => 'With Premium you can see other users, but they won\'t be able to see you on the map.';

  @override
  String get privacySettingUpdateErrorMessage => 'That change wasn\'t saved. Please try again in a moment.';

  @override
  String get privacyTwoFactorTitle => 'Enable two-factor authentication';

  @override
  String get privacyTwoFactorHelperText => 'Only your choice is saved for now — SMS and Authenticator support are coming soon.';

  @override
  String get privacyExportDataTitle => 'Download my data';

  @override
  String get privacyExportDataDescription => 'Data stored about you in the app will be prepared and shown to you.';

  @override
  String get exportDataScreenTitle => 'My data';

  @override
  String get exportDataCopyButton => 'Copy';

  @override
  String get exportDataCopiedNotice => 'Data copied to clipboard.';

  @override
  String get exportDataLoadErrorMessage => 'Couldn\'t load your data. Please try again.';

  @override
  String get privacyDeleteAccountTitle => 'Delete my account';

  @override
  String get deleteAccountWarningTitle => 'Are you sure you want to delete your account?';

  @override
  String get deleteAccountWarningMessage => 'Your profile, chats and all your data will be permanently deleted. This can\'t be undone.';

  @override
  String get deleteAccountFinalConfirmTitle => 'Final confirmation';

  @override
  String get deleteAccountFinalConfirmMessage => 'You\'re about to delete your account. There\'s no going back after this.';

  @override
  String get deleteAccountConfirmButton => 'Yes, delete my account';

  @override
  String get deleteAccountReauthTitle => 'Verify it\'s you';

  @override
  String get deleteAccountReauthMessage => 'For security, you need to re-verify your phone number before deleting your account.';

  @override
  String get deleteAccountSendCodeButton => 'Send code';

  @override
  String get deleteAccountCodeSentMessage => 'Code sent';

  @override
  String get deleteAccountOtpHint => 'SMS code';

  @override
  String get deleteAccountConfirmCodeButton => 'Confirm';

  @override
  String get deleteAccountReauthFailedMessage => 'Verification failed. Please try again.';

  @override
  String get deleteAccountErrorMessage => 'Couldn\'t delete the account. Please try again in a moment.';

  @override
  String get blockedUsersTitle => 'Blocked users';

  @override
  String get blockedUsersEmptyTitle => 'No blocked users';

  @override
  String get blockedUsersEmptySubtitle => 'Users you block will show up here.';

  @override
  String get menuNotifications => 'Notifications';

  @override
  String get menuHelp => 'Help';

  @override
  String get menuLogout => 'Log out';

  @override
  String uploadingProgress(String percent) {
    return '$percent% uploading...';
  }

  @override
  String get removePhotoButton => 'Remove photo';

  @override
  String get fieldAgeLabel => 'Age';

  @override
  String get fieldAgeHint => '25';

  @override
  String get fieldEmailOptionalLabel => 'Email (optional)';

  @override
  String get fieldEmailHint => 'name@email.com';

  @override
  String get sectionAboutTitle => 'About you';

  @override
  String get bioHintEdit => 'Write a few sentences about yourself...';

  @override
  String get saveButton => 'Save';

  @override
  String get waitPhotoUploadError => 'Wait for the photo to finish uploading...';

  @override
  String get invalidEmailError => 'Enter a valid email address';

  @override
  String saveFailedError(String error) {
    return 'Couldn\'t save: $error';
  }

  @override
  String get photoOperationFailedError => 'The photo operation failed.';

  @override
  String get storageErrorFileTooLarge => 'The photo can\'t be larger than 5MB.';

  @override
  String get storageErrorInvalidContentType => 'Unsupported file format.';

  @override
  String get storageErrorUploadFailed => 'The photo couldn\'t be uploaded.';

  @override
  String get storageErrorDownloadUrlFailed => 'The photo couldn\'t be loaded.';

  @override
  String get storageErrorDeleteFailed => 'The photo couldn\'t be deleted.';

  @override
  String get storageErrorPermissionDenied => 'You don\'t have permission for this action.';

  @override
  String get storageErrorUnauthenticated => 'You\'re not signed in.';

  @override
  String get storageErrorUnknown => 'An unknown storage error occurred.';

  @override
  String get comingSoonDefaultMessage => 'This feature will be available soon.';

  @override
  String get pickCountryHint => 'Search country';

  @override
  String get pickCityTitle => 'Choose city';

  @override
  String get pickCityHint => 'Search city';

  @override
  String get searchNotFound => 'No results found';

  @override
  String get fieldCountryLabel => 'Country';

  @override
  String get fieldCitySelectFirstHint => 'Choose a country first';

  @override
  String get fieldCityLabel => 'City';

  @override
  String get contactRequiredError => 'Enter your email or phone number';

  @override
  String get contactInvalidError => 'Enter a valid email or phone number';

  @override
  String get stampLike => 'LIKE';

  @override
  String get stampReject => 'PASS';

  @override
  String get stampSuper => 'SUPER';

  @override
  String get emptyStackTitle => 'No one around yet';

  @override
  String get emptyStackSubtitle => 'Try changing the radius or filter.';

  @override
  String get discoverActiveNowLabel => 'Active now';

  @override
  String get discoverSwipeUpHint => 'Swipe up for the next card';

  @override
  String get discoverMatchTitle => 'It\'s a match!';

  @override
  String get discoverMatchMessage => 'You both liked each other!';

  @override
  String get discoverMatchLaterButton => 'Later';

  @override
  String get storyVisibilitySheetTitle => 'Who can see this?';

  @override
  String get storyVisibilityPickPrompt => 'Who can see this?';

  @override
  String get storyVisibilityFollowers => 'Following & Followers';

  @override
  String get storyVisibilityEveryone => 'Everyone';

  @override
  String get storyShareButton => 'Share';

  @override
  String get storyVideoTooLongMessage => 'Videos can be at most 60 seconds long';

  @override
  String get storyShareErrorMessage => 'Couldn\'t share this. Please try again shortly.';

  @override
  String get storyViewersEmptyMessage => 'No one has viewed this yet';

  @override
  String get storyViewersTitle => 'Viewers';

  @override
  String get postCaptureSheetTitle => 'Add a post';

  @override
  String get postCameraOption => 'Take a photo';

  @override
  String get postGalleryPhotoOption => 'Choose a photo';

  @override
  String get postGalleryVideoOption => 'Choose a video';

  @override
  String get postShareButton => 'Share';

  @override
  String get postShareErrorMessage => 'The post couldn\'t be shared. Please try again shortly.';

  @override
  String get postFeedEmptyMessage => 'No posts yet';

  @override
  String get postCommentsSheetTitle => 'Comments';

  @override
  String get postCommentsEmptyMessage => 'No comments yet';

  @override
  String get postCommentHint => 'Write a comment...';

  @override
  String get postCommentSendButton => 'Send';

  @override
  String get postCommentErrorMessage => 'The comment wasn\'t sent. Please try again shortly.';

  @override
  String get postLikeErrorMessage => 'The like wasn\'t saved. Please try again shortly.';

  @override
  String get feedSearchHint => 'Search';

  @override
  String get feedSearchNoResultsMessage => 'No results found';

  @override
  String get feedDownloadVideoOption => 'Download video';

  @override
  String feedDownloadInProgressMessage(int percent) {
    return 'Downloading... $percent%';
  }

  @override
  String get feedDownloadCompleteMessage => 'Video saved to your gallery';

  @override
  String get feedDownloadErrorMessage => 'Couldn\'t download the video. Please try again shortly.';

  @override
  String get postTimeJustNow => 'Just now';

  @override
  String postTimeMinutesAgo(int count) {
    return '$count min ago';
  }

  @override
  String postTimeHoursAgo(int count) {
    return '${count}h ago';
  }

  @override
  String postTimeDaysAgo(int count) {
    return '${count}d ago';
  }

  @override
  String postTimeWeeksAgo(int count) {
    return '${count}w ago';
  }

  @override
  String get postCaptionHint => 'Write a caption...';

  @override
  String get postMenuEdit => 'Edit';

  @override
  String get postMenuDelete => 'Delete';

  @override
  String get postEditCaptionTitle => 'Edit caption';

  @override
  String get postEditCaptionSave => 'Save';

  @override
  String get postEditCaptionErrorMessage => 'The change wasn\'t saved. Please try again shortly.';

  @override
  String get postDeleteConfirmTitle => 'Delete this post?';

  @override
  String get postDeleteConfirmMessage => 'This action cannot be undone.';

  @override
  String get postDeleteErrorMessage => 'The post wasn\'t deleted. Please try again shortly.';

  @override
  String get storyDeleteConfirmTitle => 'Delete this story?';

  @override
  String get storyDeleteConfirmMessage => 'This action cannot be undone.';

  @override
  String get storyDeleteErrorMessage => 'The story wasn\'t deleted. Please try again shortly.';

  @override
  String get viewActiveStoryButton => 'View story';

  @override
  String get postReplyAction => 'Reply';

  @override
  String postReplyingToLabel(String name) {
    return 'Replying to $name';
  }

  @override
  String get postCommentDeleteConfirmTitle => 'Delete this comment?';

  @override
  String get postCommentDeleteErrorMessage => 'The comment wasn\'t deleted. Please try again shortly.';

  @override
  String get postCommentEditErrorMessage => 'The comment wasn\'t updated. Please try again shortly.';

  @override
  String get postShareOptionsSheetTitle => 'Share';

  @override
  String get postShareToChatOption => 'Send in chat';

  @override
  String get postShareExternalOption => 'Share to other apps';

  @override
  String get postSendToSheetTitle => 'Send to';

  @override
  String get postSendToEmptyMessage => 'You don\'t have any chats yet';

  @override
  String get postSentToChatSuccessMessage => 'Post sent';

  @override
  String get postSentToChatErrorMessage => 'The post wasn\'t sent. Please try again shortly.';

  @override
  String get chatPostMessageLabel => 'Post';

  @override
  String get friendRequestSendButton => 'Add friend';

  @override
  String get friendRequestSentLabel => 'Sent';

  @override
  String get friendRequestPendingLabel => 'Pending';

  @override
  String get friendRequestAcceptedLabel => 'Friends';

  @override
  String get friendRequestDeclinedLabel => 'Declined';

  @override
  String get friendRequestErrorMessage => 'Couldn\'t send the request. Please try again shortly.';

  @override
  String get sendMessageButton => 'Message';

  @override
  String get followButton => 'Follow';

  @override
  String get followingButton => 'Following';

  @override
  String get followErrorMessage => 'Something went wrong. Please try again shortly.';

  @override
  String get profileStatsFollowing => 'Following';

  @override
  String get profileStatsFollowers => 'Followers';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguageRowLabel => 'Language';

  @override
  String get languagePickerTitle => 'Choose language';

  @override
  String get settingsAccountRowTitle => 'Account';

  @override
  String get settingsAccountRowSubtitle => 'Personal info, phone, email, password';

  @override
  String get changePhotoScreenTitle => 'Change profile photo';

  @override
  String get settingsChangePhotoRowSubtitle => 'Update or remove your profile photo';

  @override
  String get settingsPrivacyRowSubtitle => 'Visibility, blocks, active devices and more';

  @override
  String get settingsNotificationsRowSubtitle => 'Messages, push notifications';

  @override
  String get settingsLanguageRowSubtitle => 'App language';

  @override
  String get settingsIdentityRowSubtitle => 'Verify your identity, earn a trusted badge';

  @override
  String get settingsVipRowTitle => 'Meevima VIP';

  @override
  String get settingsVipRowSubtitle => 'Go VIP, manage your plan';

  @override
  String get settingsVipActiveLabel => 'Active';

  @override
  String get settingsVipBadgeLabel => 'VIP';

  @override
  String get settingsMapRowTitle => 'Map & Location';

  @override
  String get settingsMapRowSubtitle => 'Map type, distance unit, GPS';

  @override
  String get settingsPaymentsRowTitle => 'Payments';

  @override
  String get settingsPaymentsRowSubtitle => 'Payment history, cards, subscription';

  @override
  String get settingsHelpRowTitle => 'Help';

  @override
  String get settingsHelpRowSubtitle => 'FAQ, contact us, report a problem';

  @override
  String get settingsLegalRowTitle => 'Legal';

  @override
  String get settingsLegalRowSubtitle => 'Privacy policy, terms of use';

  @override
  String get settingsAboutRowTitle => 'About';

  @override
  String get settingsAboutRowSubtitle => 'Version, what\'s new, social media';

  @override
  String get settingsLogoutRowTitle => 'Log out';

  @override
  String get settingsLogoutRowSubtitle => 'Sign out of your account';

  @override
  String get notificationsScreenTitle => 'Notifications';

  @override
  String get notifMessagesTitle => 'Messages';

  @override
  String get notifMessagesSubtitle => 'Get notified about new messages';

  @override
  String get notifFollowersTitle => 'Followers';

  @override
  String get notifFollowersSubtitle => 'New followers and follow requests';

  @override
  String get notifNewUsersTitle => 'New users';

  @override
  String get notifNewUsersSubtitle => 'When a new user joins nearby';

  @override
  String get notifLikesTitle => 'Likes';

  @override
  String get notifLikesSubtitle => 'Get notified when someone likes you';

  @override
  String get notifCommentsTitle => 'Comments';

  @override
  String get notifCommentsSubtitle => 'Get notified about comments and reactions';

  @override
  String get notifVenueOffersTitle => 'Venue offers';

  @override
  String get notifVenueOffersSubtitle => 'New offers from venues you follow';

  @override
  String get notifVenueUpdatesTitle => 'Venue updates';

  @override
  String get notifVenueUpdatesSubtitle => 'Venue additions and verifications';

  @override
  String get notifSecurityTitle => 'Security';

  @override
  String get notifSecuritySubtitle => 'Important security alerts about your account';

  @override
  String get notifSystemTitle => 'System notifications';

  @override
  String get notifSystemSubtitle => 'Important announcements about the app';

  @override
  String get notifMarketingTitle => 'Marketing';

  @override
  String get notifMarketingSubtitle => 'Stay updated on campaigns and discounts';

  @override
  String get notifPushTitle => 'Push notifications';

  @override
  String get notifEmailTitle => 'Email notifications';

  @override
  String get notifUpdateErrorMessage => 'The change wasn\'t saved. Please try again shortly.';

  @override
  String get mapLocationScreenTitle => 'Map & Location';

  @override
  String get mapTypeTitle => 'Map type';

  @override
  String get mapTypeStandard => 'Standard';

  @override
  String get mapTypeSatellite => 'Satellite';

  @override
  String get mapTypeHybrid => 'Hybrid';

  @override
  String get distanceUnitTitle => 'Distance unit';

  @override
  String get distanceUnitKm => 'Kilometers';

  @override
  String get distanceUnitMi => 'Miles';

  @override
  String get gpsAccuracyTitle => 'GPS accuracy';

  @override
  String get gpsAccuracyHigh => 'High';

  @override
  String get gpsAccuracyStandard => 'Standard';

  @override
  String get backgroundLocationTitle => 'Background location';

  @override
  String get backgroundLocationSubtitle => 'Keep your location updated while the app is in the background';

  @override
  String get backgroundLocationDeniedMessage => 'To enable background location, choose \"Allow all the time\" in Settings > Apps.';

  @override
  String get mapLocationUpdateErrorMessage => 'The change wasn\'t saved. Please try again shortly.';

  @override
  String get helpScreenTitle => 'Help';

  @override
  String get helpFaqSectionTitle => 'Frequently asked questions';

  @override
  String get helpFaq1Question => 'How does Meevima work?';

  @override
  String get helpFaq1Answer => 'The app uses your location to show you other nearby users. You can choose the radius and filters from the Discover tab.';

  @override
  String get helpFaq2Question => 'Who can see my location?';

  @override
  String get helpFaq2Answer => 'Only your approximate distance is shown to other users, never your exact coordinates. Turn on Ghost Mode under Settings > Privacy & Security to hide completely.';

  @override
  String get helpFaq3Question => 'How do I delete my account?';

  @override
  String get helpFaq3Answer => 'Go to Settings > Account > Delete my account to permanently remove your account. This action cannot be undone.';

  @override
  String get helpFaq4Question => 'What should I do if someone is bothering me?';

  @override
  String get helpFaq4Answer => 'You can block or report that user from their profile at any time. A blocked user will no longer be able to see you.';

  @override
  String get helpFaq5Question => 'What is Meevima VIP for?';

  @override
  String get helpFaq5Answer => 'VIP membership unlocks an extended visibility radius, Ghost Mode, and extra filters.';

  @override
  String get helpFaq6Question => 'How do I change my visibility radius?';

  @override
  String get helpFaq6Answer => 'Use the radius picker below the map on the Discover tab to choose the distance you want.';

  @override
  String get helpContactRowTitle => 'Contact us';

  @override
  String get helpContactRowSubtitle => 'Get in touch with any questions';

  @override
  String get helpReportProblemRowTitle => 'Report a problem';

  @override
  String get helpReportProblemRowSubtitle => 'Let us know about a technical issue';

  @override
  String get helpSendSuggestionRowTitle => 'Send a suggestion';

  @override
  String get helpSendSuggestionRowSubtitle => 'How can we make the app better?';

  @override
  String get contactUsSheetTitle => 'Contact us';

  @override
  String get contactUsEmailCopiedNotice => 'Email address copied';

  @override
  String get contactUsSendEmailButton => 'Send email';

  @override
  String get reportProblemSheetTitle => 'Report a problem';

  @override
  String get sendSuggestionSheetTitle => 'Send a suggestion';

  @override
  String get supportMessageHint => 'Write your message here...';

  @override
  String get supportMessageSendButton => 'Send';

  @override
  String get supportMessageSentNotice => 'Your message was sent. Thank you!';

  @override
  String get supportMessageErrorMessage => 'The message wasn\'t sent. Please try again shortly.';

  @override
  String get legalPrivacyPolicyTitle => 'Privacy Policy';

  @override
  String get legalTermsOfServiceTitle => 'Terms of Service';

  @override
  String get legalLicensesTitle => 'Licenses';

  @override
  String get aboutWhatsNewTitle => 'What\'s new';

  @override
  String get aboutSocialMediaTitle => 'Social media';

  @override
  String get aboutSocialMediaComingSoonLabel => 'Coming soon';

  @override
  String get aboutCopyrightText => '© 2026 Meevima. All rights reserved.';

  @override
  String get aboutChangelogV1Title => 'v1.0.0';

  @override
  String get aboutChangelogV1Body => 'First release: discover nearby users, friend requests, chats, stories, and profile management.';

  @override
  String get vipHeaderTitle => 'Meevima VIP';

  @override
  String get vipHeaderSubtitle => 'Meet more people with expanded features';

  @override
  String get vipChoosePackageTitle => 'Choose a package';

  @override
  String get vipPeriodMonthly => 'Monthly';

  @override
  String get vipPeriodQuarterly => '3 Months';

  @override
  String get vipPeriodYearly => 'Yearly';

  @override
  String get vipBestValueBadge => 'Best value';

  @override
  String get vipPriceComingSoonNote => 'Prices will appear here once the store connection is live.';

  @override
  String get vipSubscribeButton => 'Subscribe';

  @override
  String get vipAlreadySubscribedButton => 'You\'re already VIP';

  @override
  String get vipBillingComingSoonMessage => 'Billing will be enabled soon.';

  @override
  String get vipCurrentPackageTitle => 'Current package';

  @override
  String get vipCurrentPackageActiveLabel => 'Active';

  @override
  String get vipManageButton => 'Manage';

  @override
  String get vipFeatureGhostTitle => 'Ghost Mode';

  @override
  String get vipFeatureGhostDescription => 'See other users without appearing on the map yourself.';

  @override
  String get vipFeatureRadiusTitle => 'Extended radius';

  @override
  String get vipFeatureRadiusDescription => 'Discover people within a 5 km or 10 km radius.';

  @override
  String get vipFeatureFilterTitle => 'Extra filters';

  @override
  String get vipFeatureFilterDescription => 'Narrow your search with gender and other filters.';

  @override
  String get accountScreenTitle => 'Account';

  @override
  String get accountPersonalInfoTitle => 'Personal info';

  @override
  String get accountPhoneRowTitle => 'Phone number';

  @override
  String get accountEmailRowTitle => 'Email';

  @override
  String get accountEmailEmptyValue => 'Not added';

  @override
  String get accountPasswordRowTitle => 'Change password';

  @override
  String get accountPhoneUnsetValue => 'Not verified';

  @override
  String get accountChangeEmailSheetTitle => 'Change email';

  @override
  String get accountNewEmailLabel => 'New email address';

  @override
  String get accountEmailInvalidError => 'Enter a valid email address';

  @override
  String get accountEmailUpdatedNotice => 'Email updated';

  @override
  String get accountDeleteRowTitle => 'Delete account';

  @override
  String get accountDeleteRowSubtitle => 'Delete your account and all your data';

  @override
  String get accountDeleteConfirmWordLabel => 'Type \"DELETE\" below to confirm';

  @override
  String get accountDeleteConfirmWordHint => 'DELETE';

  @override
  String get accountDeleteConfirmWordMismatchError => 'Type \"DELETE\" exactly to continue';

  @override
  String get paymentsScreenTitle => 'Payments';

  @override
  String get paymentHistoryRowTitle => 'Payment history';

  @override
  String get myCardsTitle => 'My cards';

  @override
  String get addCardButton => 'Add card';

  @override
  String get noCardsMessage => 'No cards added yet';

  @override
  String get cardOptionsSetDefault => 'Set as default';

  @override
  String get cardOptionsDelete => 'Delete';

  @override
  String get paymentHistoryEmptyMessage => 'No transactions yet';

  @override
  String get paymentTypePurchase => 'Purchase';

  @override
  String get paymentTypeRenewal => 'Renewal';

  @override
  String get paymentTypeCancellation => 'Cancellation';

  @override
  String get paymentTypeRefund => 'Refund';

  @override
  String get activeDevicesTitle => 'Active devices';

  @override
  String get privacyActiveDevicesSubtitle => 'List of your active devices';

  @override
  String get activeDevicesEmptyMessage => 'No active devices found';

  @override
  String get thisDeviceLabel => 'This device';

  @override
  String get lastActiveLabel => 'Last active';

  @override
  String get signOutDeviceButton => 'Sign out';

  @override
  String get signOutDeviceConfirmTitle => 'Sign out this device?';

  @override
  String get signOutDeviceConfirmMessage => 'This device will be signed out remotely. If it\'s offline, it\'ll be signed out the next time it connects.';

  @override
  String get signOutDeviceErrorMessage => 'Couldn\'t sign out. Please try again shortly.';

  @override
  String get privacyTwoFactorActivateTitle => 'Activate two-factor authentication';

  @override
  String get privacyTwoFactorDisableButton => 'Turn off';
}
