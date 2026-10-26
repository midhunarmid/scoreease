import 'package:flutter_test/flutter_test.dart';
import 'package:scoreease/engine/counter_engine.dart';
import 'package:scoreease/engine/cricket_engine.dart';
import 'package:scoreease/engine/engine.dart';
import 'package:scoreease/engine/placements_engine.dart';
import 'package:scoreease/engine/rounds_engine.dart';
import 'package:scoreease/engine/sets_engine.dart';

Game game(GameMode mode, {int players = 2, Map<String, dynamic> settings = const {}}) => Game(
      id: 'g',
      title: 'Test',
      templateId: mode.name,
      mode: mode,
      settings: settings,
      participants: [for (var i = 0; i < players; i++) Participant(id: 'p$i', name: 'P$i')],
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

/// Builds events with increasing ids so their order is the list order.
class Log {
  final events = <ScoreEvent>[];
  var _n = 0;

  String add(String type, [Map<String, dynamic> data = const {}]) {
    final id = 'e${(_n++).toString().padLeft(5, '0')}';
    events.add(ScoreEvent(id: id, type: type, data: data, ts: 1000 * _n));
    return id;
  }
}

void main() {
  group('counter', () {
    test('adds, sets and ranks', () {
      final g = game(GameMode.counter, players: 3);
      final log = Log()
        ..add('add', {'p': 'p0', 'v': 3})
        ..add('add', {'p': 'p1', 'v': 5})
        ..add('set', {'p': 'p2', 'v': 3});
      final snap = GameEngine.compute(g, log.events);
      expect(snap.stateAs<CounterState>().scores, {'p0': 3, 'p1': 5, 'p2': 3});
      expect(snap.standings.first.participantId, 'p1');
      expect(snap.standings[1].rank, 2);
      expect(snap.standings[2].rank, 2);
      expect(snap.finished, isFalse);
    });

    test('target finishes the game and ignores later events', () {
      final g = game(GameMode.counter, settings: {'target': 5});
      final log = Log()
        ..add('add', {'p': 'p0', 'v': 5})
        ..add('add', {'p': 'p1', 'v': 9});
      final snap = GameEngine.compute(g, log.events);
      expect(snap.finished, isTrue);
      expect(snap.winners, ['p0']);
      expect(snap.stateAs<CounterState>().scores['p1'], 0);
    });

    test('clock banks elapsed time across pauses', () {
      final g = game(GameMode.counter);
      final events = [
        const ScoreEvent(id: 'a', type: 'clock', data: {'run': true}, ts: 1000),
        const ScoreEvent(id: 'b', type: 'clock', data: {'run': false}, ts: 4000),
        const ScoreEvent(id: 'c', type: 'clock', data: {'run': true}, ts: 10000),
      ];
      final state = GameEngine.compute(g, events).stateAs<CounterState>();
      expect(state.elapsedMs(12000), 5000);
    });

    test('win by 2 plays on past the target until someone leads by 2', () {
      final g = game(GameMode.counter, settings: {'target': 11, 'winBy': 2});
      final log = Log()
        ..add('add', {'p': 'p0', 'v': 10})
        ..add('add', {'p': 'p1', 'v': 10})
        ..add('add', {'p': 'p0', 'v': 1});
      var snap = GameEngine.compute(g, log.events);
      expect(snap.finished, isFalse, reason: '11-10 is not a 2 point lead');
      expect(CounterEngine.onGamePoint(snap.stateAs<CounterState>(), g), {'p0'});

      log.add('add', {'p': 'p0', 'v': 1});
      snap = GameEngine.compute(g, log.events);
      expect(snap.finished, isTrue);
      expect(snap.winners, ['p0']);
    });

    test('game point needs the target within one step', () {
      final g = game(GameMode.counter, settings: {'target': 25, 'steps': '1,3'});
      final log = Log()
        ..add('add', {'p': 'p0', 'v': 21})
        ..add('add', {'p': 'p1', 'v': 22});
      final state = GameEngine.compute(g, log.events).stateAs<CounterState>();
      expect(CounterEngine.onGamePoint(state, g), {'p1'});
      expect(CounterEngine.onGamePoint(state, game(GameMode.counter)), isEmpty, reason: 'no target');
    });

    test('countdown starts high, subtracts points and ends at 0', () {
      final g = game(GameMode.counter, settings: {'startAt': 301, 'steps': '20'});
      final log = Log()
        ..add('add', {'p': 'p0', 'v': 281})
        ..add('add', {'p': 'p1', 'v': 100});
      var snap = GameEngine.compute(g, log.events);
      expect(snap.stateAs<CounterState>().scores, {'p0': 20, 'p1': 201});
      expect(snap.standings.first.participantId, 'p0', reason: 'fewest left leads');
      expect(CounterEngine.onGamePoint(snap.stateAs<CounterState>(), g), {'p0'});
      expect(snap.describe(log.events.first), 'P0 -281');

      log.add('add', {'p': 'p0', 'v': 20});
      snap = GameEngine.compute(g, log.events);
      expect(snap.finished, isTrue);
      expect(snap.winners, ['p0']);
    });

    test('period points split the score by period', () {
      final g = game(GameMode.counter, settings: {'periods': 4, 'periodMinutes': 10});
      final log = Log()
        ..add('add', {'p': 'p0', 'v': 12})
        ..add('add', {'p': 'p1', 'v': 8})
        ..add('period')
        ..add('add', {'p': 'p0', 'v': 3})
        ..add('add', {'p': 'p1', 'v': 10});
      final state = GameEngine.compute(g, log.events).stateAs<CounterState>();
      expect(state.periodPoints(g), [
        {'p0': 12, 'p1': 8},
        {'p0': 3, 'p1': 10},
      ]);
    });
  });

  group('placements', () {
    test('musical chairs: players go out from last place up, the last one in wins', () {
      final g = game(GameMode.placements, players: 4, settings: {'order': 'out', 'placePoints': '3,2,1'});
      final log = Log()..add('place', {'p': 'p2'});
      var snap = GameEngine.compute(g, log.events);
      expect(snap.finished, isFalse);
      expect(snap.standings.map((s) => (s.participantId, s.rank, s.score)), [
        ('p0', 0, 0),
        ('p1', 0, 0),
        ('p3', 0, 0),
        ('p2', 4, 0),
      ], reason: 'players still in lead; 4th gets no points');
      expect(snap.summary, '3 still in');

      log
        ..add('place', {'p': 'p2'})
        ..add('place', {'p': 'p0'})
        ..add('place', {'p': 'p3'});
      snap = GameEngine.compute(g, log.events);
      expect(snap.finished, isTrue);
      expect(snap.winners, ['p1']);
      expect({for (final s in snap.standings) s.participantId: (s.rank, s.score)}, {'p1': (1, 3), 'p3': (2, 2), 'p0': (3, 1), 'p2': (4, 0)});
      expect(snap.standings.first.detail, '1st');
      expect(snap.standings[1].detail, 'Out · 2nd');
      expect(snap.describe(log.events.first), 'P2 is out');
    });

    test('race: players finish from first place down', () {
      final g = game(GameMode.placements, players: 3, settings: {'order': 'finish', 'placePoints': '5,3'});
      final log = Log()
        ..add('place', {'p': 'p1'})
        ..add('place', {'p': 'p0'});
      final snap = GameEngine.compute(g, log.events);
      expect(snap.finished, isTrue);
      expect(snap.winners, ['p1']);
      expect({for (final s in snap.standings) s.participantId: (s.rank, s.score)}, {'p1': (1, 5), 'p0': (2, 3), 'p2': (3, 0)});
      expect(snap.summary, '1st P1 · 2nd P0 · 3rd P2');
    });

    test('undo brings a player back; ending early shares 1st among those still in', () {
      final g = game(GameMode.placements, players: 4);
      final log = Log();
      final out = log.add('place', {'p': 'p0'});
      log.add('undo', {'target': out});
      expect(GameEngine.compute(g, log.events).stateAs<PlacementsState>().order, isEmpty);

      log
        ..add('place', {'p': 'p3'})
        ..add('end');
      final snap = GameEngine.compute(g, log.events);
      expect(snap.winners, ['p0', 'p1', 'p2']);
    });

    test('point tables and ordinals', () {
      expect(parsePlacePoints('5, 3,1'), [5, 3, 1]);
      expect(parsePlacePoints(''), [3, 2, 1]);
      expect(parsePlacePoints('x'), [3, 2, 1]);
      expect(pointsForPlace([3, 2, 1], 4), 0);
      expect([1, 2, 3, 4, 11, 12, 13, 21, 22, 23, 101].map(ordinal), ['1st', '2nd', '3rd', '4th', '11th', '12th', '13th', '21st', '22nd', '23rd', '101st']);
    });
  });

  group('undo / redo', () {
    test('undo removes the target and redo restores it', () {
      final g = game(GameMode.counter);
      final log = Log();
      final first = log.add('add', {'p': 'p0', 'v': 1});
      final second = log.add('add', {'p': 'p0', 'v': 2});
      log.add('undo', {'target': second});
      var snap = GameEngine.compute(g, log.events);
      expect(snap.stateAs<CounterState>().scores['p0'], 1);
      expect(snap.canRedo, isTrue);

      log.add('redo', {'target': second});
      snap = GameEngine.compute(g, log.events);
      expect(snap.stateAs<CounterState>().scores['p0'], 3);
      expect(snap.canRedo, isFalse);

      log.add('undo', {'target': second});
      log.add('add', {'p': 'p1', 'v': 1});
      snap = GameEngine.compute(g, log.events);
      expect(snap.canRedo, isFalse, reason: 'a new score clears redo');
      expect(snap.effective.map((e) => e.id), contains(first));
    });

    test('an end event can be undone', () {
      final g = game(GameMode.counter);
      final log = Log();
      final end = log.add('end');
      expect(GameEngine.compute(g, log.events).finished, isTrue);
      log.add('undo', {'target': end});
      expect(GameEngine.compute(g, log.events).finished, isFalse);
    });
  });

  group('who scored', () {
    Game teams(GameMode mode, {Map<String, dynamic> settings = const {}}) => Game(
          id: 'g',
          title: 'Teams',
          templateId: mode.name,
          mode: mode,
          settings: settings,
          participants: const [
            Participant(id: 'p0', name: 'Reds', members: ['Ann', 'Bob', 'Cy']),
            Participant(id: 'p1', name: 'Blues', members: ['Dee', 'Eve']),
          ],
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );

    test('every tagged member gets the full points; the latest tag wins', () {
      final g = teams(GameMode.counter);
      final log = Log();
      final goal = log.add('add', {'p': 'p0', 'v': 2});
      log.add('tag', tagData(goal, [0, 1]));
      var snap = GameEngine.compute(g, log.events);
      expect(snap.memberPoints, {'p0': {0: 2, 1: 2}});
      expect(snap.describe(log.events[0]), 'Reds +2 · Ann, Bob');
      expect(snap.membersLine(g.participants[0]), 'Ann 2 · Bob 2 · Cy');
      expect(snap.stateAs<CounterState>().scores['p0'], 2, reason: 'tags never change the score');

      log.add('tag', tagData(goal, [2]));
      snap = GameEngine.compute(g, log.events);
      expect(snap.memberPoints, {'p0': {2: 2}});
      expect(snap.memberPointsByName, {'Cy': 2});

      log.add('tag', tagData(goal, []));
      expect(GameEngine.compute(g, log.events).memberPoints, isEmpty);
    });

    test('a tag on an undone score is ignored and undo skips tags', () {
      final g = teams(GameMode.counter);
      final log = Log();
      final goal = log.add('add', {'p': 'p0', 'v': 1});
      log.add('tag', tagData(goal, [0]));
      var snap = GameEngine.compute(g, log.events);
      expect(snap.canUndo, isTrue);
      expect(snap.log.map((e) => e.type), ['add'], reason: 'tags are not shown as log lines');

      log.add('undo', {'target': goal});
      snap = GameEngine.compute(g, log.events);
      expect(snap.memberPoints, isEmpty);
      expect(snap.canUndo, isFalse, reason: 'only the tag is left');
    });

    test('tagging does not clear redo', () {
      final g = teams(GameMode.counter);
      final log = Log();
      final first = log.add('add', {'p': 'p0', 'v': 1});
      final second = log.add('add', {'p': 'p0', 'v': 1});
      log.add('undo', {'target': second});
      log.add('tag', tagData(first, [1]));
      expect(GameEngine.compute(g, log.events).redoTarget, second);
    });

    test('tags count after the game ends, scores after the end do not', () {
      final g = teams(GameMode.counter, settings: {'target': 1});
      final log = Log();
      final winner = log.add('add', {'p': 'p0', 'v': 1});
      final late = log.add('add', {'p': 'p1', 'v': 1});
      log.add('tag', tagData(winner, [0]));
      log.add('tag', tagData(late, [0]));
      final snap = GameEngine.compute(g, log.events);
      expect(snap.finished, isTrue);
      expect(snap.memberPoints, {'p0': {0: 1}});
    });

    test('sets points can be tagged; players without teams cannot', () {
      final g = teams(GameMode.sets);
      final log = Log();
      final point = log.add('point', {'p': 'p1'});
      log.add('tag', tagData(point, [0, 1]));
      expect(GameEngine.compute(g, log.events).memberPoints, {'p1': {0: 1, 1: 1}});

      final solo = game(GameMode.counter);
      final soloLog = Log();
      final add = soloLog.add('add', {'p': 'p0', 'v': 1});
      soloLog.add('tag', tagData(add, [0]));
      expect(GameEngine.compute(solo, soloLog.events).creditable, isEmpty);
    });

    test('member points survive a JSON round trip', () {
      final g = teams(GameMode.counter).copyWith(memberPoints: {'Ann': 3});
      expect(Game.fromJson(g.toJson()).memberPoints, {'Ann': 3});
      expect(g.toMetaJson().containsKey('memberPoints'), isFalse, reason: 'never shared');
    });
  });

  group('rounds', () {
    test('rummy style elimination leaves the last player as winner', () {
      final g = game(GameMode.rounds, players: 3, settings: {'lowWins': true, 'eliminateAt': 100});
      final log = Log()
        ..add('round', {'s': {'p0': 10, 'p1': 60, 'p2': 50}})
        ..add('round', {'s': {'p0': 20, 'p1': 40, 'p2': 10}});
      var snap = GameEngine.compute(g, log.events);
      expect(snap.finished, isFalse);
      expect(RoundsEngine.isOut(snap.stateAs<RoundsState>(), g, 'p1'), isTrue);
      expect(snap.standings.last.participantId, 'p1');

      log.add('round', {'s': {'p0': 0, 'p1': 0, 'p2': 45}});
      snap = GameEngine.compute(g, log.events);
      expect(snap.finished, isTrue);
      expect(snap.winners, ['p0']);
    });

    test('editing a round changes totals', () {
      final g = game(GameMode.rounds);
      final log = Log()
        ..add('round', {'s': {'p0': 5, 'p1': 3}})
        ..add('editRound', {'i': 0, 's': {'p0': 1, 'p1': 3}});
      final state = GameEngine.compute(g, log.events).stateAs<RoundsState>();
      expect(state.totalOf('p0'), 1);
    });

    test('golf ends after max rounds with lowest winning', () {
      final g = game(GameMode.rounds, settings: {'lowWins': true, 'maxRounds': 2});
      final log = Log()
        ..add('round', {'s': {'p0': 4, 'p1': 3}})
        ..add('round', {'s': {'p0': 4, 'p1': 6}});
      final snap = GameEngine.compute(g, log.events);
      expect(snap.finished, isTrue);
      expect(snap.winners, ['p0']);
    });
  });

  group('sets', () {
    Log points(Log log, String pid, int n) {
      for (var i = 0; i < n; i++) {
        log.add('point', {'p': pid});
      }
      return log;
    }

    test('needs a two point lead', () {
      final g = game(GameMode.sets, settings: {'points': 11, 'winBy': 2, 'sets': 2});
      final log = Log();
      points(log, 'p0', 10);
      points(log, 'p1', 10);
      points(log, 'p0', 1);
      var state = GameEngine.compute(g, log.events).stateAs<SetsState>();
      expect(state.sets, isEmpty);
      expect(state.current, [11, 10]);
      points(log, 'p0', 1);
      state = GameEngine.compute(g, log.events).stateAs<SetsState>();
      expect(state.sets, [
        [12, 10]
      ]);
    });

    test('cap ends a set without a two point lead', () {
      final g = game(GameMode.sets, settings: {'points': 21, 'winBy': 2, 'cap': 30, 'sets': 1});
      final log = Log();
      for (var i = 0; i < 29; i++) {
        points(log, 'p0', 1);
        points(log, 'p1', 1);
      }
      points(log, 'p1', 1);
      final snap = GameEngine.compute(g, log.events);
      expect(snap.finished, isTrue);
      expect(snap.winners, ['p1']);
    });

    test('match ends after enough sets and uses deciding set points', () {
      final g = game(GameMode.sets, settings: {'points': 25, 'sets': 2, 'decidingPoints': 15});
      final log = Log();
      points(log, 'p0', 25);
      points(log, 'p1', 25);
      points(log, 'p1', 15);
      final snap = GameEngine.compute(g, log.events);
      expect(snap.finished, isTrue);
      expect(snap.winners, ['p1']);
      expect(snap.resultText, contains('2-1'));
    });

    test('table tennis serve changes every two points then every point at deuce', () {
      final g = game(GameMode.sets, settings: {'points': 11, 'sets': 3, 'serveEvery': 2});
      final log = Log();
      int server() => GameEngine.compute(g, log.events).stateAs<SetsState>().server;
      expect(server(), 0);
      points(log, 'p0', 2);
      expect(server(), 1);
      points(log, 'p1', 2);
      expect(server(), 0);
      points(log, 'p0', 8);
      points(log, 'p1', 8);
      expect(server(), 0, reason: '20 points played, 10 changes');
      points(log, 'p1', 1);
      expect(server(), 1);
      points(log, 'p0', 1);
      expect(server(), 0);
    });
  });

  group('cricket', () {
    test('extras, wickets and over rollover', () {
      final g = game(GameMode.cricket, settings: {'overs': 2, 'wickets': 2});
      final log = Log()
        ..add('ball', {'r': 1})
        ..add('ball', {'r': 0, 'x': 'wd'})
        ..add('ball', {'r': 4, 'x': 'nb'})
        ..add('ball', {'r': 0, 'w': true})
        ..add('ball', {'r': 2, 'x': 'lb'})
        ..add('ball', {'r': 6})
        ..add('ball', {'r': 0})
        ..add('ball', {'r': 1});
      final state = GameEngine.compute(g, log.events).stateAs<CricketState>();
      final inn = state.current;
      expect(inn.runs, 1 + 1 + 5 + 0 + 2 + 6 + 0 + 1);
      expect(inn.extras, 1 + 1 + 2);
      expect(inn.wickets, 1);
      expect(inn.legalBalls, 6);
      expect(inn.overs, '1.0');
      expect(inn.currentOver, isEmpty);
    });

    test('chase won by wickets and defended by runs', () {
      final g = game(GameMode.cricket, settings: {'overs': 1, 'wickets': 3});
      final log = Log();
      for (var i = 0; i < 6; i++) {
        log.add('ball', {'r': 2});
      }
      var snap = GameEngine.compute(g, log.events);
      expect(snap.stateAs<CricketState>().target, 13);
      log.add('ball', {'r': 6});
      log.add('ball', {'r': 0, 'w': true});
      log.add('ball', {'r': 6});
      log.add('ball', {'r': 1});
      snap = GameEngine.compute(g, log.events);
      expect(snap.finished, isTrue);
      expect(snap.winners, ['p1']);
      expect(snap.resultText, 'P1 won by 2 wickets');
    });

    test('team batting first wins when the chase falls short', () {
      final g = game(GameMode.cricket, settings: {'overs': 1, 'wickets': 1});
      final log = Log()
        ..add('ball', {'r': 4})
        ..add('endInnings')
        ..add('ball', {'r': 1})
        ..add('ball', {'r': 0, 'w': true});
      final snap = GameEngine.compute(g, log.events);
      expect(snap.finished, isTrue);
      expect(snap.resultText, 'P0 won by 3 runs');
    });
  });

  test('push ids sort by time', () {
    final a = PushId.next(1000);
    final b = PushId.next(1000);
    final c = PushId.next(2000);
    expect(a.compareTo(b), lessThan(0));
    expect(b.compareTo(c), lessThan(0));
    expect(a.length, 20);
  });

  test('game json round trip', () {
    final g = game(GameMode.rounds, settings: {'lowWins': true}).copyWith(
      participants: const [
        Participant(id: 'p0', name: 'Reds', members: ['Ann', 'Bob']),
        Participant(id: 'p1', name: 'Blues'),
      ],
      shareCode: 'abc123',
    );
    final back = Game.fromJson(g.toJson());
    expect(back.participants.first.members, ['Ann', 'Bob']);
    expect(back.settings['lowWins'], isTrue);
    expect(back.shareCode, 'abc123');
    expect(back.mode, GameMode.rounds);
  });
}
