import 'dart:math' as math;

import 'probability_vector.dart';

double mean(Iterable<num> values) {
  final List<num> list = values.toList(growable: false);
  return list.isEmpty
      ? 0
      : list.fold<double>(0, (double sum, num value) => sum + value) /
            list.length;
}

double median(Iterable<num> values) {
  final List<double> list =
      values.map((num value) => value.toDouble()).toList(growable: false)
        ..sort();
  if (list.isEmpty) {
    return 0;
  }
  final int middle = list.length ~/ 2;
  return list.length.isOdd
      ? list[middle]
      : (list[middle - 1] + list[middle]) / 2;
}

double logLoss(List<double> probabilities, int actualIndex) {
  final List<double> distribution = normalizeOrUniform(probabilities);
  if (actualIndex < 0 || actualIndex >= distribution.length) {
    throw RangeError.index(actualIndex, distribution, 'actualIndex');
  }
  return -math.log(distribution[actualIndex].clamp(1e-12, 1));
}

double brierScore(List<double> probabilities, int actualIndex) {
  final List<double> distribution = normalizeOrUniform(probabilities);
  if (actualIndex < 0 || actualIndex >= distribution.length) {
    throw RangeError.index(actualIndex, distribution, 'actualIndex');
  }
  double score = 0;
  for (int i = 0; i < distribution.length; i++) {
    final double error = distribution[i] - (i == actualIndex ? 1 : 0);
    score += error * error;
  }
  return score;
}

({double lower, double upper}) wilsonInterval(int hits, int trials) {
  if (trials <= 0) {
    return (lower: 0, upper: 1);
  }
  const double z = 1.95996398454;
  final double proportion = hits / trials;
  final double denominator = 1 + z * z / trials;
  final double center = (proportion + z * z / (2 * trials)) / denominator;
  final double margin =
      z *
      math.sqrt(
        (proportion * (1 - proportion) + z * z / (4 * trials)) / trials,
      ) /
      denominator;
  return (
    lower: (center - margin).clamp(0, 1),
    upper: (center + margin).clamp(0, 1),
  );
}
