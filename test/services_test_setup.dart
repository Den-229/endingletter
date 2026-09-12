/// Helpers pour les tests unitaires des services dépendant de sqflite.
///
/// Initialise `sqflite_common_ffi` et fournit une base in-memory avec le
/// même schéma que `DatabaseService` (mais sans le path_provider de l'OS).
library;

import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

int _dbCounter = 0;

class TestDb {
  TestDb(this.path, this.db, this.version);
  final String path;
  final Database db;
  final int version;
}

Future<TestDb> openTestDb({String? path, int version = 2}) async {
  // Path absolu dans /tmp pour ne pas dépendre du cwd de sqflite_common_ffi
  // qui stocke ses DB dans `.dart_tool/`. Chaque test a son propre fichier.
  final p = path ?? '/tmp/endingletter_test_${_dbCounter++}.sqlite';
  final file = File(p);
  if (file.existsSync()) await file.delete();
  final db = await databaseFactory.openDatabase(
    p,
    options: OpenDatabaseOptions(
      version: version,
      onCreate: (db, _) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 2) {
          await _createV2Only(db);
        }
      },
    ),
  );
  return TestDb(p, db, version);
}

Future<void> closeAndDeleteTestDb(TestDb testDb) async {
  await testDb.db.close();
  final file = File(testDb.path);
  if (file.existsSync()) await file.delete();
}

void initSqfliteForTests() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

Future<void> _createSchema(Database db) async {
  await db.execute('''
    CREATE TABLE words (
      word           TEXT PRIMARY KEY NOT NULL,
      length         INTEGER NOT NULL,
      first_letter   TEXT NOT NULL,
      last_letter    TEXT NOT NULL,
      frequency      REAL NOT NULL DEFAULT 1.0,
      category       TEXT NOT NULL DEFAULT 'general',
      source_version TEXT NOT NULL
    )
  ''');
  await db.execute(
      'CREATE INDEX idx_words_first_letter ON words(first_letter)');
  await db.execute(
      'CREATE INDEX idx_words_last_letter  ON words(last_letter)');
  await db.execute('CREATE INDEX idx_words_category     ON words(category)');
  await db.execute('CREATE INDEX idx_words_length       ON words(length)');

  await db.execute('''
    CREATE TABLE dictionary_meta (
      key   TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE api_validated_words (
      word         TEXT PRIMARY KEY,
      validated_at INTEGER NOT NULL,
      hits         INTEGER NOT NULL DEFAULT 1
    )
  ''');

  await db.execute('''
    CREATE TABLE pending_reports (
      id         INTEGER PRIMARY KEY AUTOINCREMENT,
      word       TEXT NOT NULL,
      reason     TEXT NOT NULL,
      comment    TEXT,
      created_at INTEGER NOT NULL,
      synced     INTEGER NOT NULL DEFAULT 0
    )
  ''');
  await db.execute(
      'CREATE INDEX idx_pending_reports_synced ON pending_reports(synced)');

  await _createV2Only(db);
}

Future<void> _createV2Only(Database db) async {
  await db.execute('''
    CREATE TABLE dictionary_sync_state (
      local_sha256   TEXT PRIMARY KEY,
      remote_version TEXT NOT NULL,
      remote_sha256  TEXT NOT NULL,
      applied_at     INTEGER NOT NULL,
      source         TEXT NOT NULL DEFAULT 'firestore'
    )
  ''');
  await db.execute(
      'CREATE INDEX idx_sync_state_applied_at ON dictionary_sync_state(applied_at)');

  await db.execute('''
    CREATE TABLE lan_sessions (
      session_id      TEXT PRIMARY KEY,
      role            TEXT NOT NULL,
      peer_name       TEXT,
      peer_host       TEXT,
      peer_port       INTEGER,
      history_json    TEXT NOT NULL,
      current_player  INTEGER NOT NULL,
      required_letter TEXT,
      started_at      INTEGER NOT NULL,
      ended_at        INTEGER
    )
  ''');
  await db.execute(
      'CREATE INDEX idx_lan_sessions_role ON lan_sessions(role, ended_at)');
}