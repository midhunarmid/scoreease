import 'package:scoreease/features/scoreboard/data/models/access_model.dart';
import 'package:scoreease/features/scoreboard/domain/entities/access_entity.dart';

class AccessMapper {
  static AccessEntity toEntity(AccessMetaModel meta) {
    return AccessEntity(
      readProtected: meta.readProtected,
      writeProtected: meta.writeProtected,
      ownerProtected: meta.ownerProtected,
    );
  }

  static AccessModel secretsFromEntity(AccessEntity entity) {
    return AccessModel(
      read: entity.read,
      write: entity.write,
      owner: entity.owner,
    );
  }
}
