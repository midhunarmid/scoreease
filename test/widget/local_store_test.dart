import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:scoreease/data/local/local_store.dart';
import 'package:scoreease/engine/engine.dart';
import 'package:scoreease/engine/meet.dart';

void main() {
  late Directory dir;
  late LocalStore store;

  Future<LocalStore> open(String prefix) async => LocalStore.withBoxes(
        await Hive.openBox<String>('${prefix}games'),
        await Hive.openBox<String>('${prefix}events'),
        await Hive.openBox<String>('${prefix}players'),
        await Hive.openBox('${prefix}settings'),
        meets: await Hive.openBox<String>('${prefix}meets'),
      );

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('scoreease_store');
    Hive.init(dir.path);
    store = await open('');
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  final now = DateTime(2026, 10, 26);
  Meet meet(String id, {int day = 26}) => Meet(
        id: id,
        name: 'Day $id',
        teams: const [MeetTeam(id: 't0', name: 'Reds', members: ['Ann']), MeetTeam(id: 't1', name: 'Blues', members: ['Bob'])],
        createdAt: now,
        updatedAt: DateTime(2026, 10, day),
      );
  Game game(String id, {String? eventId}) => Game(
        id: id,
        title: id,
        templateId: 'race',
        mode: GameMode.placements,
        participants: const [Participant(id: 'p0', name: 'Ann', teamId: 't0'), Participant(id: 'p1', name: 'Bob', teamId: 't1')],
        createdAt: now,
        updatedAt: now,
        eventId: eventId,
      );

  test('events are saved, listed newest first, and know their games', () async {
    await store.saveMeet(meet('a', day: 1));
    await store.saveMeet(meet('b', day: 2));
    await store.saveGame(game('g1', eventId: 'a'));
    await store.saveGame(game('g2', eventId: 'a'));
    await store.saveGame(game('solo'));

    expect(store.meets().map((m) => m.id), ['b', 'a']);
    expect(store.meet('a')!.teams.map((t) => t.name), ['Reds', 'Blues']);
    expect(store.meet('missing'), isNull);
    expect(store.gamesInMeet('a').map((g) => g.id), unorderedEquals(['g1', 'g2']));
    expect(store.game('g1')!.participants.first.teamId, 't0', reason: 'teams survive storage');
  });

  test('deleting an event deletes its games and their scores, nothing else', () async {
    await store.saveMeet(meet('a'));
    await store.saveGame(game('g1', eventId: 'a'));
    await store.saveEvents('g1', const [ScoreEvent(id: 'e1', type: 'place', data: {'p': 'p0'}, ts: 1)]);
    await store.saveGame(game('solo'));

    await store.deleteMeet('a');
    expect(store.meet('a'), isNull);
    expect(store.game('g1'), isNull);
    expect(store.events('g1'), isEmpty);
    expect(store.game('solo'), isNotNull);
  });

  test('a backup carries events and their games to another device', () async {
    await store.saveMeet(meet('a'));
    await store.saveGame(game('g1', eventId: 'a'));
    await store.saveEvents('g1', const [ScoreEvent(id: 'e1', type: 'place', data: {'p': 'p0'}, ts: 1)]);
    final backup = jsonDecode(jsonEncode(store.exportAll())) as Map;

    final other = await open('other_');
    expect(await other.importAll(backup), 1);
    expect(other.meet('a')!.name, 'Day a');
    expect(other.gamesInMeet('a').single.id, 'g1');
    expect(other.events('g1').single.type, 'place');
  });

  test('a corrupt event is skipped instead of breaking the list', () async {
    await store.saveMeet(meet('a'));
    await Hive.box<String>('meets').put('bad', '{not json');
    expect(store.meets().map((m) => m.id), ['a']);
  });

  test('a store without an events box (older tests, first run) has no events', () async {
    final bare = LocalStore.withBoxes(
      await Hive.openBox<String>('bare_games'),
      await Hive.openBox<String>('bare_events'),
      await Hive.openBox<String>('bare_players'),
      await Hive.openBox('bare_settings'),
    );
    expect(bare.meets(), isEmpty);
    expect(bare.meet('a'), isNull);
    await bare.saveMeet(meet('a'));
    expect(await bare.meetChanges.isEmpty, isTrue);
  });
}
