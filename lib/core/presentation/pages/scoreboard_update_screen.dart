import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:loading_indicator/loading_indicator.dart';
import 'package:progress_dialog_null_safe/progress_dialog_null_safe.dart';
import 'package:scoreease/core/domain/entities/scoreboard_entity.dart';
import 'package:scoreease/core/presentation/blocs/score_board_setup/score_board_setup_bloc.dart';
import 'package:scoreease/core/presentation/utils/constants.dart';
import 'package:scoreease/core/presentation/utils/theme.dart';
import 'package:scoreease/core/presentation/utils/widget_helper.dart';
import 'package:scoreease/core/presentation/widgets/animated_container.dart';
import 'package:scoreease/core/presentation/widgets/web_optimised_widget.dart';

class ScoreboardScoreUpdateScreen extends StatefulWidget {
  final ScoreboardEntity _scoreboardEntity;
  const ScoreboardScoreUpdateScreen(this._scoreboardEntity, {Key? key}) : super(key: key);
  static const routeName = 'update';

  @override
  State<ScoreboardScoreUpdateScreen> createState() => _ScoreboardScoreUpdateScreenState();
}

class _ScoreboardScoreUpdateScreenState extends State<ScoreboardScoreUpdateScreen> {
  final ScoreboardSetupBloc _bloc = ScoreboardSetupBloc();
  ProgressDialog? _pr;
  late ScoreboardEntity _scoreboardEntity;

  @override
  void initState() {
    super.initState();
    _scoreboardEntity = widget._scoreboardEntity;
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener(
      bloc: _bloc,
      listener: (context, state) {
        appLogger.i(state);

        if (_pr?.isShowing() ?? false) {
          _pr?.hide();
        }
        if (state is LoadingState) {
          _pr = ProgressDialog(
            context,
            type: ProgressDialogType.normal,
            isDismissible: false,
          );
          _pr?.style(
            backgroundColor: appColors.screenBg,
            padding: WebOptimisedWidget.getWebOptimisedHorizonatalPadding(),
            message: state.loadingInfo.message,
            widgetAboveTheDialog: Text(
              state.loadingInfo.title,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            progressWidget: Padding(
              padding: const EdgeInsets.all(8.0),
              child: LoadingIndicator(
                indicatorType: Indicator.lineScalePulseOutRapid,
                colors: appColors.rainbowColors,
                strokeWidth: 2,
                backgroundColor: appColors.screenBg,
                pathBackgroundColor: appColors.screenBg,
              ),
            ),
            progressTextStyle: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w400),
            messageTextStyle: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w400),
          );
          _pr?.show();
        } else if (state is ScoreboardSetupErrorState) {
          showSingleButtonAlertDialog(context: context, title: state.title, message: state.message);
        } else if (state is ScoreboardScoreUpdateSuccessState) {
          _scoreboardEntity = state.scoreboardEntity;
        }
      },
      child: BlocBuilder<ScoreboardSetupBloc, ScoreboardSetupState>(
        bloc: _bloc,
        builder: (ctx, state) {
          List<String> playersList = _scoreboardEntity.players?.keys.toList() ?? [];
          return Scaffold(
            body: Padding(
              padding: WebOptimisedWidget.getWebOptimisedHorizonatalPadding(),
              child: playersList.isNotEmpty
                  ? getGridLayout(playersList)
                  : Center(
                      child: Text(
                        "No players found in this scoreboard. Please add players to update scores.",
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.red),
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget getGridLayout(List<String> playersList) {
    return GridView.builder(
      itemCount: playersList.length,
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 0.5.sw,
        childAspectRatio: 1,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        String playerName = playersList[index];
        String playerScore = _scoreboardEntity.players?[playerName]?.toString() ?? '0';
        return Container(
          decoration: BoxDecoration(
            color: appColors.pleasantButtonBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                playerName,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: appColors.buttonTextColor,
                    ),
              ),
              Text(
                playerScore,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: appColors.buttonTextColor,
                    ),
              ),
              SizedBox(height: 16.h),
              AnimatedClickableTextContainer(
                isActive: false,
                iconSrc: "",
                title: "+ 1",
                press: () {
                  onPlayerScoreAddButtonClicked(playerName);
                },
                bgColor: appColors.pleasantButtonBgHover,
                bgColorHover: appColors.pleasantButtonBg,
              ),
            ],
          ),
        );
      },
    );
  }

  void onPlayerScoreAddButtonClicked(String playerName) {
    _bloc.add(ScoreboardUpdatePlayerScoreEvent(playerName, _scoreboardEntity));
  }
}
