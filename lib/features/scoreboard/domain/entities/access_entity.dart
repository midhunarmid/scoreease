import 'package:flutter/foundation.dart';

/// The three password levels a scoreboard can be protected with.
/// `name` doubles as the database key under `secrets/` and `grants/`.
enum AccessLevel { read, write, owner }

@immutable
class AccessEntity {
  /// Password hashes to store. Only set when creating a scoreboard or changing
  /// its passwords: `null` keeps the current value, `""` removes the password.
  /// Hashes are never read back from the server.
  final String? read;
  final String? write;
  final String? owner;

  /// Public flags telling whether each level is password protected.
  final bool readProtected;
  final bool writeProtected;
  final bool ownerProtected;

  const AccessEntity({
    this.read,
    this.write,
    this.owner,
    this.readProtected = false,
    this.writeProtected = false,
    this.ownerProtected = false,
  });

  bool isProtected(AccessLevel level) {
    switch (level) {
      case AccessLevel.read:
        return readProtected;
      case AccessLevel.write:
        return writeProtected;
      case AccessLevel.owner:
        return ownerProtected;
    }
  }

  @override
  String toString() =>
      'Access(readProtected: $readProtected, writeProtected: $writeProtected, ownerProtected: $ownerProtected)';

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    if (other is! AccessEntity) return false;

    return other.read == read &&
        other.write == write &&
        other.owner == owner &&
        other.readProtected == readProtected &&
        other.writeProtected == writeProtected &&
        other.ownerProtected == ownerProtected;
  }

  @override
  int get hashCode => Object.hash(read, write, owner, readProtected, writeProtected, ownerProtected);
}
