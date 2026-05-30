import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:scoreease/core/utils/message_generator.dart';
import 'package:scoreease/core/utils/theme.dart';
import 'package:scoreease/core/utils/widget_helper.dart';
import 'package:scoreease/core/widgets/animated_container.dart';

class ScoreboardSetupAccessStage extends StatelessWidget {
  final TextEditingController readController;
  final TextEditingController writeController;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  const ScoreboardSetupAccessStage({
    Key? key,
    required this.readController,
    required this.writeController,
    required this.onNext,
    required this.onPrevious,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 16.h),
        Icon(Icons.lock_outline, size: 64.sp, color: appColors.primaryColor).animate().shake(hz: 4, duration: 600.ms),
        SizedBox(height: 16.h),
        Text(
          MessageGenerator.getMessage("scoreboard-setup-access-read-description"),
          style: Theme.of(context).textTheme.labelSmall,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 4.h),
        getTextInputWidget(
          context: context,
          label: MessageGenerator.getLabel('read password'),
          hint: MessageGenerator.getLabel('score@1234'),
          controller: readController,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.go,
          prefixIcon: const Icon(Icons.password_outlined),
          inputFormatters: [
            LengthLimitingTextInputFormatter(10),
          ],
        ),
        SizedBox(height: 8.h),
        Text(
          MessageGenerator.getMessage("scoreboard-setup-access-write-description"),
          style: Theme.of(context).textTheme.labelSmall,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 4.h),
        getTextInputWidget(
          context: context,
          label: MessageGenerator.getLabel('write password'),
          hint: MessageGenerator.getLabel('score@1234'),
          controller: writeController,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.go,
          prefixIcon: const Icon(Icons.password_outlined),
          inputFormatters: [
            LengthLimitingTextInputFormatter(10),
          ],
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: AnimatedClickableTextContainer(
                  title: '⟵ Back',
                  iconSrc: '',
                  isActive: false,
                  bgColor: appColors.inputBgFill,
                  bgColorHover: appColors.sideMenuHighlight,
                  textColor: appColors.textColor,
                  textColorHover: Theme.of(context).brightness == Brightness.light ? Colors.white : Colors.black,
                  press: () {
                    HapticFeedback.lightImpact();
                    onPrevious();
                  },
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: AnimatedClickableTextContainer(
                  title: '🏆 Finalize Scoreboard',
                  iconSrc: '',
                  isActive: false,
                  bgColor: appColors.pleasantButtonBg,
                  bgColorHover: appColors.pleasantButtonBgHover,
                  press: () {
                    HapticFeedback.mediumImpact();
                    onNext();
                  },
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16.h),
      ],
    );
  }
}
