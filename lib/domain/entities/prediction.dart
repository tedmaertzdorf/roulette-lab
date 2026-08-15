import '../../core/localization/app_strings.dart';
import '../../core/math/probability_vector.dart';

enum PredictionStatus { active, evaluated, invalidated }

class PredictionResult {
  PredictionResult({
    required this.engineId,
    required this.engineName,
    required this.modelVersion,
    required List<double> probabilities,
    required this.historyFingerprint,
    required this.sampleCount,
    required this.diagnostics,
    required this.expertWeights,
    required this.modelStrength,
  }) : probabilities = List<double>.unmodifiable(
         normalizeOrUniform(probabilities, expectedLength: 37),
       ) {
    final List<int> ranked = rankedIndexes(this.probabilities);
    topNumber = ranked.first;
    top3 = List<int>.unmodifiable(ranked.take(3));
    dozenProbabilities = aggregateDozens(this.probabilities);
    predictedDozen = rankedIndexes(dozenProbabilities.sublist(1)).first + 1;
  }

  final String engineId;
  final String engineName;
  final int modelVersion;
  final List<double> probabilities;
  final String historyFingerprint;
  final int sampleCount;
  final Map<String, Object?> diagnostics;
  final Map<String, double> expertWeights;
  final double modelStrength;
  late final int topNumber;
  late final List<int> top3;
  late final List<double> dozenProbabilities;
  late final int predictedDozen;

  String get dataQualityLabel {
    if (sampleCount < 10) {
      return AppStrings.veryLittleData;
    }
    if (sampleCount < 30) {
      return AppStrings.littleData;
    }
    return AppStrings.moreHistoryAvailable;
  }
}

class PredictionRecord {
  const PredictionRecord({
    required this.id,
    required this.engineId,
    required this.engineName,
    required this.modelVersion,
    required this.historyFingerprint,
    required this.basedOnSpinCount,
    required this.targetPosition,
    required this.status,
    required this.predictedNumber,
    required this.predictedDozen,
    required this.top3,
    required this.probabilities,
    required this.dozenProbabilities,
    required this.diagnostics,
    required this.expertWeights,
    required this.modelStrength,
    required this.createdAtUtc,
    this.actualNumber,
    this.exactHit,
    this.top3Hit,
    this.dozenHit,
    this.logLoss,
    this.brierScore,
    this.evaluatedAtUtc,
  });

  factory PredictionRecord.fromResult({
    required PredictionResult result,
    required int targetPosition,
    DateTime? nowUtc,
  }) => PredictionRecord(
    id: null,
    engineId: result.engineId,
    engineName: result.engineName,
    modelVersion: result.modelVersion,
    historyFingerprint: result.historyFingerprint,
    basedOnSpinCount: result.sampleCount,
    targetPosition: targetPosition,
    status: PredictionStatus.active,
    predictedNumber: result.topNumber,
    predictedDozen: result.predictedDozen,
    top3: result.top3,
    probabilities: result.probabilities,
    dozenProbabilities: result.dozenProbabilities,
    diagnostics: result.diagnostics,
    expertWeights: result.expertWeights,
    modelStrength: result.modelStrength,
    createdAtUtc: nowUtc ?? DateTime.now().toUtc(),
  );

  final int? id;
  final String engineId;
  final String engineName;
  final int modelVersion;
  final String historyFingerprint;
  final int basedOnSpinCount;
  final int targetPosition;
  final PredictionStatus status;
  final int predictedNumber;
  final int? predictedDozen;
  final List<int> top3;
  final List<double> probabilities;
  final List<double> dozenProbabilities;
  final Map<String, Object?> diagnostics;
  final Map<String, double> expertWeights;
  final double modelStrength;
  final int? actualNumber;
  final bool? exactHit;
  final bool? top3Hit;
  final bool? dozenHit;
  final double? logLoss;
  final double? brierScore;
  final DateTime createdAtUtc;
  final DateTime? evaluatedAtUtc;
}
