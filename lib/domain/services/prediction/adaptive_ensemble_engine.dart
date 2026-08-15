import 'dart:math' as math;

import '../../../core/constants/roulette_constants.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/math/hashing.dart';
import '../../../core/math/probability_vector.dart';
import '../../../core/math/statistics.dart';
import '../../entities/prediction.dart';
import '../../entities/roulette_number_meta.dart';
import '../../entities/spin.dart';
import 'prediction_engine.dart';

const List<String> ensembleExpertNames = <String>[
  'Uniforme controle',
  'Aflopende frequentie',
  'Markov eerste orde',
  'Markov tweede orde',
  'Contextgelijkenis',
  'Eigenschapsovergang',
  'Wielsector-overgang',
];

class AdaptiveEnsembleEngine implements PredictionEngine {
  const AdaptiveEnsembleEngine();

  @override
  String get id => 'adaptive_ensemble';

  @override
  String get name => AppStrings.adaptiveModel;

  @override
  int get modelVersion => 1;

  @override
  PredictionResult predict(List<Spin> history) {
    final List<int> numbers = history
        .map((Spin spin) => spin.number)
        .toList(growable: false);
    List<double> weights = uniformDistribution(ensembleExpertNames.length);
    final List<double> recentLosses = <double>[];
    for (int target = 1; target < numbers.length; target++) {
      final List<List<double>> expertPredictions = ensembleExpertDistributions(
        numbers,
        end: target,
      );
      final List<double> combined = mixDistributions(
        expertPredictions,
        weights,
      );
      recentLosses.add(logLoss(combined, numbers[target]));
      if (recentLosses.length > 50) {
        recentLosses.removeAt(0);
      }
      weights = hedgeUpdate(
        weights: weights,
        expertDistributions: expertPredictions,
        actualIndex: numbers[target],
        eta: 0.065,
        gamma: 0.035,
      );
    }
    final List<List<double>> experts = ensembleExpertDistributions(numbers);
    final List<double> combined = mixDistributions(experts, weights);
    final double lambda = math.min(
      0.80,
      numbers.length / (numbers.length + 120),
    );
    final List<double> shrunk = normalizeOrUniform(<double>[
      for (int number = 0; number < rouletteNumberCount; number++)
        lambda * combined[number] + (1 - lambda) * uniformRouletteProbability,
    ], expectedLength: rouletteNumberCount);
    final int topNumber = rankedIndexes(shrunk).first;
    final int contextMatches = nearestContextSupport(numbers);
    final double rollingLoss = recentLosses.isEmpty
        ? math.log(37)
        : mean(recentLosses);
    final double improvement = math.log(37) - rollingLoss;
    final double sampleFactor = numbers.length / (numbers.length + 120);
    final double concentration = 1 - normalizedEntropy(shrunk);
    final double supportFactor = math.min(1, contextMatches / 10);
    final double validationFactor = improvement <= 0
        ? 0.15
        : math.min(1, improvement / 0.12);
    double strength =
        sampleFactor *
        (0.25 * concentration + 0.35 * supportFactor + 0.40 * validationFactor);
    if (numbers.length < 30 || improvement <= 0) {
      strength = math.min(strength, numbers.length < 30 ? 0.20 : 0.32);
    }
    final List<({String name, double contribution})> contributions =
        <({String name, double contribution})>[
          for (int i = 0; i < experts.length; i++)
            (
              name: ensembleExpertNames[i],
              contribution: weights[i] * experts[i][topNumber],
            ),
        ]..sort((a, b) => b.contribution.compareTo(a.contribution));
    return PredictionResult(
      engineId: id,
      engineName: name,
      modelVersion: modelVersion,
      probabilities: shrunk,
      historyFingerprint: historyFingerprint(
        numbers,
        settingsKey: '$id:$modelVersion',
      ),
      sampleCount: numbers.length,
      diagnostics: <String, Object?>{
        'contextMatches': contextMatches,
        'rollingLogLoss': rollingLoss,
        'uniformLogLoss': math.log(37),
        'rollingVerbetering': improvement,
        'entropy': normalizedEntropy(shrunk),
        'topBijdragen': <String>[
          for (final ({String name, double contribution}) entry
              in contributions.take(3))
            '${entry.name}: ${(entry.contribution * 100).toStringAsFixed(2)}%',
        ],
        'uitleg': AppStrings.ensembleModelExplanation,
      },
      expertWeights: <String, double>{
        for (int i = 0; i < ensembleExpertNames.length; i++)
          ensembleExpertNames[i]: weights[i],
      },
      modelStrength: strength.clamp(0, 1),
    );
  }
}

List<List<double>> ensembleExpertDistributions(List<int> numbers, {int? end}) {
  final int length = end ?? numbers.length;
  return <List<double>>[
    uniformDistribution(),
    decayedFrequencyExpert(numbers, end: length),
    firstOrderMarkovExpert(numbers, end: length),
    secondOrderMarkovExpert(numbers, end: length),
    nearestContextExpert(numbers, end: length),
    propertyTransitionExpert(numbers, end: length),
    wheelSectorExpert(numbers, end: length),
  ];
}

List<double> decayedFrequencyExpert(List<int> numbers, {int? end}) {
  final int length = end ?? numbers.length;
  final List<double> counts = List<double>.filled(37, 12 / 37);
  final int earliest = math.max(0, length - 1400);
  for (int i = earliest; i < length; i++) {
    final int age = length - 1 - i;
    counts[numbers[i]] += math.exp(-age * math.ln2 / 60);
  }
  return normalizeOrUniform(counts, expectedLength: 37);
}

List<double> firstOrderMarkovExpert(List<int> numbers, {int? end}) {
  final int length = end ?? numbers.length;
  final List<double> backoff = decayedFrequencyExpert(numbers, end: length);
  if (length == 0) {
    return backoff;
  }
  final List<double> counts = <double>[for (final double p in backoff) p * 16];
  final int last = numbers[length - 1];
  final int earliest = math.max(0, length - 1200);
  for (int i = earliest; i + 1 < length; i++) {
    if (numbers[i] == last) {
      counts[numbers[i + 1]] += math.exp(-(length - i) / 300);
    }
  }
  return normalizeOrUniform(counts, expectedLength: 37);
}

List<double> secondOrderMarkovExpert(List<int> numbers, {int? end}) {
  final int length = end ?? numbers.length;
  final List<double> backoff = firstOrderMarkovExpert(numbers, end: length);
  if (length < 2) {
    return backoff;
  }
  final List<double> counts = <double>[for (final double p in backoff) p * 28];
  final int previous = numbers[length - 2];
  final int last = numbers[length - 1];
  final int earliest = math.max(0, length - 1200);
  for (int i = earliest; i + 2 < length; i++) {
    if (numbers[i] == previous && numbers[i + 1] == last) {
      counts[numbers[i + 2]] += math.exp(-(length - i) / 350);
    }
  }
  return normalizeOrUniform(counts, expectedLength: 37);
}

double _numberSimilarity(int a, int b) {
  if (a == b) {
    return 1;
  }
  final RouletteNumberMeta first = RouletteNumberMeta.of(a);
  final RouletteNumberMeta second = RouletteNumberMeta.of(b);
  double score = 0;
  score += 0.22 * (1 - absoluteWheelDistance(a, b) / 18);
  if (first.color == second.color) {
    score += 0.16;
  }
  if (first.dozen == second.dozen) {
    score += 0.17;
  }
  if (first.column == second.column) {
    score += 0.13;
  }
  if (first.parity == second.parity) {
    score += 0.12;
  }
  if (first.range == second.range) {
    score += 0.12;
  }
  return score.clamp(0, 0.92);
}

List<double> nearestContextExpert(List<int> numbers, {int? end}) {
  final int length = end ?? numbers.length;
  final List<double> backoff = firstOrderMarkovExpert(numbers, end: length);
  final List<double> votes = <double>[for (final double p in backoff) p * 12];
  final int maxContext = math.min(6, length);
  final int earliest = math.max(0, length - 650);
  for (int context = 3; context <= maxContext; context++) {
    for (int start = earliest; start + context < length; start++) {
      double similarity = 0;
      for (int offset = 0; offset < context; offset++) {
        similarity += _numberSimilarity(
          numbers[length - context + offset],
          numbers[start + offset],
        );
      }
      similarity /= context;
      if (similarity >= 0.52) {
        final double recency = math.exp(-(length - start) / 260);
        votes[numbers[start + context]] +=
            math.pow(similarity, 3).toDouble() * context * recency;
      }
    }
  }
  return normalizeOrUniform(votes, expectedLength: 37);
}

int nearestContextSupport(List<int> numbers) {
  final int length = numbers.length;
  if (length < 3) {
    return 0;
  }
  final int context = math.min(6, length);
  final int earliest = math.max(0, length - 650);
  int support = 0;
  for (int start = earliest; start + context < length; start++) {
    double similarity = 0;
    for (int offset = 0; offset < context; offset++) {
      similarity += _numberSimilarity(
        numbers[length - context + offset],
        numbers[start + offset],
      );
    }
    if (similarity / context >= 0.52) {
      support++;
    }
  }
  return support;
}

int _colorCategory(int number) => switch (RouletteNumberMeta.of(number).color) {
  RouletteColor.green => 0,
  RouletteColor.red => 1,
  RouletteColor.black => 2,
};

int _parityCategory(int number) =>
    switch (RouletteNumberMeta.of(number).parity) {
      RouletteParity.neutral => 0,
      RouletteParity.even => 1,
      RouletteParity.odd => 2,
    };

int _rangeCategory(int number) => switch (RouletteNumberMeta.of(number).range) {
  RouletteRange.neutral => 0,
  RouletteRange.low => 1,
  RouletteRange.high => 2,
};

List<double> _categoryTransition(
  List<int> numbers,
  int length,
  int Function(int) category,
  int categoryCount,
) {
  final List<double> counts = List<double>.filled(
    categoryCount,
    4 / categoryCount,
  );
  if (length == 0) {
    return normalizeOrUniform(counts);
  }
  final int lastCategory = category(numbers[length - 1]);
  final int earliest = math.max(0, length - 900);
  for (int i = earliest; i + 1 < length; i++) {
    if (category(numbers[i]) == lastCategory) {
      counts[category(numbers[i + 1])] += math.exp(-(length - i) / 280);
    }
  }
  return normalizeOrUniform(counts);
}

List<double> propertyTransitionExpert(List<int> numbers, {int? end}) {
  final int length = end ?? numbers.length;
  if (length == 0) {
    return uniformDistribution();
  }
  int dozen(int number) => RouletteNumberMeta.of(number).dozen ?? 0;
  int column(int number) => RouletteNumberMeta.of(number).column ?? 0;
  final List<double> colorP = _categoryTransition(
    numbers,
    length,
    _colorCategory,
    3,
  );
  final List<double> dozenP = _categoryTransition(numbers, length, dozen, 4);
  final List<double> columnP = _categoryTransition(numbers, length, column, 4);
  final List<double> parityP = _categoryTransition(
    numbers,
    length,
    _parityCategory,
    3,
  );
  final List<double> rangeP = _categoryTransition(
    numbers,
    length,
    _rangeCategory,
    3,
  );
  final List<double> scores = List<double>.filled(37, 0);
  for (int number = 0; number < 37; number++) {
    final double logScore =
        0.24 * math.log(colorP[_colorCategory(number)].clamp(1e-12, 1)) +
        0.23 * math.log(dozenP[dozen(number)].clamp(1e-12, 1)) +
        0.17 * math.log(columnP[column(number)].clamp(1e-12, 1)) +
        0.18 * math.log(parityP[_parityCategory(number)].clamp(1e-12, 1)) +
        0.18 * math.log(rangeP[_rangeCategory(number)].clamp(1e-12, 1));
    scores[number] = math.exp(logScore);
  }
  final List<double> projected = normalizeOrUniform(scores, expectedLength: 37);
  return normalizeOrUniform(<double>[
    for (int number = 0; number < 37; number++)
      0.68 * projected[number] + 0.32 / 37,
  ], expectedLength: 37);
}

List<double> wheelSectorExpert(List<int> numbers, {int? end}) {
  final int length = end ?? numbers.length;
  final List<double> votes = List<double>.filled(37, 10 / 37);
  if (length == 0) {
    return normalizeOrUniform(votes);
  }
  final int last = numbers[length - 1];
  final int earliest = math.max(0, length - 1000);
  for (int i = earliest; i + 1 < length; i++) {
    final int sourceDistance = absoluteWheelDistance(numbers[i], last);
    if (sourceDistance <= 2) {
      final double similarity = sourceDistance == 0
          ? 1
          : sourceDistance == 1
          ? 0.65
          : 0.35;
      final double recency = math.exp(-(length - i) / 300);
      final int target = numbers[i + 1];
      for (final ({int offset, double kernel}) entry
          in const <({int offset, double kernel})>[
            (offset: 0, kernel: 0.50),
            (offset: -1, kernel: 0.16),
            (offset: 1, kernel: 0.16),
            (offset: -2, kernel: 0.09),
            (offset: 2, kernel: 0.09),
          ]) {
        votes[numberAtSignedDelta(target, entry.offset)] +=
            similarity * recency * entry.kernel;
      }
    }
  }
  return normalizeOrUniform(votes, expectedLength: 37);
}
