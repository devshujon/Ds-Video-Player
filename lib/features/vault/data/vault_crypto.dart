import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Authenticated, chunked file encryption for the private vault.
///
/// Layout on disk:
///
///   header (13 bytes):
///     magic "DSVB"          [4]
///     version              [1]   (= 1)
///     master_nonce_prefix  [8]   (random per file)
///
///   for each chunk i = 0, 1, …:
///     cipher_length        [4]   big-endian uint32
///     ciphertext           [cipher_length]
///     gcm_tag              [16]
///
/// Per-chunk 12-byte nonce = master_nonce_prefix(8) || chunk_index_be(4).
/// The random prefix gives ~2⁶⁴ unique values per file; chunk_index keeps
/// nonces unique *within* a file. Combined, no AES-GCM nonce is ever
/// reused under a given key — the only correctness invariant that matters.
///
/// Chunks of 4 MiB balance throughput, memory, and tag overhead (16 B per
/// chunk → ~0.0004% overhead for video-sized files).
class VaultCrypto {
  VaultCrypto({Random? random, this.chunkSize = _defaultChunkSize})
      : _random = random ?? Random.secure(),
        assert(chunkSize > 0, 'chunkSize must be positive');

  final Random _random;
  final AesGcm _algo = AesGcm.with256bits();

  /// Chunk size in bytes. Tunable for tests; production callers should
  /// leave this at the default so vault files stay binary-compatible.
  final int chunkSize;

  static const int _defaultChunkSize = 4 * 1024 * 1024; // 4 MiB
  static const int _magic0 = 0x44; // 'D'
  static const int _magic1 = 0x53; // 'S'
  static const int _magic2 = 0x56; // 'V'
  static const int _magic3 = 0x42; // 'B'
  static const int _version = 1;
  static const int _masterNoncePrefixLen = 8;
  static const int _headerLen = 4 + 1 + _masterNoncePrefixLen;
  static const int _tagLen = 16; // AES-GCM tag size in bytes.

  Future<void> encryptFile({
    required File input,
    required File output,
    required List<int> keyBytes,
    void Function(double fraction)? onProgress,
  }) async {
    _assertKey(keyBytes);
    final secretKey = SecretKey(keyBytes);
    final masterNoncePrefix = _randomBytes(_masterNoncePrefixLen);

    final totalSize = await input.length();
    final sink = output.openWrite();
    try {
      sink
        ..add(const [_magic0, _magic1, _magic2, _magic3])
        ..add(const [_version])
        ..add(masterNoncePrefix);

      var chunkIndex = 0;
      var processed = 0;
      final buffer = BytesBuilder(copy: false);

      await for (final block in input.openRead()) {
        buffer.add(block);
        while (buffer.length >= chunkSize) {
          final all = buffer.takeBytes();
          var offset = 0;
          while (all.length - offset >= chunkSize) {
            final chunk = Uint8List.sublistView(
              all,
              offset,
              offset + chunkSize,
            );
            await _writeChunk(
              sink: sink,
              secretKey: secretKey,
              masterNoncePrefix: masterNoncePrefix,
              chunkIndex: chunkIndex++,
              chunk: chunk,
            );
            offset += chunkSize;
            processed += chunkSize;
            onProgress?.call(processed / totalSize);
          }
          if (offset < all.length) {
            buffer.add(Uint8List.sublistView(all, offset));
          }
        }
      }

      if (buffer.length > 0) {
        final tail = buffer.takeBytes();
        await _writeChunk(
          sink: sink,
          secretKey: secretKey,
          masterNoncePrefix: masterNoncePrefix,
          chunkIndex: chunkIndex,
          chunk: tail,
        );
        processed += tail.length;
        onProgress?.call(processed / totalSize);
      }
    } finally {
      await sink.flush();
      await sink.close();
    }
  }

  Future<void> decryptFile({
    required File input,
    required File output,
    required List<int> keyBytes,
    void Function(double fraction)? onProgress,
  }) async {
    _assertKey(keyBytes);
    final secretKey = SecretKey(keyBytes);
    final raf = await input.open();
    final out = output.openWrite();
    try {
      final totalSize = await input.length();
      final header = await raf.read(_headerLen);
      if (header.length != _headerLen ||
          header[0] != _magic0 ||
          header[1] != _magic1 ||
          header[2] != _magic2 ||
          header[3] != _magic3) {
        throw const FormatException('Not a DS vault blob (bad magic)');
      }
      if (header[4] != _version) {
        throw FormatException('Unsupported vault version: ${header[4]}');
      }
      final masterNoncePrefix =
          header.sublist(5, 5 + _masterNoncePrefixLen);

      var chunkIndex = 0;
      var pos = _headerLen;
      while (pos < totalSize) {
        final lenBytes = await raf.read(4);
        if (lenBytes.length != 4) {
          throw const FormatException('Truncated vault blob (length)');
        }
        final cipherLen =
            ByteData.sublistView(Uint8List.fromList(lenBytes)).getUint32(0);
        final cipherText = await raf.read(cipherLen);
        final mac = await raf.read(_tagLen);
        if (cipherText.length != cipherLen || mac.length != _tagLen) {
          throw const FormatException('Truncated vault blob (chunk)');
        }
        final nonce = _chunkNonce(masterNoncePrefix, chunkIndex);
        final plain = await _algo.decrypt(
          SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
          secretKey: secretKey,
        );
        out.add(plain);
        chunkIndex++;
        pos += 4 + cipherLen + _tagLen;
        onProgress?.call(pos / totalSize);
      }
    } finally {
      await raf.close();
      await out.flush();
      await out.close();
    }
  }

  Future<void> _writeChunk({
    required IOSink sink,
    required SecretKey secretKey,
    required List<int> masterNoncePrefix,
    required int chunkIndex,
    required List<int> chunk,
  }) async {
    final nonce = _chunkNonce(masterNoncePrefix, chunkIndex);
    final box = await _algo.encrypt(
      chunk,
      secretKey: secretKey,
      nonce: nonce,
    );
    final cipher = box.cipherText;
    final mac = box.mac.bytes;
    sink
      ..add(_u32be(cipher.length))
      ..add(cipher)
      ..add(mac);
  }

  Uint8List _chunkNonce(List<int> masterPrefix, int chunkIndex) {
    final n = Uint8List(12);
    n.setRange(0, _masterNoncePrefixLen, masterPrefix);
    ByteData.sublistView(n).setUint32(
      _masterNoncePrefixLen,
      chunkIndex,
      Endian.big,
    );
    return n;
  }

  Uint8List _u32be(int v) {
    final b = Uint8List(4);
    ByteData.sublistView(b).setUint32(0, v, Endian.big);
    return b;
  }

  Uint8List _randomBytes(int n) {
    final b = Uint8List(n);
    for (var i = 0; i < n; i++) {
      b[i] = _random.nextInt(256);
    }
    return b;
  }

  void _assertKey(List<int> key) {
    if (key.length != 32) {
      throw ArgumentError(
        'AES-256 vault key must be 32 bytes; got ${key.length}.',
      );
    }
  }
}

/// Hex-decodes the 64-char SHA-256 string that `SecureStorageService`
/// returns into the 32 raw bytes AES-256 needs.
List<int> vaultKeyFromHex(String hex) {
  if (hex.length != 64) {
    throw ArgumentError(
      'Expected 64 hex chars (32 bytes); got ${hex.length}.',
    );
  }
  final out = Uint8List(32);
  for (var i = 0; i < 32; i++) {
    out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}
