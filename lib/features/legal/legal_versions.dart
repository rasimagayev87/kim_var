/// The Terms of Service / Privacy Policy version this build's consent
/// checkbox (registration, and the re-consent dialog) asks the user to
/// accept — must match the "Versiya: X.Y" line on the actual documents
/// (peakpin-landing/public/terms-of-service.html, privacy-policy.html,
/// mirrored in kim_var/legal/) and `config/legal.currentTermsVersion`/
/// `currentPrivacyVersion` in Firestore. All three are updated by hand
/// together whenever a document changes materially — see
/// `presentation/widgets/consent_dialog.dart`'s doc comment for the
/// re-consent flow this drives.
const String kCurrentTermsVersion = '1.0';
const String kCurrentPrivacyVersion = '1.1';
