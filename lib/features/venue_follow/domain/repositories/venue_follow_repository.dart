/// Venue-level "İzlə" — deliberately separate from
/// `lib/features/follow/` (user-to-user profile follow). Following a
/// venue never touches, shows, or is shown by the owner's personal
/// profile or its own follower/following counts; it only makes that
/// venue's offers/events bypass the viewer's own selected Kəşf/Canlı
/// radius entirely (see `VenueProfileScreen`'s "İzlə" confirm dialog
/// copy) and unlocks push notifications for it — both unconditional,
/// no geographic gate on either side (a venue's `audienceRadiusMode`/
/// `audienceRadiusKm` is unrelated: that field only drives the
/// owner-only "Ətrafda N istifadəçi" live counter, not follow reach).
/// Today only `VenueCategory.independentArtist` venues show the
/// button, but nothing here is category-specific — the gate lives in
/// the UI.
abstract class VenueFollowRepository {
  Stream<bool> watchIsFollowing({required String venueId, required String uid});

  /// Every venue id [uid] currently follows — what the "Canlı"
  /// radius-bypass query starts from.
  Stream<List<String>> watchFollowedVenueIds(String uid);

  Future<void> follow({required String venueId, required String uid});

  Future<void> unfollow({required String venueId, required String uid});
}
