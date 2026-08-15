import '../../../core/math/statistics.dart';
import '../../entities/roulette_number_meta.dart';
import '../../entities/spin.dart';

class RecentWindowStats {
  const RecentWindowStats({
    required this.requestedSize,
    required this.availableSize,
    required this.dozenCounts,
    required this.colorCounts,
    required this.parityCounts,
    required this.rangeCounts,
    required this.columnCounts,
  });

  final int requestedSize;
  final int availableSize;
  final List<int> dozenCounts;
  final Map<String, int> colorCounts;
  final Map<String, int> parityCounts;
  final Map<String, int> rangeCounts;
  final List<int> columnCounts;

  List<int> get winningDozens {
    final int maximum = dozenCounts
        .skip(1)
        .fold<int>(0, (int a, int b) => a > b ? a : b);
    if (maximum == 0) {
      return const <int>[];
    }
    return <int>[
      for (int dozen = 1; dozen <= 3; dozen++)
        if (dozenCounts[dozen] == maximum) dozen,
    ];
  }

  double dozenPercentage(int dozen) =>
      availableSize == 0 ? 0 : dozenCounts[dozen] / availableSize;
}

RecentWindowStats recentStats(List<Spin> history, int window) {
  if (window <= 0) {
    throw RangeError.value(window, 'window');
  }
  final int start = (history.length - window).clamp(0, history.length);
  final List<Spin> spins = history.sublist(start);
  final List<int> dozens = List<int>.filled(4, 0);
  final List<int> columns = List<int>.filled(4, 0);
  final Map<String, int> colors = <String, int>{
    'rood': 0,
    'zwart': 0,
    'groen': 0,
  };
  final Map<String, int> parities = <String, int>{
    'even': 0,
    'oneven': 0,
    'neutraal': 0,
  };
  final Map<String, int> ranges = <String, int>{
    'laag': 0,
    'hoog': 0,
    'neutraal': 0,
  };
  for (final Spin spin in spins) {
    final RouletteNumberMeta meta = RouletteNumberMeta.of(spin.number);
    dozens[meta.dozen ?? 0]++;
    columns[meta.column ?? 0]++;
    colors[meta.colorLabel] = (colors[meta.colorLabel] ?? 0) + 1;
    parities[meta.parityLabel] = (parities[meta.parityLabel] ?? 0) + 1;
    ranges[meta.rangeLabel] = (ranges[meta.rangeLabel] ?? 0) + 1;
  }
  return RecentWindowStats(
    requestedSize: window,
    availableSize: spins.length,
    dozenCounts: List<int>.unmodifiable(dozens),
    colorCounts: Map<String, int>.unmodifiable(colors),
    parityCounts: Map<String, int>.unmodifiable(parities),
    rangeCounts: Map<String, int>.unmodifiable(ranges),
    columnCounts: List<int>.unmodifiable(columns),
  );
}

class TransitionStat {
  const TransitionStat({
    required this.number,
    required this.count,
    required this.percentage,
    required this.mostRecentPosition,
  });

  final int number;
  final int count;
  final double percentage;
  final int mostRecentPosition;
}

class NumberDetails {
  const NumberDetails({
    required this.number,
    required this.sampleSize,
    required this.totalOccurrences,
    required this.windowOccurrences,
    required this.positions,
    required this.gaps,
    required this.averageGap,
    required this.medianGap,
    required this.minimumGap,
    required this.maximumGap,
    required this.lastSeenSpinsAgo,
    required this.lastSeenAtUtc,
    required this.successors,
    required this.predecessors,
    required this.recentSuccessors,
    required this.pendingSuccessor,
  });

  final int number;
  final int sampleSize;
  final int totalOccurrences;
  final int windowOccurrences;
  final List<int> positions;
  final List<int> gaps;
  final double averageGap;
  final double medianGap;
  final int? minimumGap;
  final int? maximumGap;
  final int? lastSeenSpinsAgo;
  final DateTime? lastSeenAtUtc;
  final List<TransitionStat> successors;
  final List<TransitionStat> predecessors;
  final List<int> recentSuccessors;
  final bool pendingSuccessor;

  double get percentageInWindow =>
      sampleSize == 0 ? 0 : windowOccurrences / sampleSize;
}

NumberDetails numberDetails(List<Spin> history, int number, {int? lastN}) {
  RouletteNumberMeta.of(number);
  final List<int> allIndexes = <int>[
    for (int i = 0; i < history.length; i++)
      if (history[i].number == number) i,
  ];
  final int start = lastN == null
      ? 0
      : (history.length - lastN).clamp(0, history.length);
  final List<Spin> sample = history.sublist(start);
  final List<int> sampleIndexes = <int>[
    for (int i = start; i < history.length; i++)
      if (history[i].number == number) i,
  ];
  final List<int> gaps = <int>[
    for (int i = 1; i < allIndexes.length; i++)
      allIndexes[i] - allIndexes[i - 1],
  ];
  final Map<int, List<int>> successors = <int, List<int>>{};
  final Map<int, List<int>> predecessors = <int, List<int>>{};
  final List<int> recentSuccessors = <int>[];
  for (final int index in sampleIndexes) {
    if (index + 1 < history.length) {
      final int successor = history[index + 1].number;
      successors
          .putIfAbsent(successor, () => <int>[])
          .add(history[index + 1].position);
      recentSuccessors.add(successor);
    }
    if (index > start) {
      final int predecessor = history[index - 1].number;
      predecessors
          .putIfAbsent(predecessor, () => <int>[])
          .add(history[index - 1].position);
    }
  }

  List<TransitionStat> rank(Map<int, List<int>> source) {
    final int total = source.values.fold<int>(
      0,
      (int sum, List<int> values) => sum + values.length,
    );
    final List<TransitionStat> result = <TransitionStat>[
      for (final MapEntry<int, List<int>> entry in source.entries)
        TransitionStat(
          number: entry.key,
          count: entry.value.length,
          percentage: total == 0 ? 0 : entry.value.length / total,
          mostRecentPosition: entry.value.last,
        ),
    ];
    result.sort((TransitionStat a, TransitionStat b) {
      final int countOrder = b.count.compareTo(a.count);
      if (countOrder != 0) {
        return countOrder;
      }
      final int recentOrder = b.mostRecentPosition.compareTo(
        a.mostRecentPosition,
      );
      return recentOrder == 0 ? a.number.compareTo(b.number) : recentOrder;
    });
    return List<TransitionStat>.unmodifiable(result);
  }

  final int? latestIndex = allIndexes.isEmpty ? null : allIndexes.last;
  return NumberDetails(
    number: number,
    sampleSize: sample.length,
    totalOccurrences: allIndexes.length,
    windowOccurrences: sampleIndexes.length,
    positions: List<int>.unmodifiable(
      allIndexes.map((int index) => history[index].position),
    ),
    gaps: List<int>.unmodifiable(gaps),
    averageGap: mean(gaps),
    medianGap: median(gaps),
    minimumGap: gaps.isEmpty
        ? null
        : gaps.reduce((int a, int b) => a < b ? a : b),
    maximumGap: gaps.isEmpty
        ? null
        : gaps.reduce((int a, int b) => a > b ? a : b),
    lastSeenSpinsAgo: latestIndex == null
        ? null
        : history.length - 1 - latestIndex,
    lastSeenAtUtc: latestIndex == null
        ? null
        : history[latestIndex].occurredAtUtc ??
              history[latestIndex].createdAtUtc,
    successors: rank(successors),
    predecessors: rank(predecessors),
    recentSuccessors: List<int>.unmodifiable(recentSuccessors.reversed.take(8)),
    pendingSuccessor:
        sampleIndexes.isNotEmpty && sampleIndexes.last == history.length - 1,
  );
}
