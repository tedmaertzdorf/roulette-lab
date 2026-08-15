import 'package:flutter_test/flutter_test.dart';
import 'package:roulette_lab/domain/entities/spin.dart';
import 'package:roulette_lab/domain/services/evaluation/walk_forward_evaluator.dart';
import 'package:roulette_lab/domain/services/prediction/adaptive_ensemble_engine.dart';
import 'package:roulette_lab/domain/services/prediction/wheel_distance_engine.dart';

void main() {
  group('voorspellingsmodellen', () {
    test('5/10/5-fixture zet 29 zeer hoog', () {
      final result = const WheelDistanceEngine().predict(
        spins(<int>[0, 21, 30, 24]),
      );
      expect(result.top3, contains(29));
      expectValid(result.probabilities);
    });

    test('ensemble is deterministisch en muteert invoer niet', () {
      final List<Spin> history = spins(<int>[
        8,
        4,
        10,
        3,
        8,
        4,
        10,
        3,
        8,
        4,
        10,
        3,
        16,
        22,
        0,
        36,
      ]);
      final List<int> before = history.map((Spin spin) => spin.number).toList();
      final first = const AdaptiveEnsembleEngine().predict(history);
      final second = const AdaptiveEnsembleEngine().predict(history);
      expect(first.probabilities, orderedEquals(second.probabilities));
      expect(history.map((Spin spin) => spin.number), orderedEquals(before));
      expectValid(first.probabilities);
      expect(first.top3.toSet(), hasLength(3));
    });

    test('prefixvoorspelling verandert niet door latere suffix', () {
      final List<Spin> prefix = spins(<int>[1, 2, 3, 4, 5, 6, 7, 8]);
      final first = const AdaptiveEnsembleEngine().predict(prefix);
      final List<Spin> extended = spins(<int>[
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        36,
        0,
        12,
      ]);
      final second = const AdaptiveEnsembleEngine().predict(
        extended.sublist(0, prefix.length),
      );
      expect(first.probabilities, orderedEquals(second.probabilities));
      expect(first.historyFingerprint, second.historyFingerprint);
    });

    test('propertyachtige histories blijven altijd geldige verdelingen', () {
      for (int length = 0; length <= 80; length++) {
        final List<int> values = <int>[
          for (int i = 0; i < length; i++) (i * 17 + i ~/ 3) % 37,
        ];
        expectValid(
          const WheelDistanceEngine().predict(spins(values)).probabilities,
        );
        expectValid(
          const AdaptiveEnsembleEngine().predict(spins(values)).probabilities,
        );
      }
    });

    test('walk-forward begint pas na training en lekt niet', () {
      final List<Spin> history = spins(<int>[
        for (int i = 0; i < 45; i++) (i * 11) % 37,
      ]);
      final BacktestReport report = const WalkForwardEvaluator().evaluate(
        const AdaptiveEnsembleEngine(),
        history,
      );
      expect(report.points, hasLength(25));
      expect(report.points.first.targetPosition, 21);
      expect(report.averageLogLoss.isFinite, isTrue);
    });
  });
}

void expectValid(List<double> values) {
  expect(values, hasLength(37));
  expect(values.reduce((double a, double b) => a + b), closeTo(1, 1e-10));
  expect(values.every((double value) => value.isFinite && value >= 0), isTrue);
}

List<Spin> spins(List<int> numbers) {
  final DateTime now = DateTime.utc(2026);
  return <Spin>[
    for (int i = 0; i < numbers.length; i++)
      Spin(
        id: i + 1,
        position: i + 1,
        number: numbers[i],
        createdAtUtc: now.add(Duration(seconds: i)),
        updatedAtUtc: now.add(Duration(seconds: i)),
      ),
  ];
}
