import 'package:flutter_test/flutter_test.dart';
import 'package:scoreease/engine/engine.dart';
import 'package:scoreease/engine/event_scoring.dart';
import 'package:scoreease/engine/meet.dart';
import 'package:scoreease/features/play/export.dart';

Game _game(GameMode mode, List<Participant> participants, {Map<String, dynamic> settings = const {}, String id = 'g'}) => Game(
      id: id,
      title: 'Test',
      templateId: mode.name,
      mode: mode,
      settings: settings,
      participants: participants,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      eventId: 'm',
    );

GameSnapshot _play(Game game, List<(String, Map<String, dynamic>)> events) => GameEngine.compute(game, [
      for (final (i, (type, data)) in events.indexed) ScoreEvent(id: 'e${i.toString().padLeft(4, '0')}', type: type, data: data, ts: i),
    ]);

void main() {
  test('rounds export a row per round and totals', () {
    final snap = _play(_game(GameMode.rounds, const [Participant(id: 'p0', name: 'Ann'), Participant(id: 'p1', name: 'Bob')]), [
      ('round', {'s': {'p0': 10, 'p1': 5}}),
      ('round', {'s': {'p0': 3, 'p1': 7}}),
    ]);
    expect(gameCsv(snap).split('\n'), ['Round,Ann,Bob', '1,10,5', '2,3,7', 'Total,13,12']);
  });

  test('placements export places, points and who is still in; names with commas are quoted', () {
    final snap = _play(
      _game(GameMode.placements, const [
        Participant(id: 'p0', name: 'Ann'),
        Participant(id: 'p1', name: 'Bob, Jr'),
        Participant(id: 'p2', name: 'Cy'),
      ], settings: {'order': 'out'}),
      [('place', {'p': 'p2'})],
    );
    expect(gameCsv(snap).split('\n'), ['Place,Name,Points', 'Still in,Ann,0', 'Still in,"Bob, Jr",0', '3,Cy,1']);
  });

  test('a finished game ends with its result, and team members with their points', () {
    final snap = _play(
      _game(GameMode.counter, const [
        Participant(id: 'p0', name: 'Reds', members: ['Ann', 'Bob']),
        Participant(id: 'p1', name: 'Blues', members: ['Cy']),
      ], settings: {'target': 1}),
      [('add', {'p': 'p0', 'v': 1}), ('tag', {'target': 'e0000', 'm': {'m1': 1}})],
    );
    final lines = gameCsv(snap).split('\n');
    expect(lines.take(3), ['Rank,Name,Score', '1,Reds,1', '2,Blues,0']);
    expect(lines, containsAllInOrder(['Team,Member,Points involved', 'Reds,Ann,0', 'Reds,Bob,1', 'Result,Reds wins!']));
  });

  test('an event exports team totals, each game, and everyone who played', () {
    final meet = Meet(
      id: 'm',
      name: 'Games day',
      teams: const [
        MeetTeam(id: 'red', name: 'Reds', members: ['Ann', 'Bob']),
        MeetTeam(id: 'blue', name: 'Blues', members: ['Cy', 'Dee']),
      ],
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final race = _play(
      _game(GameMode.placements, const [
        Participant(id: 'p0', name: 'Ann', teamId: 'red'),
        Participant(id: 'p1', name: 'Cy', teamId: 'blue'),
      ], settings: {'order': 'finish'}),
      [('place', {'p': 'p1'})],
    );
    final lines = meetCsv(scoreMeet(meet, [race])).split('\n');
    expect(lines.first, 'Games day');
    expect(lines, containsAllInOrder(['Team,Points,Players', 'Blues,3,Cy; Dee', 'Reds,2,Ann; Bob']));
    expect(lines, containsAllInOrder(['Game,Status,Reds,Blues', 'Test,Finished,2,3']));
    expect(lines, containsAllInOrder(['Name,Team,Points,Played,Wins,Scored', 'Cy,Blues,3,1,1,0', 'Ann,Reds,2,1,0,0']));
    expect(lines.last, 'Result,Blues won!');
  });

  test('a sub shows in the member table, and a retired side instead of a rank', () {
    final snap = _play(
      _game(GameMode.counter, const [
        Participant(id: 'p0', name: 'Reds', members: ['Ann', 'Bob']),
        Participant(id: 'p1', name: 'Blues', members: ['Cy']),
        Participant(id: 'p2', name: 'Greens', members: ['Dee']),
      ]),
      [
        ('add', {'p': 'p0', 'v': 2}),
        ('tag', {'target': 'e0000', 'm': {'m0': 1}}),
        ('sub', {'p': 'p0', 'o': 0, 'n': 'Eli'}),
        ('add', {'p': 'p0', 'v': 1}),
        ('tag', {'target': 'e0003', 'm': {'m2': 1}}),
        ('add', {'p': 'p2', 'v': 5}),
        ('retire', {'p': 'p2'}),
      ],
    );
    expect(gameCsv(snap).split('\n'), [
      'Rank,Name,Score',
      '1,Reds,3',
      '2,Blues,0',
      'Retired,Greens,5',
      '',
      'Team,Member,Points involved',
      'Reds,Ann,2',
      'Reds,Bob,0',
      'Reds,Eli,1',
    ]);
  });

  test('a player who joined a rounds game has blanks for the rounds before', () {
    final snap = _play(_game(GameMode.rounds, const [Participant(id: 'p0', name: 'Ann'), Participant(id: 'p1', name: 'Bob')]), [
      ('round', {'s': {'p0': 1, 'p1': 2}}),
      ('addSide', {'n': 'Cy', 'c': 2}),
      ('round', {'s': {'p0': 3, 'p1': 4, 'e0001': 5}}),
    ]);
    expect(gameCsv(snap).split('\n'), ['Round,Ann,Bob,Cy', '1,1,2,', '2,3,4,5', 'Total,4,6,5']);
  });
}
