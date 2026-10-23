import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scoreease/core/utils/theme.dart';

/// Asks for an exact score. Returns the new score, or null if cancelled.
Future<int?> showCustomScoreDialog({
  required BuildContext context,
  required String playerName,
  required int currentScore,
}) {
  final controller = TextEditingController(text: currentScore.toString());
  return showDialog<int>(
    context: context,
    builder: (ctx) {
      void save() => Navigator.pop(ctx, int.tryParse(controller.text) ?? currentScore);

      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          "Edit score for $playerName",
          style: Theme.of(ctx)
              .textTheme
              .labelLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(signed: true),
          autofocus: true,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
          ],
          onSubmitted: (_) => save(),
          style: Theme.of(ctx).textTheme.labelMedium,
          decoration: InputDecoration(
            labelText: "Score",
            filled: true,
            fillColor: appColors.inputBgFill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "Cancel",
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: appColors.pleasantButtonBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: save,
            child: Text(
              "Save",
              style: TextStyle(color: appColors.buttonTextColor),
            ),
          ),
        ],
      );
    },
  ).whenComplete(controller.dispose);
}
