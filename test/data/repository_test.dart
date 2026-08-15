import 'package:flutter_test/flutter_test.dart';
import 'package:roulette_lab/data/database/app_database.dart';
import 'package:roulette_lab/data/repositories/sqlite_app_repository.dart';
import 'package:roulette_lab/domain/entities/prediction.dart';
import 'package:roulette_lab/domain/entities/spin.dart';
import 'package:roulette_lab/domain/repositories/app_repository.dart';
import 'package:roulette_lab/domain/services/prediction/adaptive_ensemble_engine.dart';
import 'package:roulette_lab/domain/services/prediction/wheel_distance_engine.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late AppDatabase database;
  late SqliteAppRepository repository;

  setUp(() {
    database = AppDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    repository = SqliteAppRepository(database);
  });

  tearDown(() => database.close());

  test('schema v1 en CRUD houden chronologische posities intact', () async {
    await repository.addSpin(8);
    await repository.addSpin(8);
    await repository.addSpin(14);
    AppSnapshot snapshot = await repository.loadSnapshot();
    expect(snapshot.spins.map((Spin spin) => spin.number), <int>[8, 8, 14]);
    expect(snapshot.spins.map((Spin spin) => spin.position), <int>[1, 2, 3]);

    await repository.editSpin(snapshot.spins[1].id!, 0);
    snapshot = await repository.loadSnapshot();
    expect(snapshot.spins.map((Spin spin) => spin.number), <int>[8, 0, 14]);

    await repository.deleteSpin(snapshot.spins.first.id!);
    snapshot = await repository.loadSnapshot();
    expect(snapshot.spins.map((Spin spin) => spin.number), <int>[0, 14]);
    expect(snapshot.spins.map((Spin spin) => spin.position), <int>[1, 2]);
  });

  test(
    'actieve voorspellingen worden atomair op volgende draai geëvalueerd',
    () async {
      for (final int number in <int>[0, 21, 30, 24]) {
        await repository.addSpin(number);
      }
      final AppSnapshot before = await repository.loadSnapshot();
      final List<PredictionRecord> active = <PredictionRecord>[
        PredictionRecord.fromResult(
          result: const WheelDistanceEngine().predict(before.spins),
          targetPosition: 5,
        ),
        PredictionRecord.fromResult(
          result: const AdaptiveEnsembleEngine().predict(before.spins),
          targetPosition: 5,
        ),
      ];
      await repository.saveActivePredictions(active);
      await repository.addSpin(29);
      final AppSnapshot after = await repository.loadSnapshot();
      expect(after.spins, hasLength(5));
      expect(after.predictions, hasLength(2));
      expect(
        after.predictions.every(
          (PredictionRecord record) =>
              record.status == PredictionStatus.evaluated &&
              record.actualNumber == 29 &&
              record.logLoss!.isFinite &&
              record.brierScore!.isFinite,
        ),
        isTrue,
      );
    },
  );

  test('bewerken of verwijderen invalideert afhankelijke evaluaties', () async {
    for (final int number in <int>[1, 2, 3, 4]) {
      await repository.addSpin(number);
    }
    AppSnapshot snapshot = await repository.loadSnapshot();
    await repository.saveActivePredictions(<PredictionRecord>[
      PredictionRecord.fromResult(
        result: const WheelDistanceEngine().predict(snapshot.spins),
        targetPosition: 5,
      ),
    ]);
    await repository.addSpin(5);
    snapshot = await repository.loadSnapshot();
    await repository.editSpin(snapshot.spins[1].id!, 20);
    snapshot = await repository.loadSnapshot();
    expect(snapshot.predictions.single.status, PredictionStatus.invalidated);
  });

  test(
    'bulkimport van 10.000 draaien blijft transactioneel en geordend',
    () async {
      final DateTime now = DateTime.utc(2026);
      final List<Spin> input = <Spin>[
        for (int i = 0; i < 10000; i++)
          Spin(
            id: null,
            position: i + 1,
            number: (i * 19) % 37,
            createdAtUtc: now,
            updatedAtUtc: now,
          ),
      ];
      await repository.importSpins(input, replace: true);
      final AppSnapshot snapshot = await repository.loadSnapshot();
      expect(snapshot.spins, hasLength(10000));
      expect(snapshot.spins.first.position, 1);
      expect(snapshot.spins.last.position, 10000);
      expect(snapshot.spins.last.number, (9999 * 19) % 37);
    },
  );
}
