import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// A widget that overlays floating score-change indicators (+1, -1, +5, etc.)
/// on top of its [child]. Call [ScoreChangeIndicatorState.showDelta] to spawn
/// a new indicator that floats upward and fades out.
///
/// Usage:
/// ```dart
/// final indicatorKey = GlobalKey<ScoreChangeIndicatorState>();
///
/// ScoreChangeIndicator(
///   key: indicatorKey,
///   child: yourCardWidget,
/// );
///
/// // On score change:
/// indicatorKey.currentState?.showDelta(1);  // +1
/// indicatorKey.currentState?.showDelta(-1); // -1
/// ```
class ScoreChangeIndicator extends StatefulWidget {
  final Widget child;

  const ScoreChangeIndicator({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  ScoreChangeIndicatorState createState() => ScoreChangeIndicatorState();
}

class ScoreChangeIndicatorState extends State<ScoreChangeIndicator> {
  final List<_IndicatorData> _indicators = [];
  int _nextId = 0;
  final _rng = Random();

  /// Spawns a floating indicator showing the given [delta] value.
  void showDelta(int delta) {
    if (delta == 0) return;
    final id = _nextId++;
    final xOffset = (_rng.nextDouble() - 0.5) * 32; // ±16px jitter
    setState(() {
      _indicators.add(_IndicatorData(id: id, delta: delta, xOffset: xOffset));
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) {
        setState(() => _indicators.removeWhere((e) => e.id == id));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        ..._indicators.map((indicator) => _FloatingDelta(
              key: ValueKey(indicator.id),
              indicator: indicator,
            )),
      ],
    );
  }
}

// ─── Internal data model ─────────────────────────────────────────────────────

class _IndicatorData {
  final int id;
  final int delta;
  final double xOffset;

  const _IndicatorData({
    required this.id,
    required this.delta,
    required this.xOffset,
  });
}

// ─── Animated floating delta widget ──────────────────────────────────────────

class _FloatingDelta extends StatefulWidget {
  final _IndicatorData indicator;

  const _FloatingDelta({
    Key? key,
    required this.indicator,
  }) : super(key: key);

  @override
  State<_FloatingDelta> createState() => _FloatingDeltaState();
}

class _FloatingDeltaState extends State<_FloatingDelta>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _translateY;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );

    _translateY = Tween<double>(begin: 0, end: -70).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_controller);

    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.5, end: 1.2)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 25,
      ),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 75),
    ]).animate(_controller);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPositive = widget.indicator.delta > 0;
    final label =
        isPositive ? "+${widget.indicator.delta}" : "${widget.indicator.delta}";
    final color = isPositive ? Colors.green.shade500 : Colors.red.shade400;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: 0,
          right: 0,
          top: 20 + _translateY.value,
          child: Center(
            child: Transform.translate(
              offset: Offset(widget.indicator.xOffset, 0),
              child: Transform.scale(
                scale: _scale.value,
                child: Opacity(
                  opacity: _opacity.value.clamp(0.0, 1.0),
                  child: child!,
                ),
              ),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14.sp,
          ),
        ),
      ),
    );
  }
}
