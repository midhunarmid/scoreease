import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:scoreease/app/di.dart';
import 'package:scoreease/data/local/local_store.dart';
import 'package:scoreease/data/local/settings_store.dart';
import 'package:scoreease/design/theme.dart';
import 'package:scoreease/engine/engine.dart';
import 'package:scoreease/engine/meet.dart';
import 'package:scoreease/features/events/event_tv_page.dart';
import 'package:scoreease/features/events/new_event_page.dart';

import 'memory_store.dart';

void main() {
  late Directory dir;
  late MemoryStore store;

  setUp(() async {
    useGoogleFonts = false;
    dir = await Directory.systemTemp.createTemp('scoreease_screens');
    store = await MemoryStore.open(dir);
    await getIt.reset();
    getIt
      ..registerSingleton<LocalStore>(store)
      ..registerSingleton<SettingsStore>(SettingsStore(store.settingsBox));
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  Future<void> pumpAt(WidgetTester tester, Widget app, {Size size = const Size(500, 1600)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app);
    await tester.pump();
  }

  group('new event', () {
    Widget app() => MaterialApp.router(
          theme: buildTheme(Brightness.light),
          routerConfig: GoRouter(routes: [
            GoRoute(path: '/', builder: (_, __) => const NewEventPage()),
            GoRoute(path: '/event/:id', builder: (_, s) => Text('Opened ${s.pathParameters['id']}')),
          ]),
        );

    Finder chipsOf(String team) => find.descendant(
          of: find.ancestor(of: find.widgetWithText(TextField, team), matching: find.byType(Column)).first,
          matching: find.byType(InputChip),
        );

    testWidgets('pasted names split into balanced teams and make an event', (tester) async {
      await pumpAt(tester, app());
      await tester.enterText(find.widgetWithText(TextField, 'Type or paste names, one per line'), 'Ann, Bob\nCy; Dee\nEve\nann');
      await tester.pump();
      expect(find.text('0 on teams · 5 waiting'), findsOneWidget, reason: 'commas, semicolons and lines split names; repeats are dropped');

      await tester.tap(find.text('Split randomly'));
      await tester.pump();
      expect(find.byType(InputChip), findsNWidgets(5));
      expect(chipsOf('Reds'), findsNWidgets(3));
      expect(chipsOf('Blues'), findsNWidgets(2));
      expect(find.text('5 on teams'), findsOneWidget);

      await tester.tap(find.text('Create event'));
      await tester.pumpAndSettle();
      final meet = store.meets().single;
      expect(meet.name, 'Games day');
      expect(meet.placePoints, '3,2,1');
      expect(meet.teams.map((t) => t.name), ['Reds', 'Blues']);
      expect(meet.teams.expand((t) => t.members).toSet(), {'Ann', 'Bob', 'Cy', 'Dee', 'Eve'});
      expect(find.text('Opened ${meet.id}'), findsOneWidget);
    });

    testWidgets('tapping a name moves it; names can be added to one team; empty or same-named teams are refused', (tester) async {
      await pumpAt(tester, app());
      await tester.enterText(find.widgetWithText(TextField, 'Type or paste names, one per line'), 'Ann\nBob');
      await tester.pump();
      await tester.tap(find.text('Add to Reds'));
      await tester.pump();
      expect(chipsOf('Reds'), findsNWidgets(2));

      await tester.tap(find.text('Create event'));
      await tester.pump();
      expect(find.text('Every team needs at least one player'), findsOneWidget);
      expect(store.meets(), isEmpty);

      await tester.tap(find.widgetWithText(InputChip, 'Bob'));
      await tester.pump();
      expect(chipsOf('Reds'), findsOneWidget);
      expect(chipsOf('Blues'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Blues'), 'Reds');
      await tester.pump();
      await tester.tap(find.text('Create event'));
      await tester.pumpAndSettle();
      expect(find.text('Team names must be different'), findsOneWidget);
      expect(store.meets(), isEmpty);
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('event TV', () {
    Future<void> seed() async {
      final now = DateTime(2026);
      await store.saveMeet(Meet(
        id: 'm',
        name: 'Games day',
        teams: const [
          MeetTeam(id: 't0', name: 'Reds', color: 1, members: ['Ann', 'Bob']),
          MeetTeam(id: 't1', name: 'Blues', members: ['Dee', 'Eve']),
        ],
        createdAt: now,
        updatedAt: now,
        finished: true,
      ));
      await store.saveGame(Game(
        id: 'g',
        title: 'Musical chairs',
        templateId: 'musicalchairs',
        mode: GameMode.placements,
        settings: const {'order': 'out'},
        participants: const [
          Participant(id: 'p0', name: 'Ann', teamId: 't0'),
          Participant(id: 'p1', name: 'Bob', teamId: 't0'),
          Participant(id: 'p2', name: 'Dee', teamId: 't1'),
          Participant(id: 'p3', name: 'Eve', teamId: 't1'),
        ],
        createdAt: now,
        updatedAt: now,
        eventId: 'm',
      ));
      // Out: Ann 4th, Bob 3rd (1 pt), Dee 2nd (2 pts); Eve wins (3 pts). Blues 5, Reds 1.
      await store.saveEvents('g', const [
        ScoreEvent(id: 'e1', type: 'place', data: {'p': 'p0'}, ts: 1),
        ScoreEvent(id: 'e2', type: 'place', data: {'p': 'p1'}, ts: 2),
        ScoreEvent(id: 'e3', type: 'place', data: {'p': 'p2'}, ts: 3),
      ]);
    }

    testWidgets('announcing reveals the winning team, then the top three', (tester) async {
      await seed();
      await pumpAt(tester, MaterialApp(theme: buildTheme(Brightness.light), home: const EventTvPage(id: 'm', announce: true)), size: const Size(1600, 900));
      expect(find.text('And the winner is…'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 2200));
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('Blues'), findsOneWidget);
      expect(find.text('Blues 5'), findsOneWidget);
      expect(find.text('Reds 1'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 3500));
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('Blues won!'), findsOneWidget);
      expect(find.text('Top performers'), findsOneWidget);
      expect(find.text('3 pts · played 1'), findsOneWidget, reason: 'Eve');
      expect(find.text('Ann'), findsNothing, reason: 'only the top three stand on the podium');

      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('And the winner is…'), findsOneWidget, reason: 'R replays it');
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('the scoreboard shows totals, the latest game and the leaderboard', (tester) async {
      await seed();
      await pumpAt(tester, MaterialApp(theme: buildTheme(Brightness.light), home: const EventTvPage(id: 'm')), size: const Size(1600, 900));
      expect(find.text('Latest: Musical chairs · Blues +5 · Reds +1'), findsOneWidget);
      expect(find.text('5'), findsWidgets);
      expect(find.text('Eve'), findsOneWidget);
      expect(find.text('Ann'), findsOneWidget);

      await tester.tap(find.byTooltip('Announce the result (A)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('And the winner is…'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('a deleted event says so', (tester) async {
      await pumpAt(tester, MaterialApp(theme: buildTheme(Brightness.light), home: const EventTvPage(id: 'gone')), size: const Size(1600, 900));
      expect(find.text('Event not found'), findsOneWidget);
    });
  });
}
