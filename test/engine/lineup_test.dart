import 'package:flutter_test/flutter_test.dart';
import 'package:scoreease/engine/counter_engine.dart';
import 'package:scoreease/engine/engine.dart';
import 'package:scoreease/engine/placements_engine.dart';
import 'package:scoreease/engine/rounds_engine.dart';
import 'package:scoreease/engine/sets_engine.dart';

Game _game(GameMode mode, List<Participant> participants, {Map<String, dynamic> settings = const {}, String template = 'counter'}) => Game(
      id: 'g',
      title: 'Test',
      templateId: template,
      mode: mode,
      settings: settings,
      participants: participants,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

/// Event ids e0000, e0001... so tests can point at them.
List<ScoreEvent> _log(List<(String, Map<String, dynamic>)> events) => [
      for (final (i, (type, data)) in events.indexed) ScoreEvent(id: 'e${i.toString().padLeft(4, '0')}', type: type, data: data, ts: i),
    ];

GameSnapshot _play(Game game, List<(String, Map<String, dynamic>)> events) => GameEngine.compute(game, _log(events));

const _reds = Participant(id: 'p0', name: 'Reds', members: ['Ann', 'Bob']);
const _blues = Participant(id: 'p1', name: 'Blues', members: ['Cy', 'Dee']);
const _ann = Participant(id: 'p0', name: 'Ann');
const _bob = Participant(id: 'p1', name: 'Bob');
const _cy = Participant(id: 'p2', name: 'Cy');

void main() {
  group('substitutions', () {
    test('earlier credit stays with the player who scored it', () {
      final snap = _play(_game(GameMode.counter, const [_reds, _blues]), [
        ('add', {'p': 'p0', 'v': 2}),
        ('tag', {'target': 'e0000', 'm': {'m0': 1}}),
        ('sub', {'p': 'p0', 'o': 0, 'n': 'Eli'}),
        ('add', {'p': 'p0', 'v': 3}),
        ('tag', {'target': 'e0003', 'm': {'m2': 1}}),
      ]);
      final reds = snap.game.participant('p0')!;
      expect(reds.members, ['Ann', 'Bob', 'Eli']);
      expect(reds.onCourt, [2, 1]);
      expect(snap.memberPointsByName, {'Ann': 2, 'Eli': 3});
      expect(snap.stateAs<CounterState>().scores['p0'], 5);
      expect(snap.describe(snap.effective[2]), 'Ann replaced by Eli');
      expect(snap.membersLine(reds), 'Eli 3 · Ann 2 · Bob');
    });

    test('someone coming back on keeps the same index', () {
      final snap = _play(_game(GameMode.counter, const [_reds, _blues]), [
        ('add', {'p': 'p0', 'v': 1}),
        ('sub', {'p': 'p0', 'o': 0, 'n': 'Eli'}),
        ('sub', {'p': 'p0', 'o': 2, 'n': 'ann'}),
      ]);
      final reds = snap.game.participant('p0')!;
      expect(reds.members, ['Ann', 'Bob', 'Eli']);
      expect(reds.onCourt, [0, 1]);
    });

    test('undo and redo work like any other action', () {
      final events = [
        ('add', <String, dynamic>{'p': 'p0', 'v': 1}),
        ('sub', <String, dynamic>{'p': 'p0', 'o': 0, 'n': 'Eli'}),
      ];
      final undone = _play(_game(GameMode.counter, const [_reds, _blues]), [...events, ('undo', {'target': 'e0001'})]);
      expect(undone.game.participant('p0')!.members, ['Ann', 'Bob']);
      expect(undone.canRedo, isTrue);
      expect(undone.notes, isEmpty);

      final redone = _play(_game(GameMode.counter, const [_reds, _blues]), [
        ...events,
        ('undo', {'target': 'e0001'}),
        ('redo', {'target': 'e0001'}),
      ]);
      expect(redone.game.participant('p0')!.members, ['Ann', 'Bob', 'Eli']);
    });

    test('are refused once the game has ended, and leave no log line', () {
      final snap = _play(_game(GameMode.counter, const [_reds, _blues], settings: {'target': 1}), [
        ('add', {'p': 'p0', 'v': 1}),
        ('sub', {'p': 'p0', 'o': 0, 'n': 'Eli'}),
      ]);
      expect(snap.finished, isTrue);
      expect(snap.game.participant('p0')!.members, ['Ann', 'Bob']);
      expect(snap.effective.map((e) => e.type), ['add']);
      expect(snap.canSub, isFalse);
    });

    test('before anything is scored the swap is as if it was set up that way', () {
      final snap = _play(_game(GameMode.counter, const [_reds, _blues]), [
        ('sub', {'p': 'p0', 'o': 0, 'n': 'Eli'}),
        ('sub', {'p': 'p1', 'o': 1}),
      ]);
      expect(snap.game.participant('p0')!.members, ['Eli', 'Bob']);
      expect(snap.game.participant('p1')!.members, ['Cy']);
      expect(snap.game.participant('p0')!.court, isNull);
      expect(snap.eras, hasLength(1));
    });

    test('an individual side keeps its score and remembers who it was', () {
      final snap = _play(_game(GameMode.counter, const [_ann, _bob]), [
        ('add', {'p': 'p0', 'v': 4}),
        ('sub', {'p': 'p0', 'n': 'Eli'}),
        ('add', {'p': 'p0', 'v': 1}),
      ]);
      final side = snap.game.participant('p0')!;
      expect(side.name, 'Eli');
      expect(side.former, ['Ann']);
      expect(side.everyone, ['Ann', 'Eli']);
      expect(snap.stateAs<CounterState>().scores['p0'], 5);
      expect(snap.describe(snap.effective[0]), 'Ann +4');
      expect(snap.describe(snap.effective[2]), 'Eli +1');
    });

    test('team members can join and leave without a replacement', () {
      final snap = _play(_game(GameMode.counter, const [_reds, _blues]), [
        ('add', {'p': 'p0', 'v': 1}),
        ('sub', {'p': 'p0', 'n': 'Eli'}),
        ('sub', {'p': 'p0', 'o': 1}),
      ]);
      expect(snap.game.participant('p0')!.onCourt, [0, 2]);
      expect(snap.notes.values, ['Eli joined Reds', 'Bob left Reds']);
    });

    test('someone already on the side, or a side\'s last player leaving, is refused', () {
      const solo = Participant(id: 'p1', name: 'Blues', members: ['Cy']);
      final snap = _play(_game(GameMode.counter, const [_reds, solo]), [
        ('add', {'p': 'p0', 'v': 1}),
        ('sub', {'p': 'p0', 'o': 0, 'n': 'bob'}),
        ('sub', {'p': 'p1', 'o': 0}),
      ]);
      expect(snap.notes, isEmpty);
      expect(snap.effective.map((e) => e.type), ['add']);
    });

    test('two people can trade sides with two swaps', () {
      final snap = _play(_game(GameMode.counter, const [_reds, _blues]), [
        ('add', {'p': 'p0', 'v': 1}),
        ('sub', {'p': 'p0', 'o': 0, 'n': 'Cy'}),
        ('sub', {'p': 'p1', 'o': 0, 'n': 'Ann'}),
      ]);
      final reds = snap.game.participant('p0')!, blues = snap.game.participant('p1')!;
      expect(reds.onCourt.map((i) => reds.members[i]), ['Cy', 'Bob']);
      expect(blues.onCourt.map((i) => blues.members[i]), ['Ann', 'Dee']);
    });
  });

  group('badminton doubles', () {
    Game doubles() => _game(GameMode.sets, const [_reds, _blues], template: 'badminton', settings: {'points': 21, 'sets': 2});

    test('a substitute takes the court of the player they replace', () {
      final snap = _play(doubles(), [
        ('point', {'p': 'p0'}),
        ('sub', {'p': 'p0', 'o': 1, 'n': 'Eli'}),
      ]);
      final state = snap.stateAs<SetsState>();
      expect(SetsEngine.isDoubles(snap.game), isTrue);
      // Reds scored serving, so they switched: Bob's slot is on the right.
      expect(state.rightCourt[0], 1);
      expect(snap.game.participant('p0')!.playerIn(1), 'Eli');
      expect(SetsEngine.serveLine(state, snap.game), 'Ann → Dee · left court');
    });

    test('serve lines from before a sub still name who was playing', () {
      final snap = _play(doubles(), [
        ('serve', {'p': 'p0', 'm': 0, 'r': 0}),
        ('point', {'p': 'p0'}),
        ('sub', {'p': 'p0', 'o': 0, 'n': 'Eli'}),
        ('serve', {'p': 'p0', 'm': 0, 'r': 0}),
      ]);
      expect(snap.describe(snap.effective[0]), 'Ann serves to Cy');
      expect(snap.describe(snap.effective[3]), 'Eli serves to Cy');
    });

    test('teams keep their size', () {
      final snap = _play(doubles(), [
        ('point', {'p': 'p0'}),
        ('sub', {'p': 'p0', 'n': 'Eli'}),
        ('sub', {'p': 'p0', 'o': 0}),
      ]);
      expect(snap.notes, isEmpty);
      expect(snap.fixedTeams, isTrue);
      expect(SetsEngine.isDoubles(snap.game), isTrue);
    });
  });

  group('sides joining and leaving', () {
    test('sets and cricket always stay two sides', () {
      for (final mode in [GameMode.sets, GameMode.cricket]) {
        final snap = _play(_game(mode, const [_ann, _bob]), [
          ('addSide', {'n': 'Cy', 'c': 2}),
          ('retire', {'p': 'p1'}),
        ]);
        expect(snap.game.participants, hasLength(2), reason: mode.name);
        expect(snap.notes, isEmpty);
        expect(snap.canChangeSides, isFalse);
      }
    });

    test('a counter side can join any time, from the start value', () {
      final snap = _play(_game(GameMode.counter, const [_ann, _bob], settings: {'startAt': 301}), [
        ('add', {'p': 'p0', 'v': 100}),
        ('addSide', {'n': 'Cy', 'c': 2}),
        ('add', {'p': 'e0001', 'v': 1}),
      ]);
      expect(snap.stateAs<CounterState>().scores, {'p0': 201, 'p1': 301, 'e0001': 300});
      expect(snap.game.nameOf('e0001'), 'Cy');
    });

    test('team sides bring their members and event team', () {
      final snap = _play(_game(GameMode.counter, const [_reds, _blues]), [
        ('add', {'p': 'p0', 'v': 1}),
        ('addSide', {'n': 'Greens', 'c': 3, 't': 't2', 'm1': 'Hal', 'm0': 'Gus'}),
      ]);
      final greens = snap.game.participant('e0001')!;
      expect(greens.members, ['Gus', 'Hal']);
      expect(greens.teamId, 't2');
      expect(greens.color, 3);
    });

    test('two devices adding the same name only add it once', () {
      final snap = _play(_game(GameMode.counter, const [_ann, _bob]), [
        ('addSide', {'n': 'Cy', 'c': 2}),
        ('addSide', {'n': 'cy', 'c': 3}),
      ]);
      expect(snap.game.participants.map((p) => p.name), ['Ann', 'Bob', 'Cy']);
      expect(snap.effective, hasLength(1));
    });

    test('a retired side keeps its score but ranks last, can\'t score and can\'t win', () {
      final snap = _play(_game(GameMode.counter, const [_ann, _bob, _cy], settings: {'target': 5}), [
        ('add', {'p': 'p0', 'v': 4}),
        ('add', {'p': 'p1', 'v': 1}),
        ('retire', {'p': 'p0'}),
        ('add', {'p': 'p0', 'v': 4}),
      ]);
      expect(snap.finished, isFalse);
      expect(snap.stateAs<CounterState>().scores['p0'], 4);
      expect(snap.standings.last.participantId, 'p0');
      expect(snap.standings.last.detail, 'Retired');
      expect(snap.standings.first.participantId, 'p1');
      expect(snap.game.sides.map((p) => p.id), ['p1', 'p2']);

      final ended = _play(_game(GameMode.counter, const [_ann, _bob, _cy], settings: {'target': 5}), [
        ('add', {'p': 'p0', 'v': 4}),
        ('retire', {'p': 'p0'}),
        ('end', {}),
      ]);
      expect(ended.winners, isEmpty, reason: 'the two left are level at 0');
    });

    test('a side can\'t be left with nobody', () {
      final snap = _play(_game(GameMode.counter, const [_ann, _bob]), [
        ('add', {'p': 'p0', 'v': 1}),
        ('retire', {'p': 'p0'}),
        ('retire', {'p': 'p1'}),
      ]);
      expect(snap.game.sides.map((p) => p.id), ['p1']);
    });

    test('retiring when a side has already won the race ends the game', () {
      final snap = _play(_game(GameMode.counter, const [_ann, _bob], settings: {'target': 5, 'winBy': 2}), [
        ('add', {'p': 'p0', 'v': 5}),
        ('add', {'p': 'p1', 'v': 4}),
        ('retire', {'p': 'p1'}),
      ]);
      expect(snap.finished, isTrue);
      expect(snap.winners, ['p0']);
    });

    test('undo brings a retired side back', () {
      final snap = _play(_game(GameMode.counter, const [_ann, _bob]), [
        ('add', {'p': 'p0', 'v': 1}),
        ('retire', {'p': 'p0'}),
        ('undo', {'target': 'e0001'}),
        ('add', {'p': 'p0', 'v': 1}),
      ]);
      expect(snap.game.participant('p0')!.retired, isFalse);
      expect(snap.stateAs<CounterState>().scores['p0'], 2);
    });

    test('rounds: joining doesn\'t change whose deal is next', () {
      final game = _game(GameMode.rounds, const [_ann, _bob, _cy]);
      final before = _play(game, [
        ('round', {'s': {'p0': 1, 'p1': 1, 'p2': 1}}),
        ('round', {'s': {'p0': 1, 'p1': 1, 'p2': 1}}),
      ]);
      expect(RoundsEngine.dealer(before.stateAs<RoundsState>(), before.game), 'p2');

      final after = _play(game, [
        ('round', {'s': {'p0': 1, 'p1': 1, 'p2': 1}}),
        ('round', {'s': {'p0': 1, 'p1': 1, 'p2': 1}}),
        ('addSide', {'n': 'Dee', 'c': 3}),
      ]);
      expect(RoundsEngine.dealer(after.stateAs<RoundsState>(), after.game), 'p2');

      final next = _play(game, [
        ('round', {'s': {'p0': 1, 'p1': 1, 'p2': 1}}),
        ('round', {'s': {'p0': 1, 'p1': 1, 'p2': 1}}),
        ('addSide', {'n': 'Dee', 'c': 3}),
        ('round', {'s': {'p0': 1, 'p1': 1, 'p2': 1, 'e0002': 1}}),
      ]);
      expect(RoundsEngine.dealer(next.stateAs<RoundsState>(), next.game), 'e0002', reason: 'the new seat is next round the table');
    });

    test('rounds: a retired player loses their deal and the game can end', () {
      final snap = _play(_game(GameMode.rounds, const [_ann, _bob, _cy], settings: {'eliminateAt': 10}), [
        ('round', {'s': {'p0': 1, 'p1': 1, 'p2': 10}}),
        ('retire', {'p': 'p1'}),
      ]);
      expect(snap.finished, isTrue);
      expect(snap.winners, ['p0']);
      expect(snap.standings.firstWhere((s) => s.participantId == 'p1').detail, 'Retired');
      expect(RoundsEngine.active(snap.stateAs<RoundsState>(), snap.game), hasLength(1));
    });

    test('placements can change only until the first place', () {
      final game = _game(GameMode.placements, const [_ann, _bob, _cy]);
      final early = _play(game, [
        ('retire', {'p': 'p2'}),
        ('sub', {'p': 'p0', 'n': 'Eli'}),
        ('addSide', {'n': 'Dee', 'c': 3}),
        ('addSide', {'n': 'Fay', 'c': 4}),
        ('place', {'p': 'p1'}),
      ]);
      expect(early.game.participants.map((p) => p.name), ['Eli', 'Bob', 'Dee', 'Fay']);
      expect(early.game.participant('p2'), isNull, reason: 'removed outright, so places count from 4');
      expect(PlacementsEngine.places(early.stateAs<PlacementsState>(), early.game), {'p1': 4});
      expect(early.canSub, isFalse);
      expect(early.canChangeSides, isFalse);

      final late = _play(game, [
        ('place', {'p': 'p1'}),
        ('retire', {'p': 'p2'}),
        ('sub', {'p': 'p0', 'n': 'Eli'}),
        ('addSide', {'n': 'Dee', 'c': 3}),
      ]);
      expect(late.game.participants.map((p) => p.name), ['Ann', 'Bob', 'Cy']);
      expect(late.notes, isEmpty);
    });
  });

  group('renames', () {
    test('rewrite the name everywhere, even after the game ended, and keep undo and redo', () {
      final snap = _play(_game(GameMode.counter, const [_reds, _blues], settings: {'target': 1}), [
        ('add', {'p': 'p0', 'v': 1}),
        ('tag', {'target': 'e0000', 'm': {'m1': 1}}),
        ('rename', {'f': 'bob', 'n': 'Robert'}),
      ]);
      expect(snap.game.participant('p0')!.members, ['Ann', 'Robert']);
      expect(snap.memberPointsByName, {'Robert': 1});
      expect(snap.log.map((e) => e.type), ['add'], reason: 'not in the log');
      expect(snap.canUndo, isTrue);
    });

    test('apply to names that came on later, and chain', () {
      final snap = _play(_game(GameMode.counter, const [_reds, _blues]), [
        ('add', {'p': 'p0', 'v': 1}),
        ('sub', {'p': 'p0', 'o': 0, 'n': 'Bbo'}),
        ('rename', {'f': 'Bbo', 'n': 'Bo'}),
        ('rename', {'f': 'Bo', 'n': 'Boris'}),
      ]);
      expect(snap.game.participant('p0')!.members, ['Ann', 'Bob', 'Boris']);
      expect(snap.notes['e0001'], 'Ann replaced by Boris');
    });

    test('don\'t lose what could be redone', () {
      final snap = _play(_game(GameMode.counter, const [_ann, _bob]), [
        ('add', {'p': 'p0', 'v': 1}),
        ('undo', {'target': 'e0000'}),
        ('rename', {'f': 'Ann', 'n': 'Anna'}),
      ]);
      expect(snap.canRedo, isTrue);
      expect(snap.canUndo, isFalse, reason: 'only a spelling fix is left');
    });
  });

  group('saved copy', () {
    final events = _log([
      ('add', {'p': 'p0', 'v': 2}),
      ('sub', {'p': 'p0', 'o': 0, 'n': 'Eli'}),
      ('addSide', {'n': 'Greens', 'c': 3, 'm0': 'Gus'}),
      ('retire', {'p': 'p1'}),
      ('rename', {'f': 'Bob', 'n': 'Robert'}),
    ]);

    test('keeps the setup and adds the lineup, so replaying it changes nothing', () {
      final once = GameEngine.compute(_game(GameMode.counter, const [_reds, _blues]), events);
      final saved = once.toSaved(DateTime(2027));
      expect(saved.participants.map((p) => p.members), [['Ann', 'Bob'], ['Cy', 'Dee']]);
      expect(saved.current.map((p) => p.name), ['Reds', 'Blues', 'Greens']);
      expect(saved.sides.map((p) => p.name), ['Reds', 'Greens']);
      expect(saved.nameOf('e0002'), 'Greens');
      expect(saved.lineup.first.onCourt, [2, 1]);

      final twice = GameEngine.compute(saved, events);
      expect(twice.game.participant('p0')!.members, ['Ann', 'Robert', 'Eli']);
      expect(twice.game.participants, hasLength(3));
      expect(twice.toSaved(DateTime(2027)).toJson(), saved.toJson());
    });

    test('is dropped once undone, and survives JSON', () {
      final saved = GameEngine.compute(_game(GameMode.counter, const [_reds, _blues]), events).toSaved(DateTime(2027));
      final restored = Game.fromJson(saved.toJson());
      expect(restored.lineup.first.court, [2, 1]);
      expect(restored.lineup[1].retired, isTrue);
      expect(restored.participants, hasLength(2));

      final none = GameEngine.compute(saved, const []).toSaved(DateTime(2027));
      expect(none.lineup, isEmpty);
      expect(none.current.map((p) => p.name), ['Reds', 'Blues']);
    });

    test('never shares what the events decided', () {
      final saved = GameEngine.compute(_game(GameMode.counter, const [_reds, _blues]), events).toSaved(DateTime(2027));
      final meta = saved.toMetaJson();
      expect(meta.containsKey('lineup'), isFalse);
      expect((meta['participants'] as Map).keys, ['p0', 'p1']);
      expect(saved.lineup.first.toJson().containsKey('court'), isFalse);
    });
  });
}
