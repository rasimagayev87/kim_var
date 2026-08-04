import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Raw Firebase I/O boundary for the offers feature — mirrors
/// `VenueRemoteDatasource`'s exact shape and division of
/// responsibility (this speaks Firestore/Storage primitives only,
/// never the domain `Offer` type).
abstract class OfferRemoteDatasource {
  String allocateOfferId();

  Future<void> setOffer(String offerId, Map<String, dynamic> data);

  Future<void> updateOffer(String offerId, Map<String, dynamic> data);

  Future<void> deleteOffer(String offerId);

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchOffer(String offerId);

  Stream<QuerySnapshot<Map<String, dynamic>>> watchOffersByOwner(String ownerId);

  /// Backs Offer Details' "Digər aktiv təkliflər" — every active offer
  /// at [venueId], the caller (repository) excludes the one currently
  /// being viewed and filters expiry.
  Future<QuerySnapshot<Map<String, dynamic>>> queryByVenue(String venueId);

  /// GeoFlutterFire Plus query, same shape as
  /// `VenueRemoteDatasource.queryWithinRadius` — active offers within
  /// [radiusKm] of ([lat], [lng]), optionally narrowed to one
  /// [category] (the Filter bottom sheet's selection). Does NOT filter
  /// by `endDate` here: Firestore only allows one range/inequality
  /// field per query, and the geohash range GeoFlutterFire itself
  /// needs already claims that slot, so expiry is filtered
  /// client-side by the repository after this returns.
  Future<List<(DocumentSnapshot<Map<String, dynamic>> doc, double distanceKm)>> queryWithinRadius({
    required double lat,
    required double lng,
    required double radiusKm,
    String? category,
  });

  /// Backs "Ölkə üzrə" — mirrors `VenueRemoteDatasource.queryByCountry`.
  Future<QuerySnapshot<Map<String, dynamic>>> queryByCountry(String country, {String? category});

  /// Backs "Dünya üzrə" — mirrors `VenueRemoteDatasource.queryAllActive`.
  Future<QuerySnapshot<Map<String, dynamic>>> queryAllActive({required int limit, String? category});

  Future<String> uploadOfferPhoto(
    String offerId,
    File photo, {
    ValueChanged<double>? onProgress,
    ValueChanged<VoidCallback>? onTaskReady,
  });

  Future<void> deleteOfferPhoto(String offerId);

  /// Realtime set of offer ids the given user has favorited — mirrors
  /// `VenueRemoteDatasource.watchFavoriteVenueIds`, but stored under
  /// its own `favoriteOffers` subcollection rather than reusing
  /// venues' `favorites` one: both venue and offer ids are unrelated
  /// Firestore auto-ids from different collections, and could
  /// theoretically collide if they ever shared one flat id space.
  Stream<Set<String>> watchFavoriteOfferIds(String uid);

  Future<void> setFavorite({
    required String uid,
    required String offerId,
    required bool isFavorite,
  });
}
