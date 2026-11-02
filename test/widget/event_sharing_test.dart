import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:scoreease/app/di.dart';
import 'package:scoreease/data/cloud/access_remote.dart';
import 'package:scoreease/data/cloud/cloud.dart';
import 'package:scoreease/data/cloud/event_board_remote.dart';
import 'package:scoreease/data/cloud/live_board_remote.dart';
import 'package:scoreease/data/local/local_store.dart';
import 'package:scoreease/data/local/settings_store.dart';
import 'package:scoreease/design/theme.dart';
import 'package:scoreease/engine/engine.dart';
import 'package:scoreease/engine/event_scoring.dart';
import 'package:scoreease/engine/meet.dart';
import 'package:scoreease/features/events/event_follow_cubit.dart';
import 'package:scoreease/features/events/event_page.dart';
import 'package:scoreease/features/events/event_sharing.dart';
import 'package:scoreease/features/events/event_widgets.dart';

import 'memory_store.dart';

final _now = DateTime(2026);

Meet _meet({String? shareCode}) => Meet(
      id: 'm',
      name: 'Games day',
      teams: const [
        MeetTeam(id: 't0', name: 'Reds', color: 1, members: ['Ann', 'Bob']),
        MeetTeam(id: 't1', name: 'Blues', members: ['Dee']),
      ],
      createdAt: _now,
      updatedAt: _now,
      shareCode: shareCode,
    );

Game _race(String id, {String? shareCode, int minute = 0}) => Game(
      id: id,
      title: 'Race $id',
      templateId: 'race',
      mode: GameMode.placements,
      settings: const {'order': 'finish'},
      participants: const [Participant(id: 'p0', name: 'Ann', teamId: 't0'), Participant(id: 'p1', name: 'Dee', teamId: 't1')],
      createdAt: _now.add(Duration(minutes: minute)),
      updatedAt: _now,
      shareCode: shareCode,
      eventId: 'm',
    );

class _FakeEvents implements EventBoardRemote {
  final published = <Meet>[];
  final updates = <(String, Meet, Map<String, String>)>[];
  final removed = <(String, List<String>)>[];
  final controller = StreamController<SharedEvent>.broadcast();

  @override
  Future<String> publish(Meet meet) async {
    published.add(meet);
    return 'evt234';
  }

  @override
  Future<void> update(String code, Meet meet, Map<String, String> games) async => updates.add((code, meet, games));

  @override
  Future<void> unpublish(String code, Iterable<String> boards) async => removed.add((code, boards.toList()));

  @override
  Future<bool> exists(String code) async => true;

  @override
  Stream<SharedEvent> watch(String code) => controller.stream;
}

class _FakeBoards extends LiveBoardRemote {
  _FakeBoards() : super(AccessRemote());

  final publishedWith = <String, String>{};
  final streams = <String, StreamController<LiveBoard>>{};
  bool offline = false;
  int _next = 0;

  @override
  Future<String> publish(Game game, List<ScoreEvent> events, {String readPassword = '', String writePassword = ''}) async {
    if (offline) throw CloudException.offline;
    final code = 'board${_next++}';
    publishedWith[code] = writePassword;
    return code;
  }

  @override
  Stream<LiveBoard> watch(String code, AccessMeta accessMeta) => (streams[code] ??= StreamController<LiveBoard>.broadcast()).stream;
}

class _FakeAccess extends AccessRemote {
  @override
  Future<AccessMeta?> getMeta(String id) async => const AccessMeta(ownerId: 'alice');
}

void main() {
  late Directory dir;
  late MemoryStore store;
  late _FakeEvents events;
  late _FakeBoards boards;
  late EventSharing sharing;

  setUp(() async {
    useGoogleFonts = false;
    dir = await Directory.systemTemp.createTemp('scoreease_sharing');
    store = await MemoryStore.open(dir);
    events = _FakeEvents();
    boards = _FakeBoards();
    sharing = EventSharing(store, events, boards);
    await getIt.reset();
    getIt
      ..registerSingleton<LocalStore>(store)
      ..registerSingleton<SettingsStore>(SettingsStore(store.settingsBox))
      ..registerSingleton<EventSharing>(sharing);
  });

  tearDown(() async {
    await events.controller.close();
    await Hive.close();
    await dir.delete(recursive: true);
  });

  group('EventSharing', () {
    test('sharing publishes every game, with scoring kept to the owner', () async {
      await store.saveMeet(_meet());
      await store.saveGame(_race('a'));
      await store.saveGame(_race('b', shareCode: 'mine23'));

      expect(await sharing.share('m'), 'evt234');

      final meet = store.meet('m')!;
      expect(meet.shareCode, 'evt234');
      expect(meet.sharedBoards, ['board0'], reason: 'a game shared on its own is not the event\'s to remove');
      expect(store.game('a')!.shareCode, 'board0');
      expect(boards.publishedWith['board0'], isNotEmpty, reason: 'no one is told this password');
      expect(events.updates.last.$3, {'a': 'board0', 'b': 'mine23'});
    });

    test('a game that can\'t be published is left out and tried again', () async {
      await store.saveMeet(_meet(shareCode: 'evt234'));
      await store.saveGame(_race('a'));

      boards.offline = true;
      await sharing.sync('m');
      expect(store.game('a')!.shareCode, isNull);
      expect(events.updates.last.$3, isEmpty);

      boards.offline = false;
      await sharing.sync('m');
      expect(store.game('a')!.shareCode, 'board0');
      expect(events.updates.last.$3, {'a': 'board0'});
    });

    test('a game is published once when syncs overlap', () async {
      await store.saveMeet(_meet(shareCode: 'evt234'));
      await store.saveGame(_race('a'));

      await Future.wait([sharing.sync('m'), sharing.sync('m'), sharing.sync('m')]);

      expect(boards.publishedWith, hasLength(1));
    });

    test('stopping removes only what the event published', () async {
      await store.saveMeet(_meet());
      await store.saveGame(_race('a'));
      await store.saveGame(_race('b', shareCode: 'mine23'));
      await sharing.share('m');

      await sharing.stop('m');

      expect(events.removed.single.$1, 'evt234');
      expect(events.removed.single.$2, ['board0']);
      expect(store.meet('m')!.shareCode, isNull);
      expect(store.meet('m')!.sharedBoards, isEmpty);
      expect(store.game('a')!.shareCode, isNull);
      expect(store.game('b')!.shareCode, 'mine23');
    });
  });

  group('EventFollowCubit', () {
    late EventFollowCubit cubit;

    LiveBoard live(String code, Game game, [List<ScoreEvent> events = const []]) =>
        LiveBoard(code: code, game: game.copyWith(shareCode: code), events: events, access: const AccessMeta());

    setUp(() {
      cubit = EventFollowCubit('evt234', events: events, boards: boards, access: _FakeAccess());
    });

    tearDown(() => cubit.close());

    Future<void> openWith(List<String> codes) async {
      cubit.open();
      await pumpEventQueue();
      events.controller.add(SharedEvent(_meet(shareCode: 'evt234'), codes));
      await pumpEventQueue();
    }

    test('works out the totals from the boards as they change', () async {
      await openWith(['one', 'two']);
      expect(cubit.state.standings!.games, isEmpty);

      boards.streams['one']!.add(live('one', _race('live_one')));
      boards.streams['two']!.add(live('two', _race('live_two', minute: 1)));
      await pumpEventQueue();
      expect(cubit.state.standings!.games.map((g) => g.upcoming), [true, true]);

      boards.streams['one']!.add(live('one', _race('live_one'), const [ScoreEvent(id: 'e1', type: 'place', data: {'p': 'p0'}, ts: 1)]));
      await pumpEventQueue();
      final standings = cubit.state.standings!;
      expect(standings.games.first.counted, true);
      expect(standings.teamTotals, {'t0': 3, 't1': 2});
    });

    test('drops a game taken out of the event', () async {
      await openWith(['one']);
      boards.streams['one']!.add(live('one', _race('live_one')));
      await pumpEventQueue();
      expect(cubit.state.standings!.games, hasLength(1));

      events.controller.add(SharedEvent(_meet(shareCode: 'evt234'), const []));
      await pumpEventQueue();
      expect(cubit.state.standings!.games, isEmpty);
    });

    test('lists a game it can\'t read, and tries it again', () async {
      await openWith(['one']);
      boards.streams['one']!.addError(CloudException.accessDenied);
      await pumpEventQueue();
      expect(cubit.state.locked, ['one']);

      cubit.retryLocked();
      await pumpEventQueue();
      boards.streams['one']!.add(live('one', _race('live_one')));
      await pumpEventQueue();
      expect(cubit.state.locked, isEmpty);
      expect(cubit.state.standings!.games, hasLength(1));
    });

    test('says so when the event is gone', () async {
      cubit.open();
      await pumpEventQueue();
      events.controller.addError(CloudException.eventNotFound);
      await pumpEventQueue();
      expect(cubit.state.error, CloudException.eventNotFound);
    });
  });

  group('the games list', () {
    GameAward award(String id, List<ScoreEvent> events, {int minute = 0}) =>
        GameAward(GameEngine.compute(_race(id, minute: minute), events), const {});

    test('a game is up next until something is played', () {
      expect(award('a', const []).upcoming, true);
      expect(award('a', const [ScoreEvent(id: 'e1', type: 'sub', data: {'p': 'p0', 'n': 'Bob'}, ts: 1)]).upcoming, true);
      expect(award('a', const [ScoreEvent(id: 'e1', type: 'place', data: {'p': 'p0'}, ts: 1)]).upcoming, false, reason: 'ended by the only placing left');

      final undone = award('a', const [
        ScoreEvent(id: 'e1', type: 'place', data: {'p': 'p0'}, ts: 1),
        ScoreEvent(id: 'e2', type: 'undo', data: {'target': 'e1'}, ts: 2),
      ]);
      expect(undone.upcoming, true);
    });

    testWidgets('groups games into playing, up next and played', (tester) async {
      final standings = scoreMeet(_meet(), [
        GameEngine.compute(_race('next2', minute: 3), const []),
        GameEngine.compute(_race('next1', minute: 2), const []),
        GameEngine.compute(_race('done', minute: 1), const [ScoreEvent(id: 'e1', type: 'place', data: {'p': 'p0'}, ts: 1)]),
      ]);
      await tester.pumpWidget(MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(body: EventGameList(standings: standings, empty: 'None', onOpen: (_) {})),
      ));

      expect(find.text('Playing now'), findsNothing);
      expect(find.text('Up next'), findsOneWidget);
      expect(find.text('Played'), findsOneWidget);
      expect(find.text('Ann vs Dee'), findsNWidgets(2));
      expect(find.text('Reds +3 · Blues +2'), findsOneWidget);

      final first = tester.getTopLeft(find.text('Race next1')).dy;
      final second = tester.getTopLeft(find.text('Race next2')).dy;
      expect(first, lessThan(second), reason: 'in the order they were added');
    });
  });

  testWidgets('the event page syncs a shared event when it changes', (tester) async {
    await store.saveMeet(_meet());
    await store.saveGame(_race('a'));
    await tester.runAsync(() => sharing.share('m'));
    final before = events.updates.length;

    await tester.pumpWidget(MaterialApp(theme: buildTheme(Brightness.light), home: const EventPage(id: 'm')));
    await tester.pump();
    await tester.runAsync(pumpEventQueue);
    expect(events.updates.length, before + 1, reason: 'on opening');

    await tester.runAsync(() => store.saveMeet(store.meet('m')!.copyWith(name: 'Sports day')));
    await tester.pump();
    await tester.runAsync(pumpEventQueue);
    expect(events.updates.last.$2.name, 'Sports day');

    final count = events.updates.length;
    await tester.runAsync(() => store.saveGame(store.game('a')!));
    await tester.pump();
    await tester.runAsync(pumpEventQueue);
    expect(events.updates.length, count, reason: 'nothing followers see of the event changed');

    await tester.pumpWidget(const SizedBox());
  });

  test('a meet survives the trip to followers', () {
    final meet = Meet.fromShareJson('evt234', _meet().copyWith(finished: true).toShareJson());
    expect(meet.name, 'Games day');
    expect(meet.finished, true);
    expect(meet.shareCode, 'evt234');
    expect(meet.teams.map((t) => t.name), ['Reds', 'Blues']);
    expect(meet.teams.first.members, ['Ann', 'Bob']);
  });
}
