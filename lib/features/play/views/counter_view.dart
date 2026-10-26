import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../design/responsive.dart';
import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets.dart';
import '../../../engine/counter_engine.dart';
import '../../../engine/engine.dart';
import '../../common/game_ui.dart';
import '../play_cubit.dart';
import '../widgets/score_change.dart';
import '../widgets/who_scored.dart';

class CounterView extends StatelessWidget {
  final GameSnapshot snapshot;
  final bool enabled;

  const CounterView({super.key, required this.snapshot, required this.enabled});

  @override
  Widget build(BuildContext context) {
    final game = snapshot.game;
    final state = snapshot.stateAs<CounterState>();
    final rule = counterRule(game);
    final hasClock = (game.intSetting('periods') ?? 0) > 0;
    final ranks = {for (final s in snapshot.standings) s.participantId: s.rank};
    final st = snapshot.standings;
    final leader = st.length > 1 && st[1].rank > 1 ? st.first.participantId : null;
    final gamePoint = snapshot.finished ? const <String>{} : CounterEngine.onGamePoint(state, game);

    final header = <Widget>[
      if (hasClock) MatchClock(game: game, state: state, enabled: enabled),
      if (rule != null)
        Padding(
          padding: const EdgeInsets.only(top: Space.sm),
          child: Text(
            rule,
            textAlign: TextAlign.center,
            style: context.text.labelLarge?.copyWith(color: context.colors.onSurfaceVariant),
          ),
        ),
    ];

    if (game.participants.length == 2) {
      return Column(children: [
        ...header,
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            final horizontal = c.maxWidth > c.maxHeight * 0.9;
            final sides = [
              for (final p in game.participants)
                Expanded(child: _BigSide(
                    game: game,
                    participant: p,
                    score: state.scores[p.id] ?? 0,
                    leading: p.id == leader,
                    gamePoint: gamePoint.contains(p.id),
                    enabled: enabled,
                  )),
            ];
            return Padding(
              padding: const EdgeInsets.all(Space.sm),
              child: horizontal
                  ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [sides[0], const SizedBox(width: Space.sm), sides[1]])
                  : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [sides[0], const SizedBox(height: Space.sm), sides[1]]),
            );
          }),
        ),
      ]);
    }

    return CustomScrollView(slivers: [
      SliverToBoxAdapter(child: Column(children: header)),
      SliverPadding(
        padding: EdgeInsets.all(context.isCompact ? Space.sm : Space.lg),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: context.isCompact ? 240 : 280,
            mainAxisExtent: 200,
            mainAxisSpacing: Space.sm,
            crossAxisSpacing: Space.sm,
          ),
          delegate: SliverChildBuilderDelegate(
            childCount: game.participants.length,
            (context, i) {
              final p = game.participants[i];
              return _PlayerTile(
                game: game,
                participant: p,
                score: state.scores[p.id] ?? 0,
                rank: ranks[p.id] ?? 0,
                gamePoint: gamePoint.contains(p.id),
                enabled: enabled,
                index: i,
              );
            },
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: Space.xxl)),
    ]);
  }
}

/// "First to 11 · win by 2", "301 down to 0", or null with no end rule.
String? counterRule(Game game) {
  if (CounterEngine.isCountdown(game)) return '${CounterEngine.startOf(game)} down to 0';
  final target = game.intSetting('target');
  if (target == null) return null;
  if (game.flag('lowWins')) return 'Ends at $target';
  final winBy = CounterEngine.winByOf(game);
  return 'First to $target${winBy > 1 ? ' · win by $winBy' : ''}';
}

/// Button label for scoring [v]: a countdown takes points off what is left.
String _stepLabel(Game game, int v) => signed(CounterEngine.isCountdown(game) ? -v : v).replaceFirst('-', '−');

/// Opens the keypad to score any amount, take it back, or set the score.
/// [add] records points the same way the step buttons do.
Future<void> _scoreAmount(BuildContext context, Game game, Participant p, int current, void Function(int) add) async {
  final cubit = context.read<PlayCubit>();
  final result = await showAdaptiveSheet<(_AmountAction, int)>(
    context,
    builder: (_) => _AmountSheet(game: game, participant: p, current: current),
  );
  if (result == null) return;
  final (action, value) = result;
  switch (action) {
    case _AmountAction.add:
      add(value);
    case _AmountAction.takeBack:
      add(-value);
    case _AmountAction.set:
      if (value != current) await cubit.add(CounterEngine.set, {'p': p.id, 'v': value});
  }
}

enum _AmountAction { add, takeBack, set }

class _AmountSheet extends StatefulWidget {
  final Game game;
  final Participant participant;
  final int current;
  const _AmountSheet({required this.game, required this.participant, required this.current});

  @override
  State<_AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends State<_AmountSheet> {
  String _digits = '';

  int? get _value => int.tryParse(_digits);

  void _type(String key) => setState(() {
        if (key == '⌫') {
          if (_digits.isNotEmpty) _digits = _digits.substring(0, _digits.length - 1);
        } else if (_digits.length < 6) {
          _digits = _digits == '0' ? key : _digits + key;
        }
      });

  void _done(_AmountAction action) {
    final v = _value;
    if (v == null || (v == 0 && action != _AmountAction.set)) return;
    Navigator.pop(context, (action, v));
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final ch = e.character;
    if (ch != null && RegExp(r'^[0-9]$').hasMatch(ch)) {
      _type(ch);
    } else if (e.logicalKey == LogicalKeyboardKey.backspace) {
      _type('⌫');
    } else if (e.logicalKey == LogicalKeyboardKey.enter || e.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _done(_AmountAction.add);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final v = _value;
    final countdown = CounterEngine.isCountdown(game);
    final ready = v != null && v > 0;
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              PlayerAvatar(name: widget.participant.name, color: widget.participant.color, size: 28),
              const SizedBox(width: Space.sm),
              Expanded(child: Text(widget.participant.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleLarge)),
              Text('${countdown ? 'Left' : 'Now'} ${widget.current}', style: context.text.labelLarge?.copyWith(color: context.colors.onSurfaceVariant)),
            ]),
            const SizedBox(height: Space.md),
            Text(_digits.isEmpty ? '0' : _digits, textAlign: TextAlign.center, style: scoreStyle(context, 56, color: _digits.isEmpty ? context.colors.outline : null)),
            const SizedBox(height: Space.md),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: Space.sm,
              crossAxisSpacing: Space.sm,
              childAspectRatio: 2,
              children: [
                for (final k in ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'])
                  k.isEmpty
                      ? const SizedBox()
                      : FilledButton.tonal(
                          onPressed: () => _type(k),
                          style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                          child: k == '⌫' ? const Icon(Icons.backspace_outlined, semanticLabel: 'Delete') : Text(k, style: scoreStyle(context, 22)),
                        ),
              ],
            ),
            const SizedBox(height: Space.lg),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: ready ? () => _done(_AmountAction.takeBack) : null,
                  child: Text(ready ? _stepLabel(game, -v) : 'Take back'),
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: ready ? () => _done(_AmountAction.add) : null,
                  child: Text(ready ? _stepLabel(game, v) : 'Score'),
                ),
              ),
            ]),
            const SizedBox(height: Space.xs),
            TextButton(
              onPressed: v == null ? null : () => _done(_AmountAction.set),
              child: Text(v == null ? (countdown ? 'Set what is left' : 'Set score') : (countdown ? 'Set left to $v' : 'Set score to $v')),
            ),
          ]),
        ),
      ),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  final Game game;
  final Participant participant;
  final int score;
  final int rank;
  final bool gamePoint;
  final bool enabled;
  final int index;

  const _PlayerTile({
    required this.game,
    required this.participant,
    required this.score,
    required this.rank,
    required this.gamePoint,
    required this.enabled,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PlayCubit>();
    final steps = CounterEngine.stepsOf(game);
    final color = playerColor(participant.color);

    return WhoScored(
      team: participant,
      builder: (context, score, strip) {
        void add(int v) => score(() => cubit.addPoints(participant.id, v), v);
        return _tile(context, steps, color, add, strip);
      },
    );
  }

  Widget _tile(BuildContext context, List<int> steps, Color color, void Function(int) add, Widget? strip) {
    return Card(
      shape: gamePoint ? RoundedRectangleBorder(borderRadius: Radii.mdAll, side: BorderSide(color: context.scoreColors.gold, width: 2)) : null,
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(height: 4, color: color),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.sm, 0),
          child: Row(children: [
            PlayerAvatar(name: participant.name, color: participant.color, size: 28),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Text(participant.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            ),
            if (gamePoint) ...[const GamePointBadge(), const SizedBox(width: Space.xs)],
            if (rank > 0) RankBadge(rank: rank, size: 24),
          ]),
        ),
        Expanded(
          child: Stack(fit: StackFit.expand, children: [
            Semantics(
              label: '${participant.name}: $score points. Tap for ${_stepLabel(game, steps.first)}.',
              button: enabled,
              child: InkWell(
                onTap: enabled ? () => add(steps.first) : null,
                onLongPress: enabled ? () => _scoreAmount(context, game, participant, score, add) : null,
                child: Center(child: _AnimatedScore(score: score, size: 52)),
              ),
            ),
            Positioned(top: Space.xs, right: Space.md, child: ScoreDelta(score: score, size: 20)),
            if (strip != null) Positioned(left: Space.sm, right: Space.sm, bottom: Space.xs, child: strip),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.sm, 0, Space.sm, Space.sm),
          child: Row(children: [
            _StepButton(label: _stepLabel(game, -steps.first), onPressed: enabled ? () => add(-steps.first) : null, tonal: false),
            for (final s in steps) ...[const SizedBox(width: Space.xs), _StepButton(label: _stepLabel(game, s), onPressed: enabled ? () => add(s) : null)],
            if (index < 9) ...[
              const SizedBox(width: Space.xs),
              Tooltip(message: 'Key ${index + 1}', child: Text('${index + 1}', style: context.text.labelSmall?.copyWith(color: context.colors.outline))),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _StepButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool tonal;
  const _StepButton({required this.label, this.onPressed, this.tonal = true});

  @override
  Widget build(BuildContext context) => Expanded(
        child: tonal
            ? FilledButton.tonal(onPressed: onPressed, style: FilledButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 44)), child: Text(label))
            : OutlinedButton(onPressed: onPressed, style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 44)), child: Text(label)),
      );
}

/// Half of the screen for one side in a two-player game: tap anywhere to score.
class _BigSide extends StatelessWidget {
  final Game game;
  final Participant participant;
  final int score;
  final bool leading;
  final bool gamePoint;
  final bool enabled;

  const _BigSide({
    required this.game,
    required this.participant,
    required this.score,
    required this.leading,
    required this.gamePoint,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PlayCubit>();
    final steps = CounterEngine.stepsOf(game);
    final color = playerColor(participant.color);

    return WhoScored(
      team: participant,
      builder: (context, score, strip) {
        void add(int v) => score(() => cubit.addPoints(participant.id, v), v);
        return _side(context, steps, color, add, strip);
      },
    );
  }

  Widget _side(BuildContext context, List<int> steps, Color color, void Function(int) add, Widget? strip) {
    return Material(
      color: color.withValues(alpha: context.theme.brightness == Brightness.dark ? 0.22 : 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: Radii.lgAll,
        side: BorderSide(color: gamePoint ? context.scoreColors.gold : (leading ? color : Colors.transparent), width: gamePoint ? 3 : 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: GestureDetector(
        // Swipe up to score, down to take back: quick with one thumb.
        onVerticalDragEnd: enabled
            ? (d) {
                final v = d.primaryVelocity ?? 0;
                if (v.abs() > 250) add(v < 0 ? steps.first : -steps.first);
              }
            : null,
        child: InkWell(
          onTap: enabled ? () => add(steps.first) : null,
          onLongPress: enabled ? () => _scoreAmount(context, game, participant, score, add) : null,
          child: Padding(
            padding: const EdgeInsets.all(Space.md),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                PlayerAvatar(name: participant.name, color: participant.color, size: 28),
                const SizedBox(width: Space.sm),
                Flexible(child: Text(participant.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleLarge)),
                if (gamePoint) ...[const SizedBox(width: Space.sm), const GamePointBadge()],
              ]),
              Expanded(
                child: Stack(fit: StackFit.expand, children: [
                  FittedBox(
                    child: Padding(padding: const EdgeInsets.all(Space.sm), child: _AnimatedScore(score: score, size: 120, color: color)),
                  ),
                  Positioned(top: 0, right: 0, child: ScoreDelta(score: score, size: 28)),
                ]),
              ),
              Row(children: [
                _StepButton(label: _stepLabel(game, -steps.first), onPressed: enabled ? () => add(-steps.first) : null, tonal: false),
                for (final s in steps.skip(1)) ...[const SizedBox(width: Space.sm), _StepButton(label: _stepLabel(game, s), onPressed: enabled ? () => add(s) : null)],
              ]),
              const SizedBox(height: Space.xs),
              strip ??
                  Text(
                    enabled ? 'Tap or swipe ↑ ${_stepLabel(game, steps.first)} · swipe ↓ ${_stepLabel(game, -steps.first)} · hold for more' : '',
                    style: context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant),
                  ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _AnimatedScore extends StatelessWidget {
  final int score;
  final double size;
  final Color? color;
  const _AnimatedScore({required this.score, required this.size, this.color});

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: motionFast,
        transitionBuilder: (child, anim) => ScaleTransition(scale: Tween(begin: 0.8, end: 1.0).animate(anim), child: FadeTransition(opacity: anim, child: child)),
        child: Text('$score', key: ValueKey(score), style: scoreStyle(context, size, color: color)),
      );
}

/// Match clock with periods. Ticks locally; start/pause are events so every
/// device shows the same time.
class MatchClock extends StatefulWidget {
  final Game game;
  final CounterState state;
  final bool enabled;
  const MatchClock({super.key, required this.game, required this.state, required this.enabled});

  @override
  State<MatchClock> createState() => MatchClockState();
}

class MatchClockState extends State<MatchClock> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (widget.state.clockRunning && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _fmt(int ms) {
    final s = ms ~/ 1000;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PlayCubit>();
    final periods = widget.game.intSetting('periods') ?? 1;
    final minutes = widget.game.intSetting('periodMinutes') ?? 0;
    final elapsed = widget.state.elapsedMs(DateTime.now().millisecondsSinceEpoch);
    final overtime = minutes > 0 && elapsed >= minutes * 60000;
    final breakdown = periodLine(widget.game, widget.state);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
            Text('Period ${widget.state.period}/$periods', style: context.text.labelLarge),
            const Spacer(),
            Text(_fmt(elapsed), style: scoreStyle(context, 28, color: overtime ? context.scoreColors.negative : null)),
            if (minutes > 0) Text(' / $minutes:00', style: context.text.labelMedium?.copyWith(color: context.colors.onSurfaceVariant)),
            const Spacer(),
            if (widget.enabled) ...[
              IconButton.filledTonal(
                tooltip: widget.state.clockRunning ? 'Pause clock' : 'Start clock',
                onPressed: () => cubit.add(CounterEngine.clock, {'run': !widget.state.clockRunning}),
                icon: Icon(widget.state.clockRunning ? Icons.pause : Icons.play_arrow),
              ),
              IconButton(
                tooltip: 'Next period',
                onPressed: widget.state.period < periods
                    ? () {
                        HapticFeedback.mediumImpact();
                        cubit.add(CounterEngine.nextPeriod);
                      }
                    : null,
                icon: const Icon(Icons.skip_next),
              ),
            ] else
              Icon(widget.state.clockRunning ? Icons.timer_outlined : Icons.pause_circle_outline, color: context.colors.onSurfaceVariant),
            ]),
            if (breakdown != null)
              Padding(
                padding: const EdgeInsets.only(top: Space.xs),
                child: Text(breakdown, textAlign: TextAlign.center, style: context.text.labelMedium?.copyWith(color: context.colors.onSurfaceVariant)),
              ),
          ]),
        ),
      ),
    );
  }
}

/// "P1 12–8 · P2 3–10" for two sides, "P1 Ann 5, Bob 3 · ..." for more.
/// Null until a period has finished.
String? periodLine(Game game, CounterState state) {
  if (state.periodScores.isEmpty) return null;
  final periods = state.periodPoints(game);
  final ids = game.participants.map((p) => p.id).toList();
  return [
    for (var i = 0; i < periods.length; i++)
      ids.length == 2
          ? 'P${i + 1} ${periods[i][ids[0]]}–${periods[i][ids[1]]}'
          : 'P${i + 1} ${game.participants.map((p) => '${p.name} ${periods[i][p.id]}').join(', ')}',
  ].join(' · ');
}
