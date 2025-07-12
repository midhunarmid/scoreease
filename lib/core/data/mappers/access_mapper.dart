import 'package:scoreease/core/data/models/access_model.dart';
import 'package:scoreease/core/domain/entities/access_entity.dart';

class AccessMapper {
  static AccessEntity toEntity(AccessModel model) {
    return AccessEntity(
      read: model.read,
      write: model.write,
    );
  }

  static AccessModel fromEntity(AccessEntity entity) {
    return AccessModel(
      read: entity.read,
      write: entity.write,
    );
  }
}
