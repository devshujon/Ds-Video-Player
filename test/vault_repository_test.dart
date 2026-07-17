import 'dart:io';

import 'package:ds_video_player/core/constants/app_constants.dart';
import 'package:ds_video_player/core/database/app_database.dart';
import 'package:ds_video_player/core/services/secure_storage_service.dart';
import 'package:ds_video_player/features/media_library/domain/entities/media_item.dart';
import 'package:ds_video_player/core/constants/media_formats.dart';
import 'package:ds_video_player/features/vault/data/vault_repository.dart';
import 'package:ds_video_player/features/vault/domain/entities/vault_category.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakeSecureStorage extends SecureStorageService {
  final Map<String, String> _mem = {};

  @override
  Future<bool> get hasPin async => _mem.containsKey(AppConstants.kPinHash);

  @override
  Future<void> setPin(String pin) async {
    _mem[AppConstants.kPinHash] = pin;
  }

  @override
  Future<bool> verifyPin(String pin) async => _mem[AppConstants.kPinHash] == pin;

  @override
  Future<String> getOrCreateVaultKey() async {
    return _mem.putIfAbsent(AppConstants.kVaultKey, () => '0a' * 32);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tmp;
  late AppDatabase appDb;
  late VaultRepository repo;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('vault_repo');
    appDb = AppDatabase(overridePath: inMemoryDatabasePath);
    await appDb.database;
    repo = VaultRepositoryImpl(
      db: appDb,
      secure: _FakeSecureStorage(),
      vaultDirOverride: () async => Directory('${tmp.path}/vault_store'),
    );
  });

  tearDown(() async {
    await appDb.close();
    if (await tmp.exists()) {
      await tmp.delete(recursive: true);
    }
  });

  test('imports, lists, and deletes vaulted files with metadata', () async {
    final plain = File('${tmp.path}/clip.mp4');
    await plain.writeAsBytes(List<int>.generate(1200, (i) => i % 251));

    final item = await repo.importFile(
      plain,
      originalName: 'clip.mp4',
      originalUri: plain.path,
      folderPath: '/storage/Movies',
      durationMs: 95000,
    );

    expect(item.category, VaultCategory.videos.id);
    expect(item.plaintextSizeBytes, 1200);
    expect(item.durationMs, 95000);

    final all = await repo.list();
    expect(all, hasLength(1));

    final counts = await repo.categoryCounts();
    expect(counts[VaultCategory.videos.id], 1);

    await repo.delete(item);
    expect(await repo.list(), isEmpty);
  });

  test('lockFromMediaItem classifies downloads path', () async {
    final downloadDir = Directory('${tmp.path}/Download');
    await downloadDir.create();
    final plain = File('${downloadDir.path}/song.mp3');
    await plain.writeAsBytes([1, 2, 3, 4]);

    final item = await repo.lockFromMediaItem(
      MediaItem(
        uri: plain.path,
        title: 'song.mp3',
        type: MediaType.audio,
        folderPath: downloadDir.path,
        sizeBytes: 4,
        durationMs: 0,
        dateAddedMs: 1,
        dateModifiedMs: 1,
      ),
    );

    expect(item.category, VaultCategory.downloads.id);
  });

  test('importing same uri twice returns existing item', () async {
    final plain = File('${tmp.path}/dup.mp4');
    await plain.writeAsBytes([1, 2, 3]);
    final first = await repo.importFile(
      plain,
      originalUri: '/storage/dup.mp4',
    );
    final second = await repo.importFile(
      plain,
      originalUri: '/storage/dup.mp4',
    );
    expect(second.id, first.id);
    expect(await repo.list(), hasLength(1));
  });
}
