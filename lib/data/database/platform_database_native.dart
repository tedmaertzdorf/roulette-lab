import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as mobile;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<({DatabaseFactory factory, String path})>
createDatabaseConfiguration() async {
  final Directory directory = await getApplicationSupportDirectory();
  await directory.create(recursive: true);
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    return (
      factory: databaseFactoryFfi,
      path: p.join(directory.path, 'roulette_lab.sqlite'),
    );
  }
  return (
    factory: mobile.databaseFactory,
    path: p.join(directory.path, 'roulette_lab.sqlite'),
  );
}
