import 'package:flutter_test/flutter_test.dart';
import 'package:roulette_lab/domain/entities/spin.dart';
import 'package:roulette_lab/domain/services/analytics/roulette_analytics.dart';

void main() {
  test('recente vensters tellen nul, dozijnen en ties correct', () {
    final List<Spin> history = spins(<int>[0, 1, 13, 25, 2]);
    final RecentWindowStats stats = recentStats(history, 10);
    expect(stats.availableSize, 5);
    expect(stats.dozenCounts, <int>[1, 2, 1, 1]);
    expect(stats.winningDozens, <int>[1]);
    final RecentWindowStats tie = recentStats(spins(<int>[1, 13, 25]), 3);
    expect(tie.winningDozens, <int>[1, 2, 3]);
  });

  test('voorgangers, opvolgers, gaps en laatste pending opvolger kloppen', () {
    final List<Spin> history = spins(<int>[8, 4, 8, 10, 3, 8]);
    final NumberDetails details = numberDetails(history, 8);
    expect(details.positions, <int>[1, 3, 6]);
    expect(details.gaps, <int>[2, 3]);
    expect(details.averageGap, 2.5);
    expect(details.medianGap, 2.5);
    expect(
      details.successors.map((TransitionStat e) => e.number),
      containsAll(<int>[4, 10]),
    );
    expect(
      details.predecessors.map((TransitionStat e) => e.number),
      containsAll(<int>[4, 3]),
    );
    expect(details.pendingSuccessor, isTrue);
    expect(details.lastSeenSpinsAgo, 0);
  });
}

List<Spin> spins(List<int> numbers) {
  final DateTime now = DateTime.utc(2026);
  return <Spin>[
    for (int i = 0; i < numbers.length; i++)
      Spin(
        id: i + 1,
        position: i + 1,
        number: numbers[i],
        createdAtUtc: now.add(Duration(minutes: i)),
        updatedAtUtc: now.add(Duration(minutes: i)),
      ),
  ];
}
