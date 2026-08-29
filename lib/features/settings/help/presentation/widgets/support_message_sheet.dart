import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../domain/entities/support_message.dart';
import '../providers/support_providers.dart';

void showSupportMessageSheet(BuildContext context, SupportMessageType type) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _SupportMessageSheet(type: type),
  );
}

class _SupportMessageSheet extends ConsumerStatefulWidget {
  final SupportMessageType type;

  const _SupportMessageSheet({required this.type});

  @override
  ConsumerState<_SupportMessageSheet> createState() => _SupportMessageSheetState();
}

class _SupportMessageSheetState extends ConsumerState<_SupportMessageSheet> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send(AppLocalizations loc) async {
    final message = _controller.text.trim();
    if (message.isEmpty || _sending) return;
    setState(() => _sending = true);

    final ok = await ref.read(supportControllerProvider).sendMessage(widget.type, message);

    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.supportMessageSentNotice)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.supportMessageErrorMessage)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final title = widget.type == SupportMessageType.problem ? loc.reportProblemSheetTitle : loc.sendSuggestionSheetTitle;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.cardTitle.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              maxLines: 5,
              minLines: 3,
              // Matches firestore.rules' new `message.size() <= 2000`
              // (Düzəliş Prompt 8 / RT-2).
              maxLength: 2000,
              style: AppTextStyles.body,
              decoration: InputDecoration(
                hintText: loc.supportMessageHint,
                filled: true,
                fillColor: AppColors.card,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _sending ? null : () => _send(loc),
                child: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.onAccent),
                      )
                    : Text(loc.supportMessageSendButton),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
