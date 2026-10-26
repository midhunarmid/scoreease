import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../app/di.dart';
import '../../app/router.dart';
import '../../data/local/local_store.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../engine/event_scoring.dart';
import '../../engine/meet.dart';
import 'event_data.dart';
import 'event_widgets.dart';

/// The event on a big screen: team totals and top performers, updating as
/// games end. With [announce], reveals the winning team and then the podium.
class EventTvPage extends StatefulWidget {
  final String id;
  final bool announce;

  const EventTvPage({super.key, required this.id, this.announce = false});

  @override
  State<EventTvPage> createState() => _EventTvPageState();
}

class _EventTvPageState extends State<EventTvPage> {
  final _store = getIt<LocalStore>();
  late bool _announce = widget.announce;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable().ignore();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    WakelockPlus.disable().ignore();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Theme(
        data: buildTheme(Brightness.dark),
        child: StreamBuilder<void>(
          stream: _store.meetChanges,
          builder: (context, _) => StreamBuilder<void>(
            stream: _store.gameChanges,
            builder: (context, _) {
              final meet = _store.meet(widget.id);
              return CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.escape): () => goBack(context, '/event/${widget.id}'),
                  const SingleActivator(LogicalKeyboardKey.keyA): () => setState(() => _announce = !_announce),
                },
                child: Focus(
                  autofocus: true,
                  child: Scaffold(
                    backgroundColor: Colors.black,
                    body: SafeArea(
                      child: meet == null
                          ? const ErrorState(title: 'Event not found', message: 'It may have been deleted.')
                          : _body(context, meet, loadMeetStandings(_store, meet)),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );

  Widget _body(BuildContext context, Meet meet, MeetStandings standings) => LayoutBuilder(builder: (context, c) {
        final scale = (c.maxWidth / 900).clamp(1.0, 2.4);
        final header = Row(children: [
          IconButton(tooltip: 'Exit TV mode (Esc)', onPressed: () => goBack(context, '/event/${meet.id}'), icon: const Icon(Icons.close)),
          const SizedBox(width: Space.sm),
          Text('🏆', style: TextStyle(fontSize: 24 * scale)),
          const SizedBox(width: Space.sm),
          Expanded(child: Text(meet.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.headlineMedium?.copyWith(fontSize: 26 * scale))),
          IconButton(
            tooltip: _announce ? 'Show the scoreboard (A)' : 'Announce the result (A)',
            onPressed: () => setState(() => _announce = !_announce),
            icon: Icon(_announce ? Icons.leaderboard : Icons.campaign),
          ),
        ]);
        return Padding(
          padding: EdgeInsets.all(Space.lg * scale),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            header,
            SizedBox(height: Space.lg * scale),
            Expanded(child: _announce ? _Announcement(standings: standings, scale: scale) : _Scoreboard(standings: standings, scale: scale, wide: c.maxWidth > c.maxHeight)),
          ]),
        );
      });
}

class _Scoreboard extends StatelessWidget {
  final MeetStandings standings;
  final double scale;
  final bool wide;
  const _Scoreboard({required this.standings, required this.scale, required this.wide});

  @override
  Widget build(BuildContext context) {
    final latest = standings.games.lastWhereOrNull((g) => g.counted);
    final left = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TeamTotals(standings: standings, scale: scale),
      if (latest != null) ...[
        SizedBox(height: Space.lg * scale),
        Text(
          'Latest: ${latest.game.title} · ${latest.teamPoints.isEmpty ? 'no points' : awardLine(standings.meet, latest.teamPoints)}',
          textAlign: TextAlign.center,
          style: context.text.titleMedium?.copyWith(fontSize: 18 * scale, color: Colors.white70),
        ),
      ],
    ]);
    final board = SingleChildScrollView(child: EventLeaderboard(standings: standings, limit: wide ? 8 : 5, scale: scale));
    return wide
        ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 3, child: left),
            SizedBox(width: Space.xl * scale),
            Expanded(flex: 2, child: board),
          ])
        : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [left, SizedBox(height: Space.xl * scale), Expanded(child: board)]);
  }
}

/// "And the winner is…", then the winning team, then the top three people.
class _Announcement extends StatefulWidget {
  final MeetStandings standings;
  final double scale;
  const _Announcement({required this.standings, required this.scale});

  @override
  State<_Announcement> createState() => _AnnouncementState();
}

class _AnnouncementState extends State<_Announcement> {
  int _stage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    if (_stage < 2) _timer = Timer(Duration(milliseconds: _stage == 0 ? 2200 : 3500), _next);
  }

  void _next() {
    if (!mounted || _stage >= 2) return;
    setState(() => _stage++);
    _schedule();
  }

  void _replay() {
    setState(() => _stage = 0);
    _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    final s = widget.standings;
    final result = s.resultText;
    final Widget child = switch (_stage) {
      _ when result == null => Text('No results yet', key: const ValueKey('none'), style: context.text.displaySmall),
      0 => Text(
          s.leaders.length > 1 ? 'And the result is…' : 'And the winner is…',
          key: const ValueKey(0),
          style: context.text.displaySmall?.copyWith(fontSize: 40 * scale, color: Colors.white70),
        ),
      1 => _WinnerReveal(key: const ValueKey(1), standings: s, scale: scale),
      _ => Column(key: const ValueKey(2), mainAxisSize: MainAxisSize.min, children: [
          Text(result, style: context.text.headlineMedium?.copyWith(fontSize: 30 * scale, color: context.scoreColors.gold, fontWeight: FontWeight.w800)),
          SizedBox(height: Space.lg * scale),
          Text('Top performers', style: context.text.titleLarge?.copyWith(fontSize: 22 * scale, color: Colors.white70)),
          SizedBox(height: Space.lg * scale),
          _Podium(standings: s, scale: scale),
        ]),
    };
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _stage < 2 ? _next : null,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.space): _next,
          const SingleActivator(LogicalKeyboardKey.arrowRight): _next,
          const SingleActivator(LogicalKeyboardKey.keyR): _replay,
        },
        child: Focus(
          autofocus: true,
          child: Stack(children: [
            Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutBack)), child: child),
                ),
                child: child,
              ),
            ),
            if (_stage == 2)
              Positioned(right: 0, bottom: 0, child: TextButton.icon(onPressed: _replay, icon: const Icon(Icons.replay), label: const Text('Replay (R)'))),
          ]),
        ),
      ),
    );
  }
}

class _WinnerReveal extends StatelessWidget {
  final MeetStandings standings;
  final double scale;
  const _WinnerReveal({super.key, required this.standings, required this.scale});

  @override
  Widget build(BuildContext context) {
    final leaders = standings.leaders;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (leaders.length == 1) Icon(Icons.emoji_events, size: 96 * scale, color: context.scoreColors.gold),
      Text(
        leaders.length == 1 ? standings.meet.team(leaders.first)!.name : 'It\'s a draw!',
        textAlign: TextAlign.center,
        style: context.text.displayLarge?.copyWith(
          fontSize: 88 * scale,
          fontWeight: FontWeight.w900,
          color: leaders.length == 1 ? playerColor(standings.meet.team(leaders.first)!.color) : context.scoreColors.gold,
        ),
      ),
      SizedBox(height: Space.md * scale),
      Wrap(alignment: WrapAlignment.center, spacing: Space.xl * scale, children: [
        for (final t in standings.rankedTeams)
          Text('${t.name} ${standings.teamTotals[t.id]}', style: scoreStyle(context, 32 * scale, color: playerColor(t.color))),
      ]),
    ]);
  }
}

/// 2nd, 1st, 3rd side by side, the winner tallest.
class _Podium extends StatelessWidget {
  final MeetStandings standings;
  final double scale;
  const _Podium({required this.standings, required this.scale});

  @override
  Widget build(BuildContext context) {
    final top = EventLeaderboard.ranked(standings).take(3).toList();
    if (top.isEmpty) return const SizedBox();
    final order = [if (top.length > 1) top[1], top[0], if (top.length > 2) top[2]];
    return Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
      for (final (place, p) in order)
        Padding(
          padding: EdgeInsets.symmetric(horizontal: Space.sm * scale),
          child: SizedBox(
            width: 180 * scale,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              PlayerAvatar(name: p.name, color: standings.meet.team(p.teamId)?.color ?? 0, size: 56 * scale),
              SizedBox(height: Space.xs * scale),
              Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleLarge?.copyWith(fontSize: 22 * scale, fontWeight: FontWeight.w800)),
              Text(
                '${p.points} pts · played ${p.played}',
                style: context.text.bodyMedium?.copyWith(fontSize: 14 * scale, color: Colors.white70),
              ),
              SizedBox(height: Space.sm * scale),
              Container(
                height: (place == 1 ? 140 : (place == 2 ? 100 : 70)) * scale,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: (context.scoreColors.forRank(place) ?? Colors.white24).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.md * scale)),
                  border: Border.all(color: context.scoreColors.forRank(place) ?? Colors.white24, width: 2),
                ),
                child: Text('$place', style: scoreStyle(context, 48 * scale, color: context.scoreColors.forRank(place))),
              ),
            ]),
          ),
        ),
    ]);
  }
}
