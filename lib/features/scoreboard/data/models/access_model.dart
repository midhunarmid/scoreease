import 'package:flutter/foundation.dart';

/// Public access flags, stored at `boardMeta/{id}` and readable by everyone.
@immutable
class AccessMetaModel {
  final String? ownerId;
  final bool readProtected;
  final bool writeProtected;
  final bool ownerProtected;

  const AccessMetaModel({
    this.ownerId,
    this.readProtected = false,
    this.writeProtected = false,
    this.ownerProtected = false,
  });

  factory AccessMetaModel.fromMap(Map<String, dynamic> data) => AccessMetaModel(
        ownerId: data['ownerId'] as String?,
        readProtected: data['readProtected'] as bool? ?? false,
        writeProtected: data['writeProtected'] as bool? ?? false,
        ownerProtected: data['ownerProtected'] as bool? ?? false,
      );

  Map<String, dynamic> toMap() => {
        'ownerId': ownerId ?? '',
        'readProtected': readProtected,
        'writeProtected': writeProtected,
        'ownerProtected': ownerProtected,
      };

  @override
  String toString() =>
      'AccessMetaModel(ownerId: $ownerId, readProtected: $readProtected, writeProtected: $writeProtected, ownerProtected: $ownerProtected)';

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    if (other is! AccessMetaModel) return false;
    return other.ownerId == ownerId &&
        other.readProtected == readProtected &&
        other.writeProtected == writeProtected &&
        other.ownerProtected == ownerProtected;
  }

  @override
  int get hashCode => Object.hash(ownerId, readProtected, writeProtected, ownerProtected);
}

/// Password hashes to write to `secrets/{id}`. That node is never readable by
/// clients; `null` keeps the stored value and `""` removes it.
@immutable
class AccessModel {
  final String? read;
  final String? write;
  final String? owner;

  const AccessModel({this.read, this.write, this.owner});

  @override
  String toString() => 'AccessModel(read: ${_mask(read)}, write: ${_mask(write)}, owner: ${_mask(owner)})';

  static String? _mask(String? value) => value == null ? null : (value.isEmpty ? '""' : '***');

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    if (other is! AccessModel) return false;
    return other.read == read && other.write == write && other.owner == owner;
  }

  @override
  int get hashCode => Object.hash(read, write, owner);
}
