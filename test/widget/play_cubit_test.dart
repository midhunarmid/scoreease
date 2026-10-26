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

  test('tags who scored, undo removes the score, and member points persist', () async {
    final now = DateTime.now();
    await store.saveGame(Game(
      id: 'g2',
      title: 'Football',
      templateId: 'counter',
      mode: GameMode.counter,
      participants: const [
        Participant(id: 'p0', name: 'Reds', members: ['Ann', 'Bob']),
        Participant(id: 'p1', name: 'Blues', members: ['Cy']),
      ],
      createdAt: now,
      updatedAt: now,
    ));

    final c = cubit();
    await c.openLocal('g2');
    final goal = await c.add(CounterEngine.add, {'p': 'p0', 'v': 1});
    expect(goal, isNotNull);
    await c.tag(goal!, {1});
    final second = await c.add(CounterEngine.add, {'p': 'p0', 'v': 1});
    await c.tag(second!, {0, 1});
    expect(c.state.snapshot!.memberPoints, {'p0': {0: 1, 1: 2}});

    await c.undo();
    expect(c.state.snapshot!.stateAs<CounterState>().scores['p0'], 1, reason: 'undo takes back the score, not the tag');
    expect(c.state.snapshot!.memberPoints, {'p0': {1: 1}});
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(store.game('g2')!.memberPoints, {'Bob': 1});
    await c.close();
  });

  test('quick taps on one side become one event; undo takes back the burst', () async {
    final now = DateTime.now();
    await store.saveGame(Game(
      id: 'g3',
      title: 'Basketball',
      templateId: 'counter',
      mode: GameMode.counter,
      participants: const [Participant(id: 'p0', name: 'Ann'), Participant(id: 'p1', name: 'Bob')],
      createdAt: now,
      updatedAt: now,
    ));

    final c = cubit();
    await c.openLocal('g3');
    final first = await c.addPoints('p0', 1);
    expect(await c.addPoints('p0', 2), first);
    expect(await c.addPoints('p0', 1), first);
    expect(c.state.snapshot!.stateAs<CounterState>().scores['p0'], 4, reason: 'shows at once');
    expect(c.state.snapshot!.log.map(c.state.snapshot!.describe), ['Ann +4']);

    await c.addPoints('p1', 1);
    await c.addPoints('p0', -1);
    expect(c.state.snapshot!.log.length, 3, reason: 'another side or a minus starts a new event');

    await c.undo();
    await c.undo();
    await c.undo();
    expect(c.state.snapshot!.stateAs<CounterState>().scores, {'p0': 0, 'p1': 0});
    await c.close();
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });

  test('a missing game shows an error instead of loading forever', () async {
    final c = cubit();
    await c.openLocal('nope');
    expect(c.state.loading, isFalse);
    expect(c.state.error, isNotNull);
    await c.close();
  });
}
