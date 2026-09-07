// lib/core/services/database_service.dart — SQLite singleton: apertura, schema e versioning
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._();

  factory DatabaseService() => _instance;

  DatabaseService._();

  /// ponytail: unico seam per i test. Il singleton apre un file su disco, i test
  /// passano qui un database SQLite in memoria gia aperto con lo stesso schema.
  DatabaseService.forTesting(Database db) : _db = db;

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'flightchat.db');
    return openDatabase(
      path,
      version: schemaVersion,
      onConfigure: onConfigure,
      onCreate: onCreate,
    );
  }

  /// `version` e lo schema versioning richiesto dal piano. Nessun `onUpgrade`
  /// finche non esiste una migrazione vera da scrivere.
  static const int schemaVersion = 1;

  /// DECISION: sqflite non applica le foreign key per default, quindi la
  /// FOREIGN KEY dichiarata su `messages` sarebbe decorativa senza questo pragma.
  static Future<void> onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  static Future<void> onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE groups (
        group_id TEXT PRIMARY KEY,
        group_name TEXT,
        encryption_key TEXT NOT NULL,
        t0 INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        role TEXT NOT NULL DEFAULT 'member'
      )
    ''');

    await db.execute('''
      CREATE TABLE messages (
        message_id TEXT PRIMARY KEY,
        group_id TEXT NOT NULL,
        sender_device_id TEXT NOT NULL,
        sender_name TEXT NOT NULL,
        sender_avatar_icon_index INTEGER NOT NULL DEFAULT 0,
        content_encrypted BLOB NOT NULL,
        time_delta INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'sent',
        is_mine INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (group_id) REFERENCES groups(group_id)
      )
    ''');

    // DECISION: `is_local` non e nello schema del piano, ma senza una colonna
    // che marchi il profilo del dispositivo il metodo `getLocalProfile()` che
    // il piano richiede non e implementabile.
    await db.execute('''
      CREATE TABLE user_profiles (
        device_id TEXT PRIMARY KEY,
        nickname TEXT NOT NULL,
        avatar_icon_index INTEGER NOT NULL DEFAULT 0,
        last_seen_delta INTEGER,
        is_local INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_messages_group ON messages(group_id, time_delta)',
    );
    await db.execute(
      'CREATE INDEX idx_messages_dedup ON messages(message_id)',
    );
  }
}
