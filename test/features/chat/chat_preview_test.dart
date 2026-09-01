// Çat siyahısındakı önizləmə dünənki mesajda donub qalmışdı: «məndən
// sil» bir dəfə override yazır, override isə heç vaxt köhnəlmirdi.
import 'package:flutter_test/flutter_test.dart';
import 'package:peakpin/features/chat/domain/entities/chat.dart';
import 'package:peakpin/features/chat/domain/entities/chat_message.dart';

void main() {
  final t0 = DateTime(2026, 9, 1, 12, 0);
  final t1 = DateTime(2026, 9, 1, 23, 6);

  Chat chatWith({
    required String lastMessage,
    required DateTime lastMessageAt,
    ({String text, MessageType? type, DateTime? at})? override,
  }) => Chat(
        id: 'c1',
        participantIds: const ['me', 'other'],
        initiatorId: 'me',
        status: ChatRequestStatus.accepted,
        lastMessage: lastMessage,
        lastMessageAt: lastMessageAt,
        lastMessageOverride: override == null ? const {} : {'me': override},
      );

  group('previewFor', () {
    test('override yoxdursa ortaq mesaj göstərilir', () {
      final c = chatWith(lastMessage: 'necəsən?', lastMessageAt: t1);
      expect(c.previewFor('me').text, 'necəsən?');
    });

    test('KÖHNƏ override tətbiq edilmir — əsl qüsur bu idi', () {
      // Override dünənki mesajdan yazılıb, sonra yeni mesaj gəlib.
      final c = chatWith(
        lastMessage: 'necəsən?',
        lastMessageAt: t1,
        override: (text: 'Hi', type: MessageType.text, at: t0),
      );
      expect(c.previewFor('me').text, 'necəsən?');
    });

    test('BƏRABƏR at override qalib gəlir — silinən mesaj geri qayıtmamalıdır', () {
      // Silinən mesajın özü sonuncu idisə, at == lastMessageAt olur və
      // override məhz bu hal üçün mövcuddur.
      final c = chatWith(
        lastMessage: 'silinmiş',
        lastMessageAt: t1,
        override: (text: 'əvvəlki', type: MessageType.text, at: t1),
      );
      expect(c.previewFor('me').text, 'əvvəlki');
    });

    test('YENİ override qalib gəlir', () {
      final c = chatWith(
        lastMessage: 'köhnə',
        lastMessageAt: t0,
        override: (text: 'yeni', type: MessageType.text, at: t1),
      );
      expect(c.previewFor('me').text, 'yeni');
    });

    test('at yoxdursa override qalib gəlir — köhnə sənədlər', () {
      // `at` sahəsi əlavə olunmazdan əvvəl yazılmış override-lər.
      // Onları köhnəlmiş saymaq silinmiş mesajı geri gətirərdi.
      final c = chatWith(
        lastMessage: 'silinmiş',
        lastMessageAt: t1,
        override: (text: 'əvvəlki', type: MessageType.text, at: null),
      );
      expect(c.previewFor('me').text, 'əvvəlki');
    });

    test('override başqa istifadəçiyə aiddirsə mənə təsir etmir', () {
      final c = chatWith(
        lastMessage: 'necəsən?',
        lastMessageAt: t1,
        override: (text: 'Hi', type: MessageType.text, at: t0),
      );
      expect(c.previewFor('other').text, 'necəsən?');
    });
  });
}
