import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webrtc_interface/webrtc_interface.dart' show MediaStream;

import '../../data/firebase_call_repository.dart';
import '../../domain/call_repository.dart';
import '../../domain/entities/call_session.dart';

/// Every call site in the app goes through this provider, not
/// `FirebaseCallRepository` directly.
final callRepositoryProvider = Provider<CallRepository>((ref) => FirebaseCallRepository());

/// Watched once at the app's home screen so an incoming call surfaces
/// no matter which tab/screen the user is currently on.
final incomingCallProvider = StreamProvider.autoDispose<CallSession?>((ref) {
  return ref.watch(callRepositoryProvider).watchIncomingCall();
});

final callSessionProvider = StreamProvider.autoDispose.family<CallSession?, String>((ref, callId) {
  return ref.watch(callRepositoryProvider).watchCall(callId);
});

final localCallStreamProvider = StreamProvider.autoDispose.family<MediaStream?, String>((ref, callId) {
  return ref.watch(callRepositoryProvider).watchLocalStream(callId);
});

final remoteCallStreamProvider = StreamProvider.autoDispose.family<MediaStream?, String>((ref, callId) {
  return ref.watch(callRepositoryProvider).watchRemoteStream(callId);
});
