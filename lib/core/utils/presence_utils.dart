/// Single source of truth for "is this user currently online" —
/// someone only counts as online if the presence system marked them
/// so AND their last heartbeat/lifecycle write is recent enough that
/// a stale write (a force-quit or crash that never got to write
/// `online: false`) doesn't leave them stuck "online" forever. See
/// `presence_provider.dart` for the write side (heartbeat interval +
/// background grace period), which this threshold needs to
/// comfortably exceed.
const kOnlineStalenessThreshold = Duration(seconds: 90);

bool isRecentlyOnline({required bool online, required DateTime? lastSeen}) {
  if (!online || lastSeen == null) return false;
  return DateTime.now().difference(lastSeen) <= kOnlineStalenessThreshold;
}
