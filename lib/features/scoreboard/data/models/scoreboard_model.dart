import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:scoreease/features/scoreboard/data/models/access_model.dart';
import 'package:scoreease/features/scoreboard/data/models/team_model.dart';

@immutable
class ScoreboardModel {
  final String? id;
  final String? title;
  final String? description;
  final String? author;
  final String? ownerId;
  final int? createdAt;
  final int? lastUpdated;
  final AccessModel? access;
  final Map<String, int>? players;
  final bool? isTeamGame;
  final Map<String, TeamModel>? teams;

  const ScoreboardModel({
    this.id,
    this.title,
    this.description,
    this.author,
    this.ownerId,
    this.createdAt,
    this.lastUpdated,
    this.access,
    this.players,
    this.isTeamGame,
    this.teams,
  });

  @override
  String toString() {
    return 'ScoreboardModel(id: $id, title: $title, description: $description, author: $author, ownerId: $ownerId, createdAt: $createdAt, lastUpdated: $lastUpdated, access: $access, players: $players, isTeamGame: $isTeamGame, teams: $teams)';
  }

  factory ScoreboardModel.fromMap(Map<String, dynamic> data) {
    return ScoreboardModel(
      id: data['id'] as String?,
      title: data['title'] as String?,
      description: data['description'] as String?,
      author: data['author'] as String?,
      ownerId: data['ownerId'] as String?,
      createdAt: data['createdAt'] as int?,
      lastUpdated: data['lastUpdated'] as int?,
      access: data['access'] == null ? null : AccessModel.fromMap(Map<String, dynamic>.from(data['access'] as Map)),
      players: data['players'] == null ? null : Map<String, int>.from(data['players'] as Map<dynamic, dynamic>),
      isTeamGame: data['isTeamGame'] as bool?,
      teams: data['teams'] == null
          ? null
          : (data['teams'] as Map).map(
              (key, value) => MapEntry(key.toString(), TeamModel.fromMap(Map<String, dynamic>.from(value as Map))),
            ),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'author': author,
        'ownerId': ownerId,
        'createdAt': createdAt,
        'lastUpdated': ServerValue.timestamp,
        'access': access?.toMap(),
        'players': players,
        'isTeamGame': isTeamGame,
        'teams': teams?.map((k, v) => MapEntry(k, v.toMap())),
      };

  /// `dart:convert`
  ///
  /// Parses the string and returns the resulting Json object as [ScoreboardModel].
  factory ScoreboardModel.fromJson(String data) {
    return ScoreboardModel.fromMap(json.decode(data) as Map<String, dynamic>);
  }

  /// `dart:convert`
  ///
  /// Converts [ScoreboardModel] to a JSON string.
  String toJson() => json.encode(toMap());

  ScoreboardModel copyWith({
    String? id,
    String? title,
    String? description,
    String? author,
    String? ownerId,
    int? createdAt,
    int? lastUpdated,
    AccessModel? access,
    Map<String, int>? players,
    bool? isTeamGame,
    Map<String, TeamModel>? teams,
  }) {
    return ScoreboardModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      author: author ?? this.author,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      access: access ?? this.access,
      players: players ?? this.players,
      isTeamGame: isTeamGame ?? this.isTeamGame,
      teams: teams ?? this.teams,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    if (other is! ScoreboardModel) return false;
    final mapEquals = const DeepCollectionEquality().equals;
    return mapEquals(other.toMap(), toMap());
  }

  @override
  int get hashCode => id.hashCode;
}
