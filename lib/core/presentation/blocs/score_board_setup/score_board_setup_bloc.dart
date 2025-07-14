import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:scoreease/core/data/models/plain_response_model.dart';
import 'package:scoreease/core/domain/entities/scoreboard_entity.dart';
import 'package:scoreease/core/domain/usecases/score_board_usecase.dart';
import 'package:scoreease/core/presentation/utils/constants.dart';
import 'package:scoreease/core/presentation/utils/message_generator.dart';
import 'package:scoreease/core/presentation/utils/my_app_exception.dart';
import 'package:get_it/get_it.dart';

part 'score_board_setup_event.dart';
part 'score_board_setup_state.dart';

class ScoreboardSetupBloc extends Bloc<ScoreboardSetupEvent, ScoreboardSetupState> {
  ScoreboardSetupBloc() : super(ScoreboardSetupInitial()) {
    on<ScoreboardSetupEvent>((event, emit) async {
      try {
        appLogger.i(event);
        if (event is ScoreboardSetupBasicSubmitEvent) {
          String errorTitle = "";
          String errorMessage = "";

          if (event.scoreboardEntity.id?.isEmpty ?? true) {
            errorTitle = MessageGenerator.getMessage("scoreboard-name-empty");
            errorMessage = MessageGenerator.getMessage("scoreboard-name-empty-message");
          } else if ((event.scoreboardEntity.id?.length ?? 0) < 3) {
            errorTitle = MessageGenerator.getMessage("scoreboard-name-too-short");
            errorMessage = MessageGenerator.getMessage("scoreboard-name-too-short-message");
          } else if (event.scoreboardEntity.author?.isEmpty ?? true) {
            errorTitle = MessageGenerator.getMessage("scoreboard-author-empty");
            errorMessage = MessageGenerator.getMessage("scoreboard-author-empty-message");
          } else if ((event.scoreboardEntity.author?.length ?? 0) < 3) {
            errorTitle = MessageGenerator.getMessage("scoreboard-author-too-short");
            errorMessage = MessageGenerator.getMessage("scoreboard-author-too-short-message");
          }

          if (errorTitle.isNotEmpty) {
            emit.call(ScoreboardSetupErrorState(errorTitle, errorMessage, StatusInfoIconEnum.error));
            return;
          }

          emit.call(ScoreboardSetupBasicSuccessState(event.scoreboardEntity));
        }
        if (event is ScoreboardSetupPlayerNamesSubmitEvent) {
          String errorTitle = "";
          String errorMessage = "";

          if (event.scoreboardEntity.players?.isEmpty ?? true) {
            errorTitle = MessageGenerator.getMessage("scoreboard-players-empty");
            errorMessage = MessageGenerator.getMessage("scoreboard-players-empty-message");
          } else if (event.scoreboardEntity.players?.keys.any((name) => name.isEmpty) ?? true) {
            errorTitle = MessageGenerator.getMessage("scoreboard-players-empty-name");
            errorMessage = MessageGenerator.getMessage("scoreboard-players-empty-name-message");
          }

          if (errorTitle.isNotEmpty) {
            emit.call(ScoreboardSetupErrorState(errorTitle, errorMessage, StatusInfoIconEnum.error));
            return;
          }

          emit.call(ScoreboardSetupPlayerNamesSuccessState(event.scoreboardEntity));
        } else if (event is ScoreboardSetupFinalSubmitEvent) {
          emit.call(
            LoadingState(
              LoadingInfo(
                icon: LoadingIconEnum.submitting,
                title: MessageGenerator.getLabel("Creating Scoreboard"),
                message: MessageGenerator.getMessage("Please wait while we create the score board for you..."),
              ),
            ),
          );

          ScoreboardUseCase scoreboardUseCase = GetIt.instance<ScoreboardUseCase>();
          String scoreboardId = await scoreboardUseCase.saveScoreboard(event.scoreboardEntity.copyWith(
            createdAt: DateTime.now(),
            ));
          await delayedEmit(emit, ScoreboardSetupSuccessState(scoreboardId));
        } else if (event is ScoreboardUpdatePlayerScoreEvent) {
          emit.call(
            LoadingState(
              LoadingInfo(
                icon: LoadingIconEnum.submitting,
                title: MessageGenerator.getMessage("scoreboard-score-update-title"),
                message: MessageGenerator.getMessage("scoreboard-score-update-message"),
              ),
            ),
          );

          ScoreboardEntity scoreboardEntity = event.scoreboardEntity;
          String playerName = event.playerName;
          ScoreboardEntity updatedScoreboardEntity = scoreboardEntity.copyWith(players: {
            ...?scoreboardEntity.players,
            playerName: (scoreboardEntity.players?[playerName] ?? 1) + 1,
          });

          ScoreboardUseCase scoreboardUseCase = GetIt.instance<ScoreboardUseCase>();
          await scoreboardUseCase.saveScoreboard(updatedScoreboardEntity);
          await delayedEmit(emit, ScoreboardScoreUpdateSuccessState(updatedScoreboardEntity));
        }
      } on MyAppException catch (ae) {
        appLogger.e(ae);
        await delayedEmit(
          emit,
          ScoreboardSetupErrorState(
            MessageGenerator.getMessage(ae.title),
            MessageGenerator.getMessage(ae.message),
            StatusInfoIconEnum.error,
          ),
        );
      } catch (e) {
        appLogger.e(e);
        await delayedEmit(
          emit,
          ScoreboardSetupErrorState(
            MessageGenerator.getMessage("un-expected-error"),
            MessageGenerator.getMessage("un-expected-error-message"),
            StatusInfoIconEnum.error,
          ),
        );
      }
    });
  }

  Future<void> delayedEmit(Emitter<ScoreboardSetupState> emitter, ScoreboardSetupState state) async {
    await Future.delayed(const Duration(milliseconds: 500));
    emitter.call(state);
  }
}
