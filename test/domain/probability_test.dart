import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:roulette_lab/core/math/hashing.dart';
import 'package:roulette_lab/core/math/probability_vector.dart';
import 'package:roulette_lab/core/math/statistics.dart';

void main() {
  test('normalisatie valt voor ongeldige waarden uniform terug', () {
    for (final List<num> values in <List<num>>[
      <num>[0, 0, 0],
      <num>[1, -1, 2],
      <num>[1, double.nan, 2],
      <num>[1, double.infinity, 2],
    ]) {
      final List<double> result = normalizeOrUniform(values);
      expect(result, hasLength(3));
      expect(result.reduce((double a, double b) => a + b), closeTo(1, 1e-12));
      expect(result.every((double p) => p.isFinite && p >= 0), isTrue);
    }
  });

  test('dozijnaggregatie houdt nul apart', () {
    final List<double> distribution = List<double>.filled(37, 0);
    distribution[0] = 0.1;
    distribution[1] = 0.2;
    distribution[13] = 0.3;
    distribution[25] = 0.4;
    expect(
      aggregateDozens(distribution),
      closeToList(<double>[0.1, 0.2, 0.3, 0.4]),
    );
  });

  test('log-loss en Brier-score zijn correct', () {
    final List<double> certain = <double>[1, 0, 0];
    expect(logLoss(certain, 0), closeTo(0, 1e-12));
    expect(brierScore(certain, 0), closeTo(0, 1e-12));
    final List<double> uniform = <double>[1 / 3, 1 / 3, 1 / 3];
    expect(logLoss(uniform, 1), closeTo(math.log(3), 1e-12));
    expect(brierScore(uniform, 1), closeTo(2 / 3, 1e-12));
  });

  test('Hedge beloont expert met lagere loss en blijft gemengd', () {
    final List<double> updated = hedgeUpdate(
      weights: <double>[0.5, 0.5],
      expertDistributions: <List<double>>[
        <double>[0.9, 0.1],
        <double>[0.1, 0.9],
      ],
      actualIndex: 0,
    );
    expect(updated[0], greaterThan(updated[1]));
    expect(updated.every((double value) => value > 0), isTrue);
  });

  test('fingerprint is deterministisch en volgordegevoelig', () {
    expect(
      historyFingerprint(<int>[1, 2, 3]),
      historyFingerprint(<int>[1, 2, 3]),
    );
    expect(
      historyFingerprint(<int>[1, 2, 3]),
      isNot(historyFingerprint(<int>[1, 3, 2])),
    );
    expect(
      historyFingerprint(<int>[1, 2]),
      isNot(historyFingerprint(<int>[1, 2, 3])),
    );
  });
}

Matcher closeToList(List<double> expected) => predicate<List<double>>(
  (List<double> actual) =>
      actual.length == expected.length &&
      List<bool>.generate(
        actual.length,
        (int i) => (actual[i] - expected[i]).abs() < 1e-12,
      ).every((bool value) => value),
);
