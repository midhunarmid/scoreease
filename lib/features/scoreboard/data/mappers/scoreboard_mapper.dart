import 'package:scoreease/features/scoreboard/data/mappers/access_mapper.dart';
import 'package:scoreease/features/scoreboard/data/models/scoreboard_model.dart';
import 'package:scoreease/features/scoreboard/data/models/team_model.dart';
import 'package:scoreease/features/scoreboard/domain/entities/scoreboard_entity.dart';

class ScoreboardMapper {
  static ScoreboardEntity toEntity(ScoreboardModel model) {
    return ScoreboardEntity(
      id: model.id,
      title: model.title,
      description: model.description,
      author: model.author,
      ownerId: model.ownerId,
      createdAt: model.createdAt != null ? DateTime.fromMillisecondsSinceEpoch(model.createdAt!) : null,
      lastUpdated: model.lastUpdated != null ? DateTime.fromMillisecondsSinceEpoch(model.lastUpdated!) : null,
      access: model.access == null ? null : AccessMapper.toEntity(model.access!),
      players: model.players,
      isTeamGame: model.isTeamGame,
      teams: model.teams?.map((k, v) => MapEntry(k, v.toEntity())),
    );
  }

  static ScoreboardModel fromEntity(ScoreboardEntity entity) {
    return ScoreboardModel(
      id: entity.id,
      title: entity.title,
      description: entity.description,
      author: entity.author,
      ownerId: entity.ownerId,
      createdAt: entity.createdAt?.millisecondsSinceEpoch,
      lastUpdated: entity.lastUpdated?.millisecondsSinceEpoch,
      access: entity.access == null ? null : AccessMapper.fromEntity(entity.access!),
      players: entity.players,
      isTeamGame: entity.isTeamGame,
      teams: entity.teams?.map((k, v) => MapEntry(k, TeamModel.fromEntity(v))),
    );
  }
}
