// Zəng OS ekranından cavablandıqdan sonra qəbul edən tərəfdə heç nə
// olmurdu. Səbəb burada idi: `watchIncomingCall` yalnız `ringing`
// dinləyirdi, CallKit isə statusu `accepted` edirdi — yəni cavab vermə
// aktı sənədi axından ÇIXARIRDI, ona görə naviqasiya da, `acceptCall()`
// da heç vaxt işləmirdi.
import 'package:flutter_test/flutter_test.dart';
import 'package:peakpin/features/calls/domain/incoming_call_filter.dart';

void main() {
  final now = DateTime(2026, 9, 1, 17, 0);
  final fresh = now.subtract(const Duration(seconds: 10));

  group('shouldSurfaceIncomingCall', () {
    test('ringing — adi gələn zəng', () {
      expect(
        shouldSurfaceIncomingCall(status: 'ringing', hasAnswer: false, createdAt: fresh, now: now),
        isTrue,
      );
    });

    test('accepted + answer YOX — OS ekranından cavablanıb, qurulmalıdır', () {
      // Məhz sınan hal. CallKit statusu dəyişdirib, amma WebRTC tərəfi
      // qurulmayıb — ekran açılmalı və `acceptCall()` işləməlidir.
      expect(
        shouldSurfaceIncomingCall(status: 'accepted', hasAnswer: false, createdAt: fresh, now: now),
        isTrue,
      );
    });

    test('accepted + answer VAR — təkrar qurulmamalıdır', () {
      // İkinci cihaz, və ya bu cihazda artıq qurulmuş zəng. İkinci dəfə
      // qurulsa iki PeerConnection eyni offer-ə cavab verməyə çalışar.
      expect(
        shouldSurfaceIncomingCall(status: 'accepted', hasAnswer: true, createdAt: fresh, now: now),
        isFalse,
      );
    });

    test('declined və ended açılmır', () {
      for (final status in ['declined', 'ended', 'busy']) {
        expect(
          shouldSurfaceIncomingCall(status: status, hasAnswer: false, createdAt: fresh, now: now),
          isFalse,
          reason: status,
        );
      }
    });

    test('naməlum və null status açılmır', () {
      expect(shouldSurfaceIncomingCall(status: null, hasAnswer: false, createdAt: fresh, now: now), isFalse);
      expect(shouldSurfaceIncomingCall(status: 'yeni_status', hasAnswer: false, createdAt: fresh, now: now), isFalse);
    });

    test('köhnəlmiş zəng açılmır — dünənki sənəd bu gün çalmamalıdır', () {
      final yesterday = now.subtract(const Duration(days: 1));
      expect(
        shouldSurfaceIncomingCall(status: 'ringing', hasAnswer: false, createdAt: yesterday, now: now),
        isFalse,
      );
      expect(
        shouldSurfaceIncomingCall(status: 'accepted', hasAnswer: false, createdAt: yesterday, now: now),
        isFalse,
      );
    });

    test('həddin tam sərhədi', () {
      final exactly = now.subtract(kIncomingCallMaxAge);
      // Tam həddə hələ keçir (">" istifadə olunur, ">=" yox) — sərhəddə
      // real zəngi itirmək köhnə sənədi göstərməkdən pisdir.
      expect(
        shouldSurfaceIncomingCall(status: 'ringing', hasAnswer: false, createdAt: exactly, now: now),
        isTrue,
      );
      expect(
        shouldSurfaceIncomingCall(
          status: 'ringing',
          hasAnswer: false,
          createdAt: exactly.subtract(const Duration(seconds: 1)),
          now: now,
        ),
        isFalse,
      );
    });

    test('createdAt yoxdursa köhnəlmə yoxlanmır — zəng itmir', () {
      // Köhnə sənədlərdə sahə olmaya bilər. Belə halda zəngi gizlətmək
      // funksiyanı sındırardı; sahənin yoxluğu «köhnə» demək deyil.
      expect(
        shouldSurfaceIncomingCall(status: 'ringing', hasAnswer: false, createdAt: null, now: now),
        isTrue,
      );
    });
  });
}
