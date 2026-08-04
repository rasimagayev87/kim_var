import 'dart:io';

import 'package:flutter/foundation.dart';

import '../entities/venue.dart';
import '../repositories/venue_repository.dart';
import 'create_venue_usecase.dart';

class UpdateVenueUseCase {
  const UpdateVenueUseCase(this._repository);

  final VenueRepository _repository;

  Future<void> call({
    required String venueId,
    required String name,
    required VenueCategory? category,
    File? photo,
    required bool hasExistingPhoto,
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
      hasExistingPhoto: hasExistingPhoto,
      name: name,
      category: category,
      lat: lat,
      lng: lng,
      address: address,
      country: country,
      openingHours: openingHours,
    );

    await assertValidVenuePhoto(photo);

    return _repository.updateVenue(
      venueId: venueId,
      name: fields.name,
      category: fields.category,
      photo: photo,
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
