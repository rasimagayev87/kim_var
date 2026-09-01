import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../core/utils/app_logger.dart';
import '../../safety/data/firebase_safety_repository.dart';
import '../../safety/domain/safety_repository.dart';
import '../domain/call_repository.dart';
import '../domain/entities/call_session.dart';

/// Real, WebRTC-backed [CallRepository]. Signaling (the SDP offer/answer
/// and trickled ICE candidates) rides on `calls/{callId}` the same way
/// `FirebaseChatRepository` rides on `chats/{chatId}` — see
/// `firestore.rules`' `calls` block for the access rules. TURN
/// credentials come from the `getTurnCredentials` Cloud Function so the
/// Cloudflare API token never ships inside the app.
///
/// One instance is expected to have at most one active call at a time
/// (matches the app's UI — there's no call-waiting), so the per-callId
/// maps below exist mainly to make cleanup on end/decline unambiguous
/// rather than to support real concurrency.
class FirebaseCallRepository implements CallRepository {
  FirebaseCallRepository({FirebaseFirestore? firestore, FirebaseFunctions? functions, SafetyRepository? safetyRepository})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance,
        _safetyRepository = safetyRepository ?? FirebaseSafetyRepository(firestore: firestore);

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final SafetyRepository _safetyRepository;

  CollectionReference<Map<String, dynamic>> get _calls => _firestore.collection('calls');

  String? get _myUid => fb.FirebaseAuth.instance.currentUser?.uid;

  final _peerConnections = <String, RTCPeerConnection>{};
  final _localStreams = <String, MediaStream>{};
  final _remoteStreams = <String, MediaStream>{};
  final _localStreamControllers = <String, StreamController<MediaStream?>>{};
  final _remoteStreamControllers = <String, StreamController<MediaStream?>>{};
  final _subscriptions = <String, List<StreamSubscription<dynamic>>>{};

  // Free, unlimited, no account needed — always included alongside
  // whatever Cloudflare TURN servers getTurnCredentials returns, so a
  // same-network call still connects even if TURN is unreachable.
  static const _stunServer = {'urls': 'stun:stun.cloudflare.com:3478'};

  Future<List<Map<String, dynamic>>> _iceServers() async {
    try {
      final result = await _functions.httpsCallable('getTurnCredentials').call<Map<String, dynamic>>();
      final raw = (result.data['iceServers'] as List).cast<dynamic>();
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e, st) {
      // Most commonly: the Cloudflare secrets haven't been configured
      // yet (see getTurnCredentials' doc comment in functions/src/index.ts).
      // STUN-only still lets two devices on the same network connect —
      // just not across most real mobile connections.
      logError('firebase_call_repository._iceServers', e, st);
      return [_stunServer];
    }
  }

  StreamController<MediaStream?> _localController(String callId) =>
      _localStreamControllers.putIfAbsent(callId, () => StreamController<MediaStream?>.broadcast());

  StreamController<MediaStream?> _remoteController(String callId) =>
      _remoteStreamControllers.putIfAbsent(callId, () => StreamController<MediaStream?>.broadcast());

  Future<MediaStream> _openLocalStream(String callId, CallType type) async {
    final stream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': type == CallType.video ? {'facingMode': 'user'} : false,
    });
    _localStreams[callId] = stream;
    _localController(callId).add(stream);
    return stream;
  }

  Future<RTCPeerConnection> _openPeerConnection(String callId) async {
    final iceServers = await _iceServers();
    final pc = await createPeerConnection({
      'iceServers': iceServers,
      'sdpSemantics': 'unified-plan',
    });
    _peerConnections[callId] = pc;
    pc.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteStreams[callId] = event.streams.first;
        _remoteController(callId).add(event.streams.first);
      }
    };
    return pc;
  }

  void _addSub(String callId, StreamSubscription<dynamic> sub) {
    _subscriptions.putIfAbsent(callId, () => []).add(sub);
  }

  void _listenForRemoteCandidates(String callId, RTCPeerConnection pc, CollectionReference<Map<String, dynamic>> source) {
    _addSub(
      callId,
      source.snapshots().listen((snap) {
        for (final change in snap.docChanges) {
          if (change.type != DocumentChangeType.added) continue;
          final d = change.doc.data();
          if (d == null) continue;
          pc.addCandidate(RTCIceCandidate(d['candidate'] as String?, d['sdpMid'] as String?, d['sdpMLineIndex'] as int?));
        }
      }),
    );
  }

  @override
  Future<CallSession> startCall({required String receiverId, required CallType type}) async {
    final uid = _myUid;
    if (uid == null) throw StateError('startCall requires a signed-in user');

    // Düzəliş Prompt 5 (K-3/RT-14) — checked BEFORE opening the local
    // camera/mic stream below, not after: no reason to prompt for
    // media permissions (or hold the hardware open) for a call that's
    // going to be rejected anyway. `firestore.rules`' own `calls/create`
    // check is the real enforcement — this is the same "give a real
    // error instead of a raw permission-denied" pre-check pattern
    // `FirebaseChatRepository._sendMessage` already uses.
    if (await _safetyRepository.isBlockedPair(uid, receiverId)) {
      throw StateError('blocked');
    }

    final callDoc = _calls.doc();
    final callId = callDoc.id;

    final localStream = await _openLocalStream(callId, type);
    final pc = await _openPeerConnection(callId);
    for (final track in localStream.getTracks()) {
      await pc.addTrack(track, localStream);
    }

    final offerCandidates = callDoc.collection('offerCandidates');
    pc.onIceCandidate = (candidate) => offerCandidates.add(candidate.toMap());

    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);

    await callDoc.set({
      'callerId': uid,
      'receiverId': receiverId,
      'participants': [uid, receiverId],
      'type': type.name,
      'status': 'ringing',
      'offer': offer.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    _addSub(
      callId,
      callDoc.snapshots().listen((snap) async {
        final data = snap.data();
        final answer = data?['answer'] as Map<String, dynamic>?;
        if (answer == null) return;
        if (await pc.getRemoteDescription() != null) return;
        await pc.setRemoteDescription(RTCSessionDescription(answer['sdp'] as String?, answer['type'] as String?));
      }),
    );
    _listenForRemoteCandidates(callId, pc, callDoc.collection('answerCandidates'));

    return CallSession(
      id: callId,
      callerId: uid,
      receiverId: receiverId,
      type: type,
      status: CallStatus.ringing,
      startedAt: DateTime.now(),
    );
  }

  @override
  Future<void> acceptCall(String callId) async {
    final callDoc = _calls.doc(callId);
    final snap = await callDoc.get();
    final data = snap.data();
    if (data == null) throw StateError('Call $callId not found');

    final offer = data['offer'] as Map<String, dynamic>;
    final type = data['type'] == 'video' ? CallType.video : CallType.audio;

    final localStream = await _openLocalStream(callId, type);
    final pc = await _openPeerConnection(callId);
    for (final track in localStream.getTracks()) {
      await pc.addTrack(track, localStream);
    }

    final answerCandidates = callDoc.collection('answerCandidates');
    pc.onIceCandidate = (candidate) => answerCandidates.add(candidate.toMap());

    await pc.setRemoteDescription(RTCSessionDescription(offer['sdp'] as String?, offer['type'] as String?));
    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);

    await callDoc.update({'status': 'accepted', 'answer': answer.toMap()});

    _listenForRemoteCandidates(callId, pc, callDoc.collection('offerCandidates'));
  }

  @override
  Future<void> declineCall(String callId) async {
    await _calls.doc(callId).update({'status': 'declined'});
    await _cleanup(callId);
  }

  @override
  Future<void> endCall(String callId) async {
    try {
      await _calls.doc(callId).update({'status': 'ended', 'endedAt': FieldValue.serverTimestamp()});
    } catch (e, st) {
      // The other side may have already deleted/ended it first — losing
      // this race isn't worth surfacing an error over, cleanup below
      // still needs to run either way.
      logError('firebase_call_repository.endCall', e, st);
    }
    await _cleanup(callId);
  }

  Future<void> _cleanup(String callId) async {
    for (final sub in _subscriptions.remove(callId) ?? const <StreamSubscription<dynamic>>[]) {
      await sub.cancel();
    }
    await _peerConnections.remove(callId)?.close();
    await _localStreams.remove(callId)?.dispose();
    _remoteStreams.remove(callId);
    _localController(callId).add(null);
    _remoteController(callId).add(null);
  }

  @override
  Stream<CallSession?> watchIncomingCall() {
    final uid = _myUid;
    if (uid == null) return Stream.value(null);
    return _calls
        .where('receiverId', isEqualTo: uid)
        .where('status', isEqualTo: 'ringing')
        .snapshots()
        .map((snap) => snap.docs.isEmpty ? null : _sessionFromDoc(snap.docs.first));
  }

  @override
  Stream<CallSession?> watchCall(String callId) {
    return _calls.doc(callId).snapshots().map((d) => d.exists ? _sessionFromDoc(d) : null);
  }

  // `_openLocalStream`/`pc.onTrack` fire (and `.add()` to these broadcast
  // controllers) as soon as `startCall`/`acceptCall` runs — which is
  // BEFORE `CallScreen` exists to subscribe, since both are awaited
  // ahead of the `Navigator.push` that creates it. A plain broadcast
  // stream doesn't replay that already-emitted value to a listener that
  // shows up late, so the screen's renderer never got a stream to
  // render (the camera *was* open the whole time — the UI just never
  // heard about it). Re-yielding whatever's already cached before
  // tailing the live stream closes that race for any subscriber,
  // late or not.
  @override
  Stream<MediaStream?> watchLocalStream(String callId) async* {
    final current = _localStreams[callId];
    if (current != null) yield current;
    yield* _localController(callId).stream;
  }

  @override
  Stream<MediaStream?> watchRemoteStream(String callId) async* {
    final current = _remoteStreams[callId];
    if (current != null) yield current;
    yield* _remoteController(callId).stream;
  }

  @override
  Future<void> setMuted(String callId, bool muted) async {
    for (final track in _localStreams[callId]?.getAudioTracks() ?? const []) {
      track.enabled = !muted;
    }
  }

  @override
  Future<void> setVideoEnabled(String callId, bool enabled) async {
    for (final track in _localStreams[callId]?.getVideoTracks() ?? const []) {
      track.enabled = enabled;
    }
  }

  @override
  Future<void> switchCamera(String callId) async {
    final tracks = _localStreams[callId]?.getVideoTracks() ?? const [];
    if (tracks.isEmpty) return;
    await Helper.switchCamera(tracks.first);
  }

  @override
  Future<void> setSpeakerphoneOn(String callId, bool enabled) => Helper.setSpeakerphoneOn(enabled);

  @override
  Future<int?> getDataUsageBytes(String callId) async {
    final pc = _peerConnections[callId];
    if (pc == null) return null;
    try {
      final reports = await pc.getStats();
      var total = 0;
      for (final report in reports) {
        if (report.type == 'outbound-rtp' || report.type == 'inbound-rtp') {
          final sent = report.values['bytesSent'];
          final received = report.values['bytesReceived'];
          if (sent is num) total += sent.toInt();
          if (received is num) total += received.toInt();
        }
      }
      return total;
    } catch (e, st) {
      logError('firebase_call_repository.getDataUsageBytes', e, st);
      return null;
    }
  }

  CallSession _sessionFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return CallSession(
      id: doc.id,
      callerId: data['callerId'] as String,
      receiverId: data['receiverId'] as String,
      type: data['type'] == 'video' ? CallType.video : CallType.audio,
      status: switch (data['status'] as String) {
        'accepted' => CallStatus.accepted,
        'declined' => CallStatus.declined,
        'ended' => CallStatus.ended,
        'busy' => CallStatus.busy,
        _ => CallStatus.ringing,
      },
      startedAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      deliveredAt: (data['deliveredAt'] as Timestamp?)?.toDate(),
    );
  }
}
