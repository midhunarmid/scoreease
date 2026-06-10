import 'package:flutter/foundation.dart';

@immutable
class TeamEntity {
  final String name;
  final Map<String, bool> players;

  const TeamEntity({
    required this.name,
    required this.players,
  });

  TeamEntity copyWith({
    String? name,
    Map<String, bool>? players,
  }) {
    return TeamEntity(
      name: name ?? this.name,
      players: players ?? this.players,
    );
  }

  @override
  String toString() => 'TeamEntity(name: $name, players: $players)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TeamEntity && other.name == name;
  }

  @override
  int get hashCode => name.hashCode;
}
