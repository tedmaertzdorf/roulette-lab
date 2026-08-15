import 'dart:math' as math;

import '../../../core/constants/roulette_constants.dart';
import '../../../core/math/probability_vector.dart';
import '../../../core/math/statistics.dart';
import '../../entities/roulette_number_meta.dart';
import '../../entities/spin.dart';
import '../prediction/adaptive_ensemble_engine.dart';
import '../prediction/prediction_engine.dart';
import '../prediction/wheel_distance_engine.dart';

class BacktestPoint {
  const BacktestPoint({
    required this.targetPosition,
    required this.actualNumber,
    required this.predictedNumber,
    required this.top3,
    required this.exactHit,
    required this.top3Hit,
    required this.dozenHit,
    required this.logLoss,
    required this.brierScore,
    required this.uniformImprovement,
  });

  final int targetPosition;
  final int actualNumber;
  final int predictedNumber;
  final List<int> top3;
  final bool exactHit;
  final bool top3Hit;
  final bool dozenHit;
  final double logLoss;
  final double brierScore;
  final double uniformImprovement;
}

class BacktestReport {
  const BacktestReport({
    required this.engineId,
    required this.points,
    required this.averageLogLoss,
    required this.averageBrierScore,
    required this.exactRate,
    required this.top3Rate,
    required this.dozenRate,
    required this.cumulativeImprovement,
  });

  factory BacktestReport.fromPoints(
    String engineId,
    List<BacktestPoint> points,
  ) {
    if (points.isEmpty) {
      return BacktestReport(
        engineId: engineId,
        points: const <BacktestPoint>[],
        averageLogLoss: 0,
        averageBrierScore: 0,
        exactRate: 0,
        top3Rate: 0,
        dozenRate: 0,
        cumulativeImprovement: 0,
      );
    }
    return BacktestReport(
      engineId: engineId,
      points: List<BacktestPoint>.unmodifiable(points),
      averageLogLoss: mean(points.map((BacktestPoint p) => p.logLoss)),
      averageBrierScore: mean(points.map((BacktestPoint p) => p.brierScore)),
      exactRate:
          points.where((BacktestPoint p) => p.exactHit).length / points.length,
      top3Rate:
          points.where((BacktestPoint p) => p.top3Hit).length / points.length,
      dozenRate:
          points.where((BacktestPoint p) => p.dozenHit).length / points.length,
      cumulativeImprovement: points.fold<double>(
        0,
        (double sum, BacktestPoint p) => sum + p.uniformImprovement,
      ),
    );
  }

  final String engineId;
  final List<BacktestPoint> points;
  final double averageLogLoss;
  final double averageBrierScore;
  final double exactRate;
  final double top3Rate;
  final double dozenRate;
  final double cumulativeImprovement;
}

class WalkForwardEvaluator {
  const WalkForwardEvaluator({this.minimumTrainingLength = 20});

  final int minimumTrainingLength;

  BacktestReport evaluate(PredictionEngine engine, List<Spin> history) {
    final List<int> numbers = history
        .map((Spin spin) => spin.number)
        .toList(growable: false);
    if (engine.id == 'wheel_distance') {
      return _evaluateWheel(numbers);
    }
    if (engine.id == 'adaptive_ensemble') {
      return _evaluateEnsemble(numbers);
    }
    final List<BacktestPoint> points = <BacktestPoint>[];
    for (int target = 1; target < history.length; target++) {
      if (target < minimumTrainingLength) {
        continue;
      }
      final result = engine.predict(history.sublist(0, target));
      points.add(_score(target + 1, result.probabilities, numbers[target]));
    }
    return BacktestReport.fromPoints(engine.id, points);
  }

  BacktestReport _evaluateWheel(List<int> numbers) {
    final List<BacktestPoint> points = <BacktestPoint>[];
    final List<int> deltas = <int>[];
    List<double> weights = uniformDistribution(wheelExpertNames.length);
    for (int target = 1; target < numbers.length; target++) {
      final List<List<double>> experts = distanceExpertDistributions(deltas);
      final List<double> deltaDistribution = mixDistributions(experts, weights);
      final List<double> raw = List<double>.filled(37, 0);
      for (int delta = -18; delta <= 18; delta++) {
        raw[numberAtSignedDelta(numbers[target - 1], delta)] +=
            deltaDistribution[delta + 18];
      }
      final double lambda = math.min(0.78, target / (target + 90));
      final List<double> distribution = normalizeOrUniform(<double>[
        for (int number = 0; number < 37; number++)
          lambda * raw[number] + (1 - lambda) / 37,
      ], expectedLength: 37);
      if (target >= minimumTrainingLength) {
        points.add(_score(target + 1, distribution, numbers[target]));
      }
      final int actualDelta = signedWheelDistance(
        numbers[target - 1],
        numbers[target],
      );
      weights = hedgeUpdate(
        weights: weights,
        expertDistributions: experts,
        actualIndex: actualDelta + 18,
      );
      deltas.add(actualDelta);
    }
    return BacktestReport.fromPoints('wheel_distance', points);
  }

  BacktestReport _evaluateEnsemble(List<int> numbers) {
    final List<BacktestPoint> points = <BacktestPoint>[];
    List<double> weights = uniformDistribution(ensembleExpertNames.length);
    for (int target = 1; target < numbers.length; target++) {
      final List<List<double>> experts = ensembleExpertDistributions(
        numbers,
        end: target,
      );
      final List<double> combined = mixDistributions(experts, weights);
      final double lambda = math.min(0.80, target / (target + 120));
      final List<double> distribution = normalizeOrUniform(<double>[
        for (int number = 0; number < 37; number++)
          lambda * combined[number] + (1 - lambda) / 37,
      ], expectedLength: 37);
      if (target >= minimumTrainingLength) {
        points.add(_score(target + 1, distribution, numbers[target]));
      }
      weights = hedgeUpdate(
        weights: weights,
        expertDistributions: experts,
        actualIndex: numbers[target],
        eta: 0.065,
        gamma: 0.035,
      );
    }
    return BacktestReport.fromPoints('adaptive_ensemble', points);
  }
}

BacktestPoint _score(
  int targetPosition,
  List<double> probabilities,
  int actual,
) {
  final List<int> ranked = rankedIndexes(probabilities);
  final int predicted = ranked.first;
  final int? actualDozen = RouletteNumberMeta.of(actual).dozen;
  final int predictedDozen =
      rankedIndexes(aggregateDozens(probabilities).sublist(1)).first + 1;
  final double loss = logLoss(probabilities, actual);
  return BacktestPoint(
    targetPosition: targetPosition,
    actualNumber: actual,
    predictedNumber: predicted,
    top3: List<int>.unmodifiable(ranked.take(3)),
    exactHit: predicted == actual,
    top3Hit: ranked.take(3).contains(actual),
    dozenHit: actualDozen != null && actualDozen == predictedDozen,
    logLoss: loss,
    brierScore: brierScore(probabilities, actual),
    uniformImprovement: math.log(37) - loss,
  );
}
