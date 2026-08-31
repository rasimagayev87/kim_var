import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bottom-nav tab indices, by name rather than by magic number.
///
/// `HomeScreen` renders these in an `IndexedStack`; the order here is
/// that stack's order.
class HomeTab {
  static const discover = 0;
  static const chats = 1;
  static const live = 2;
  static const notifications = 3;
  static const profile = 4;
}

/// A request to switch `HomeScreen`'s bottom-nav tab from somewhere
/// that is not `HomeScreen`.
///
/// Exists for the daily digest notification, whose destination is the
/// Canlı tab rather than a single document: "Ətrafında 5 yeni
/// kampaniya" is about five different listings, so there is nothing to
/// push a detail route for. Every other notification type names one
/// document and navigates with `Navigator.push`.
///
/// A one-shot signal, not persisted state: `HomeScreen` consumes it and
/// writes `null` back. Left as a plain index it would re-fire the tab
/// switch on every unrelated rebuild, and the user could never navigate
/// away from Canlı.
final requestedHomeTabProvider = StateProvider<int?>((ref) => null);
