import '../../../core/constants/roulette_constants.dart';
import '../../entities/roulette_number_meta.dart';
import '../../entities/spin.dart';

enum PatternKind { exactCycle, categoryAlternation, categoryStreak, wheelCycle }

enum PatternFeature { number, color, parity, range, dozen, column, wheelStep }

class PatternSignal {
  const PatternSignal({
    required this.kind,
    required this.feature,
    required this.sequence,
    required this.span,
    required this.repeats,
    required this.strength,
  });

  final PatternKind kind;
  final PatternFeature feature;
  final List<int> sequence;
  final int span;
  final int repeats;

  /// Relative evidence strength from 0 to 1. This is not a probability.
  final double strength;
}

class PatternReport {
  const PatternReport({
    required this.spinsAnalyzed,
    required this.totalSpinCount,
    required this.signals,
  });

  static const int minimumSpinCount = 6;

  final int spinsAnalyzed;
  final int totalSpinCount;
  final List<PatternSignal> signals;

  bool get hasEnoughData => totalSpinCount >= minimumSpinCount;
}

/// Finds explainable patterns at the end of the current history.
///
/// Only suffix patterns are reported, so stale patterns disappear immediately
/// after a new spin breaks them. Work is capped to [maxWindow] recent spins.
class PatternRecognizer {
  const PatternRecognizer({this.maxWindow = 120, this.maxSignals = 4})
    : assert(maxWindow >= PatternReport.minimumSpinCount),
      assert(maxSignals > 0);

  final int maxWindow;
  final int maxSignals;

  PatternReport analyze(List<Spin> history) {
    final List<int> numbers = history
        .skip(history.length > maxWindow ? history.length - maxWindow : 0)
        .map((Spin spin) => spin.number)
        .toList(growable: false);
    if (numbers.length < PatternReport.minimumSpinCount) {
      return PatternReport(
        spinsAnalyzed: numbers.length,
        totalSpinCount: history.length,
        signals: const <PatternSignal>[],
      );
    }

    final List<PatternSignal> candidates = <PatternSignal>[
      ..._exactCycles(numbers),
      ..._categoryPatterns(numbers),
      ..._wheelCycles(numbers),
    ]..sort(_compareSignals);

    final List<PatternSignal> selected = <PatternSignal>[];
    for (final PatternSignal candidate in candidates) {
      final bool duplicate = selected.any(
        (PatternSignal current) =>
            current.kind == candidate.kind &&
            current.feature == candidate.feature,
      );
      if (!duplicate) {
        selected.add(candidate);
      }
      if (selected.length == maxSignals) {
        break;
      }
    }
    return PatternReport(
      spinsAnalyzed: numbers.length,
      totalSpinCount: history.length,
      signals: List<PatternSignal>.unmodifiable(selected),
    );
  }

  List<PatternSignal> _exactCycles(List<int> numbers) {
    final List<PatternSignal> result = <PatternSignal>[];
    final int maximumPeriod = numbers.length ~/ 2 < 8 ? numbers.length ~/ 2 : 8;
    for (int period = 1; period <= maximumPeriod; period++) {
      final List<int> cycle = numbers.sublist(numbers.length - period);
      if (!_isFundamentalCycle(cycle)) {
        continue;
      }
      final int repeats = _suffixRepeatCount(numbers, cycle);
      final int span = repeats * period;
      final int requiredRepeats = period <= 2 ? 3 : 2;
      if (repeats < requiredRepeats || span < 6) {
        continue;
      }
      final double strength = _clampStrength(
        0.52 + (repeats - requiredRepeats) * 0.09 + (span - 6) * 0.018,
      );
      result.add(
        PatternSignal(
          kind: PatternKind.exactCycle,
          feature: PatternFeature.number,
          sequence: List<int>.unmodifiable(cycle),
          span: span,
          repeats: repeats,
          strength: strength,
        ),
      );
    }
    return result;
  }

  List<PatternSignal> _categoryPatterns(List<int> numbers) {
    final List<PatternSignal> result = <PatternSignal>[];
    for (final PatternFeature feature in const <PatternFeature>[
      PatternFeature.color,
      PatternFeature.parity,
      PatternFeature.range,
      PatternFeature.dozen,
      PatternFeature.column,
    ]) {
      final List<int?> values = numbers
          .map((int number) => _categoryValue(number, feature))
          .toList(growable: false);
      final int streak = _suffixStreak(values);
      final int minimumStreak = switch (feature) {
        PatternFeature.color => 4,
        PatternFeature.parity || PatternFeature.range => 5,
        PatternFeature.dozen || PatternFeature.column => 4,
        _ => 5,
      };
      if (streak >= minimumStreak) {
        result.add(
          PatternSignal(
            kind: PatternKind.categoryStreak,
            feature: feature,
            sequence: <int>[values.last!],
            span: streak,
            repeats: streak,
            strength: _clampStrength(0.48 + (streak - minimumStreak) * 0.075),
          ),
        );
      }

      final int alternatingSpan = _alternatingSuffixLength(values);
      if (alternatingSpan >= 6) {
        result.add(
          PatternSignal(
            kind: PatternKind.categoryAlternation,
            feature: feature,
            sequence: <int>[values[values.length - 2]!, values.last!],
            span: alternatingSpan,
            repeats: alternatingSpan ~/ 2,
            strength: _clampStrength(0.50 + (alternatingSpan - 6) * 0.06),
          ),
        );
      }
    }
    return result;
  }

  List<PatternSignal> _wheelCycles(List<int> numbers) {
    final List<int> steps = <int>[
      for (int index = 1; index < numbers.length; index++)
        signedWheelDistance(numbers[index - 1], numbers[index]),
    ];
    final List<PatternSignal> result = <PatternSignal>[];
    final int maximumPeriod = steps.length ~/ 3 < 3 ? steps.length ~/ 3 : 3;
    for (int period = 1; period <= maximumPeriod; period++) {
      final List<int> cycle = steps.sublist(steps.length - period);
      if (!_isFundamentalCycle(cycle) || cycle.every((int step) => step == 0)) {
        continue;
      }
      final int repeats = _suffixRepeatCount(steps, cycle);
      final int transitionSpan = repeats * period;
      if (repeats < 3 || transitionSpan < 4) {
        continue;
      }
      result.add(
        PatternSignal(
          kind: PatternKind.wheelCycle,
          feature: PatternFeature.wheelStep,
          sequence: List<int>.unmodifiable(cycle),
          span: transitionSpan + 1,
          repeats: repeats,
          strength: _clampStrength(
            0.55 + (repeats - 3) * 0.09 + (transitionSpan - 4) * 0.018,
          ),
        ),
      );
    }
    return result;
  }
}

int? _categoryValue(int number, PatternFeature feature) {
  final RouletteNumberMeta meta = RouletteNumberMeta.of(number);
  return switch (feature) {
    PatternFeature.color => meta.color.index,
    PatternFeature.parity =>
      meta.parity == RouletteParity.neutral ? null : meta.parity.index,
    PatternFeature.range =>
      meta.range == RouletteRange.neutral ? null : meta.range.index,
    PatternFeature.dozen => meta.dozen,
    PatternFeature.column => meta.column,
    _ => null,
  };
}

int _suffixStreak(List<int?> values) {
  final int? target = values.last;
  if (target == null) {
    return 0;
  }
  int length = 0;
  for (int index = values.length - 1; index >= 0; index--) {
    if (values[index] != target) {
      break;
    }
    length++;
  }
  return length;
}

int _alternatingSuffixLength(List<int?> values) {
  if (values.length < 2 ||
      values.last == null ||
      values[values.length - 2] == null ||
      values.last == values[values.length - 2]) {
    return 0;
  }
  int length = 2;
  for (int index = values.length - 3; index >= 0; index--) {
    if (values[index] == null || values[index] != values[index + 2]) {
      break;
    }
    length++;
  }
  return length;
}

int _suffixRepeatCount(List<int> values, List<int> cycle) {
  int repeats = 0;
  int end = values.length;
  while (end >= cycle.length) {
    bool equal = true;
    final int start = end - cycle.length;
    for (int index = 0; index < cycle.length; index++) {
      if (values[start + index] != cycle[index]) {
        equal = false;
        break;
      }
    }
    if (!equal) {
      break;
    }
    repeats++;
    end -= cycle.length;
  }
  return repeats;
}

bool _isFundamentalCycle(List<int> cycle) {
  for (int period = 1; period <= cycle.length ~/ 2; period++) {
    if (cycle.length % period != 0) {
      continue;
    }
    bool repeats = true;
    for (int index = period; index < cycle.length; index++) {
      if (cycle[index] != cycle[index % period]) {
        repeats = false;
        break;
      }
    }
    if (repeats) {
      return false;
    }
  }
  return true;
}

double _clampStrength(double value) => value.clamp(0.0, 0.95).toDouble();

int _compareSignals(PatternSignal left, PatternSignal right) {
  final int byStrength = right.strength.compareTo(left.strength);
  if (byStrength != 0) {
    return byStrength;
  }
  final int bySpan = right.span.compareTo(left.span);
  if (bySpan != 0) {
    return bySpan;
  }
  final int byKind = left.kind.index.compareTo(right.kind.index);
  return byKind != 0
      ? byKind
      : left.feature.index.compareTo(right.feature.index);
}
