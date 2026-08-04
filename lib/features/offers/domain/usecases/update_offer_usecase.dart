import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../venues/domain/entities/venue.dart' show VenueCategory;
import '../entities/offer.dart';
import '../repositories/offer_repository.dart';
import 'create_offer_usecase.dart';

class UpdateOfferUseCase {
  const UpdateOfferUseCase(this._repository);

  final OfferRepository _repository;

  Future<void> call({
    required String offerId,
    required String title,
    required String description,
    required VenueCategory? category,
    required OfferType? offerType,
    required double? discountValue,
    required DateTime? startDate,
    required DateTime? endDate,
    File? photo,
    required bool hasExistingPhoto,
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
      hasExistingPhoto: hasExistingPhoto,
      title: title,
      category: category,
      requireVenue: false,
      description: description,
      offerType: offerType,
      discountValue: discountValue,
      startDate: startDate,
      endDate: endDate,
    );

    await assertValidOfferPhoto(photo);

    await _repository.updateOffer(
      offerId: offerId,
      category: fields.category,
      title: fields.title,
      description: fields.description,
      offerType: fields.offerType,
      discountValue: fields.discountValue,
      startDate: fields.startDate,
      endDate: fields.endDate,
      photo: photo,
      hasExistingPhoto: hasExistingPhoto,
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
