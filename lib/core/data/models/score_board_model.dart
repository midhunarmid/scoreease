import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import 'access_model.dart';

@immutable
class ScoreBoardModel {
  final String? id;
  final String? title;
  final String? description;
  final String? author;
  final int? createdAt;
  final int? lastUpdated;
  final Access? access;
  final Map<String, int>? players;

  const ScoreBoardModel({
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
    return 'ScoreBoardModel(id: $id, title: $title, description: $description, author: $author, createdAt: $createdAt, lastUpdated: $lastUpdated, access: $access, players: $players)';
  }

  factory ScoreBoardModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data() ?? {};
    return ScoreBoardModel.fromMap(data);
  }

  factory ScoreBoardModel.fromMap(Map<String, dynamic> data) {
    return ScoreBoardModel(
      id: data['id'] as String?,
      title: data['title'] as String?,
      description: data['description'] as String?,
      author: data['author'] as String?,
      createdAt: data['createdAt'] as int?,
      lastUpdated: data['lastUpdated'] as int?,
      access: data['access'] == null
          ? null
          : Access.fromMap(data['access'] as Map<String, dynamic>),
      players: data['players'] == null
          ? null
          : Map<String, int>.from(data['players'] as Map<dynamic, dynamic>),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'author': author,
        'createdAt': createdAt,
        'lastUpdated': lastUpdated,
        'access': access?.toMap(),
        'players': players,
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
    String? author,
    int? createdAt,
    int? lastUpdated,
    Access? access,
    Map<String, int>? players,
  }) {
    return ScoreBoardModel(
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
    if (other is! ScoreBoardModel) return false;
    final mapEquals = const DeepCollectionEquality().equals;
    return mapEquals(other.toMap(), toMap());
  }

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      description.hashCode ^
      author.hashCode ^
      createdAt.hashCode ^
      lastUpdated.hashCode ^
      access.hashCode ^
      players.hashCode;
}
