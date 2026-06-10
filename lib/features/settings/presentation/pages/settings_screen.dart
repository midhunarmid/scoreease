import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:scoreease/core/utils/theme.dart';
import 'package:scoreease/core/utils/version_story.dart';
import 'package:scoreease/core/utils/widget_helper.dart';
import 'package:scoreease/core/widgets/web_optimised_widget.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:scoreease/core/utils/global.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:scoreease/core/utils/theme_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:scoreease/features/settings/presentation/pages/version_history_screen.dart';

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
      backgroundColor: appColors.screenBg,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: appColors.textColor,
      ),
      body: Center(
        child: Container(
          padding: WebOptimisedWidget.getWebOptimisedHorizonatalPadding(),
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final isHeader = item.type == SettingsItemType.header;

              if (isHeader) {
                return Padding(
                  padding: EdgeInsets.only(
                      top: index == 0 ? 0 : 24.h, bottom: 12.h, left: 8.w),
                  child: Text(
                    item.title.toUpperCase(),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).hintColor,
                          letterSpacing: 1.2,
                        ),
                  ),
                )
                    .animate()
                    .fade(duration: 400.ms, delay: (40 * index).ms)
                    .slideX(begin: 0.05, end: 0);
              }

              return Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: SettingsListItem(item: item),
              )
                  .animate()
                  .fade(duration: 400.ms, delay: (40 * index).ms)
                  .slideY(begin: 0.1, end: 0);
            },
          ),
        ),
      ),
    );
  }
}

class SettingsListItem extends StatefulWidget {
  final SettingsItem item;

  const SettingsListItem({super.key, required this.item});

  @override
  State<SettingsListItem> createState() => _SettingsListItemState();
}

class _SettingsListItemState extends State<SettingsListItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = widget.item.iconColor ?? appColors.primaryColor;

    return GestureDetector(
      onTapDown: (_) {
        if (widget.item.onTap != null) setState(() => _isPressed = true);
      },
      onTapUp: (_) {
        if (widget.item.onTap != null) {
          setState(() => _isPressed = false);
          widget.item.onTap!();
        }
      },
      onTapCancel: () {
        if (widget.item.onTap != null) setState(() => _isPressed = false);
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20.r),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 16.w),
              decoration: BoxDecoration(
                color: appColors.tileBgColor.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: iconColor.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  if (widget.item.icon != null) ...[
                    Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.item.icon,
                        color: iconColor,
                        size: 24.w,
                      ),
                    ),
                    SizedBox(width: 16.w),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 16.sp,
                          ),
                        ),
                        if (widget.item.description != null) ...[
                          SizedBox(height: 4.h),
                          Text(
                            widget.item.description!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.hintColor,
                              fontSize: 12.sp,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (widget.item.valueBuilder != null) ...[
                    SizedBox(width: 12.w),
                    widget.item.valueBuilder!(context),
                  ] else if (widget.item.onTap != null) ...[
                    Icon(
                      Icons.chevron_right_rounded,
                      color: theme.hintColor.withValues(alpha: 0.5),
                    ),
                  ],
                ],
              ),
            ),
          ),
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
      title: 'Preferences',
      type: SettingsItemType.header,
    ),
    SettingsItem(
      title: 'Switch Theme',
      description: 'Tap to switch between light, dark, and system themes.',
      icon: Icons.palette_rounded,
      iconColor: Colors.purpleAccent,
      valueBuilder: (_) => ListenableBuilder(
        listenable: themeProvider,
        builder: (context, _) {
          final modeName = themeProvider.themeMode.name;
          final display = modeName[0].toUpperCase() + modeName.substring(1);
          return Text(
            display,
            style: appTheme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: appColors.primaryColor,
            ),
          );
        },
      ),
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) {
            return Container(
              margin: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: appColors.screenBg,
                borderRadius: BorderRadius.circular(24.r),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 16.h),
                  Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: appColors.textColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    "Choose Theme",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  SizedBox(height: 16.h),
                  ListTile(
                    leading: const Icon(Icons.brightness_auto_rounded),
                    title: const Text("System Default"),
                    onTap: () {
                      themeProvider.setThemeMode(ThemeMode.system);
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.light_mode_rounded),
                    title: const Text("Light Mode"),
                    onTap: () {
                      themeProvider.setThemeMode(ThemeMode.light);
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.dark_mode_rounded),
                    title: const Text("Dark Mode"),
                    onTap: () {
                      themeProvider.setThemeMode(ThemeMode.dark);
                      Navigator.pop(context);
                    },
                  ),
                  SizedBox(height: 16.h),
                ],
              ),
            );
          },
        );
      },
      type: SettingsItemType.selection,
    ),
    SettingsItem(
      title: 'Security',
      type: SettingsItemType.header,
    ),
    SettingsItem(
      title: 'Clear Saved Passwords',
      description: 'Clear all locally saved scoreboard passwords.',
      icon: Icons.lock_reset_rounded,
      iconColor: Colors.redAccent,
      onTap: () {
        showTwoButtonAlertDialog(
          context: context,
          title: "Clear Passwords",
          message:
              "Are you sure you want to clear all locally saved scoreboard accesses? You will have to enter passwords again.",
          positiveButton: "Clear",
          negativeButton: "Cancel",
          positiveAction: () async {
            await GlobalValues.clearAllScoreboardAccesses();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      const Text("All saved passwords cleared successfully!"),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: appColors.pleasantButtonBg,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
        );
      },
      type: SettingsItemType.info,
    ),
    SettingsItem(
      title: 'About',
      type: SettingsItemType.header,
    ),
    SettingsItem(
      title: 'Version',
      description: 'Current installed app version.',
      icon: Icons.info_outline_rounded,
      iconColor: Colors.blueAccent,
      valueBuilder: (_) => FutureBuilder<ScoreEaseVersionStory?>(
        future: getAppVersion(),
        builder: (context, snapshot) {
          versionStory = snapshot.data;
          return Text(
            versionStory?.versionDisplay ?? '-',
            style: appTheme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600, color: appColors.primaryColor),
          );
        },
      ),
      onTap: () {
        context.push('/${VersionHistoryScreen.routeName}');
      },
      type: SettingsItemType.info,
    ),
    SettingsItem(
      title: 'Report an Issue',
      description: 'Found a bug? Let us know.',
      icon: Icons.bug_report_rounded,
      iconColor: Colors.orangeAccent,
      onTap: () {
        launchUrl(Uri.parse(
            'https://github.com/midhunarmid/scoreease/issues/new?template=bug_report.md'));
      },
      type: SettingsItemType.link,
    ),
    SettingsItem(
      title: 'Suggest a Feature',
      description: 'Have an idea? Share it with us.',
      icon: Icons.lightbulb_outline_rounded,
      iconColor: Colors.amber,
      onTap: () {
        launchUrl(Uri.parse(
            'https://github.com/midhunarmid/scoreease/issues/new?template=feature_request.md'));
      },
      type: SettingsItemType.link,
    ),
    SettingsItem(
      title: 'Devs Credits',
      description: 'Meet the team behind this app.',
      icon: Icons.people_outline_rounded,
      iconColor: Colors.tealAccent,
      onTap: () {
        launchUrl(Uri.parse(
            'https://github.com/midhunarmid/scoreease/graphs/contributors'));
      },
      type: SettingsItemType.link,
    ),
    SettingsItem(
      title: 'About App',
      description: 'Learn more about this app.',
      icon: Icons.code_rounded,
      iconColor: Colors.indigoAccent,
      onTap: () {
        launchUrl(Uri.parse('https://github.com/midhunarmid/scoreease'));
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
  header,
  toggle,
  selection,
  link,
  info,
}

class SettingsItem {
  final String title;
  final String? description;
  final IconData? icon;
  final Color? iconColor;
  final Widget Function(BuildContext)? valueBuilder;
  final VoidCallback? onTap;
  final SettingsItemType type;

  SettingsItem({
    required this.title,
    this.description,
    this.icon,
    this.iconColor,
    this.valueBuilder,
    this.onTap,
    required this.type,
  });
}
