import 'package:flutter/foundation.dart';

@immutable
class AccessEntity {
  final String? read;
  final String? write;
  final String? owner;

  const AccessEntity({this.read, this.write, this.owner});

  @override
  String toString() => 'Access(read: $read, write: $write, owner: $owner)';

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    if (other is! AccessEntity) return false;
    
    return other.read == read && other.write == write && other.owner == owner; 
  }

  @override
  int get hashCode => read.hashCode ^ write.hashCode ^ owner.hashCode;
}
