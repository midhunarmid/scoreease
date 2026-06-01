import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:scoreease/features/scoreboard/domain/entities/scoreboard_entity.dart';
import 'package:scoreease/features/scoreboard/presentation/blocs/score_board_setup/score_board_setup_bloc.dart';
import 'package:scoreease/features/scoreboard/presentation/pages/scoreboard_update_screen.dart';
import 'package:scoreease/core/utils/constants.dart';
import 'package:scoreease/core/utils/theme.dart';
import 'package:scoreease/core/utils/widget_helper.dart';
import 'package:scoreease/core/widgets/animated_container.dart';
import 'package:scoreease/core/widgets/web_optimised_widget.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';

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
  bool _sortByScore = true; // Default to sort by score/rank

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

          // Sort players based on current preference
          if (_sortByScore) {
            playersList.sort((a, b) {
              final scoreA = _scoreboardEntity?.players?[a] ?? 0;
              final scoreB = _scoreboardEntity?.players?[b] ?? 0;
              int compare = scoreB.compareTo(scoreA);
              if (compare != 0) return compare;
              return a.compareTo(b);
            });
          } else {
            playersList.sort();
          }

          return Scaffold(
            appBar: _buildAppBar(context),
            body: Padding(
              padding: WebOptimisedWidget.getWebOptimisedHorizonatalPadding().copyWith(left: 16, right: 16),
              child: playersList.isNotEmpty
                  ? Column(
                      children: [
                        _buildOverviewCard(),
                        Expanded(child: getGridLayout(playersList)),
                      ],
                    )
                  : Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.people_outline_rounded, size: 48, color: Colors.red),
                            const SizedBox(height: 16),
                            Text(
                              "No players found in this scoreboard.\nPlease add players to show standings.",
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(height: 1.4),
                            ),
                            const SizedBox(height: 20),
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
            ),
          );
        },
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    final title = _scoreboardEntity?.title ?? "Live Leaderboard";
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
        onPressed: () {
          context.go("/");
        },
      ),
      actions: [
        IconButton(
          icon: Icon(_sortByScore ? Icons.sort_by_alpha : Icons.leaderboard),
          tooltip: _sortByScore ? "Sort Alphabetically" : "Sort by Rank",
          onPressed: () {
            setState(() {
              _sortByScore = !_sortByScore;
            });
          },
        ),
        IconButton(
          icon: const Icon(Icons.share_outlined),
          tooltip: "Share Scoreboard",
          onPressed: () {
            final link = "$appBaseUrl/display?id=$_id";
            SharePlus.instance.share(ShareParams(text: "Check out the live scores on ScoreEase!\n$link"));
          },
        ),
        IconButton(
          icon: const Icon(Icons.edit_note_outlined),
          tooltip: "Update Scores",
          onPressed: () {
            context.go("/${ScoreboardScoreUpdateScreen.routeName}?id=$_id", extra: _scoreboardEntity);
          },
        ),
      ],
    );
  }

  Widget _buildOverviewCard() {
    final desc = _scoreboardEntity?.description ?? "";
    final totalPlayers = _scoreboardEntity?.players?.length ?? 0;

    int totalScore = 0;
    _scoreboardEntity?.players?.values.forEach((val) => totalScore += val);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12, bottom: 16),
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
                      "Total Players",
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).hintColor,
                          ),
                    ),
                    Text(
                      "$totalPlayers players",
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "Combined Score",
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).hintColor,
                          ),
                    ),
                    Text(
                      "$totalScore points",
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: appColors.primaryColor,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
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

  Widget _buildPlayerCard(String playerName, String playerScore, int rank) {
    final avatarColor = _getAvatarColor(playerName);
    final firstLetter = playerName.isNotEmpty ? playerName[0].toUpperCase() : "?";
    final isLeader = rank == 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLeader ? Colors.amber.shade400 : appColors.primaryColor.withValues(alpha: 0.12),
          width: isLeader ? 2 : 1.5,
        ),
        boxShadow: [
          if (isLeader)
            BoxShadow(
              color: Colors.amber.shade200.withValues(alpha: 0.3),
              blurRadius: 12,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            )
          else
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRankBadge(rank),
              if (isLeader)
                Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.amber.shade700,
                  size: 24.sp,
                )
              else
                const SizedBox(width: 24),
            ],
          ),
          Column(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: avatarColor,
                child: Text(
                  firstLetter,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
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
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              playerScore,
              key: ValueKey<String>(playerScore),
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontSize: 64.sp,
                    fontWeight: FontWeight.w900,
                    color: isLeader ? Colors.amber.shade800 : appColors.primaryColor,
                  ),
            ).animate(key: ValueKey(playerScore)).fade().scaleXY(begin: 1.5, end: 1.0, duration: 400.ms, curve: Curves.easeOutBack),
          ),
        ],
      ),
    ).animate().fade().slideY(begin: 0.2, curve: Curves.easeOut);
  }

  Widget _buildRankBadge(int rank) {
    if (rank == 1) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.amber.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events_rounded, color: Colors.amber.shade800, size: 14.sp),
            const SizedBox(width: 4),
            Text(
              "1st",
              style: TextStyle(
                color: Colors.amber.shade900,
                fontWeight: FontWeight.bold,
                fontSize: 10.sp,
              ),
            ),
          ],
        ),
      );
    } else if (rank == 2) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events_rounded, color: Colors.grey.shade600, size: 14.sp),
            const SizedBox(width: 4),
            Text(
              "2nd",
              style: TextStyle(
                color: Colors.grey.shade800,
                fontWeight: FontWeight.bold,
                fontSize: 10.sp,
              ),
            ),
          ],
        ),
      );
    } else if (rank == 3) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events_rounded, color: Colors.orange.shade700, size: 14.sp),
            const SizedBox(width: 4),
            Text(
              "3rd",
              style: TextStyle(
                color: Colors.orange.shade900,
                fontWeight: FontWeight.bold,
                fontSize: 10.sp,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          "#$rank",
          style: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.bold,
            fontSize: 10.sp,
          ),
        ),
      );
    }
  }

  Widget getGridLayout(List<String> playersList) {
    // Rank lookup list (always sorted by score descending for accurate rank index calculation)
    final scoreSortedList = List<String>.from(playersList);
    scoreSortedList.sort((a, b) {
      final scoreA = _scoreboardEntity?.players?[a] ?? 0;
      final scoreB = _scoreboardEntity?.players?[b] ?? 0;
      int compare = scoreB.compareTo(scoreA);
      if (compare != 0) return compare;
      return a.compareTo(b);
    });

    return GridView.builder(
      itemCount: playersList.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        childAspectRatio: 0.75,
        mainAxisSpacing: 16,

        crossAxisSpacing: 16,
      ),
      itemBuilder: (context, index) {
        String playerName = playersList[index];
        String playerScore = _scoreboardEntity?.players?[playerName]?.toString() ?? '0';
        int rank = scoreSortedList.indexOf(playerName) + 1;
        return _buildPlayerCard(playerName, playerScore, rank);
      },
    );
  }
}
