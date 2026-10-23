import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../engine/engine.dart';
import '../../engine/templates.dart';

const appBaseUrl = 'https://scoreease.armid.in';

String liveLink(String code) => '$appBaseUrl/live/$code';

/// Pulls a share code out of a pasted link or plain code.
String? parseJoinCode(String input) {
  final text = input.trim().toLowerCase();
  final fromLink = RegExp(r'/live/([a-z0-9]{4,12})').firstMatch(text);
  if (fromLink != null) return fromLink.group(1);
  final legacy = RegExp(r'[?&]id=([a-z0-9]{3,50})').firstMatch(text);
  if (legacy != null) return 'legacy:${legacy.group(1)}';
  if (RegExp(r'^[a-z0-9]{4,12}$').hasMatch(text)) return text;
  return null;
}

String timeAgo(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays < 7) return '${diff.inDays} d ago';
  return DateFormat.yMMMd().format(time);
}

String formatScore(num n) => n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(1);

class LiveBadge extends StatelessWidget {
  final bool compact;
  const LiveBadge({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final color = context.scoreColors.negative;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : Space.sm, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: Radii.smAll),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text('LIVE', style: context.text.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
      ]),
    );
  }
}

/// Medal-coloured rank number.
class RankBadge extends StatelessWidget {
  final int rank;
  final double size;
  const RankBadge({super.key, required this.rank, this.size = 28});

  @override
  Widget build(BuildContext context) {
    final medal = context.scoreColors.forRank(rank);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: medal?.withValues(alpha: 0.18) ?? context.colors.surfaceContainerHighest,
        shape: BoxShape.circle,
        border: medal == null ? null : Border.all(color: medal, width: 1.5),
      ),
      child: Text(
        '$rank',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: size * 0.45, color: medal ?? context.colors.onSurfaceVariant),
      ),
    );
  }
}

/// A row in game lists.
class GameTile extends StatelessWidget {
  final Game game;
  final VoidCallback onTap;
  final Widget? trailing;

  const GameTile({super.key, required this.game, required this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    final template = Templates.byId(game.templateId);
    final winners = game.winners.map(game.nameOf).join(' & ');
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Space.md),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: context.colors.primaryContainer, borderRadius: Radii.mdAll),
              child: Text(template.emoji, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(
                    child: Text(game.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  if (game.shareCode != null && !game.isFinished) ...[const SizedBox(width: Space.sm), const LiveBadge(compact: true)],
                ]),
                const SizedBox(height: 2),
                Text(
                  game.isFinished && winners.isNotEmpty ? '🏆 $winners' : (game.summary.isEmpty ? template.name : game.summary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                ),
              ]),
            ),
            const SizedBox(width: Space.sm),
            Text(timeAgo(game.updatedAt), style: context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant)),
            if (trailing != null) trailing!,
          ]),
        ),
      ),
    );
  }
}

/// Where a game in a list opens.
String gameRoute(Game game) => !game.isOwner && game.shareCode != null ? '/live/${game.shareCode}' : '/game/${game.id}';
