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

    test('override varsa o göstərilir — at DAHA KÖHNƏ olsa da', () {
      // Qanuni override məhz belədir: istifadəçi ən son mesajı gizlədib,
      // ona görə override daha KÖHNƏ mesajı göstərir. `at >= lastMessageAt`
      // müqayisəsi sınandı və GERİ GÖTÜRÜLDÜ — o, məhz bu halı rədd edir
      // və silinmiş mesajı geri gətirirdi.
      final c = chatWith(
        lastMessage: 'gizlədilmiş',
        lastMessageAt: t1,
        override: (text: 'əvvəlki', type: MessageType.text, at: t0),
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

    // Köhnəlmə artıq SERVERDƏ həll olunur: `onChatMessageCreated` yeni
    // mesaj gələn kimi bütün override-ləri silir, ona görə burada
    // qalan hər override cari sayılır.
  });
}
