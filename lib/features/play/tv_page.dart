import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../app/router.dart';
import '../../data/cloud/access_remote.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../engine/templates.dart';
import '../common/game_ui.dart';
import 'play_cubit.dart';
import 'widgets/board_view.dart';
import 'widgets/password_gate.dart';

/// Big, dark, always-on scoreboard for a TV or a propped-up tablet.
class TvPage extends StatefulWidget {
  final String? gameId;
  final String? code;

  const TvPage.local({super.key, required String this.gameId}) : code = null;
  const TvPage.live({super.key, required String this.code}) : gameId = null;

  @override
  State<TvPage> createState() => _TvPageState();
}

class _TvPageState extends State<TvPage> {
  /// Shows a QR code in the corner so people in the room can follow along.
  bool _showQr = true;
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
        child: BlocProvider(
          create: (_) {
            final cubit = PlayCubit();
            if (widget.gameId != null) {
              cubit.openLocal(widget.gameId!);
            } else {
              cubit.openLive(widget.code!, AccessLevel.read);
            }
            return cubit;
          },
          child: BlocBuilder<PlayCubit, PlayState>(
            builder: (context, state) {
              if (state.needsPassword != null) {
                return PasswordGate(level: state.needsPassword!, onUnlock: context.read<PlayCubit>().unlock, onCancel: () => goBack(context));
              }
              final snapshot = state.snapshot;
              return CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.escape): () => goBack(context),
                  const SingleActivator(LogicalKeyboardKey.keyQ): () => setState(() => _showQr = !_showQr),
                },
                child: Focus(
                  autofocus: true,
                  child: Scaffold(
                    backgroundColor: Colors.black,
                    body: SafeArea(
                      child: snapshot == null
                          ? (state.error != null ? ErrorState(message: '${state.error}') : const LoadingState())
                          : Padding(
                              padding: const EdgeInsets.all(Space.xl),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                                Row(children: [
                                  IconButton(tooltip: 'Exit TV mode (Esc)', onPressed: () => goBack(context), icon: const Icon(Icons.close)),
                                  const SizedBox(width: Space.sm),
                                  Text(Templates.byId(snapshot.game.templateId).emoji, style: const TextStyle(fontSize: 28)),
                                  const SizedBox(width: Space.sm),
                                  Expanded(
                                    child: Text(snapshot.game.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.headlineMedium),
                                  ),
                                  if (state.liveCode != null) ...[
                                    const LiveBadge(),
                                    const SizedBox(width: Space.md),
                                    Text(state.liveCode!.toUpperCase(), style: scoreStyle(context, 22, color: Colors.white70)),
                                    const SizedBox(width: Space.sm),
                                    IconButton(
                                      tooltip: _showQr ? 'Hide join code (Q)' : 'Show join code (Q)',
                                      onPressed: () => setState(() => _showQr = !_showQr),
                                      icon: Icon(_showQr ? Icons.qr_code_2 : Icons.qr_code),
                                    ),
                                  ],
                                ]),
                                if (snapshot.finished)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: Space.lg),
                                    child: Text('🏆 ${snapshot.resultText}', textAlign: TextAlign.center, style: context.text.headlineMedium?.copyWith(color: context.scoreColors.gold)),
                                  ),
                                const SizedBox(height: Space.lg),
                                Expanded(
                                  child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                                    Expanded(child: Center(child: BoardView(snapshot: snapshot, tv: true))),
                                    // Beside the board on a landscape screen; a portrait phone has no room.
                                    if (_showQr && state.liveCode != null && MediaQuery.sizeOf(context).aspectRatio > 1) ...[
                                      const SizedBox(width: Space.xl),
                                      Align(alignment: Alignment.bottomRight, child: _JoinQr(code: state.liveCode!)),
                                    ],
                                  ]),
                                ),
                              ]),
                            ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
}

/// "Scan to follow" corner card with the live link.
class _JoinQr extends StatelessWidget {
  final String code;
  const _JoinQr({required this.code});

  @override
  Widget build(BuildContext context) {
    final size = (MediaQuery.sizeOf(context).shortestSide * 0.2).clamp(96.0, 200.0);
    return Container(
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(color: Colors.white, borderRadius: Radii.mdAll),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        QrImageView(data: liveLink(code), size: size, padding: EdgeInsets.zero, backgroundColor: Colors.white),
        const SizedBox(height: Space.sm),
        Text('Scan to follow', style: context.text.labelLarge?.copyWith(color: Colors.black87, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
