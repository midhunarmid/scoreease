import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:scoreease/engine/engine.dart';
import 'package:scoreease/engine/event_scoring.dart';
import 'package:scoreease/engine/meet.dart';

final _meet = Meet(
  id: 'm',
  name: 'Office day',
  teams: const [
    MeetTeam(id: 'red', name: 'Reds', members: ['Ann', 'Bob', 'Cy']),
    MeetTeam(id: 'blue', name: 'Blues', color: 1, members: ['Dee', 'Eve', 'Fay']),
  ],
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

var _clock = 0;

Game _game(GameMode mode, List<Participant> participants, {Map<String, dynamic> settings = const {}}) => Game(
      id: 'g${_clock++}',
      title: mode.name,
      templateId: mode.name,
      mode: mode,
      settings: settings,
      participants: participants,
      createdAt: DateTime(2026, 1, 1, 0, _clock),
      updatedAt: DateTime(2026),
      eventId: 'm',
    );

GameSnapshot _play(Game game, List<(String, Map<String, dynamic>)> events) => GameEngine.compute(game, [
      for (final (i, (type, data)) in events.indexed) ScoreEvent(id: 'e${i.toString().padLeft(4, '0')}', type: type, data: data, ts: i),
    ]);

void main() {
  test('places add up for players and their teams; team games score the team', () {
    final chairs = _play(
      _game(GameMode.placements, const [
        Participant(id: 'p0', name: 'Ann', teamId: 'red'),
        Participant(id: 'p1', name: 'Bob', teamId: 'red'),
        Participant(id: 'p2', name: 'Dee', teamId: 'blue'),
        Participant(id: 'p3', name: 'Eve', teamId: 'blue'),
      ], settings: {'order': 'out'}),
      [('place', {'p': 'p1'}), ('place', {'p': 'p2'}), ('place', {'p': 'p0'})],
    );
    final tug = _play(
      _game(GameMode.counter, const [
        Participant(id: 'p0', name: 'Reds', teamId: 'red', members: ['Ann', 'Bob', 'Cy']),
        Participant(id: 'p1', name: 'Blues', teamId: 'blue', members: ['Dee', 'Eve', 'Fay']),
      ], settings: {'target': 1}),
      [('add', {'p': 'p0', 'v': 1}), ('tag', {'target': 'e0000', 'm': {'m0': 1}})],
    );
    final unfinished = _play(
      _game(GameMode.placements, const [
        Participant(id: 'p0', name: 'Cy', teamId: 'red'),
        Participant(id: 'p1', name: 'Fay', teamId: 'blue'),
        Participant(id: 'p2', name: 'Eve', teamId: 'blue'),
      ]),
      [('place', {'p': 'p0'})],
    );

    final s = scoreMeet(_meet, [tug, unfinished, chairs]);
    // Chairs: Eve 1st 3, Ann 2nd 2, Dee 3rd 1, Bob 4th 0. Tug: Reds 1st 3, Blues 2nd 2.
    expect(s.games.map((g) => g.teamPoints), [
      {'red': 2, 'blue': 4},
      {'red': 3, 'blue': 2},
      <String, int>{},
    ], reason: 'oldest game first; an unfinished game gives nothing yet');
    expect(s.teamTotals, {'red': 5, 'blue': 6});
    expect(s.leaders, ['blue']);
    expect(s.resultText, 'Blues won!');
    expect(s.rankedTeams.map((t) => t.id), ['blue', 'red']);

    expect([for (final p in s.people) (p.name, p.points, p.played, p.wins, p.scored)], [
      ('Eve', 3, 2, 1, 0),
      ('Ann', 2, 2, 0, 1),
      ('Dee', 1, 2, 0, 0),
      ('Cy', 0, 1, 0, 0),
      ('Fay', 0, 1, 0, 0),
      ('Bob', 0, 2, 0, 0),
    ]);
  });

  test('a game\'s own points table wins over the event\'s; ties share points; equal totals draw', () {
    final race = _play(
      _game(GameMode.placements, const [
        Participant(id: 'p0', name: 'Ann', teamId: 'red'),
        Participant(id: 'p1', name: 'Dee', teamId: 'blue'),
      ], settings: {'order': 'finish', 'placePoints': '5,5'}),
      [('place', {'p': 'p0'})],
    );
    final s = scoreMeet(_meet, [race]);
    expect(s.teamTotals, {'red': 5, 'blue': 5});
    expect(s.leaders, ['red', 'blue']);
    expect(s.resultText, 'It\'s a draw!');
    expect(scoreMeet(_meet, const []).resultText, isNull, reason: 'nothing played yet');
  });

  test('splitting people gives teams that differ by at most one', () {
    final people = [for (var i = 0; i < 17; i++) 'P$i'];
    final teams = splitEvenly(people, 2, random: Random(1));
    expect(teams.map((t) => t.length), [9, 8]);
    expect({...teams[0], ...teams[1]}, people.toSet());
  });

  test('an event survives a JSON round trip', () {
    final again = Meet.fromJson(_meet.copyWith(finished: true).toJson());
    expect(again.teams.map((t) => t.toJson()), _meet.teams.map((t) => t.toJson()));
    expect(again.finished, isTrue);
    expect(again.placePoints, '3,2,1');
    expect(again.teamOf('eve')?.id, 'blue');
  });

  test('subs count as having played, but a side\'s place goes to whoever finished', () {
    final race = _play(
      _game(GameMode.placements, const [
        Participant(id: 'p0', name: 'Ann', teamId: 'red'),
        Participant(id: 'p1', name: 'Dee', teamId: 'blue'),
      ], settings: {'order': 'finish'}),
      [('sub', {'p': 'p0', 'n': 'Bob'}), ('place', {'p': 'p0'})],
    );
    final tug = _play(
      _game(GameMode.counter, const [
        Participant(id: 'p0', name: 'Reds', teamId: 'red', members: ['Ann', 'Bob']),
        Participant(id: 'p1', name: 'Blues', teamId: 'blue', members: ['Dee']),
      ], settings: {'target': 2}),
      [
        ('add', {'p': 'p0', 'v': 1}),
        ('sub', {'p': 'p0', 'o': 1, 'n': 'Cy'}),
        ('add', {'p': 'p0', 'v': 1}),
      ],
    );
    final doubleBack = _play(
      _game(GameMode.counter, const [
        Participant(id: 'p0', name: 'Eve', teamId: 'blue'),
        Participant(id: 'p1', name: 'Fay', teamId: 'blue'),
      ], settings: {'target': 3}),
      [
        ('add', {'p': 'p0', 'v': 1}),
        ('sub', {'p': 'p0', 'n': 'Ann'}),
        ('add', {'p': 'p0', 'v': 2}),
      ],
    );
    final s = scoreMeet(_meet, [race, tug, doubleBack]);
    final line = {for (final p in s.people) p.name: p};
    expect(line['Bob']!.played, 2, reason: 'took over in the race, and left the tug part way');
    expect(line['Cy']!.played, 1);
    expect(line['Eve']!.played, 1);
    expect(line['Eve']!.points, 0, reason: 'replaced, so the win went to Ann');
    expect(line['Ann']!.points, 3);
    expect(line['Ann']!.wins, 1);
  });

  test('a retired side gets no points, even if it was ahead', () {
    final snap = _play(
      _game(GameMode.counter, const [
        Participant(id: 'p0', name: 'Ann', teamId: 'red'),
        Participant(id: 'p1', name: 'Dee', teamId: 'blue'),
        Participant(id: 'p2', name: 'Eve', teamId: 'blue'),
      ]),
      [
        ('add', {'p': 'p0', 'v': 9}),
        ('add', {'p': 'p1', 'v': 1}),
        ('retire', {'p': 'p0'}),
        ('end', {}),
      ],
    );
    final s = scoreMeet(_meet, [snap]);
    expect(s.teamTotals, {'red': 0, 'blue': 5});
    final ann = s.people.firstWhere((p) => p.name == 'Ann');
    expect(ann.points, 0);
    expect(ann.played, 1);
  });

  test('moving someone keeps totals, and the leaderboard shows their team now', () {
    final race = _play(
      _game(GameMode.placements, const [
        Participant(id: 'p0', name: 'Ann', teamId: 'red'),
        Participant(id: 'p1', name: 'Dee', teamId: 'blue'),
      ], settings: {'order': 'finish'}),
      [('place', {'p': 'p0'})],
    );
    final before = scoreMeet(_meet, [race]);
    final after = scoreMeet(_meet.moved('Ann', 'blue'), [race]);
    expect(after.teamTotals, before.teamTotals);
    expect(after.people.firstWhere((p) => p.name == 'Ann').teamId, 'blue');
    expect(after.meet.team('blue')!.members, ['Dee', 'Eve', 'Fay', 'Ann']);
    expect(after.meet.team('red')!.members, ['Bob', 'Cy']);
  });

  test('roster changes: rename, swap, remove', () {
    final renamed = _meet.renamed('ann', 'Anna').renamed('Blues', 'Navy');
    expect(renamed.team('red')!.members.first, 'Anna');
    expect(renamed.team('blue')!.name, 'Navy');

    final swapped = _meet.swapped('Ann', 'Eve');
    expect(swapped.team('red')!.members, ['Eve', 'Bob', 'Cy']);
    expect(swapped.team('blue')!.members, ['Dee', 'Ann', 'Fay']);

    expect(_meet.without('bob').team('red')!.members, ['Ann', 'Cy']);
    expect(_meet.withPerson('Gus', 'blue').teamOf('gus')!.id, 'blue');
  });
}
