import 'dart:io';

import 'package:flutter/foundation.dart';

import '../pinbox_failure.dart';
import '../repositories/pinbox_repository.dart';
import 'create_pinbox_usecase.dart' show assertValidPinBoxPhoto;

/// Same fields as [PinBoxFieldError] minus `.stock` — total stock is
/// create-time-only (see [PinBoxRepository.updatePinBox]'s own doc
/// comment), so an edit never has anything to say about it.
List<PinBoxFieldError> _missingFields({
  required bool hasExistingPhoto,
  required File? photo,
  required String title,
  required double? originalPrice,
  required double? pinboxPrice,
  required DateTime? pickupWindowStart,
  required DateTime? pickupWindowEnd,
}) {
  final missing = <PinBoxFieldError>[];
  if (photo == null && !hasExistingPhoto) missing.add(PinBoxFieldError.photo);
  if (title.trim().isEmpty) missing.add(PinBoxFieldError.title);
  if (originalPrice == null ||
      originalPrice <= 0 ||
      pinboxPrice == null ||
      pinboxPrice <= 0 ||
      pinboxPrice >= originalPrice) {
    missing.add(PinBoxFieldError.price);
  }
  if (pickupWindowStart == null || pickupWindowEnd == null || !pickupWindowEnd.isAfter(pickupWindowStart)) {
    missing.add(PinBoxFieldError.pickupWindow);
  }
  return missing;
}

class UpdatePinBoxUseCase {
  const UpdatePinBoxUseCase(this._repository);

  final PinBoxRepository _repository;

  Future<void> call({
    required String pinboxId,
    required String title,
    required String description,
    required File? photo,
    required bool hasExistingPhoto,
    required double? originalPrice,
    required double? pinboxPrice,
    required DateTime? pickupWindowStart,
    required DateTime? pickupWindowEnd,
    ValueChanged<double>? onUploadProgress,
    ValueChanged<VoidCallback>? onUploadTaskReady,
  }) async {
    final missing = _missingFields(
      hasExistingPhoto: hasExistingPhoto,
      photo: photo,
      title: title,
      originalPrice: originalPrice,
      pinboxPrice: pinboxPrice,
      pickupWindowStart: pickupWindowStart,
      pickupWindowEnd: pickupWindowEnd,
    );
    if (missing.isNotEmpty) throw PinBoxValidationException(missing);

    await assertValidPinBoxPhoto(photo);

    await _repository.updatePinBox(
      pinboxId: pinboxId,
      title: title.trim(),
      description: description.trim(),
      originalPrice: originalPrice!,
      pinboxPrice: pinboxPrice!,
      pickupWindowStart: pickupWindowStart!,
      pickupWindowEnd: pickupWindowEnd!,
      photo: photo,
      hasExistingPhoto: hasExistingPhoto,
      onUploadProgress: onUploadProgress,
      onUploadTaskReady: onUploadTaskReady,
    );
  }
}
