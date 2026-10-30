import 'dart:math';

import 'models.dart';

/// One team in an event, with everyone on its roster.
class MeetTeam {
  final String id;
  final String name;
  final int color;
  final List<String> members;

  const MeetTeam({required this.id, required this.name, this.color = 0, this.members = const []});

  MeetTeam copyWith({String? name, int? color, List<String>? members}) =>
      MeetTeam(id: id, name: name ?? this.name, color: color ?? this.color, members: members ?? this.members);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'color': color, 'members': members};

  factory MeetTeam.fromJson(Map json) => MeetTeam(
        id: json['id'].toString(),
        name: (json['name'] ?? '').toString(),
        color: (json['color'] as num?)?.toInt() ?? 0,
        members: (json['members'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      );
}

/// An event: teams that play several games, with points for places in each
/// game adding up to an overall winner. Called a Meet in code so it isn't
/// confused with a [ScoreEvent]; the app calls it an event. Its scores are
/// never stored; they are worked out from its games.
class Meet {
  final String id;
  final String name;
  final List<MeetTeam> teams;

  /// Default points for 1st, 2nd, 3rd... in each game, e.g. "3,2,1".
  final String placePoints;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool finished;

  const Meet({
    required this.id,
    required this.name,
    required this.teams,
    this.placePoints = '3,2,1',
    required this.createdAt,
    required this.updatedAt,
    this.finished = false,
  });

  MeetTeam? team(String? id) {
    for (final t in teams) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// The team [person] is on (names match ignoring case).
  MeetTeam? teamOf(String person) {
    final key = person.toLowerCase();
    for (final t in teams) {
      if (t.members.any((m) => m.toLowerCase() == key)) return t;
    }
    return null;
  }

  List<MeetTeam> _editTeams(MeetTeam Function(MeetTeam) edit) => [for (final t in teams) edit(t)];

  static List<String> _replaced(List<String> members, String from, String to) => [
        for (final m in members) m.toLowerCase() == from.toLowerCase() ? to : m,
      ];

  /// With [from] corrected to [to], as a team name or a person.
  Meet renamed(String from, String to) => copyWith(
        teams: _editTeams((t) => t.copyWith(
              name: t.name.toLowerCase() == from.toLowerCase() ? to : t.name,
              members: _replaced(t.members, from, to),
            )),
      );

  /// With [person] on team [teamId].
  Meet withPerson(String person, String teamId) =>
      copyWith(teams: _editTeams((t) => t.id == teamId ? t.copyWith(members: [...t.members, person]) : t));

  /// With [person] off every team.
  Meet without(String person) => copyWith(
        teams: _editTeams((t) => t.copyWith(members: t.members.where((m) => m.toLowerCase() != person.toLowerCase()).toList())),
      );

  /// With [person] moved to team [teamId].
  Meet moved(String person, String teamId) => without(person).withPerson(teamOf(person)?.members.firstWhere((m) => m.toLowerCase() == person.toLowerCase()) ?? person, teamId);

  /// With [a] and [b] in each other's places.
  Meet swapped(String a, String b) {
    const hold = '\u0000';
    return renamed(a, hold).renamed(b, a).renamed(hold, b);
  }

  Meet copyWith({String? name, List<MeetTeam>? teams, String? placePoints, DateTime? updatedAt, bool? finished}) => Meet(
        id: id,
        name: name ?? this.name,
        teams: teams ?? this.teams,
        placePoints: placePoints ?? this.placePoints,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        finished: finished ?? this.finished,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'teams': [for (final t in teams) t.toJson()],
        'placePoints': placePoints,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        if (finished) 'finished': true,
      };

  factory Meet.fromJson(Map json) {
    final created = (json['createdAt'] as num?)?.toInt() ?? 0;
    return Meet(
      id: json['id'].toString(),
      name: (json['name'] ?? '').toString(),
      teams: [for (final t in (json['teams'] as List? ?? const [])) MeetTeam.fromJson(t as Map)],
      placePoints: (json['placePoints'] ?? '3,2,1').toString(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(created),
      updatedAt: DateTime.fromMillisecondsSinceEpoch((json['updatedAt'] as num?)?.toInt() ?? created),
      finished: json['finished'] == true,
    );
  }
}

/// Splits [people] into [teams] teams of near-equal size, in random order.
/// [random] is for tests.
List<List<String>> splitEvenly(List<String> people, int teams, {Random? random}) {
  final shuffled = [...people]..shuffle(random);
  return [
    for (var t = 0; t < teams; t++) [for (var i = t; i < shuffled.length; i += teams) shuffled[i]],
  ];
}
