import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:scoreease/core/presentation/utils/constants.dart';
import 'package:scoreease/core/presentation/utils/theme.dart';
import 'package:scoreease/core/presentation/utils/version_story.dart';
import 'package:scoreease/core/presentation/utils/widget_helper.dart';
import 'package:scoreease/core/presentation/widgets/web_optimised_widget.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  static const routeName = 'settings';

  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final items = getSettingsItems(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Center(
        child: Container(
          padding: WebOptimisedWidget.getWebOptimisedHorizonatalPadding(),
          width: maxScreenWidth,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final item = items[index];
              return SettingsListItem(item: item);
            },
          ),
        ),
      ),
    );
  }
}

class SettingsListItem extends StatelessWidget {
  final SettingsItem item;

  const SettingsListItem({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (item.valueBuilder != null) item.valueBuilder!(context),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              item.description,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            ),
          ],
        ),
      ),
    );
  }
}

// ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

List<SettingsItem> getSettingsItems(BuildContext context) {
  ScoreEaseVersionStory? versionStory;

  return [
    SettingsItem(
      title: 'Switch Theme',
      description: 'Tap to switch between light, dark, and system themes.',
      valueBuilder: (_) => Text(
        "System Theme",
        style: appTheme.textTheme.bodyMedium,
      ),
      onTap: () {},
      type: SettingsItemType.selection,
    ),
    SettingsItem(
      title: 'About App',
      description: 'Learn more about this app.',
      onTap: () {
        launchUrl(Uri.parse('https://github.com/midhunarmid/scoreease'));
      },
      type: SettingsItemType.link,
    ),
    SettingsItem(
      title: 'Version',
      description: 'Current installed app version.',
      valueBuilder: (_) => FutureBuilder<ScoreEaseVersionStory?>(
        future: getAppVersion(),
        builder: (context, snapshot) {
          versionStory = snapshot.data;
          return Text(versionStory?.versionDisplay ?? '-', style: appTheme.textTheme.bodyMedium);
        },
      ),
      onTap: () {
        showSingleButtonAlertDialog(
          context: context,
          dialogType: DialogType.info,
          title: "Version: ${versionStory?.versionName}",
          message: "${versionStory?.tagline}\n\n"
              "Build Number: ${versionStory?.versionSemantic} (${versionStory?.buildNumber})\n"
              "Build Date: ${versionStory?.buildDate}\n\n"
              "Features:\n${versionStory?.features.map((e) => e).join('\n')}",
        );
      },
      type: SettingsItemType.info,
    ),
    SettingsItem(
      title: 'Report an Issue',
      description: 'Found a bug? Let us know.',
      onTap: () {
        launchUrl(Uri.parse('https://github.com/midhunarmid/scoreease/issues/new?template=bug_report.md'));
      },
      type: SettingsItemType.link,
    ),
    SettingsItem(
      title: 'Suggest a Feature',
      description: 'Have an idea? Share it with us.',
      onTap: () {
        launchUrl(Uri.parse('https://github.com/midhunarmid/scoreease/issues/new?template=feature_request.md'));
      },
      type: SettingsItemType.link,
    ),
    SettingsItem(
      title: 'Devs Credits',
      description: 'Meet the team behind this app.',
      onTap: () {
        launchUrl(Uri.parse('https://github.com/midhunarmid/scoreease/graphs/contributors'));
      },
      type: SettingsItemType.link,
    ),
  ];
}

// ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

Future<ScoreEaseVersionStory?> getAppVersion() async {
  final packageInfo = await PackageInfo.fromPlatform();
  return ScoreEaseVersionStory.versionStoryMap[packageInfo.buildNumber];
}

// ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

enum SettingsItemType {
  toggle,
  selection,
  link,
  info,
}

class SettingsItem {
  final String title;
  final String description;
  final Widget Function(BuildContext)? valueBuilder;
  final VoidCallback onTap;
  final SettingsItemType type;

  SettingsItem({
    required this.title,
    required this.description,
    this.valueBuilder,
    required this.onTap,
    required this.type,
  });
}
