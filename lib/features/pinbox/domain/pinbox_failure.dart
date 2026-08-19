/// One entry per missing/invalid required field — mirrors `OfferFieldError`.
enum PinBoxFieldError { photo, title, price, stock, pickupWindow }

class PinBoxValidationException implements Exception {
  final List<PinBoxFieldError> missingFields;
  const PinBoxValidationException(this.missingFields);
}
