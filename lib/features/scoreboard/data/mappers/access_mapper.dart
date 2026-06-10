import 'package:scoreease/features/scoreboard/data/models/access_model.dart';
import 'package:scoreease/features/scoreboard/domain/entities/access_entity.dart';

class AccessMapper {
  static AccessEntity toEntity(AccessModel model) {
    return AccessEntity(
      read: model.read,
      write: model.write,
      owner: model.owner,
    );
  }

  static AccessModel fromEntity(AccessEntity entity) {
    return AccessModel(
      read: entity.read,
      write: entity.write,
      owner: entity.owner,
    );
  }
}
