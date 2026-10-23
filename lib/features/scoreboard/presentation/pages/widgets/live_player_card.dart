import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:scoreease/core/utils/avatar_color.dart';
import 'package:scoreease/core/utils/theme.dart';
import 'package:scoreease/features/scoreboard/presentation/pages/widgets/score_change_indicator.dart';

/// A player's tile on the live (read-only) scoreboard.
class LivePlayerCard extends StatelessWidget {
  final String playerName;
  final String playerScore;
  final int rank;
  final GlobalKey<ScoreChangeIndicatorState> indicatorKey;

  const LivePlayerCard({
    Key? key,
    required this.playerName,
    required this.playerScore,
    required this.rank,
    required this.indicatorKey,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final avatarColor = avatarColorFor(playerName);
    final firstLetter = avatarInitial(playerName);
    final isLeader = rank == 1;

    return ScoreChangeIndicator(
        key: indicatorKey,
        child: Container(
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
                  _buildRankBadge(context),
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
                )
                    .animate(key: ValueKey(playerScore))
                    .fade()
                    .scaleXY(begin: 1.5, end: 1.0, duration: 400.ms, curve: Curves.easeOutBack),
              ),
            ],
          ),
        ));
  }

  Widget _buildRankBadge(BuildContext context) {
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
}
