import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:scoreease/app/di.dart';
import 'package:scoreease/data/local/local_store.dart';
import 'package:scoreease/data/local/settings_store.dart';
import 'package:scoreease/design/theme.dart';
import 'package:scoreease/engine/engine.dart';
import 'package:scoreease/engine/meet.dart';
import 'package:scoreease/features/events/event_page.dart';

/// Keeps everything in memory: Hive's disk writes never finish on a widget
/// test's fake clock.
class _MemoryStore extends LocalStore {
  final _games = <String, Game>{};
  final _events = <String, List<ScoreEvent>>{};
  final _meets = <String, Meet>{};
  final _changes = StreamController<void>.broadcast();

  _MemoryStore(super.games, super.events, super.players, super.settings) : super.withBoxes();

  @override
  Stream<void> get gameChanges => _changes.stream;
  @override
  Stream<void> get meetChanges => _changes.stream;
  @override
  List<Game> games() => _games.values.toList();
  @override
  Game? game(String id) => _games[id];
  @override
  List<ScoreEvent> events(String gameId) => _events[gameId] ?? [];
  @override
  Future<void> saveGame(Game game) async {
    _games[game.id] = game;
    _changes.add(null);
  }

  @override
  Future<void> saveEvents(String gameId, List<ScoreEvent> events) async => _events[gameId] = events;
  @override
  List<Meet> meets() => _meets.values.toList();
  @override
  Meet? meet(String id) => _meets[id];
  @override
  Future<void> saveMeet(Meet meet) async {
    _meets[meet.id] = meet;
    _changes.add(null);
  }
}

void main() {
  late Directory dir;
  late _MemoryStore store;

  setUp(() async {
    useGoogleFonts = false;
    dir = await Directory.systemTemp.createTemp('scoreease_event');
    Hive.init(dir.path);
    store = _MemoryStore(
      await Hive.openBox<String>('games'),
      await Hive.openBox<String>('events'),
      await Hive.openBox<String>('players'),
      await Hive.openBox('settings'),
    );
    await getIt.reset();
    getIt
      ..registerSingleton<LocalStore>(store)
      ..registerSingleton<SettingsStore>(SettingsStore(store.settingsBox));
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  testWidgets('shows team totals and top performers, and follows an undo', (tester) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

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
    const out = [
      ScoreEvent(id: 'e1', type: 'place', data: {'p': 'p1'}, ts: 1),
      ScoreEvent(id: 'e2', type: 'place', data: {'p': 'p2'}, ts: 2),
      ScoreEvent(id: 'e3', type: 'place', data: {'p': 'p3'}, ts: 3),
    ];
    await store.saveEvents('g', out);

    await tester.pumpWidget(MaterialApp(theme: buildTheme(Brightness.light), home: const EventPage(id: 'm')));
    await tester.pump();

    // Ann 1st 3, Eve 2nd 2, Dee 3rd 1, Bob 4th 0.
    expect(find.text('Reds +3 · Blues +3'), findsOneWidget);
    expect(find.text('3'), findsWidgets);
    expect(find.text('Top performers'), findsOneWidget);
    expect(find.text('Ann'), findsOneWidget);

    await store.saveEvents('g', [...out, const ScoreEvent(id: 'e4', type: 'undo', data: {'target': 'e3'}, ts: 4)]);
    await store.saveGame(store.game('g')!);
    await tester.pump();
    expect(find.text('In progress · 2 still in'), findsOneWidget, reason: 'the undone game no longer counts');
    expect(find.text('No points yet'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });
}
