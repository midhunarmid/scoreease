import 'package:flutter/services.dart';

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
    );
  }
}

class LowerCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(
      text: newValue.text.toLowerCase(),
    );
  }
}

/// Player and team names are used as database keys, which can't contain
/// `. # $ [ ] /`. Limits a name field to [maxLength] and drops those characters.
List<TextInputFormatter> nameKeyFormatters({int maxLength = 20}) => [
      FilteringTextInputFormatter.deny(RegExp(r'[.#$\[\]/]')),
      LengthLimitingTextInputFormatter(maxLength),
    ];
