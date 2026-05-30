import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:loading_indicator/loading_indicator.dart';
import 'package:progress_dialog_null_safe/progress_dialog_null_safe.dart';
import 'package:scoreease/core/domain/entities/scoreboard_entity.dart';
import 'package:scoreease/core/presentation/blocs/score_board_setup/score_board_setup_bloc.dart';
import 'package:scoreease/core/presentation/pages/scoreboard_score_display_screen.dart';
import 'package:scoreease/core/presentation/pages/settings_screen.dart';
import 'package:scoreease/core/presentation/utils/constants.dart';
import 'package:scoreease/core/presentation/utils/theme.dart';
import 'package:scoreease/core/presentation/utils/widget_helper.dart';
import 'package:scoreease/core/presentation/widgets/web_optimised_widget.dart';

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

  @override
  void initState() {
    super.initState();
    _scoreboardEntity = widget._scoreboardEntity;
    if (_scoreboardEntity == null) {
      _bloc.add(ScoreboardGetEvent(widget._id));
    }
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
                        ? getGridLayout(playersList)
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
                ),
          ),
          if (subtitle.isNotEmpty)
            Text(
              subtitle,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).hintColor,
                    fontSize: 10.sp,
                  ),
            ),
        ],
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          context.go("/");
        },
      ),
      actions: [
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
                  _bloc.add(ScoreboardResetScoresEvent(_scoreboardEntity!));
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
              Column(
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

  Color _getAvatarColor(String name) {
    final colors = [
      Colors.blue.shade600,
      Colors.purple.shade600,
      Colors.orange.shade600,
      Colors.teal.shade600,
      Colors.pink.shade600,
      Colors.indigo.shade600,
      Colors.green.shade600,
      Colors.amber.shade700,
    ];
    int hash = 0;
    for (int i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return colors[hash.abs() % colors.length];
  }

  Widget _buildPlayerCard(String playerName, String playerScore) {
    final avatarColor = _getAvatarColor(playerName);
    final firstLetter =
        playerName.isNotEmpty ? playerName[0].toUpperCase() : "?";

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: appColors.primaryColor.withValues(alpha: 0.12),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: avatarColor,
                child: Text(
                  firstLetter,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                playerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
              ),
            ],
          ),
          Text(
            playerScore,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontSize: 32.sp,
                  fontWeight: FontWeight.w900,
                  color: appColors.primaryColor,
                ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildScoreControlButton(
                icon: Icons.remove,
                color: appColors.negativeButtonBg,
                tooltip: "Subtract 1",
                onTap: () {
                  _bloc.add(ScoreboardUpdatePlayerScoreEvent(
                    playerName,
                    _scoreboardEntity!,
                    delta: -1,
                  ));
                },
              ),
              _buildScoreControlButton(
                icon: Icons.edit_outlined,
                color: Colors.grey.shade600,
                tooltip: "Edit custom score",
                onTap: () {
                  _showCustomScoreDialog(
                      playerName, int.tryParse(playerScore) ?? 0);
                },
              ),
              _buildScoreControlButton(
                icon: Icons.add,
                color: appColors.pleasantButtonBg,
                tooltip: "Add 1",
                onTap: () {
                  _bloc.add(ScoreboardUpdatePlayerScoreEvent(
                    playerName,
                    _scoreboardEntity!,
                    delta: 1,
                  ));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScoreControlButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: color,
            size: 18.sp,
          ),
        ),
      ),
    );
  }

  void _showCustomScoreDialog(String playerName, int currentScore) {
    final controller = TextEditingController(text: currentScore.toString());
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            "Edit score for $playerName",
            style: Theme.of(ctx)
                .textTheme
                .labelLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
            ],
            style: Theme.of(ctx).textTheme.labelMedium,
            decoration: InputDecoration(
              labelText: "Score",
              filled: true,
              fillColor: appColors.inputBgFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                "Cancel",
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: appColors.pleasantButtonBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                final newScore = int.tryParse(controller.text) ?? currentScore;
                final delta = newScore - currentScore;
                if (delta != 0) {
                  _bloc.add(ScoreboardUpdatePlayerScoreEvent(
                    playerName,
                    _scoreboardEntity!,
                    delta: delta,
                  ));
                }
                Navigator.pop(ctx);
              },
              child: Text(
                "Save",
                style: TextStyle(color: appColors.buttonTextColor),
              ),
            ),
          ],
        );
      },
    );
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
}
