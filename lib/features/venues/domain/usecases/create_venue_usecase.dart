import 'dart:io';

import 'package:flutter/foundation.dart';

import '../entities/venue.dart';
import '../repositories/venue_repository.dart';
import '../venue_failure.dart';

/// The validated, normalized fields a create/update call needs — shared
/// with `UpdateVenueUseCase` so the "same validation rules apply"
/// requirement can't drift between the two.
class ValidatedVenueFields {
  final String name;
  final VenueCategory category;
  final double lat;
  final double lng;
  final String address;
  final String? country;
  final OpeningHours openingHours;

  const ValidatedVenueFields({
    required this.name,
    required this.category,
    required this.lat,
    required this.lng,
    required this.address,
    this.country,
    required this.openingHours,
  });
}

/// Matches the 5MB limit enforced by the venue-photo Storage rule.
const maxVenuePhotoBytes = 5 * 1024 * 1024;

List<VenueFieldError> _missingFields({
  required File? photo,
  required bool hasExistingPhoto,
  required String name,
  required VenueCategory? category,
  required double? lat,
  required double? lng,
  required OpeningHours openingHours,
}) {
  final missing = <VenueFieldError>[];
  if (photo == null && !hasExistingPhoto) missing.add(VenueFieldError.photo);
  if (name.trim().isEmpty) missing.add(VenueFieldError.name);
  if (category == null) missing.add(VenueFieldError.category);
  if (lat == null || lng == null) missing.add(VenueFieldError.location);
  if (!openingHours.hasAnyOpenDay) missing.add(VenueFieldError.hours);
  return missing;
}

ValidatedVenueFields validateVenueFields({
  required File? photo,
  required bool hasExistingPhoto,
  required String name,
  required VenueCategory? category,
  required double? lat,
  required double? lng,
  required String address,
  String? country,
  required OpeningHours openingHours,
}) {
  final trimmedName = name.trim();
  final missing = _missingFields(
    photo: photo,
    hasExistingPhoto: hasExistingPhoto,
    name: trimmedName,
    category: category,
    lat: lat,
    lng: lng,
    openingHours: openingHours,
  );

  if (missing.isNotEmpty) {
    throw VenueValidationException(missing);
  }

  return ValidatedVenueFields(
    name: trimmedName,
    category: category!,
    lat: lat!,
    lng: lng!,
    address: address,
    country: country,
    openingHours: openingHours,
  );
}

Future<void> assertValidVenuePhoto(File? photo) async {
  if (photo == null) return;
  final sizeBytes = await photo.length();
  if (sizeBytes == 0 || sizeBytes > maxVenuePhotoBytes) {
    throw ArgumentError('Venue photo must be non-empty and under 5MB.');
  }
}

class CreateVenueUseCase {
  const CreateVenueUseCase(this._repository);

  final VenueRepository _repository;

  Future<String> call({
    required String ownerId,
    required String name,
    required VenueCategory? category,
    required File? photo,
    required double? lat,
    required double? lng,
    required String address,
    String? country,
    required OpeningHours openingHours,
    ValueChanged<double>? onUploadProgress,
    ValueChanged<VoidCallback>? onUploadTaskReady,
  }) async {
    final fields = validateVenueFields(
      photo: photo,
      hasExistingPhoto: false,
      name: name,
      category: category,
      lat: lat,
      lng: lng,
      address: address,
      country: country,
      openingHours: openingHours,
    );

    await assertValidVenuePhoto(photo);

    return _repository.createVenue(
      ownerId: ownerId,
      name: fields.name,
      category: fields.category,
      photo: photo!,
      lat: fields.lat,
      lng: fields.lng,
      address: fields.address,
      country: fields.country,
      openingHours: fields.openingHours,
      onUploadProgress: onUploadProgress,
      onUploadTaskReady: onUploadTaskReady,
    );
  }
}
