import 'package:ds_video_player/features/vault/presentation/widgets/vault_pin_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  testWidgets('VaultPinStrength labels stronger PIN', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VaultPinStrength(pin: '864209'),
        ),
      ),
    );
    expect(find.text('Good'), findsOneWidget);
  });
}
