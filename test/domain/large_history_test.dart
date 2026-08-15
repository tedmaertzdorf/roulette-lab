@Timeout(Duration(minutes: 5))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:roulette_lab/domain/entities/spin.dart';
import 'package:roulette_lab/domain/services/analytics/roulette_analytics.dart';
import 'package:roulette_lab/domain/services/evaluation/walk_forward_evaluator.dart';
import 'package:roulette_lab/domain/services/prediction/adaptive_ensemble_engine.dart';
import 'package:roulette_lab/domain/services/prediction/wheel_distance_engine.dart';

void main() {
  test('10.000 draaien blijven analyseerbaar en leveren geldige modellen', () {
    final List<Spin> history = _history(10000);
    expect(recentStats(history, 30).availableSize, 30);
    expect(numberDetails(history, 8).sampleSize, 10000);

    final wheel = const WheelDistanceEngine().predict(history);
    final ensemble = const AdaptiveEnsembleEngine().predict(history);
    _expectDistribution(wheel.probabilities);
    _expectDistribution(ensemble.probabilities);
    expect(wheel.sampleCount, 10000);
    expect(ensemble.sampleCount, 10000);
  });

  test('walk-forward verwerkt 2.000 draaien incrementeel zonder lek', () {
    final List<Spin> history = _history(2000);
    const WalkForwardEvaluator evaluator = WalkForwardEvaluator();
    final wheel = evaluator.evaluate(const WheelDistanceEngine(), history);
    final ensemble = evaluator.evaluate(
      const AdaptiveEnsembleEngine(),
      history,
    );
    expect(wheel.points, hasLength(1980));
    expect(ensemble.points, hasLength(1980));
    expect(wheel.averageLogLoss.isFinite, isTrue);
    expect(ensemble.averageLogLoss.isFinite, isTrue);
    expect(wheel.averageBrierScore.isFinite, isTrue);
    expect(ensemble.averageBrierScore.isFinite, isTrue);
  });
}

List<Spin> _history(int length) {
  final DateTime start = DateTime.utc(2026);
  return <Spin>[
    for (int i = 0; i < length; i++)
      Spin(
        id: i + 1,
        position: i + 1,
        number: (i * 17 + i ~/ 7 + (i % 11) * 3) % 37,
        createdAtUtc: start.add(Duration(seconds: i)),
        updatedAtUtc: start.add(Duration(seconds: i)),
      ),
  ];
}

void _expectDistribution(List<double> probabilities) {
  expect(probabilities, hasLength(37));
  expect(
    probabilities.reduce((double sum, double value) => sum + value),
    closeTo(1, 1e-10),
  );
  expect(
    probabilities.every((double value) => value.isFinite && value >= 0),
    isTrue,
  );
}
