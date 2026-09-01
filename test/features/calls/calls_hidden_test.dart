// Zəng launch üçün gizlədilib (docs/calls-hidden-for-launch.md).
//
// Bu testlər kodun silinmədiyini deyil, GİRİŞ NÖQTƏLƏRİNİN bağlı
// olduğunu qoruyur. Ən vacibi sonuncu qrupdur: bayraq oxunmayan halda
// nə baş verir — çünki səhv istiqamətə düşən defolt gizlətməni ləğv
// edər.
import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

import 'package:peakpin/features/app_config/domain/entities/app_config.dart';

void main() {
  group('FeatureFlag.calls — launch üçün bağlıdır', () {
    test('paketlənmiş defolt FALSE-dur', () {
      // Remote Config gəlməmiş (ilk açılış, offline, uğursuz fetch) məhz
      // bu dəyər tətbiq olunur. `true` olsaydı, hər soyuq başlanğıcda
      // zəng düymələri bir anlıq görünərdi.
      const config = AppConfig();
      expect(config.featureFlags[FeatureFlag.calls], isFalse);
    });

    test('digər funksiyalar bundan təsirlənməyib', () {
      // Gizlətmə yalnız zəngə aiddir; qonşu bayraqları söndürmək
      // launch-ı daha da daraldardı.
      const config = AppConfig();
      expect(config.featureFlags[FeatureFlag.offers], isTrue);
      expect(config.featureFlags[FeatureFlag.venueSubmission], isTrue);
    });

    test('Remote Config SDK defoltu da FALSE-dur — İKİ defolt var', () {
      // Bu, əsl tələdir və bir dəfə tuşa düşdü: `AppConfig`-in fallback
      // xəritəsi ilə `setDefaults`-a verilən xəritə AYRIDIR, və Remote
      // Config açarı olmayanda `getBool` məhz İKİNCİSİNİ qaytarır.
      // Birincisini `false` edib ikincisini `true` qoymaq düymələri
      // ekranda saxlayır — kodu oxumaqla yox, build-i sınamaqla tapıldı.
      final src = File('lib/features/app_config/data/datasources/remote_config_data_source.dart')
          .readAsStringSync();
      expect(
        src.contains("'feature_calls_enabled': false,"),
        isTrue,
        reason: 'setDefaults-dakı feature_calls_enabled false olmalıdır',
      );
    });

    test('bayraq enum-da qalır — kod silinməyib', () {
      // Açmaq üçün yalnız dəyər dəyişməlidir, kod bərpası yox.
      expect(FeatureFlag.values, contains(FeatureFlag.calls));
    });
  });
}
