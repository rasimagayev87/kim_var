import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../providers/waitlist_providers.dart';

const _kMinPartySize = 1;
const _kMaxPartySize = 10;

/// "Neçə nəfərsiniz?" party-size sheet, opened from the "Sıraya yaz"
/// button on `VenueProfileScreen`. Pops `true` on a successful join so
/// the caller can react (there's nothing to react to today beyond the
/// sheet closing — `myWaitlistEntryProvider`'s stream picks up the new
/// entry on its own — but keeping the bool return matches this
/// codebase's other confirm-sheet conventions).
Future<bool?> showWaitlistJoinSheet(BuildContext context, String venueId) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _WaitlistJoinSheet(venueId: venueId),
  );
}

class _WaitlistJoinSheet extends ConsumerStatefulWidget {
  final String venueId;

  const _WaitlistJoinSheet({required this.venueId});

  @override
  ConsumerState<_WaitlistJoinSheet> createState() => _WaitlistJoinSheetState();
}

class _WaitlistJoinSheetState extends ConsumerState<_WaitlistJoinSheet> {
  int _partySize = 2;
  bool _joining = false;

  Future<void> _join() async {
    setState(() => _joining = true);
    final loc = AppLocalizations.of(context);
    final ok = await ref.read(waitlistControllerProvider).join(venueId: widget.venueId, partySize: _partySize);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() => _joining = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.waitlistGenericErrorMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(loc.waitlistPartySizeSheetTitle, style: AppTextStyles.cardTitle.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StepperButton(
                  icon: Icons.remove,
                  onTap: _partySize > _kMinPartySize ? () => setState(() => _partySize--) : null,
                ),
                SizedBox(
                  width: 90,
                  child: Text(
                    '$_partySize',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: ChatLightColors.ink),
                  ),
                ),
                _StepperButton(
                  icon: Icons.add,
                  onTap: _partySize < _kMaxPartySize ? () => setState(() => _partySize++) : null,
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _joining ? null : _join,
              child: _joining
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onAccent),
                    )
                  : Text(loc.waitlistJoinButton),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _StepperButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: enabled ? AppColors.primary.withValues(alpha: 0.12) : ChatLightColors.cardSurface,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Icon(icon, size: 22, color: enabled ? AppColors.primary : ChatLightColors.inkFaint),
        ),
      ),
    );
  }
}
