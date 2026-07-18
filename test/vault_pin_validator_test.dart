import 'package:ds_video_player/features/vault/domain/vault_pin_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VaultPinValidator', () {
    test('rejects repeating digits', () {
      expect(VaultPinValidator.validate('1111'), isNotNull);
      expect(VaultPinValidator.validate('000000'), isNotNull);
    });

    test('rejects sequential PINs', () {
      expect(VaultPinValidator.validate('1234'), isNotNull);
      expect(VaultPinValidator.validate('123456'), isNotNull);
      expect(VaultPinValidator.validate('4321'), isNotNull);
    });

    test('accepts reasonable PINs', () {
      expect(VaultPinValidator.validate('8642'), isNull);
      expect(VaultPinValidator.validate('592847'), isNull);
    });
  });
}
