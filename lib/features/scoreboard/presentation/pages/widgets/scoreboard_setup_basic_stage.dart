import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:scoreease/core/utils/input_case_text_formatter.dart';
import 'package:scoreease/core/utils/message_generator.dart';
import 'package:scoreease/core/utils/theme.dart';
import 'package:scoreease/core/utils/widget_helper.dart';
import 'package:scoreease/core/widgets/animated_container.dart';

class ScoreboardSetupBasicStage extends StatelessWidget {
  final TextEditingController idController;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController authorController;
  final VoidCallback onNext;

  const ScoreboardSetupBasicStage({
    Key? key,
    required this.idController,
    required this.titleController,
    required this.descriptionController,
    required this.authorController,
    required this.onNext,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 8.h),
        getTextInputWidget(
          context: context,
          label: MessageGenerator.getLabel('type in scoreboard name'),
          hint: MessageGenerator.getLabel('messironaldo'),
          controller: idController,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.next,
          prefixIcon: const Icon(Icons.key),
          maxLength: 50,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
            LengthLimitingTextInputFormatter(50),
            LowerCaseTextFormatter(),
          ],
        ),
        SizedBox(height: 8.h),
        getTextInputWidget(
          context: context,
          label: MessageGenerator.getLabel('type in title'),
          hint: MessageGenerator.getLabel('Messi vs Ronaldo'),
          controller: titleController,
          keyboardType: TextInputType.name,
          textInputAction: TextInputAction.next,
          prefixIcon: const Icon(Icons.title),
          maxLength: 100,
          inputFormatters: [
            LengthLimitingTextInputFormatter(100),
          ],
        ),
        SizedBox(height: 8.h),
        getTextInputWidget(
          context: context,
          label: MessageGenerator.getLabel('type in description'),
          hint: MessageGenerator.getLabel(
              'Track the eternal rivalry between Lionel Messi and Cristiano Ronaldo with this simple, real-time scoreboard. Update scores, log moments, and settle debates — who\'s leading in your books?'),
          controller: descriptionController,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          minLines: 5,
          maxLines: 5,
          prefixIcon: const Icon(Icons.description),
          maxLength: 500,
          inputFormatters: [
            LengthLimitingTextInputFormatter(500),
          ],
        ),
        SizedBox(height: 8.h),
        getTextInputWidget(
          context: context,
          label: MessageGenerator.getLabel('type in author'),
          hint: MessageGenerator.getLabel('Midhun Mohanan'),
          controller: authorController,
          keyboardType: TextInputType.name,
          textInputAction: TextInputAction.next,
          prefixIcon: const Icon(Icons.person_2_outlined),
          maxLength: 20,
          inputFormatters: [
            LengthLimitingTextInputFormatter(20),
          ],
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: AnimatedClickableTextContainer(
                  title: 'Next: Draft Players ➔',
                  iconSrc: '',
                  isActive: false,
                  bgColor: appColors.pleasantButtonBg,
                  bgColorHover: appColors.pleasantButtonBgHover,
                  press: () {
                    HapticFeedback.lightImpact();
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
