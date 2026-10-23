import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:scoreease/core/utils/input_case_text_formatter.dart';
import 'package:scoreease/core/widgets/not_found_screen.dart';
import 'package:scoreease/features/scoreboard/presentation/pages/widgets/player_score_card.dart';
import 'package:scoreease/features/scoreboard/presentation/pages/widgets/score_change_indicator.dart';

void main() {
  testWidgets('unknown URLs show the not found page with a way home', (tester) async {
    final router = GoRouter(
      initialLocation: '/nowhere',
      errorBuilder: (context, state) => const NotFoundScreen(),
      routes: [GoRoute(path: '/', builder: (context, state) => const Text('Home'))],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('Page not found'), findsOneWidget);
    await tester.tap(find.text('Go to home'));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('score buttons are labelled for screen readers', (tester) async {
    final deltas = <int>[];
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(ScreenUtilInit(
      designSize: const Size(360, 690),
      builder: (context, child) => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 220,
            height: 270,
            child: PlayerScoreCard(
              playerName: 'Ann',
              playerScore: '7',
              indicatorKey: GlobalKey<ScoreChangeIndicatorState>(),
              onChangeScore: deltas.add,
              onEditScore: () {},
            ),
          ),
        ),
      ),
    ));
    // Let the entrance fade finish; fully transparent widgets have no semantics.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.bySemanticsLabel('Add 1 point to Ann'), findsOneWidget);
    expect(find.bySemanticsLabel('Take 1 point from Ann'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Ann has 7 points')), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Add 1 point to Ann'));
    await tester.tap(find.bySemanticsLabel('Take 1 point from Ann'));
    expect(deltas, [1, -1]);
    handle.dispose();
  });

  test('name fields drop characters the database cannot store', () {
    final formatters = nameKeyFormatters(maxLength: 10);
    TextEditingValue value = const TextEditingValue(text: 'Dr. [Who]/#1');
    for (final formatter in formatters) {
      value = formatter.formatEditUpdate(TextEditingValue.empty, value);
    }
    expect(value.text, 'Dr Who1');
    expect(formatters.whereType<LengthLimitingTextInputFormatter>().single.maxLength, 10);
  });
}
