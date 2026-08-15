import '../entities/prediction.dart';
import '../entities/spin.dart';

class AppSnapshot {
  const AppSnapshot({required this.spins, required this.predictions});

  final List<Spin> spins;
  final List<PredictionRecord> predictions;
}

abstract interface class AppRepository {
  Future<AppSnapshot> loadSnapshot();
  Future<void> addSpin(int number, {DateTime? occurredAtUtc});
  Future<void> editSpin(int id, int number, {DateTime? occurredAtUtc});
  Future<void> deleteSpin(int id);
  Future<void> clearSpins();
  Future<void> clearAllData();
  Future<void> importSpins(
    List<Spin> spins, {
    required bool replace,
    List<PredictionRecord> predictions,
  });
  Future<List<PredictionRecord>> saveActivePredictions(
    List<PredictionRecord> predictions,
  );
  Future<void> clearPredictionEvaluations();
  Future<void> invalidatePredictionsFrom(int targetPosition);
}
