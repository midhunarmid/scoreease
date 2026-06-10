import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:scoreease/core/utils/theme.dart';
import 'package:scoreease/core/utils/version_story.dart';
import 'package:scoreease/core/widgets/web_optimised_widget.dart';
import 'package:package_info_plus/package_info_plus.dart';

class VersionHistoryScreen extends StatelessWidget {
  static const routeName = 'version_history';

  const VersionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appColors.screenBg,
      appBar: AppBar(
        title: const Text('Version History'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: appColors.textColor,
      ),
      body: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final currentBuildNumber =
              int.tryParse(snapshot.data!.buildNumber) ?? 0;

          // Split and sort keys
          final allKeys = ScoreEaseVersionStory.versionStoryMap.keys.toList()
            ..sort((a, b) => int.parse(b).compareTo(int.parse(a)));

          final futureKeys =
              allKeys.where((k) => int.parse(k) > currentBuildNumber).toList();
          final pastKeys =
              allKeys.where((k) => int.parse(k) <= currentBuildNumber).toList();

          return Center(
            child: Container(
              padding: WebOptimisedWidget.getWebOptimisedHorizonatalPadding(),
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
                children: [
                  if (futureKeys.isNotEmpty) ...[
                    _buildRoadmapHeader(context)
                        .animate()
                        .fade(duration: 500.ms)
                        .slideY(begin: 0.1, end: 0),
                    ...List.generate(futureKeys.length, (index) {
                      final version = ScoreEaseVersionStory
                          .versionStoryMap[futureKeys[index]]!;
                      return _buildRoadmapNode(context, version)
                          .animate()
                          .fade(duration: 500.ms, delay: (100 * (index + 1)).ms)
                          .slideY(begin: 0.1, end: 0);
                    }),
                    SizedBox(height: 16.h),
                  ],
                  ...List.generate(pastKeys.length, (index) {
                    final version =
                        ScoreEaseVersionStory.versionStoryMap[pastKeys[index]]!;
                    final isLast = index == pastKeys.length - 1;
                    return _buildVersionNode(context, version, isLast)
                        .animate()
                        .fade(
                            duration: 500.ms,
                            delay: (100 * (futureKeys.length + index + 1)).ms)
                        .slideY(begin: 0.1, end: 0);
                  }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRoadmapHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 40.w,
          child: Container(
            width: 24.w,
            height: 24.w,
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.amber, width: 2),
            ),
            child: Icon(Icons.rocket_launch_rounded,
                size: 14.w, color: Colors.amber),
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: 16.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Upcoming Roadmap",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade700,
                      ),
                ),
                SizedBox(height: 4.h),
                Text(
                  "Here is a sneak peek into the future of ScoreEase.",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).hintColor,
                      ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoadmapNode(
      BuildContext context, ScoreEaseVersionStory version) {
    return Stack(
      children: [
        // Dashed line
        Positioned(
          left: 20.w - 1, // Center of the 40.w area
          top: 0,
          bottom: 0,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Flex(
                direction: Axis.vertical,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  (constraints.constrainHeight() / 6).floor(),
                  (index) => SizedBox(
                    width: 2,
                    height: 3,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.5)),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 40.w), // Empty space for dashed line to pass through
            SizedBox(width: 8.w),
            // Content Card
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: 24.h),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16.r),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "v${version.versionSemantic} ${version.versionName}",
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber.shade700,
                                    ),
                              ),
                              Text(
                                "Planned",
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: Colors.amber,
                                      fontStyle: FontStyle.italic,
                                    ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            version.tagline,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontStyle: FontStyle.italic,
                                  color: Colors.amber,
                                ),
                          ),
                          SizedBox(height: 12.h),
                          ...version.features.map((feature) =>
                              _buildFeatureBullet(context, feature,
                                  color: Colors.amber)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVersionNode(
      BuildContext context, ScoreEaseVersionStory version, bool isLast) {
    return Stack(
      children: [
        if (!isLast)
          Positioned(
            left: 20.w - 1,
            top: 20.w,
            bottom: 0,
            child: Container(
              width: 2,
              color: appColors.primaryColor.withValues(alpha: 0.3),
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline indicator
            SizedBox(
              width: 40.w,
              child: Container(
                width: 20.w,
                height: 20.w,
                decoration: BoxDecoration(
                  color: appColors.primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: appColors.screenBg, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: appColors.primaryColor.withValues(alpha: 0.4),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 8.w),
            // Content Card
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 24.h),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16.r),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: appColors.tileBgColor.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: appColors.primaryColor.withValues(alpha: 0.15),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "v${version.versionSemantic} ${version.versionName}",
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              Text(
                                version.buildDate,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: Theme.of(context).hintColor,
                                    ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            version.tagline,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontStyle: FontStyle.italic,
                                  color: appColors.primaryColor,
                                ),
                          ),
                          SizedBox(height: 12.h),
                          ...version.features.map((feature) =>
                              _buildFeatureBullet(context, feature)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureBullet(BuildContext context, String text,
      {Color? color}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 6.h, right: 8.w),
            child: CircleAvatar(
              radius: 3,
              backgroundColor:
                  color ?? appColors.textColor.withValues(alpha: 0.5),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style:
                  Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
