import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:scoreease/features/scoreboard/domain/entities/scoreboard_entity.dart';
import 'package:scoreease/features/scoreboard/presentation/blocs/score_board_setup/score_board_setup_bloc.dart';
import 'package:scoreease/features/scoreboard/presentation/pages/scoreboard_update_screen.dart';
import 'package:get_it/get_it.dart';
import 'package:scoreease/core/utils/my_app_exception.dart';
import 'package:scoreease/features/scoreboard/domain/entities/access_entity.dart';
import 'package:scoreease/features/scoreboard/domain/usecases/score_board_usecase.dart';
import 'package:scoreease/core/utils/constants.dart';
import 'package:scoreease/core/utils/theme.dart';
import 'package:scoreease/core/utils/widget_helper.dart';
import 'package:scoreease/core/widgets/animated_container.dart';
import 'package:scoreease/core/widgets/password_prompt_widget.dart';
import 'package:scoreease/core/widgets/web_optimised_widget.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';
import 'package:scoreease/features/scoreboard/presentation/pages/widgets/live_player_card.dart';
import 'package:scoreease/features/scoreboard/presentation/pages/widgets/score_change_indicator.dart';

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

  final Map<String, GlobalKey<ScoreChangeIndicatorState>> _indicatorKeys = {};
  Map<String, int> _previousRanks = {};
  Map<String, int> _currentRanks = {};

  Map<String, int> _calculateRanks(Map<String, int> playersMap) {
    List<String> playersList = playersMap.keys.toList();
    playersList.sort((a, b) {
      final scoreA = playersMap[a] ?? 0;
      final scoreB = playersMap[b] ?? 0;
      int compare = scoreB.compareTo(scoreA);
      if (compare != 0) return compare;
      return a.compareTo(b);
    });
    
    Map<String, int> ranks = {};
    for (int i = 0; i < playersList.length; i++) {
      ranks[playersList[i]] = i + 1;
    }
    return ranks;
  }
  final ScoreboardUseCase _useCase = GetIt.instance<ScoreboardUseCase>();
  bool _isReadUnlocked = false;
  bool _isLoadingAccess = true;

  @override
  void initState() {
    super.initState();
    _id = widget._id;
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    bool hasAccess = false;
    try {
      hasAccess = await _useCase.hasAccess(_id, AccessLevel.read);
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
      _isReadUnlocked = hasAccess;
      _isLoadingAccess = false;
    });
    if (hasAccess) _bloc.add(ScoreboardListenPlayerScoreEvent(_id));
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
          final oldPlayers = _scoreboardEntity?.players;
          final newPlayers = state.scoreboardEntity.players;
          
          if (oldPlayers != null && newPlayers != null) {
            newPlayers.forEach((player, newScore) {
              final oldScore = oldPlayers[player] ?? 0;
              final delta = newScore - oldScore;
              if (delta != 0) {
                _indicatorKeys[player]?.currentState?.showDelta(delta);
              }
            });
          }

          if (_scoreboardEntity != null && state.scoreboardEntity.players != null) {
              _previousRanks = _calculateRanks(_scoreboardEntity!.players ?? {});
              _currentRanks = _calculateRanks(state.scoreboardEntity.players!);
          }

          setState(() {
            _scoreboardEntity = state.scoreboardEntity;
          });
        }
      },
      child: BlocBuilder<ScoreboardSetupBloc, ScoreboardSetupState>(
        bloc: _bloc,
        builder: (ctx, state) {
          if (_isLoadingAccess) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (!_isReadUnlocked) {
            return PasswordPromptWidget(
              onVerify: (password) => _useCase.unlock(_id, AccessLevel.read, password),
              title: "Protected Scoreboard",
              message: "Enter the read password to view this scoreboard.",
              onSuccess: () {
                setState(() {
                  _isReadUnlocked = true;
                });
                _bloc.add(ScoreboardListenPlayerScoreEvent(_id));
              },
              onCancel: () => context.go('/'),
            );
          }

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
                        Expanded(
                          child: _scoreboardEntity?.isTeamGame == true
                              ? _buildTeamLayout()
                              : getGridLayout(playersList),
                        ),
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
        tooltip: "Back",
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
            context.go("/${ScoreboardScoreUpdateScreen.routeName}?id=$_id");
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
        childAspectRatio: 0.70,
        mainAxisSpacing: 16,

        crossAxisSpacing: 16,
      ),
      itemBuilder: (context, index) {
        String playerName = playersList[index];
        String playerScore = _scoreboardEntity?.players?[playerName]?.toString() ?? '0';
        int rank = scoreSortedList.indexOf(playerName) + 1;
        
        bool rankChanged = _previousRanks.isNotEmpty && _previousRanks[playerName] != _currentRanks[playerName];

        Widget card = LivePlayerCard(
          key: ValueKey('live_$playerName'),
          playerName: playerName,
          playerScore: playerScore,
          rank: rank,
          indicatorKey: _indicatorKeys.putIfAbsent(playerName, () => GlobalKey<ScoreChangeIndicatorState>()),
        );

        if (rankChanged) {
           card = card.animate(key: ValueKey('rank_change_${_currentRanks[playerName]}_$playerName'))
               .shimmer(duration: 800.ms, color: Colors.amber.withValues(alpha: 0.5))
               .scaleXY(begin: 1.0, end: 1.05, duration: 300.ms, curve: Curves.easeOutBack)
               .then()
               .scaleXY(begin: 1.05, end: 1.0, duration: 300.ms, curve: Curves.easeIn);
        } else {
           card = card.animate(key: ValueKey('fade_in_$playerName')).fade().slideY(begin: 0.2, curve: Curves.easeOut);
        }

        return card;
      },
    );
  }

  Widget _buildTeamLayout() {
    final teams = _scoreboardEntity?.teams;
    if (teams == null || teams.isEmpty) return const SizedBox.shrink();

    // Calculate team scores
    final Map<String, int> teamScores = {};
    for (var entry in teams.entries) {
      int score = 0;
      for (var player in entry.value.players.keys) {
        score += _scoreboardEntity?.players?[player] ?? 0;
      }
      teamScores[entry.key] = score;
    }

    // Sort teams by score
    final sortedTeams = teams.keys.toList();
    sortedTeams.sort((a, b) => teamScores[b]!.compareTo(teamScores[a]!));

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: sortedTeams.length,
      itemBuilder: (context, index) {
        final teamName = sortedTeams[index];
        final teamEntity = teams[teamName]!;
        final teamTotalScore = teamScores[teamName]!;
        
        // Sort players within team
        final teamPlayers = teamEntity.players.keys.toList();
        teamPlayers.sort((a, b) {
          final scoreA = _scoreboardEntity?.players?[a] ?? 0;
          final scoreB = _scoreboardEntity?.players?[b] ?? 0;
          int compare = scoreB.compareTo(scoreA);
          if (compare != 0) return compare;
          return a.compareTo(b);
        });

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
              itemCount: teamPlayers.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 240,
                childAspectRatio: 0.70,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
              ),
              itemBuilder: (context, idx) {
                String playerName = teamPlayers[idx];
                String playerScore = _scoreboardEntity?.players?[playerName]?.toString() ?? '0';
                
                // Rank logic for display screen
                // Use global rank or team rank? Let's use global rank for now.
                final globalScoreSortedList = List<String>.from(_scoreboardEntity?.players?.keys ?? <String>[]);
                globalScoreSortedList.sort((a, b) {
                  final scoreA = _scoreboardEntity?.players?[a] ?? 0;
                  final scoreB = _scoreboardEntity?.players?[b] ?? 0;
                  int compare = scoreB.compareTo(scoreA);
                  if (compare != 0) return compare;
                  return a.compareTo(b);
                });
                int rank = globalScoreSortedList.indexOf(playerName) + 1;
                
                bool rankChanged = _previousRanks.isNotEmpty && _previousRanks[playerName] != _currentRanks[playerName];
                Widget card = LivePlayerCard(
          key: ValueKey('live_$playerName'),
          playerName: playerName,
          playerScore: playerScore,
          rank: rank,
          indicatorKey: _indicatorKeys.putIfAbsent(playerName, () => GlobalKey<ScoreChangeIndicatorState>()),
        );

                if (rankChanged) {
                   card = card.animate(key: ValueKey('rank_change_${_currentRanks[playerName]}_$playerName'))
                       .shimmer(duration: 800.ms, color: Colors.amber.withValues(alpha: 0.5))
                       .scaleXY(begin: 1.0, end: 1.05, duration: 300.ms, curve: Curves.easeOutBack)
                       .then()
                       .scaleXY(begin: 1.05, end: 1.0, duration: 300.ms, curve: Curves.easeIn);
                } else {
                   card = card.animate(key: ValueKey('fade_in_$playerName')).fade().slideY(begin: 0.2, curve: Curves.easeOut);
                }

                return card;
              },
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}
