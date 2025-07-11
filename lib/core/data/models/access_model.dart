import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

@immutable
class Access {
  final String? read;
  final String? write;

  const Access({this.read, this.write});

  @override
  String toString() => 'Access(read: $read, write: $write)';

  factory Access.fromMap(Map<String, dynamic> data) => Access(
        read: data['read'] as String?,
        write: data['write'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'read': read,
        'write': write,
      };

  /// `dart:convert`
  ///
  /// Parses the string and returns the resulting Json object as [Access].
  factory Access.fromJson(String data) {
    return Access.fromMap(json.decode(data) as Map<String, dynamic>);
  }

  /// `dart:convert`
  ///
  /// Converts [Access] to a JSON string.
  String toJson() => json.encode(toMap());

  Access copyWith({
    String? read,
    String? write,
  }) {
    return Access(
      read: read ?? this.read,
      write: write ?? this.write,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    if (other is! Access) return false;
    final mapEquals = const DeepCollectionEquality().equals;
    return mapEquals(other.toMap(), toMap());
  }

  @override
  int get hashCode => read.hashCode ^ write.hashCode;
}
