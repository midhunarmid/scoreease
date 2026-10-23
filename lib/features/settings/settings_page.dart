import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/di.dart';
import '../../app/version_story.dart';
import '../../data/cloud/access_remote.dart';
import '../../data/local/local_store.dart';
import '../../data/local/settings_store.dart';
import '../../design/responsive.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../play/export.dart';

const _repo = 'https://github.com/midhunarmid/scoreease';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _export(BuildContext context) async {
    final json = const JsonEncoder.withIndent(' ').convert(getIt<LocalStore>().exportAll());
    final date = DateTime.now().toIso8601String().substring(0, 10);
    await shareFile(context, Uint8List.fromList(utf8.encode(json)), 'scoreease-backup-$date.json', 'application/json');
  }

  Future<void> _import(BuildContext context) async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['json'], withData: true);
      final bytes = result?.files.single.bytes;
      if (bytes == null) return;
      final count = await getIt<LocalStore>().importAll(jsonDecode(utf8.decode(bytes)) as Map);
      if (context.mounted) toast(context, 'Imported $count game${count == 1 ? '' : 's'}');
    } catch (e) {
      if (context.mounted) toast(context, 'That file isn\'t a ScoreEase backup');
    }
  }

  Future<void> _forgetPasswords(BuildContext context) async {
    final settings = getIt<SettingsStore>();
    final ok = await confirm(
      context,
      title: 'Forget saved passwords?',
      message: 'You\'ll need to enter passwords again for protected live games.',
      confirmLabel: 'Forget',
    );
    if (!ok) return;
    try {
      await getIt<AccessRemote>().revokeGrants(settings.unlockedBoards);
      settings.unlockedBoards = const [];
      if (context.mounted) toast(context, 'Saved passwords cleared');
    } catch (_) {
      if (context.mounted) toast(context, 'Couldn\'t reach the server. Try again when online.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = getIt<SettingsStore>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          padding: EdgeInsets.fromLTRB(context.gutter, Space.sm, context.gutter, Space.xxl),
          children: [
            MaxWidth(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SectionCard(
                  title: 'Appearance',
                  child: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto), label: Text('System')),
                      ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode), label: Text('Light')),
                      ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode), label: Text('Dark')),
                    ],
                    showSelectedIcon: false,
                    selected: {settings.themeMode},
                    onSelectionChanged: (s) => settings.themeMode = s.first,
                  ),
                ),
                const SizedBox(height: Space.lg),
                SectionCard(
                  title: 'While playing',
                  padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.sm),
                  child: Column(children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Vibrate on score'),
                      value: settings.haptics,
                      onChanged: (v) => settings.haptics = v,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Keep screen on'),
                      subtitle: const Text('While a game is open'),
                      value: settings.keepAwake,
                      onChanged: (v) => settings.keepAwake = v,
                    ),
                  ]),
                ),
                const SizedBox(height: Space.lg),
                SectionCard(
                  title: 'Your data',
                  padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.sm),
                  child: Column(children: [
                    Text(
                      'Games are saved on this device only. Back them up to move to another device.',
                      style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                    ),
                    ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.upload_file), title: const Text('Export backup'), onTap: () => _export(context)),
                    ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.download), title: const Text('Import backup'), onTap: () => _import(context)),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.key_off_outlined),
                      title: const Text('Forget saved passwords'),
                      onTap: () => _forgetPasswords(context),
                    ),
                  ]),
                ),
                const SizedBox(height: Space.lg),
                SectionCard(
                  title: 'About',
                  padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.sm),
                  child: Column(children: [
                    FutureBuilder<PackageInfo>(
                      future: PackageInfo.fromPlatform(),
                      builder: (context, snap) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.new_releases_outlined),
                        title: const Text('What\'s new'),
                        subtitle: Text(snap.hasData ? 'Version ${snap.data!.version}' : ''),
                        onTap: () => _showVersions(context),
                      ),
                    ),
                    _link(Icons.bug_report_outlined, 'Report a problem', '$_repo/issues/new?template=bug_report.md'),
                    _link(Icons.lightbulb_outline, 'Suggest a feature', '$_repo/issues/new?template=feature_request.md'),
                    _link(Icons.code, 'Source code', _repo),
                  ]),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _link(IconData icon, String title, String url) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.open_in_new, size: 18),
        onTap: () => launchUrl(Uri.parse(url)),
      );

  void _showVersions(BuildContext context) {
    final versions = ScoreEaseVersionStory.versionStoryMap.values.toList();
    showAdaptiveSheet(
      context,
      builder: (context) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.xl),
        children: [
          Text('What\'s new', style: context.text.titleLarge),
          const SizedBox(height: Space.md),
          for (final v in versions) ...[
            Text('${v.versionSemantic} · ${v.versionName}', style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            Text(v.tagline, style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
            const SizedBox(height: Space.xs),
            for (final f in v.features) Padding(padding: const EdgeInsets.only(bottom: 2), child: Text('• $f')),
            const SizedBox(height: Space.lg),
          ],
        ],
      ),
    );
  }
}
