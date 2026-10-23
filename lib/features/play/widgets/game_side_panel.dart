import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets.dart';
import '../../../engine/engine.dart';
import '../../common/game_ui.dart';

/// Standings plus the event log, newest first. A side panel on desktop and a
/// sheet on phones.
class GameSidePanel extends StatelessWidget {
  final GameSnapshot snapshot;
  const GameSidePanel({super.key, required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final game = snapshot.game;
    final events = snapshot.effective.reversed.toList();
    final time = DateFormat.Hm();
    return CustomScrollView(slivers: [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.sm),
        sliver: SliverToBoxAdapter(child: Text('Standings', style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
      ),
      SliverList.builder(
        itemCount: snapshot.standings.length,
        itemBuilder: (context, i) {
          final s = snapshot.standings[i];
          final p = game.participant(s.participantId);
          return ListTile(
            dense: true,
            leading: RankBadge(rank: s.rank, size: 26),
            title: Text(p?.name ?? '?', maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: s.detail.isEmpty ? null : Text(s.detail),
            trailing: Text(formatScore(s.score), style: scoreStyle(context, 18, color: s.out ? context.colors.onSurfaceVariant : null)),
          );
        },
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.sm),
        sliver: SliverToBoxAdapter(
          child: Text('History (${events.length})', style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        ),
      ),
      if (events.isEmpty)
        const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(Space.lg), child: Text('Nothing scored yet.')))
      else
        SliverList.builder(
          itemCount: events.length,
          itemBuilder: (context, i) {
            final e = events[i];
            final pid = e.get<String>('p');
            final p = pid == null ? null : game.participant(pid);
            return ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              leading: p == null ? const Icon(Icons.circle, size: 10) : PlayerAvatar(name: p.name, color: p.color, size: 24),
              title: Text(GameEngine.describe(game, e)),
              trailing: Text(time.format(DateTime.fromMillisecondsSinceEpoch(e.ts)), style: context.text.labelSmall),
            );
          },
        ),
      const SliverToBoxAdapter(child: SizedBox(height: Space.xl)),
    ]);
  }
}
