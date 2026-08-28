import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../venues/domain/entities/venue.dart' show VenueCategory;
import '../../domain/entities/venue_event.dart';
import '../../domain/repositories/venue_event_repository.dart';

/// Same GeoFlutterFire Plus convention as `kVenueGeoField`/`kOfferGeoField`
/// — a datasource-level query detail, deliberately not part of the
/// domain [VenueEvent] entity itself (see `Offer`'s own `position`
/// field for the identical reasoning).
const _kEventGeoField = 'position';

class FirebaseVenueEventRepository implements VenueEventRepository {
  FirebaseVenueEventRepository({FirebaseFirestore? firestore, FirebaseStorage? storage})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _events => _firestore.collection('venueEvents');

  /// See `FirebaseVenueRepository._safeVenue`'s doc comment — same
  /// per-document isolation, applied here for `VenueEvent`.
  VenueEvent? _safeEvent(String id, Map<String, dynamic> data) {
    try {
      return VenueEvent.fromFirestore(id, data);
    } catch (e, st) {
      logError('firebase_venue_event_repository.VenueEvent.fromFirestore($id)', e, st);
      return null;
    }
  }

  @override
  Future<String> createEvent({
    required String venueId,
    required String venueName,
    String? venuePhotoUrl,
    required VenueCategory venueCategory,
    required double lat,
    required double lng,
    required String title,
    required String description,
    File? coverImage,
    required DateTime startAt,
    required DateTime endAt,
    required VenueEventCategory category,
    ValueChanged<double>? onUploadProgress,
    ValueChanged<VoidCallback>? onUploadTaskReady,
  }) async {
    final ref = _events.doc();

    String? coverImageUrl;
    if (coverImage != null) {
      final storageRef = _storage.ref('event_covers/${ref.id}.jpg');
      final task = storageRef.putFile(coverImage, SettableMetadata(contentType: 'image/jpeg'));
      onUploadTaskReady?.call(task.cancel);
      if (onUploadProgress != null) {
        task.snapshotEvents.listen((snapshot) {
          if (snapshot.totalBytes > 0) onUploadProgress(snapshot.bytesTransferred / snapshot.totalBytes);
        });
      }
      await task;
      coverImageUrl = await storageRef.getDownloadURL();
    }

    await ref.set({
      'venueId': venueId,
      'venueName': venueName,
      'venuePhotoUrl': venuePhotoUrl,
      'venueCategory': venueCategory.name,
      'lat': lat,
      'lng': lng,
      _kEventGeoField: GeoFirePoint(GeoPoint(lat, lng)).data,
      'title': title,
      'description': description,
      'coverImageUrl': coverImageUrl,
      'startAt': Timestamp.fromDate(startAt),
      'endAt': Timestamp.fromDate(endAt),
      'category': category.name,
      'status': VenueEventStatus.upcoming.name,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return ref.id;
  }

  @override
  Future<void> cancelEvent(String eventId) {
    return _events.doc(eventId).update({'status': VenueEventStatus.cancelled.name});
  }

  @override
  Future<void> updateEvent({
    required String eventId,
    required String title,
    required String description,
    File? coverImage,
    required DateTime startAt,
    required DateTime endAt,
    required VenueEventCategory category,
    ValueChanged<double>? onUploadProgress,
    ValueChanged<VoidCallback>? onUploadTaskReady,
  }) async {
    String? coverImageUrl;
    if (coverImage != null) {
      // Same path convention as create — reusing the event's own id
      // means a re-upload just overwrites the old file, no separate
      // delete step needed.
      final storageRef = _storage.ref('event_covers/$eventId.jpg');
      final task = storageRef.putFile(coverImage, SettableMetadata(contentType: 'image/jpeg'));
      onUploadTaskReady?.call(task.cancel);
      if (onUploadProgress != null) {
        task.snapshotEvents.listen((snapshot) {
          if (snapshot.totalBytes > 0) onUploadProgress(snapshot.bytesTransferred / snapshot.totalBytes);
        });
      }
      await task;
      coverImageUrl = await storageRef.getDownloadURL();
    }

    await _events.doc(eventId).update({
      'title': title,
      'description': description,
      if (coverImageUrl != null) 'coverImageUrl': coverImageUrl,
      'startAt': Timestamp.fromDate(startAt),
      'endAt': Timestamp.fromDate(endAt),
      'category': category.name,
    });
  }

  @override
  Future<void> reportEvent({required String eventId, required String reportedBy, required String reason}) {
    return _firestore.collection('eventReports').add({
      'eventId': eventId,
      'reportedBy': reportedBy,
      'reason': reason,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Stream<VenueEvent?> watchEvent(String eventId) {
    return _events.doc(eventId).snapshots().map((doc) {
      final data = doc.data();
      return data == null ? null : _safeEvent(doc.id, data);
    });
  }

  @override
  Stream<List<VenueEvent>> watchEventsByVenue(String venueId) {
    return _events
        .where('venueId', isEqualTo: venueId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => _safeEvent(d.id, d.data())).whereType<VenueEvent>().toList());
  }

  @override
  Future<bool> hasAnyEvent(String venueId) async {
    final snap = await _events.where('venueId', isEqualTo: venueId).limit(1).get();
    return snap.docs.isNotEmpty;
  }

  @override
  Future<VenueEvent?> fetchTodayEventForVenue(String venueId) async {
    final snap = await _events
        .where('venueId', isEqualTo: venueId)
        .where('status', whereIn: [VenueEventStatus.upcoming.name, VenueEventStatus.live.name])
        .get();
    final events =
        snap.docs.map((d) => _safeEvent(d.id, d.data())).whereType<VenueEvent>().where((e) => e.isToday).toList()
          ..sort((a, b) => a.startAt.compareTo(b.startAt));
    return events.isEmpty ? null : events.first;
  }

  @override
  Future<List<VenueEventWithDistance>> fetchEventsWithinRadius({
    required double lat,
    required double lng,
    required double radiusKm,
    VenueCategory? category,
  }) async {
    final geoCollection = GeoCollectionReference<Map<String, dynamic>>(_events);
    final results = await geoCollection.fetchWithinWithDistance(
      center: GeoFirePoint(GeoPoint(lat, lng)),
      radiusInKm: radiusKm,
      field: _kEventGeoField,
      geopointFrom: (data) => data[_kEventGeoField]['geopoint'] as GeoPoint,
      queryBuilder: (query) {
        var q = query.where('status', whereIn: [VenueEventStatus.upcoming.name, VenueEventStatus.live.name]);
        if (category != null) q = q.where('venueCategory', isEqualTo: category.name);
        return q;
      },
      strictMode: true,
    );
    return results
        .map((r) => (
              event: _safeEvent(r.documentSnapshot.id, r.documentSnapshot.data()!),
              distanceMeters: r.distanceFromCenterInKm * 1000,
            ))
        .where((r) => r.event != null)
        .map((r) => (event: r.event!, distanceMeters: r.distanceMeters))
        .toList();
  }
}
