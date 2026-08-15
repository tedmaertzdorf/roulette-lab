import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Uses SQLite/Wasm while persisting the database in browser IndexedDB.
Future<({DatabaseFactory factory, String path})>
createDatabaseConfiguration() async =>
    (factory: databaseFactoryFfiWeb, path: 'roulette_lab.sqlite');
