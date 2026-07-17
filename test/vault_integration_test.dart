import 'dart:io';

import 'package:ds_video_player/core/constants/app_constants.dart';
import 'package:ds_video_player/core/database/app_database.dart';
import 'package:ds_video_player/core/services/secure_storage_service.dart';
import 'package:ds_video_player/features/vault/data/vault_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// End-to-end vault persistence: encrypt → list → restart repo → still listed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('vault survives repository re-open (simulated restart)', () async {
    final dbPath = inMemoryDatabasePath;
    final tmp = await Directory.systemTemp.createTemp('vault_int');
    final secure = _FakeSecure();

    VaultRepository repo1 = VaultRepositoryImpl(
      db: AppDatabase(overridePath: dbPath),
      secure: secure,
      vaultDirOverride: () async => Directory('${tmp.path}/blobs'),
    );

    await secure.setPin('1234');
    final plain = File('${tmp.path}/video.mp4');
    await plain.writeAsBytes(List<int>.generate(500, (i) => i % 200));

    final item = await repo1.importFile(
      plain,
      originalName: 'video.mp4',
      originalUri: plain.path,
    );
    expect(item.id, greaterThan(0));

    // Simulate app restart with same DB + secure store.
    final repo2 = VaultRepositoryImpl(
      db: AppDatabase(overridePath: dbPath),
      secure: secure,
      vaultDirOverride: () async => Directory('${tmp.path}/blobs'),
    );
    final listed = await repo2.list();
    expect(listed, hasLength(1));
    expect(listed.first.originalName, 'video.mp4');
    expect(listed.first.blobAvailable, isTrue);

    final dup = await repo2.importFile(
      plain,
      originalName: 'video.mp4',
      originalUri: plain.path,
    );
    expect(dup.id, item.id);

    final blob = File(listed.first.vaultPath);
    await blob.delete();
    final purged = await repo2.purgeMissingBlobs();
    expect(purged, 1);
    expect(await repo2.list(), isEmpty);
  });
}

class _FakeSecure extends SecureStorageService {
  final Map<String, String> _mem = {};

  @override
  Future<void> setPin(String pin) async =>
      _mem[AppConstants.kPinHash] = pin;

  @override
  Future<String> getOrCreateVaultKey() async =>
      _mem.putIfAbsent(AppConstants.kVaultKey, () => '0a' * 32);
}
