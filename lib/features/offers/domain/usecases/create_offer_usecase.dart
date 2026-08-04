import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../venues/domain/entities/venue.dart' show VenueCategory;
import '../entities/offer.dart';
import '../offer_failure.dart';
import '../repositories/offer_repository.dart';

/// The validated, normalized fields a create/update call needs —
/// mirrors `ValidatedVenueFields`'s role for venues.
class ValidatedOfferFields {
  final String title;
  final String description;
  final VenueCategory category;
  final OfferType offerType;
  final double? discountValue;
  final DateTime startDate;
  final DateTime endDate;

  const ValidatedOfferFields({
    required this.title,
    required this.description,
    required this.category,
    required this.offerType,
    required this.discountValue,
    required this.startDate,
    required this.endDate,
  });
}

/// Matches the 5MB limit enforced by the offer-photo Storage rule —
/// same ceiling as venue photos.
const maxOfferPhotoBytes = 5 * 1024 * 1024;

List<OfferFieldError> _missingFields({
  required File? photo,
  required bool hasExistingPhoto,
  required String title,
  required VenueCategory? category,
  required bool requireVenue,
  required String? venueId,
  required OfferType? offerType,
  required double? discountValue,
  required DateTime? startDate,
  required DateTime? endDate,
}) {
  final missing = <OfferFieldError>[];
  if (photo == null && !hasExistingPhoto) missing.add(OfferFieldError.photo);
  if (title.trim().isEmpty) missing.add(OfferFieldError.title);
  if (category == null) missing.add(OfferFieldError.category);
  if (requireVenue && (venueId == null || venueId.isEmpty)) missing.add(OfferFieldError.venue);
  if (offerType == null) missing.add(OfferFieldError.offerType);
  if ((offerType == OfferType.discount || offerType == OfferType.fixedPrice) && discountValue == null) {
    missing.add(OfferFieldError.discountValue);
  }
  if (startDate == null || endDate == null || endDate.isBefore(startDate)) {
    missing.add(OfferFieldError.dates);
  }
  return missing;
}

/// [venueId] only matters (and is validated as required) when
/// [requireVenue] is true — the Create form must have a venue picked,
/// but Update never re-picks one (mirrors `Venue`'s own create/update
/// asymmetry: location can't change after creation there either), so
/// the update call site simply never passes a [venueId] worth checking.
ValidatedOfferFields validateOfferFields({
  required File? photo,
  required bool hasExistingPhoto,
  required String title,
  required VenueCategory? category,
  bool requireVenue = true,
  String? venueId,
  required String description,
  required OfferType? offerType,
  required double? discountValue,
  required DateTime? startDate,
  required DateTime? endDate,
}) {
  final trimmedTitle = title.trim();
  final missing = _missingFields(
    photo: photo,
    hasExistingPhoto: hasExistingPhoto,
    title: trimmedTitle,
    category: category,
    requireVenue: requireVenue,
    venueId: venueId,
    offerType: offerType,
    discountValue: discountValue,
    startDate: startDate,
    endDate: endDate,
  );

  if (missing.isNotEmpty) {
    throw OfferValidationException(missing);
  }

  return ValidatedOfferFields(
    title: trimmedTitle,
    description: description.trim(),
    category: category!,
    offerType: offerType!,
    discountValue: offerType == OfferType.discount || offerType == OfferType.fixedPrice ? discountValue : null,
    startDate: startDate!,
    endDate: endDate!,
  );
}

Future<void> assertValidOfferPhoto(File? photo) async {
  if (photo == null) return;
  final sizeBytes = await photo.length();
  if (sizeBytes == 0 || sizeBytes > maxOfferPhotoBytes) {
    throw ArgumentError('Offer photo must be non-empty and under 5MB.');
  }
}

class CreateOfferUseCase {
  const CreateOfferUseCase(this._repository);

  final OfferRepository _repository;

  Future<String> call({
    required String ownerId,
    required String? venueId,
    required String venueName,
    String? venuePhotoUrl,
    required double? lat,
    required double? lng,
    required String address,
    String? country,
    required String title,
    required String description,
    required VenueCategory? category,
    required OfferType? offerType,
    required double? discountValue,
    required DateTime? startDate,
    required DateTime? endDate,
    required File? photo,
    String? terms,
    String? contactPhone,
    bool showContactPhone = false,
    String? contactWebsite,
    bool showContactWebsite = false,
    String? contactInstagram,
    bool showContactInstagram = false,
    ValueChanged<double>? onUploadProgress,
    ValueChanged<VoidCallback>? onUploadTaskReady,
  }) async {
    final fields = validateOfferFields(
      photo: photo,
      hasExistingPhoto: false,
      title: title,
      category: category,
      venueId: venueId,
      description: description,
      offerType: offerType,
      discountValue: discountValue,
      startDate: startDate,
      endDate: endDate,
    );

    await assertValidOfferPhoto(photo);

    return _repository.createOffer(
      ownerId: ownerId,
      venueId: venueId!,
      venueName: venueName,
      venuePhotoUrl: venuePhotoUrl,
      lat: lat!,
      lng: lng!,
      address: address,
      country: country,
      category: fields.category,
      title: fields.title,
      description: fields.description,
      offerType: fields.offerType,
      discountValue: fields.discountValue,
      startDate: fields.startDate,
      endDate: fields.endDate,
      photo: photo,
      terms: terms,
      contactPhone: contactPhone,
      showContactPhone: showContactPhone,
      contactWebsite: contactWebsite,
      showContactWebsite: showContactWebsite,
      contactInstagram: contactInstagram,
      showContactInstagram: showContactInstagram,
      onUploadProgress: onUploadProgress,
      onUploadTaskReady: onUploadTaskReady,
    );
  }
}
