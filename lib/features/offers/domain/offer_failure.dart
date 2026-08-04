/// One entry per missing/invalid required field — mirrors
/// `VenueFieldError`'s role in the venues feature.
enum OfferFieldError { photo, title, category, venue, offerType, discountValue, dates }

class OfferValidationException implements Exception {
  final List<OfferFieldError> missingFields;
  const OfferValidationException(this.missingFields);
}
