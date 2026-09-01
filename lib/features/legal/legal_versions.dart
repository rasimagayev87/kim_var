/// The Terms of Service / Privacy Policy version this build's consent
/// checkbox (registration, and the re-consent dialog) asks the user to
/// accept — must match the "Versiya: X.Y" line on the actual documents
/// (peakpin-landing/public/terms-of-service.html, privacy-policy.html,
/// mirrored in kim_var/legal/) and `config/legal.currentTermsVersion`/
/// `currentPrivacyVersion` in Firestore. All three are updated by hand
/// together whenever a document changes materially — see
/// `presentation/widgets/consent_dialog.dart`'s doc comment for the
/// re-consent flow this drives.
///
/// ── These two are AHEAD of Firestore on purpose ────────────────────
///
/// Bumped to 1.1 / 2.0 on 2026-09-01 so this build's registration
/// writes the new numbers, while `config/legal` still holds 1.0 / 1.1.
/// The two must NOT be raised together, and the order is not
/// interchangeable:
///
///   · `firebase_auth_repository.dart` stamps THESE constants onto a
///     new account at registration.
///   · `consent_dialog.dart` compares that stamp against
///     `config/legal` and shows the re-consent dialog when they differ.
///
/// Raising Firestore while an older build is still the one in the
/// store would show the re-consent dialog to someone who had just
/// ticked the consent box seconds earlier. Raising these first is
/// harmless in the other direction: a new account is simply stamped
/// with a version Firestore has not reached yet, and no dialog fires.
///
/// Firestore is raised only once BOTH are true — the store rollout has
/// landed AND the rewritten documents are live on peakpin.app. The
/// second condition matters as much as the first: a re-consent dialog
/// that sends someone to read the OLD text is worse than no dialog.
/// See docs/legal-gap-analysis.md §5.3 for the full sequence.
const String kCurrentTermsVersion = '1.1';
const String kCurrentPrivacyVersion = '2.0';
