import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../location/presentation/providers/location_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../venue_follow/presentation/providers/venue_follow_providers.dart';
import '../../data/live_feed_service.dart';
import '../../domain/entities/live_feed_item.dart';

/// "Canlı" — a presentation-only aggregation of documents that already
/// live in `venues`, `offers`, `venueEvents`, and a venue's own
/// `activeCheckins` subcollection. No new Firestore collection exists
/// for this feature, and [LiveFeedService] never writes anything —
/// this whole module (`lib/features/live_feed/`) reads the exact same
/// data Məkanlar/Təkliflər/Tədbirlər/Növbə already show elsewhere,
/// just re-grouped by "what's happening right now nearby" instead of
/// by module. Deleting this directory removes the entire feature with
/// zero changes required anywhere else in the app.
///
/// Deliberately POLLING, not a set of realtime listeners: this tab
/// would otherwise need five-plus concurrent `.snapshots()` streams
/// per user (venues, offers, events, and one `activeCheckins` listener
/// PER nearby venue) just to stay open — polling on a timer while the
/// tab is actually visible, and stopping entirely once it isn't (see
/// [LiveFeedController.stop], called from the screen's lifecycle
/// hooks in the Faza 2 UI), keeps the steady-state read cost bounded
/// regardless of how long someone leaves the tab open.
final liveFeedServiceProvider = Provider<LiveFeedService>((ref) => LiveFeedService());

/// Refresh cadence for everything except the audience section (Tədbir/
/// Təklif/Boş yer/Doğum günü) — cheap, one geo-query each.
const liveFeedPollInterval = Duration(seconds: 60);

/// "Ətrafınızda" refreshes on its OWN, slower cadence — computing it
/// costs up to 30 extra reads (one `activeCheckins` count per nearby
/// venue, see `LiveFeedService.fetchAudienceItems`), by far the most
/// expensive part of a poll cycle, while also being the section where
/// a couple of minutes' staleness matters least (how many people are
/// somewhere right now is a much softer number than "a new offer just
/// went up"). Explicit product decision, not a default.
const liveFeedAudiencePollInterval = Duration(seconds: 120);

/// How far back an offer/upcoming-event still counts as "fresh" enough
/// to show — audience/seat-availability cards aren't time-windowed
/// this way (they reflect current state, not recent creation), see
/// `LiveFeedService`'s per-section doc comments.
const liveFeedFreshWindow = Duration(hours: 24);

final liveFeedControllerProvider = StateNotifierProvider<LiveFeedController, AsyncValue<List<LiveFeedItem>>>((ref) {
  return LiveFeedController(ref);
});

class LiveFeedController extends StateNotifier<AsyncValue<List<LiveFeedItem>>> {
  LiveFeedController(this._ref) : super(const AsyncValue.loading());

  final Ref _ref;
  Timer? _fastTimer;
  Timer? _audienceTimer;

  List<LiveFeedVenueSnapshot> _lastVenues = [];
  List<LiveFeedItem> _fastItems = [];

  /// Offers/events from "İzlə"-followed `independentArtist` venues —
  /// refreshed on the same cadence as [_fastItems] but via a
  /// completely different query path (see
  /// `LiveFeedService.fetchFollowedVenueItems`'s own doc comment: this
  /// bypasses the viewer's own selected radius on purpose, so it must
  /// run even when [_readLocationParams] returns null for country/
  /// world mode).
  List<LiveFeedItem> _followedVenueItems = [];

  /// Audience ("Ətrafınızda") entries are upserted by
  /// [LiveFeedItem.id] (stable per venue — `audience_<venueId>`, see
  /// `LiveFeedService.fetchAudienceItems`) instead of being replaced
  /// wholesale every 120s cycle. A `Map` preserves insertion order in
  /// Dart, and reassigning an existing key's value doesn't move it —
  /// so a venue's count can update in place (new subtitle, ORIGINAL
  /// timestamp kept, see [_upsertAudienceItems]) without jumping to
  /// the top of `_emit`'s timestamp sort every refresh, which is what
  /// made it look like a fresh "324 nəfər" / "318 nəfər" / "331 nəfər"
  /// card kept getting added on top of the last one. Other item types
  /// don't need this: each carries a real Firestore document id and a
  /// real data timestamp (an offer's `createdAt`, an event's
  /// `startAt`) that's already stable across polls.
  final Map<String, LiveFeedItem> _audienceById = {};

  /// Starts both poll cycles — call from the Canlı screen's
  /// `initState`/`didChangeAppLifecycleState` (resumed), never from a
  /// plain widget `build()`, so it doesn't restart the timers on every
  /// rebuild. The very first audience fetch piggybacks on the first
  /// fast-cycle fetch (reusing the venue list it just fetched) instead
  /// of waiting up to [liveFeedAudiencePollInterval] for its own timer
  /// to fire, so the tab doesn't open with "Ətrafınızda" empty for two
  /// minutes.
  void start() {
    _fastTimer?.cancel();
    _audienceTimer?.cancel();

    unawaited(_runFastCycle(alsoRefreshAudience: true));
    _fastTimer = Timer.periodic(liveFeedPollInterval, (_) => unawaited(_runFastCycle(alsoRefreshAudience: false)));
    _audienceTimer = Timer.periodic(liveFeedAudiencePollInterval, (_) => unawaited(_runAudienceCycle()));
  }

  /// Forces an immediate fetch on the current radius/mode without
  /// resetting the poll timers — call this right after something the
  /// user did (not the timer) changes what a cycle would fetch, e.g.
  /// [selectedDiscoverModeProvider] widening from the empty-state's
  /// "Radiusu artır" button. Without this, that button only took
  /// effect on the NEXT scheduled tick (up to [liveFeedPollInterval]
  /// later), which read as "the button does nothing."
  void refreshNow() {
    unawaited(_runFastCycle(alsoRefreshAudience: true));
  }

  /// Cancels both poll timers — call this when the Canlı screen is
  /// backgrounded/disposed. Doesn't clear [state]: the last-fetched
  /// list stays visible (stale-but-present beats a blank screen) until
  /// [start] is called again and a fresh fetch resolves.
  void stop() {
    _fastTimer?.cancel();
    _audienceTimer?.cancel();
    _fastTimer = null;
    _audienceTimer = null;
  }

  ({double lat, double lng, double radiusKm})? _readLocationParams() {
    final position = _ref.read(locationControllerProvider).valueOrNull;
    if (position == null) return null;
    final selection = _ref.read(selectedDiscoverModeProvider);
    // Same "distance mode only" reasoning as `nearbyEventsProvider` —
    // Canlı is inherently a "what's near me right this minute" tab, so
    // Ölkə/Dünya radius modes (which have no real "nearby" concept)
    // simply show nothing rather than something misleading.
    if (selection.mode != DiscoverRadiusMode.distance || selection.km == null) return null;
    return (lat: position.latitude, lng: position.longitude, radiusKm: selection.km!);
  }

  /// Just the viewer's raw current position, independent of
  /// [selectedDiscoverModeProvider]'s mode — [_readLocationParams]
  /// returns null outside distance mode on purpose (see its own doc
  /// comment), but followed-venue items must still run then, since
  /// bypassing exactly that selection is their entire point.
  ({double lat, double lng})? _readViewerPosition() {
    final position = _ref.read(locationControllerProvider).valueOrNull;
    if (position == null) return null;
    return (lat: position.latitude, lng: position.longitude);
  }

  Future<void> _runFastCycle({required bool alsoRefreshAudience}) async {
    final params = _readLocationParams();
    final viewerPosition = _readViewerPosition();

    try {
      final service = _ref.read(liveFeedServiceProvider);

      var geoItems = <LiveFeedItem>[];
      List<LiveFeedVenueSnapshot>? venues;
      if (params != null) {
        venues = await service.fetchVenueSnapshots(lat: params.lat, lng: params.lng, radiusKm: params.radiusKm);
        _lastVenues = venues;
        final categoryByVenueId = {for (final v in venues) v.id: v.category};
        final photoUrlByVenueId = {for (final v in venues) v.id: v.photoUrl};

        final seatItems = service.seatAvailableItemsFrom(venues);
        final eventItems = await service.fetchEventItems(
          lat: params.lat,
          lng: params.lng,
          radiusKm: params.radiusKm,
          categoryByVenueId: categoryByVenueId,
          photoUrlByVenueId: photoUrlByVenueId,
        );
        final offerItems = await service.fetchOfferAndBirthdayItems(
          lat: params.lat,
          lng: params.lng,
          radiusKm: params.radiusKm,
          myUid: fb.FirebaseAuth.instance.currentUser?.uid,
          freshWindow: liveFeedFreshWindow,
          photoUrlByVenueId: photoUrlByVenueId,
        );
        final pinboxItems = await service.fetchPinBoxItems(
          lat: params.lat,
          lng: params.lng,
          radiusKm: params.radiusKm,
          photoUrlByVenueId: photoUrlByVenueId,
        );
        geoItems = [...seatItems, ...eventItems, ...offerItems, ...pinboxItems];
      }

      var followedItems = <LiveFeedItem>[];
      final followedVenueIds = _ref.read(myFollowedVenueIdsProvider).valueOrNull ?? const [];
      if (viewerPosition != null && followedVenueIds.isNotEmpty) {
        followedItems = await service.fetchFollowedVenueItems(
          followedVenueIds: followedVenueIds,
          viewerLat: viewerPosition.lat,
          viewerLng: viewerPosition.lng,
          viewerCountry: _ref.read(profileControllerProvider).country,
        );
      }

      _fastItems = geoItems;
      _followedVenueItems = followedItems;
      _emit();

      if (alsoRefreshAudience && venues != null) unawaited(_runAudienceCycle(venues: venues));
    } catch (e, st) {
      logError('live_feed_providers.runFastCycle', e, st);
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  Future<void> _runAudienceCycle({List<LiveFeedVenueSnapshot>? venues}) async {
    final rows = venues ?? _lastVenues;
    if (rows.isEmpty) return;

    try {
      final fresh = await _ref.read(liveFeedServiceProvider).fetchAudienceItems(rows);
      _upsertAudienceItems(fresh);
      _emit();
    } catch (e, st) {
      logError('live_feed_providers.runAudienceCycle', e, st);
      // Non-fatal — the rest of the tab (events/offers/seats) still
      // works, so this only skips updating "Ətrafınızda" this round
      // rather than surfacing an error state for the whole screen.
    }
  }

  /// A venue no longer in [fresh] (checkins dropped to 0, or it fell
  /// out of the nearest-30 cutoff) is dropped rather than left stale.
  /// A venue already tracked keeps its original [LiveFeedItem.timestamp]
  /// — only title/subtitle/distance are refreshed — so its position in
  /// `_emit`'s sort doesn't change. A venue seen for the first time is
  /// genuinely new, so it keeps the fresh "now" timestamp and sorts to
  /// the top like any other new item.
  void _upsertAudienceItems(List<LiveFeedItem> fresh) {
    final freshIds = fresh.map((item) => item.id).toSet();
    _audienceById.removeWhere((id, _) => !freshIds.contains(id));

    for (final item in fresh) {
      final existing = _audienceById[item.id];
      _audienceById[item.id] = existing == null
          ? item
          : LiveFeedItem(
              id: item.id,
              type: item.type,
              venueId: item.venueId,
              targetId: item.targetId,
              targetType: item.targetType,
              title: item.title,
              subtitle: item.subtitle,
              distanceMeters: item.distanceMeters,
              timestamp: existing.timestamp,
            );
    }
  }

  void _emit() {
    if (!mounted) return;
    // A followed venue that ALSO happens to fall within the viewer's
    // own normal geo radius would otherwise produce the same offer/
    // event id twice (once from each source) — de-dup by id via a Map
    // before sorting, rather than trying to keep the two sources from
    // ever overlapping in the first place.
    final byId = <String, LiveFeedItem>{};
    for (final item in [..._fastItems, ..._followedVenueItems, ..._audienceById.values]) {
      byId[item.id] = item;
    }
    final merged = byId.values.toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    state = AsyncValue.data(merged);
  }

  @override
  void dispose() {
    _fastTimer?.cancel();
    _audienceTimer?.cancel();
    super.dispose();
  }
}
