import '../../../core/math/statistics.dart';
import '../../entities/prediction.dart';
import '../../entities/roulette_number_meta.dart';

PredictionRecord evaluatePrediction(
  PredictionRecord record,
  int actualNumber, {
  DateTime? evaluatedAtUtc,
}) {
  final int? actualDozen = RouletteNumberMeta.of(actualNumber).dozen;
  return PredictionRecord(
    id: record.id,
    engineId: record.engineId,
    engineName: record.engineName,
    modelVersion: record.modelVersion,
    historyFingerprint: record.historyFingerprint,
    basedOnSpinCount: record.basedOnSpinCount,
    targetPosition: record.targetPosition,
    status: PredictionStatus.evaluated,
    predictedNumber: record.predictedNumber,
    predictedDozen: record.predictedDozen,
    top3: record.top3,
    probabilities: record.probabilities,
    dozenProbabilities: record.dozenProbabilities,
    diagnostics: record.diagnostics,
    expertWeights: record.expertWeights,
    modelStrength: record.modelStrength,
    actualNumber: actualNumber,
    exactHit: record.predictedNumber == actualNumber,
    top3Hit: record.top3.contains(actualNumber),
    dozenHit: actualDozen != null && record.predictedDozen == actualDozen,
    logLoss: logLoss(record.probabilities, actualNumber),
    brierScore: brierScore(record.probabilities, actualNumber),
    createdAtUtc: record.createdAtUtc,
    evaluatedAtUtc: evaluatedAtUtc ?? DateTime.now().toUtc(),
  );
}

class PerformanceSummary {
  const PerformanceSummary({
    required this.evaluationCount,
    required this.exactHits,
    required this.top3Hits,
    required this.dozenHits,
    required this.averageLogLoss,
    required this.averageBrierScore,
    required this.uniformLogLoss,
    required this.cumulativeImprovement,
    required this.rollingLogLoss,
  });

  factory PerformanceSummary.fromRecords(
    Iterable<PredictionRecord> records, {
    int rollingWindow = 20,
  }) {
    final List<PredictionRecord> evaluated = records
        .where(
          (PredictionRecord record) =>
              record.status == PredictionStatus.evaluated,
        )
        .toList(growable: false);
    if (evaluated.isEmpty) {
      return const PerformanceSummary(
        evaluationCount: 0,
        exactHits: 0,
        top3Hits: 0,
        dozenHits: 0,
        averageLogLoss: 0,
        averageBrierScore: 0,
        uniformLogLoss: 3.61091791264,
        cumulativeImprovement: 0,
        rollingLogLoss: <double>[],
      );
    }
    final List<double> losses = evaluated
        .map((PredictionRecord record) => record.logLoss ?? 0)
        .toList(growable: false);
    final List<double> briers = evaluated
        .map((PredictionRecord record) => record.brierScore ?? 0)
        .toList(growable: false);
    final List<double> rolling = <double>[];
    for (int i = 0; i < losses.length; i++) {
      final int start = (i - rollingWindow + 1).clamp(0, i);
      rolling.add(mean(losses.sublist(start, i + 1)));
    }
    const double uniformLoss = 3.61091791264;
    return PerformanceSummary(
      evaluationCount: evaluated.length,
      exactHits: evaluated
          .where((PredictionRecord r) => r.exactHit ?? false)
          .length,
      top3Hits: evaluated
          .where((PredictionRecord r) => r.top3Hit ?? false)
          .length,
      dozenHits: evaluated
          .where((PredictionRecord r) => r.dozenHit ?? false)
          .length,
      averageLogLoss: mean(losses),
      averageBrierScore: mean(briers),
      uniformLogLoss: uniformLoss,
      cumulativeImprovement:
          evaluated.length * uniformLoss -
          losses.fold<double>(0, (double a, double b) => a + b),
      rollingLogLoss: List<double>.unmodifiable(rolling),
    );
  }

  final int evaluationCount;
  final int exactHits;
  final int top3Hits;
  final int dozenHits;
  final double averageLogLoss;
  final double averageBrierScore;
  final double uniformLogLoss;
  final double cumulativeImprovement;
  final List<double> rollingLogLoss;

  double get exactRate =>
      evaluationCount == 0 ? 0 : exactHits / evaluationCount;
  double get top3Rate => evaluationCount == 0 ? 0 : top3Hits / evaluationCount;
  double get dozenRate =>
      evaluationCount == 0 ? 0 : dozenHits / evaluationCount;
}
