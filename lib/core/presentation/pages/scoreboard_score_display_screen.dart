import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:scoreease/core/domain/entities/scoreboard_entity.dart';
import 'package:scoreease/core/presentation/blocs/score_board_setup/score_board_setup_bloc.dart';
import 'package:scoreease/core/presentation/utils/constants.dart';
import 'package:scoreease/core/presentation/utils/theme.dart';
import 'package:scoreease/core/presentation/utils/widget_helper.dart';
import 'package:scoreease/core/presentation/widgets/animated_container.dart';
import 'package:scoreease/core/presentation/widgets/web_optimised_widget.dart';

class ScoreboardScoreDisplayScreen extends StatefulWidget {
  final String _id;
  const ScoreboardScoreDisplayScreen(this._id, {Key? key}) : super(key: key);
  static const routeName = 'display';

  @override
  State<ScoreboardScoreDisplayScreen> createState() => _ScoreboardScoreDisplayScreenState();
}

class _ScoreboardScoreDisplayScreenState extends State<ScoreboardScoreDisplayScreen> {
  final ScoreboardSetupBloc _bloc = ScoreboardSetupBloc();
  ScoreboardEntity? _scoreboardEntity;
  late String _id;

  @override
  void initState() {
    super.initState();
    _id = widget._id;
    _bloc.add(ScoreboardListenPlayerScoreEvent(_id));
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

        if (state is ScoreboardSetupErrorState) {
          showSingleButtonAlertDialog(context: context, title: state.title, message: state.message);
        } else if (state is ScoreboardReceivedSuccessState) {
          _scoreboardEntity = state.scoreboardEntity;
        }
      },
      child: BlocBuilder<ScoreboardSetupBloc, ScoreboardSetupState>(
        bloc: _bloc,
        builder: (ctx, state) {
          List<String> playersList = _scoreboardEntity?.players?.keys.toList() ?? [];
          playersList.sort();
          return Scaffold(
            body: Padding(
              padding: WebOptimisedWidget.getWebOptimisedHorizonatalPadding(),
              child: playersList.isNotEmpty
                  ? getGridLayout(playersList)
                  : Center(
                      child: Column(
                        children: [
                          Text(
                            "No players found in this scoreboard. Please add players to update scores.",
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.red),
                          ),
                          AnimatedClickableTextContainer(
                            isActive: false,
                            iconSrc: "",
                            title: "Reload",
                            press: () {
                              _bloc.add(ScoreboardListenPlayerScoreEvent(_id));
                            },
                            bgColor: appColors.pleasantButtonBg,
                            bgColorHover: appColors.pleasantButtonBgHover,
                          )
                        ],
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
        String playerScore = _scoreboardEntity?.players?[playerName]?.toString() ?? '0';
        return Container(
          decoration: BoxDecoration(
            color: appColors.screenBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                playerName,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(),
              ),
              Text(
                playerScore,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(),
              ),
            ],
          ),
        );
      },
    );
  }
}
