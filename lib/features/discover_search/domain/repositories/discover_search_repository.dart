import '../../../profile/domain/entities/public_profile.dart';
import '../../../venues/domain/entities/venue.dart';

abstract class DiscoverSearchRepository {
  /// Users whose `@username` starts with [query] (case-insensitive) —
  /// the primary search key. Backed by the `usernames` reservation
  /// collection's own document IDs (already lowercase, since that's
  /// how username uniqueness is enforced), so this needs no backfill
  /// to work on every existing account, unlike [searchUsersByName].
  Future<List<PublicProfile>> searchUsersByUsername(
    String query, {
    int limit = 20,
  });

  /// Users whose first+last name starts with [query] (case-insensitive).
  /// Backed by `users.nameLower`, written at onboarding/profile-edit
  /// time — an account that predates this field won't match until it
  /// next saves its profile.
  Future<List<PublicProfile>> searchUsersByName(String query, {int limit = 20});

  /// Approved venues whose name starts with [query] (case-insensitive).
  /// Same `nameLower`/backfill caveat as [searchUsersByName].
  Future<List<Venue>> searchVenues(String query, {int limit = 20});
}
