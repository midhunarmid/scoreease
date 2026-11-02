import 'package:flutter/material.dart';

import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../engine/engine.dart';
import '../../engine/event_scoring.dart';
import '../../engine/templates.dart';
import '../common/game_ui.dart';
import '../play/widgets/score_change.dart';
import 'event_data.dart';

/// Short form of a points table for headers: "3-2-1 pts".
String pointsLabel(String raw) => '${raw.replaceAll(',', '-')} pts';

/// An event's games: those being played, then those up next in the order they
/// were added, then those played, latest first.
class EventGameList extends StatelessWidget {
  final MeetStandings standings;
  final String empty;
  final ValueChanged<Game> onOpen;

  const EventGameList({super.key, required this.standings, required this.empty, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final games = standings.games;
    if (games.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.md),
        child: Text(empty, style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
      );
    }
    final sections = {
      'Playing now': games.where((g) => !g.counted && !g.upcoming),
      'Up next': games.where((g) => g.upcoming),
      'Played': games.where((g) => g.counted).toList().reversed,
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final MapEntry(key: title, value: list) in sections.entries)
        if (list.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: Space.xs, bottom: Space.xs),
            child: Text(title, style: context.text.labelLarge?.copyWith(color: context.colors.onSurfaceVariant)),
          ),
          for (final g in list)
            Padding(padding: const EdgeInsets.only(bottom: Space.sm), child: _GameRow(standings: standings, award: g, onOpen: onOpen)),
        ],
    ]);
  }
}

class _GameRow extends StatelessWidget {
  final MeetStandings standings;
  final GameAward award;
  final ValueChanged<Game> onOpen;
  const _GameRow({required this.standings, required this.award, required this.onOpen});

  /// Who a game is between: "Reds vs Blues", or how many are in it.
  String get _sides {
    final sides = award.game.sides;
    return sides.length == 2 ? '${sides[0].name} vs ${sides[1].name}' : '${sides.length} ${sides.any((p) => p.isTeam) ? 'teams' : 'players'}';
  }

  @override
  Widget build(BuildContext context) {
    final game = award.game;
    final template = Templates.byId(game.templateId);
    final String status;
    if (award.counted) {
      status = award.teamPoints.isEmpty ? 'No points' : awardLine(standings.meet, award.teamPoints);
    } else {
      status = award.upcoming ? _sides : 'In progress · ${award.snapshot.summary}';
    }
    return Card(
      child: ListTile(
        onTap: () => onOpen(game),
        leading: Text(template.emoji, style: const TextStyle(fontSize: 26)),
        title: Text(game.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        subtitle: Text(status, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: award.counted
            ? Icon(Icons.check_circle, color: context.scoreColors.positive)
            : Icon(award.upcoming ? Icons.schedule : Icons.play_circle_outline),
      ),
    );
  }
}

/// One big card per team with its event total. [scale] grows it for TV.
class TeamTotals extends StatelessWidget {
  final MeetStandings standings;
  final double scale;

  /// Makes each team's player count a button.
  final VoidCallback? onPlayers;

  const TeamTotals({super.key, required this.standings, this.scale = 1, this.onPlayers});

  @override
  Widget build(BuildContext context) {
    final leaders = standings.leaders;
    final teams = standings.meet.teams;
    // Equal-height cards, also inside scrolling lists.
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final (i, t) in teams.indexed) ...[
          if (i > 0) SizedBox(width: Space.sm * scale),
          Expanded(
            child: ScorePulse(
              score: standings.teamTotals[t.id] ?? 0,
              color: playerColor(t.color),
              borderRadius: Radii.lgAll,
              child: Container(
                padding: EdgeInsets.all(Space.md * scale),
                decoration: BoxDecoration(
                  color: playerColor(t.color).withValues(alpha: 0.14),
                  borderRadius: Radii.lgAll,
                  border: Border.all(color: leaders.contains(t.id) ? context.scoreColors.gold : Colors.transparent, width: 2),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    if (leaders.length == 1 && leaders.first == t.id) ...[
                      Icon(Icons.emoji_events, color: context.scoreColors.gold, size: 20 * scale),
                      SizedBox(width: Space.xs * scale),
                    ],
                    Flexible(
                      child: Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleMedium?.copyWith(fontSize: 18 * scale, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                  FittedBox(
                    child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${standings.teamTotals[t.id] ?? 0}', style: scoreStyle(context, 56 * scale, color: playerColor(t.color))),
                      ScoreDelta(score: standings.teamTotals[t.id] ?? 0, size: 20 * scale),
                    ]),
                  ),
                  InkWell(
                    onTap: onPlayers,
                    child: Text('${t.members.length} players', style: context.text.labelSmall?.copyWith(fontSize: 11 * scale, color: context.colors.onSurfaceVariant)),
                  ),
                ]),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

/// People by event points. Shared places for equal points and games played.
class EventLeaderboard extends StatelessWidget {
  final MeetStandings standings;
  final int? limit;
  final double scale;

  const EventLeaderboard({super.key, required this.standings, this.limit, this.scale = 1});

  /// People who have played, with their place.
  static List<(int, PersonLine)> ranked(MeetStandings standings) {
    final played = standings.people.where((p) => p.played > 0).toList();
    final out = <(int, PersonLine)>[];
    for (final (i, p) in played.indexed) {
      final prev = i > 0 ? played[i - 1] : null;
      final same = prev != null && prev.points == p.points && prev.played == p.played && prev.wins == p.wins;
      out.add((same ? out.last.$1 : i + 1, p));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final rows = ranked(standings);
    if (rows.isEmpty) {
      return const EmptyState(icon: Icons.leaderboard_outlined, title: 'No points yet', message: 'People show up here once a game ends.');
    }
    final shown = limit == null ? rows : rows.take(limit!).toList();
    final anyScored = rows.any((r) => r.$2.scored > 0);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final (place, p) in shown)
        Padding(
          padding: EdgeInsets.only(bottom: Space.xs * scale),
          child: Row(children: [
            RankBadge(rank: place, size: 28 * scale),
            SizedBox(width: Space.sm * scale),
            PlayerAvatar(name: p.name, color: standings.meet.team(p.teamId)?.color ?? 0, size: 30 * scale),
            SizedBox(width: Space.sm * scale),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall?.copyWith(fontSize: 15 * scale, fontWeight: FontWeight.w700)),
                Text(
                  [
                    standings.meet.team(p.teamId)?.name ?? 'No team',
                    'played ${p.played}',
                    if (p.wins > 0) '${p.wins} win${p.wins == 1 ? '' : 's'}',
                    if (anyScored && p.scored > 0) 'scored ${p.scored}',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(fontSize: 12 * scale, color: context.colors.onSurfaceVariant),
                ),
              ]),
            ),
            Text('${p.points}', style: scoreStyle(context, 24 * scale)),
            Text(' pts', style: context.text.labelSmall?.copyWith(fontSize: 11 * scale, color: context.colors.onSurfaceVariant)),
          ]),
        ),
      if (shown.length < rows.length)
        Text('+ ${rows.length - shown.length} more', style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
    ]);
  }
}
