import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';

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

  @override
  Future<String> createEvent({
    required String venueId,
    required String venueName,
    String? venuePhotoUrl,
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
      return data == null ? null : VenueEvent.fromFirestore(doc.id, data);
    });
  }

  @override
  Stream<List<VenueEvent>> watchEventsByVenue(String venueId) {
    return _events
        .where('venueId', isEqualTo: venueId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => VenueEvent.fromFirestore(d.id, d.data())).toList());
  }

  @override
  Future<VenueEvent?> fetchTodayEventForVenue(String venueId) async {
    final snap = await _events
        .where('venueId', isEqualTo: venueId)
        .where('status', whereIn: [VenueEventStatus.upcoming.name, VenueEventStatus.live.name])
        .get();
    final events = snap.docs.map((d) => VenueEvent.fromFirestore(d.id, d.data())).where((e) => e.isToday).toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    return events.isEmpty ? null : events.first;
  }

  @override
  Future<List<VenueEventWithDistance>> fetchEventsWithinRadius({required double lat, required double lng, required double radiusKm}) async {
    final geoCollection = GeoCollectionReference<Map<String, dynamic>>(_events);
    final results = await geoCollection.fetchWithinWithDistance(
      center: GeoFirePoint(GeoPoint(lat, lng)),
      radiusInKm: radiusKm,
      field: _kEventGeoField,
      geopointFrom: (data) => data[_kEventGeoField]['geopoint'] as GeoPoint,
      queryBuilder: (query) => query.where('status', whereIn: [VenueEventStatus.upcoming.name, VenueEventStatus.live.name]),
      strictMode: true,
    );
    return results
        .map((r) => (
              event: VenueEvent.fromFirestore(r.documentSnapshot.id, r.documentSnapshot.data()!),
              distanceMeters: r.distanceFromCenterInKm * 1000,
            ))
        .toList();
  }
}
