import 'package:flutter/foundation.dart';

@immutable
class AccessEntity {
  final String? read;
  final String? write;

  const AccessEntity({this.read, this.write});

  @override
  String toString() => 'Access(read: $read, write: $write)';

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    if (other is! AccessEntity) return false;
    
    return other.read == read && other.write == write; 
  }

  @override
  int get hashCode => read.hashCode ^ write.hashCode;
}
