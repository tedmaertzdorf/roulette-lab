import 'package:flutter_test/flutter_test.dart';
import 'package:roulette_lab/core/constants/roulette_constants.dart';
import 'package:roulette_lab/domain/entities/spin.dart';
import 'package:roulette_lab/domain/services/analytics/pattern_recognizer.dart';

void main() {
  const PatternRecognizer recognizer = PatternRecognizer();

  test('wacht op voldoende historie en meldt geen vroeg patroon', () {
    final PatternReport report = recognizer.analyze(_spins(<int>[1, 2, 1, 2]));

    expect(report.hasEnoughData, isFalse);
    expect(report.signals, isEmpty);
    expect(report.spinsAnalyzed, 4);
  });

  test('herkent een exacte afsluitende getalcyclus', () {
    final PatternReport report = recognizer.analyze(
      _spins(<int>[1, 2, 3, 1, 2, 3, 1, 2, 3]),
    );
    final PatternSignal signal = report.signals.firstWhere(
      (PatternSignal value) => value.kind == PatternKind.exactCycle,
    );

    expect(signal.sequence, <int>[1, 2, 3]);
    expect(signal.repeats, 3);
    expect(signal.span, 9);
    expect(signal.strength, inInclusiveRange(0, 1));
  });

  test('herkent afwisselende kleur en laat nul de reeks doorbreken', () {
    PatternReport report = recognizer.analyze(
      _spins(<int>[1, 2, 1, 2, 1, 2, 1, 2]),
    );
    expect(
      report.signals.any(
        (PatternSignal value) =>
            value.kind == PatternKind.categoryAlternation &&
            value.feature == PatternFeature.color,
      ),
      isTrue,
    );

    report = recognizer.analyze(_spins(<int>[1, 2, 1, 2, 1, 2, 0]));
    expect(
      report.signals.any(
        (PatternSignal value) =>
            value.kind == PatternKind.categoryAlternation &&
            value.feature == PatternFeature.color,
      ),
      isFalse,
    );
  });

  test('herkent alleen de actuele suffix als categorie-reeks', () {
    final PatternReport report = recognizer.analyze(
      _spins(<int>[2, 4, 1, 3, 5, 7]),
    );
    final PatternSignal signal = report.signals.firstWhere(
      (PatternSignal value) =>
          value.kind == PatternKind.categoryStreak &&
          value.feature == PatternFeature.color,
    );

    expect(signal.span, 4);
    expect(signal.sequence, hasLength(1));
  });

  test('herkent een herhaalde fysieke wielstap', () {
    final List<int> numbers = <int>[0];
    for (int index = 0; index < 6; index++) {
      numbers.add(numberAtSignedDelta(numbers.last, 5));
    }
    final PatternReport report = recognizer.analyze(_spins(numbers));
    final PatternSignal signal = report.signals.firstWhere(
      (PatternSignal value) => value.kind == PatternKind.wheelCycle,
    );

    expect(signal.sequence, <int>[5]);
    expect(signal.repeats, 6);
    expect(signal.span, 7);
  });

  test('ruis levert geen kunstmatig sterk signaal op', () {
    final PatternReport report = recognizer.analyze(
      _spins(<int>[0, 1, 2, 14, 27, 6, 20, 35, 11, 24, 9]),
    );

    expect(
      report.signals.where((PatternSignal value) => value.strength >= 0.75),
      isEmpty,
    );
  });

  test('analyse is deterministisch, begrensd en muteert invoer niet', () {
    final List<Spin> history = _spins(<int>[
      for (int index = 0; index < 300; index++) (index * 17 + index ~/ 3) % 37,
    ]);
    final List<int> before = history.map((Spin spin) => spin.number).toList();
    final PatternReport first = recognizer.analyze(history);
    final PatternReport second = recognizer.analyze(history);

    expect(first.spinsAnalyzed, 120);
    expect(first.signals.length, lessThanOrEqualTo(4));
    expect(first.signals.map(_fingerprint), second.signals.map(_fingerprint));
    expect(history.map((Spin spin) => spin.number), before);
  });
}

String _fingerprint(PatternSignal signal) =>
    '${signal.kind.name}:${signal.feature.name}:${signal.sequence}:'
    '${signal.span}:${signal.repeats}:${signal.strength}';

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
