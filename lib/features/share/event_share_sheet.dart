import 'package:flutter/material.dart';

import '../../app/di.dart';
import '../../data/cloud/cloud.dart';
import '../../data/local/local_store.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../common/game_ui.dart';
import '../events/event_sharing.dart';
import 'share_sheet.dart';

Future<void> showEventShareSheet(BuildContext context, String meetId) => showAdaptiveSheet(context, builder: (_) => _EventShareSheet(meetId: meetId));

class _EventShareSheet extends StatefulWidget {
  final String meetId;
  const _EventShareSheet({required this.meetId});

  @override
  State<_EventShareSheet> createState() => _EventShareSheetState();
}

class _EventShareSheetState extends State<_EventShareSheet> {
  final _store = getIt<LocalStore>();
  final _sharing = getIt<EventSharing>();
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) toast(context, e is CloudException ? e.message : 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<void>(
        stream: _store.meetChanges,
        builder: (context, _) {
          final code = _store.meet(widget.meetId)?.shareCode;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.xl),
            child: code == null ? _notShared(context) : _shared(context, code),
          );
        },
      );

  Widget _notShared(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Share this event', style: context.text.titleLarge),
        const SizedBox(height: Space.sm),
        Text(
          'People follow the team totals and every game, played, playing and up next, on their phone or laptop. Only you keep score, and games you add later show up by themselves.',
          style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
        ),
        const SizedBox(height: Space.lg),
        FilledButton.icon(
          onPressed: _busy ? null : () => _run(() => _sharing.share(widget.meetId)),
          icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.cell_tower),
          label: const Text('Share event'),
        ),
      ]);

  Widget _shared(BuildContext context, String code) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [Text('Event shared', style: context.text.titleLarge), const SizedBox(width: Space.sm), const LiveBadge()]),
        const SizedBox(height: Space.sm),
        Text('Anyone with the link can follow. It opens the event, and every game in it.', style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
        const SizedBox(height: Space.md),
        ShareLinkPanel(code: code, link: followLink(code), subject: 'Follow the event live'),
        const SizedBox(height: Space.lg),
        const Divider(),
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: context.colors.error),
          onPressed: _busy
              ? null
              : () async {
                  final ok = await confirm(
                    context,
                    title: 'Stop sharing?',
                    message: 'The event link and its game links stop working. Everything stays on this device.',
                    confirmLabel: 'Stop sharing',
                    destructive: true,
                  );
                  if (ok) await _run(() => _sharing.stop(widget.meetId));
                },
          icon: const Icon(Icons.portable_wifi_off),
          label: const Text('Stop sharing'),
        ),
      ]);
}
