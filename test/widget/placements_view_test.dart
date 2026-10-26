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
import 'package:scoreease/engine/engine.dart';
import 'package:scoreease/features/play/play_cubit.dart';
import 'package:scoreease/engine/placements_engine.dart';
import 'package:scoreease/features/play/views/placements_view.dart';

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
    dir = await Directory.systemTemp.createTemp('scoreease_place');
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
      title: 'Musical chairs',
      templateId: 'musicalchairs',
      mode: GameMode.placements,
      settings: const {'order': 'out', 'placePoints': '3,2,1'},
      participants: const [
        Participant(id: 'p0', name: 'Ann', teamId: 't0'),
        Participant(id: 'p1', name: 'Bob', teamId: 't1'),
        Participant(id: 'p2', name: 'Cy', teamId: 't0'),
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

  testWidgets('tapping players out places them, and team points add up', (tester) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: BlocProvider.value(
        value: cubit,
        child: Scaffold(
          body: BlocBuilder<PlayCubit, PlayState>(
            builder: (context, s) => PlacementsView(
              snapshot: s.snapshot!,
              enabled: !s.snapshot!.finished,
              teams: const {'t0': (name: 'Reds', color: 0), 't1': (name: 'Blues', color: 1)},
            ),
          ),
        ),
      ),
    ));
    expect(find.text("Tap who's out · 3rd place, 1 pt"), findsOneWidget);

    await tester.tap(find.text('Bob'));
    await tester.pump();
    expect(cubit.state.snapshot!.stateAs<PlacementsState>().order, ['p1']);
    expect(find.text('Blues  +1'), findsOneWidget);

    await tester.tap(find.text('Cy'));
    await tester.pump();
    expect(cubit.state.snapshot!.finished, isTrue);
    expect(cubit.state.snapshot!.winners, ['p0']);
    expect(find.text('Reds  +5'), findsOneWidget, reason: 'Ann 1st (3) + Cy 2nd (2)');
  });
}
