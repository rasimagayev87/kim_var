import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../../domain/entities/venue.dart';
import '../providers/venue_providers.dart';

const _kMinSeats = 0;
const _kMaxSeats = 50;

/// "Boş yer sayı" quick-edit bottom sheet, opened from the venue's
/// 3-dot menu on `MyVenuesScreen` — deliberately separate from the
/// full [CreateVenueScreen] edit form, since this is meant for
/// frequent single-tap updates, not a form resubmit. Writes directly
/// via `VenueController.updateAvailableSeats` on Save; the caller only
/// needs to `await showModalBottomSheet` and doesn't need a return
/// value, since [VenueProfileScreen]'s [SeatAvailabilityCard] picks up
/// the change live from its own stream.
Future<void> showSeatCountEditorSheet(BuildContext context, Venue venue) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _SeatCountEditorSheet(venue: venue),
  );
}

class _SeatCountEditorSheet extends ConsumerStatefulWidget {
  final Venue venue;

  const _SeatCountEditorSheet({required this.venue});

  @override
  ConsumerState<_SeatCountEditorSheet> createState() =>
      _SeatCountEditorSheetState();
}

class _SeatCountEditorSheetState extends ConsumerState<_SeatCountEditorSheet> {
  late bool _activated = widget.venue.availableSeats != null;
  late int _seats = widget.venue.availableSeats ?? 0;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    final loc = AppLocalizations.of(context);
    final ok = await ref
        .read(venueControllerProvider)
        .updateAvailableSeats(venueId: widget.venue.id, availableSeats: _seats);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.venueGenericErrorMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.seatsSheetTitle,
              style: AppTextStyles.cardTitle.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              loc.seatsSheetSubtitle,
              style: AppTextStyles.caption.copyWith(
                color: ChatLightColors.inkSoft,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            if (!_activated)
              ElevatedButton(
                onPressed: () => setState(() => _activated = true),
                child: Text(loc.seatsActivateButton),
              )
            else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StepperButton(
                    icon: Icons.remove,
                    onTap: _seats > _kMinSeats
                        ? () => setState(() => _seats--)
                        : null,
                  ),
                  SizedBox(
                    width: 90,
                    child: Text(
                      '$_seats',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: ChatLightColors.ink,
                      ),
                    ),
                  ),
                  _StepperButton(
                    icon: Icons.add,
                    onTap: _seats < _kMaxSeats
                        ? () => setState(() => _seats++)
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.onAccent,
                        ),
                      )
                    : Text(loc.saveButton),
              ),
            ],
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
      color: enabled
          ? AppColors.primary.withValues(alpha: 0.12)
          : ChatLightColors.cardSurface,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Icon(
            icon,
            size: 22,
            color: enabled ? AppColors.primary : ChatLightColors.inkFaint,
          ),
        ),
      ),
    );
  }
}
