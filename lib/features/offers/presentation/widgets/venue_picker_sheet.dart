import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../../../venues/domain/entities/venue.dart';
import '../../../venues/presentation/providers/venue_providers.dart';
import '../../../venues/presentation/screens/create_venue_screen.dart' show venueCategoryLabel;

/// "Məkan seç" step of Create Offer — lists only the signed-in user's
/// own venues ([myVenuesProvider]), since an offer can only ever
/// belong to a venue its creator owns. Pops the full [Venue] (not just
/// an id) so the caller can denormalize name/photo/address/position
/// without a second read.
///
/// [venues]/[label] let other callers (e.g. Discover's "Mənim
/// tədbirlərim" icon, PinBox Faza 3's "Qutu yarat" flow) reuse this same
/// sheet with a pre-filtered venue list and their own heading instead of
/// the unfiltered "Məkan seçin" — [venues] null falls back to watching
/// [myVenuesProvider] directly, unchanged from the original behavior.
class VenuePickerSheet extends ConsumerWidget {
  final List<Venue>? venues;
  final String? label;

  const VenuePickerSheet({super.key, this.venues, this.label});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final venuesAsync = venues != null ? AsyncValue.data(venues!) : ref.watch(myVenuesProvider);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: ChatLightColors.inkFaint.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              label ?? loc.offerVenuePickerLabel,
              style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: venuesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.primary)),
                ),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text('$error', style: TextStyle(color: ChatLightColors.inkSoft)),
                ),
                data: (venues) {
                  if (venues.isEmpty) return _NoVenuesState(loc: loc);
                  return ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    itemCount: venues.length,
                    itemBuilder: (context, index) => _VenueRow(venue: venues[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VenueRow extends StatelessWidget {
  final Venue venue;

  const _VenueRow({required this.venue});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.pop(context, venue),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: venue.photoUrl != null
                      ? AppImage(venue.photoUrl!, thumbnail: true, fit: BoxFit.cover)
                      : Container(
                          color: ChatLightColors.cardSurface,
                          alignment: Alignment.center,
                          child: Icon(venueCategoryIcon(venue.category), size: 20, color: ChatLightColors.inkSoft),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      venue.name,
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      venue.address.isNotEmpty ? venue.address : venueCategoryLabel(loc, venue.category),
                      style: TextStyle(fontSize: 12.5, color: ChatLightColors.inkSoft),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: ChatLightColors.inkFaint),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoVenuesState extends StatelessWidget {
  final AppLocalizations loc;

  const _NoVenuesState({required this.loc});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withValues(alpha: 0.1)),
            child: const Icon(Icons.storefront_outlined, color: AppColors.primary, size: 32),
          ),
          const SizedBox(height: 18),
          Text(
            loc.offerNoVenuesTitle,
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            loc.offerNoVenuesSubtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: ChatLightColors.inkSoft, height: 1.5),
          ),
        ],
      ),
    );
  }
}
