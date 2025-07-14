import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:scoreease/core/data/models/access_model.dart';

@immutable
class ScoreboardModel {
  final String? id;
  final String? title;
  final String? description;
  final String? author;
  final Timestamp? createdAt;
  final Timestamp? lastUpdated;
  final AccessModel? access;
  final Map<String, int>? players;

  const ScoreboardModel({
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
    return 'ScoreboardModel(id: $id, title: $title, description: $description, author: $author, createdAt: $createdAt, lastUpdated: $lastUpdated, access: $access, players: $players)';
  }

  factory ScoreboardModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data() ?? {};
    return ScoreboardModel.fromMap(data);
  }

  factory ScoreboardModel.fromMap(Map<String, dynamic> data) {
    return ScoreboardModel(
      id: data['id'] as String?,
      title: data['title'] as String?,
      description: data['description'] as String?,
      author: data['author'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
      lastUpdated: data['lastUpdated'] as Timestamp?,
      access: data['access'] == null ? null : AccessModel.fromMap(data['access'] as Map<String, dynamic>),
      players: data['players'] == null ? null : Map<String, int>.from(data['players'] as Map<dynamic, dynamic>),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'author': author,
        'createdAt': createdAt,
        'lastUpdated': FieldValue.serverTimestamp(),
        'access': access?.toMap(),
        'players': players,
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
    Timestamp? createdAt,
    Timestamp? lastUpdated,
    AccessModel? access,
    Map<String, int>? players,
  }) {
    return ScoreboardModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      author: author ?? this.author,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      access: access ?? this.access,
      players: players ?? this.players,
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
