import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scoreease/design/theme.dart';
import 'package:scoreease/features/play/widgets/score_change.dart';

void main() {
  Widget host(num score) => MaterialApp(theme: buildTheme(Brightness.light), home: Scaffold(body: ScoreDelta(score: score)));

  double opacity(WidgetTester tester) => tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;

  testWidgets('changes close together add up, then fade', (tester) async {
    await tester.pumpWidget(host(10));
    expect(opacity(tester), 0, reason: 'nothing changed yet');

    await tester.pumpWidget(host(11));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpWidget(host(13));
    expect(find.text('+3'), findsOneWidget);
    expect(opacity(tester), 1);

    await tester.pump(ScoreDelta.visibleFor);
    expect(opacity(tester), 0);

    await tester.pumpWidget(host(8));
    expect(find.text('−5'), findsOneWidget, reason: 'a new change starts from zero');
    await tester.pump(ScoreDelta.visibleFor);
  });

  testWidgets('a pulse glows when the score goes up, not down', (tester) async {
    Widget pulse(num score) => MaterialApp(
          home: ScorePulse(score: score, color: Colors.red, countsDown: false, child: const SizedBox(width: 50, height: 50)),
        );
    List<BoxShadow> shadows() =>
        (tester.widget<DecoratedBox>(find.descendant(of: find.byType(ScorePulse), matching: find.byType(DecoratedBox))).decoration as BoxDecoration).boxShadow!;

    await tester.pumpWidget(pulse(1));
    expect(shadows(), isEmpty);
    await tester.pumpWidget(pulse(2));
    await tester.pump(const Duration(milliseconds: 100));
    expect(shadows(), isNotEmpty);
    await tester.pumpAndSettle();
    expect(shadows(), isEmpty);

    await tester.pumpWidget(pulse(1));
    await tester.pump(const Duration(milliseconds: 100));
    expect(shadows(), isEmpty, reason: 'taking a point back is not news');
  });
}
