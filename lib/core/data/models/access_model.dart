import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

@immutable
class AccessModel {
  final String? readPassword;
  final String? writePassword;

  const AccessModel({this.readPassword, this.writePassword});

  @override
  String toString() {
    return 'Access(readPassword: $readPassword, writePassword: $writePassword)';
  }

  factory AccessModel.fromMap(Map<String, dynamic> data) => AccessModel(
        readPassword: data['readPassword'] as String?,
        writePassword: data['writePassword'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'readPassword': readPassword,
        'writePassword': writePassword,
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
    String? readPassword,
    String? writePassword,
  }) {
    return AccessModel(
      readPassword: readPassword ?? this.readPassword,
      writePassword: writePassword ?? this.writePassword,
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
  int get hashCode => readPassword.hashCode ^ writePassword.hashCode;
}
