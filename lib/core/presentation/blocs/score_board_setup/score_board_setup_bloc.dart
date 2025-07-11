import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:scoreease/core/data/models/plain_response_model.dart';
import 'package:scoreease/core/data/models/score_board_model.dart';
import 'package:scoreease/core/domain/usecases/score_board_usecase.dart';
import 'package:scoreease/core/presentation/utils/constants.dart';
import 'package:scoreease/core/presentation/utils/message_generator.dart';
import 'package:scoreease/core/presentation/utils/my_app_exception.dart';
import 'package:get_it/get_it.dart';

part 'score_board_setup_event.dart';
part 'score_board_setup_state.dart';

class ScoreBoardSetupBloc
    extends Bloc<ScoreBoardSetupEvent, ScoreBoardSetupState> {
  ScoreBoardSetupBloc() : super(ScoreBoardSetupInitial()) {
    on<ScoreBoardSetupEvent>((event, emit) async {
      try {
        appLogger.i(event);
        if (event is ScoreBoardSetupSubmitEvent) {
          emit.call(
            LoadingState(
              LoadingInfo(
                icon: LoadingIconEnum.submitting,
                title: MessageGenerator.getLabel("Creating Score Board"),
                message: MessageGenerator.getMessage(
                    "Please wait while we create the score board for you..."),
              ),
            ),
          );

          ScoreBoardUseCase scoreBoardUseCase =
              GetIt.instance<ScoreBoardUseCase>();
          ScoreBoardModel scoreBoardModel =
              await scoreBoardUseCase.getScoreBoard(event.id);
          await delayedEmit(emit, ScoreBoardSetupSuccessState());
        }
      } on MyAppException catch (ae) {
        appLogger.e(ae);
        await delayedEmit(
          emit,
          ScoreBoardSetupErrorState(
            MessageGenerator.getMessage(ae.title),
            MessageGenerator.getMessage(ae.message),
            StatusInfoIconEnum.error,
          ),
        );
      } catch (e) {
        appLogger.e(e);
        await delayedEmit(
          emit,
          ScoreBoardSetupErrorState(
            MessageGenerator.getMessage("un-expected-error"),
            MessageGenerator.getMessage("un-expected-error-message"),
            StatusInfoIconEnum.error,
          ),
        );
      }
    });
  }

  Future<void> delayedEmit(
      Emitter<ScoreBoardSetupState> emitter, ScoreBoardSetupState state) async {
    await Future.delayed(const Duration(milliseconds: 500));
    emitter.call(state);
  }
}
