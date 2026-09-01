// Tema ripple-ı qəsdən söndürür (`NoSplash`), amma vəd olunan «öz state
// styling» heç vaxt qurulmamışdı — toxunuş heç bir cavab vermirdi.
// `Pressable` həmin çatışmayan hissədir.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peakpin/core/widgets/pressable.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

  testWidgets('basılan anda kiçilir və soluxur', (tester) async {
    await tester.pumpWidget(wrap(Pressable(onTap: () {}, child: const Text('düymə'))));

    double scaleNow() => tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;
    double opacityNow() => tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;

    expect(scaleNow(), 1.0);
    expect(opacityNow(), 1.0);

    final gesture = await tester.startGesture(tester.getCenter(find.text('düymə')));
    await tester.pump();

    expect(scaleNow(), lessThan(1.0), reason: 'barmaq düşən kimi kiçilməlidir');
    expect(opacityNow(), lessThan(1.0), reason: 'barmaq düşən kimi solmalıdır');

    await gesture.up();
    await tester.pumpAndSettle();

    expect(scaleNow(), 1.0);
    expect(opacityNow(), 1.0);
  });

  testWidgets('toxunuş ləğv olunsa geri qayıdır', (tester) async {
    // Barmaq sürüşüb çıxsa düymə basılı qalmamalıdır.
    await tester.pumpWidget(wrap(Pressable(onTap: () {}, child: const Text('düymə'))));
    final gesture = await tester.startGesture(tester.getCenter(find.text('düymə')));
    await tester.pump();
    await gesture.moveBy(const Offset(400, 400));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1.0);
  });

  testWidgets('onTap işə düşür', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(wrap(Pressable(onTap: () => tapped++, child: const Text('düymə'))));
    await tester.tap(find.text('düymə'));
    await tester.pump();
    expect(tapped, 1);
  });

  testWidgets('deaktiv düymə REAKSİYA VERMİR', (tester) async {
    // Heç nə baş verməyəcəksə, toxunuşun qeydə alındığını göstərmək
    // cavabsızlıqdan da pisdir.
    await tester.pumpWidget(wrap(const Pressable(onTap: null, child: Text('düymə'))));
    final gesture = await tester.startGesture(tester.getCenter(find.text('düymə')));
    await tester.pump();

    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1.0);
    await gesture.up();
  });
}
