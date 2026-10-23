import 'dart:async';
import 'dart:convert';

import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../../engine/engine.dart';

/// Everything kept on the device. Values are stored as JSON strings so no
/// Hive type adapters or code generation are needed.
class LocalStore {
  late final Box<String> _games;
  late final Box<String> _events;
  late final Box<String> _players;
  late final Box _settings;

  Box get settingsBox => _settings;

  Future<void> init() async {
    await Hive.initFlutter('scoreease');
    _games = await Hive.openBox<String>('games');
    _events = await Hive.openBox<String>('events');
    _players = await Hive.openBox<String>('players');
    _settings = await Hive.openBox('settings');
  }

  /// For tests: use already-open boxes.
  LocalStore.withBoxes(Box<String> games, Box<String> events, Box<String> players, Box settings) {
    _games = games;
    _events = events;
    _players = players;
    _settings = settings;
  }

  LocalStore();

  // ---- Games ----

  Stream<void> get gameChanges => _games.watch().map((_) {});

  List<Game> games() {
    final list = <Game>[];
    for (final raw in _games.values) {
      try {
        list.add(Game.fromJson(jsonDecode(raw) as Map));
      } catch (_) {
        // Skip a corrupt entry rather than breaking the whole list.
      }
    }
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  Game? game(String id) {
    final raw = _games.get(id);
    return raw == null ? null : Game.fromJson(jsonDecode(raw) as Map);
  }

  Game? gameByShareCode(String code) {
    for (final g in games()) {
      if (g.shareCode == code) return g;
    }
    return null;
  }

  Future<void> saveGame(Game game) => _games.put(game.id, jsonEncode(game.toJson()));

  Future<void> deleteGame(String id) async {
    await _games.delete(id);
    await _events.delete(id);
  }

  // ---- Events ----

  List<ScoreEvent> events(String gameId) {
    final raw = _events.get(gameId);
    if (raw == null) return [];
    final map = jsonDecode(raw) as Map;
    final list = map.entries.map((e) => ScoreEvent.fromJson(e.key.toString(), e.value as Map)).toList();
    list.sort((a, b) => a.id.compareTo(b.id));
    return list;
  }

  Future<void> saveEvents(String gameId, List<ScoreEvent> events) =>
      _events.put(gameId, jsonEncode({for (final e in events) e.id: e.toJson()}));

  // ---- Players ----

  Stream<void> get playerChanges => _players.watch().map((_) {});

  List<SavedPlayer> players() {
    final list = _players.toMap().entries.map((e) => SavedPlayer.fromJson(e.key.toString(), jsonDecode(e.value) as Map)).toList();
    list.sort((a, b) => b.lastUsed.compareTo(a.lastUsed));
    return list;
  }

  Future<void> savePlayer(SavedPlayer p) => _players.put(p.id, jsonEncode(p.toJson()));
  Future<void> deletePlayer(String id) => _players.delete(id);

  /// Remembers the names used in a game so they can be picked next time.
  Future<void> rememberPlayers(Iterable<Participant> participants) async {
    final existing = {for (final p in players()) p.name.toLowerCase(): p};
    final now = DateTime.now().millisecondsSinceEpoch;
    final names = <String, int>{};
    for (final p in participants) {
      if (p.members.isEmpty) {
        names[p.name] = p.color;
      } else {
        for (final m in p.members) {
          names[m] = existing[m.toLowerCase()]?.color ?? names.length;
        }
      }
    }
    final placeholder = RegExp(r'^(player|team|side) ([0-9]+|[a-z])$', caseSensitive: false);
    for (final entry in names.entries) {
      final name = entry.key.trim();
      if (name.isEmpty || placeholder.hasMatch(name)) continue;
      final found = existing[name.toLowerCase()];
      await savePlayer(found == null
          ? SavedPlayer(id: PushId.next(), name: name, color: entry.value, lastUsed: now)
          : found.copyWith(lastUsed: now));
    }
  }

  // ---- Backup ----

  Map<String, dynamic> exportAll() => {
        'app': 'scoreease',
        'version': 2,
        'exportedAt': DateTime.now().toIso8601String(),
        'games': [
          for (final g in games()) {'game': g.toJson(), 'events': {for (final e in events(g.id)) e.id: e.toJson()}},
        ],
        'players': [for (final p in players()) {'id': p.id, ...p.toJson()}],
      };

  /// Merges a backup made by [exportAll]. Returns how many games were added
  /// or updated.
  Future<int> importAll(Map json) async {
    if (json['app'] != 'scoreease') throw const FormatException('Not a ScoreEase backup');
    var count = 0;
    for (final item in (json['games'] as List? ?? const [])) {
      final game = Game.fromJson(item['game'] as Map);
      final events = (item['events'] as Map? ?? const {})
          .entries
          .map((e) => ScoreEvent.fromJson(e.key.toString(), e.value as Map))
          .toList();
      await saveGame(game);
      await saveEvents(game.id, events);
      count++;
    }
    for (final item in (json['players'] as List? ?? const [])) {
      final map = item as Map;
      await savePlayer(SavedPlayer.fromJson(map['id'].toString(), map));
    }
    return count;
  }
}

/// A player remembered on this device.
class SavedPlayer {
  final String id;
  final String name;
  final int color;
  final int lastUsed;

  const SavedPlayer({required this.id, required this.name, required this.color, required this.lastUsed});

  SavedPlayer copyWith({String? name, int? color, int? lastUsed}) =>
      SavedPlayer(id: id, name: name ?? this.name, color: color ?? this.color, lastUsed: lastUsed ?? this.lastUsed);

  Map<String, dynamic> toJson() => {'name': name, 'color': color, 'lastUsed': lastUsed};

  factory SavedPlayer.fromJson(String id, Map json) => SavedPlayer(
        id: id,
        name: (json['name'] ?? '').toString(),
        color: (json['color'] as num?)?.toInt() ?? 0,
        lastUsed: (json['lastUsed'] as num?)?.toInt() ?? 0,
      );
}
