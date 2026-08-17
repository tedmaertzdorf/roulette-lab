import 'package:flutter_test/flutter_test.dart';
import 'package:roulette_lab/domain/entities/prediction.dart';
import 'package:roulette_lab/domain/entities/roulette_bet_set.dart';
import 'package:roulette_lab/domain/entities/spin.dart';
import 'package:roulette_lab/domain/services/analytics/bet_set_analyzer.dart';

void main() {
  const BetSetAnalyzer analyzer = BetSetAnalyzer();

  test('dozijnen, kolommen en officiële wielsectoren zijn geldig', () {
    for (final RouletteBetSet set in rouletteBetSets) {
      expect(set.numbers, isNotEmpty, reason: set.id);
      expect(
        set.numbers.toSet(),
        hasLength(set.numbers.length),
        reason: set.id,
      );
      expect(
        set.numbers.every((int number) => number >= 0 && number <= 36),
        isTrue,
        reason: set.id,
      );
      expect(set.fairCoverage, closeTo(set.numbers.length / 37, 1e-12));
    }

    final List<RouletteBetSet> primaryWheelSectors = rouletteBetSets
        .where(
          (RouletteBetSet set) => const <RouletteBetSetKind>{
            RouletteBetSetKind.voisins,
            RouletteBetSetKind.tiers,
            RouletteBetSetKind.orphelins,
          }.contains(set.kind),
        )
        .toList();
    final List<int> covered = primaryWheelSectors
        .expand((RouletteBetSet set) => set.numbers)
        .toList();
    expect(covered, hasLength(37));
    expect(covered.toSet(), <int>{
      for (int number = 0; number <= 36; number++) number,
    });
  });

  test(
    'kansberekening gebruikt alleen actieve modellen voor de volgende draai',
    () {
      final List<Spin> history = _spins(<int>[1, 4, 7, 10, 13, 16]);
      final List<double> secondColumn = List<double>.filled(37, 0);
      for (final int number
          in rouletteBetSets
              .firstWhere((RouletteBetSet set) => set.id == 'column_2')
              .numbers) {
        secondColumn[number] = 1 / 12;
      }
      final PredictionRecord active = _prediction(
        probabilities: secondColumn,
        targetPosition: 7,
      );
      final PredictionRecord stale = _prediction(
        probabilities: List<double>.filled(37, 1 / 37),
        targetPosition: 6,
      );

      final BetSetAnalysisReport report = analyzer.analyze(
        history: history,
        predictions: <PredictionRecord>[stale, active],
      );

      expect(report.modelCount, 1);
      expect(report.modelRecommendation?.set.id, 'column_2');
      expect(report.modelRecommendation?.estimatedCoverage, closeTo(1, 1e-12));
      expect(report.modelAssessments, hasLength(rouletteBetSets.length));
    },
  );

  test('patroonanalyse reageert op een afsluitende getalcyclus', () {
    final BetSetAnalysisReport report = analyzer.analyze(
      history: _spins(<int>[1, 2, 3, 1, 2, 3, 1, 2, 3]),
      predictions: const <PredictionRecord>[],
    );

    expect(report.modelRecommendation, isNull);
    expect(report.patternRecommendation, isNotNull);
    expect(report.patternRecommendation!.set.contains(1), isTrue);
    expect(report.patternRecommendation!.relativeLift, greaterThan(0));
    expect(
      report.patternAssessments.every(
        (BetSetAssessment value) =>
            value.estimatedCoverage.isFinite &&
            value.estimatedCoverage >= 0 &&
            value.estimatedCoverage <= 1 &&
            value.evidenceStrength >= 0 &&
            value.evidenceStrength <= 1,
      ),
      isTrue,
    );
  });

  test('weinig data geeft nog geen patroonaanbeveling', () {
    final BetSetAnalysisReport report = analyzer.analyze(
      history: _spins(<int>[1, 2, 3, 1, 2]),
      predictions: const <PredictionRecord>[],
    );

    expect(report.spinsAnalyzed, 5);
    expect(report.patternRecommendation, isNull);
  });

  test('10.000 draaien worden begrensd en invoer blijft ongewijzigd', () {
    final List<Spin> history = _spins(<int>[
      for (int index = 0; index < 10000; index++)
        (index * 17 + index ~/ 7 + (index % 11) * 3) % 37,
    ]);
    final List<int> before = history.map((Spin spin) => spin.number).toList();

    final BetSetAnalysisReport report = analyzer.analyze(
      history: history,
      predictions: const <PredictionRecord>[],
    );

    expect(report.spinsAnalyzed, 120);
    expect(report.patternAssessments, hasLength(rouletteBetSets.length));
    expect(history.map((Spin spin) => spin.number), before);
  });
}

PredictionRecord _prediction({
  required List<double> probabilities,
  required int targetPosition,
}) {
  final PredictionResult result = PredictionResult(
    engineId: 'test-model',
    engineName: 'Testmodel',
    modelVersion: 1,
    probabilities: probabilities,
    historyFingerprint: 'test',
    sampleCount: targetPosition - 1,
    diagnostics: const <String, Object?>{},
    expertWeights: const <String, double>{},
    modelStrength: 0.7,
  );
  return PredictionRecord.fromResult(
    result: result,
    targetPosition: targetPosition,
    nowUtc: DateTime.utc(2026),
  );
}

List<Spin> _spins(List<int> numbers) {
  final DateTime start = DateTime.utc(2026);
  return <Spin>[
    for (int index = 0; index < numbers.length; index++)
      Spin(
        id: index + 1,
        position: index + 1,
        number: numbers[index],
        createdAtUtc: start.add(Duration(seconds: index)),
        updatedAtUtc: start.add(Duration(seconds: index)),
      ),
  ];
}
