import 'dart:math' as math;

import '../../../core/constants/roulette_constants.dart';
import '../../../core/math/probability_vector.dart';
import '../../entities/prediction.dart';
import '../../entities/roulette_bet_set.dart';
import '../../entities/roulette_number_meta.dart';
import '../../entities/spin.dart';
import 'pattern_recognizer.dart';

class BetSetAssessment {
  const BetSetAssessment({
    required this.set,
    required this.estimatedCoverage,
    required this.relativeLift,
    required this.evidenceStrength,
  });

  final RouletteBetSet set;

  /// Aggregated model mass or pattern-weighted coverage. Not a proven chance.
  final double estimatedCoverage;

  /// Relative deviation from the fair-wheel coverage of this set.
  final double relativeLift;

  /// Data support from 0 to 1. This is not a probability.
  final double evidenceStrength;
}

class BetSetAnalysisReport {
  const BetSetAnalysisReport({
    required this.modelAssessments,
    required this.patternAssessments,
    required this.modelCount,
    required this.spinsAnalyzed,
  });

  final List<BetSetAssessment> modelAssessments;
  final List<BetSetAssessment> patternAssessments;
  final int modelCount;
  final int spinsAnalyzed;

  BetSetAssessment? get modelRecommendation => modelAssessments.firstOrNull;
  BetSetAssessment? get patternRecommendation => patternAssessments.firstOrNull;
}

/// Compares table and wheel sets using the existing next-spin models and a
/// separate, conservatively shrunk pattern distribution.
class BetSetAnalyzer {
  const BetSetAnalyzer({this.maxWindow = 120}) : assert(maxWindow >= 6);

  final int maxWindow;

  BetSetAnalysisReport analyze({
    required List<Spin> history,
    required List<PredictionRecord> predictions,
  }) {
    final List<PredictionRecord> activeModels = _activeModels(
      history,
      predictions,
    );
    final List<BetSetAssessment> modelAssessments = activeModels.isEmpty
        ? const <BetSetAssessment>[]
        : _assess(
            _modelDistribution(activeModels),
            evidenceStrength: _modelStrength(activeModels),
            rankByCoverage: true,
          );

    final List<Spin> recentHistory = history
        .skip(history.length > maxWindow ? history.length - maxWindow : 0)
        .toList(growable: false);
    final _PatternDistribution? pattern = recentHistory.length < 6
        ? null
        : _patternDistribution(recentHistory);
    final List<BetSetAssessment> patternAssessments = pattern == null
        ? const <BetSetAssessment>[]
        : _assess(
            pattern.probabilities,
            evidenceStrength: pattern.strength,
            rankByCoverage: false,
          );

    return BetSetAnalysisReport(
      modelAssessments: modelAssessments,
      patternAssessments: patternAssessments,
      modelCount: activeModels.length,
      spinsAnalyzed: recentHistory.length,
    );
  }

  List<PredictionRecord> _activeModels(
    List<Spin> history,
    List<PredictionRecord> predictions,
  ) {
    final Map<String, PredictionRecord> latestByEngine =
        <String, PredictionRecord>{};
    for (final PredictionRecord record in predictions) {
      if (record.status == PredictionStatus.active &&
          record.targetPosition == history.length + 1 &&
          record.probabilities.length == rouletteNumberCount) {
        latestByEngine[record.engineId] = record;
      }
    }
    return latestByEngine.values.toList(growable: false);
  }

  List<double> _modelDistribution(List<PredictionRecord> records) =>
      mixDistributions(
        <List<double>>[
          for (final PredictionRecord record in records) record.probabilities,
        ],
        <double>[
          for (final PredictionRecord record in records)
            0.25 + 0.75 * record.modelStrength.clamp(0, 1),
        ],
      );

  double _modelStrength(List<PredictionRecord> records) {
    final double average =
        records.fold<double>(
          0,
          (double sum, PredictionRecord record) =>
              sum + record.modelStrength.clamp(0, 1),
        ) /
        records.length;
    final int sampleCount = records
        .map((PredictionRecord record) => record.basedOnSpinCount)
        .reduce(math.min);
    final double sampleFactor = sampleCount / (sampleCount + 60);
    return (0.25 * sampleFactor + 0.75 * average).clamp(0.05, 0.90);
  }

  _PatternDistribution _patternDistribution(List<Spin> history) {
    final List<int> numbers = history
        .map((Spin spin) => spin.number)
        .toList(growable: false);
    final List<double> recency = List<double>.filled(rouletteNumberCount, 0);
    for (int index = 0; index < numbers.length; index++) {
      final int age = numbers.length - 1 - index;
      recency[numbers[index]] += math.pow(0.94, age).toDouble();
    }

    final List<double> transition = List<double>.filled(rouletteNumberCount, 0);
    int transitionSupport = 0;
    final int latest = numbers.last;
    for (int index = 0; index < numbers.length - 1; index++) {
      if (numbers[index] == latest) {
        final int age = numbers.length - 2 - index;
        transition[numbers[index + 1]] += math.pow(0.95, age).toDouble();
        transitionSupport++;
      }
    }

    final PatternReport patternReport = const PatternRecognizer().analyze(
      history,
    );
    final List<List<double>> anchorDistributions = <List<double>>[];
    final List<double> anchorWeights = <double>[];
    for (final PatternSignal signal in patternReport.signals) {
      final List<double>? distribution = _signalDistribution(signal, latest);
      if (distribution != null) {
        anchorDistributions.add(distribution);
        anchorWeights.add(signal.strength);
      }
    }
    final List<double> anchors = anchorDistributions.isEmpty
        ? uniformDistribution()
        : mixDistributions(anchorDistributions, anchorWeights);

    final double transitionWeight = transitionSupport >= 2 ? 0.12 : 0;
    final double anchorWeight = anchorDistributions.isEmpty ? 0 : 0.10;
    final double uniformWeight = 1 - 0.28 - transitionWeight - anchorWeight;
    final List<double> probabilities = mixDistributions(
      <List<double>>[
        uniformDistribution(),
        normalizeOrUniform(recency, expectedLength: rouletteNumberCount),
        if (transitionWeight > 0)
          normalizeOrUniform(transition, expectedLength: rouletteNumberCount),
        if (anchorWeight > 0) anchors,
      ],
      <double>[
        uniformWeight,
        0.28,
        if (transitionWeight > 0) transitionWeight,
        if (anchorWeight > 0) anchorWeight,
      ],
    );
    final double strongestPattern = patternReport.signals.isEmpty
        ? 0
        : patternReport.signals.first.strength;
    final double sampleFactor = numbers.length / (numbers.length + 50);
    final double transitionFactor = math.min(1, transitionSupport / 6);
    final double strength = math.min(
      0.85,
      0.35 * sampleFactor + 0.45 * strongestPattern + 0.20 * transitionFactor,
    );
    return _PatternDistribution(
      probabilities: probabilities,
      strength: strength,
    );
  }

  List<BetSetAssessment> _assess(
    List<double> probabilities, {
    required double evidenceStrength,
    required bool rankByCoverage,
  }) {
    final List<BetSetAssessment> result = <BetSetAssessment>[
      for (final RouletteBetSet set in rouletteBetSets)
        BetSetAssessment(
          set: set,
          estimatedCoverage: set.numbers.fold<double>(
            0,
            (double sum, int number) => sum + probabilities[number],
          ),
          relativeLift:
              set.numbers.fold<double>(
                    0,
                    (double sum, int number) => sum + probabilities[number],
                  ) /
                  set.fairCoverage -
              1,
          evidenceStrength: evidenceStrength,
        ),
    ];
    result.sort((BetSetAssessment left, BetSetAssessment right) {
      final int primary = rankByCoverage
          ? right.estimatedCoverage.compareTo(left.estimatedCoverage)
          : right.relativeLift.compareTo(left.relativeLift);
      return primary != 0 ? primary : left.set.id.compareTo(right.set.id);
    });
    return List<BetSetAssessment>.unmodifiable(result);
  }
}

List<double>? _signalDistribution(PatternSignal signal, int latest) {
  switch (signal.kind) {
    case PatternKind.exactCycle:
      return _pointDistribution(signal.sequence.first);
    case PatternKind.wheelCycle:
      return _pointDistribution(
        numberAtSignedDelta(latest, signal.sequence.first),
      );
    case PatternKind.categoryAlternation:
      return _categoryDistribution(signal.feature, signal.sequence.first);
    case PatternKind.categoryStreak:
      return _categoryDistribution(signal.feature, signal.sequence.single);
  }
}

List<double> _pointDistribution(int number) => <double>[
  for (int value = 0; value < rouletteNumberCount; value++)
    value == number ? 1 : 0,
];

List<double>? _categoryDistribution(PatternFeature feature, int target) {
  final List<int> matching = <int>[
    for (int number = 0; number < rouletteNumberCount; number++)
      if (_matchesCategory(number, feature, target)) number,
  ];
  if (matching.isEmpty) {
    return null;
  }
  return <double>[
    for (int number = 0; number < rouletteNumberCount; number++)
      matching.contains(number) ? 1 / matching.length : 0,
  ];
}

bool _matchesCategory(int number, PatternFeature feature, int target) {
  final RouletteNumberMeta meta = RouletteNumberMeta.of(number);
  return switch (feature) {
    PatternFeature.color => meta.color.index == target,
    PatternFeature.parity =>
      meta.parity != RouletteParity.neutral && meta.parity.index == target,
    PatternFeature.range =>
      meta.range != RouletteRange.neutral && meta.range.index == target,
    PatternFeature.dozen => meta.dozen == target,
    PatternFeature.column => meta.column == target,
    _ => false,
  };
}

class _PatternDistribution {
  const _PatternDistribution({
    required this.probabilities,
    required this.strength,
  });

  final List<double> probabilities;
  final double strength;
}
