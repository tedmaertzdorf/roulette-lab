import 'package:sqflite_common/sqlite_api.dart';

import 'platform_database_native.dart'
    if (dart.library.js_interop) 'platform_database_web.dart'
    as platform;

class AppDatabase {
  AppDatabase({required DatabaseFactory factory, required String path})
    : _factory = factory,
      _path = path;

  static const int schemaVersion = 1;
  final DatabaseFactory _factory;
  final String _path;
  Database? _database;

  static Future<AppDatabase> production() async {
    final ({DatabaseFactory factory, String path}) configuration =
        await platform.createDatabaseConfiguration();
    return AppDatabase(
      factory: configuration.factory,
      path: configuration.path,
    );
  }

  Future<Database>
  get database async => _database ??= await _factory.openDatabase(
    _path,
    options: OpenDatabaseOptions(
      version: schemaVersion,
      onConfigure: (Database db) async =>
          db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (Database db, int version) async {
        await db.execute('''
CREATE TABLE spins (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  position INTEGER NOT NULL UNIQUE,
  number INTEGER NOT NULL CHECK(number BETWEEN 0 AND 36),
  occurred_at_utc TEXT,
  created_at_utc TEXT NOT NULL,
  updated_at_utc TEXT NOT NULL
)''');
        await db.execute('CREATE INDEX idx_spins_number ON spins(number)');
        await db.execute('CREATE INDEX idx_spins_position ON spins(position)');
        await db.execute('''
CREATE TABLE predictions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  engine_id TEXT NOT NULL,
  engine_name TEXT NOT NULL,
  model_version INTEGER NOT NULL,
  history_fingerprint TEXT NOT NULL,
  based_on_spin_count INTEGER NOT NULL,
  target_position INTEGER NOT NULL,
  status TEXT NOT NULL CHECK(status IN ('active','evaluated','invalidated')),
  predicted_number INTEGER NOT NULL CHECK(predicted_number BETWEEN 0 AND 36),
  predicted_dozen INTEGER,
  top3_json TEXT NOT NULL,
  probabilities_json TEXT NOT NULL,
  dozen_probabilities_json TEXT NOT NULL,
  diagnostics_json TEXT NOT NULL,
  weights_json TEXT NOT NULL,
  model_strength REAL NOT NULL,
  actual_number INTEGER,
  exact_hit INTEGER,
  top3_hit INTEGER,
  dozen_hit INTEGER,
  log_loss REAL,
  brier_score REAL,
  created_at_utc TEXT NOT NULL,
  evaluated_at_utc TEXT
)''');
        await db.execute(
          'CREATE INDEX idx_predictions_engine_status ON predictions(engine_id, status)',
        );
        await db.execute(
          'CREATE INDEX idx_predictions_target ON predictions(target_position)',
        );
        await db.execute('''
CREATE TABLE app_meta (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
)''');
      },
    ),
  );

  Future<void> close() async {
    final Database? value = _database;
    _database = null;
    await value?.close();
  }
}
