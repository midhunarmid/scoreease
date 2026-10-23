import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets.dart';
import '../../../engine/engine.dart';
import '../../../engine/templates.dart';
import '../../common/game_ui.dart';
import '../export.dart';

/// Shown above the board once a game is over.
class ResultBanner extends StatelessWidget {
  final GameSnapshot snapshot;
  final bool canRematch;

  const ResultBanner({super.key, required this.snapshot, required this.canRematch});

  @override
  Widget build(BuildContext context) => Material(
        color: context.colors.tertiaryContainer,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.sm),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: Space.md,
            runSpacing: Space.xs,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.emoji_events, color: context.scoreColors.gold),
                const SizedBox(width: Space.sm),
                Text(snapshot.resultText, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: context.colors.onTertiaryContainer)),
              ]),
              Row(mainAxisSize: MainAxisSize.min, children: [
                TextButton.icon(onPressed: () => showResultDialog(context, snapshot), icon: const Icon(Icons.share), label: const Text('Share')),
                if (canRematch)
                  TextButton.icon(
                    onPressed: () => context.push('/new?rematch=${snapshot.game.id}'),
                    icon: const Icon(Icons.replay),
                    label: const Text('Rematch'),
                  ),
              ]),
            ],
          ),
        ),
      );
}

/// Celebration with a result card that can be shared as an image.
Future<void> showResultDialog(BuildContext context, GameSnapshot snapshot) {
  final boundary = GlobalKey();
  return showDialog(
    context: context,
    builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Space.lg),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            RepaintBoundary(key: boundary, child: ResultCard(snapshot: snapshot))
                .animate()
                .scale(begin: const Offset(0.9, 0.9), duration: motionMedium, curve: Curves.easeOutBack)
                .fadeIn(duration: motionMedium),
            const SizedBox(height: Space.lg),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))),
              const SizedBox(width: Space.sm),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.share),
                  label: const Text('Share image'),
                  onPressed: () async {
                    final bytes = await _capture(boundary);
                    if (bytes == null || !context.mounted) {
                      if (context.mounted) toast(context, 'Couldn\'t create the image');
                      return;
                    }
                    await shareFile(context, bytes, 'scoreease-result.png', 'image/png', text: snapshot.resultText);
                  },
                ),
              ),
            ]),
          ]),
        ),
      ),
    ),
  );
}

Future<Uint8List?> _capture(GlobalKey key) async {
  final render = key.currentContext?.findRenderObject();
  if (render is! RenderRepaintBoundary) return null;
  final image = await render.toImage(pixelRatio: 3);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data?.buffer.asUint8List();
}

/// The shareable summary: title, result and final standings.
class ResultCard extends StatelessWidget {
  final GameSnapshot snapshot;
  const ResultCard({super.key, required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final game = snapshot.game;
    final template = Templates.byId(game.templateId);
    return Container(
      padding: const EdgeInsets.all(Space.xl),
      decoration: BoxDecoration(
        borderRadius: Radii.lgAll,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.colors.primary, Color.lerp(context.colors.primary, Colors.black, 0.35)!],
        ),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text('${template.emoji}  ${game.title}', style: context.text.titleMedium?.copyWith(color: Colors.white70, fontWeight: FontWeight.w600)),
          const SizedBox(height: Space.md),
          const Text('🏆', style: TextStyle(fontSize: 44), textAlign: TextAlign.center),
          const SizedBox(height: Space.sm),
          Text(snapshot.resultText, textAlign: TextAlign.center, style: context.text.headlineSmall?.copyWith(color: Colors.white)),
          const SizedBox(height: Space.lg),
          for (final s in snapshot.standings.take(8))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                SizedBox(width: 28, child: Text('${s.rank}.', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700))),
                Expanded(child: Text(game.nameOf(s.participantId), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
                if (s.detail.isNotEmpty && game.mode == GameMode.cricket)
                  Text(s.detail, style: scoreStyle(context, 18, color: Colors.white))
                else
                  Text(formatScore(s.score), style: scoreStyle(context, 20, color: Colors.white)),
              ]),
            ),
          const SizedBox(height: Space.lg),
          Text('scoreease.armid.in', textAlign: TextAlign.center, style: context.text.labelSmall?.copyWith(color: Colors.white60, letterSpacing: 1)),
        ]),
      ),
    );
  }
}
