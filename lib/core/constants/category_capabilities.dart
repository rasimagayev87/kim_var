import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/venues/domain/entities/venue.dart';

/// Which listing-type features a [VenueCategory] is allowed to use.
/// This is the single source of truth for "offer-only" categories —
/// call sites compose `category.capabilities.canUseX` with whatever
/// category-eligibility mechanism they already use (Firestore config
/// docs for Events/Waitlist, `kPinboxEligibleVenueCategories` for
/// PinBox — see this file's own module doc below), rather than
/// replacing them. A category absent from [kCategoryCapabilities]
/// fails OPEN (every field `true`, via [VenueCategoryCapabilities.capabilities]'s
/// `?? const CategoryCapabilities()` fallback) — a future category this
/// build doesn't know about should never lose access to a feature it
/// was never deliberately restricted from.
///
/// Adding a new restricted category later is exactly one entry in
/// [kCategoryCapabilities] — never a new `if (category == ...)` scattered
/// through the UI.
class CategoryCapabilities {
  const CategoryCapabilities({
    this.canCreateOffers = true,
    this.canCreateEvents = true,
    this.canUsePinBox = true,
    this.canUseWaitlist = true,
    this.canUseQueue = true,
  });

  final bool canCreateOffers;
  final bool canCreateEvents;
  final bool canUsePinBox;
  final bool canUseWaitlist;
  final bool canUseQueue;
}

/// This codebase has no separate "queue" concept distinct from the
/// waitlist/seat-count system — "Növbə" (queue) is the existing
/// Azerbaijani UI label FOR the waitlist feature (see
/// `Venue.waitlistEnabled`'s own doc comment: "Növbəni aktivləşdir/
/// söndür"). [CategoryCapabilities.canUseWaitlist] and [canUseQueue]
/// are kept as two distinct fields to match the product spec's shape,
/// but every call site in this codebase checks them together — there
/// is only one real gate to apply either to.
const _offerOnlyCapabilities = CategoryCapabilities(
  canCreateEvents: false,
  canUsePinBox: false,
  canUseWaitlist: false,
  canUseQueue: false,
);

/// Categories restricted to offers-only. Deliberately small and
/// explicit — every other [VenueCategory] (34 at the time this was
/// written) is absent on purpose, so it falls through to the
/// all-`true` default in [VenueCategoryCapabilities.capabilities] and
/// nothing about its existing behavior changes.
const Map<VenueCategory, CategoryCapabilities> kCategoryCapabilities = {
  VenueCategory.wineHouse: _offerOnlyCapabilities,
  VenueCategory.homeServices: _offerOnlyCapabilities,
  VenueCategory.realEstate: _offerOnlyCapabilities,
};

extension VenueCategoryCapabilities on VenueCategory {
  CategoryCapabilities get capabilities => kCategoryCapabilities[this] ?? const CategoryCapabilities();
}

/// Plain passthrough so UI can `ref.watch(categoryCapabilitiesProvider(category))`
/// where a provider-based read fits the surrounding code better than a
/// direct `.capabilities` call.
final categoryCapabilitiesProvider = Provider.family<CategoryCapabilities, VenueCategory>(
  (ref, category) => category.capabilities,
);
