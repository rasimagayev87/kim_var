import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../providers/venue_event_providers.dart';

/// "Şikayət et" — every event card/detail shows this (see `VenueEvent`'s
/// doc comment: events are auto-approved, so after-the-fact reporting
/// is the only moderation lever). Writes `eventReports/{id}`, resolved
/// later from the admin panel's "Tədbir şikayətləri" section.
class EventReportButton extends ConsumerWidget {
  final String eventId;
  final Color? color;

  const EventReportButton({super.key, required this.eventId, this.color});

  Future<void> _report(BuildContext context, WidgetRef ref) async {
    final loc = AppLocalizations.of(context);
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  loc.eventReportSheetTitle,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              title: Text(loc.eventReportReasonSpam),
              onTap: () => Navigator.pop(sheetContext, 'spam'),
            ),
            ListTile(
              title: Text(loc.eventReportReasonInappropriate),
              onTap: () => Navigator.pop(sheetContext, 'inappropriate'),
            ),
            ListTile(
              title: Text(loc.eventReportReasonOther),
              onTap: () => Navigator.pop(sheetContext, 'other'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (reason == null || !context.mounted) return;

    final uid = fb.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final ok = await ref.read(venueEventControllerProvider).reportEvent(eventId: eventId, reportedBy: uid, reason: reason);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? loc.eventReportSubmittedMessage : loc.eventReportErrorMessage)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    return TextButton.icon(
      onPressed: () => _report(context, ref),
      icon: Icon(Icons.flag_outlined, size: 16, color: color ?? ChatLightColors.inkFaint),
      label: Text(loc.eventReportButton, style: TextStyle(fontSize: 12.5, color: color ?? ChatLightColors.inkFaint)),
    );
  }
}
