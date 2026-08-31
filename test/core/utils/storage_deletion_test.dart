import 'package:flutter_test/flutter_test.dart';
import 'package:peakpin/core/utils/storage_deletion.dart';

void main() {
  group('resizedVariantPath', () {
    test('adi hallar', () {
      expect(resizedVariantPath('venue_photos/uid/v1.jpg'),
          'venue_photos/uid/v1_200x200.jpg');
      expect(resizedVariantPath('chat_photos/a_b/a/m1.jpg'),
          'chat_photos/a_b/a/m1_200x200.jpg');
      expect(resizedVariantPath('posts/uid/p.png'), 'posts/uid/p_200x200.png');
    });

    test('null qaytarmalı hallar', () {
      expect(resizedVariantPath(''), isNull);
      // Uzantı yoxdur.
      expect(resizedVariantPath('posts/uid/file'), isNull);
      // Nöqtə qovluq adındadır, fayl adında yox.
      expect(resizedVariantPath('a.b/c'), isNull);
      // Gizli fayl — uzantı deyil.
      expect(resizedVariantPath('posts/uid/.hidden'), isNull);
      // Artıq törəmədir — ikiqat şəkilçi yaranmamalıdır.
      expect(resizedVariantPath('posts/uid/p_200x200.jpg'), isNull);
    });

    test('şəkilçi TypeScript tərəfi ilə eynidir', () {
      // `functions/src/chat-media.ts`-dəki RESIZED_IMAGE_SUFFIX və
      // `app_image.dart`-dakı sabit ilə eyni olmalıdır.
      expect(kResizedImageSuffix, '_200x200');
    });

    test('nəticə heç vaxt orijinalın özü olmur', () {
      // Səhv bir istiqamətdə təhlükəlidir: eyni yolu qaytarsa,
      // silinən şey orijinalın özü olar və sonra bir daha silinər.
      for (final p in [
        'venue_photos/u/v.jpg',
        'offer_photos/u/o.jpeg',
        'profile_photos/u/a.png',
      ]) {
        expect(resizedVariantPath(p), isNot(p));
      }
    });
  });
}
