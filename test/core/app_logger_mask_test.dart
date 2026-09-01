// Release build-də `logError` artıq logcat-a yazır. Logcat isə telefonu
// əlində tutan hər kəs üçün oxunaqlıdır, ona görə şəxsi məlumat və
// açarlar oradan çıxmamalıdır.
import 'package:flutter_test/flutter_test.dart';
import 'package:peakpin/core/utils/app_logger.dart';

void main() {
  _localeCodes();
  group('maskSensitive', () {
    test('e-poçt maskalanır', () {
      final out = maskSensitive('write failed for rasimagayev80@gmail.com');
      expect(out, contains('[email]'));
      expect(out, isNot(contains('rasimagayev80')));
      expect(out, isNot(contains('gmail.com')));
    });

    test('telefon nömrəsi maskalanır', () {
      final out = maskSensitive('phoneNumber +994501234567 already taken');
      expect(out, contains('[phone]'));
      expect(out, isNot(contains('994501234567')));
    });

    test('koordinat maskalanır', () {
      final out = maskSensitive('position 40.37575310379095, 49.85986769199371');
      expect(out, contains('[coord]'));
      expect(out, isNot(contains('40.375')));
      expect(out, isNot(contains('49.859')));
    });

    test('FCM token maskalanır', () {
      const token = 'dQw4w9WgXcQ:APA91bHZxKqLmNoPqRsTuVwXyZ0123456789abcdef';
      final out = maskSensitive('token $token rejected');
      expect(out, contains('[fcm-token]'));
      expect(out, isNot(contains('APA91')));
    });

    test('JWT maskalanır', () {
      const jwt = 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NSJ9.abcDEF123456';
      final out = maskSensitive('App Check token $jwt failed');
      expect(out, contains('[jwt]'));
      expect(out, isNot(contains('eyJhbGci')));
    });

    test('uid maskalanır', () {
      final out = maskSensitive('receiverId 3cyKZtOCJjhfeWFWMNOA8OGCUaG3 mismatch');
      expect(out, contains('[id]'));
      expect(out, isNot(contains('3cyKZtOCJjhfeWFWMNOA8OGCUaG3')));
    });

    test('diaqnostik dəyər qorunur — mesaj hələ də oxunaqlıdır', () {
      // Maskalama loqu faydasız etməməlidir: xəta kodu, sahə adı və
      // əməliyyat qalmalıdır, yalnız dəyərlər getməlidir.
      final out = maskSensitive(
        '[cloud_firestore/permission-denied] deliveredAt write for uid AbcDefGhiJklMnoPqrStu denied',
      );
      expect(out, contains('permission-denied'));
      expect(out, contains('deliveredAt'));
      expect(out, contains('[id]'));
    });

    test('adi rəqəmlər və qiymətlər maskalanmır', () {
      // 7 AZN, 5 kvota, 2 dəqiqə — bunlar həssas deyil və loqda lazımdır.
      final out = maskSensitive('fee 7 AZN, quota 5, ttl 45000 ms, ratio 1.5');
      expect(out, contains('7 AZN'));
      expect(out, contains('quota 5'));
      expect(out, contains('45000'));
      expect(out, contains('1.5'));
    });

    test('qısa sənəd id-si kimi görünən sözlər qorunur', () {
      // Kolleksiya adları və qısa açarlar 20 simvoldan qısadır.
      final out = maskSensitive('collection pinboxOrders field pickupWindowEnd');
      expect(out, contains('pinboxOrders'));
      expect(out, contains('pickupWindowEnd'));
    });
  });
}

// Azərbaycan lokalında `firebase_functions` xəta kodunu nöqtəsiz `ı`
// ilə qaytarır (`UNAVAILABLE`.toLowerCase() → `unavaılable`), ona görə
// düz müqayisə heç vaxt tutmurdu. Cihazda ölçülüb.
void _localeCodes() {
  group('errorCodeIs — lokal təhlükəsizliyi', () {
    test('nöqtəsiz ı ilə gələn kod tanınır', () {
      expect(errorCodeIs('unavaılable', 'unavailable'), isTrue);
      expect(errorCodeIs('permıssıon-denıed', 'permission-denied'), isTrue);
    });

    test('düzgün yazılmış kod da tanınır', () {
      expect(errorCodeIs('unavailable', 'unavailable'), isTrue);
      expect(errorCodeIs('permission-denied', 'permission-denied'), isTrue);
    });

    test('böyük hərflə gələn kod tanınır', () {
      expect(errorCodeIs('UNAVAILABLE', 'unavailable'), isTrue);
    });

    test('fərqli kodlar qarışdırılmır', () {
      expect(errorCodeIs('unavailable', 'permission-denied'), isFalse);
      expect(errorCodeIs('not-found', 'unavailable'), isFalse);
      // Yaxın, amma fərqli — folding həddindən artıq geniş olmamalıdır.
      expect(errorCodeIs('unavailable', 'unavailables'), isFalse);
    });
  });
}
