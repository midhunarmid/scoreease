import 'dart:async';
import 'dart:io';

import 'package:hive_ce/hive_ce.dart';
import 'package:scoreease/data/local/local_store.dart';
import 'package:scoreease/engine/engine.dart';
import 'package:scoreease/engine/meet.dart';

/// Keeps games and events in memory: Hive's disk writes never finish on a
/// widget test's fake clock. Change streams fire on every save.
class MemoryStore extends LocalStore {
  final _games = <String, Game>{};
  final _events = <String, List<ScoreEvent>>{};
  final _meets = <String, Meet>{};
  final _changes = StreamController<void>.broadcast();

  MemoryStore._(super.games, super.events, super.players, super.settings) : super.withBoxes();

  /// Opens the Hive boxes a [LocalStore] needs (settings still live there).
  static Future<MemoryStore> open(Directory dir) async {
    Hive.init(dir.path);
    return MemoryStore._(
      await Hive.openBox<String>('games'),
      await Hive.openBox<String>('events'),
      await Hive.openBox<String>('players'),
      await Hive.openBox('settings'),
    );
  }

  /// Tells listeners something changed, as a Hive box watch would.
  void changed() => _changes.add(null);

  @override
  Stream<void> get gameChanges => _changes.stream;
  @override
  Stream<void> get meetChanges => _changes.stream;
  @override
  List<Game> games() => _games.values.toList();
  @override
  Game? game(String id) => _games[id];
  @override
  List<ScoreEvent> events(String gameId) => _events[gameId] ?? [];
  @override
  Future<void> saveGame(Game game) async {
    _games[game.id] = game;
    changed();
  }

  @override
  Future<void> saveEvents(String gameId, List<ScoreEvent> events) async => _events[gameId] = events;
  @override
  List<Meet> meets() => _meets.values.toList();
  @override
  Meet? meet(String id) => _meets[id];
  @override
  Future<void> saveMeet(Meet meet) async {
    _meets[meet.id] = meet;
    changed();
  }

  @override
  Future<void> rememberPlayers(Iterable<Participant> participants) async {}
}
