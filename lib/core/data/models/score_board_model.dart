import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import 'access_model.dart';

@immutable
class ScoreBoardModel {
  final String? id;
  final String? title;
  final String? description;
  final String? createdAt;
  final int? playerCount;
  final AccessModel? access;

  const ScoreBoardModel({
    this.id,
    this.title,
    this.description,
    this.createdAt,
    this.playerCount,
    this.access,
  });

  @override
  String toString() {
    return 'ScoreBoard(id: $id, title: $title, description: $description, createdAt: $createdAt, playerCount: $playerCount, access: $access)';
  }

  factory ScoreBoardModel.fromMap(Map<String, dynamic> data) => ScoreBoardModel(
        id: data['id'] as String?,
        title: data['title'] as String?,
        description: data['description'] as String?,
        createdAt: data['createdAt'] as String?,
        playerCount: data['playerCount'] as int?,
        access: data['access'] == null
            ? null
            : AccessModel.fromMap(data['access'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'createdAt': createdAt,
        'playerCount': playerCount,
        'access': access?.toMap(),
      };

  /// `dart:convert`
  ///
  /// Parses the string and returns the resulting Json object as [ScoreBoardModel].
  factory ScoreBoardModel.fromJson(String data) {
    return ScoreBoardModel.fromMap(json.decode(data) as Map<String, dynamic>);
  }

  /// `dart:convert`
  ///
  /// Converts [ScoreBoardModel] to a JSON string.
  String toJson() => json.encode(toMap());

  ScoreBoardModel copyWith({
    String? id,
    String? title,
    String? description,
    String? createdAt,
    int? playerCount,
    AccessModel? access,
  }) {
    return ScoreBoardModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      playerCount: playerCount ?? this.playerCount,
      access: access ?? this.access,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    if (other is! ScoreBoardModel) return false;
    final mapEquals = const DeepCollectionEquality().equals;
    return mapEquals(other.toMap(), toMap());
  }

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      description.hashCode ^
      createdAt.hashCode ^
      playerCount.hashCode ^
      access.hashCode;
}
