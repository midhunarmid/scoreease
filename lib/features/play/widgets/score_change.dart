import 'dart:async';

import 'package:flutter/material.dart';

import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../engine/engine.dart';

/// Shows how much [score] just changed, e.g. "+3", then fades. Changes close
/// together add up, so a burst of taps reads as one "+5".
class ScoreDelta extends StatefulWidget {
  final num score;
  final double size;

  const ScoreDelta({super.key, required this.score, this.size = 16});

  static const visibleFor = Duration(seconds: 2);

  @override
  State<ScoreDelta> createState() => _ScoreDeltaState();
}

class _ScoreDeltaState extends State<ScoreDelta> {
  num _delta = 0;
  bool _visible = false;
  Timer? _timer;

  @override
  void didUpdateWidget(ScoreDelta old) {
    super.didUpdateWidget(old);
    if (old.score == widget.score) return;
    _delta = (_visible ? _delta : 0) + widget.score - old.score;
    _visible = _delta != 0;
    _timer?.cancel();
    _timer = Timer(ScoreDelta.visibleFor, () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final up = _delta > 0;
    final text = _delta == 0 ? '' : (up ? '+' : '−') + formatNum(_delta.abs());
    return ExcludeSemantics(
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: _visible ? motionFast : motionMedium,
        child: AnimatedSlide(
          offset: _visible ? Offset.zero : const Offset(0, -0.4),
          duration: motionMedium,
          child: Text(text, style: scoreStyle(context, widget.size, color: up ? context.scoreColors.positive : context.scoreColors.negative)),
        ),
      ),
    );
  }
}

/// "Game point" pill for whoever can win with one more score.
class GamePointBadge extends StatelessWidget {
  final double scale;
  const GamePointBadge({super.key, this.scale = 1});

  @override
  Widget build(BuildContext context) {
    final gold = context.scoreColors.gold;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: Space.sm * scale, vertical: 2 * scale),
      decoration: BoxDecoration(color: gold.withValues(alpha: 0.18), borderRadius: Radii.smAll, border: Border.all(color: gold)),
      child: Text('Game point', style: context.text.labelSmall?.copyWith(fontSize: 11 * scale, fontWeight: FontWeight.w800, color: gold)),
    );
  }
}
