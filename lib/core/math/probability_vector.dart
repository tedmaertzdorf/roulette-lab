import 'dart:math' as math;

import '../../domain/entities/roulette_number_meta.dart';
import '../constants/roulette_constants.dart';

List<double> uniformDistribution([int length = rouletteNumberCount]) =>
    List<double>.filled(length, 1 / length);

List<double> normalizeOrUniform(List<num> values, {int? expectedLength}) {
  final int length = expectedLength ?? values.length;
  if (length <= 0 || values.length != length) {
    return length <= 0 ? <double>[] : uniformDistribution(length);
  }
  double sum = 0;
  final List<double> normalized = List<double>.filled(length, 0);
  for (int i = 0; i < length; i++) {
    final double value = values[i].toDouble();
    if (!value.isFinite || value < 0) {
      return uniformDistribution(length);
    }
    normalized[i] = value;
    sum += value;
  }
  if (!sum.isFinite || sum <= 0) {
    return uniformDistribution(length);
  }
  for (int i = 0; i < length; i++) {
    normalized[i] /= sum;
  }
  return List<double>.unmodifiable(normalized);
}

List<int> rankedIndexes(List<double> probabilities) {
  final List<int> indexes = List<int>.generate(
    probabilities.length,
    (int i) => i,
  );
  indexes.sort((int a, int b) {
    final int scoreOrder = probabilities[b].compareTo(probabilities[a]);
    return scoreOrder == 0 ? a.compareTo(b) : scoreOrder;
  });
  return indexes;
}

List<double> aggregateDozens(List<double> probabilities) {
  final List<double> distribution = normalizeOrUniform(
    probabilities,
    expectedLength: rouletteNumberCount,
  );
  final List<double> result = List<double>.filled(4, 0);
  for (int number = 0; number < rouletteNumberCount; number++) {
    final int? dozen = RouletteNumberMeta.of(number).dozen;
    result[dozen ?? 0] += distribution[number];
  }
  return List<double>.unmodifiable(result);
}

double normalizedEntropy(List<double> probabilities) {
  final List<double> values = normalizeOrUniform(probabilities);
  if (values.length <= 1) {
    return 0;
  }
  double entropy = 0;
  for (final double probability in values) {
    if (probability > 0) {
      entropy -= probability * math.log(probability);
    }
  }
  return (entropy / math.log(values.length)).clamp(0, 1);
}

List<double> mixDistributions(
  List<List<double>> distributions,
  List<double> weights,
) {
  if (distributions.isEmpty || distributions.length != weights.length) {
    return uniformDistribution();
  }
  final int length = distributions.first.length;
  if (length == 0 ||
      distributions.any((List<double> d) => d.length != length)) {
    return uniformDistribution(length == 0 ? rouletteNumberCount : length);
  }
  final List<double> safeWeights = normalizeOrUniform(
    weights,
    expectedLength: weights.length,
  );
  final List<double> result = List<double>.filled(length, 0);
  for (int expert = 0; expert < distributions.length; expert++) {
    final List<double> distribution = normalizeOrUniform(
      distributions[expert],
      expectedLength: length,
    );
    for (int i = 0; i < length; i++) {
      result[i] += safeWeights[expert] * distribution[i];
    }
  }
  return normalizeOrUniform(result, expectedLength: length);
}

List<double> hedgeUpdate({
  required List<double> weights,
  required List<List<double>> expertDistributions,
  required int actualIndex,
  double eta = 0.07,
  double gamma = 0.03,
}) {
  if (weights.length != expertDistributions.length || weights.isEmpty) {
    return uniformDistribution(weights.isEmpty ? 1 : weights.length);
  }
  final List<double> current = normalizeOrUniform(weights);
  final List<double> raw = List<double>.filled(weights.length, 0);
  for (int i = 0; i < weights.length; i++) {
    final List<double> distribution = normalizeOrUniform(
      expertDistributions[i],
    );
    final double probability =
        actualIndex >= 0 && actualIndex < distribution.length
        ? distribution[actualIndex].clamp(1e-12, 1)
        : 1e-12;
    final double loss = (-math.log(probability)).clamp(0, 27.6310211159);
    raw[i] = current[i] * math.exp(-eta * loss);
  }
  final List<double> learned = normalizeOrUniform(raw);
  final double safeGamma = gamma.clamp(0, 1);
  return List<double>.unmodifiable(<double>[
    for (final double weight in learned)
      (1 - safeGamma) * weight + safeGamma / learned.length,
  ]);
}
