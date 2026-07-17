import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ds_video_player/core/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('AppDatabase opens in-memory under 700ms', () async {
    final db = AppDatabase(overridePath: inMemoryDatabasePath);
    final sw = Stopwatch()..start();
    await db.database;
    sw.stop();
    expect(sw.elapsedMilliseconds, lessThan(700));
    await db.close();
  });
}
