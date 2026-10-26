import 'dart:math';

/// The ways a game can be scored. Each has its own engine.
enum GameMode { counter, rounds, sets, cricket, placements }

enum GameStatus { active, finished }

/// A player or a team taking part in a game.
class Participant {
  final String id;
  final String name;
  final int color;

  /// Player names when this participant is a team. Empty for individuals.
  final List<String> members;

  /// In an event, the event team an individual player scores for.
  final String? teamId;

  const Participant({required this.id, required this.name, this.color = 0, this.members = const [], this.teamId});

  bool get isTeam => members.isNotEmpty;

  Participant copyWith({String? name, int? color, List<String>? members}) => Participant(
        id: id,
        name: name ?? this.name,
        color: color ?? this.color,
        members: members ?? this.members,
        teamId: teamId,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'color': color,
        if (members.isNotEmpty) 'members': {for (var i = 0; i < members.length; i++) 'm$i': members[i]},
        if (teamId != null) 'team': teamId,
      };

  factory Participant.fromJson(String id, Map json) {
    final raw = json['members'];
    final members = <String>[];
    if (raw is Map) {
      final keys = raw.keys.map((k) => k.toString()).toList()..sort(_naturalCompare);
      members.addAll(keys.map((k) => raw[k].toString()));
    } else if (raw is List) {
      members.addAll(raw.whereType<Object>().map((e) => e.toString()));
    }
    return Participant(
      id: id,
      name: (json['name'] ?? '').toString(),
      color: (json['color'] as num?)?.toInt() ?? 0,
      members: members,
      teamId: json['team']?.toString(),
    );
  }
}

int _naturalCompare(String a, String b) {
  final na = int.tryParse(a.replaceAll(RegExp(r'\D'), ''));
  final nb = int.tryParse(b.replaceAll(RegExp(r'\D'), ''));
  if (na != null && nb != null && na != nb) return na.compareTo(nb);
  return a.compareTo(b);
}

/// One thing that happened in a game: a point, a round, an undo... The game's
/// state is always rebuilt by replaying these in order, which gives undo,
/// history and live sync for free.
class ScoreEvent {
  /// Sortable id (same format as Firebase push ids), so events from several
  /// devices merge in time order.
  final String id;
  final String type;
  final Map<String, dynamic> data;
  final int ts;

  /// Who made it: a Firebase uid for live games, `local` otherwise.
  final String by;

  const ScoreEvent({required this.id, required this.type, this.data = const {}, required this.ts, this.by = 'local'});

  Map<String, dynamic> toJson() => {'t': type, if (data.isNotEmpty) 'd': data, 'ts': ts, 'by': by};

  factory ScoreEvent.fromJson(String id, Map json) => ScoreEvent(
        id: id,
        type: (json['t'] ?? '').toString(),
        data: _deepCast(json['d']),
        ts: (json['ts'] as num?)?.toInt() ?? 0,
        by: (json['by'] ?? 'local').toString(),
      );

  T? get<T>(String key) {
    final v = data[key];
    return v is T ? v : null;
  }

  int intOf(String key, [int fallback = 0]) => (data[key] as num?)?.toInt() ?? fallback;
}

Map<String, dynamic> _deepCast(Object? raw) {
  if (raw is! Map) return {};
  return raw.map((k, v) => MapEntry(k.toString(), v is Map ? _deepCast(v) : v));
}

/// A game as stored on the device. Scores are not stored here, they are
/// derived from the game's events.
class Game {
  final String id;
  final String title;
  final String templateId;
  final GameMode mode;
  final Map<String, dynamic> settings;
  final List<Participant> participants;
  final DateTime createdAt;
  final DateTime updatedAt;
  final GameStatus status;

  /// Winner participant ids, filled in when the game finishes.
  final List<String> winners;

  /// Short summary line for lists, e.g. "Ann 21 · Bob 18".
  final String summary;

  /// Set when the game is shared live.
  final String? shareCode;

  /// False for a live game someone else owns that this device joined.
  final bool isOwner;

  /// Points each team member was credited with, by member name. Kept on the
  /// device for player stats; derived from the events.
  final Map<String, int> memberPoints;

  /// The event (a [Meet]) this game counts towards, if any. Device only.
  final String? eventId;

  const Game({
    required this.id,
    required this.title,
    required this.templateId,
    required this.mode,
    this.settings = const {},
    required this.participants,
    required this.createdAt,
    required this.updatedAt,
    this.status = GameStatus.active,
    this.winners = const [],
    this.summary = '',
    this.shareCode,
    this.isOwner = true,
    this.memberPoints = const {},
    this.eventId,
  });

  bool get isFinished => status == GameStatus.finished;

  Participant? participant(String id) {
    for (final p in participants) {
      if (p.id == id) return p;
    }
    return null;
  }

  String nameOf(String id) => participant(id)?.name ?? '?';

  bool flag(String key, [bool fallback = false]) => settings[key] is bool ? settings[key] as bool : fallback;
  int? intSetting(String key) => (settings[key] as num?)?.toInt();
  String? stringSetting(String key) => settings[key]?.toString();

  Game copyWith({
    String? title,
    Map<String, dynamic>? settings,
    List<Participant>? participants,
    DateTime? updatedAt,
    GameStatus? status,
    List<String>? winners,
    String? summary,
    String? shareCode,
    bool clearShareCode = false,
    bool? isOwner,
    Map<String, int>? memberPoints,
  }) =>
      Game(
        id: id,
        title: title ?? this.title,
        templateId: templateId,
        mode: mode,
        settings: settings ?? this.settings,
        participants: participants ?? this.participants,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        status: status ?? this.status,
        winners: winners ?? this.winners,
        summary: summary ?? this.summary,
        shareCode: clearShareCode ? null : (shareCode ?? this.shareCode),
        isOwner: isOwner ?? this.isOwner,
        memberPoints: memberPoints ?? this.memberPoints,
        eventId: eventId,
      );

  /// The part of a game that is shared live (no device-only fields).
  Map<String, dynamic> toMetaJson() => {
        'title': title,
        'template': templateId,
        'mode': mode.name,
        'settings': settings,
        'participants': {for (final p in participants) p.id: p.toJson()},
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        ...toMetaJson(),
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'status': status.name,
        'winners': winners,
        'summary': summary,
        if (shareCode != null) 'shareCode': shareCode,
        'isOwner': isOwner,
        if (memberPoints.isNotEmpty) 'memberPoints': memberPoints,
        if (eventId != null) 'eventId': eventId,
      };

  factory Game.fromJson(Map json, {String? id}) {
    final rawParticipants = json['participants'];
    final participants = <Participant>[];
    if (rawParticipants is Map) {
      final keys = rawParticipants.keys.map((k) => k.toString()).toList()..sort(_naturalCompare);
      for (final k in keys) {
        participants.add(Participant.fromJson(k, rawParticipants[k] as Map));
      }
    }
    final created = (json['createdAt'] as num?)?.toInt() ?? 0;
    return Game(
      id: id ?? json['id'].toString(),
      title: (json['title'] ?? '').toString(),
      templateId: (json['template'] ?? 'counter').toString(),
      mode: GameMode.values.firstWhere((m) => m.name == json['mode'], orElse: () => GameMode.counter),
      settings: _deepCast(json['settings']),
      participants: participants,
      createdAt: DateTime.fromMillisecondsSinceEpoch(created),
      updatedAt: DateTime.fromMillisecondsSinceEpoch((json['updatedAt'] as num?)?.toInt() ?? created),
      status: json['status'] == 'finished' ? GameStatus.finished : GameStatus.active,
      winners: (json['winners'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      summary: (json['summary'] ?? '').toString(),
      shareCode: json['shareCode']?.toString(),
      isOwner: json['isOwner'] != false,
      memberPoints: {
        if (json['memberPoints'] case final Map raw)
          for (final MapEntry(:key, :value) in raw.entries)
            if (value is num) key.toString(): value.toInt(),
      },
      eventId: json['eventId']?.toString(),
    );
  }
}

/// Generates ids in the same format as Firebase push ids: 8 chars of
/// timestamp then 12 random chars, so they sort by creation time.
class PushId {
  static const _chars = '-0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz';
  static final _random = Random();
  static int _lastTime = 0;
  static final List<int> _lastRandom = List.filled(12, 0);

  static String next([int? now]) {
    var time = now ?? DateTime.now().millisecondsSinceEpoch;
    final duplicate = time == _lastTime;
    _lastTime = time;
    final timeChars = List.filled(8, '');
    for (var i = 7; i >= 0; i--) {
      timeChars[i] = _chars[time % 64];
      time = time ~/ 64;
    }
    if (!duplicate) {
      for (var i = 0; i < 12; i++) {
        _lastRandom[i] = _random.nextInt(64);
      }
    } else {
      var i = 11;
      while (i >= 0 && _lastRandom[i] == 63) {
        _lastRandom[i] = 0;
        i--;
      }
      if (i >= 0) _lastRandom[i]++;
    }
    return timeChars.join() + _lastRandom.map((r) => _chars[r]).join();
  }
}
