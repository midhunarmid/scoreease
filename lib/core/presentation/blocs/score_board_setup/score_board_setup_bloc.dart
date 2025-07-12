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

class ScoreboardSetupBloc
    extends Bloc<ScoreboardSetupEvent, ScoreboardSetupState> {
  ScoreboardSetupBloc() : super(ScoreboardSetupInitial()) {
    on<ScoreboardSetupEvent>((event, emit) async {
      try {
        appLogger.i(event);
        if (event is ScoreboardSetupSubmitEvent) {
          emit.call(
            LoadingState(
              LoadingInfo(
                icon: LoadingIconEnum.submitting,
                title: MessageGenerator.getLabel("Creating Scoreboard"),
                message: MessageGenerator.getMessage(
                    "Please wait while we create the score board for you..."),
              ),
            ),
          );

          ScoreboardUseCase scoreboardUseCase =
              GetIt.instance<ScoreboardUseCase>();
          ScoreboardEntity scoreboardModel =
              await scoreboardUseCase.getScoreboard(event.id);
          await delayedEmit(emit, ScoreboardSetupSuccessState());
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

  Future<void> delayedEmit(
      Emitter<ScoreboardSetupState> emitter, ScoreboardSetupState state) async {
    await Future.delayed(const Duration(milliseconds: 500));
    emitter.call(state);
  }
}
