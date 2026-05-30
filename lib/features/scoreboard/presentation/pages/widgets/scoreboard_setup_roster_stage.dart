import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:scoreease/core/utils/message_generator.dart';
import 'package:scoreease/core/utils/theme.dart';
import 'package:scoreease/core/utils/widget_helper.dart';
import 'package:scoreease/core/widgets/animated_container.dart';

class ScoreboardSetupRosterStage extends StatefulWidget {
  final List<String> players;
  final ValueChanged<String> onAddPlayer;
  final ValueChanged<String> onRemovePlayer;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  const ScoreboardSetupRosterStage({
    Key? key,
    required this.players,
    required this.onAddPlayer,
    required this.onRemovePlayer,
    required this.onNext,
    required this.onPrevious,
  }) : super(key: key);

  @override
  State<ScoreboardSetupRosterStage> createState() => _ScoreboardSetupRosterStageState();
}

class _ScoreboardSetupRosterStageState extends State<ScoreboardSetupRosterStage> {
  final TextEditingController _scoreboardPlayerTextController = TextEditingController();
  late FocusNode _playerNameAddFocuNode;

  @override
  void initState() {
    super.initState();
    _playerNameAddFocuNode = FocusNode();
  }

  @override
  void dispose() {
    _scoreboardPlayerTextController.dispose();
    _playerNameAddFocuNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 8.h),
        getTextInputWidget(
          context: context,
          label: MessageGenerator.getLabel('player name'),
          hint: MessageGenerator.getLabel('Messi'),
          controller: _scoreboardPlayerTextController,
          keyboardType: TextInputType.name,
          textInputAction: TextInputAction.go,
          prefixIcon: const Icon(Icons.person_add_alt_1_outlined),
          inputFormatters: [
            LengthLimitingTextInputFormatter(20),
          ],
          icon: Icons.add,
          focusNode: _playerNameAddFocuNode,
          onPressed: () {
            final newPlayer = _scoreboardPlayerTextController.text.trim();
            if (newPlayer.isNotEmpty) {
              if (widget.players.contains(newPlayer)) {
                showSingleButtonAlertDialog(
                  context: context,
                  title: 'Duplicate Player',
                  message: 'Player "$newPlayer" is already on the roster!',
                );
              } else {
                HapticFeedback.lightImpact();
                widget.onAddPlayer(newPlayer);
                _scoreboardPlayerTextController.clear();
              }
            }
            _playerNameAddFocuNode.requestFocus();
          },
        ),
        SizedBox(height: 8.h),
        widget.players.isNotEmpty
            ? Wrap(
                spacing: 12.0,
                runSpacing: 12.0,
                alignment: WrapAlignment.center,
                children: widget.players.map((player) {
                  return Container(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: appColors.tileBgColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: appColors.tileBgColorHover, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sports_esports, color: appColors.primaryColor, size: 16.sp),
                        SizedBox(width: 8.w),
                        Flexible(
                          child: Text(
                            player,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: appColors.textColor,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            widget.onRemovePlayer(player);
                          },
                          child: Icon(Icons.cancel, color: Colors.red.shade400, size: 18.sp),
                        ),
                      ],
                    ),
                  ).animate().scale(duration: 200.ms, curve: Curves.easeOutBack);
                }).toList(),
              )
            : Column(
                children: [
                  Icon(Icons.sports_soccer, size: 48.sp, color: appColors.textColor.withValues(alpha: 0.3))
                      .animate(onPlay: (controller) => controller.repeat(reverse: true))
                      .slideY(begin: -0.2, end: 0.2, duration: 1.seconds, curve: Curves.easeInOutSine),
                  SizedBox(height: 16.h),
                  Text(
                    MessageGenerator.getMessage('scoreboard-setup-players-empty-message'),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: appColors.textColor.withValues(alpha: 0.6),
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
        SizedBox(height: 8.h),
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
                  textColorHover: Theme.of(context).brightness == Brightness.light ? Colors.white : Colors.black,
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
}
