import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/private_data_ref.dart';
import '../../../../l10n/app_localizations.dart';
import 'consent_checkbox_row.dart';

import '../../../../core/utils/callables.dart';

/// One-shot, best-effort check — called once from `HomeScreen.initState`,
/// same pattern as its other launch-time setup calls (`setOnline()`,
/// `syncSubscriptions()`, etc.). Compares the signed-in user's stored
/// `users/{uid}.consent.termsVersion`/`privacyVersion` against
/// `config/legal`'s `currentTermsVersion`/`currentPrivacyVersion` — a
/// mismatch (including a user with no `consent` at all, e.g. one who
/// onboarded before this feature shipped) shows a blocking,
/// non-dismissible re-consent dialog reusing the exact same
/// [ConsentCheckboxRow] the registration screen uses. Any failure
/// (offline, `config/legal` not bootstrapped yet via
/// `npm run set-legal-version`, etc.) just skips the check silently —
/// this must never be the reason a user can't open the app.
Future<void> checkAndShowConsentDialogIfNeeded(BuildContext context, WidgetRef ref) async {
  final uid = fb.FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  try {
    final firestore = FirebaseFirestore.instance;
    final configSnap = await firestore.collection('config').doc('legal').get();
    final currentTerms = configSnap.data()?['currentTermsVersion'] as String?;
    final currentPrivacy = configSnap.data()?['currentPrivacyVersion'] as String?;
    if (currentTerms == null || currentPrivacy == null) return;

    // `consent` lives on `users/{uid}/private/data` (Düzəliş Prompt 4).
    final userSnap = await privateDataRef(uid, firestore: firestore).get();
    final consent = (userSnap.data()?['consent'] as Map?)?.cast<String, dynamic>();
    final userTerms = consent?['termsVersion'] as String?;
    final userPrivacy = consent?['privacyVersion'] as String?;

    if (userTerms == currentTerms && userPrivacy == currentPrivacy) return;
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ConsentDialog(uid: uid, termsVersion: currentTerms, privacyVersion: currentPrivacy),
    );
  } catch (e, st) {
    logError('consent_dialog.checkAndShowConsentDialogIfNeeded', e, st);
  }
}

class _ConsentDialog extends ConsumerStatefulWidget {
  final String uid;
  final String termsVersion;
  final String privacyVersion;

  const _ConsentDialog({required this.uid, required this.termsVersion, required this.privacyVersion});

  @override
  ConsumerState<_ConsentDialog> createState() => _ConsentDialogState();
}

class _ConsentDialogState extends ConsumerState<_ConsentDialog> {
  bool _accepted = false;
  bool _submitting = false;

  Future<void> _accept() async {
    setState(() => _submitting = true);
    try {
      // P0 / H-9 — `consent` is a legal acceptance record, so it is no
      // longer written from here. `recordConsent` (Cloud Function) reads
      // the accepted versions from `config/legal` itself rather than
      // trusting the two version strings this widget happens to hold,
      // and stamps `acceptedAt` server-side; `firestore.rules` blocks
      // the field from any client write. The versions passed to this
      // widget still drive what the user is SHOWN — they just no longer
      // decide what gets recorded as agreed to.
      await FirebaseFunctions.instance.httpsCallable('recordConsent', options: callableOptions()).call<Map<String, dynamic>>();
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e, st) {
      logError('consent_dialog._ConsentDialogState._accept', e, st);
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    // Blocks the Android back gesture/button too — this dialog is
    // deliberately not dismissible any other way either
    // (barrierDismissible: false at the showDialog call site).
    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(loc.consentDialogTitle, style: AppTextStyles.cardTitle.copyWith(fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(loc.consentDialogMessage, style: AppTextStyles.body.copyWith(fontSize: 14.5)),
            const SizedBox(height: 16),
            ConsentCheckboxRow(value: _accepted, onChanged: (value) => setState(() => _accepted = value)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: (_accepted && !_submitting) ? _accept : null,
            child: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  )
                : Text(loc.consentDialogContinueButton),
          ),
        ],
      ),
    );
  }
}
