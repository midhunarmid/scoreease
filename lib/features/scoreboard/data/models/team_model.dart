import 'package:flutter/foundation.dart';
import 'package:collection/collection.dart';
import 'package:scoreease/features/scoreboard/domain/entities/team_entity.dart';

@immutable
class TeamModel {
  final String name;
  final Map<String, bool> players;

  const TeamModel({
    required this.name,
    required this.players,
  });

  factory TeamModel.fromMap(Map<String, dynamic> data) {
    return TeamModel(
      name: data['name'] as String? ?? '',
      players: data['players'] == null
          ? {}
          : Map<String, bool>.from(data['players'] as Map),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'players': players,
      };

  TeamModel copyWith({
    String? name,
    Map<String, bool>? players,
  }) {
    return TeamModel(
      name: name ?? this.name,
      players: players ?? this.players,
    );
  }

  TeamEntity toEntity() {
    return TeamEntity(name: name, players: players);
  }

  factory TeamModel.fromEntity(TeamEntity entity) {
    return TeamModel(name: entity.name, players: entity.players);
  }

  @override
  String toString() => 'TeamModel(name: $name, players: $players)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    final mapEquals = const DeepCollectionEquality().equals;
    return other is TeamModel &&
        other.name == name &&
        mapEquals(other.players, players);
  }

  @override
  int get hashCode => name.hashCode ^ const DeepCollectionEquality().hash(players);
}
