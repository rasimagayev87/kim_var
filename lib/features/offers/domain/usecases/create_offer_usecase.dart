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
  final ActiveHours? activeHours;
  final List<String> activeDays;

  const ValidatedOfferFields({
    required this.title,
    required this.description,
    required this.category,
    required this.offerType,
    required this.discountValue,
    required this.startDate,
    required this.endDate,
    required this.activeHours,
    required this.activeDays,
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
  required ActiveHours? activeHours,
  required List<String> activeDays,
}) {
  final missing = <OfferFieldError>[];
  if (photo == null && !hasExistingPhoto) missing.add(OfferFieldError.photo);
  if (title.trim().isEmpty) missing.add(OfferFieldError.title);
  if (category == null) missing.add(OfferFieldError.category);
  if (requireVenue && (venueId == null || venueId.isEmpty))
    missing.add(OfferFieldError.venue);
  if (offerType == null) missing.add(OfferFieldError.offerType);
  const typesWithDiscountValue = {
    OfferType.discount,
    OfferType.fixedPrice,
    OfferType.happyHour,
    OfferType.firstVisit,
    OfferType.birthday,
  };
  if (typesWithDiscountValue.contains(offerType) && discountValue == null) {
    missing.add(OfferFieldError.discountValue);
  }
  if (offerType == OfferType.happyHour &&
      (activeHours == null || activeDays.isEmpty)) {
    missing.add(OfferFieldError.activeHours);
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
  ActiveHours? activeHours,
  List<String> activeDays = const [],
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
    activeHours: activeHours,
    activeDays: activeDays,
  );

  if (missing.isNotEmpty) {
    throw OfferValidationException(missing);
  }

  final isHappyHour = offerType == OfferType.happyHour;
  const typesWithDiscountValue = {
    OfferType.discount,
    OfferType.fixedPrice,
    OfferType.happyHour,
    OfferType.firstVisit,
    OfferType.birthday,
  };
  return ValidatedOfferFields(
    title: trimmedTitle,
    description: description.trim(),
    category: category!,
    offerType: offerType!,
    discountValue: typesWithDiscountValue.contains(offerType)
        ? discountValue
        : null,
    startDate: startDate!,
    endDate: endDate!,
    activeHours: isHappyHour ? activeHours : null,
    activeDays: isHappyHour ? activeDays : const [],
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

  /// [category] is only used for this call's own client-side validation
  /// (matching [OfferFieldError.category] to the UI's "pick a venue
  /// first" state) — the actual offer's category, along with
  /// venueName/venuePhotoUrl/lat/lng/address/country, is derived
  /// server-side from the venue doc by `submitOffer` (Cloud Function),
  /// never trusted from here. See [OfferRepository.createOffer]'s own
  /// doc comment for why.
  Future<SubmitOfferResult> call({
    required String? venueId,
    required String title,
    required String description,
    required VenueCategory? category,
    required OfferType? offerType,
    required double? discountValue,
    required DateTime? startDate,
    required DateTime? endDate,
    required File? photo,
    String? terms,
    ActiveHours? activeHours,
    List<String> activeDays = const [],
    String? birthdayMatchId,
    List<String> targetUserIds = const [],
    String? personalMessage,
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
      activeHours: activeHours,
      activeDays: activeDays,
    );

    await assertValidOfferPhoto(photo);

    return _repository.createOffer(
      venueId: venueId!,
      title: fields.title,
      description: fields.description,
      offerType: fields.offerType,
      discountValue: fields.discountValue,
      startDate: fields.startDate,
      endDate: fields.endDate,
      photo: photo,
      terms: terms,
      activeHours: fields.activeHours,
      activeDays: fields.activeDays,
      birthdayMatchId: fields.offerType == OfferType.birthday
          ? birthdayMatchId
          : null,
      targetUserIds: fields.offerType == OfferType.birthday
          ? targetUserIds
          : const [],
      personalMessage: fields.offerType == OfferType.birthday
          ? personalMessage
          : null,
      onUploadProgress: onUploadProgress,
      onUploadTaskReady: onUploadTaskReady,
    );
  }
}
