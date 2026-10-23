import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:scoreease/core/utils/theme.dart';
import 'package:scoreease/core/utils/widget_helper.dart';

/// A titled card grouping related fields on the scoreboard editor.
class EditorSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final IconData? icon;
  final Widget? action;

  const EditorSection({Key? key, required this.title, required this.children, this.icon, this.action})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 24.h),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: appColors.primaryColor.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: appColors.primaryColor, size: 20.sp),
                  SizedBox(width: 8.w),
                ],
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold, color: appColors.primaryColor)),
                const Spacer(),
                if (action != null) action!,
              ],
            ),
          ),
          Divider(height: 1, color: appColors.primaryColor.withValues(alpha: 0.1)),
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

/// A password field with a "remove" checkbox, used for each access level.
class EditorPasswordField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool removeFlag;
  final ValueChanged<bool?> onChanged;

  const EditorPasswordField({
    Key? key,
    required this.label,
    required this.controller,
    required this.removeFlag,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        getTextInputWidget(
          context: context,
          label: label,
          hint: removeFlag ? "Password removed" : "Leave empty to keep existing",
          controller: controller,
          prefixIcon: const Icon(Icons.lock_outline),
          enabled: !removeFlag,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text("Remove $label Access",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: removeFlag ? Colors.red : null)),
              Checkbox(
                value: removeFlag,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
