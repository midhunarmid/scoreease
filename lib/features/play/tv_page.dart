import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
                bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => goBack(context)},
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
                                  ],
                                ]),
                                if (snapshot.finished)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: Space.lg),
                                    child: Text('🏆 ${snapshot.resultText}', textAlign: TextAlign.center, style: context.text.headlineMedium?.copyWith(color: context.scoreColors.gold)),
                                  ),
                                const SizedBox(height: Space.lg),
                                Expanded(child: Center(child: BoardView(snapshot: snapshot, tv: true))),
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
