import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/payments/epoint_checkout.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../../../settings/map_location/domain/entities/map_location_settings.dart';
import '../../../settings/map_location/presentation/providers/map_location_providers.dart';
import '../../../venues/domain/entities/venue.dart';
import '../../../venues/presentation/screens/create_venue_screen.dart' show venueCategoryLabel;
import '../../../venues/presentation/screens/venue_profile_screen.dart';
import '../../domain/entities/offer.dart';
import '../providers/offer_providers.dart';

/// Full details page for a single offer — opened by tapping a card in
/// Kəşf et → Təkliflər. Watches [offerByIdProvider] (realtime), same
/// reasoning as `VenueProfileScreen`.
class OfferDetailsScreen extends ConsumerWidget {
  final String offerId;

  const OfferDetailsScreen({super.key, required this.offerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final offerAsync = ref.watch(offerByIdProvider(offerId));
    final isFavorite = ref.watch(favoriteOfferIdsProvider.select((async) => async.valueOrNull?.contains(offerId) ?? false));

    return Scaffold(
      backgroundColor: ChatLightColors.bg1,
      body: Stack(
        children: [
          const ChatLightBackground(),
          offerAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.primary)),
            error: (error, _) => _ErrorState(message: '$error'),
            data: (offer) => offer == null
                ? _ErrorState(message: loc.offerNotFoundMessage)
                : _OfferDetailsContent(
                    offer: offer,
                    isFavorite: isFavorite,
                    onToggleFavorite: () =>
                        ref.read(offerControllerProvider).toggleFavorite(offerId, isCurrentlyFavorite: isFavorite),
                  ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            left: 16,
            child: _OverlayCircleButton(
              icon: Icons.arrow_back_ios_new,
              iconSize: 16,
              onTap: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;

  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(message, textAlign: TextAlign.center, style: const TextStyle(color: ChatLightColors.inkSoft)),
      ),
    );
  }
}

class _OfferDetailsContent extends ConsumerWidget {
  final Offer offer;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  const _OfferDetailsContent({required this.offer, required this.isFavorite, required this.onToggleFavorite});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final dateFormat = DateFormat('d MMM yyyy');
    final otherOffersAsync = ref.watch(
      otherOffersForVenueProvider((venueId: offer.venueId, excludeOfferId: offer.id)),
    );

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _HeroImage(offer: offer, isFavorite: isFavorite, onToggleFavorite: onToggleFavorite)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _VenueRow(offer: offer),
                const SizedBox(height: 16),
                _CategoryPill(category: offer.category),
                const SizedBox(height: 12),
                Text(
                  offer.title,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ChatLightColors.ink),
                ),
                const SizedBox(height: 10),
                _OfferValueCard(offer: offer),
                if (offer.offerType == OfferType.firstVisit) ...[
                  const SizedBox(height: 14),
                  _RedeemButton(offer: offer),
                ],
                if (offer.description.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    offer.description,
                    style: const TextStyle(fontSize: 14.5, color: ChatLightColors.ink, height: 1.5),
                  ),
                ],
                if (offer.terms != null && offer.terms!.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    loc.offerTermsLabel,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    offer.terms!,
                    style: TextStyle(fontSize: 13.5, color: ChatLightColors.inkSoft, height: 1.5),
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  loc.offerValidityLabel,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
                ),
                const SizedBox(height: 8),
                _ValidityRow(loc: loc, offer: offer, dateFormat: dateFormat),
                const SizedBox(height: 28),
                Text(
                  loc.venueLocationLabel,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
                ),
                const SizedBox(height: 10),
                _MiniMap(offer: offer),
                const SizedBox(height: 14),
                _DirectionsRow(offer: offer),
                if (offer.address.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    loc.venueFullAddressLabel,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: ChatLightColors.inkSoft),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    offer.address,
                    style: const TextStyle(fontSize: 14.5, color: ChatLightColors.ink, height: 1.4),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => VenueProfileScreen(venueId: offer.venueId)),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    child: Text(loc.offerViewVenueProfileButton, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                otherOffersAsync.maybeWhen(
                  data: (others) {
                    if (others.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc.offerOtherActiveOffersLabel,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
                          ),
                          const SizedBox(height: 10),
                          for (final other in others)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _OtherOfferRow(offer: other),
                            ),
                        ],
                      ),
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroImage extends ConsumerWidget {
  final Offer offer;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  const _HeroImage({required this.offer, required this.isFavorite, required this.onToggleFavorite});

  /// Owner-only — "Təklifi önə çək". Picking a tier opens an Epoint
  /// checkout (`OfferController.createBoostCheckout`); `Offer.boostedUntil`
  /// (which sorts this offer ahead of non-boosted ones in
  /// `nearbyOffersProvider`) is only ever set by `epointWebhook`
  /// (functions/src/index.ts) once that charge is confirmed — never
  /// directly from here, and firestore.rules blocks a direct client
  /// write to it too. Unlike venues (governed purely by user likes —
  /// see `discover_tab.dart`'s `_VenueCard`, which deliberately has no
  /// owner-only menu here at all), a time-boxed paid boost is the
  /// actual product decision for offers specifically.
  Future<void> _openBoostMenu(BuildContext context, WidgetRef ref) async {
    final loc = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
        final sheetLoc = AppLocalizations.of(sheetContext);
        Widget tier(String label, int hours, int priceAzn) => ListTile(
              leading: const Icon(Icons.trending_up_rounded, color: ChatLightColors.ink),
              title: Text(label, style: const TextStyle(fontSize: 15, color: ChatLightColors.ink)),
              trailing: Text(
                sheetLoc.offerBoostPriceSuffix(priceAzn),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
              onTap: () async {
                Navigator.pop(sheetContext);
                final result = await ref.read(offerControllerProvider).createBoostCheckout(offer.id, hours);
                if (result == null) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.offerGenericErrorMessage)));
                  return;
                }
                if (!context.mounted) return;
                await presentEpointCheckout(
                  context,
                  checkoutUrl: result.checkoutUrl,
                  paymentId: result.paymentId,
                  feeAmount: result.feeAmount,
                );
              },
            );
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    sheetLoc.offerBoostMenuItem,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              tier(sheetLoc.offerBoost6h, 6, 2),
              tier(sheetLoc.offerBoost12h, 12, 4),
              tier(sheetLoc.offerBoost18h, 18, 6),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUid = fb.FirebaseAuth.instance.currentUser?.uid;
    final isOwner = currentUid != null && offer.isOwnedBy(currentUid);

    return Stack(
      children: [
        SizedBox(
          height: 240,
          width: double.infinity,
          child: offer.imageUrl != null
              ? Image.network(offer.imageUrl!, fit: BoxFit.cover)
              : Container(
                  color: ChatLightColors.cardSurface,
                  alignment: Alignment.center,
                  child: Icon(venueCategoryIcon(offer.category), size: 64, color: ChatLightColors.inkFaint),
                ),
        ),
        Positioned(
          top: MediaQuery.paddingOf(context).top + 12,
          right: 16,
          child: isOwner
              ? _OverlayCircleButton(
                  icon: Icons.more_vert_outlined,
                  iconSize: 18,
                  onTap: () => _openBoostMenu(context, ref),
                )
              : _OverlayCircleButton(
                  icon: isFavorite ? Icons.favorite : Icons.favorite_border,
                  iconSize: 18,
                  iconColor: isFavorite ? AppColors.primary : Colors.white,
                  onTap: onToggleFavorite,
                ),
        ),
      ],
    );
  }
}

/// Same translucent circular chrome for both the back button and the
/// favorite button.
class _OverlayCircleButton extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final Color iconColor;
  final VoidCallback? onTap;

  const _OverlayCircleButton({required this.icon, required this.iconSize, this.iconColor = Colors.white, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, size: iconSize, color: iconColor),
        ),
      ),
    );
  }
}

class _VenueRow extends StatelessWidget {
  final Offer offer;

  const _VenueRow({required this.offer});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 28,
            height: 28,
            child: offer.venuePhotoUrl != null
                ? Image.network(offer.venuePhotoUrl!, fit: BoxFit.cover)
                : Container(
                    color: ChatLightColors.cardSurface,
                    alignment: Alignment.center,
                    child: Icon(venueCategoryIcon(offer.category), size: 15, color: ChatLightColors.inkSoft),
                  ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            offer.venueName,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.primary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final VenueCategory category;

  const _CategoryPill({required this.category});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: ChatLightColors.cardSurface, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(venueCategoryIcon(category), size: 13, color: ChatLightColors.inkSoft),
          const SizedBox(width: 5),
          Text(
            venueCategoryLabel(loc, category),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ChatLightColors.ink),
          ),
        ],
      ),
    );
  }
}

/// The offer's value, shown large — same per-type color/copy as the
/// list card's `_OfferTypeBadge`, just bigger and full-width here.
class _OfferValueCard extends StatelessWidget {
  final Offer offer;

  const _OfferValueCard({required this.offer});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final (color, text) = switch (offer.offerType) {
      OfferType.discount => (AppColors.primary, '${offer.discountValue?.round() ?? 0}% ${loc.offerBadgeDiscountSuffix}'),
      OfferType.fixedPrice => (AppColors.cyanDark, '${offer.discountValue?.round() ?? 0} ${loc.offerBadgeFixedPriceSuffix}'),
      OfferType.gift => (const Color(0xFFF5A524), loc.offerBadgeGiftLabel),
      OfferType.buyOneGetOne => (const Color(0xFF7C6CF2), '${loc.offerBadgeBuyOneGetOneLabel} ${loc.offerBadgeGiftLabel}'),
      OfferType.happyHour => (
        const Color(0xFFFF6B6B),
        '⏰ ${offer.activeHours != null ? '${offer.activeHours!.start}-${offer.activeHours!.end}' : ''}',
      ),
      OfferType.firstVisit => (const Color(0xFF9B59F5), '🎁 ${loc.offerBadgeFirstVisitLabel}'),
      OfferType.birthday => (const Color(0xFFFF4FA3), '🎂 ${loc.offerBadgeBirthdayLabel}'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
      child: Text(text, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color)),
    );
  }
}

/// The one-time "Aktivləşdir" action for `OfferType.firstVisit` —
/// creates `offers/{offerId}/redemptions/{uid}` on tap, then flips to
/// a disabled "İstifadə edilib" for the rest of this offer's
/// lifetime. Hidden entirely for the offer's own owner, same
/// anti-self-inflation reasoning as `VenueProfileScreen`'s check-in
/// button (an owner "activating" their own first-visit offer isn't a
/// real visit).
class _RedeemButton extends ConsumerStatefulWidget {
  final Offer offer;

  const _RedeemButton({required this.offer});

  @override
  ConsumerState<_RedeemButton> createState() => _RedeemButtonState();
}

class _RedeemButtonState extends ConsumerState<_RedeemButton> {
  bool _submitting = false;

  Future<void> _redeem() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final loc = AppLocalizations.of(context);
    final success = await ref.read(offerControllerProvider).redeemOffer(widget.offer.id);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.offerGenericErrorMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final currentUid = fb.FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null || widget.offer.isOwnedBy(currentUid)) return const SizedBox.shrink();

    final isRedeemed = ref.watch(isOfferRedeemedByMeProvider(widget.offer.id)).valueOrNull ?? false;
    final disabled = isRedeemed || _submitting;

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: disabled ? null : _redeem,
        icon: Icon(isRedeemed ? Icons.check_circle_outline_rounded : Icons.card_giftcard_rounded, size: 18),
        label: Text(isRedeemed ? loc.offerRedeemedButtonLabel : loc.offerRedeemButtonLabel),
        style: ElevatedButton.styleFrom(
          backgroundColor: isRedeemed ? ChatLightColors.cardSurface : const Color(0xFF9B59F5),
          foregroundColor: isRedeemed ? ChatLightColors.inkSoft : Colors.white,
          disabledBackgroundColor: ChatLightColors.cardSurface,
          disabledForegroundColor: ChatLightColors.inkSoft,
        ),
      ),
    );
  }
}

class _ValidityRow extends StatelessWidget {
  final AppLocalizations loc;
  final Offer offer;
  final DateFormat dateFormat;

  const _ValidityRow({required this.loc, required this.offer, required this.dateFormat});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Expanded(
            child: _ValidityDate(label: loc.offerStartDateLabel, date: dateFormat.format(offer.startDate)),
          ),
          Container(width: 1, height: 28, color: ChatLightColors.inkFaint.withValues(alpha: 0.2)),
          Expanded(
            child: _ValidityDate(label: loc.offerEndDateLabel, date: dateFormat.format(offer.endDate)),
          ),
        ],
      ),
    );
  }
}

class _ValidityDate extends StatelessWidget {
  final String label;
  final String date;

  const _ValidityDate({required this.label, required this.date});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11.5, color: ChatLightColors.inkFaint)),
        const SizedBox(height: 3),
        Text(date, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ChatLightColors.ink)),
      ],
    );
  }
}

class _MiniMap extends ConsumerWidget {
  final Offer offer;

  const _MiniMap({required this.offer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mapLocationSettings = ref.watch(mapLocationSettingsProvider).valueOrNull ?? const MapLocationSettings();
    final center = LatLng(offer.lat, offer.lng);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 160,
        child: IgnorePointer(
          child: GoogleMap(
            initialCameraPosition: CameraPosition(target: center, zoom: 15.5),
            mapType: toGoogleMapType(mapLocationSettings.mapType),
            markers: {Marker(markerId: const MarkerId('offer'), position: center)},
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            zoomGesturesEnabled: false,
            scrollGesturesEnabled: false,
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
          ),
        ),
      ),
    );
  }
}

class _DirectionsRow extends StatelessWidget {
  final Offer offer;

  const _DirectionsRow({required this.offer});

  Future<void> _open(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final lat = offer.lat;
    final lng = offer.lng;

    return Row(
      children: [
        Expanded(
          child: _DirectionsButton(
            icon: Icons.map_outlined,
            label: loc.venueDirectionsGoogleMaps,
            onTap: () => _open('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _DirectionsButton(
            icon: Icons.map_outlined,
            label: loc.venueDirectionsAppleMaps,
            onTap: () => _open('https://maps.apple.com/?daddr=$lat,$lng'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _DirectionsButton(
            icon: Icons.navigation_outlined,
            label: loc.venueDirectionsWaze,
            onTap: () => _open('https://waze.com/ul?ll=$lat,$lng&navigate=yes'),
          ),
        ),
      ],
    );
  }
}

class _DirectionsButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DirectionsButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ChatLightColors.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OtherOfferRow extends StatelessWidget {
  final Offer offer;

  const _OtherOfferRow({required this.offer});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => OfferDetailsScreen(offerId: offer.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: offer.imageUrl != null
                      ? Image.network(offer.imageUrl!, fit: BoxFit.cover)
                      : Container(
                          color: ChatLightColors.cardSurface,
                          alignment: Alignment.center,
                          child: Icon(venueCategoryIcon(offer.category), size: 18, color: ChatLightColors.inkSoft),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  offer.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: ChatLightColors.ink),
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
