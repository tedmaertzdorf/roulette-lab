import 'dart:math' as math;

import '../../../core/constants/roulette_constants.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/math/hashing.dart';
import '../../../core/math/probability_vector.dart';
import '../../entities/prediction.dart';
import '../../entities/spin.dart';
import 'prediction_engine.dart';

const List<String> wheelExpertNames = <String>[
  'Exact suffix',
  'Fuzzy patroon',
  'Periodiciteit',
  'Delta-overgang',
  'Aflopende prior',
];

class WheelDistanceEngine implements PredictionEngine {
  const WheelDistanceEngine();

  @override
  String get id => 'wheel_distance';

  @override
  String get name => AppStrings.wheelModel;

  @override
  int get modelVersion => 1;

  @override
  PredictionResult predict(List<Spin> history) {
    final List<int> numbers = history
        .map((Spin spin) => spin.number)
        .toList(growable: false);
    final List<int> deltas = <int>[
      for (int i = 1; i < numbers.length; i++)
        signedWheelDistance(numbers[i - 1], numbers[i]),
    ];
    List<double> weights = uniformDistribution(wheelExpertNames.length);
    for (int i = 1; i < deltas.length; i++) {
      final List<int> prefix = deltas.sublist(0, i);
      final List<List<double>> predictions = distanceExpertDistributions(
        prefix,
      );
      weights = hedgeUpdate(
        weights: weights,
        expertDistributions: predictions,
        actualIndex: deltas[i] + 18,
      );
    }

    final List<List<double>> experts = distanceExpertDistributions(deltas);
    final List<double> deltaDistribution = mixDistributions(experts, weights);
    final List<double> rawNumbers = List<double>.filled(rouletteNumberCount, 0);
    if (numbers.isEmpty) {
      for (int i = 0; i < rouletteNumberCount; i++) {
        rawNumbers[i] = uniformRouletteProbability;
      }
    } else {
      for (int delta = -18; delta <= 18; delta++) {
        rawNumbers[numberAtSignedDelta(numbers.last, delta)] +=
            deltaDistribution[delta + 18];
      }
    }
    final double lambda = math.min(0.78, deltas.length / (deltas.length + 90));
    final List<double> shrunk = <double>[
      for (int number = 0; number < rouletteNumberCount; number++)
        lambda * rawNumbers[number] + (1 - lambda) * uniformRouletteProbability,
    ];
    final int suffixSupport = exactSuffixSupport(deltas);
    final int fuzzySupport = fuzzyPatternSupport(deltas);
    final int? periodicLag = strongestPeriodicLag(deltas);
    final double concentration = 1 - normalizedEntropy(shrunk);
    final double supportFactor = math.min(
      1,
      (suffixSupport + fuzzySupport) / 12,
    );
    double strength =
        (numbers.length / (numbers.length + 120)) *
        (0.35 * concentration + 0.65 * supportFactor);
    if (numbers.length < 30) {
      strength = math.min(strength, 0.22);
    }
    final List<int> recentDeltas = deltas.length <= 8
        ? deltas
        : deltas.sublist(deltas.length - 8);
    final List<int> rankedDeltaIndexes = rankedIndexes(deltaDistribution);
    final int predictedDelta = rankedDeltaIndexes.first - 18;
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
        'laatsteAfstanden': recentDeltas,
        'absoluteAfstanden': recentDeltas
            .map((int value) => value.abs())
            .toList(),
        'voorspeldeAfstand': predictedDelta,
        'voorspeldeRichting': predictedDelta == 0
            ? AppStrings.equalDirection
            : predictedDelta > 0
            ? AppStrings.clockwiseDirection
            : AppStrings.counterClockwiseDirection,
        'suffixMatches': suffixSupport,
        'fuzzyMatches': fuzzySupport,
        'periodiekeLag': periodicLag,
        'contextSupport': suffixSupport + fuzzySupport,
        'uitleg': numbers.length < 4
            ? AppStrings.wheelInsufficientExplanation
            : AppStrings.wheelModelExplanation,
      },
      expertWeights: <String, double>{
        for (int i = 0; i < wheelExpertNames.length; i++)
          wheelExpertNames[i]: weights[i],
      },
      modelStrength: strength.clamp(0, 1),
    );
  }
}

List<List<double>> distanceExpertDistributions(List<int> deltas) =>
    <List<double>>[
      exactSuffixDistribution(deltas),
      fuzzyPatternDistribution(deltas),
      periodicDistribution(deltas),
      transitionDistribution(deltas),
      decayedDeltaPrior(deltas),
    ];

List<double> _smoothedDeltaVotes(List<double> votes, {double alpha = 1.2}) {
  final List<double> values = <double>[
    for (final double vote in votes) vote + alpha / 37,
  ];
  return normalizeOrUniform(values, expectedLength: 37);
}

List<double> exactSuffixDistribution(List<int> deltas) {
  final List<double> votes = List<double>.filled(37, 0);
  final int maxLength = math.min(6, deltas.length);
  final int earliest = math.max(0, deltas.length - 700);
  for (int length = 1; length <= maxLength; length++) {
    final List<int> suffix = deltas.sublist(deltas.length - length);
    for (int start = earliest; start + length < deltas.length; start++) {
      bool equal = true;
      for (int j = 0; j < length; j++) {
        if (deltas[start + j] != suffix[j]) {
          equal = false;
          break;
        }
      }
      if (equal) {
        final int age = deltas.length - (start + length);
        final double recency = math.exp(-age / 180);
        votes[deltas[start + length] + 18] += length * length * recency;
      }
    }
  }
  return _smoothedDeltaVotes(votes);
}

int exactSuffixSupport(List<int> deltas) {
  if (deltas.isEmpty) {
    return 0;
  }
  int support = 0;
  final int maxLength = math.min(6, deltas.length);
  final int earliest = math.max(0, deltas.length - 700);
  for (int length = 1; length <= maxLength; length++) {
    final List<int> suffix = deltas.sublist(deltas.length - length);
    for (int start = earliest; start + length < deltas.length; start++) {
      bool equal = true;
      for (int j = 0; j < length; j++) {
        if (deltas[start + j] != suffix[j]) {
          equal = false;
          break;
        }
      }
      if (equal) {
        support++;
      }
    }
  }
  return support;
}

List<double> fuzzyPatternDistribution(List<int> deltas) {
  final List<double> votes = List<double>.filled(37, 0);
  final int maxLength = math.min(6, deltas.length);
  final int earliest = math.max(0, deltas.length - 500);
  for (int length = 3; length <= maxLength; length++) {
    final List<int> suffix = deltas.sublist(deltas.length - length);
    for (int start = earliest; start + length < deltas.length; start++) {
      double signedDifference = 0;
      double magnitudeDifference = 0;
      for (int j = 0; j < length; j++) {
        signedDifference += (suffix[j] - deltas[start + j]).abs();
        magnitudeDifference += (suffix[j].abs() - deltas[start + j].abs())
            .abs();
      }
      final double meanDifference =
          (0.65 * signedDifference + 0.35 * magnitudeDifference) / length;
      final double similarity = math.exp(-meanDifference / 3.5);
      if (similarity >= 0.18) {
        final int age = deltas.length - (start + length);
        votes[deltas[start + length] + 18] +=
            similarity * math.exp(-age / 220) * length;
      }
    }
  }
  return _smoothedDeltaVotes(votes, alpha: 1.8);
}

int fuzzyPatternSupport(List<int> deltas) {
  if (deltas.length < 3) {
    return 0;
  }
  int support = 0;
  final int length = math.min(6, deltas.length);
  final List<int> suffix = deltas.sublist(deltas.length - length);
  final int earliest = math.max(0, deltas.length - 500);
  for (int start = earliest; start + length < deltas.length; start++) {
    double difference = 0;
    for (int j = 0; j < length; j++) {
      difference += (suffix[j] - deltas[start + j]).abs();
    }
    if (math.exp(-(difference / length) / 3.5) >= 0.18) {
      support++;
    }
  }
  return support;
}

List<double> periodicDistribution(List<int> deltas) {
  final List<double> votes = List<double>.filled(37, 0);
  for (int lag = 2; lag <= math.min(8, deltas.length); lag++) {
    final int comparisons = math.min(12, deltas.length - lag);
    if (comparisons <= 0) {
      continue;
    }
    double difference = 0;
    for (int offset = 0; offset < comparisons; offset++) {
      final int recent = deltas.length - 1 - offset;
      difference += (deltas[recent] - deltas[recent - lag]).abs();
    }
    final double score =
        (comparisons / (comparisons + 2)) *
        math.exp(-(difference / comparisons) / 2.8);
    final int predicted = deltas[deltas.length - lag];
    votes[predicted + 18] += score * (lag == 2 ? 2.2 : 1);
  }
  return _smoothedDeltaVotes(votes, alpha: 1.4);
}

int? strongestPeriodicLag(List<int> deltas) {
  int? bestLag;
  double bestScore = 0;
  for (int lag = 2; lag <= math.min(8, deltas.length); lag++) {
    final int comparisons = math.min(12, deltas.length - lag);
    if (comparisons <= 0) {
      continue;
    }
    double difference = 0;
    for (int offset = 0; offset < comparisons; offset++) {
      final int recent = deltas.length - 1 - offset;
      difference += (deltas[recent] - deltas[recent - lag]).abs();
    }
    final double score = math.exp(-(difference / comparisons) / 2.8);
    if (score > bestScore) {
      bestScore = score;
      bestLag = lag;
    }
  }
  return bestScore >= 0.35 ? bestLag : null;
}

List<double> transitionDistribution(List<int> deltas) {
  if (deltas.isEmpty) {
    return uniformDistribution();
  }
  final List<double> prior = decayedDeltaPrior(deltas);
  final List<double> votes = <double>[
    for (final double value in prior) value * 6,
  ];
  final int last = deltas.last;
  final int earliest = math.max(0, deltas.length - 1000);
  for (int i = earliest; i + 1 < deltas.length; i++) {
    if (deltas[i] == last) {
      final int age = deltas.length - 1 - i;
      votes[deltas[i + 1] + 18] += math.exp(-age / 250);
    }
  }
  return normalizeOrUniform(votes, expectedLength: 37);
}

List<double> decayedDeltaPrior(List<int> deltas) {
  final List<double> votes = List<double>.filled(37, 0.8 / 37);
  final int earliest = math.max(0, deltas.length - 1200);
  for (int i = earliest; i < deltas.length; i++) {
    final int age = deltas.length - 1 - i;
    votes[deltas[i] + 18] += math.exp(-age * math.ln2 / 90);
  }
  return normalizeOrUniform(votes, expectedLength: 37);
}
