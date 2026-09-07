// test/test_db.dart — SQLite in memoria con lo schema reale, condiviso dai test
import 'package:flight_chat/core/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Apre un database in memoria applicando lo **stesso** `onCreate` e
/// `onConfigure` della produzione: se lo schema cambia, i test lo vedono.
Future<DatabaseService> openTestDb() async {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;
  final db = await factory.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: DatabaseService.schemaVersion,
      onConfigure: DatabaseService.onConfigure,
      onCreate: DatabaseService.onCreate,
    ),
  );
  return DatabaseService.forTesting(db);
}

const String testKey =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

const String otherKey =
    'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';
