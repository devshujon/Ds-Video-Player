/// Rejects weak or easily guessed vault PINs.
class VaultPinValidator {
  VaultPinValidator._();

  static const Set<String> _commonPins = {
    '0000', '1111', '2222', '3333', '4444', '5555', '6666', '7777', '8888',
    '9999', '1234', '4321', '1212', '1004', '2000', '2580',
    '123456', '654321', '111111', '000000', '123123', '112233',
  };

  /// Returns an error message when [pin] should be rejected, otherwise null.
  static String? validate(String pin) {
    if (pin.isEmpty) return null;
    if (!RegExp(r'^\d+$').hasMatch(pin)) {
      return 'PIN must contain digits only';
    }
    if (RegExp(r'^(\d)\1+$').hasMatch(pin)) {
      return 'Avoid repeating the same digit';
    }
    if (_isSequential(pin)) {
      return 'Avoid simple number sequences';
    }
    if (_commonPins.contains(pin)) {
      return 'This PIN is too easy to guess';
    }
    return null;
  }

  static bool _isSequential(String pin) {
    if (pin.length < 3) return false;
    var asc = true;
    var desc = true;
    for (var i = 1; i < pin.length; i++) {
      final prev = int.parse(pin[i - 1]);
      final cur = int.parse(pin[i]);
      if (cur != prev + 1) asc = false;
      if (cur != prev - 1) desc = false;
    }
    return asc || desc;
  }
}
