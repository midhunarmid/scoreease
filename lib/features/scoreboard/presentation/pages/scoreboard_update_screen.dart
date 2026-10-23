import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:loading_indicator/loading_indicator.dart';
import 'package:progress_dialog_null_safe/progress_dialog_null_safe.dart';
import 'package:scoreease/features/scoreboard/domain/entities/scoreboard_entity.dart';
import 'package:scoreease/features/scoreboard/presentation/blocs/score_board_setup/score_board_setup_bloc.dart';
import 'package:scoreease/features/scoreboard/presentation/pages/scoreboard_score_display_screen.dart';
import 'package:scoreease/features/scoreboard/presentation/pages/scoreboard_editor_screen.dart';
import 'package:get_it/get_it.dart';
import 'package:scoreease/core/utils/my_app_exception.dart';
import 'package:scoreease/features/scoreboard/domain/entities/access_entity.dart';
import 'package:scoreease/features/scoreboard/domain/usecases/score_board_usecase.dart';
import 'package:scoreease/features/settings/presentation/pages/settings_screen.dart';
import 'package:scoreease/core/utils/constants.dart';
import 'package:scoreease/core/utils/theme.dart';
import 'package:scoreease/core/utils/widget_helper.dart';
import 'package:scoreease/core/widgets/password_prompt_widget.dart';
import 'package:scoreease/core/widgets/web_optimised_widget.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:scoreease/features/scoreboard/presentation/pages/widgets/custom_score_dialog.dart';
import 'package:scoreease/features/scoreboard/presentation/pages/widgets/player_score_card.dart';
import 'package:scoreease/features/scoreboard/presentation/pages/widgets/score_change_indicator.dart';

class ScoreboardScoreUpdateScreen extends StatefulWidget {
  final ScoreboardEntity? _scoreboardEntity;
  final String _id;
  const ScoreboardScoreUpdateScreen(this._id, this._scoreboardEntity,
      {Key? key})
      : super(key: key);
  static const routeName = 'update';

  @override
  State<ScoreboardScoreUpdateScreen> createState() =>
      _ScoreboardScoreUpdateScreenState();
}

class _ScoreboardScoreUpdateScreenState
    extends State<ScoreboardScoreUpdateScreen> {
  final ScoreboardSetupBloc _bloc = ScoreboardSetupBloc();
  ProgressDialog? _pr;
  ScoreboardEntity? _scoreboardEntity;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  final Map<String, GlobalKey<ScoreChangeIndicatorState>> _indicatorKeys = {};
  final ScoreboardUseCase _useCase = GetIt.instance<ScoreboardUseCase>();
  bool _isWriteUnlocked = false;
  bool _isLoadingAccess = true;

  @override
  void initState() {
    super.initState();
    _scoreboardEntity = widget._scoreboardEntity;
    _checkAccess();
  }

  @override
  void didUpdateWidget(ScoreboardScoreUpdateScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget._scoreboardEntity != oldWidget._scoreboardEntity) {
      setState(() {
        _scoreboardEntity = widget._scoreboardEntity;
      });
    }
  }

  Future<void> _checkAccess() async {
    bool hasAccess = false;
    try {
      hasAccess = await _useCase.hasAccess(widget._id, AccessLevel.write);
    } on MyAppException catch (e) {
      if (mounted) {
        showSingleButtonAlertDialog(
          context: context,
          title: e.title,
          message: e.message,
          positiveAction: () => context.go('/'),
        );
      }
      return;
    } catch (e) {
      appLogger.e(e);
    }
    if (!mounted) return;
    setState(() {
      _isWriteUnlocked = hasAccess;
      _isLoadingAccess = false;
    });
    if (hasAccess) _loadScoreboard();
  }

  // Listen live so scores from other scorers show up here too.
  void _loadScoreboard() {
    _bloc.add(ScoreboardListenPlayerScoreEvent(widget._id));
  }

  @override
  void dispose() {
    _searchController.dispose();
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
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
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
            progressTextStyle: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(fontWeight: FontWeight.w400),
            messageTextStyle: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(fontWeight: FontWeight.w400),
          );
          _pr?.show();
        } else if (state is ScoreboardSetupErrorState) {
          showSingleButtonAlertDialog(
              context: context, title: state.title, message: state.message);
        } else if (state is ScoreboardScoreUpdateSuccessState) {
          _scoreboardEntity = state.scoreboardEntity;
        } else if (state is ScoreboardReceivedSuccessState) {
          _scoreboardEntity = state.scoreboardEntity;
        }
      },
      child: BlocBuilder<ScoreboardSetupBloc, ScoreboardSetupState>(
        bloc: _bloc,
        builder: (ctx, state) {
          if (_isLoadingAccess) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          if (!_isWriteUnlocked) {
            return PasswordPromptWidget(
              onVerify: (password) =>
                  _useCase.unlock(widget._id, AccessLevel.write, password),
              title: "Update Protected Scoreboard",
              message: "Enter the write password to update scores.",
              onSuccess: () {
                setState(() {
                  _isWriteUnlocked = true;
                });
                _loadScoreboard();
              },
              onCancel: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/display?id=${widget._id}');
                }
              },
            );
          }

          List<String> playersList =
              _scoreboardEntity?.players?.keys.toList() ?? [];
          playersList.sort(); // Sort players alphabetically for consistency

          return Scaffold(
            appBar: _buildAppBar(context),
            body: Padding(
              padding: WebOptimisedWidget.getWebOptimisedHorizonatalPadding()
                  .copyWith(left: 16, right: 16),
              child: Column(
                children: [
                  _buildOverviewCard(),
                  _buildSearchBar(),
                  Expanded(
                    child: playersList.isNotEmpty
                        ? (_scoreboardEntity?.isTeamGame == true
                            ? _buildTeamLayout()
                            : getGridLayout(playersList))
                        : Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Text(
                                "No players found in this scoreboard. Please add players to update scores.",
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(color: Colors.red),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    final title = _scoreboardEntity?.title ?? "Scoreboard Update";
    final author = _scoreboardEntity?.author ?? "";
    final subtitle = author.isNotEmpty ? "Created by $author" : "";

    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
          ),
          if (subtitle.isNotEmpty)
            Text(
              subtitle,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 10.sp,
                  ),
            ),
        ],
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: "Back",
        onPressed: () {
          context.go(
              '/${ScoreboardScoreDisplayScreen.routeName}?id=${widget._id}');
        },
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_document),
          tooltip: "Edit Scoreboard",
          onPressed: () {
            if (_scoreboardEntity != null) {
              context
                  .go("/${ScoreboardEditorScreen.routeName}?id=${widget._id}");
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.copy_rounded),
          tooltip: "Copy Scoreboard ID",
          onPressed: () {
            final id = _scoreboardEntity?.id ?? widget._id;
            if (id.isNotEmpty) {
              Clipboard.setData(ClipboardData(text: id));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Scoreboard ID '$id' copied to clipboard!"),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: appColors.pleasantButtonBg,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: "Reset All Scores",
          onPressed: () {
            if (_scoreboardEntity != null) {
              showTwoButtonAlertDialog(
                context: context,
                title: "Reset Scores",
                message:
                    "Are you sure you want to reset all player scores to 0?",
                positiveButton: "Reset",
                negativeButton: "Cancel",
                positiveAction: () {
                  final board = _scoreboardEntity!;
                  final previousScores = Map<String, int>.from(board.players ?? {});
                  _bloc.add(ScoreboardResetScoresEvent(board));
                  _showUndoSnackBar("All scores reset to 0", () {
                    _bloc.add(ScoreboardRestoreScoresEvent(board, previousScores));
                  });
                },
              );
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.settings),
          tooltip: "Settings",
          onPressed: () {
            context.go("/${SettingsScreen.routeName}");
          },
        ),
      ],
    );
  }

  Widget _buildOverviewCard() {
    final desc = _scoreboardEntity?.description ?? "";
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (desc.isNotEmpty) ...[
            Text(
              desc,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).hintColor,
                    fontWeight: FontWeight.w400,
                  ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Scoreboard ID:",
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).hintColor,
                          ),
                    ),
                    Text(
                      _scoreboardEntity?.id ?? widget._id,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: appColors.pleasantButtonBg,
                  foregroundColor: appColors.buttonTextColor,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  context.go(
                      "/${ScoreboardScoreDisplayScreen.routeName}?id=${_scoreboardEntity?.id}");
                },
                icon: const Icon(Icons.monitor_heart_outlined, size: 18),
                label: const Text("Live Scoreboard"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: TextField(
        controller: _searchController,
        style: Theme.of(context).textTheme.labelMedium,
        onChanged: (val) {
          setState(() {
            _searchQuery = val;
          });
        },
        decoration: InputDecoration(
          hintText: "Search players...",
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: "Clear search",
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = "";
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: appColors.inputBgFill,
          border: OutlineInputBorder(
            borderSide: BorderSide.none,
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildPlayerCard(String playerName, String playerScore) {
    final indicatorKey = _indicatorKeys.putIfAbsent(
        playerName, () => GlobalKey<ScoreChangeIndicatorState>());
    return PlayerScoreCard(
      key: ValueKey('score_$playerName'),
      playerName: playerName,
      playerScore: playerScore,
      indicatorKey: indicatorKey,
      onChangeScore: (delta) => _changeScore(playerName, delta, indicatorKey),
      onEditScore: () async {
        final currentScore = int.tryParse(playerScore) ?? 0;
        final newScore = await showCustomScoreDialog(
            context: context, playerName: playerName, currentScore: currentScore);
        if (newScore != null && newScore != currentScore) {
          final delta = newScore - currentScore;
          _changeScore(playerName, delta, indicatorKey);
          _showUndoSnackBar("$playerName set to $newScore", () {
            _changeScore(playerName, -delta, indicatorKey);
          });
        }
      },
    );
  }

  void _showUndoSnackBar(String message, VoidCallback onUndo) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(label: "Undo", onPressed: onUndo),
      ),
    );
  }

  void _changeScore(String playerName, int delta,
      GlobalKey<ScoreChangeIndicatorState> indicatorKey) {
    if (delta == 0 || _scoreboardEntity == null) return;
    indicatorKey.currentState?.showDelta(delta);
    _bloc.add(ScoreboardUpdatePlayerScoreEvent(
      playerName,
      _scoreboardEntity!,
      delta: delta,
    ));
  }

  Widget getGridLayout(List<String> playersList) {
    final filteredList = playersList
        .where((player) =>
            player.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    if (filteredList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off_rounded, size: 48.sp, color: Colors.grey),
              const SizedBox(height: 8),
              Text(
                "No players matching '$_searchQuery'",
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.grey,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      itemCount: filteredList.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        childAspectRatio: 0.82,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      ),
      itemBuilder: (context, index) {
        String playerName = filteredList[index];
        String playerScore =
            _scoreboardEntity?.players?[playerName]?.toString() ?? '0';
        return _buildPlayerCard(playerName, playerScore);
      },
    );
  }

  Widget _buildTeamLayout() {
    final teams = _scoreboardEntity?.teams;
    if (teams == null || teams.isEmpty) return const SizedBox.shrink();

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: teams.length,
      itemBuilder: (context, index) {
        final teamEntity = teams.values.elementAt(index);
        final teamName = teamEntity.name;
        
        final filteredPlayers = teamEntity.players.keys
            .where((player) =>
                player.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

        if (filteredPlayers.isEmpty) return const SizedBox.shrink();

        int teamTotalScore = 0;
        for (var p in teamEntity.players.keys) {
          teamTotalScore += _scoreboardEntity?.players?[p] ?? 0;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.only(top: 16, bottom: 8),
              decoration: BoxDecoration(
                color: appColors.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: appColors.primaryColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.shield, color: appColors.primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        teamName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: appColors.primaryColor,
                            ),
                      ),
                    ],
                  ),
                  Text(
                    teamTotalScore.toString(),
                    key: ValueKey("team_${teamName}_$teamTotalScore"),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: appColors.primaryColor,
                        ),
                  ).animate(key: ValueKey("team_${teamName}_$teamTotalScore")).scaleXY(
                      begin: 1.5,
                      end: 1.0,
                      duration: 250.ms,
                      curve: Curves.easeOutBack),
                ],
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredPlayers.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                childAspectRatio: 0.82,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
              ),
              itemBuilder: (context, idx) {
                String playerName = filteredPlayers[idx];
                String playerScore =
                    _scoreboardEntity?.players?[playerName]?.toString() ?? '0';
                return _buildPlayerCard(playerName, playerScore);
              },
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}
