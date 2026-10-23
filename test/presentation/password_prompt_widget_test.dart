import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scoreease/core/widgets/password_prompt_widget.dart';

void main() {
  Future<void> pumpPrompt(
    WidgetTester tester, {
    required Future<bool> Function(String) onVerify,
    required VoidCallback onSuccess,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: PasswordPromptWidget(
        onVerify: onVerify,
        title: 'Protected Scoreboard',
        message: 'Enter the read password.',
        onSuccess: onSuccess,
        onCancel: () {},
      ),
    ));
    await tester.pump(const Duration(seconds: 2));
  }

  testWidgets('shows an error for a wrong password', (tester) async {
    var unlocked = false;
    await pumpPrompt(tester, onVerify: (_) async => false, onSuccess: () => unlocked = true);

    await tester.enterText(find.byType(TextField), 'nope');
    await tester.tap(find.text('Unlock'));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Incorrect password. Please try again.'), findsOneWidget);
    expect(unlocked, isFalse);
  });

  testWidgets('passes the typed password to onVerify and unlocks', (tester) async {
    String? checked;
    var unlocked = false;
    await pumpPrompt(
      tester,
      onVerify: (password) async {
        checked = password;
        return true;
      },
      onSuccess: () => unlocked = true,
    );

    await tester.enterText(find.byType(TextField), 'letmein');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(seconds: 1));

    expect(checked, 'letmein');
    expect(unlocked, isTrue);
  });

  testWidgets('explains a connection failure', (tester) async {
    await pumpPrompt(tester, onVerify: (_) async => throw Exception('offline'), onSuccess: () {});

    await tester.enterText(find.byType(TextField), 'letmein');
    await tester.tap(find.text('Unlock'));
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining("Couldn't check the password"), findsOneWidget);
  });
}
