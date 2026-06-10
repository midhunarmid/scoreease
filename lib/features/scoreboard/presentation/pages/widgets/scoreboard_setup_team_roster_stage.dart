import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:scoreease/core/utils/theme.dart';
import 'package:scoreease/core/utils/widget_helper.dart';
import 'package:scoreease/core/widgets/animated_container.dart';

class ScoreboardSetupTeamRosterStage extends StatefulWidget {
  final Map<String, List<String>> teams;
  final ValueChanged<String> onAddTeam;
  final ValueChanged<String> onRemoveTeam;
  final void Function(String team, String player) onAddPlayer;
  final void Function(String team, String player) onRemovePlayer;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  const ScoreboardSetupTeamRosterStage({
    Key? key,
    required this.teams,
    required this.onAddTeam,
    required this.onRemoveTeam,
    required this.onAddPlayer,
    required this.onRemovePlayer,
    required this.onNext,
    required this.onPrevious,
  }) : super(key: key);

  @override
  State<ScoreboardSetupTeamRosterStage> createState() =>
      _ScoreboardSetupTeamRosterStageState();
}

class _ScoreboardSetupTeamRosterStageState
    extends State<ScoreboardSetupTeamRosterStage> {
  final TextEditingController _teamTextController = TextEditingController();
  late FocusNode _teamFocusNode;
  final Map<String, TextEditingController> _playerControllers = {};
  final Map<String, FocusNode> _playerFocusNodes = {};

  @override
  void initState() {
    super.initState();
    _teamFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _teamTextController.dispose();
    _teamFocusNode.dispose();
    for (var controller in _playerControllers.values) {
      controller.dispose();
    }
    for (var node in _playerFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: 8.h),
        getTextInputWidget(
          context: context,
          label: 'Add Team',
          hint: 'e.g. Red Team',
          controller: _teamTextController,
          keyboardType: TextInputType.name,
          textInputAction: TextInputAction.go,
          prefixIcon: const Icon(Icons.group_add_outlined),
          inputFormatters: [
            LengthLimitingTextInputFormatter(20),
          ],
          icon: Icons.add,
          focusNode: _teamFocusNode,
          onPressed: () {
            final newTeam = _teamTextController.text.trim();
            if (newTeam.isNotEmpty) {
              if (widget.teams.containsKey(newTeam)) {
                showSingleButtonAlertDialog(
                  context: context,
                  title: 'Duplicate Team',
                  message: 'Team "$newTeam" is already added!',
                );
              } else {
                HapticFeedback.lightImpact();
                widget.onAddTeam(newTeam);
                _teamTextController.clear();
              }
            }
            _teamFocusNode.requestFocus();
          },
        ),
        SizedBox(height: 16.h),
        if (widget.teams.isEmpty)
          Column(
            children: [
              Icon(Icons.sports_kabaddi,
                      size: 48.sp,
                      color: appColors.textColor.withValues(alpha: 0.3))
                  .animate(
                      onPlay: (controller) => controller.repeat(reverse: true))
                  .slideY(
                      begin: -0.2,
                      end: 0.2,
                      duration: 1.seconds,
                      curve: Curves.easeInOutSine),
              SizedBox(height: 16.h),
              Text(
                "No teams added yet. Add at least 2 teams to continue.",
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: appColors.textColor.withValues(alpha: 0.6),
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          )
        else
          ...widget.teams.entries.map((entry) => _buildTeamCard(entry.key, entry.value)).toList(),
        SizedBox(height: 16.h),
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: AnimatedClickableTextContainer(
                  title: '⟵ Back',
                  iconSrc: '',
                  isActive: false,
                  bgColor: appColors.inputBgFill,
                  bgColorHover: appColors.sideMenuHighlight,
                  textColor: appColors.textColor,
                  textColorHover: Theme.of(context).brightness == Brightness.light
                      ? Colors.white
                      : Colors.black,
                  press: () {
                    HapticFeedback.lightImpact();
                    widget.onPrevious();
                  },
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: AnimatedClickableTextContainer(
                  title: 'Next: Set Access ➔',
                  iconSrc: '',
                  isActive: false,
                  bgColor: appColors.pleasantButtonBg,
                  bgColorHover: appColors.pleasantButtonBgHover,
                  press: () {
                    HapticFeedback.lightImpact();
                    widget.onNext();
                  },
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16.h),
      ],
    );
  }

  Widget _buildTeamCard(String teamName, List<String> players) {
    if (!_playerControllers.containsKey(teamName)) {
      _playerControllers[teamName] = TextEditingController();
      _playerFocusNodes[teamName] = FocusNode();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: appColors.tileBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: appColors.tileBgColorHover, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: appColors.primaryColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
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
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    widget.onRemoveTeam(teamName);
                  },
                  tooltip: "Remove Team",
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                getTextInputWidget(
                  context: context,
                  label: 'Add Player to $teamName',
                  hint: 'Player Name',
                  controller: _playerControllers[teamName]!,
                  keyboardType: TextInputType.name,
                  textInputAction: TextInputAction.go,
                  prefixIcon: const Icon(Icons.person_add_alt_1_outlined),
                  icon: Icons.add,
                  focusNode: _playerFocusNodes[teamName],
                  onPressed: () {
                    final newPlayer = _playerControllers[teamName]!.text.trim();
                    if (newPlayer.isNotEmpty) {
                      bool playerExists = widget.teams.values
                          .expand((p) => p)
                          .contains(newPlayer);
                      if (playerExists) {
                        showSingleButtonAlertDialog(
                          context: context,
                          title: 'Duplicate Player',
                          message: 'Player "$newPlayer" is already in a team!',
                        );
                      } else {
                        HapticFeedback.lightImpact();
                        widget.onAddPlayer(teamName, newPlayer);
                        _playerControllers[teamName]!.clear();
                      }
                    }
                    _playerFocusNodes[teamName]!.requestFocus();
                  },
                ),
                const SizedBox(height: 12),
                if (players.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      "No players in this team yet.",
                      style: TextStyle(
                        color: appColors.textColor.withValues(alpha: 0.5),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: players.map((player) {
                      return Chip(
                        label: Text(player),
                        deleteIcon: const Icon(Icons.cancel, size: 18),
                        onDeleted: () {
                          HapticFeedback.lightImpact();
                          widget.onRemovePlayer(teamName, player);
                        },
                        backgroundColor: appColors.screenBg,
                        side: BorderSide(color: appColors.disableBgColor),
                      ).animate().scale(duration: 200.ms, curve: Curves.easeOut);
                    }).toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fade().slideY(begin: 0.1);
  }
}
