import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../design/responsive.dart';
import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../engine/cricket_engine.dart';
import '../../../engine/engine.dart';
import '../play_cubit.dart';

/// Scorecard on top, a scoring pad below (side by side on wide screens).
class CricketView extends StatefulWidget {
  final GameSnapshot snapshot;
  final bool enabled;

  const CricketView({super.key, required this.snapshot, required this.enabled});

  @override
  State<CricketView> createState() => _CricketViewState();
}

class _CricketViewState extends State<CricketView> {
  String _extra = '';
  bool _wicket = false;

  void _ball(int runs) {
    context.read<PlayCubit>().add(CricketEngine.ball, {
      'r': runs,
      if (_extra.isNotEmpty) 'x': _extra,
      if (_wicket) 'w': true,
    });
    setState(() {
      _extra = '';
      _wicket = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final card = CricketScorecard(snapshot: widget.snapshot);
    if (!widget.enabled) return SingleChildScrollView(padding: EdgeInsets.all(context.gutter), child: card);

    final pad = _Pad(
      extra: _extra,
      wicket: _wicket,
      onExtra: (x) => setState(() => _extra = _extra == x ? '' : x),
      onWicket: () => setState(() => _wicket = !_wicket),
      onRuns: _ball,
    );
    if (!context.isCompact) {
      return Padding(
        padding: EdgeInsets.all(context.gutter),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: SingleChildScrollView(child: card)),
          const SizedBox(width: Space.xl),
          SizedBox(width: 360, child: pad),
        ]),
      );
    }
    return Column(children: [
      Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(Space.lg), child: card)),
      Material(
        color: context.colors.surfaceContainer,
        child: Padding(padding: const EdgeInsets.all(Space.md), child: pad),
      ),
    ]);
  }
}

class CricketScorecard extends StatelessWidget {
  final GameSnapshot snapshot;
  final double scale;

  const CricketScorecard({super.key, required this.snapshot, this.scale = 1});

  @override
  Widget build(BuildContext context) {
    final game = snapshot.game;
    final state = snapshot.stateAs<CricketState>();
    final inn = state.current;
    final batting = game.participants[inn.side];
    final maxBalls = CricketEngine.maxOvers(game) * 6;
    final crr = inn.legalBalls == 0 ? 0.0 : inn.runs * 6 / inn.legalBalls;
    final target = state.target;
    final need = target == null ? null : target - inn.runs;
    final ballsLeft = maxBalls - inn.legalBalls;
    final rrr = need == null || ballsLeft <= 0 ? null : need * 6 / ballsLeft;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Card(
        child: Padding(
          padding: EdgeInsets.all(Space.lg * scale),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(snapshot.finished ? 'Final innings' : '${batting.name} batting', style: context.text.titleMedium?.copyWith(fontSize: 16 * scale)),
            SizedBox(height: Space.xs * scale),
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text(inn.scoreLine, style: scoreStyle(context, 64 * scale)),
              SizedBox(width: Space.md * scale),
              Text('(${inn.overs}/${CricketEngine.maxOvers(game)} ov)', style: context.text.titleMedium?.copyWith(fontSize: 18 * scale, color: context.colors.onSurfaceVariant)),
            ]),
            SizedBox(height: Space.sm * scale),
            Wrap(spacing: Space.lg * scale, runSpacing: Space.xs, children: [
              _Stat('CRR', crr.toStringAsFixed(2), scale),
              _Stat('Extras', '${inn.extras}', scale),
              if (target != null) _Stat('Target', '$target', scale),
              if (rrr != null && !snapshot.finished) _Stat('RRR', rrr.toStringAsFixed(2), scale),
            ]),
            if (need != null && need > 0 && !snapshot.finished) ...[
              SizedBox(height: Space.sm * scale),
              Text(
                'Need $need from $ballsLeft ball${ballsLeft == 1 ? '' : 's'}',
                style: context.text.titleSmall?.copyWith(fontSize: 15 * scale, color: context.colors.primary, fontWeight: FontWeight.w700),
              ),
            ],
            SizedBox(height: Space.md * scale),
            Text('This over', style: context.text.labelMedium?.copyWith(fontSize: 12 * scale, color: context.colors.onSurfaceVariant)),
            SizedBox(height: Space.xs * scale),
            Wrap(spacing: Space.xs * scale, runSpacing: Space.xs * scale, children: [
              if (inn.currentOver.isEmpty) Text('–', style: context.text.bodyMedium),
              for (final b in inn.currentOver) _BallChip(label: b, scale: scale),
            ]),
          ]),
        ),
      ),
      if (state.innings.length == 2) ...[
        SizedBox(height: Space.sm * scale),
        Card(
          child: ListTile(
            title: Text('${game.participants[state.innings[0].side].name} · 1st innings', style: TextStyle(fontSize: 14 * scale)),
            trailing: Text('${state.innings[0].scoreLine} (${state.innings[0].overs})', style: scoreStyle(context, 20 * scale)),
          ),
        ),
      ],
    ]);
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final double scale;
  const _Stat(this.label, this.value, this.scale);

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: context.text.labelSmall?.copyWith(fontSize: 11 * scale, color: context.colors.onSurfaceVariant)),
        Text(value, style: scoreStyle(context, 20 * scale, weight: FontWeight.w600)),
      ]);
}

class _BallChip extends StatelessWidget {
  final String label;
  final double scale;
  const _BallChip({required this.label, this.scale = 1});

  @override
  Widget build(BuildContext context) {
    final wicket = label.contains('W') && !label.contains('Wd');
    final boundary = label == '4' || label == '6';
    final bg = wicket
        ? context.scoreColors.negative
        : boundary
            ? context.colors.primary
            : context.colors.surfaceContainerHighest;
    final fg = wicket || boundary ? Colors.white : context.colors.onSurface;
    return Container(
      constraints: BoxConstraints(minWidth: 34 * scale),
      height: 34 * scale,
      padding: EdgeInsets.symmetric(horizontal: 6 * scale),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(17 * scale)),
      child: Center(widthFactor: 1, child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13 * scale))),
    );
  }
}

class _Pad extends StatelessWidget {
  final String extra;
  final bool wicket;
  final ValueChanged<String> onExtra;
  final VoidCallback onWicket;
  final ValueChanged<int> onRuns;

  const _Pad({required this.extra, required this.wicket, required this.onExtra, required this.onWicket, required this.onRuns});

  @override
  Widget build(BuildContext context) {
    Widget toggle(String label, bool selected, VoidCallback onTap, {Color? color}) => Expanded(
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: FilterChip(
              label: SizedBox(width: double.infinity, child: Text(label, textAlign: TextAlign.center)),
              selected: selected,
              showCheckmark: false,
              selectedColor: color,
              onSelected: (_) => onTap(),
            ),
          ),
        );

    Widget runButton(int r) => Expanded(
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: FilledButton.tonal(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 56), padding: EdgeInsets.zero),
              onPressed: () => onRuns(r),
              child: Text(r == 0 ? '•' : '$r', style: scoreStyle(context, 22)),
            ),
          ),
        );

    final hint = [
      if (extra.isNotEmpty) {'wd': 'Wide', 'nb': 'No ball', 'b': 'Byes', 'lb': 'Leg byes'}[extra],
      if (wicket) 'Wicket',
    ].join(' + ');

    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        toggle('Wd', extra == 'wd', () => onExtra('wd')),
        toggle('Nb', extra == 'nb', () => onExtra('nb')),
        toggle('B', extra == 'b', () => onExtra('b')),
        toggle('Lb', extra == 'lb', () => onExtra('lb')),
        toggle('Wkt', wicket, onWicket, color: context.scoreColors.negative.withValues(alpha: 0.3)),
      ]),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.xs),
        child: Text(
          hint.isEmpty ? 'Runs off the ball' : '$hint · then pick runs',
          textAlign: TextAlign.center,
          style: context.text.labelMedium?.copyWith(color: context.colors.onSurfaceVariant),
        ),
      ),
      Row(children: [runButton(0), runButton(1), runButton(2), runButton(3)]),
      Row(children: [runButton(4), runButton(5), runButton(6)]),
    ]);
  }
}
