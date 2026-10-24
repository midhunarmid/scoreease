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
import '../widgets/who_scored.dart';

class CounterView extends StatelessWidget {
  final GameSnapshot snapshot;
  final bool enabled;

  const CounterView({super.key, required this.snapshot, required this.enabled});

  @override
  Widget build(BuildContext context) {
    final game = snapshot.game;
    final state = snapshot.stateAs<CounterState>();
    final target = game.intSetting('target');
    final hasClock = (game.intSetting('periods') ?? 0) > 0;
    final ranks = {for (final s in snapshot.standings) s.participantId: s.rank};
    final st = snapshot.standings;
    final leader = st.length > 1 && st[1].rank > 1 ? st.first.participantId : null;

    final header = <Widget>[
      if (hasClock) MatchClock(game: game, state: state, enabled: enabled),
      if (target != null)
        Padding(
          padding: const EdgeInsets.only(top: Space.sm),
          child: Text(
            '${game.flag('lowWins') ? 'Ends' : 'First'} at $target',
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
                Expanded(child: _BigSide(game: game, participant: p, score: state.scores[p.id] ?? 0, leading: p.id == leader, enabled: enabled)),
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
              return _PlayerTile(game: game, participant: p, score: state.scores[p.id] ?? 0, rank: ranks[p.id] ?? 0, enabled: enabled, index: i);
            },
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: Space.xxl)),
    ]);
  }
}

Future<void> _setExact(BuildContext context, Participant p, int current) async {
  final text = await promptText(
    context,
    title: 'Set ${p.name}\'s score',
    initial: '$current',
    confirmLabel: 'Set',
    keyboardType: const TextInputType.numberWithOptions(signed: true),
    validator: (v) => int.tryParse(v.trim()) == null ? 'Enter a whole number' : null,
  );
  final value = text == null ? null : int.tryParse(text.trim());
  if (value != null && value != current && context.mounted) {
    context.read<PlayCubit>().add(CounterEngine.set, {'p': p.id, 'v': value});
  }
}

class _PlayerTile extends StatelessWidget {
  final Game game;
  final Participant participant;
  final int score;
  final int rank;
  final bool enabled;
  final int index;

  const _PlayerTile({required this.game, required this.participant, required this.score, required this.rank, required this.enabled, required this.index});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PlayCubit>();
    final steps = CounterEngine.stepsOf(game);
    final color = playerColor(participant.color);

    return WhoScored(
      team: participant,
      builder: (context, score, strip) {
        void add(int v) => score(() => cubit.add(CounterEngine.add, {'p': participant.id, 'v': v}), v);
        return _tile(context, steps, color, add, strip);
      },
    );
  }

  Widget _tile(BuildContext context, List<int> steps, Color color, void Function(int) add, Widget? strip) {
    return Card(
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
            if (rank > 0) RankBadge(rank: rank, size: 24),
          ]),
        ),
        Expanded(
          child: Stack(fit: StackFit.expand, children: [
            Semantics(
              label: '${participant.name}: $score points. Tap to add ${steps.first}.',
              button: enabled,
              child: InkWell(
                onTap: enabled ? () => add(steps.first) : null,
                onLongPress: enabled ? () => _setExact(context, participant, score) : null,
                child: Center(child: _AnimatedScore(score: score, size: 52)),
              ),
            ),
            if (strip != null) Positioned(left: Space.sm, right: Space.sm, bottom: Space.xs, child: strip),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.sm, 0, Space.sm, Space.sm),
          child: Row(children: [
            _StepButton(label: '−${steps.first}', onPressed: enabled ? () => add(-steps.first) : null, tonal: false),
            for (final s in steps) ...[const SizedBox(width: Space.xs), _StepButton(label: '+$s', onPressed: enabled ? () => add(s) : null)],
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
  final bool enabled;

  const _BigSide({required this.game, required this.participant, required this.score, required this.leading, required this.enabled});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PlayCubit>();
    final steps = CounterEngine.stepsOf(game);
    final color = playerColor(participant.color);

    return WhoScored(
      team: participant,
      builder: (context, score, strip) {
        void add(int v) => score(() => cubit.add(CounterEngine.add, {'p': participant.id, 'v': v}), v);
        return _side(context, steps, color, add, strip);
      },
    );
  }

  Widget _side(BuildContext context, List<int> steps, Color color, void Function(int) add, Widget? strip) {
    return Material(
      color: color.withValues(alpha: context.theme.brightness == Brightness.dark ? 0.22 : 0.12),
      shape: RoundedRectangleBorder(borderRadius: Radii.lgAll, side: BorderSide(color: leading ? color : Colors.transparent, width: 2)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? () => add(steps.first) : null,
        onLongPress: enabled ? () => _setExact(context, participant, score) : null,
        child: Padding(
          padding: const EdgeInsets.all(Space.md),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              PlayerAvatar(name: participant.name, color: participant.color, size: 28),
              const SizedBox(width: Space.sm),
              Flexible(child: Text(participant.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleLarge)),
            ]),
            Expanded(
              child: FittedBox(
                child: Padding(padding: const EdgeInsets.all(Space.sm), child: _AnimatedScore(score: score, size: 120, color: color)),
              ),
            ),
            Row(children: [
              _StepButton(label: '−${steps.first}', onPressed: enabled ? () => add(-steps.first) : null, tonal: false),
              for (final s in steps.skip(1)) ...[const SizedBox(width: Space.sm), _StepButton(label: '+$s', onPressed: enabled ? () => add(s) : null)],
            ]),
            const SizedBox(height: Space.xs),
            strip ??
                Text(
                  enabled ? 'Tap to add ${steps.first} · hold to set' : '',
                  style: context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant),
                ),
          ]),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
          child: Row(children: [
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
        ),
      ),
    );
  }
}
