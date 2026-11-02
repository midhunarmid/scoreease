import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/router.dart';
import '../../data/cloud/cloud.dart';
import '../../design/responsive.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../engine/event_scoring.dart';
import '../common/game_ui.dart';
import 'event_follow_cubit.dart';
import 'event_widgets.dart';

/// What someone sees when they open a shared event's link: the team totals
/// and every game, updating as they are played.
class EventFollowPage extends StatelessWidget {
  final String code;
  const EventFollowPage({super.key, required this.code});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => EventFollowCubit(code)..open(),
        child: BlocBuilder<EventFollowCubit, EventFollowState>(builder: (context, state) {
          final standings = state.standings;
          if (standings == null) {
            final error = state.error;
            return Scaffold(
              appBar: AppBar(leading: BackButton(onPressed: () => goBack(context))),
              body: error == null
                  ? const LoadingState(message: 'Connecting…')
                  : ErrorState(
                      title: error is CloudException ? error.title : 'Couldn\'t open event',
                      message: error is CloudException ? error.message : '$error',
                      onRetry: context.read<EventFollowCubit>().open,
                    ),
            );
          }
          return _FollowView(code: code, standings: standings, locked: state.locked);
        }),
      );
}

class _FollowView extends StatelessWidget {
  final String code;
  final MeetStandings standings;
  final List<String> locked;
  const _FollowView({required this.code, required this.standings, required this.locked});

  /// Opens a locked game's password gate, then reads it again.
  Future<void> _unlock(BuildContext context, String board) async {
    final cubit = context.read<EventFollowCubit>();
    await context.push('/live/$board');
    cubit.retryLocked();
  }

  @override
  Widget build(BuildContext context) {
    final meet = standings.meet;
    final wide = !context.isCompact;
    final result = standings.resultText;

    final games = SectionCard(
      title: 'Games',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        EventGameList(
          standings: standings,
          empty: 'No games yet. They show up here as soon as they are added.',
          onOpen: (game) => context.push('/live/${game.shareCode}'),
        ),
        for (final board in locked)
          Card(
            child: ListTile(
              onTap: () => _unlock(context, board),
              leading: const Icon(Icons.lock_outline),
              title: const Text('Password-protected game'),
              subtitle: const Text('Not in the totals here. Tap to enter its password.'),
            ),
          ),
      ]),
    );
    final board = SectionCard(title: 'Top performers', child: EventLeaderboard(standings: standings));

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => goBack(context)),
        titleSpacing: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(meet.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          Row(children: [
            Flexible(
              child: Text(
                '🏆 Event · ${pointsLabel(meet.placePoints)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelMedium?.copyWith(color: context.colors.onSurfaceVariant),
              ),
            ),
            if (!meet.finished) ...[const SizedBox(width: Space.sm), const LiveBadge(compact: true)],
          ]),
        ]),
        actions: [
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.share),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: followLink(code)));
              if (context.mounted) toast(context, 'Link copied');
              SharePlus.instance.share(ShareParams(uri: Uri.parse(followLink(code)))).ignore();
            },
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(context.gutter, Space.md, context.gutter, Space.xl),
        children: [
          MaxWidth(
            maxWidth: 1100,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (meet.finished && result != null) ...[
                Card(
                  color: context.colors.tertiaryContainer,
                  child: ListTile(
                    leading: Icon(Icons.emoji_events, color: context.scoreColors.gold),
                    title: Text(result, style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: Space.sm),
              ],
              TeamTotals(standings: standings, scale: wide ? 1.2 : 1),
              const SizedBox(height: Space.lg),
              if (wide)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: games),
                  const SizedBox(width: Space.lg),
                  Expanded(child: board),
                ])
              else ...[
                games,
                const SizedBox(height: Space.lg),
                board,
              ],
            ]),
          ),
        ],
      ),
    );
  }
}
