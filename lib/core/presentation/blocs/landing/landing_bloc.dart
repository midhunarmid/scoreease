import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:scoreease/core/data/models/plain_response_model.dart';
import 'package:scoreease/core/domain/entities/scoreboard_entity.dart';
import 'package:scoreease/core/domain/usecases/score_board_usecase.dart';
import 'package:scoreease/core/presentation/utils/constants.dart';
import 'package:scoreease/core/presentation/utils/message_generator.dart';
import 'package:scoreease/core/presentation/utils/my_app_exception.dart';
import 'package:get_it/get_it.dart';

part 'landing_event.dart';
part 'landing_state.dart';

class LandingBloc extends Bloc<LandingEvent, LandingState> {
  LandingBloc() : super(LandingInitial()) {
    on<LandingEvent>((event, emit) async {
      try {
        appLogger.i(event);
        if (event is LandingGetScoreboardEvent) {
          emit.call(
            LoadingState(
              LoadingInfo(
                icon: LoadingIconEnum.submitting,
                title: MessageGenerator.getLabel("Checking Scoreboard"),
                message: MessageGenerator.getMessage("Please wait while we check the score board..."),
              ),
            ),
          );

          ScoreboardUseCase scoreboardUseCase = GetIt.instance<ScoreboardUseCase>();
          ScoreboardEntity scoreboardEntity = await scoreboardUseCase.getScoreboard(event.id);
          await delayedEmit(emit, LandingScoreCardReceivedState(scoreboardEntity));
        }
      } on MyAppException catch (ae) {
        appLogger.e(ae);
        await delayedEmit(
          emit,
          LandingErrorState(
            MessageGenerator.getMessage(ae.title),
            MessageGenerator.getMessage(ae.message),
            StatusInfoIconEnum.error,
          ),
        );
      } catch (e) {
        appLogger.e(e);
        await delayedEmit(
          emit,
          LandingErrorState(
            MessageGenerator.getMessage("un-expected-error"),
            MessageGenerator.getMessage("un-expected-error-message"),
            StatusInfoIconEnum.error,
          ),
        );
      }
    });
  }

  Future<void> delayedEmit(Emitter<LandingState> emitter, LandingState state) async {
    await Future.delayed(const Duration(milliseconds: 500));
    emitter.call(state);
  }
}
