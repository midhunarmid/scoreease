import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:scoreease/core/utils/avatar_color.dart';
import 'package:scoreease/core/utils/theme.dart';
import 'package:scoreease/features/scoreboard/presentation/pages/widgets/score_change_indicator.dart';

/// A player's tile on the scorer screen, with -1 / +1 buttons. Tapping the
/// score opens [onEditScore] to set an exact value.
class PlayerScoreCard extends StatelessWidget {
  final String playerName;
  final String playerScore;
  final GlobalKey<ScoreChangeIndicatorState> indicatorKey;
  final ValueChanged<int> onChangeScore;
  final VoidCallback onEditScore;

  const PlayerScoreCard({
    Key? key,
    required this.playerName,
    required this.playerScore,
    required this.indicatorKey,
    required this.onChangeScore,
    required this.onEditScore,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ScoreChangeIndicator(
        key: indicatorKey,
        child: Container(
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
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: avatarColorFor(playerName),
                    child: Text(
                      avatarInitial(playerName),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      playerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 18.sp,
                              ),
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: onEditScore,
                child: Text(
                  playerScore,
                  key: ValueKey(playerScore),
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontSize: 48.sp,
                        fontWeight: FontWeight.w900,
                        color: appColors.primaryColor,
                      ),
                ).animate(key: ValueKey(playerScore)).scaleXY(
                    begin: 1.5,
                    end: 1.0,
                    duration: 250.ms,
                    curve: Curves.easeOutBack),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onChangeScore(-1);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color:
                              appColors.negativeButtonBg.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: appColors.negativeButtonBg, width: 2),
                        ),
                        child: Icon(Icons.remove,
                            color: appColors.negativeButtonBg, size: 32),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        onChangeScore(1);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: appColors.pleasantButtonBg,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: appColors.pleasantButtonBg
                                  .withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.add,
                            color: Colors.white, size: 32),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        )).animate().fade().slideY(begin: 0.2, curve: Curves.easeOut);
  }
}
