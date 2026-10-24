import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/router.dart';
import '../../data/cloud/access_remote.dart';
import '../../data/cloud/cloud.dart';
import '../../design/responsive.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../engine/engine.dart';
import '../../engine/templates.dart';
import '../common/game_ui.dart';
import '../play/play_cubit.dart';
import '../play/widgets/board_view.dart';
import '../play/widgets/password_gate.dart';

/// What someone sees when they open a shared link.
class LivePage extends StatelessWidget {
  final String code;
  const LivePage({super.key, required this.code});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => PlayCubit()..openLive(code, AccessLevel.read),
        child: BlocBuilder<PlayCubit, PlayState>(builder: (context, state) {
          if (state.needsPassword != null) {
            return PasswordGate(level: state.needsPassword!, onUnlock: context.read<PlayCubit>().unlock, onCancel: () => goBack(context));
          }
          final snapshot = state.snapshot;
          if (snapshot == null) {
            final error = state.error;
            return Scaffold(
              appBar: AppBar(leading: BackButton(onPressed: () => goBack(context))),
              body: error == null
                  ? const LoadingState(message: 'Connecting…')
                  : ErrorState(
                      title: error is CloudException ? error.title : 'Couldn\'t open game',
                      message: error is CloudException ? error.message : '$error',
                      onRetry: () => context.read<PlayCubit>().openLive(code, AccessLevel.read),
                    ),
            );
          }
          return _LiveView(code: code, state: state, snapshot: snapshot);
        }),
      );
}

class _LiveView extends StatelessWidget {
  final String code;
  final PlayState state;
  final GameSnapshot snapshot;

  const _LiveView({required this.code, required this.state, required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final game = snapshot.game;
    final template = Templates.byId(game.templateId);
    final recent = snapshot.log.take(8).toList();
    final time = DateFormat.Hm();

    final board = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (snapshot.finished)
        Card(
          color: context.colors.tertiaryContainer,
          child: ListTile(leading: Icon(Icons.emoji_events, color: context.scoreColors.gold), title: Text(snapshot.resultText)),
        ),
      if (snapshot.finished) const SizedBox(height: Space.md),
      BoardView(snapshot: snapshot),
    ]);

    final activity = SectionCard(
      title: 'Latest',
      child: recent.isEmpty
          ? const Text('Nothing scored yet.')
          : Column(children: [
              for (final e in recent)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.xs),
                  child: Row(children: [
                    Expanded(child: Text(snapshot.describe(e))),
                    Text(time.format(DateTime.fromMillisecondsSinceEpoch(e.ts)), style: context.text.labelSmall),
                  ]),
                ),
            ]),
    );

    final actions = Wrap(spacing: Space.sm, runSpacing: Space.sm, children: [
      if (!snapshot.finished)
        FilledButton.icon(
          onPressed: () => context.push(game.isOwner ? '/game/${game.id}' : '/live/$code/score'),
          icon: const Icon(Icons.edit_note),
          label: const Text('Keep score'),
        ),
      OutlinedButton.icon(onPressed: () => context.push('/live/$code/tv'), icon: const Icon(Icons.tv), label: const Text('TV mode')),
      OutlinedButton.icon(
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: liveLink(code)));
          if (context.mounted) toast(context, 'Link copied');
          SharePlus.instance.share(ShareParams(uri: Uri.parse(liveLink(code)))).ignore();
        },
        icon: const Icon(Icons.share),
        label: const Text('Share'),
      ),
    ]);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => goBack(context)),
        titleSpacing: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(game.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          Row(children: [
            Text('${template.emoji} ${template.name}', style: context.text.labelMedium?.copyWith(color: context.colors.onSurfaceVariant)),
            const SizedBox(width: Space.sm),
            if (!snapshot.finished) const LiveBadge(compact: true),
          ]),
        ]),
      ),
      body: ListView(
        padding: EdgeInsets.all(context.gutter),
        children: [
          MaxWidth(
            maxWidth: 1100,
            child: context.isExpanded
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [board, const SizedBox(height: Space.lg), actions])),
                    const SizedBox(width: Space.xl),
                    Expanded(flex: 2, child: activity),
                  ])
                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    actions,
                    const SizedBox(height: Space.lg),
                    board,
                    const SizedBox(height: Space.lg),
                    activity,
                  ]),
          ),
        ],
      ),
    );
  }
}
