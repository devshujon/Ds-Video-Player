import 'dart:io';

import 'package:ds_video_player/core/constants/app_constants.dart';
import 'package:ds_video_player/core/constants/media_formats.dart';
import 'package:ds_video_player/core/database/app_database.dart';
import 'package:ds_video_player/core/services/secure_storage_service.dart';
import 'package:ds_video_player/core/utils/result.dart';
import 'package:ds_video_player/features/media_library/domain/entities/media_item.dart';
import 'package:ds_video_player/features/media_library/domain/entities/media_folder.dart';
import 'package:ds_video_player/features/media_library/domain/entities/scan_batch.dart';
import 'package:ds_video_player/features/media_library/domain/repositories/media_repository.dart';
import 'package:ds_video_player/features/media_library/domain/usecases/library_usecases.dart';
import 'package:ds_video_player/features/vault/data/vault_repository.dart';
import 'package:ds_video_player/features/vault/presentation/providers/vault_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakeSecureStorage extends SecureStorageService {
  final Map<String, String> _mem = {};

  @override
  Future<bool> get hasPin async => _mem.containsKey(AppConstants.kPinHash);

  @override
  Future<void> setPin(String pin) async => _mem[AppConstants.kPinHash] = pin;

  @override
  Future<bool> verifyPin(String pin) async =>
      _mem[AppConstants.kPinHash] == pin;

  @override
  Future<bool> get biometricsEnabled async => false;

  @override
  Future<void> setBiometricsEnabled(bool enabled) async {}

  @override
  Future<String> getOrCreateVaultKey() async =>
      _mem.putIfAbsent(AppConstants.kVaultKey, () => '0a' * 32);
}

class _FakeMediaRepository implements MediaRepository {
  final List<String> removed = [];

  @override
  Future<Result<void>> removeMedia(String uri) async {
    removed.add(uri);
    return const Success(null);
  }

  @override
  Future<Result<List<MediaItem>>> scan({bool force = false}) async =>
      const Success([]);

  @override
  Stream<Result<ScanBatch>> scanProgressive() async* {}

  @override
  Future<Result<List<MediaItem>>> getByType(MediaType type) async =>
      const Success([]);

  @override
  Future<Result<List<MediaFolder>>> getFolders() async => const Success([]);

  @override
  Future<Result<List<MediaItem>>> getFavorites() async => const Success([]);

  @override
  Future<Result<List<MediaItem>>> getRecentlyPlayed() async =>
      const Success([]);

  @override
  Future<Result<List<MediaItem>>> getHidden() async => const Success([]);

  @override
  Future<Result<List<MediaItem>>> search(String query) async =>
      const Success([]);

  @override
  Future<Result<void>> toggleFavorite(String uri) async =>
      const Success(null);

  @override
  Future<Result<void>> saveResume({
    required String uri,
    required int positionMs,
    required int durationMs,
  }) async =>
      const Success(null);

  @override
  Future<Result<void>> setFolderHidden(String path, bool hidden) async =>
      const Success(null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tmp;
  late AppDatabase appDb;
  late VaultRepository repo;
  late VaultProvider provider;
  late _FakeMediaRepository mediaRepo;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('vault_provider');
    appDb = AppDatabase(overridePath: inMemoryDatabasePath);
    await appDb.database;
    repo = VaultRepositoryImpl(
      db: appDb,
      secure: _FakeSecureStorage(),
      vaultDirOverride: () async => Directory('${tmp.path}/vault'),
    );
    mediaRepo = _FakeMediaRepository();
    provider = VaultProvider(
      _FakeSecureStorage(),
      repo,
      RemoveMedia(mediaRepo),
    );
  });

  tearDown(() async {
    await repo.deleteAll();
    await appDb.close();
    if (await tmp.exists()) {
      await tmp.delete(recursive: true);
    }
  });

  test('setupVault unlocks and lists encrypted items', () async {
    final ok = await provider.setupVault(
      pin: '1234',
      confirmPin: '1234',
      enableBiometrics: false,
    );
    expect(ok, isTrue);
    expect(provider.state, VaultState.unlocked);

    final file = File('${tmp.path}/secret.mp4');
    await file.writeAsBytes([9, 8, 7, 6]);
    await provider.importFile(file);
    expect(provider.totalItemCount, 1);
  });

  test('lockFromMediaItem removes library entry and deduplicates', () async {
    await provider.setupVault(
      pin: '1234',
      confirmPin: '1234',
      enableBiometrics: false,
    );

    final file = File('${tmp.path}/clip.mp4');
    await file.writeAsBytes([1, 2, 3]);
    final item = MediaItem(
      uri: file.path,
      title: 'clip.mp4',
      type: MediaType.video,
      folderPath: '/Movies',
      sizeBytes: 3,
      durationMs: 1000,
      dateAddedMs: 1,
      dateModifiedMs: 1,
    );

    final first = await provider.lockFromMediaItem(item);
    expect(first, isTrue);
    expect(mediaRepo.removed, contains(file.path));

    await file.writeAsBytes([1, 2, 3]);
    final dup = await provider.lockFromMediaItem(item);
    expect(dup, isFalse);
    expect(provider.totalItemCount, 1);
  });

  test('lock clears cached items', () async {
    await provider.setupVault(
      pin: '1234',
      confirmPin: '1234',
      enableBiometrics: false,
    );
    provider.lock();
    expect(provider.state, VaultState.locked);
    expect(provider.items, isEmpty);
  });
}
