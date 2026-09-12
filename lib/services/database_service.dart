import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Gestionnaire de la base SQLite locale.
///
/// Schéma (v2) :
///   words                — dictionnaire principal
///   dictionary_meta      — métadonnées (version, checksum, etc.)
///   api_validated_words  — cache des mots validés via API externe
///   pending_reports      — signalements en attente d'envoi (offline-first)
///   dictionary_sync_state — dernier manifest cloud appliqué (Phase 2)
///   lan_sessions         — sessions LAN en cours / récentes (Phase 3)
class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  static const String _dbFileName = 'endingletter.db';
  static const int _schemaVersion = 2;

  Database? _db;

  /// Ouvre (ou crée) la base de données et exécute les migrations.
  Future<Database> open() async {
    if (_db != null) return _db!;
    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docsDir.path, _dbFileName);
    _db = await openDatabase(
      dbPath,
      version: _schemaVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return _db!;
  }

  /// Accès direct à la base (à appeler après [open]).
  Database get db {
    final d = _db;
    if (d == null) {
      throw StateError('DatabaseService.open() doit être appelé avant db');
    }
    return d;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<void> _onCreate(Database db, int version) async {
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

    await _createV2Tables(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createV2Tables(db);
    }
  }

  Future<void> _createV2Tables(Database db) async {
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
}