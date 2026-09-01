import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../venues/domain/entities/venue.dart' show VenueCategory;
import '../pinbox_failure.dart';
import '../repositories/pinbox_repository.dart';

/// Same 5MB ceiling as offer/venue photos.
const maxPinBoxPhotoBytes = 5 * 1024 * 1024;

List<PinBoxFieldError> _missingFields({
  required File? photo,
  required String title,
  required double? originalPrice,
  required double? pinboxPrice,
  required int? stockTotal,
  required DateTime? pickupWindowStart,
  required DateTime? pickupWindowEnd,
}) {
  final missing = <PinBoxFieldError>[];
  if (photo == null) missing.add(PinBoxFieldError.photo);
  if (title.trim().isEmpty) missing.add(PinBoxFieldError.title);
  if (originalPrice == null ||
      originalPrice <= 0 ||
      pinboxPrice == null ||
      pinboxPrice <= 0 ||
      pinboxPrice >= originalPrice) {
    missing.add(PinBoxFieldError.price);
  }
  if (stockTotal == null || stockTotal <= 0)
    missing.add(PinBoxFieldError.stock);
  if (pickupWindowStart == null ||
      pickupWindowEnd == null ||
      !pickupWindowEnd.isAfter(pickupWindowStart)) {
    missing.add(PinBoxFieldError.pickupWindow);
  }
  return missing;
}

Future<void> assertValidPinBoxPhoto(File? photo) async {
  if (photo == null) return;
  final sizeBytes = await photo.length();
  if (sizeBytes == 0 || sizeBytes > maxPinBoxPhotoBytes) {
    throw ArgumentError('PinBox photo must be non-empty and under 5MB.');
  }
}

class CreatePinBoxUseCase {
  const CreatePinBoxUseCase(this._repository);

  final PinBoxRepository _repository;

  Future<String> call({
    required String ownerId,
    required String venueId,
    required String venueName,
    String? venuePhotoUrl,
    required double lat,
    required double lng,
    required String address,
    String? country,
    required VenueCategory category,
    required String title,
    required String description,
    required File? photo,
    required double? originalPrice,
    required double? pinboxPrice,
    required int? stockTotal,
    required DateTime? pickupWindowStart,
    required DateTime? pickupWindowEnd,
    ValueChanged<double>? onUploadProgress,
    ValueChanged<VoidCallback>? onUploadTaskReady,
  }) async {
    final missing = _missingFields(
      photo: photo,
      title: title,
      originalPrice: originalPrice,
      pinboxPrice: pinboxPrice,
      stockTotal: stockTotal,
      pickupWindowStart: pickupWindowStart,
      pickupWindowEnd: pickupWindowEnd,
    );
    if (missing.isNotEmpty) throw PinBoxValidationException(missing);

    await assertValidPinBoxPhoto(photo);

    return _repository.createPinBox(
      ownerId: ownerId,
      venueId: venueId,
      venueName: venueName,
      venuePhotoUrl: venuePhotoUrl,
      lat: lat,
      lng: lng,
      address: address,
      country: country,
      category: category,
      title: title.trim(),
      description: description.trim(),
      photo: photo,
      originalPrice: originalPrice!,
      pinboxPrice: pinboxPrice!,
      stockTotal: stockTotal!,
      pickupWindowStart: pickupWindowStart!,
      pickupWindowEnd: pickupWindowEnd!,
      onUploadProgress: onUploadProgress,
      onUploadTaskReady: onUploadTaskReady,
    );
  }
}
