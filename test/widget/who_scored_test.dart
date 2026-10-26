import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:scoreease/data/cloud/access_remote.dart';
import 'package:scoreease/data/cloud/live_board_remote.dart';
import 'package:scoreease/data/local/local_store.dart';
import 'package:scoreease/data/local/settings_store.dart';
import 'package:scoreease/design/theme.dart';
import 'package:scoreease/engine/counter_engine.dart';
import 'package:scoreease/engine/engine.dart';
import 'package:scoreease/features/play/play_cubit.dart';
import 'package:scoreease/features/play/views/counter_view.dart';
import 'package:scoreease/features/play/widgets/who_scored.dart';

/// Keeps games in memory: Hive's disk writes never finish on a widget test's
/// fake clock.
class _MemoryStore extends LocalStore {
  final _games = <String, Game>{};
  final _events = <String, List<ScoreEvent>>{};

  _MemoryStore(super.games, super.events, super.players, super.settings) : super.withBoxes();

  @override
  Game? game(String id) => _games[id];
  @override
  List<ScoreEvent> events(String gameId) => _events[gameId] ?? [];
  @override
  Future<void> saveGame(Game game) async => _games[game.id] = game;
  @override
  Future<void> saveEvents(String gameId, List<ScoreEvent> events) async => _events[gameId] = events;
}

void main() {
  late Directory dir;
  late LocalStore store;
  late PlayCubit cubit;

  setUp(() async {
    useGoogleFonts = false;
    dir = await Directory.systemTemp.createTemp('scoreease_who');
    Hive.init(dir.path);
    store = _MemoryStore(
      await Hive.openBox<String>('games'),
      await Hive.openBox<String>('events'),
      await Hive.openBox<String>('players'),
      await Hive.openBox('settings'),
    );
    final now = DateTime.now();
    await store.saveGame(Game(
      id: 'g',
      title: 'Football',
      templateId: 'football',
      mode: GameMode.counter,
      participants: const [
        Participant(id: 'p0', name: 'Reds', members: ['Ann', 'Bob']),
        Participant(id: 'p1', name: 'Blues', members: ['Cy', 'Dee']),
      ],
      createdAt: now,
      updatedAt: now,
    ));
    final access = AccessRemote();
    cubit = PlayCubit(store: store, access: access, remote: LiveBoardRemote(access), settings: SettingsStore(store.settingsBox)..haptics = false);
    await cubit.openLocal('g');
  });

  tearDown(() async {
    await cubit.close();
    await Hive.close();
    await dir.delete(recursive: true);
  });

  Future<void> pump(WidgetTester tester, {bool faceToFace = false}) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: BlocProvider.value(
        value: cubit,
        child: Scaffold(
          body: BlocBuilder<PlayCubit, PlayState>(builder: (context, s) => CounterView(snapshot: s.snapshot!, enabled: true, faceToFace: faceToFace)),
        ),
      ),
    ));
  }

  testWidgets('a team score offers its members and saves the tag when the strip closes', (tester) async {
    await pump(tester);
    expect(find.text('Who?'), findsNothing);

    await tester.tap(find.text('Reds'));
    await tester.pump();
    expect(find.text('Who?'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Ann'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Cy'), findsNothing, reason: 'only the scoring team');

    await tester.tap(find.widgetWithText(FilterChip, 'Bob'));
    await tester.pump();
    expect(cubit.state.snapshot!.tags, isEmpty, reason: 'saved once, when the strip closes');

    await tester.pump(WhoScored.visibleFor);
    expect(find.text('Who?'), findsNothing);
    expect(cubit.state.snapshot!.memberPoints, {'p0': {1: 1}});
    expect(cubit.state.snapshot!.stateAs<CounterState>().scores['p0'], 1);
  });

  testWidgets('ignoring the strip leaves the point untagged', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Blues'));
    await tester.pump();
    expect(find.text('Who?'), findsOneWidget);
    await tester.pump(WhoScored.visibleFor);
    expect(find.text('Who?'), findsNothing);
    expect(cubit.state.snapshot!.tags, isEmpty);
  });

  int scoreOf(String id) => cubit.state.snapshot!.stateAs<CounterState>().scores[id]!;

  testWidgets('swiping a side up scores and down takes it back', (tester) async {
    await pump(tester);
    await tester.fling(find.text('Reds'), const Offset(0, -150), 1000);
    await tester.pump();
    expect(scoreOf('p0'), 1);
    await tester.pump(WhoScored.visibleFor);

    await tester.fling(find.text('Reds'), const Offset(0, 150), 1000);
    await tester.pump();
    expect(scoreOf('p0'), 0);
    await tester.pump(WhoScored.visibleFor);
  });

  testWidgets('holding a side opens a keypad to score or set any amount', (tester) async {
    await pump(tester);
    await tester.longPress(find.text('Blues'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '1'));
    await tester.tap(find.widgetWithText(FilledButton, '2'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '+12'));
    await tester.pumpAndSettle();
    expect(scoreOf('p1'), 12);
    expect(find.text('Who?'), findsOneWidget, reason: 'a keypad score can be tagged too');
    await tester.pump(WhoScored.visibleFor);

    await tester.longPress(find.text('Blues'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '5'));
    await tester.pump();
    await tester.tap(find.text('Set score to 5'));
    await tester.pumpAndSettle();
    expect(scoreOf('p1'), 5);
    await tester.pump(WhoScored.visibleFor);
  });

  testWidgets('face to face turns the top side around', (tester) async {
    int turnsOf(String name) => tester.widget<RotatedBox>(find.ancestor(of: find.text(name), matching: find.byType(RotatedBox))).quarterTurns;

    await pump(tester);
    expect(turnsOf('Reds'), 0);

    await pump(tester, faceToFace: true);
    expect(turnsOf('Reds'), 2);
    expect(turnsOf('Blues'), 0);

    await tester.tap(find.text('Reds'));
    await tester.pump();
    expect(scoreOf('p0'), 1, reason: 'the turned side still scores');
    await tester.pump(WhoScored.visibleFor);
  });
}
