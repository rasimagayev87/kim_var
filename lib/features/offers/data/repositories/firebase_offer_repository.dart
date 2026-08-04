import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';

import '../../../venues/domain/entities/venue.dart' show VenueCategory;
import '../../domain/entities/offer.dart';
import '../../domain/repositories/offer_repository.dart';
import '../datasources/firebase_offer_remote_datasource.dart';
import '../datasources/offer_remote_datasource.dart';

class FirebaseOfferRepository implements OfferRepository {
  FirebaseOfferRepository({OfferRemoteDatasource? datasource}) : _datasource = datasource ?? FirebaseOfferRemoteDatasource();

  final OfferRemoteDatasource _datasource;

  @override
  Future<String> createOffer({
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
    required OfferType offerType,
    double? discountValue,
    required DateTime startDate,
    required DateTime endDate,
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
    final offerId = _datasource.allocateOfferId();
    String? imageUrl;
    if (photo != null) {
      imageUrl = await _datasource.uploadOfferPhoto(
        offerId,
        photo,
        onProgress: onUploadProgress,
        onTaskReady: onUploadTaskReady,
      );
    }

    await _datasource.setOffer(offerId, {
      'ownerId': ownerId,
      'venueId': venueId,
      'venueName': venueName,
      'venuePhotoUrl': venuePhotoUrl,
      'lat': lat,
      'lng': lng,
      kOfferGeoField: GeoFirePoint(GeoPoint(lat, lng)).data,
      'address': address,
      if (country != null) 'country': country,
      'category': category.name,
      'title': title,
      'description': description,
      'offerType': offerType.name,
      'discountValue': discountValue,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'imageUrl': imageUrl,
      'terms': terms,
      'contactPhone': contactPhone,
      'showContactPhone': showContactPhone,
      'contactWebsite': contactWebsite,
      'showContactWebsite': showContactWebsite,
      'contactInstagram': contactInstagram,
      'showContactInstagram': showContactInstagram,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    });

    return offerId;
  }

  @override
  Future<void> updateOffer({
    required String offerId,
    required VenueCategory category,
    required String title,
    required String description,
    required OfferType offerType,
    double? discountValue,
    required DateTime startDate,
    required DateTime endDate,
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
    String? imageUrl;
    if (photo != null) {
      imageUrl = await _datasource.uploadOfferPhoto(
        offerId,
        photo,
        onProgress: onUploadProgress,
        onTaskReady: onUploadTaskReady,
      );
    }

    await _datasource.updateOffer(offerId, {
      'category': category.name,
      'title': title,
      'description': description,
      'offerType': offerType.name,
      'discountValue': discountValue,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'terms': terms,
      'contactPhone': contactPhone,
      'showContactPhone': showContactPhone,
      'contactWebsite': contactWebsite,
      'showContactWebsite': showContactWebsite,
      'contactInstagram': contactInstagram,
      'showContactInstagram': showContactInstagram,
      'updatedAt': FieldValue.serverTimestamp(),
      if (imageUrl != null) 'imageUrl': imageUrl,
    });
  }

  @override
  Future<void> deleteOffer(String offerId) async {
    await _datasource.deleteOffer(offerId);
    await _datasource.deleteOfferPhoto(offerId);
  }

  @override
  Stream<Offer?> watchOffer(String offerId) {
    return _datasource.watchOffer(offerId).map((doc) => doc.exists ? Offer.fromFirestore(doc.id, doc.data()!) : null);
  }

  @override
  Stream<List<Offer>> watchMyOffers(String ownerId) {
    return _datasource
        .watchOffersByOwner(ownerId)
        .map((snap) => snap.docs.map((d) => Offer.fromFirestore(d.id, d.data())).toList());
  }

  @override
  Future<List<Offer>> fetchOtherActiveOffersForVenue(String venueId, {required String excludeOfferId}) async {
    final snap = await _datasource.queryByVenue(venueId);
    final now = DateTime.now();
    return snap.docs
        .where((d) => d.id != excludeOfferId)
        .map((d) => Offer.fromFirestore(d.id, d.data()))
        .where((offer) => offer.endDate.isAfter(now))
        .toList();
  }

  @override
  Future<List<OfferWithDistance>> fetchOffersWithinRadius({
    required double lat,
    required double lng,
    required double radiusKm,
    VenueCategory? category,
  }) async {
    final results = await _datasource.queryWithinRadius(
      lat: lat,
      lng: lng,
      radiusKm: radiusKm,
      category: category?.name,
    );

    final now = DateTime.now();
    return results
        .map((r) => (offer: Offer.fromFirestore(r.$1.id, r.$1.data()!), distanceMeters: r.$2 * 1000))
        .where((entry) => entry.offer.endDate.isAfter(now))
        .toList();
  }

  @override
  Future<List<Offer>> fetchOffersByCountry(String country, {VenueCategory? category}) async {
    final snap = await _datasource.queryByCountry(country, category: category?.name);
    final now = DateTime.now();
    return snap.docs
        .map((d) => Offer.fromFirestore(d.id, d.data()))
        .where((offer) => offer.endDate.isAfter(now))
        .toList();
  }

  @override
  Future<List<Offer>> fetchAllActiveOffers({int limit = 300, VenueCategory? category}) async {
    final snap = await _datasource.queryAllActive(limit: limit, category: category?.name);
    final now = DateTime.now();
    return snap.docs
        .map((d) => Offer.fromFirestore(d.id, d.data()))
        .where((offer) => offer.endDate.isAfter(now))
        .toList();
  }

  @override
  Stream<Set<String>> watchFavoriteOfferIds(String uid) => _datasource.watchFavoriteOfferIds(uid);

  @override
  Future<void> setFavorite({required String uid, required String offerId, required bool isFavorite}) {
    return _datasource.setFavorite(uid: uid, offerId: offerId, isFavorite: isFavorite);
  }
}
