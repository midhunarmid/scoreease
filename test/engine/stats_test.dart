import 'package:flutter_test/flutter_test.dart';
import 'package:scoreease/engine/engine.dart';
import 'package:scoreease/features/players/stats.dart';

Game _saved(List<Participant> participants, List<(String, Map<String, dynamic>)> events, {Map<String, dynamic> settings = const {'target': 3}}) {
  final game = Game(
    id: 'g',
    title: 'Test',
    templateId: 'counter',
    mode: GameMode.counter,
    settings: settings,
    participants: participants,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  return GameEngine.compute(game, [
    for (final (i, (type, data)) in events.indexed) ScoreEvent(id: 'e${i.toString().padLeft(4, '0')}', type: type, data: data, ts: i),
  ]).toSaved(DateTime(2026));
}

void main() {
  test('everyone swapped in or out of a team shares its result and keeps their points', () {
    final stats = computeStats([
      _saved(const [
        Participant(id: 'p0', name: 'Reds', members: ['Ann', 'Bob']),
        Participant(id: 'p1', name: 'Blues', members: ['Cy']),
      ], [
        ('add', {'p': 'p0', 'v': 1}),
        ('tag', {'target': 'e0000', 'm': {'m0': 1}}),
        ('sub', {'p': 'p0', 'o': 0, 'n': 'Eli'}),
        ('add', {'p': 'p0', 'v': 2}),
        ('tag', {'target': 'e0003', 'm': {'m2': 1}}),
      ]),
    ]);
    expect(stats['ann']!.played, 1);
    expect(stats['ann']!.wins, 1);
    expect(stats['ann']!.points, 1);
    expect(stats['eli']!.played, 1);
    expect(stats['eli']!.points, 2);
    expect(stats['cy']!.wins, 0);
  });

  test('an individual side counts for everyone who played it', () {
    final stats = computeStats([
      _saved(const [Participant(id: 'p0', name: 'Ann'), Participant(id: 'p1', name: 'Bob')], [
        ('add', {'p': 'p0', 'v': 1}),
        ('sub', {'p': 'p0', 'n': 'Eli'}),
        ('add', {'p': 'p0', 'v': 2}),
      ]),
    ]);
    expect(stats.keys, containsAll(['ann', 'eli', 'bob']));
    expect(stats['eli']!.wins, 1);
  });

  test('a side that joined counts, and points follow a fixed spelling', () {
    final stats = computeStats([
      _saved(const [
        Participant(id: 'p0', name: 'Reds', members: ['Bbo']),
        Participant(id: 'p1', name: 'Blues', members: ['Cy']),
      ], [
        ('addSide', {'n': 'Greens', 'c': 2, 'm0': 'Gus'}),
        ('add', {'p': 'p0', 'v': 3}),
        ('tag', {'target': 'e0001', 'm': {'m0': 1}}),
        ('rename', {'f': 'Bbo', 'n': 'Bob'}),
      ]),
    ]);
    expect(stats.containsKey('bbo'), isFalse);
    expect(stats['bob']!.points, 3);
    expect(stats['gus']!.played, 1);
  });
}
