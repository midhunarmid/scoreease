import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:scoreease/data/cloud/access_remote.dart';
import 'package:scoreease/data/cloud/live_board_remote.dart';
import 'package:scoreease/data/local/local_store.dart';
import 'package:scoreease/data/local/settings_store.dart';
import 'package:scoreease/engine/counter_engine.dart';
import 'package:scoreease/engine/engine.dart';
import 'package:scoreease/features/play/play_cubit.dart';

void main() {
  late Directory dir;
  late LocalStore store;
  late SettingsStore settings;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    dir = await Directory.systemTemp.createTemp('scoreease_cubit');
    Hive.init(dir.path);
    store = LocalStore.withBoxes(
      await Hive.openBox<String>('games'),
      await Hive.openBox<String>('events'),
      await Hive.openBox<String>('players'),
      await Hive.openBox('settings'),
    );
    settings = SettingsStore(store.settingsBox)..haptics = false;
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  PlayCubit cubit() {
    final access = AccessRemote();
    return PlayCubit(store: store, access: access, remote: LiveBoardRemote(access), settings: settings);
  }

  test('scores, undoes, persists and finishes a local game', () async {
    final now = DateTime.now();
    await store.saveGame(Game(
      id: 'g1',
      title: 'Carrom',
      templateId: 'carrom',
      mode: GameMode.counter,
      settings: const {'target': 5},
      participants: const [Participant(id: 'p0', name: 'Ann'), Participant(id: 'p1', name: 'Bob')],
      createdAt: now,
      updatedAt: now,
    ));

    final c = cubit();
    await c.openLocal('g1');
    expect(c.state.canScore, isTrue);

    await c.add(CounterEngine.add, {'p': 'p0', 'v': 3});
    await c.add(CounterEngine.add, {'p': 'p1', 'v': 1});
    await c.undo();
    expect(c.state.snapshot!.stateAs<CounterState>().scores, {'p0': 3, 'p1': 0});

    final finished = c.onFinished.first;
    await c.add(CounterEngine.add, {'p': 'p0', 'v': 2});
    expect((await finished).winners, ['p0']);
    await c.close();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // Reopening rebuilds the same state from the saved events.
    final saved = store.game('g1')!;
    expect(saved.isFinished, isTrue);
    expect(saved.winners, ['p0']);
    expect(saved.summary, contains('Ann 5'));
    final again = cubit();
    await again.openLocal('g1');
    expect(again.state.snapshot!.stateAs<CounterState>().scores['p0'], 5);
    await again.close();
  });

  test('a missing game shows an error instead of loading forever', () async {
    final c = cubit();
    await c.openLocal('nope');
    expect(c.state.loading, isFalse);
    expect(c.state.error, isNotNull);
    await c.close();
  });
}
