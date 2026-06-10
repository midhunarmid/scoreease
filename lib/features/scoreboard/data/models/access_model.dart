import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

@immutable
class AccessModel {
  final String? read;
  final String? write;
  final String? owner;

  const AccessModel({this.read, this.write, this.owner});

  @override
  String toString() => 'AccessModel(read: $read, write: $write, owner: $owner)';

  factory AccessModel.fromMap(Map<String, dynamic> data) => AccessModel(
        read: data['read'] as String?,
        write: data['write'] as String?,
        owner: data['owner'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'read': read,
        'write': write,
        'owner': owner,
      };

  /// `dart:convert`
  ///
  /// Parses the string and returns the resulting Json object as [AccessModel].
  factory AccessModel.fromJson(String data) {
    return AccessModel.fromMap(json.decode(data) as Map<String, dynamic>);
  }

  /// `dart:convert`
  ///
  /// Converts [AccessModel] to a JSON string.
  String toJson() => json.encode(toMap());

  AccessModel copyWith({
    String? read,
    String? write,
    String? owner,
  }) {
    return AccessModel(
      read: read ?? this.read,
      write: write ?? this.write,
      owner: owner ?? this.owner,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    if (other is! AccessModel) return false;
    final mapEquals = const DeepCollectionEquality().equals;
    return mapEquals(other.toMap(), toMap());
  }

  @override
  int get hashCode => read.hashCode ^ write.hashCode ^ owner.hashCode;
}
