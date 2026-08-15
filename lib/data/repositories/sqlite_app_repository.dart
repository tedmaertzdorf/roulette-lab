import 'dart:convert';

import 'package:sqflite_common/sqlite_api.dart';

import '../../core/constants/roulette_constants.dart';
import '../../core/math/probability_vector.dart';
import '../../domain/entities/prediction.dart';
import '../../domain/entities/spin.dart';
import '../../domain/repositories/app_repository.dart';
import '../../domain/services/evaluation/prediction_scorer.dart';
import '../database/app_database.dart';

class SqliteAppRepository implements AppRepository {
  const SqliteAppRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  @override
  Future<AppSnapshot> loadSnapshot() async {
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> spinRows = await db.query(
      'spins',
      orderBy: 'position ASC',
    );
    final List<Map<String, Object?>> predictionRows = await db.query(
      'predictions',
      orderBy: 'created_at_utc ASC, id ASC',
    );
    return AppSnapshot(
      spins: List<Spin>.unmodifiable(spinRows.map(_spinFromRow)),
      predictions: List<PredictionRecord>.unmodifiable(
        predictionRows.map(_predictionFromRow),
      ),
    );
  }

  @override
  Future<void> addSpin(int number, {DateTime? occurredAtUtc}) async {
    requireRouletteNumber(number);
    final Database db = await _appDatabase.database;
    await db.transaction((Transaction transaction) async {
      final int nextPosition = await _nextPosition(transaction);
      await _evaluateActiveFor(
        transaction,
        targetPosition: nextPosition,
        actualNumber: number,
      );
      final DateTime now = DateTime.now().toUtc();
      await transaction.insert('spins', <String, Object?>{
        'position': nextPosition,
        'number': number,
        'occurred_at_utc': occurredAtUtc?.toUtc().toIso8601String(),
        'created_at_utc': now.toIso8601String(),
        'updated_at_utc': now.toIso8601String(),
      });
    });
  }

  @override
  Future<void> editSpin(int id, int number, {DateTime? occurredAtUtc}) async {
    requireRouletteNumber(number);
    final Database db = await _appDatabase.database;
    await db.transaction((Transaction transaction) async {
      final List<Map<String, Object?>> rows = await transaction.query(
        'spins',
        columns: <String>['position'],
        where: 'id = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError('De gekozen draai bestaat niet meer.');
      }
      final int position = (rows.first['position'] as num).toInt();
      await transaction.update(
        'spins',
        <String, Object?>{
          'number': number,
          if (occurredAtUtc != null)
            'occurred_at_utc': occurredAtUtc.toUtc().toIso8601String(),
          'updated_at_utc': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
      await _invalidateFrom(transaction, position);
    });
  }

  @override
  Future<void> deleteSpin(int id) async {
    final Database db = await _appDatabase.database;
    await db.transaction((Transaction transaction) async {
      final List<Map<String, Object?>> rows = await transaction.query(
        'spins',
        columns: <String>['position'],
        where: 'id = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) {
        return;
      }
      final int position = (rows.first['position'] as num).toInt();
      await transaction.delete(
        'spins',
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
      await transaction.rawUpdate(
        'UPDATE spins SET position = position - 1, updated_at_utc = ? WHERE position > ?',
        <Object?>[DateTime.now().toUtc().toIso8601String(), position],
      );
      await _invalidateFrom(transaction, position);
    });
  }

  @override
  Future<void> clearSpins() async {
    final Database db = await _appDatabase.database;
    await db.transaction((Transaction transaction) async {
      await transaction.delete('spins');
      await transaction.update(
        'predictions',
        <String, Object?>{'status': PredictionStatus.invalidated.name},
        where: 'status != ?',
        whereArgs: <Object?>[PredictionStatus.invalidated.name],
      );
    });
  }

  @override
  Future<void> clearAllData() async {
    final Database db = await _appDatabase.database;
    await db.transaction((Transaction transaction) async {
      await transaction.delete('predictions');
      await transaction.delete('spins');
      await transaction.delete('app_meta');
    });
  }

  @override
  Future<void> importSpins(
    List<Spin> spins, {
    required bool replace,
    List<PredictionRecord> predictions = const <PredictionRecord>[],
  }) async {
    for (final Spin spin in spins) {
      requireRouletteNumber(spin.number);
    }
    final Database db = await _appDatabase.database;
    await db.transaction((Transaction transaction) async {
      int position;
      if (replace) {
        await transaction.delete('predictions');
        await transaction.delete('spins');
        position = 1;
      } else {
        position = await _nextPosition(transaction);
        if (spins.isNotEmpty) {
          await _evaluateActiveFor(
            transaction,
            targetPosition: position,
            actualNumber: spins.first.number,
          );
        }
      }
      for (final Spin spin in spins) {
        await transaction.insert('spins', <String, Object?>{
          'position': position++,
          'number': spin.number,
          'occurred_at_utc': spin.occurredAtUtc?.toUtc().toIso8601String(),
          'created_at_utc': spin.createdAtUtc.toUtc().toIso8601String(),
          'updated_at_utc': spin.updatedAtUtc.toUtc().toIso8601String(),
        });
      }
      if (replace) {
        for (final PredictionRecord prediction in predictions) {
          await transaction.insert('predictions', _predictionToRow(prediction));
        }
      }
    });
  }

  @override
  Future<List<PredictionRecord>> saveActivePredictions(
    List<PredictionRecord> predictions,
  ) async {
    final Database db = await _appDatabase.database;
    await db.transaction((Transaction transaction) async {
      for (final PredictionRecord prediction in predictions) {
        final List<Map<String, Object?>> existing = await transaction.query(
          'predictions',
          where: 'engine_id = ? AND status = ?',
          whereArgs: <Object?>[
            prediction.engineId,
            PredictionStatus.active.name,
          ],
        );
        final bool identical = existing.any(
          (Map<String, Object?> row) =>
              row['history_fingerprint'] == prediction.historyFingerprint &&
              row['target_position'] == prediction.targetPosition,
        );
        if (identical) {
          continue;
        }
        await transaction.update(
          'predictions',
          <String, Object?>{'status': PredictionStatus.invalidated.name},
          where: 'engine_id = ? AND status = ?',
          whereArgs: <Object?>[
            prediction.engineId,
            PredictionStatus.active.name,
          ],
        );
        await transaction.insert('predictions', _predictionToRow(prediction));
      }
    });
    final AppSnapshot snapshot = await loadSnapshot();
    return snapshot.predictions
        .where(
          (PredictionRecord value) => value.status == PredictionStatus.active,
        )
        .toList(growable: false);
  }

  @override
  Future<void> clearPredictionEvaluations() async {
    final Database db = await _appDatabase.database;
    await db.delete('predictions');
  }

  @override
  Future<void> invalidatePredictionsFrom(int targetPosition) async {
    final Database db = await _appDatabase.database;
    await db.transaction(
      (Transaction transaction) => _invalidateFrom(transaction, targetPosition),
    );
  }

  Future<int> _nextPosition(DatabaseExecutor executor) async {
    final List<Map<String, Object?>> rows = await executor.rawQuery(
      'SELECT COALESCE(MAX(position), 0) + 1 AS next_position FROM spins',
    );
    return (rows.first['next_position'] as num).toInt();
  }

  Future<void> _evaluateActiveFor(
    Transaction transaction, {
    required int targetPosition,
    required int actualNumber,
  }) async {
    final List<Map<String, Object?>> rows = await transaction.query(
      'predictions',
      where: 'status = ? AND target_position = ?',
      whereArgs: <Object?>[PredictionStatus.active.name, targetPosition],
    );
    for (final Map<String, Object?> row in rows) {
      final PredictionRecord evaluated = evaluatePrediction(
        _predictionFromRow(row),
        actualNumber,
      );
      await transaction.update(
        'predictions',
        _predictionToRow(evaluated),
        where: 'id = ?',
        whereArgs: <Object?>[evaluated.id],
      );
    }
  }

  Future<void> _invalidateFrom(
    DatabaseExecutor executor,
    int targetPosition,
  ) async {
    await executor.update(
      'predictions',
      <String, Object?>{'status': PredictionStatus.invalidated.name},
      where: 'target_position >= ? AND status != ?',
      whereArgs: <Object?>[targetPosition, PredictionStatus.invalidated.name],
    );
  }
}

Spin _spinFromRow(Map<String, Object?> row) => Spin(
  id: (row['id'] as num).toInt(),
  position: (row['position'] as num).toInt(),
  number: (row['number'] as num).toInt(),
  occurredAtUtc: _dateOrNull(row['occurred_at_utc']),
  createdAtUtc: DateTime.parse(row['created_at_utc'] as String).toUtc(),
  updatedAtUtc: DateTime.parse(row['updated_at_utc'] as String).toUtc(),
);

PredictionRecord _predictionFromRow(Map<String, Object?> row) {
  final Object? diagnosticsDecoded = jsonDecode(
    row['diagnostics_json'] as String,
  );
  final Object? weightsDecoded = jsonDecode(row['weights_json'] as String);
  final Map<String, Object?> diagnostics =
      diagnosticsDecoded is Map<String, Object?>
      ? diagnosticsDecoded
      : <String, Object?>{};
  final Map<String, Object?> weightObjects =
      weightsDecoded is Map<String, Object?>
      ? weightsDecoded
      : <String, Object?>{};
  return PredictionRecord(
    id: (row['id'] as num).toInt(),
    engineId: row['engine_id'] as String,
    engineName: row['engine_name'] as String,
    modelVersion: (row['model_version'] as num).toInt(),
    historyFingerprint: row['history_fingerprint'] as String,
    basedOnSpinCount: (row['based_on_spin_count'] as num).toInt(),
    targetPosition: (row['target_position'] as num).toInt(),
    status: PredictionStatus.values.byName(row['status'] as String),
    predictedNumber: (row['predicted_number'] as num).toInt(),
    predictedDozen: (row['predicted_dozen'] as num?)?.toInt(),
    top3: _decodeIntList(row['top3_json'] as String),
    probabilities: normalizeOrUniform(
      _decodeDoubleList(row['probabilities_json'] as String),
      expectedLength: 37,
    ),
    dozenProbabilities: normalizeOrUniform(
      _decodeDoubleList(row['dozen_probabilities_json'] as String),
      expectedLength: 4,
    ),
    diagnostics: diagnostics,
    expertWeights: <String, double>{
      for (final MapEntry<String, Object?> entry in weightObjects.entries)
        if (entry.value is num) entry.key: (entry.value! as num).toDouble(),
    },
    modelStrength: (row['model_strength'] as num).toDouble(),
    actualNumber: (row['actual_number'] as num?)?.toInt(),
    exactHit: _boolOrNull(row['exact_hit']),
    top3Hit: _boolOrNull(row['top3_hit']),
    dozenHit: _boolOrNull(row['dozen_hit']),
    logLoss: (row['log_loss'] as num?)?.toDouble(),
    brierScore: (row['brier_score'] as num?)?.toDouble(),
    createdAtUtc: DateTime.parse(row['created_at_utc'] as String).toUtc(),
    evaluatedAtUtc: _dateOrNull(row['evaluated_at_utc']),
  );
}

Map<String, Object?> _predictionToRow(PredictionRecord record) =>
    <String, Object?>{
      'engine_id': record.engineId,
      'engine_name': record.engineName,
      'model_version': record.modelVersion,
      'history_fingerprint': record.historyFingerprint,
      'based_on_spin_count': record.basedOnSpinCount,
      'target_position': record.targetPosition,
      'status': record.status.name,
      'predicted_number': record.predictedNumber,
      'predicted_dozen': record.predictedDozen,
      'top3_json': jsonEncode(record.top3),
      'probabilities_json': jsonEncode(record.probabilities),
      'dozen_probabilities_json': jsonEncode(record.dozenProbabilities),
      'diagnostics_json': jsonEncode(record.diagnostics),
      'weights_json': jsonEncode(record.expertWeights),
      'model_strength': record.modelStrength,
      'actual_number': record.actualNumber,
      'exact_hit': record.exactHit == null
          ? null
          : record.exactHit!
          ? 1
          : 0,
      'top3_hit': record.top3Hit == null
          ? null
          : record.top3Hit!
          ? 1
          : 0,
      'dozen_hit': record.dozenHit == null
          ? null
          : record.dozenHit!
          ? 1
          : 0,
      'log_loss': record.logLoss,
      'brier_score': record.brierScore,
      'created_at_utc': record.createdAtUtc.toUtc().toIso8601String(),
      'evaluated_at_utc': record.evaluatedAtUtc?.toUtc().toIso8601String(),
    };

List<int> _decodeIntList(String encoded) {
  final Object? decoded = jsonDecode(encoded);
  return decoded is List<Object?>
      ? decoded.whereType<num>().map((num value) => value.toInt()).toList()
      : <int>[];
}

List<double> _decodeDoubleList(String encoded) {
  final Object? decoded = jsonDecode(encoded);
  return decoded is List<Object?>
      ? decoded.whereType<num>().map((num value) => value.toDouble()).toList()
      : <double>[];
}

DateTime? _dateOrNull(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toUtc() : null;

bool? _boolOrNull(Object? value) => value is num ? value != 0 : null;
