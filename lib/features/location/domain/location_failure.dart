enum LocationFailure { serviceDisabled, permissionDenied, permissionDeniedForever }

class LocationException implements Exception {
  final LocationFailure type;
  const LocationException(this.type);
}
