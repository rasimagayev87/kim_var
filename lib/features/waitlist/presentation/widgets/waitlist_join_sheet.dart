import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/widgets/country_dial_code.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../providers/waitlist_providers.dart';

const _kMinPartySize = 1;
const _kMaxPartySize = 10;
const _kNoteMaxLength = 150;

/// "Sıraya yaz" sheet, opened from the "Sıraya yaz" button on
/// `VenueProfileScreen`. Asks for a phone number (required — the venue
/// may call about the queue; no OTP verification, just an honesty
/// nudge via the helper text below the field) and an optional note,
/// party size last. Pops `true` on a successful join so the caller can
/// react (there's nothing to react to today beyond the sheet closing —
/// `myWaitlistEntryProvider`'s stream picks up the new entry on its
/// own — but keeping the bool return matches this codebase's other
/// confirm-sheet conventions).
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
  final _phoneController = TextEditingController();
  final _noteController = TextEditingController();

  /// Same list/type as the OTP flow's `PhoneNumberEntryStep` — no new
  /// country data, just this sheet's own country-picker state, since
  /// this isn't part of that flow (no SMS ever sent here).
  CountryDialCode _country = kCountryDialCodes.first;
  String? _phoneError;
  int _partySize = 2;
  bool _joining = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _pickCountry() {
    final loc = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.6,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Text(loc.pickCountryTitle, style: AppTextStyles.cardTitle.copyWith(fontWeight: FontWeight.w700)),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: kCountryDialCodes.length,
                    itemBuilder: (context, index) {
                      final country = kCountryDialCodes[index];
                      return ListTile(
                        leading: Text(country.flag, style: const TextStyle(fontSize: 22)),
                        title: Text(country.name, style: const TextStyle(fontSize: 15.5, color: ChatLightColors.ink)),
                        trailing: Text(country.dialCode, style: const TextStyle(color: ChatLightColors.inkSoft)),
                        onTap: () {
                          setState(() => _country = country);
                          Navigator.pop(sheetContext);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _join() async {
    // Same minimal length gate `PhoneNumberEntryStep` itself uses
    // (`digits.length < 7`) — reusing that flow's own validation
    // threshold rather than inventing a stricter one.
    final digits = _phoneController.text.trim();
    final loc = AppLocalizations.of(context);
    if (digits.length < 7) {
      setState(() => _phoneError = loc.venueFieldRequiredError);
      return;
    }

    setState(() {
      _joining = true;
      _phoneError = null;
    });

    final note = _noteController.text.trim();
    final ok = await ref.read(waitlistControllerProvider).join(
          venueId: widget.venueId,
          partySize: _partySize,
          // Same naive concatenation `PhoneNumberEntryStep` uses —
          // valid E.164 as long as the user doesn't type a leading 0.
          phoneNumber: '${_country.dialCode}$digits',
          note: note.isEmpty ? null : note,
        );
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
            Text(loc.waitlistJoinSheetTitle, style: AppTextStyles.cardTitle.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            _FieldLabel(loc.waitlistPhoneLabel),
            Row(
              children: [
                GestureDetector(
                  onTap: _pickCountry,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadii.input),
                      border: Border.all(color: ChatLightColors.inkFaint.withValues(alpha: 0.18)),
                    ),
                    child: Row(
                      children: [
                        Text(_country.flag, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 6),
                        Text(_country.dialCode, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: ChatLightColors.ink)),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down_outlined, size: 18, color: ChatLightColors.inkSoft),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(fontSize: 15.5, color: ChatLightColors.ink),
                    decoration: InputDecoration(hintText: loc.phoneAuthNumberHint, filled: true, fillColor: Colors.white),
                    onChanged: (_) {
                      if (_phoneError != null) setState(() => _phoneError = null);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(loc.waitlistPhoneHelperText, style: AppTextStyles.caption.copyWith(height: 1.3)),
            if (_phoneError != null) ...[
              const SizedBox(height: 4),
              Text(_phoneError!, style: AppTextStyles.caption.copyWith(color: AppColors.error)),
            ],
            const SizedBox(height: 18),
            _FieldLabel(loc.waitlistNoteLabel),
            TextField(
              controller: _noteController,
              maxLines: 3,
              maxLength: _kNoteMaxLength,
              style: const TextStyle(fontSize: 15, color: ChatLightColors.ink),
              decoration: InputDecoration(hintText: loc.waitlistNoteHint, filled: true, fillColor: Colors.white),
            ),
            const SizedBox(height: 10),
            _FieldLabel(loc.waitlistPartySizeSheetTitle),
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

class _FieldLabel extends StatelessWidget {
  final String label;

  const _FieldLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: ChatLightColors.ink)),
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
