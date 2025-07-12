import 'package:flutter/foundation.dart';

import 'access_entity.dart';

@immutable
class ScoreboardEntity {
  final String? id;
  final String? title;
  final String? description;
  final String? author;
  final int? createdAt;
  final int? lastUpdated;
  final AccessEntity? access;
  final Map<String, int>? players;

  const ScoreboardEntity({
    this.id,
    this.title,
    this.description,
    this.author,
    this.createdAt,
    this.lastUpdated,
    this.access,
    this.players,
  });

  @override
  String toString() {
    return 'ScoreboardEntity(id: $id, title: $title, description: $description, author: $author, createdAt: $createdAt, lastUpdated: $lastUpdated, access: $access, players: $players)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    if (other is! ScoreboardEntity) return false;

    return other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
