import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';

import '../../domain/entities/venue.dart';
import '../../domain/repositories/venue_repository.dart';
import '../datasources/firebase_venue_remote_datasource.dart';
import '../datasources/venue_remote_datasource.dart';

/// Maps between the domain `Venue` model and [VenueRemoteDatasource]'s
/// raw Firestore/Storage primitives — this class owns "what shape does
/// a venue document have" and "how do I turn form input into that
/// shape", while the datasource just persists/queries whatever map
/// it's handed.
class FirebaseVenueRepository implements VenueRepository {
  FirebaseVenueRepository({VenueRemoteDatasource? datasource}) : _datasource = datasource ?? FirebaseVenueRemoteDatasource();

  final VenueRemoteDatasource _datasource;

  @override
  Future<String> createVenue({
    required String ownerId,
    required String name,
    required VenueCategory category,
    required File photo,
    required double lat,
    required double lng,
    required String address,
    String? country,
    required OpeningHours openingHours,
    ValueChanged<double>? onUploadProgress,
    ValueChanged<VoidCallback>? onUploadTaskReady,
  }) async {
    final venueId = _datasource.allocateVenueId();
    final photoUrl = await _datasource.uploadVenuePhoto(
      venueId,
      photo,
      onProgress: onUploadProgress,
      onTaskReady: onUploadTaskReady,
    );

    await _datasource.setVenue(venueId, {
      'ownerId': ownerId,
      'name': name,
      'category': category.name,
      'photoUrl': photoUrl,
      'lat': lat,
      'lng': lng,
      kVenueGeoField: GeoFirePoint(GeoPoint(lat, lng)).data,
      'address': address,
      if (country != null) 'country': country,
      'openingHours': openingHours.toMap(),
      'status': 'active',
      'verified': false,
      'favoriteCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return venueId;
  }

  @override
  Future<void> updateVenue({
    required String venueId,
    required String name,
    required VenueCategory category,
    File? photo,
    required double lat,
    required double lng,
    required String address,
    String? country,
    required OpeningHours openingHours,
    ValueChanged<double>? onUploadProgress,
    ValueChanged<VoidCallback>? onUploadTaskReady,
  }) async {
    String? photoUrl;
    if (photo != null) {
      photoUrl = await _datasource.uploadVenuePhoto(
        venueId,
        photo,
        onProgress: onUploadProgress,
        onTaskReady: onUploadTaskReady,
      );
    }

    await _datasource.updateVenue(venueId, {
      'name': name,
      'category': category.name,
      'lat': lat,
      'lng': lng,
      kVenueGeoField: GeoFirePoint(GeoPoint(lat, lng)).data,
      'address': address,
      'country': country,
      'openingHours': openingHours.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (photoUrl != null) 'photoUrl': photoUrl,
    });
  }

  @override
  Future<void> deleteVenue(String venueId) async {
    await _datasource.deleteVenue(venueId);
    await _datasource.deleteVenuePhoto(venueId);
  }

  @override
  Stream<Venue?> watchVenue(String venueId) {
    return _datasource.watchVenue(venueId).map((doc) => doc.exists ? Venue.fromFirestore(doc.id, doc.data()!) : null);
  }

  @override
  Stream<List<Venue>> watchMyVenues(String ownerId) {
    return _datasource
        .watchVenuesByOwner(ownerId)
        .map((snap) => snap.docs.map((d) => Venue.fromFirestore(d.id, d.data())).toList());
  }

  @override
  Future<List<VenueWithDistance>> fetchVenuesWithinRadius({
    required double lat,
    required double lng,
    required double radiusKm,
    VenueCategory? category,
  }) async {
    final results = await _datasource.queryWithinRadius(lat: lat, lng: lng, radiusKm: radiusKm, category: category?.name);
    return results
        .map(
          (r) => (
            venue: Venue.fromFirestore(r.$1.id, r.$1.data()!),
            distanceMeters: r.$2 * 1000,
          ),
        )
        .toList();
  }

  @override
  Future<List<Venue>> fetchVenuesByCountry(String country, {VenueCategory? category}) async {
    final snap = await _datasource.queryByCountry(country, category: category?.name);
    return snap.docs.map((d) => Venue.fromFirestore(d.id, d.data())).toList();
  }

  @override
  Future<List<Venue>> fetchAllActiveVenues({int limit = 300, VenueCategory? category}) async {
    final snap = await _datasource.queryAllActive(limit: limit, category: category?.name);
    return snap.docs.map((d) => Venue.fromFirestore(d.id, d.data())).toList();
  }

  @override
  Stream<Set<String>> watchFavoriteVenueIds(String uid) => _datasource.watchFavoriteVenueIds(uid);

  @override
  Future<void> setFavorite({required String uid, required String venueId, required bool isFavorite}) {
    return _datasource.setFavorite(uid: uid, venueId: venueId, isFavorite: isFavorite);
  }
}
