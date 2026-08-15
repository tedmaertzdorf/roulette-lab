import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';
import '../../core/widgets/section_card.dart';
import '../../domain/entities/spin.dart';
import '../../domain/services/analytics/roulette_analytics.dart';

class RecentDistributionCard extends StatelessWidget {
  const RecentDistributionCard({
    required this.spins,
    required this.windows,
    super.key,
  });

  final List<Spin> spins;
  final List<int> windows;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: AppStrings.recentDistribution,
    child: Column(
      children: <Widget>[
        for (int i = 0; i < windows.length; i++) ...<Widget>[
          _WindowDistribution(stats: recentStats(spins, windows[i])),
          if (i != windows.length - 1) const Divider(height: 24),
        ],
      ],
    ),
  );
}

class _WindowDistribution extends StatelessWidget {
  const _WindowDistribution({required this.stats});

  final RecentWindowStats stats;

  @override
  Widget build(BuildContext context) {
    final List<int> winners = stats.winningDozens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                AppStrings.basedOn(stats.availableSize, stats.requestedSize),
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            if (winners.isNotEmpty)
              Text(
                winners.length > 1
                    ? AppStrings.tieLabel(winners)
                    : AppStrings.leaderLabel(winners.first),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        for (int dozen = 1; dozen <= 3; dozen++)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: _DistributionBar(
              label: AppStrings.dozenLabel(dozen),
              count: stats.dozenCounts[dozen],
              percentage: stats.dozenPercentage(dozen),
              highlighted: winners.contains(dozen),
            ),
          ),
        _DistributionBar(
          label: AppStrings.zero,
          count: stats.dozenCounts[0],
          percentage: stats.availableSize == 0
              ? 0
              : stats.dozenCounts[0] / stats.availableSize,
          highlighted: false,
        ),
      ],
    );
  }
}

class _DistributionBar extends StatelessWidget {
  const _DistributionBar({
    required this.label,
    required this.count,
    required this.percentage,
    required this.highlighted,
  });

  final String label;
  final int count;
  final double percentage;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label: $count, ${AppStrings.percentage(percentage)}',
    child: Row(
      children: <Widget>[
        SizedBox(width: 82, child: Text(label)),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 9,
              color: highlighted
                  ? Theme.of(context).colorScheme.secondary
                  : Theme.of(context).colorScheme.primary,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 70,
          child: Text(
            '$count · ${AppStrings.percentage(percentage)}',
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    ),
  );
}

class BasicStatisticsCard extends StatelessWidget {
  const BasicStatisticsCard({required this.spins, super.key});

  final List<Spin> spins;

  @override
  Widget build(BuildContext context) {
    final RecentWindowStats stats = recentStats(
      spins,
      spins.isEmpty ? 1 : spins.length,
    );
    return SectionCard(
      title: AppStrings.baseStatistics,
      subtitle: AppStrings.count(spins.length),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          _StatChip(
            label: AppStrings.red,
            value: stats.colorCounts['rood'] ?? 0,
          ),
          _StatChip(
            label: AppStrings.black,
            value: stats.colorCounts['zwart'] ?? 0,
          ),
          _StatChip(label: '0', value: stats.dozenCounts[0]),
          _StatChip(
            label: AppStrings.even,
            value: stats.parityCounts['even'] ?? 0,
          ),
          _StatChip(
            label: AppStrings.odd,
            value: stats.parityCounts['oneven'] ?? 0,
          ),
          _StatChip(
            label: AppStrings.low,
            value: stats.rangeCounts['laag'] ?? 0,
          ),
          _StatChip(
            label: AppStrings.high,
            value: stats.rangeCounts['hoog'] ?? 0,
          ),
          for (int column = 1; column <= 3; column++)
            _StatChip(
              label: AppStrings.columnLabel(column),
              value: stats.columnCounts[column],
            ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Chip(
    label: Text('$label · $value'),
    side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
  );
}
