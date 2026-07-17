import 'dart:io';
import 'dart:typed_data';

import 'package:ds_video_player/features/vault/data/vault_crypto.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _key32(int seed) {
  final out = Uint8List(32);
  for (var i = 0; i < 32; i++) {
    out[i] = (seed + i) & 0xFF;
  }
  return out;
}

Future<Uint8List> _randomBytes(int n) async {
  final out = Uint8List(n);
  for (var i = 0; i < n; i++) {
    out[i] = (i * 31 + 7) & 0xFF; // deterministic, not security-sensitive
  }
  return out;
}

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('vaultcrypto');
  });

  tearDown(() async {
    if (await tmp.exists()) {
      await tmp.delete(recursive: true);
    }
  });

  group('VaultCrypto', () {
    test('round-trips a single-chunk file', () async {
      final crypto = VaultCrypto(chunkSize: 1024);
      final key = _key32(1);

      final plain = File('${tmp.path}/plain.bin');
      await plain.writeAsBytes(await _randomBytes(200));

      final blob = File('${tmp.path}/blob.dsv');
      await crypto.encryptFile(input: plain, output: blob, keyBytes: key);

      final restored = File('${tmp.path}/restored.bin');
      await crypto.decryptFile(input: blob, output: restored, keyBytes: key);

      expect(await restored.readAsBytes(), await plain.readAsBytes());
    });

    test('round-trips an empty file', () async {
      final crypto = VaultCrypto(chunkSize: 1024);
      final key = _key32(2);

      final plain = File('${tmp.path}/empty.bin')..createSync();
      final blob = File('${tmp.path}/empty.dsv');
      await crypto.encryptFile(input: plain, output: blob, keyBytes: key);

      final restored = File('${tmp.path}/restored.bin');
      await crypto.decryptFile(input: blob, output: restored, keyBytes: key);

      expect(await restored.readAsBytes(), isEmpty);
    });

    test('round-trips a multi-chunk file', () async {
      // 256-byte chunks × 5 chunks + a partial 50-byte tail.
      final crypto = VaultCrypto(chunkSize: 256);
      final key = _key32(3);

      final plain = File('${tmp.path}/multi.bin');
      await plain.writeAsBytes(await _randomBytes(256 * 5 + 50));

      final blob = File('${tmp.path}/multi.dsv');
      await crypto.encryptFile(input: plain, output: blob, keyBytes: key);

      final restored = File('${tmp.path}/multi.out');
      await crypto.decryptFile(input: blob, output: restored, keyBytes: key);

      expect(await restored.readAsBytes(), await plain.readAsBytes());
    });

    test('decryption fails on tampered ciphertext (GCM tag mismatch)',
        () async {
      final crypto = VaultCrypto(chunkSize: 1024);
      final key = _key32(4);

      final plain = File('${tmp.path}/x.bin');
      await plain.writeAsBytes(await _randomBytes(500));

      final blob = File('${tmp.path}/x.dsv');
      await crypto.encryptFile(input: plain, output: blob, keyBytes: key);

      // Flip a single byte deep inside the first chunk's ciphertext.
      final bytes = await blob.readAsBytes();
      final mutated = Uint8List.fromList(bytes);
      const tamperOffset = 30; // header is 13B, length prefix 4B, then cipher
      mutated[tamperOffset] = mutated[tamperOffset] ^ 0xFF;
      await blob.writeAsBytes(mutated);

      expect(
        () async => crypto.decryptFile(
          input: blob,
          output: File('${tmp.path}/x.out'),
          keyBytes: key,
        ),
        throwsA(anything),
      );
    });

    test('decryption fails with the wrong key', () async {
      final crypto = VaultCrypto(chunkSize: 1024);
      final right = _key32(5);
      final wrong = _key32(99);

      final plain = File('${tmp.path}/y.bin');
      await plain.writeAsBytes(await _randomBytes(300));

      final blob = File('${tmp.path}/y.dsv');
      await crypto.encryptFile(input: plain, output: blob, keyBytes: right);

      expect(
        () async => crypto.decryptFile(
          input: blob,
          output: File('${tmp.path}/y.out'),
          keyBytes: wrong,
        ),
        throwsA(anything),
      );
    });

    test('rejects keys that are not 32 bytes', () async {
      final crypto = VaultCrypto();
      final plain = File('${tmp.path}/z.bin');
      await plain.writeAsBytes(await _randomBytes(10));
      expect(
        () async => crypto.encryptFile(
          input: plain,
          output: File('${tmp.path}/z.dsv'),
          keyBytes: List<int>.filled(16, 0),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('decrypt rejects a non-vault blob (bad magic)', () async {
      final crypto = VaultCrypto();
      final fake = File('${tmp.path}/fake.bin');
      await fake.writeAsBytes(List.filled(50, 0xAA));
      expect(
        () async => crypto.decryptFile(
          input: fake,
          output: File('${tmp.path}/out.bin'),
          keyBytes: _key32(7),
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('vaultKeyFromHex', () {
    test('decodes a 64-char hex string to 32 bytes', () {
      final hex = '0a' * 32;
      final bytes = vaultKeyFromHex(hex);
      expect(bytes, hasLength(32));
      expect(bytes.every((b) => b == 0x0a), isTrue);
    });

    test('rejects wrong-length input', () {
      expect(() => vaultKeyFromHex('abcd'), throwsArgumentError);
    });
  });
}
