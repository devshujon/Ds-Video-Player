import 'package:ds_video_player/features/vault/presentation/widgets/vault_numeric_keypad.dart';
import 'package:ds_video_player/features/vault/presentation/widgets/vault_pin_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('VaultNumericKeypad renders digits 0-9', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VaultNumericKeypad(
            onDigit: (_) {},
            onBackspace: () {},
          ),
        ),
      ),
    );

    for (final d in ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0']) {
      expect(find.text(d), findsOneWidget);
    }
    expect(find.byIcon(Icons.backspace_outlined), findsOneWidget);
  });

  testWidgets('VaultPinStrength labels weak PIN', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VaultPinStrength(pin: '12'),
        ),
      ),
    );
    expect(find.text('Too short'), findsOneWidget);
  });
}
