/// One entry per missing/invalid required field — lets the form tell
/// the user exactly what's not filled in, rather than one generic
/// "fill out the form" message. Mirrors `EventFieldError`'s role in
/// the events feature.
enum VenueFieldError { photo, name, category, location, hours }

class VenueValidationException implements Exception {
  final List<VenueFieldError> missingFields;
  const VenueValidationException(this.missingFields);
}
