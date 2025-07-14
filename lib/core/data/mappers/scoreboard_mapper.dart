import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:scoreease/core/data/mappers/access_mapper.dart';
import 'package:scoreease/core/data/models/scoreboard_model.dart';
import 'package:scoreease/core/domain/entities/scoreboard_entity.dart';

class ScoreboardMapper {
  static ScoreboardEntity toEntity(ScoreboardModel model) {
    return ScoreboardEntity(
      id: model.id,
      title: model.title,
      description: model.description,
      author: model.author,
      createdAt: model.createdAt?.toDate(),
      lastUpdated: model.lastUpdated?.toDate(),
      access: model.access == null ? null : AccessMapper.toEntity(model.access!),
      players: model.players,
    );
  }

  static ScoreboardModel fromEntity(ScoreboardEntity entity) {
    return ScoreboardModel(
      id: entity.id,
      title: entity.title,
      description: entity.description,
      author: entity.author,
      createdAt: entity.createdAt != null ? Timestamp.fromDate(entity.createdAt!) : null,
      lastUpdated: entity.lastUpdated != null ? Timestamp.fromDate(entity.lastUpdated!) : null,
      access: entity.access == null ? null : AccessMapper.fromEntity(entity.access!),
      players: entity.players,
    );
  }
}
