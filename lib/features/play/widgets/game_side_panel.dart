import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets.dart';
import '../../../engine/engine.dart';
import '../../common/game_ui.dart';
import 'who_scored.dart';

/// Standings plus the event log, newest first. A side panel on desktop and a
/// sheet on phones.
class GameSidePanel extends StatelessWidget {
  final GameSnapshot snapshot;

  /// Whether tapping a team's score in the log can change who scored.
  final bool canEdit;
  const GameSidePanel({super.key, required this.snapshot, this.canEdit = false});

  @override
  Widget build(BuildContext context) {
    final game = snapshot.game;
    final events = snapshot.log;
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
          final members = p != null && p.isTeam && snapshot.memberPoints.containsKey(p.id) ? snapshot.membersLine(p) : '';
          final subtitle = [s.detail, members].where((t) => t.isNotEmpty).join('\n');
          return ListTile(
            dense: true,
            leading: RankBadge(rank: s.rank, size: 26),
            title: Text(p?.name ?? '?', maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: subtitle.isEmpty ? null : Text(subtitle),
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
            final taggable = snapshot.creditable.containsKey(e.id);
            return ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              leading: p == null ? const Icon(Icons.circle, size: 10) : PlayerAvatar(name: p.name, color: p.color, size: 24),
              title: Text(snapshot.describe(e)),
              trailing: Text(time.format(DateTime.fromMillisecondsSinceEpoch(e.ts)), style: context.text.labelSmall),
              onTap: taggable && canEdit ? () => editWhoScored(context, snapshot, e.id) : null,
            );
          },
        ),
      const SliverToBoxAdapter(child: SizedBox(height: Space.xl)),
    ]);
  }
}
